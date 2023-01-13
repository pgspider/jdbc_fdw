/*-------------------------------------------------------------------------
 *
 * option.c
 *        FDW option handling for jdbc_fdw
 *
 * Portions Copyright (c) 2012-2014, PostgreSQL Global Development Group
 *
 * Portions Copyright (c) 2021, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *        contrib/jdbc_fdw/option.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "jdbc_fdw.h"

#include "access/reloptions.h"
#include "catalog/pg_foreign_server.h"
#include "catalog/pg_foreign_table.h"
#include "catalog/pg_user_mapping.h"
#include "commands/defrem.h"
#include "utils/guc.h"


/*
 * Describes the valid options for objects that this wrapper uses.
 */
typedef struct JdbcFdwOption
{
	const char *keyword;
	Oid			optcontext;		/* OID of catalog in which option may appear */
	bool		is_libpq_opt;	/* true if it's used in libpq */
}			JdbcFdwOption;

/*
 * Valid options for jdbc_fdw. Allocated and filled in init_jdbcfdw_options.
 */
static JdbcFdwOption * jdbc_fdw_options;

/*
 * Valid options for libpq. Allocated and filled in init_jdbcfdw_options.
 */
static PQconninfoOption *libpq_options;

/*
 * Helper functions
 */
static void init_jdbcfdw_options(void);
static bool jdbc_is_valid_option(const char *keyword, Oid context);
static bool jdbc_is_libpq_option(const char *keyword);


/*
 * Validate the generic options given to a FOREIGN DATA WRAPPER, SERVER, USER
 * MAPPING or FOREIGN TABLE that uses jdbc_fdw.
 *
 * Raise an ERROR if the option or its value is considered invalid.
 */
PG_FUNCTION_INFO_V1(jdbc_fdw_validator);

Datum
jdbc_fdw_validator(PG_FUNCTION_ARGS)
{
	List	   *options_list = untransformRelOptions(PG_GETARG_DATUM(0));
	Oid			catalog = PG_GETARG_OID(1);
	ListCell   *cell;

	/* Build our options lists if we didn't yet. */
	init_jdbcfdw_options();

	/*
	 * Check that only options supported by jdbc_fdw, and allowed for the
	 * current object type, are given.
	 */
	foreach(cell, options_list)
	{
		DefElem    *def = (DefElem *) lfirst(cell);

		if (!jdbc_is_valid_option(def->defname, catalog))
		{
			/*
			 * Unknown option specified, complain about it. Provide a hint
			 * with list of valid options for the object.
			 */
			JdbcFdwOption *opt;
			StringInfoData buf;

			initStringInfo(&buf);
			for (opt = jdbc_fdw_options; opt->keyword; opt++)
			{
				if (catalog == opt->optcontext)
					appendStringInfo(&buf, "%s%s", (buf.len > 0) ? ", " : "",
									 opt->keyword);
			}

			ereport(ERROR,
					(errcode(ERRCODE_FDW_INVALID_OPTION_NAME),
					 errmsg("invalid option \"%s\"", def->defname),
					 buf.len > 0 ?
					 errhint("Valid options in this context are: %s", buf.data) :
					 errhint("There are no valid options in this context.")));
		}

		/*
		 * Validate option value, when we can do so without any context.
		 */
		if (strcmp(def->defname, "use_remote_estimate") == 0 ||
			strcmp(def->defname, "updatable") == 0)
		{
			/* these accept only boolean values */
			(void) defGetBoolean(def);
		}
		else if (strcmp(def->defname, "fdw_startup_cost") == 0 ||
				 strcmp(def->defname, "fdw_tuple_cost") == 0)
		{
			/*
			 * These must have a floating point value greater than or equal to
			 * zero.
			 */
			char	   *value;
			double		real_val;
			bool		is_parsed;

			value = defGetString(def);
			is_parsed = parse_real(value, &real_val, 0, NULL);

			if (!is_parsed)
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg("invalid value for floating point option \"%s\": %s",
								def->defname, value)));

			if (real_val < 0)
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg("\"%s\" must be a floating point value greater than or equal to zero",
								def->defname)));
		}
	}

	PG_RETURN_VOID();
}

/*
 * Initialize option lists.
 */
static void
init_jdbcfdw_options(void)
{
	int			num_libpq_opts;
	PQconninfoOption *lopt;
	JdbcFdwOption *popt;

	/* non-libpq FDW-specific FDW options */
	static const JdbcFdwOption non_libpq_options[] = {
		/* Connection options */
		{"drivername", ForeignServerRelationId, false},
		{"url", ForeignServerRelationId, false},
		{"querytimeout", ForeignServerRelationId, false},
		{"jarfile", ForeignServerRelationId, false},
		{"maxheapsize", ForeignServerRelationId, false},
		{"username", UserMappingRelationId, false},
		{"password", UserMappingRelationId, false},
		/* use_remote_estimate is available on both server and table */
		{"use_remote_estimate", ForeignServerRelationId, false},
		{"use_remote_estimate", ForeignTableRelationId, false},
		/* cost factors */
		{"fdw_startup_cost", ForeignServerRelationId, false},
		{"fdw_tuple_cost", ForeignServerRelationId, false},
		/* updatable is available on both server and table */
		{"updatable", ForeignServerRelationId, false},
		{"updatable", ForeignTableRelationId, false},
		{"schema_name", ForeignTableRelationId, false},
		{"table_name", ForeignTableRelationId, false},
		{"key", AttributeRelationId, false},
		{"column_name", AttributeRelationId, false},
		{"use_remote_estimate", ForeignTableRelationId, false},
		{NULL, InvalidOid, false}
	};

	/* Prevent redundant initialization. */
	if (jdbc_fdw_options)
		return;

	/*
	 * Get list of valid libpq options.
	 *
	 * To avoid unnecessary work, we get the list once and use it throughout
	 * the lifetime of this backend process.  We don't need to care about
	 * memory context issues, because PQconndefaults allocates with malloc.
	 */
	libpq_options = PQconndefaults();
	if (!libpq_options)			/* assume reason for failure is OOM */
		ereport(ERROR,
				(errcode(ERRCODE_FDW_OUT_OF_MEMORY),
				 errmsg("out of memory"),
				 errdetail("could not get libpq's default connection options")));

	/* Count how many libpq options are available. */
	num_libpq_opts = 0;
	for (lopt = libpq_options; lopt->keyword; lopt++)
		num_libpq_opts++;

	/*
	 * Construct an array which consists of all valid options for jdbc_fdw, by
	 * appending FDW-specific options to libpq options.
	 *
	 * We use plain malloc here to allocate jdbc_fdw_options because it lives
	 * as long as the backend process does.  Besides, keeping libpq_options in
	 * memory allows us to avoid copying every keyword string.
	 */
	jdbc_fdw_options = (JdbcFdwOption *)
		malloc(sizeof(JdbcFdwOption) * num_libpq_opts +
			   sizeof(non_libpq_options));
	if (jdbc_fdw_options == NULL)
		ereport(ERROR,
				(errcode(ERRCODE_FDW_OUT_OF_MEMORY),
				 errmsg("out of memory")));

	popt = jdbc_fdw_options;
	for (lopt = libpq_options; lopt->keyword; lopt++)
	{
		/*
		 * Hide debug options, as well as settings we override internally.
		 */
		if (strchr(lopt->dispchar, 'D') ||
			strcmp(lopt->keyword, "fallback_application_name") == 0 ||
			strcmp(lopt->keyword, "client_encoding") == 0)
			continue;

		/* We don't have to copy keyword string, as described above. */
		popt->keyword = lopt->keyword;

		/*
		 * "user" and any secret options are allowed only on user mappings.
		 * Everything else is a server option.
		 */
		if (strcmp(lopt->keyword, "user") == 0 || strchr(lopt->dispchar, '*'))
			popt->optcontext = UserMappingRelationId;
		else
			popt->optcontext = ForeignServerRelationId;
		popt->is_libpq_opt = true;

		popt++;
	}

	/* Append FDW-specific options and dummy terminator. */
	memcpy(popt, non_libpq_options, sizeof(non_libpq_options));
}

/*
 * Check whether the given option is one of the valid jdbc_fdw options.
 * context is the Oid of the catalog holding the object the option is for.
 */
static bool
jdbc_is_valid_option(const char *keyword, Oid context)
{
	JdbcFdwOption *opt;

	Assert(jdbc_fdw_options);	/* must be initialized already */

	for (opt = jdbc_fdw_options; opt->keyword; opt++)
	{
		if (context == opt->optcontext && strcmp(opt->keyword, keyword) == 0)
			return true;
	}

	return false;
}

/*
 * Check whether the given option is one of the valid libpq options.
 */
static bool
jdbc_is_libpq_option(const char *keyword)
{
	JdbcFdwOption *opt;

	Assert(jdbc_fdw_options);	/* must be initialized already */

	for (opt = jdbc_fdw_options; opt->keyword; opt++)
	{
		if (opt->is_libpq_opt && strcmp(opt->keyword, keyword) == 0)
			return true;
	}

	return false;
}

/*
 * Generate key-value arrays which include only libpq options from the given
 * list (which can contain any kind of options).  Caller must have allocated
 * large-enough arrays.  Returns number of options found.
 */
int
jdbc_extract_connection_options(List *defelems, const char **keywords,
								const char **values)
{
	ListCell   *lc;
	int			i;

	/* Build our options lists if we didn't yet. */
	init_jdbcfdw_options();

	i = 0;
	foreach(lc, defelems)
	{
		DefElem    *d = (DefElem *) lfirst(lc);

		if (jdbc_is_libpq_option(d->defname))
		{
			keywords[i] = d->defname;
			values[i] = defGetString(d);
			i++;
		}
	}
	return i;
}
