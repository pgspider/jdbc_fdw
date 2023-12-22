/*-------------------------------------------------------------------------
 *
 * connection.c
 *        Connection management functions for jdbc_fdw
 *
 * Portions Copyright (c) 2012-2014, PostgreSQL Global Development Group
 *
 * Portions Copyright (c) 2021, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *        contrib/jdbc_fdw/connection.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "jdbc_fdw.h"

#if PG_VERSION_NUM >= 130000
#include "common/hashfn.h"
#endif
#include "access/xact.h"
#include "mb/pg_wchar.h"
#include "miscadmin.h"
#include "pthread.h"
#include "utils/hsearch.h"
#include "utils/memutils.h"
#include "utils/elog.h"
#include "utils/inval.h"
#include "utils/syscache.h"


/*
 * JdbcUtils cache hash table entry
 *
 * The jdbc connection will handled by JdbcUtils class.
 *
 * The "jdbcUtilsInfo" pointer keep information of JdbcUtils object to re-use.
 */
typedef struct JdbcUtilsCacheKey
{
	Oid			serverid;		/* OID of foreign server */
	Oid			userid;			/* OID of local user whose mapping we use */
} JdbcUtilsCacheKey;

typedef struct JdbcUtilCacheEntry
{
	JdbcUtilsCacheKey key;			/* hash key (must be first) */
	JDBCUtilsInfo *jdbcUtilsInfo;	/* connection to foreign server, or NULL */
	uint32		server_hashvalue;	/* hash value of foreign server OID */
	uint32		mapping_hashvalue;	/* hash value of user mapping OID */
} JdbcUtilCacheEntry;

/*
 * JdbcUtils cache: save JdbcUtils object created based on Jenv (a thread local variable)
 * to re-use/release JDBCUtils object (not jdbc connection).
 */
static __thread HTAB *JdbcUtilsHash = NULL;

/* tracks whether any work is needed in callback functions */
static __thread volatile bool xact_got_connection = false;

/* prototypes of private functions */
static JDBCUtilsInfo * connect_jdbc_server(ForeignServer *server, UserMapping *user);
static void jdbc_check_conn_params(const char **keywords, const char **values);
static void jdbcfdw_xact_callback(XactEvent event, void *arg);
static void jdbc_fdw_inval_callback(Datum arg, int cacheid, uint32 hashvalue);

/*
 * Get a Jconn which can be used to execute queries on the remote JDBC server
 * server with the user's authorization.  A new connection is established if
 * we don't already have a suitable one, and a transaction is opened at the
 * right subtransaction nesting depth if we didn't do that already.
 *
 * will_prep_stmt must be true if caller intends to create any prepared
 * statements.  Since those don't go away automatically at transaction end
 * (not even on error), we need this flag to cue manual cleanup.
 *
 * XXX Note that caching connections theoretically requires a mechanism to
 * detect change of FDW objects to invalidate already established
 * connections. We could manage that by watching for invalidation events on
 * the relevant syscaches.  For the moment, though, it's not clear that this
 * would really be useful and not mere pedantry.  We could not flush any
 * active connections mid-transaction anyway.
 */
JDBCUtilsInfo *
jdbc_get_jdbc_utils_obj(ForeignServer *server, UserMapping *user,
						bool will_prep_stmt)
{
	bool		found;
	JdbcUtilCacheEntry *entry;
	JdbcUtilsCacheKey key;
	static bool xact_callback_registered = false;

	if (JdbcUtilsHash == NULL)
	{
		HASHCTL		ctl;
		char *hash_tbl_name;

		MemSet(&ctl, 0, sizeof(ctl));
		ctl.keysize = sizeof(JdbcUtilsCacheKey);
		ctl.entrysize = sizeof(JdbcUtilCacheEntry);
		ctl.hash = tag_hash;
		/* allocate JdbcUtilsHash in the cache context */
		ctl.hcxt = CacheMemoryContext;
		hash_tbl_name = psprintf("jdbc_fdw connections %lu", pthread_self());
		JdbcUtilsHash = hash_create(hash_tbl_name, 8,
									 &ctl,
									 HASH_ELEM | HASH_FUNCTION | HASH_CONTEXT);
	}

	/* First time through, initialize connection cache hashtable */
	if (!xact_callback_registered)
	{
		/*
		 * Register some callback functions that manage connection cleanup.
		 * This should be done just once in each backend.
		 */
		RegisterXactCallback(jdbcfdw_xact_callback, NULL);
		CacheRegisterSyscacheCallback(FOREIGNSERVEROID,
									  jdbc_fdw_inval_callback, (Datum) 0);
		CacheRegisterSyscacheCallback(USERMAPPINGOID,
									  jdbc_fdw_inval_callback, (Datum) 0);
		xact_callback_registered = true;
	}
	ereport(DEBUG3, (errmsg("Added server = %s to hashtable", server->servername)));

	/* Set flag that we did GetConnection during the current transaction */
	xact_got_connection = true;

	/* Create hash key for the entry.  Assume no pad bytes in key struct */
	key.serverid = server->serverid;
	key.userid = user->userid;

	/*
	 * Find or create cached entry for requested connection.
	 */
	entry = hash_search(JdbcUtilsHash, &key, HASH_ENTER, &found);
	if (!found)
	{
		/* initialize new hashtable entry (key is already filled in) */
		entry->jdbcUtilsInfo = NULL;
	}

	/*
	 * If cache entry doesn't have a connection, we have to establish a new
	 * connection.  (If connect_jdbc_server throws an error, the cache entry
	 * will be left in a valid empty state.)
	 */
	if (entry->jdbcUtilsInfo == NULL)
	{
		entry->server_hashvalue =
			GetSysCacheHashValue1(FOREIGNSERVEROID,
								  ObjectIdGetDatum(server->serverid));
		entry->mapping_hashvalue =
			GetSysCacheHashValue1(USERMAPPINGOID,
								  ObjectIdGetDatum(user->umid));
		entry->jdbcUtilsInfo = connect_jdbc_server(server, user);
	}
	else
	{
		jdbc_jvm_init(server, user);
	}

	return entry->jdbcUtilsInfo;
}

/*
 * Connection invalidation callback function
 *
 * After a change to a pg_foreign_server or pg_user_mapping catalog entry,
 * mark connections depending on that entry as needing to be remade.
 * We can't immediately destroy them, since they might be in the midst of
 * a transaction, but we'll remake them at the next opportunity.
 *
 * Although most cache invalidation callbacks blow away all the related stuff
 * regardless of the given hashvalue, connections are expensive enough that
 * it's worth trying to avoid that.
 *
 * NB: We could avoid unnecessary disconnection more strictly by examining
 * individual option values, but it seems too much effort for the gain.
 */
static void
jdbc_fdw_inval_callback(Datum arg, int cacheid, uint32 hashvalue)
{
	HASH_SEQ_STATUS scan;
	JdbcUtilCacheEntry *entry;

	Assert(cacheid == FOREIGNSERVEROID || cacheid == USERMAPPINGOID);

	/* JdbcUtilsHash must exist already, if we're registered */
	hash_seq_init(&scan, JdbcUtilsHash);
	while ((entry = (JdbcUtilCacheEntry *) hash_seq_search(&scan)))
	{
		/* Ignore invalid entries */
		if (entry->jdbcUtilsInfo == NULL)
			continue;

		/* hashvalue == 0 means a cache reset, must clear all state */
		if (hashvalue == 0 ||
			(cacheid == FOREIGNSERVEROID &&
			 entry->server_hashvalue == hashvalue) ||
			(cacheid == USERMAPPINGOID &&
			 entry->mapping_hashvalue == hashvalue))
		{
			pfree(entry->jdbcUtilsInfo);
			entry->jdbcUtilsInfo = NULL;
		}
	}

	/* release JDBC connection on JDBCUtils object also */
	jq_inval_callback(cacheid, hashvalue);
}

/*
 * Connect to remote server using specified server and user mapping
 * properties.
 */
static JDBCUtilsInfo *
connect_jdbc_server(ForeignServer *server, UserMapping *user)
{
	JDBCUtilsInfo *volatile jdbcUtilsInfo = NULL;

	/*
	 * Use PG_TRY block to ensure closing connection on error.
	 */
	PG_TRY();
	{
		const char **keywords;
		const char **values;
		int			n;

		/*
		 * Construct connection params from generic options of ForeignServer
		 * and UserMapping.  (Some of them might not be libpq options, in
		 * which case we'll just waste a few array slots.)  Add 3 extra slots
		 * for fallback_application_name, client_encoding, end marker.
		 */
		n = list_length(server->options) + list_length(user->options) + 3;
		keywords = (const char **) palloc(n * sizeof(char *));
		values = (const char **) palloc(n * sizeof(char *));

		n = 0;
		n += jdbc_extract_connection_options(server->options,
											 keywords + n, values + n);
		n += jdbc_extract_connection_options(user->options,
											 keywords + n, values + n);

		/* Use "jdbc_fdw" as fallback_application_name. */
		keywords[n] = "fallback_application_name";
		values[n] = "jdbc_fdw";
		n++;

		/*
		 * Set client_encoding so that libpq can convert encoding properly.
		 */
		keywords[n] = "client_encoding";
		values[n] = GetDatabaseEncodingName();
		n++;

		keywords[n] = values[n] = NULL;

		/* verify connection parameters and make connection */
		jdbc_check_conn_params(keywords, values);

		jdbcUtilsInfo = jq_connect_db_params(server, user, keywords, values);
		if (!jdbcUtilsInfo || jq_status(jdbcUtilsInfo) != CONNECTION_OK)
		{
			char	   *connmessage;
			int			msglen;

			/* libpq typically appends a newline, strip that */
			connmessage = pstrdup(jq_error_message(jdbcUtilsInfo));
			msglen = strlen(connmessage);
			if (msglen > 0 && connmessage[msglen - 1] == '\n')
				connmessage[msglen - 1] = '\0';
			ereport(ERROR,
					(errcode(ERRCODE_SQLCLIENT_UNABLE_TO_ESTABLISH_SQLCONNECTION),
					 errmsg("could not connect to server \"%s\"",
							server->servername),
					 errdetail_internal("%s", connmessage)));
		}

		pfree(keywords);
		pfree(values);
	}
	PG_CATCH();
	{
		/* Release Jconn data structure if we managed to create one */
		if (jdbcUtilsInfo)
		{
			pfree(jdbcUtilsInfo);
			jq_finish();
		}
		PG_RE_THROW();
	}
	PG_END_TRY();

	return jdbcUtilsInfo;
}

/*
 * For non-superusers, insist that the connstr specify a password.  This
 * prevents a password from being picked up from .pgpass, a service file, the
 * environment, etc.  We don't want the postgres user's passwords to be
 * accessible to non-superusers.  (See also dblink_connstr_check in
 * contrib/dblink.)
 */
static void
jdbc_check_conn_params(const char **keywords, const char **values)
{
	int			i;

	/* no check required if superuser */
	if (superuser())
		return;

	/* ok if params contain a non-empty password */
	for (i = 0; keywords[i] != NULL; i++)
	{
		if (strcmp(keywords[i], "password") == 0 && values[i][0] != '\0')
			return;
	}

	ereport(ERROR,
			(errcode(ERRCODE_S_R_E_PROHIBITED_SQL_STATEMENT_ATTEMPTED),
			 errmsg("password is required"),
			 errdetail("Non-superusers must provide a password in the user mapping.")));
}

/*
 * Release JDBCUtils object created by jdbc_get_JDBCUtils.
 */
void
jdbc_release_jdbc_utils_obj(void)
{
	HASH_SEQ_STATUS scan;
	JdbcUtilCacheEntry *entry;

	/* there is no JDBCUtils object, do nothing */
	if (JdbcUtilsHash == NULL)
		return;

	/*
	 * Scan all connection cache entries and release its resource
	 */
	hash_seq_init(&scan, JdbcUtilsHash);
	while ((entry = (JdbcUtilCacheEntry *) hash_seq_search(&scan)))
	{
		/* Ignore cache entry if no open connection right now */
		if (entry->jdbcUtilsInfo == NULL)
			continue;

		/* release JDBCUtils resource */
		jq_cancel(entry->jdbcUtilsInfo);
		entry->jdbcUtilsInfo->JDBCUtilsObject = NULL;
		pfree(entry->jdbcUtilsInfo);
		entry->jdbcUtilsInfo = NULL;
	}
	jq_finish();
}

/*
 * Report an error we got from the remote server.
 *
 * elevel: error level to use (typically ERROR, but might be less) res:
 * Jresult containing the error jdbcUtilsInfo: connection we did the query on clear:
 * if true, jq_clear the result (otherwise caller will handle it) sql: NULL,
 * or text of remote command we tried to execute
 *
 * Note: callers that choose not to throw ERROR for a remote error are
 * responsible for making sure that the associated JdbcUtilCacheEntry gets marked
 * with have_error = true.
 */
void
jdbc_fdw_report_error(int elevel, Jresult * res, JDBCUtilsInfo * jdbcUtilsInfo,
					  bool clear, const char *sql)
{
	/*
	 * If requested, Jresult must be released before leaving this function.
	 */
	PG_TRY();
	{
		char	   *diag_sqlstate = jq_result_error_field(res, PG_DIAG_SQLSTATE);
		char	   *message_primary = jq_result_error_field(res, PG_DIAG_MESSAGE_PRIMARY);
		char	   *message_detail = jq_result_error_field(res, PG_DIAG_MESSAGE_DETAIL);
		char	   *message_hint = jq_result_error_field(res, PG_DIAG_MESSAGE_HINT);
		char	   *message_context = jq_result_error_field(res, PG_DIAG_CONTEXT);
		int			sqlstate;

		if (diag_sqlstate)
			sqlstate = MAKE_SQLSTATE(diag_sqlstate[0],
									 diag_sqlstate[1],
									 diag_sqlstate[2],
									 diag_sqlstate[3],
									 diag_sqlstate[4]);
		else
			sqlstate = ERRCODE_CONNECTION_FAILURE;

		/*
		 * If we don't get a message from the Jresult, try the Jconn. This is
		 * needed because for connection-level failures, jq_exec may just
		 * return NULL, not a Jresult at all.
		 */
		if (message_primary == NULL)
			message_primary = jq_error_message(jdbcUtilsInfo);

		ereport(elevel,
				(errcode(sqlstate),
				 message_primary ? errmsg_internal("%s", message_primary) :
				 errmsg("unknown error"),
				 message_detail ? errdetail_internal("%s", message_detail) : 0,
				 message_hint ? errhint("%s", message_hint) : 0,
				 message_context ? errcontext("%s", message_context) : 0,
				 sql ? errcontext("Remote SQL command: %s", sql) : 0));
	}
	PG_CATCH();
	{
		if (clear)
			jq_clear(res);
		PG_RE_THROW();
	}
	PG_END_TRY();
	if (clear)
		jq_clear(res);
}

/*
 * jdbcfdw_xact_callback --- cleanup at main-transaction end.
 */
static void
jdbcfdw_xact_callback(XactEvent event, void *arg)
{
	HASH_SEQ_STATUS scan;
	JdbcUtilCacheEntry *entry;

	/* Quick exit if no connections were touched in this transaction. */
	if (!xact_got_connection)
		return;

	if (event == XACT_EVENT_COMMIT || event == XACT_EVENT_ABORT)
	{
		/*
		 * Scan all connection cache entries and release its resource
		 */
		hash_seq_init(&scan, JdbcUtilsHash);
		while ((entry = (JdbcUtilCacheEntry *) hash_seq_search(&scan)))
		{
			/* Ignore cache entry if no open connection right now */
			if (entry->jdbcUtilsInfo == NULL)
				continue;

			/* release JDBCUtils resource */
			jq_cancel(entry->jdbcUtilsInfo);
			entry->jdbcUtilsInfo->JDBCUtilsObject = NULL;
			pfree(entry->jdbcUtilsInfo);
			entry->jdbcUtilsInfo = NULL;
		}

		jq_release_all_result_sets();
		jq_finish();
		xact_got_connection = false;
	}
}
