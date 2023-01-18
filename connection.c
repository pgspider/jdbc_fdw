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
#include "utils/hsearch.h"
#include "utils/memutils.h"
#include "utils/elog.h"
#include "utils/syscache.h"


/*
 * Connection cache hash table entry
 *
 * The lookup key in this hash table is the foreign server OID plus the user
 * mapping OID.  (We use just one connection per user per foreign server, so
 * that we can ensure all scans use the same snapshot during a query.)
 *
 * The "conn" pointer can be NULL if we don't currently have a live
 * connection. When we do have a connection, xact_depth tracks the current
 * depth of transactions and subtransactions open on the remote side.  We
 * need to issue commands at the same nesting depth on the remote as we're
 * executing at ourselves, so that rolling back a subtransaction will kill
 * the right queries and not the wrong ones.
 */
typedef struct ConnCacheKey
{
	Oid			serverid;		/* OID of foreign server */
	Oid			userid;			/* OID of local user whose mapping we use */
} ConnCacheKey;

typedef struct ConnCacheEntry
{
	ConnCacheKey key;			/* hash key (must be first) */
	Jconn	   *conn;			/* connection to foreign server, or NULL */
	int			xact_depth;		/* 0 = no xact open, 1 = main xact open, 2 =
								 * one level of subxact open, etc */
	bool		have_prep_stmt; /* have we prepared any stmts in this xact? */
	bool		have_error;		/* have any subxacts aborted in this xact? */
} ConnCacheEntry;

/*
 * Connection cache (initialized on first use)
 */
static HTAB *ConnectionHash = NULL;

/* for assigning cursor numbers and prepared statement numbers */
static volatile unsigned int cursor_number = 0;
static unsigned int prep_stmt_number = 0;

/* tracks whether any work is needed in callback functions */
static volatile bool xact_got_connection = false;

/* prototypes of private functions */
static Jconn * connect_jdbc_server(ForeignServer *server, UserMapping *user);
static void jdbc_check_conn_params(const char **keywords, const char **values);
static void jdbc_do_sql_command(Jconn * conn, const char *sql);
static void jdbcfdw_xact_callback(XactEvent event, void *arg);
static void jdbcfdw_abort_cleanup(ConnCacheEntry *entry, bool toplevel);
static void jdbcfdw_subxact_callback(SubXactEvent event,
									 SubTransactionId mySubid,
									 SubTransactionId parentSubid,
									 void *arg);
static void jdbcfdw_reset_xact_state(ConnCacheEntry *entry, bool toplevel);


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
Jconn *
jdbc_get_connection(ForeignServer *server, UserMapping *user,
					bool will_prep_stmt)
{
	bool		found;
	ConnCacheEntry *entry;
	ConnCacheKey key;

	/* First time through, initialize connection cache hashtable */
	if (ConnectionHash == NULL)
	{
		HASHCTL		ctl;

		MemSet(&ctl, 0, sizeof(ctl));
		ctl.keysize = sizeof(ConnCacheKey);
		ctl.entrysize = sizeof(ConnCacheEntry);
		ctl.hash = tag_hash;
		/* allocate ConnectionHash in the cache context */
		ctl.hcxt = CacheMemoryContext;
		ConnectionHash = hash_create("jdbc_fdw connections", 8,
									 &ctl,
									 HASH_ELEM | HASH_FUNCTION | HASH_CONTEXT);

		/*
		 * Register some callback functions that manage connection cleanup.
		 * This should be done just once in each backend.
		 */
		RegisterXactCallback(jdbcfdw_xact_callback, NULL);
		RegisterSubXactCallback(jdbcfdw_subxact_callback, NULL);
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
	entry = hash_search(ConnectionHash, &key, HASH_ENTER, &found);
	if (!found)
	{
		/* initialize new hashtable entry (key is already filled in) */
		entry->conn = NULL;
		entry->xact_depth = 0;
		entry->have_prep_stmt = false;
		entry->have_error = false;
	}

	/*
	 * We don't check the health of cached connection here, because it would
	 * require some overhead.  Broken connection will be detected when the
	 * connection is actually used.
	 */

	/*
	 * If cache entry doesn't have a connection, we have to establish a new
	 * connection.  (If connect_jdbc_server throws an error, the cache entry
	 * will be left in a valid empty state.)
	 */
	if (entry->conn == NULL)
	{
		entry->xact_depth = 0;	/* just to be sure */
		entry->have_prep_stmt = false;
		entry->have_error = false;
		entry->conn = connect_jdbc_server(server, user);
	}
	else
	{
		jdbc_jvm_init(server, user);
	}

	/* Remember if caller will prepare statements */
	entry->have_prep_stmt |= will_prep_stmt;

	return entry->conn;
}

/*
 * Connect to remote server using specified server and user mapping
 * properties.
 */
static Jconn *
connect_jdbc_server(ForeignServer *server, UserMapping *user)
{
	Jconn	   *volatile conn = NULL;

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

		conn = jq_connect_db_params(server, user, keywords, values);
		if (!conn || jq_status(conn) != CONNECTION_OK)
		{
			char	   *connmessage;
			int			msglen;

			/* libpq typically appends a newline, strip that */
			connmessage = pstrdup(jq_error_message(conn));
			msglen = strlen(connmessage);
			if (msglen > 0 && connmessage[msglen - 1] == '\n')
				connmessage[msglen - 1] = '\0';
			ereport(ERROR,
					(errcode(ERRCODE_SQLCLIENT_UNABLE_TO_ESTABLISH_SQLCONNECTION),
					 errmsg("could not connect to server \"%s\"",
							server->servername),
					 errdetail_internal("%s", connmessage)));
		}

		/*
		 * Check that non-superuser has used password to establish connection;
		 * otherwise, he's piggybacking on the JDBC server's user identity.
		 * See also dblink_security_check() in contrib/dblink.
		 */
		if (!superuser() && !jq_connection_used_password(conn))
			ereport(ERROR,
					(errcode(ERRCODE_S_R_E_PROHIBITED_SQL_STATEMENT_ATTEMPTED),
					 errmsg("password is required"),
					 errdetail("Non-superuser cannot connect if the server does not request a password."),
					 errhint("Target server's authentication method must be changed.")));

		pfree(keywords);
		pfree(values);
	}
	PG_CATCH();
	{
		/* Release Jconn data structure if we managed to create one */
		if (conn)
			jq_finish(conn);
		PG_RE_THROW();
	}
	PG_END_TRY();

	return conn;
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
 * Convenience subroutine to issue a non-data-returning SQL command to remote
 */
static void
jdbc_do_sql_command(Jconn * conn, const char *sql)
{
	Jresult    *res;

	res = jq_exec(conn, sql);
	if (*res != PGRES_COMMAND_OK)
		jdbc_fdw_report_error(ERROR, res, conn, true, sql);
	jq_clear(res);
}

/*
 * Release connection reference count created by calling GetConnection.
 */
void
jdbc_release_connection(Jconn * conn)
{
	/*
	 * Currently, we don't actually track connection references because all
	 * cleanup is managed on a transaction or subtransaction basis instead. So
	 * there's nothing to do here.
	 */
}

/*
 * Assign a "unique" number for a cursor.
 *
 * These really only need to be unique per connection within a transaction.
 * For the moment we ignore the per-connection point and assign them across
 * all connections in the transaction, but we ask for the connection to be
 * supplied in case we want to refine that.
 *
 * Note that even if wraparound happens in a very long transaction, actual
 * collisions are highly improbable; just be sure to use %u not %d to print.
 */
unsigned int
jdbc_get_cursor_number(Jconn * conn)
{
	return ++cursor_number;
}

/*
 * Assign a "unique" number for a prepared statement.
 *
 * This works much like jdbc_get_cursor_number, except that we never reset
 * the counter within a session.  That's because we can't be 100% sure we've
 * gotten rid of all prepared statements on all connections, and it's not
 * really worth increasing the risk of prepared-statement name collisions by
 * resetting.
 */
unsigned int
jdbc_get_prep_stmt_number(Jconn * conn)
{
	return ++prep_stmt_number;
}

/*
 * Report an error we got from the remote server.
 *
 * elevel: error level to use (typically ERROR, but might be less) res:
 * Jresult containing the error conn: connection we did the query on clear:
 * if true, jq_clear the result (otherwise caller will handle it) sql: NULL,
 * or text of remote command we tried to execute
 *
 * Note: callers that choose not to throw ERROR for a remote error are
 * responsible for making sure that the associated ConnCacheEntry gets marked
 * with have_error = true.
 */
void
jdbc_fdw_report_error(int elevel, Jresult * res, Jconn * conn,
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
			message_primary = jq_error_message(conn);

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
	ConnCacheEntry *entry;

	/* Quick exit if no connections were touched in this transaction. */
	if (!xact_got_connection)
		return;

	/*
	 * Scan all connection cache entries to find open remote transactions, and
	 * close them.
	 */
	hash_seq_init(&scan, ConnectionHash);
	while ((entry = (ConnCacheEntry *) hash_seq_search(&scan)))
	{
		Jresult    *res;

		/* Ignore cache entry if no open connection right now */
		if (entry->conn == NULL)
			continue;

		/* If it has an open remote transaction, try to close it */
		if (entry->xact_depth > 0)
		{
			elog(DEBUG3, "closing remote transaction on connection %p",
				 entry->conn);

			switch (event)
			{
				case XACT_EVENT_PRE_COMMIT:

					/*
					 * Commit all remote transactions during pre-commit
					 */
					jdbc_do_sql_command(entry->conn, "COMMIT TRANSACTION");

					/*
					 * If there were any errors in subtransactions, and we
					 * made prepared statements, do a DEALLOCATE ALL to make
					 * sure we get rid of all prepared statements. This is
					 * annoying and not terribly bulletproof, but it's
					 * probably not worth trying harder.
					 *
					 * DEALLOCATE ALL only exists in 8.3 and later, so this
					 * constrains how old a server jdbc_fdw can communicate
					 * with.  We intentionally ignore errors in the
					 * DEALLOCATE, so that we can hobble along to some extent
					 * with older servers (leaking prepared statements as we
					 * go; but we don't really support update operations
					 * pre-8.3 anyway).
					 */
					if (entry->have_prep_stmt && entry->have_error)
					{
						res = jq_exec(entry->conn, "DEALLOCATE ALL");
						jq_clear(res);
					}
					entry->have_prep_stmt = false;
					entry->have_error = false;
					break;
				case XACT_EVENT_PRE_PREPARE:

					/*
					 * We disallow remote transactions that modified anything,
					 * since it's not very reasonable to hold them open until
					 * the prepared transaction is committed.  For the moment,
					 * throw error unconditionally; later we might allow
					 * read-only cases. Note that the error will cause us to
					 * come right back here with event == XACT_EVENT_ABORT, so
					 * we'll clean up the connection state at that point.
					 */
					ereport(ERROR,
							(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
							 errmsg("cannot prepare a transaction that modified remote tables")));
					break;
				case XACT_EVENT_COMMIT:
				case XACT_EVENT_PREPARE:

					/*
					 * Pre-commit should have closed the open transaction
					 */
					elog(ERROR, "missed cleaning up connection during pre-commit");
					break;
				case XACT_EVENT_ABORT:
				{
					jdbcfdw_abort_cleanup(entry, true);
					break;
				}
				case XACT_EVENT_PARALLEL_COMMIT:
					break;
				case XACT_EVENT_PARALLEL_ABORT:
					break;
				case XACT_EVENT_PARALLEL_PRE_COMMIT:
					break;
			}
		}

		/* Reset state to show we're out of a transaction */
		jdbcfdw_reset_xact_state(entry, true);
	}

	/*
	 * Regardless of the event type, we can now mark ourselves as out of the
	 * transaction.  (Note: if we are here during PRE_COMMIT or PRE_PREPARE,
	 * this saves a useless scan of the hashtable during COMMIT or PREPARE.)
	 */
	xact_got_connection = false;

	/* Also reset cursor numbering for next transaction */
	cursor_number = 0;
}

/*
 * Abort remote transaction or subtransaction.
 *
 * "toplevel" should be set to true if toplevel (main) transaction is
 * rollbacked, false otherwise.
 *
 * Set entry->changing_xact_state to false on success, true on failure.
 */
static void
jdbcfdw_abort_cleanup(ConnCacheEntry *entry, bool toplevel)
{
	Jresult    *res;

	if (toplevel)
	{
		/*
		 * Assume we might have lost track of prepared statements
		 */
		entry->have_error = true;

		/*
		 * If we're aborting, abort all remote transactions too
		 */
		res = jq_exec(entry->conn, "ABORT TRANSACTION");

		/*
		 * Note: can't throw ERROR, it would be infinite loop
		 */
		if (*res != PGRES_COMMAND_OK)
			jdbc_fdw_report_error(WARNING, res, entry->conn, true,
									"ABORT TRANSACTION");
		else
		{
			jq_clear(res);

			/*
			 * As above, make sure to clear any prepared stmts
			 */
			if (entry->have_prep_stmt && entry->have_error)
			{
				res = jq_exec(entry->conn, "DEALLOCATE ALL");
				jq_clear(res);
			}
			entry->have_prep_stmt = false;
			entry->have_error = false;
		}
	}
	else
	{
		char sql[100];
		int curlevel = GetCurrentTransactionNestLevel();

		/*
		 * Assume we might have lost track of prepared statements
		 */
		entry->have_error = true;

		/* Rollback all remote subtransactions during abort */
		snprintf(sql, sizeof(sql),
				 "ROLLBACK TO SAVEPOINT s%d; RELEASE SAVEPOINT s%d",
				 curlevel, curlevel);
		res = jq_exec(entry->conn, sql);
		if (*res != PGRES_COMMAND_OK)
			jdbc_fdw_report_error(WARNING, res, entry->conn, true, sql);
		else
			jq_clear(res);
	}
}

/*
 * jdbcfdw_subxact_callback --- cleanup at subtransaction end.
 */
static void
jdbcfdw_subxact_callback(SubXactEvent event, SubTransactionId mySubid,
						 SubTransactionId parentSubid, void *arg)
{
	HASH_SEQ_STATUS scan;
	ConnCacheEntry *entry;
	int			curlevel;

	/* Nothing to do at subxact start, nor after commit. */
	if (!(event == SUBXACT_EVENT_PRE_COMMIT_SUB ||
		  event == SUBXACT_EVENT_ABORT_SUB))
		return;

	/* Quick exit if no connections were touched in this transaction. */
	if (!xact_got_connection)
		return;

	/*
	 * Scan all connection cache entries to find open remote subtransactions
	 * of the current level, and close them.
	 */
	curlevel = GetCurrentTransactionNestLevel();
	hash_seq_init(&scan, ConnectionHash);
	while ((entry = (ConnCacheEntry *) hash_seq_search(&scan)))
	{
		char		sql[100];

		/*
		 * We only care about connections with open remote subtransactions of
		 * the current level.
		 */
		if (entry->conn == NULL || entry->xact_depth < curlevel)
			continue;

		if (entry->xact_depth > curlevel)
			elog(ERROR, "missed cleaning up remote subtransaction at level %d",
				 entry->xact_depth);

		if (event == SUBXACT_EVENT_PRE_COMMIT_SUB)
		{
			/*
			 * Commit all remote subtransactions during pre-commit
			 */
			snprintf(sql, sizeof(sql), "RELEASE SAVEPOINT s%d", curlevel);
			jdbc_do_sql_command(entry->conn, sql);
		}
		else
		{
			jdbcfdw_abort_cleanup(entry, false);
		}

		/* OK, we're outta that level of subtransaction */
		jdbcfdw_reset_xact_state(entry, false);
	}
}

/*
 * jdbcfdw_reset_xact_state --- Reset state to show we're out of a (sub)transaction
 */
static void
jdbcfdw_reset_xact_state(ConnCacheEntry *entry, bool toplevel)
{
	if (toplevel)
	{
		entry->xact_depth = 0;

		/*
		 * If the connection isn't in a good idle state, discard it to
		 * recover. Next GetConnection will open a new connection.
		 */
		if (jq_status(entry->conn) != CONNECTION_OK ||
			jq_transaction_status(entry->conn) != PQTRANS_IDLE)
		{
			elog(DEBUG3, "discarding connection %p", entry->conn);
			jq_finish(entry->conn);
			entry->conn = NULL;
		}
	}
	else
	{
		entry->xact_depth--;
	}
}
