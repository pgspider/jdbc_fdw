/*-------------------------------------------------------------------------
 *
 * jdbc_fdw.c
 *        Foreign-data wrapper for remote PostgreSQL servers
 *
 * Portions Copyright (c) 2012-2014, PostgreSQL Global Development Group
 *
 * Portions Copyright (c) 2021, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *        contrib/jdbc_fdw/jdbc_fdw.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "jdbc_fdw.h"

#include "access/htup_details.h"
#include "access/sysattr.h"
#include "commands/defrem.h"
#include "commands/explain.h"
#include "commands/vacuum.h"
#include "foreign/fdwapi.h"
#include "funcapi.h"
#include "miscadmin.h"
#include "nodes/makefuncs.h"
#include "nodes/nodeFuncs.h"
#include "optimizer/cost.h"
#include "optimizer/appendinfo.h"
#include "optimizer/pathnode.h"
#include "optimizer/paths.h"
#include "optimizer/planmain.h"
#include "optimizer/planner.h"
#include "optimizer/prep.h"
#include "optimizer/restrictinfo.h"
#include "optimizer/tlist.h"
#include "parser/parsetree.h"
#include "utils/builtins.h"
#include "utils/guc.h"
#include "utils/lsyscache.h"
#include "utils/memutils.h"
#include "utils/elog.h"
#include "executor/spi.h"


#include "storage/ipc.h"
#include "catalog/pg_foreign_server.h"
#include "catalog/pg_foreign_table.h"
#include "catalog/pg_user_mapping.h"
#define Str(arg) #arg
#define StrValue(arg) Str(arg)
#define STR_PKGLIBDIR StrValue(PKG_LIB_DIR)

#define IS_KEY_COLUMN(A)	((strcmp(A->defname, "key") == 0) && \
							 (strcmp(strVal(A->arg), "true") == 0))

PG_MODULE_MAGIC;

/* Default CPU cost to start up a foreign query. */
#define DEFAULT_FDW_STARTUP_COST    100.0

/* Default CPU cost to process 1 row (above and beyond cpu_tuple_cost). */
#define DEFAULT_FDW_TUPLE_COST      0.01


/*
 * Indexes of FDW-private information stored in fdw_private lists.
 *
 * We store various information in ForeignScan.fdw_private to pass it from
 * planner to executor.  Currently we store:
 *
 * 1) SELECT statement text to be sent to the remote server 2) Integer list
 * of attribute numbers retrieved by the SELECT
 *
 * These items are indexed with the enum FdwScanPrivateIndex, so an item can
 * be fetched with list_nth().  For example, to get the SELECT statement: sql
 * = strVal(list_nth(fdw_private, FdwScanPrivateSelectSql));
 */
enum FdwScanPrivateIndex
{
	/* SQL statement to execute remotely (as a String node) */
	FdwScanPrivateSelectSql,
	/* Integer list of attribute numbers retrieved by the SELECT */
	FdwScanPrivateRetrievedAttrs
};

/*
 * This enum describes what's kept in the fdw_private list for a ForeignPath.
 * We store:
 *
 * 1) Boolean flag showing if the remote query has the final sort 2) Boolean
 * flag showing if the remote query has the LIMIT clause
 */
enum FdwPathPrivateIndex
{
	/* has-final-sort flag (as a Boolean node) */
	FdwPathPrivateHasFinalSort,
	/* has-limit flag (as a Boolean node) */
	FdwPathPrivateHasLimit
};


/*
 * Similarly, this enum describes what's kept in the fdw_private list for a
 * ModifyTable node referencing a jdbc_fdw foreign table.  We store:
 *
 * 1) INSERT/UPDATE/DELETE statement text to be sent to the remote server 2)
 * Integer list of target attribute numbers for INSERT/UPDATE (NIL for a
 * DELETE) 3) Boolean flag showing if the remote query has a RETURNING clause
 * 4) Integer list of attribute numbers retrieved by RETURNING, if any
 */
enum FdwModifyPrivateIndex
{
	/* SQL statement to execute remotely (as a String node) */
	FdwModifyPrivateUpdateSql,
	/* Integer list of target attribute numbers for INSERT/UPDATE */
	FdwModifyPrivateTargetAttnums,
	/* has-returning flag (as a Boolean node) */
	FdwModifyPrivateHasReturning,
	/* Integer list of attribute numbers retrieved by RETURNING */
	FdwModifyPrivateRetrievedAttrs
};

/*
 * Execution state of a foreign scan using jdbc_fdw.
 */
typedef struct jdbcFdwScanState
{
	Relation	rel;			/* relcache entry for the foreign table */
	AttInMetadata *attinmeta;	/* attribute datatype conversion metadata */

	TupleDesc	tupdesc;		/* tuple descriptor of scan */

	/* extracted fdw_private data */
	char	   *query;			/* text of SELECT command */
	List	   *retrieved_attrs;	/* list of retrieved attribute numbers */

	/* for remote query execution */
	Jconn	   *conn;			/* connection for the scan */
	unsigned int cursor_number; /* quasi-unique ID for my cursor */
	bool		cursor_exists;	/* have we created the cursor? */
	int			numParams;		/* number of parameters passed to query */
	FmgrInfo   *param_flinfo;	/* output conversion functions for them */
	List	   *param_exprs;	/* executable expressions for param values */
	const char **param_values;	/* textual values of query parameters */

	/* for storing result tuples */
	HeapTuple  *tuples;			/* array of currently-retrieved tuples */
	int			num_tuples;		/* # of tuples in array */
	int			next_tuple;		/* index of next one to return */

	/*
	 * batch-level state, for optimizing rewinds and avoiding useless fetch
	 */
	int			fetch_ct_2;		/* Min(# of fetches done, 2) */
	bool		eof_reached;	/* true if last fetch reached EOF */

	/* working memory contexts */
	MemoryContext batch_cxt;	/* context holding current batch of tuples */
	MemoryContext temp_cxt;		/* context for per-tuple temporary data */

	/* for the execution of the result from java side */
	int			resultSetID;
}			jdbcFdwScanState;

/*
 * Execution state of a foreign insert/update/delete operation.
 */
typedef struct jdbcFdwModifyState
{
	Relation	rel;			/* relcache entry for the foreign table */
	AttInMetadata *attinmeta;	/* attribute datatype conversion metadata */

	/* for remote query execution */
	Jconn	   *conn;			/* connection for the scan */
	bool		is_prepared;	/* name of prepared statement, if created */


	/* extracted fdw_private data */
	char	   *query;			/* text of INSERT/UPDATE/DELETE command */
	List	   *target_attrs;	/* list of target attribute numbers */
	bool		has_returning;	/* is there a RETURNING clause? */
	List	   *retrieved_attrs;	/* attr numbers retrieved by RETURNING */

	/* info about parameters for prepared statement */
	AttrNumber *junk_idx;		/* the attrnumber of the junk column for
								 * UPDATE and DELETE */
	int			p_nums;			/* number of parameters to transmit */
	FmgrInfo   *p_flinfo;		/* output conversion functions for them */

	/* working memory context */
	MemoryContext temp_cxt;		/* context for per-tuple temporary data */

	/* for the execution of the result from java side */
	int			resultSetID;

}			jdbcFdwModifyState;

/*
 * Workspace for analyzing a foreign table.
 */
typedef struct jdbcFdwAnalyzeState
{
	Relation	rel;			/* relcache entry for the foreign table */
	AttInMetadata *attinmeta;	/* attribute datatype conversion metadata */
	List	   *retrieved_attrs;	/* attr numbers retrieved by query */

	/* collected sample rows */
	HeapTuple  *rows;			/* array of size targrows */
	int			targrows;		/* target # of sample rows */
	int			numrows;		/* # of sample rows collected */

	/* for random sampling */
	double		samplerows;		/* # of rows fetched */
	double		rowstoskip;		/* # of rows to skip before next sample */
	double		rstate;			/* random state */

	/* working memory contexts */
	MemoryContext anl_cxt;		/* context for per-analyze lifespan data */
	MemoryContext temp_cxt;		/* context for per-tuple temporary data */
}			jdbcFdwAnalyzeState;

/*
 * Identify the attribute where data conversion fails.
 */
typedef struct ConversionLocation
{
	Relation	rel;			/* foreign table's relcache entry */
	AttrNumber	cur_attno;		/* attribute number being processed, or 0 */
} ConversionLocation;

/*
 * SQL functions
 */
PG_FUNCTION_INFO_V1(jdbc_fdw_handler);
PG_FUNCTION_INFO_V1(jdbc_fdw_version);
PG_FUNCTION_INFO_V1(jdbc_exec);
/*
 * FDW callback routines
 */
static void jdbcGetForeignRelSize(PlannerInfo *root,
								  RelOptInfo *baserel,
								  Oid foreigntableid);
static void jdbcGetForeignPaths(PlannerInfo *root,
								RelOptInfo *baserel,
								Oid foreigntableid);
static ForeignScan *jdbcGetForeignPlan(PlannerInfo *root,
									   RelOptInfo *baserel,
									   Oid foreigntableid,
									   ForeignPath *best_path,
									   List *tlist,
									   List *scan_clauses,
									   Plan *outer_plan
);
static void jdbcBeginForeignScan(ForeignScanState *node, int eflags);
static TupleTableSlot *jdbcIterateForeignScan(ForeignScanState *node);
static void jdbcReScanForeignScan(ForeignScanState *node);
static void jdbcEndForeignScan(ForeignScanState *node);
static void jdbcAddForeignUpdateTargets(
#if PG_VERSION_NUM >= 140000
										PlannerInfo *root,
										Index rtindex,
#else
										Query *parsetree,
#endif
										RangeTblEntry *target_rte,
										Relation target_relation);
static List *jdbcPlanForeignModify(PlannerInfo *root,
								   ModifyTable *plan,
								   Index resultRelation,
								   int subplan_index);
static void jdbcBeginForeignModify(ModifyTableState *mtstate,
								   ResultRelInfo *resultRelInfo,
								   List *fdw_private,
								   int subplan_index,
								   int eflags);
static TupleTableSlot *jdbcExecForeignInsert(EState *estate,
											 ResultRelInfo *resultRelInfo,
											 TupleTableSlot *slot,
											 TupleTableSlot *planSlot);
static TupleTableSlot *jdbcExecForeignUpdate(EState *estate,
											 ResultRelInfo *resultRelInfo,
											 TupleTableSlot *slot,
											 TupleTableSlot *planSlot);
static TupleTableSlot *jdbcExecForeignDelete(EState *estate,
											 ResultRelInfo *resultRelInfo,
											 TupleTableSlot *slot,
											 TupleTableSlot *planSlot);
static void jdbcEndForeignModify(EState *estate,
								 ResultRelInfo *resultRelInfo);
static int	jdbcIsForeignRelUpdatable(Relation rel);
static void jdbcExplainForeignScan(ForeignScanState *node,
								   ExplainState *es);
static void jdbcExplainForeignModify(ModifyTableState *mtstate,
									 ResultRelInfo *rinfo,
									 List *fdw_private,
									 int subplan_index,
									 ExplainState *es);
static bool jdbcAnalyzeForeignTable(Relation relation,
									AcquireSampleRowsFunc *func,
									BlockNumber *totalpages);
static List *jdbcImportForeignSchema(ImportForeignSchemaStmt *stmt,
									 Oid serverOid);
static void jdbcGetForeignUpperPaths(PlannerInfo *root,
									 UpperRelationKind stage,
									 RelOptInfo *input_rel,
									 RelOptInfo *output_rel
#if (PG_VERSION_NUM >= 110000)
									 ,void *extra
#endif
);

/*
 * Helper functions
 */
static void estimate_path_cost_size(PlannerInfo *root,
									RelOptInfo *baserel,
									List *join_conds,
									double *p_rows, int *p_width,
									Cost *p_startup_cost,
									Cost *p_total_cost,
									char *q_char);
static void get_remote_estimate(const char *sql,
								Jconn * conn,
								double *rows,
								int *width,
								Cost *startup_cost,
								Cost *total_cost);
static void jdbc_close_cursor(Jconn * conn, unsigned int cursor_number);
static void jdbc_prepare_foreign_modify(jdbcFdwModifyState * fmstate);
static bool jdbc_foreign_grouping_ok(PlannerInfo *root, RelOptInfo *grouped_rel);
static void jdbc_add_foreign_grouping_paths(PlannerInfo *root,
											RelOptInfo *input_rel,
											RelOptInfo *grouped_rel
#if (PG_VERSION_NUM >= 110000)
											,GroupPathExtraData *extra
#endif
);
static void jdbc_add_foreign_final_paths(PlannerInfo *root, RelOptInfo *input_rel,
										 RelOptInfo *final_rel
#if (PG_VERSION_NUM >= 120000)
										 ,FinalPathExtraData *extra
#endif
);

static void jdbc_execute_commands(List *cmd_list);

static void jdbc_bind_junk_column_value(jdbcFdwModifyState * fmstate,
										TupleTableSlot *slot,
										TupleTableSlot *planSlot,
										Oid foreignTableId,
										int bindnum);

static void prepTuplestoreResult(FunctionCallInfo fcinfo);
static Jconn *jdbc_get_conn_by_server_name(char *servername);
static TupleDesc jdbc_create_descriptor(Jconn *conn, int *resultSetID);
static Oid jdbc_convert_type_name(char *typname);

/*
 * Foreign-data wrapper handler function: return a struct with pointers to my
 * callback routines.
 */
Datum
jdbc_fdw_handler(PG_FUNCTION_ARGS)
{
	FdwRoutine *routine = makeNode(FdwRoutine);

	/* Functions for scanning foreign tables */
	routine->GetForeignRelSize = jdbcGetForeignRelSize;
	routine->GetForeignPaths = jdbcGetForeignPaths;
	routine->GetForeignPlan = jdbcGetForeignPlan;
	routine->BeginForeignScan = jdbcBeginForeignScan;
	routine->IterateForeignScan = jdbcIterateForeignScan;
	routine->ReScanForeignScan = jdbcReScanForeignScan;
	routine->EndForeignScan = jdbcEndForeignScan;

	/* Functions for updating foreign tables */
	routine->AddForeignUpdateTargets = jdbcAddForeignUpdateTargets;
	routine->PlanForeignModify = jdbcPlanForeignModify;
	routine->BeginForeignModify = jdbcBeginForeignModify;
	routine->ExecForeignInsert = jdbcExecForeignInsert;
	routine->ExecForeignUpdate = jdbcExecForeignUpdate;
	routine->ExecForeignDelete = jdbcExecForeignDelete;
	routine->EndForeignModify = jdbcEndForeignModify;
	routine->IsForeignRelUpdatable = jdbcIsForeignRelUpdatable;

	/* Support functions for EXPLAIN */
	routine->ExplainForeignScan = jdbcExplainForeignScan;
	routine->ExplainForeignModify = jdbcExplainForeignModify;

	/* Support functions for ANALYZE */
	routine->AnalyzeForeignTable = jdbcAnalyzeForeignTable;

	/* support for IMPORT FOREIGN SCHEMA */
	routine->ImportForeignSchema = jdbcImportForeignSchema;

	/* Support functions for upper relation push-down */
	routine->GetForeignUpperPaths = jdbcGetForeignUpperPaths;
	PG_RETURN_POINTER(routine);
}

Datum
jdbc_fdw_version(PG_FUNCTION_ARGS)
{
	PG_RETURN_INT32(CODE_VERSION);
}

Datum
jdbc_exec(PG_FUNCTION_ARGS)
{
	Jconn	*conn		= NULL;
	char	*servername	= NULL;
	char	*sql		= NULL;

	Jresult *volatile res	= NULL;
	int resultSetID 		= 0;

	TupleDesc	tupleDescriptor;

	PG_TRY();
	{
		if (PG_NARGS() == 2)
		{
			servername = text_to_cstring(PG_GETARG_TEXT_PP(0));
			sql = text_to_cstring(PG_GETARG_TEXT_PP(1));
			conn = jdbc_get_conn_by_server_name(servername);
		}
		else
		{
			/* shouldn't happen */
			elog(ERROR, "jdbc_fdw: wrong number of arguments");
		}

		if (!conn)
		{
			ereport(ERROR,
					(errcode(ERRCODE_CONNECTION_DOES_NOT_EXIST),
					 errmsg("jdbc_fdw: server \"%s\" not available", servername)));
		}

		prepTuplestoreResult(fcinfo);

		/* Execute sql query */
		res = jq_exec_id(conn, sql, &resultSetID);

		if (*res != PGRES_COMMAND_OK)
			jdbc_fdw_report_error(ERROR, res, conn, false, sql);

		/* Create temp descriptor */
		tupleDescriptor = jdbc_create_descriptor(conn, &resultSetID);

		jq_iterate_all_row(fcinfo, conn, tupleDescriptor, resultSetID);
	}
	PG_FINALLY();
	{
		if (res)
			jq_clear(res);

		if (resultSetID != 0)
			jq_release_resultset_id(conn, resultSetID);

		tuplestore_donestoring((ReturnSetInfo *) fcinfo->resultinfo->setResult);

		if (conn)
		{
			jdbc_release_connection(conn);
			conn = NULL;
		}
	}
	PG_END_TRY();

	return (Datum) 0;
}

/*
 * Verify function caller can handle a tuplestore result, and set up for that.
 *
 * Note: if the caller returns without actually creating a tuplestore, the
 * executor will treat the function result as an empty set.
 */
static void
prepTuplestoreResult(FunctionCallInfo fcinfo)
{
	ReturnSetInfo *rsinfo = (ReturnSetInfo *) fcinfo->resultinfo;

	/* check to see if query supports us returning a tuplestore */
	if (rsinfo == NULL || !IsA(rsinfo, ReturnSetInfo))
		ereport(ERROR,
				(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
				 errmsg("set-valued function called in context that cannot accept a set")));
	if (!(rsinfo->allowedModes & SFRM_Materialize))
		ereport(ERROR,
				(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
				 errmsg("materialize mode required, but it is not allowed in this context")));

	/* let the executor know we're sending back a tuplestore */
	rsinfo->returnMode = SFRM_Materialize;

	/* caller must fill these to return a non-empty result */
	rsinfo->setResult = NULL;
	rsinfo->setDesc = NULL;
}

/*
 * jdbc_get_conn_by_server_name
 * Get connection by the given server name
 */
static Jconn *
jdbc_get_conn_by_server_name(char *servername)
{
	ForeignServer *foreign_server = NULL;
	UserMapping *user_mapping;
	Jconn *conn = NULL;

	foreign_server = GetForeignServerByName(servername, false);

	if (foreign_server)
	{
		Oid serverid = foreign_server->serverid;
		Oid userid = GetUserId();

		user_mapping = GetUserMapping(userid, serverid);
		conn = jdbc_get_connection(foreign_server, user_mapping, false);
	}

	return conn;
}

/*
 * jdbc_create_descriptor
 * Create TypleDesc from result set
 */
static TupleDesc
jdbc_create_descriptor(Jconn *conn, int *resultSetID)
{
	TupleDesc	desc;
	List	   *column_info_list;
	ListCell   *column_lc;
	int			column_num = 0;
	int			att_num = 0;

	column_info_list = jq_get_column_infos_without_key(conn, resultSetID, &column_num);

	desc = CreateTemplateTupleDesc(column_num);
	foreach(column_lc, column_info_list)
	{
		JcolumnInfo *column_info = (JcolumnInfo *) lfirst(column_lc);

		/* get oid from type name of column */
		Oid tmpOid = jdbc_convert_type_name(column_info->column_type);

		TupleDescInitEntry(desc, att_num + 1, NULL, tmpOid, -1, 0);
		att_num++;
	}

	return BlessTupleDesc(desc);
}

/*
 * Given a type name expressed as a string, look it up and return Oid
 */
static Oid
jdbc_convert_type_name(char *typname)
{
	Oid			oid;

	oid = DatumGetObjectId(DirectFunctionCall1(regtypein,
											   CStringGetDatum(typname)));

	if (!OidIsValid(oid))
		ereport(ERROR,
				(errcode(ERRCODE_UNDEFINED_OBJECT),
				 errmsg("type \"%s\" does not exist", typname)));

	return oid;
}

/*
 * jdbcGetForeignRelSize Estimate # of rows and width of the result of the
 * scan
 *
 * We should consider the effect of all baserestrictinfo clauses here, but
 * not any join clauses.
 */
static void
jdbcGetForeignRelSize(PlannerInfo *root,
					  RelOptInfo *baserel,
					  Oid foreigntableid)
{
	jdbcFdwRelationInfo *fpinfo;
	ListCell   *lc;
	RangeTblEntry *rte = planner_rt_fetch(baserel->relid, root);
	Oid			userid = rte->checkAsUser ? rte->checkAsUser : GetUserId();
	Jconn	   *conn;

	/* TODO: remove this functionality and support for remote statistics */
	ereport(DEBUG3, (errmsg("In jdbcGetForeignRelSize")));

	/*
	 * We use jdbcFdwRelationInfo to pass various information to subsequent
	 * functions.
	 */
	fpinfo = (jdbcFdwRelationInfo *) palloc0(sizeof(jdbcFdwRelationInfo));
	baserel->fdw_private = (void *) fpinfo;

	/* Base foreign tables need to be pushed down always. */
	fpinfo->pushdown_safe = true;

	/* Look up foreign-table catalog info. */
	fpinfo->table = GetForeignTable(foreigntableid);
	fpinfo->server = GetForeignServer(fpinfo->table->serverid);

	/*
	 * Extract user-settable option values.  Note that per-table setting of
	 * use_remote_estimate overrides per-server setting.
	 */
	fpinfo->use_remote_estimate = false;
	fpinfo->fdw_startup_cost = DEFAULT_FDW_STARTUP_COST;
	fpinfo->fdw_tuple_cost = DEFAULT_FDW_TUPLE_COST;

	foreach(lc, fpinfo->server->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "use_remote_estimate") == 0)
			fpinfo->use_remote_estimate = defGetBoolean(def);
		else if (strcmp(def->defname, "fdw_startup_cost") == 0)
			(void) parse_real(defGetString(def), &fpinfo->fdw_startup_cost, 0,
							  NULL);
		else if (strcmp(def->defname, "fdw_tuple_cost") == 0)
			(void) parse_real(defGetString(def), &fpinfo->fdw_tuple_cost, 0,
							  NULL);
	}
	foreach(lc, fpinfo->table->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "use_remote_estimate") == 0)
			fpinfo->use_remote_estimate = defGetBoolean(def);
	}

	/*
	 * If the table or the server is configured to use remote estimates,
	 * identify which user to do remote access as during planning.  This
	 * should match what ExecCheckRTEPerms() does.  If we fail due to lack of
	 * permissions, the query would have failed at runtime anyway. And use
	 * user idenfifier for get default indentifier quote from remote server.
	 */
	fpinfo->user = GetUserMapping(userid, fpinfo->server->serverid);
	conn = jdbc_get_connection(fpinfo->server, fpinfo->user, false);

	/*
	 * Identify which baserestrictinfo clauses can be sent to the remote
	 * server and which can't.
	 */
	jdbc_classify_conditions(root, baserel, baserel->baserestrictinfo,
							 &fpinfo->remote_conds, &fpinfo->local_conds);

	/*
	 * Identify which attributes will need to be retrieved from the remote
	 * server.  These include all attrs needed for joins or final output, plus
	 * all attrs used in the local_conds.  (Note: if we end up using a
	 * parameterized scan, it's possible that some of the join clauses will be
	 * sent to the remote and thus we wouldn't really need to retrieve the
	 * columns used in them.  Doesn't seem worth detecting that case though.)
	 */
	fpinfo->attrs_used = NULL;
#if PG_VERSION_NUM >= 90600
	pull_varattnos((Node *) baserel->reltarget->exprs, baserel->relid, &fpinfo->attrs_used);
#else
	pull_varattnos((Node *) baserel->reltargetlist, baserel->relid,
				   &fpinfo->attrs_used);
#endif
	foreach(lc, fpinfo->local_conds)
	{
		RestrictInfo *rinfo = (RestrictInfo *) lfirst(lc);

		pull_varattnos((Node *) rinfo->clause, baserel->relid,
					   &fpinfo->attrs_used);
	}

	/*
	 * Compute the selectivity and cost of the local_conds, so we don't have
	 * to do it over again for each path.  The best we can do for these
	 * conditions is to estimate selectivity on the basis of local statistics.
	 */
	fpinfo->local_conds_sel = clauselist_selectivity(root,
													 fpinfo->local_conds,
													 baserel->relid,
													 JOIN_INNER,
													 NULL);

	cost_qual_eval(&fpinfo->local_conds_cost, fpinfo->local_conds, root);

	/*
	 * If the table or the server is configured to use remote estimates,
	 * connect to the foreign server and execute EXPLAIN to estimate the
	 * number of rows selected by the restriction clauses, as well as the
	 * average row width.  Otherwise, estimate using whatever statistics we
	 * have locally, in a way similar to ordinary tables.
	 */
	if (fpinfo->use_remote_estimate)
	{
		/*
		 * Get cost/size estimates with help of remote server.  Save the
		 * values in fpinfo so we don't need to do it again to generate the
		 * basic foreign path.
		 */
		estimate_path_cost_size(root, baserel, NIL,
								&fpinfo->rows, &fpinfo->width,
								&fpinfo->startup_cost,
								&fpinfo->total_cost, conn->q_char);
	}
	else
	{
		/*
		 * If the foreign table has never been ANALYZEd, it will have relpages
		 * and reltuples equal to zero, which most likely has nothing to do
		 * with reality.  We can't do a whole lot about that if we're not
		 * allowed to consult the remote server, but we can use a hack similar
		 * to plancat.c's treatment of empty relations: use a minimum size
		 * estimate of 10 pages, and divide by the column-datatype-based width
		 * estimate to get the corresponding number of tuples.
		 */
#if PG_VERSION_NUM < 140000
		if (baserel->pages == 0 && baserel->tuples == 0)
#else
		if (baserel->tuples < 0)
#endif
		{
			baserel->pages = 10;
			baserel->tuples =
				(10 * BLCKSZ) / (baserel->reltarget->width + sizeof(HeapTupleHeaderData));
		}

		/*
		 * Estimate baserel size as best we can with local statistics.
		 */
		set_baserel_size_estimates(root, baserel);

		/* Fill in basically-bogus cost estimates for use later. */
		estimate_path_cost_size(root, baserel, NIL,
								&fpinfo->rows, &fpinfo->width,
								&fpinfo->startup_cost,
								&fpinfo->total_cost, conn->q_char);
	}
}

/*
 * jdbcGetForeignPaths Create possible scan paths for a scan on the foreign
 * table
 */
static void
jdbcGetForeignPaths(PlannerInfo *root,
					RelOptInfo *baserel,
					Oid foreigntableid)
{
	jdbcFdwRelationInfo *fpinfo = (jdbcFdwRelationInfo *) baserel->fdw_private;

	ereport(DEBUG3, (errmsg("In jdbcGetForeignPaths")));

	/*
	 * Create simplest ForeignScan path node and add it to baserel.  This path
	 * corresponds to SeqScan path of regular tables (though depending on what
	 * baserestrict conditions we were able to send to remote, there might
	 * actually be an indexscan happening there).  We already did all the work
	 * to estimate cost and size of this path.
	 */
	add_path(baserel, (Path *)
			 create_foreignscan_path(root, baserel,
#if PG_VERSION_NUM >= 90600
									 NULL,	/* default pathtarget */
#endif
									 fpinfo->rows,
									 fpinfo->startup_cost,
									 fpinfo->total_cost,
									 NIL,	/* no pathkeys */
									 baserel->lateral_relids,
									 NULL,	/* no extra plan */
									 NULL));	/* no fdw_private data */
	return;
}

/*
 * jdbcGetForeignPlan Create ForeignScan plan node which implements selected
 * best path
 */
static ForeignScan *
jdbcGetForeignPlan(PlannerInfo *root,
				   RelOptInfo *baserel,
				   Oid foreigntableid,
				   ForeignPath *best_path,
				   List *tlist,
				   List *scan_clauses,
				   Plan *outer_plan
)
{
	jdbcFdwRelationInfo *fpinfo = (jdbcFdwRelationInfo *) baserel->fdw_private;
	Index		scan_relid = baserel->relid;
	List	   *fdw_private;
	List	   *remote_conds = NIL;
	List	   *remote_exprs = NIL;
	List	   *local_exprs = NIL;
	List	   *params_list = NIL;
	List	   *retrieved_attrs;
	StringInfoData sql;
	ListCell   *lc;
	int			for_update = 0;
	List	   *fdw_scan_tlist = NIL;
	List	   *fdw_recheck_quals = NIL;
	bool		has_limit = false;
	Jconn	   *conn;

	ereport(DEBUG3, (errmsg("In jdbcGetForeignPlan")));

	/*
	 * Get FDW private data created by griddbGetForeignUpperPaths(), if any.
	 */
	if (best_path->fdw_private)
	{
#if PG_VERSION_NUM >= 150000
		has_limit = boolVal(list_nth(best_path->fdw_private, FdwPathPrivateHasLimit));
#else
		has_limit = intVal(list_nth(best_path->fdw_private, FdwPathPrivateHasLimit));
#endif
	}

	/*
	 * Separate the scan_clauses into those that can be executed remotely and
	 * those that can't.  baserestrictinfo clauses that were previously
	 * determined to be safe or unsafe by jdbc_classify_conditions are shown
	 * in fpinfo->remote_conds and fpinfo->local_conds.  Anything else in the
	 * scan_clauses list will be a join clause, which we have to check for
	 * remote-safety.
	 *
	 * Note: the join clauses we see here should be the exact same ones
	 * previously examined by jdbcGetForeignPaths.  Possibly it'd be worth
	 * passing forward the classification work done then, rather than
	 * repeating it here.
	 *
	 * This code must match "extract_actual_clauses(scan_clauses, false)"
	 * except for the additional decision about remote versus local execution.
	 * Note however that we only strip the RestrictInfo nodes from the
	 * local_exprs list, since jdbc_append_where_clause expects a list of
	 * RestrictInfos.
	 */

	if ((baserel->reloptkind == RELOPT_BASEREL ||
		 baserel->reloptkind == RELOPT_OTHER_MEMBER_REL)
		)
	{

		foreach(lc, scan_clauses)
		{
			RestrictInfo *rinfo = (RestrictInfo *) lfirst(lc);


			Assert(IsA(rinfo, RestrictInfo));

			/*
			 * Ignore any pseudoconstants, they're dealt with elsewhere
			 */
			if (rinfo->pseudoconstant)
				continue;

			if (list_member_ptr(fpinfo->remote_conds, rinfo))
			{
				remote_conds = lappend(remote_conds, rinfo);
				remote_exprs = lappend(remote_exprs, rinfo->clause);
			}
			else if (list_member_ptr(fpinfo->local_conds, rinfo))
				local_exprs = lappend(local_exprs, rinfo->clause);
			else if (jdbc_is_foreign_expr(root, baserel, rinfo->clause))
			{
				remote_conds = lappend(remote_conds, rinfo);
				remote_exprs = lappend(remote_exprs, rinfo->clause);
			}
			else
				local_exprs = lappend(local_exprs, rinfo->clause);
		}

		/*
		 * For a base-relation scan, we have to support EPQ recheck, which
		 * should recheck all the remote quals.
		 */
		fdw_recheck_quals = remote_exprs;
	}
	else
	{
		/*
		 * Join relation or upper relation - set scan_relid to 0.
		 */
		scan_relid = 0;

		/*
		 * For a join rel, baserestrictinfo is NIL and we are not considering
		 * parameterization right now, so there should be no scan_clauses for
		 * a joinrel or an upper rel either.
		 */
		Assert(!scan_clauses);

		/*
		 * Instead we get the conditions to apply from the fdw_private
		 * structure.
		 */
		remote_exprs = extract_actual_clauses(fpinfo->remote_conds, false);
		local_exprs = extract_actual_clauses(fpinfo->local_conds, false);

		/*
		 * We leave fdw_recheck_quals empty in this case, since we never need
		 * to apply EPQ recheck clauses.  In the case of a joinrel, EPQ
		 * recheck is handled elsewhere --- see GetForeignJoinPaths(). If
		 * we're planning an upperrel (ie, remote grouping or aggregation)
		 * then there's no EPQ to do because SELECT FOR UPDATE wouldn't be
		 * allowed, and indeed we *can't* put the remote clauses into
		 * fdw_recheck_quals because the unaggregated Vars won't be available
		 * locally.
		 */

		/*
		 * Build the list of columns to be fetched from the foreign server.
		 */

		fdw_scan_tlist = jdbc_build_tlist_to_deparse(baserel);

		/*
		 * Ensure that the outer plan produces a tuple whose descriptor
		 * matches our scan tuple slot.  Also, remove the local conditions
		 * from outer plan's quals, lest they be evaluated twice, once by the
		 * local plan and once by the scan.
		 */
		if (outer_plan)
		{
			ListCell   *lc;

			/*
			 * Right now, we only consider grouping and aggregation beyond
			 * joins. Queries involving aggregates or grouping do not require
			 * EPQ mechanism, hence should not have an outer plan here.
			 */
			Assert(!IS_UPPER_REL(baserel));

			/*
			 * First, update the plan's qual list if possible. In some cases
			 * the quals might be enforced below the topmost plan level, in
			 * which case we'll fail to remove them; it's not worth working
			 * harder than this.
			 */
			foreach(lc, local_exprs)
			{
				Node	   *qual = lfirst(lc);

				outer_plan->qual = list_delete(outer_plan->qual, qual);

				/*
				 * For an inner join the local conditions of foreign scan plan
				 * can be part of the joinquals as well.  (They might also be
				 * in the mergequals or hashquals, but we can't touch those
				 * without breaking the plan.)
				 */
				if (IsA(outer_plan, NestLoop) ||
					IsA(outer_plan, MergeJoin) ||
					IsA(outer_plan, HashJoin))
				{
					Join	   *join_plan = (Join *) outer_plan;

					if (join_plan->jointype == JOIN_INNER)
						join_plan->joinqual = list_delete(join_plan->joinqual,
														  qual);
				}
			}

			/*
			 * Now fix the subplan's tlist --- this might result in inserting
			 * a Result node atop the plan tree.
			 */
			outer_plan = change_plan_targetlist(outer_plan, fdw_scan_tlist,
												best_path->path.parallel_safe);
		}
	}

	conn = jdbc_get_connection(fpinfo->server, fpinfo->user, false);

	/*
	 * Build the query string to be sent for execution, and identify
	 * expressions to be sent as parameters.
	 */
	initStringInfo(&sql);

	jdbc_deparse_select_stmt_for_rel(&sql, root, baserel, remote_conds,
									 best_path->path.pathkeys,
									 &retrieved_attrs, &params_list, fdw_scan_tlist,
									 has_limit, false, NIL, NIL, conn->q_char);

	ereport(DEBUG3, (errmsg("SQL: %s", sql.data)));

	/*
	 * Add FOR UPDATE/SHARE if appropriate.  We apply locking during the
	 * initial row fetch, rather than later on as is done for local tables.
	 * The extra roundtrips involved in trying to duplicate the local
	 * semantics exactly don't seem worthwhile (see also comments for
	 * RowMarkType).
	 *
	 * Note: because we actually run the query as a cursor, this assumes that
	 * DECLARE CURSOR ... FOR UPDATE is supported, which it isn't before 8.3.
	 */
	if (baserel->relid == root->parse->resultRelation &&
		(root->parse->commandType == CMD_UPDATE ||
		 root->parse->commandType == CMD_DELETE))
	{
		/* Relation is UPDATE/DELETE target, so use FOR UPDATE */
		for_update = 1;
	}
	else
	{
		RowMarkClause *rc = get_parse_rowmark(root->parse, baserel->relid);

		if (rc)
		{
			/*
			 * Relation is specified as a FOR UPDATE/SHARE target, so handle
			 * that.
			 *
			 * For now, just ignore any [NO] KEY specification, since (a) it's
			 * not clear what that means for a remote table that we don't have
			 * complete information about, and (b) it wouldn't work anyway on
			 * older remote servers.  Likewise, we don't worry about NOWAIT.
			 */
			switch (rc->strength)
			{
				case LCS_FORKEYSHARE:
				case LCS_FORSHARE:
				case LCS_FORNOKEYUPDATE:
				case LCS_FORUPDATE:
				case LCS_NONE:
					break;
			}
		}
	}

	/*
	 * Build the fdw_private list that will be available to the executor.
	 * Items in the list must match enum FdwScanPrivateIndex, above.
	 */
	fdw_private = list_make3(makeString(sql.data), retrieved_attrs, makeInteger(for_update));

	/*
	 * Create the ForeignScan node from target list, local filtering
	 * expressions, remote parameter expressions, and FDW private information.
	 *
	 * Note that the remote parameter expressions are stored in the fdw_exprs
	 * field of the finished plan node; we can't keep them in private state
	 * because then they wouldn't be subject to later planner processing.
	 */
	return make_foreignscan(tlist,
							local_exprs,
							scan_relid,
							params_list,
							fdw_private,
							fdw_scan_tlist,
							fdw_recheck_quals,
							outer_plan
		);
}

/*
 * Construct a tuple descriptor for the scan tuples handled by a foreign
 * join.
 */
static TupleDesc
get_tupdesc_for_join_scan_tuples(ForeignScanState *node)
{
	ForeignScan *fsplan = (ForeignScan *) node->ss.ps.plan;
	EState	   *estate = node->ss.ps.state;
	TupleDesc	tupdesc;

	/*
	 * The core code has already set up a scan tuple slot based on
	 * fsplan->fdw_scan_tlist, and this slot's tupdesc is mostly good enough,
	 * but there's one case where it isn't.  If we have any whole-row row
	 * identifier Vars, they may have vartype RECORD, and we need to replace
	 * that with the associated table's actual composite type.  This ensures
	 * that when we read those ROW() expression values from the remote server,
	 * we can convert them to a composite type the local server knows.
	 */
	tupdesc = CreateTupleDescCopy(node->ss.ss_ScanTupleSlot->tts_tupleDescriptor);
	for (int i = 0; i < tupdesc->natts; i++)
	{
		Form_pg_attribute att = TupleDescAttr(tupdesc, i);
		Var		   *var;
		RangeTblEntry *rte;
		Oid			reltype;

		/* Nothing to do if it's not a generic RECORD attribute */
		if (att->atttypid != RECORDOID || att->atttypmod >= 0)
			continue;

		/*
		 * If we can't identify the referenced table, do nothing. This'll
		 * likely lead to failure later, but perhaps we can muddle through.
		 */
		var = (Var *) list_nth_node(TargetEntry, fsplan->fdw_scan_tlist,
									i)->expr;
		if (!IsA(var, Var) || var->varattno != 0)
			continue;
		rte = list_nth(estate->es_range_table, var->varno - 1);
		if (rte->rtekind != RTE_RELATION)
			continue;
		reltype = get_rel_type_id(rte->relid);
		if (!OidIsValid(reltype))
			continue;
		att->atttypid = reltype;
		/* shouldn't need to change anything else */
	}
	return tupdesc;
}

/*
 * jdbcBeginForeignScan Initiate an executor scan of a foreign JDBC SQL
 * table.
 */
static void
jdbcBeginForeignScan(ForeignScanState *node, int eflags)
{
	ForeignScan *fsplan = (ForeignScan *) node->ss.ps.plan;
	EState	   *estate = node->ss.ps.state;
	jdbcFdwScanState *fsstate;
	RangeTblEntry *rte;
	Oid			userid;
	ForeignTable *table;
	ForeignServer *server;
	UserMapping *user;
	int			numParams;
	int			i;
	ListCell   *lc;
	int			rtindex;

	ereport(DEBUG3, (errmsg("In jdbcBeginForeignScan")));

	/*
	 * Do nothing in EXPLAIN (no ANALYZE) case.  node->fdw_state stays NULL.
	 */
	if (eflags & EXEC_FLAG_EXPLAIN_ONLY)
		return;

	/*
	 * We'll save private state in node->fdw_state.
	 */
	fsstate = (jdbcFdwScanState *) palloc0(sizeof(jdbcFdwScanState));
	node->fdw_state = (void *) fsstate;

	/*
	 * Identify which user to do the remote access as.  This should match what
	 * ExecCheckRTEPerms() does.
	 */
	if (fsplan->scan.scanrelid > 0)
		rtindex = fsplan->scan.scanrelid;
	else
		rtindex = bms_next_member(fsplan->fs_relids, -1);
	rte = rt_fetch(rtindex, estate->es_range_table);
	userid = rte->checkAsUser ? rte->checkAsUser : GetUserId();

	/* Get info about foreign table. */
	fsstate->rel = node->ss.ss_currentRelation;

	/*
	 * table->options contains the query and/or table specified for the
	 * foreign table
	 */
	table = GetForeignTable(rte->relid);

	/*
	 * server-options contains drivername, url, querytimeout, jarfile and
	 * maxheapsize
	 */
	server = GetForeignServer(table->serverid);
	/* user->options contain username and password of the remote user */
	user = GetUserMapping(userid, server->serverid);

	/*
	 * Get connection to the foreign server.  Connection manager will
	 * establish new connection if necessary.
	 */
	fsstate->conn = jdbc_get_connection(server, user, false);

	/* Assign a unique ID for my cursor */
	fsstate->cursor_number = jdbc_get_cursor_number(fsstate->conn);
	fsstate->cursor_exists = false;

	/* Get private info created by planner functions. */
	fsstate->query = strVal(list_nth(fsplan->fdw_private,
									 FdwScanPrivateSelectSql));
	fsstate->retrieved_attrs = (List *) list_nth(fsplan->fdw_private,
												 FdwScanPrivateRetrievedAttrs);

	/*
	 * Create contexts for batches of tuples and per-tuple temp workspace.
	 */
#if PG_VERSION_NUM >= 110000
	fsstate->batch_cxt = AllocSetContextCreate(estate->es_query_cxt,
											   "jdbc_fdw tuple data",
											   ALLOCSET_DEFAULT_SIZES);
	fsstate->temp_cxt = AllocSetContextCreate(estate->es_query_cxt,
											  "jdbc_fdw temporary data",
											  ALLOCSET_DEFAULT_SIZES);
#else
	fsstate->batch_cxt = AllocSetContextCreate(estate->es_query_cxt,
											   "jdbc_fdw tuple data",
											   ALLOCSET_DEFAULT_MINSIZE,
											   ALLOCSET_DEFAULT_INITSIZE,
											   ALLOCSET_DEFAULT_MAXSIZE);
	fsstate->temp_cxt = AllocSetContextCreate(estate->es_query_cxt,
											  "jdbc_fdw temporary data",
											  ALLOCSET_SMALL_MINSIZE,
											  ALLOCSET_SMALL_INITSIZE,
											  ALLOCSET_SMALL_MAXSIZE);
#endif

	/*
	 * Get info we'll need for converting data fetched from the foreign server
	 * into local representation and error reporting during that process.
	 */
	if (fsplan->scan.scanrelid > 0)
	{
		fsstate->rel = node->ss.ss_currentRelation;
		fsstate->tupdesc = RelationGetDescr(fsstate->rel);
	}
	else
	{
		fsstate->rel = NULL;
		fsstate->tupdesc = get_tupdesc_for_join_scan_tuples(node);
	}

	fsstate->attinmeta = TupleDescGetAttInMetadata(fsstate->tupdesc);

	/* Prepare for output conversion of parameters used in remote query. */
	numParams = list_length(fsplan->fdw_exprs);
	fsstate->numParams = numParams;
	fsstate->param_flinfo = (FmgrInfo *) palloc0(sizeof(FmgrInfo) * numParams);

	i = 0;
	foreach(lc, fsplan->fdw_exprs)
	{
		Node	   *param_expr = (Node *) lfirst(lc);
		Oid			typefnoid;
		bool		isvarlena;

		getTypeOutputInfo(exprType(param_expr), &typefnoid, &isvarlena);
		fmgr_info(typefnoid, &fsstate->param_flinfo[i]);
		i++;
	}

	/*
	 * Prepare remote-parameter expressions for evaluation.  (Note: in
	 * practice, we expect that all these expressions will be just Params, so
	 * we could possibly do something more efficient than using the full
	 * expression-eval machinery for this.  But probably there would be little
	 * benefit, and it'd require jdbc_fdw to know more than is desirable about
	 * Param evaluation.)
	 */

#if PG_VERSION_NUM >= 100000
	fsstate->param_exprs = (List *) ExecInitExprList(fsplan->fdw_exprs, (PlanState *) node);
#else
	fsstate->param_exprs = (List *) ExecInitExpr((Expr *) fsplan->fdw_exprs, (PlanState *) node);
#endif

	/*
	 * Allocate buffer for text form of query parameters, if any.
	 */
	if (numParams > 0)
		fsstate->param_values = (const char **) palloc0(numParams * sizeof(char *));
	else
		fsstate->param_values = NULL;
	(void) jq_exec_id(fsstate->conn, fsstate->query, &fsstate->resultSetID);
}

/*
 * jdbcIterateForeignScan Retrieve next row from the result set, or clear
 * tuple slot to indicate EOF.
 */
static TupleTableSlot *
jdbcIterateForeignScan(ForeignScanState *node)
{
	jdbcFdwScanState *fsstate = (jdbcFdwScanState *) node->fdw_state;

	if (!fsstate->cursor_exists)
		fsstate->cursor_exists = true;
	ereport(DEBUG3, (errmsg("In jdbcIterateForeignScan")));
	jq_iterate(fsstate->conn, node, fsstate->retrieved_attrs, fsstate->resultSetID);
	return node->ss.ss_ScanTupleSlot;
}

/*
 * jdbcReScanForeignScan Restart the scan.
 */
static void
jdbcReScanForeignScan(ForeignScanState *node)
{
	jdbcFdwScanState *fsstate = (jdbcFdwScanState *) node->fdw_state;

	ereport(DEBUG3, (errmsg("In jdbcReScanForeignScan")));

	if (!fsstate->cursor_exists || !fsstate->resultSetID > 0)
		return;

	(void) jq_exec_id(fsstate->conn, fsstate->query, &fsstate->resultSetID);

	/* Now force a fresh FETCH. */
	fsstate->tuples = NULL;
	fsstate->num_tuples = 0;
	fsstate->next_tuple = 0;
	fsstate->fetch_ct_2 = 0;
	fsstate->eof_reached = false;
}

/*
 * jdbcEndForeignScan Finish scanning foreign table and dispose objects used
 * for this scan
 */
static void
jdbcEndForeignScan(ForeignScanState *node)
{
	jdbcFdwScanState *fsstate = (jdbcFdwScanState *) node->fdw_state;

	ereport(DEBUG3, (errmsg("In jdbcEndForeignScan")));

	/* if fsstate is NULL, we are in EXPLAIN; nothing to do */
	if (fsstate == NULL)
		return;

	/* Close the cursor if open, to prevent accumulation of cursors */
	if (fsstate->cursor_exists)
		jdbc_close_cursor(fsstate->conn, fsstate->cursor_number);
	jq_release_resultset_id(fsstate->conn, fsstate->resultSetID);
	/* Release remote connection */
	jdbc_release_connection(fsstate->conn);
	fsstate->conn = NULL;

	/* MemoryContexts will be deleted automatically. */
}

/*
 * jdbcAddForeignUpdateTargets Add resjunk column(s) needed for update/delete
 * on a foreign table
 */
static void
jdbcAddForeignUpdateTargets(
#if PG_VERSION_NUM >= 140000
							PlannerInfo *root,
							Index rtindex,
#else
							Query *parsetree,
#endif
							RangeTblEntry *target_rte,
							Relation target_relation)
{

	Oid			relid = RelationGetRelid(target_relation);
	TupleDesc	tupdesc = target_relation->rd_att;
	int			i;
	bool		has_key = false;

	/* loop through all columns of the foreign table */
	for (i = 0; i < tupdesc->natts; ++i)
	{
		Form_pg_attribute att = TupleDescAttr(tupdesc, i);
		AttrNumber	attrno = att->attnum;
		List	   *options;
		ListCell   *option;

		/* look for the "key" option on this column */
		options = GetForeignColumnOptions(relid, attrno);
		foreach(option, options)
		{
			DefElem    *def = (DefElem *) lfirst(option);

			/* if "key" is set, add a resjunk for this column */
			if (IS_KEY_COLUMN(def))
			{
				Var		   *var;
#if PG_VERSION_NUM < 140000
				Index		rtindex = parsetree->resultRelation;
				TargetEntry *tle;
#endif
				/* Make a Var representing the desired value */
				var = makeVar(rtindex,
							  attrno,
							  att->atttypid,
							  att->atttypmod,
							  att->attcollation,
							  0);
#if (PG_VERSION_NUM >= 140000)
				add_row_identity_var(root, var, rtindex, pstrdup(NameStr(att->attname)));
#else

				/*
				 * Wrap it in a resjunk TLE with the right name ...
				 */
				tle = makeTargetEntry((Expr *) var,
									  list_length(parsetree->targetList) + 1,
									  pstrdup(NameStr(att->attname)),
									  true);

				/* ... and add it to the query's targetlist */
				parsetree->targetList = lappend(parsetree->targetList, tle);
#endif
				has_key = true;
			}
			else if (strcmp(def->defname, "key") == 0)
			{
				elog(ERROR, "impossible column option \"%s\"", def->defname);
			}
		}
	}

	if (!has_key)
		ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
				 errmsg("no primary key column specified for foreign table"),
				 errdetail("For UPDATE or DELETE, at least one foreign table column must be marked as primary key column."),
				 errhint("Set the option \"%s\" on the columns that belong to the primary key.", "key")));

}

/*
 * jdbcPlanForeignModify Plan an insert/update/delete operation on a foreign
 * table
 *
 * Note: currently, the plan tree generated for UPDATE/DELETE will always
 * include a ForeignScan that retrieves key columns (using SELECT FOR UPDATE)
 * and then the ModifyTable node will have to execute individual remote
 * UPDATE/DELETE commands.  If there are no local conditions or joins needed,
 * it'd be better to let the scan node do UPDATE/DELETE RETURNING and then do
 * nothing at ModifyTable.  Room for future optimization ...
 */
static List *
jdbcPlanForeignModify(PlannerInfo *root,
					  ModifyTable *plan,
					  Index resultRelation,
					  int subplan_index)
{
	CmdType		operation = plan->operation;
	RangeTblEntry *rte = planner_rt_fetch(resultRelation, root);
	Relation	rel;
	StringInfoData sql;
	List	   *targetAttrs = NIL;
	List	   *returningList = NIL;
	List	   *retrieved_attrs = NIL;
	Oid			foreignTableId;
	List	   *condAttr = NULL;
	TupleDesc	tupdesc;
	int			i;
	Jconn	   *conn;
	ForeignTable *table;
	ForeignServer *server;
	UserMapping *user;
	Oid			userid;

	initStringInfo(&sql);

	ereport(DEBUG3, (errmsg("In jdbcPlanForeignModify")));

	/*
	 * Core code already has some lock on each rel being planned, so we can
	 * use NoLock here.
	 */
#if PG_VERSION_NUM < 130000
	rel = heap_open(rte->relid, NoLock);
#else
	rel = table_open(rte->relid, NoLock);
#endif

	foreignTableId = RelationGetRelid(rel);
	tupdesc = RelationGetDescr(rel);
	table = GetForeignTable(foreignTableId);
	server = GetForeignServer(table->serverid);
	userid = rte->checkAsUser ? rte->checkAsUser : GetUserId();
	user = GetUserMapping(userid, server->serverid);
	conn = jdbc_get_connection(server, user, false);

	/*
	 * In an INSERT, we transmit all columns that are defined in the foreign
	 * table.  In an UPDATE, we transmit only columns that were explicitly
	 * targets of the UPDATE, so as to avoid unnecessary data transmission.
	 * (We can't do that for INSERT since we would miss sending default values
	 * for columns not listed in the source statement.)
	 */
	if (operation == CMD_INSERT)
	{
		int			attnum;

		for (attnum = 1; attnum <= tupdesc->natts; attnum++)
		{
			Form_pg_attribute attr = TupleDescAttr(tupdesc, attnum - 1);

			if (!attr->attisdropped)
				targetAttrs = lappend_int(targetAttrs, attnum);
		}
	}
	else if (operation == CMD_UPDATE)
	{
		Bitmapset  *tmpset;
		AttrNumber	col;

#if (PG_VERSION_NUM >= 120000)
		tmpset = bms_union(rte->updatedCols, rte->extraUpdatedCols);
#else
		tmpset = bms_copy(rte->updatedCols);
#endif
		while ((col = bms_first_member(tmpset)) >= 0)
		{
			col += FirstLowInvalidHeapAttributeNumber;
			if (col <= InvalidAttrNumber)	/* shouldn't happen */
				elog(ERROR, "system-column update is not supported");
			targetAttrs = lappend_int(targetAttrs, col);
		}
	}

	/*
	 * Extract the relevant RETURNING list if any. RETURNING clause is not
	 * supported.
	 */
	if (plan->returningLists)
		ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
				 errmsg("RETURNING clause is not supported")));

	/*
	 * Add all primary key attribute names to condAttr used in where clause of
	 * update
	 */
	for (i = 0; i < tupdesc->natts; ++i)
	{
		Form_pg_attribute att = TupleDescAttr(tupdesc, i);
		AttrNumber	attrno = att->attnum;
		List	   *options;
		ListCell   *option;

		/* look for the "key" option on this column */
		options = GetForeignColumnOptions(foreignTableId, attrno);
		foreach(option, options)
		{
			DefElem    *def = (DefElem *) lfirst(option);

			if (IS_KEY_COLUMN(def))
			{
				condAttr = lappend_int(condAttr, attrno);
			}
		}
	}

	/*
	 * Construct the SQL command string.
	 */
	switch (operation)
	{
		case CMD_INSERT:
			jdbc_deparse_insert_sql(&sql, root, resultRelation, rel,
									targetAttrs, returningList,
									&retrieved_attrs, conn->q_char);
			break;
		case CMD_UPDATE:
			jdbc_deparse_update_sql(&sql, root, resultRelation, rel,
									targetAttrs, condAttr, conn->q_char);
			break;
		case CMD_DELETE:
			jdbc_deparse_delete_sql(&sql, root, resultRelation, rel,
									condAttr, conn->q_char);
			break;
		default:
			elog(ERROR, "unexpected operation: %d", (int) operation);
			break;
	}

#if PG_VERSION_NUM < 130000
	heap_close(rel, NoLock);
#else
	table_close(rel, NoLock);
#endif

	/*
	 * Build the fdw_private list that will be available to the executor.
	 * Items in the list must match enum FdwModifyPrivateIndex, above.
	 */
	return list_make2(makeString(sql.data),
					  targetAttrs);
}

/*
 * jdbcBeginForeignModify Begin an insert/update/delete operation on a
 * foreign table
 */
static void
jdbcBeginForeignModify(ModifyTableState *mtstate,
					   ResultRelInfo *resultRelInfo,
					   List *fdw_private,
					   int subplan_index,
					   int eflags)
{
	jdbcFdwModifyState *fmstate;
	EState	   *estate = mtstate->ps.state;
	Relation	rel = resultRelInfo->ri_RelationDesc;
	AttrNumber	n_params;
	Oid			typefnoid = InvalidOid;
	bool		isvarlena = false;
	ListCell   *lc;
	RangeTblEntry *rte;
	Oid			userid;
	ForeignServer *server;
	UserMapping *user;
	ForeignTable *table;
	Oid			foreignTableId = InvalidOid;
	int			i;
	Plan	   *subplan;

	ereport(DEBUG3, (errmsg("In jdbcBeginForeignModify")));

	/*
	 * Do nothing in EXPLAIN (no ANALYZE) case. resultRelInfo->ri_FdwState
	 * stays NULL.
	 */
	if (eflags & EXEC_FLAG_EXPLAIN_ONLY)
		return;

	/*
	 * Identify which user to do the remote access as.  This should match what
	 * ExecCheckRTEPerms() does.
	 */
	rte = rt_fetch(resultRelInfo->ri_RangeTableIndex, estate->es_range_table);
	userid = rte->checkAsUser ? rte->checkAsUser : GetUserId();

	foreignTableId = RelationGetRelid(rel);
#if (PG_VERSION_NUM >= 140000)
	subplan = outerPlanState(mtstate)->plan;
#else
	subplan = mtstate->mt_plans[subplan_index]->plan;
#endif

	/* Get info about foreign table. */
	table = GetForeignTable(foreignTableId);
	server = GetForeignServer(table->serverid);
	user = GetUserMapping(userid, server->serverid);

	/* Begin constructing jdbcFdwModifyState. */
	fmstate = (jdbcFdwModifyState *) palloc0(sizeof(jdbcFdwModifyState));
	fmstate->rel = rel;

	/* Open connection; report that we'll create a prepared statement. */
	fmstate->conn = jdbc_get_connection(server, user, true);
	fmstate->is_prepared = false;	/* prepared statement not made yet */

	/* Deconstruct fdw_private data. */
	fmstate->query = strVal(list_nth(fdw_private,
									 FdwModifyPrivateUpdateSql));
	fmstate->target_attrs = (List *) list_nth(fdw_private,
											  FdwModifyPrivateTargetAttnums);
	/* Create context for per-tuple temp workspace. */
#if PG_VERSION_NUM >= 110000
	fmstate->temp_cxt = AllocSetContextCreate(estate->es_query_cxt,
											  "jdbc_fdw temporary data",
											  ALLOCSET_DEFAULT_SIZES);
#else
	fmstate->temp_cxt = AllocSetContextCreate(estate->es_query_cxt,
											  "jdbc_fdw temporary data",
											  ALLOCSET_SMALL_MINSIZE,
											  ALLOCSET_SMALL_INITSIZE,
											  ALLOCSET_SMALL_MAXSIZE);
#endif

	/* Prepare for output conversion of parameters used in prepared stmt. */
	n_params = list_length(fmstate->target_attrs) + 1;
	fmstate->p_flinfo = (FmgrInfo *) palloc0(sizeof(FmgrInfo) * n_params);
	fmstate->p_nums = 0;

	/* Set up for remaining transmittable parameters */
	foreach(lc, fmstate->target_attrs)
	{
		int			attnum = lfirst_int(lc);
		Form_pg_attribute attr = TupleDescAttr(RelationGetDescr(rel), attnum - 1);

		Assert(!attr->attisdropped);

		getTypeOutputInfo(attr->atttypid, &typefnoid, &isvarlena);
		fmgr_info(typefnoid, &fmstate->p_flinfo[fmstate->p_nums]);
		fmstate->p_nums++;
	}
	Assert(fmstate->p_nums <= n_params);

	resultRelInfo->ri_FdwState = fmstate;

	fmstate->junk_idx = palloc0(RelationGetDescr(rel)->natts * sizeof(AttrNumber));
	/* loop through table columns */
	for (i = 0; i < RelationGetDescr(rel)->natts; ++i)
	{
		/*
		 * for primary key columns, get the resjunk attribute number and store
		 * it
		 */
		fmstate->junk_idx[i] =
			ExecFindJunkAttributeInTlist(subplan->targetlist,
										 get_attname(foreignTableId, i + 1
#if (PG_VERSION_NUM >= 110000)
													 ,false
#endif
													 ));
	}

}

/*
 * jdbcExecForeignInsert Insert one row into a foreign table
 */
static TupleTableSlot *
jdbcExecForeignInsert(EState *estate,
					  ResultRelInfo *resultRelInfo,
					  TupleTableSlot *slot,
					  TupleTableSlot *planSlot)
{
	jdbcFdwModifyState *fmstate = (jdbcFdwModifyState *) resultRelInfo->ri_FdwState;
	Jresult    *res;
	int			bindnum = 0;
	ListCell   *lc;
	Datum		value = 0;

	ereport(DEBUG3, (errmsg("In jdbcExecForeignInsert")));

	/*
	 * Set up the prepared statement on the remote server, if we didn't yet
	 */
	if (!fmstate->is_prepared)
		jdbc_prepare_foreign_modify(fmstate);

	/* Bind the value with jq_bind_sql_var. */
	foreach(lc, fmstate->target_attrs)
	{
		int			attnum = lfirst_int(lc) - 1;
		Oid			type = TupleDescAttr(slot->tts_tupleDescriptor, attnum)->atttypid;
		bool		isnull;

		value = slot_getattr(slot, attnum + 1, &isnull);
		jq_bind_sql_var(fmstate->conn, type, bindnum, value, &isnull, fmstate->resultSetID);
		bindnum++;
	}

	/*
	 * Execute the prepared statement, and check for success.
	 *
	 * We don't use a PG_TRY block here, so be careful not to throw error
	 * without releasing the Jresult.
	 */
	res = jq_exec_prepared(fmstate->conn,
						   NULL,
						   NULL,
						   0,
						   fmstate->resultSetID);
	if (*res !=
		(fmstate->has_returning ? PGRES_TUPLES_OK : PGRES_COMMAND_OK))
		jdbc_fdw_report_error(ERROR, res, fmstate->conn, true, fmstate->query);

	jq_clear(res);

	return slot;
}

/*
 * jdbcExecForeignUpdate Update one row in a foreign table
 */
static TupleTableSlot *
jdbcExecForeignUpdate(EState *estate,
					  ResultRelInfo *resultRelInfo,
					  TupleTableSlot *slot,
					  TupleTableSlot *planSlot)
{
	jdbcFdwModifyState *fmstate = (jdbcFdwModifyState *) resultRelInfo->ri_FdwState;
	Jresult    *res;
	Relation	rel = resultRelInfo->ri_RelationDesc;
	Oid			foreignTableId = RelationGetRelid(rel);
	ListCell   *lc = NULL;
	int			bindnum = 0;
	int			i = 0;

	ereport(DEBUG3, (errmsg("In jdbcExecForeignUpdate")));

	/*
	 * Set up the prepared statement on the remote server, if we didn't yet
	 */
	if (!fmstate->is_prepared)
		jdbc_prepare_foreign_modify(fmstate);

	/* Bind the values */
	foreach(lc, fmstate->target_attrs)
	{
		int			attnum = lfirst_int(lc);
		Oid			type;
		bool		is_null;
		Datum		value = 0;

		/* first attribute cannot be in target list attribute */
		type = TupleDescAttr(slot->tts_tupleDescriptor, attnum - 1)->atttypid;

		value = slot_getattr(slot, attnum, &is_null);

		jq_bind_sql_var(fmstate->conn, type, bindnum, value, &is_null, fmstate->resultSetID);
		bindnum++;
		i++;
	}

	/*
	 * Set up the prepared statement on the remote server, if we didn't yet
	 */
	if (!fmstate->is_prepared)
		jdbc_prepare_foreign_modify(fmstate);

	jdbc_bind_junk_column_value(fmstate, slot, planSlot, foreignTableId, bindnum);

	/*
	 * Execute the prepared statement, and check for success.
	 *
	 * We don't use a PG_TRY block here, so be careful not to throw error
	 * without releasing the Jresult.
	 */
	res = jq_exec_prepared(fmstate->conn,
						   NULL,
						   NULL,
						   0,
						   fmstate->resultSetID);
	if (*res !=
		(fmstate->has_returning ? PGRES_TUPLES_OK : PGRES_COMMAND_OK))
		jdbc_fdw_report_error(ERROR, res, fmstate->conn, true, fmstate->query);

	/* And clean up */
	jq_clear(res);

	MemoryContextReset(fmstate->temp_cxt);

	/* Return NULL if nothing was updated on the remote end */
	return slot;
}

/*
 * jdbcExecForeignDelete Delete one row from a foreign table
 */
static TupleTableSlot *
jdbcExecForeignDelete(EState *estate,
					  ResultRelInfo *resultRelInfo,
					  TupleTableSlot *slot,
					  TupleTableSlot *planSlot)
{
	jdbcFdwModifyState *fmstate = (jdbcFdwModifyState *) resultRelInfo->ri_FdwState;
	Relation	rel = resultRelInfo->ri_RelationDesc;
	Oid			foreignTableId = RelationGetRelid(rel);
	Jresult    *res;

	ereport(DEBUG3, (errmsg("In jdbcExecForeignDelete")));

	/*
	 * Set up the prepared statement on the remote server, if we didn't yet
	 */
	if (!fmstate->is_prepared)
		jdbc_prepare_foreign_modify(fmstate);

	jdbc_bind_junk_column_value(fmstate, slot, planSlot, foreignTableId, 0);

	/*
	 * Execute the prepared statement, and check for success.
	 *
	 * We don't use a PG_TRY block here, so be careful not to throw error
	 * without releasing the Jresult.
	 */
	res = jq_exec_prepared(fmstate->conn,
						   NULL,
						   NULL,
						   0,
						   fmstate->resultSetID);
	if (*res !=
		(fmstate->has_returning ? PGRES_TUPLES_OK : PGRES_COMMAND_OK))
		jdbc_fdw_report_error(ERROR, res, fmstate->conn, true, fmstate->query);

	/* And clean up */
	jq_clear(res);

	MemoryContextReset(fmstate->temp_cxt);

	/* Return NULL if nothing was deleted on the remote end */
	return slot;
}

static void
jdbc_bind_junk_column_value(jdbcFdwModifyState * fmstate,
							TupleTableSlot *slot,
							TupleTableSlot *planSlot,
							Oid foreignTableId,
							int bindnum)
{
	int			i;
	Datum		value;
	Oid			typeoid;

	/* Bind where condition using junk column */
	for (i = 0; i < slot->tts_tupleDescriptor->natts; ++i)
	{
		Form_pg_attribute att = TupleDescAttr(slot->tts_tupleDescriptor, i);
		AttrNumber	attrno = att->attnum;
		List	   *options;
		ListCell   *option;

		/* look for the "key" option on this column */
		if (fmstate->junk_idx[i] == InvalidAttrNumber)
			continue;
		options = GetForeignColumnOptions(foreignTableId, attrno);
		foreach(option, options)
		{
			DefElem    *def = (DefElem *) lfirst(option);
			bool		is_null = false;

			if (IS_KEY_COLUMN(def))
			{
				/*
				 * Get the id that was passed up as a resjunk column
				 */
				value = ExecGetJunkAttribute(planSlot, fmstate->junk_idx[i], &is_null);
				typeoid = att->atttypid;

				/* Bind qual */
				jq_bind_sql_var(fmstate->conn, typeoid, bindnum, value, &is_null, fmstate->resultSetID);
				bindnum++;
			}
		}
	}
}

/*
 * jdbcEndForeignModify Finish an insert/update/delete operation on a foreign
 * table
 */
static void
jdbcEndForeignModify(EState *estate,
					 ResultRelInfo *resultRelInfo)
{
	jdbcFdwModifyState *fmstate = (jdbcFdwModifyState *) resultRelInfo->ri_FdwState;

	ereport(DEBUG3, (errmsg("In jdbcEndForeignModify")));
	/* If fmstate is NULL, we are in EXPLAIN; nothing to do */
	if (fmstate == NULL)
		return;
	/* If we created a prepared statement, destroy it */
	if (fmstate->is_prepared)
	{
		fmstate->is_prepared = false;
	}

	/* Release remote connection */
	jdbc_release_connection(fmstate->conn);
	fmstate->conn = NULL;
}

/*
 * jdbcIsForeignRelUpdatable Determine whether a foreign table supports
 * INSERT, UPDATE and/or DELETE.
 */
static int
jdbcIsForeignRelUpdatable(Relation rel)
{
	bool		updatable;
	ForeignTable *table;
	ForeignServer *server;
	ListCell   *lc;

	ereport(DEBUG3, (errmsg("In jdbcIsForeignRelUpdatable")));

	/*
	 * By default, all jdbc_fdw foreign tables are assumed updatable. This can
	 * be overridden by a per-server setting, which in turn can be overridden
	 * by a per-table setting.
	 */
	updatable = true;

	table = GetForeignTable(RelationGetRelid(rel));
	server = GetForeignServer(table->serverid);

	foreach(lc, server->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "updatable") == 0)
			updatable = defGetBoolean(def);
	}
	foreach(lc, table->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "updatable") == 0)
			updatable = defGetBoolean(def);
	}

	/*
	 * Currently "updatable" means support for INSERT, UPDATE and DELETE.
	 */
	return updatable ?
		(1 << CMD_INSERT) | (1 << CMD_UPDATE) | (1 << CMD_DELETE) : 0;
}

/*
 * jdbcExplainForeignScan Produce extra output for EXPLAIN of a ForeignScan
 * on a foreign table
 */
static void
jdbcExplainForeignScan(ForeignScanState *node, ExplainState *es)
{
	List	   *fdw_private;
	char	   *sql;

	ereport(DEBUG3, (errmsg("In jdbcExplainForeignScan")));
	if (es->verbose)
	{
		fdw_private = ((ForeignScan *) node->ss.ps.plan)->fdw_private;
		sql = strVal(list_nth(fdw_private, FdwScanPrivateSelectSql));
		ExplainPropertyText("Remote SQL", sql, es);
	}
}

/*
 * jdbcExplainForeignModify Produce extra output for EXPLAIN of a ModifyTable
 * on a foreign table
 */
static void
jdbcExplainForeignModify(ModifyTableState *mtstate,
						 ResultRelInfo *rinfo,
						 List *fdw_private,
						 int subplan_index,
						 ExplainState *es)
{
	if (es->verbose)
	{
		char	   *sql = strVal(list_nth(fdw_private,
										  FdwModifyPrivateUpdateSql));

		ExplainPropertyText("Remote SQL", sql, es);
	}
}

/*
 * Assess whether the aggregation, grouping and having operations can be
 * pushed down to the foreign server.  As a side effect, save information we
 * obtain in this function to jdbcFdwRelationInfo of the input relation.
 */
static bool
jdbc_foreign_grouping_ok(PlannerInfo *root, RelOptInfo *grouped_rel)
{
	Query	   *query = root->parse;
	jdbcFdwRelationInfo *fpinfo = (jdbcFdwRelationInfo *) grouped_rel->fdw_private;
	PathTarget *grouping_target;
	jdbcFdwRelationInfo *ofpinfo;
	ListCell   *lc;
	int			i;
	List	   *tlist = NIL;

	/* We currently don't support pushing Grouping Sets. */
	if (query->groupingSets)
		return false;

	/* Get the fpinfo of the underlying scan relation. */
	ofpinfo = (jdbcFdwRelationInfo *) fpinfo->outerrel->fdw_private;

	/*
	 * If underlying scan relation has any local conditions, those conditions
	 * are required to be applied before performing aggregation.  Hence the
	 * aggregate cannot be pushed down.
	 */
	if (ofpinfo->local_conds)
		return false;

	/*
	 * The targetlist expected from this node and the targetlist pushed down
	 * to the foreign server may be different. The latter requires
	 * sortgrouprefs to be set to push down GROUP BY clause, but should not
	 * have those arising from ORDER BY clause. These sortgrouprefs may be
	 * different from those in the plan's targetlist. Use a copy of path
	 * target to record the new sortgrouprefs.
	 */
	grouping_target = grouped_rel->reltarget;

	/*
	 * Examine grouping expressions, as well as other expressions we'd need to
	 * compute, and check whether they are safe to push down to the foreign
	 * server.  All GROUP BY expressions will be part of the grouping target
	 * and thus there is no need to search for them separately.  Add grouping
	 * expressions into target list which will be passed to foreign server.
	 *
	 * A tricky fine point is that we must not put any expression into the
	 * target list that is just a foreign param (that is, something that
	 * deparse.c would conclude has to be sent to the foreign server).  If we
	 * do, the expression will also appear in the fdw_exprs list of the plan
	 * node, and setrefs.c will get confused and decide that the fdw_exprs
	 * entry is actually a reference to the fdw_scan_tlist entry, resulting in
	 * a broken plan.  Somewhat oddly, it's OK if the expression contains such
	 * a node, as long as it's not at top level; then no match is possible.
	 */
	i = 0;

	foreach(lc, grouping_target->exprs)
	{
		Expr	   *expr = (Expr *) lfirst(lc);
		ListCell   *l;

		/*
		 * Non-grouping expression we need to compute.  Can we ship it as-is
		 * to the foreign server?
		 */
		if (jdbc_is_foreign_expr(root, grouped_rel, expr /* , true */ ) &&
			!jdbc_is_foreign_param(root, grouped_rel, expr))
		{
			/*
			 * Yes, so add to tlist as-is; OK to suppress duplicates
			 */
			tlist = add_to_flat_tlist(tlist, list_make1(expr));
		}
		else
		{
			/*
			 * Not pushable as a whole; extract its Vars and aggregates
			 */
			List	   *aggvars;

			aggvars = pull_var_clause((Node *) expr,
									  PVC_INCLUDE_AGGREGATES);

			/*
			 * If any aggregate expression is not shippable, then we cannot
			 * push down aggregation to the foreign server.  (We don't have to
			 * check is_foreign_param, since that certainly won't return true
			 * for any such expression.)
			 */
			if (!jdbc_is_foreign_expr(root, grouped_rel, (Expr *) aggvars /* , true */ ))
				return false;

			/*
			 * Add aggregates, if any, into the targetlist. Plain Vars outside
			 * an aggregate can be ignored, because they should be either same
			 * as some GROUP BY column or part of some GROUP BY expression. In
			 * either case, they are already part of the targetlist and thus
			 * no need to add them again.  In fact including plain Vars in the
			 * tlist when they do not match a GROUP BY column would cause the
			 * foreign server to complain that the shipped query is invalid.
			 */
			foreach(l, aggvars)
			{
				Expr	   *expr = (Expr *) lfirst(l);

				if (IsA(expr, Aggref))
					tlist = add_to_flat_tlist(tlist, list_make1(expr));
			}
		}

		i++;
	}

	/*
	 * If there are any local conditions, pull Vars and aggregates from it and
	 * check whether they are safe to pushdown or not.
	 */
	if (fpinfo->local_conds)
	{
		List	   *aggvars = NIL;
		ListCell   *lc;

		foreach(lc, fpinfo->local_conds)
		{
			RestrictInfo *rinfo = lfirst_node(RestrictInfo, lc);

			aggvars = list_concat(aggvars,
								  pull_var_clause((Node *) rinfo->clause,
												  PVC_INCLUDE_AGGREGATES));
		}

		foreach(lc, aggvars)
		{
			Expr	   *expr = (Expr *) lfirst(lc);

			/*
			 * If aggregates within local conditions are not safe to push
			 * down, then we cannot push down the query. Vars are already part
			 * of GROUP BY clause which are checked above, so no need to
			 * access them again here.  Again, we need not check
			 * is_foreign_param for a foreign aggregate.
			 */
			if (IsA(expr, Aggref))
			{
				if (!jdbc_is_foreign_expr(root, grouped_rel, expr))
					return false;

				tlist = add_to_flat_tlist(tlist, list_make1(expr));
			}
		}
	}

	/* Store generated targetlist */
	fpinfo->grouped_tlist = tlist;

	/* Safe to pushdown */
	fpinfo->pushdown_safe = true;

	/*
	 * Set # of retrieved rows and cached relation costs to some negative
	 * value, so that we can detect when they are set to some sensible values,
	 * during one (usually the first) of the calls to estimate_path_cost_size.
	 */
	fpinfo->retrieved_rows = -1;
	fpinfo->rel_startup_cost = -1;
	fpinfo->rel_total_cost = -1;

	/*
	 * Set the string describing this grouped relation to be used in EXPLAIN
	 * output of corresponding ForeignScan.  Note that the decoration we add
	 * to the base relation name mustn't include any digits, or it'll confuse
	 * postgresExplainForeignScan.
	 */

	/*
	 * Set the string describing this grouped relation to be used in EXPLAIN
	 * output of corresponding ForeignScan.
	 */
	fpinfo->relation_name = makeStringInfo();

	return true;
}

/*
 * jdbc_add_foreign_grouping_paths Add foreign path for grouping and/or
 * aggregation.
 *
 * Given input_rel represents the underlying scan.  The paths are added to
 * the given grouped_rel.
 */
static void
jdbc_add_foreign_grouping_paths(PlannerInfo *root, RelOptInfo *input_rel,
								RelOptInfo *grouped_rel
#if (PG_VERSION_NUM >= 110000)
								,GroupPathExtraData *extra
#endif
)
{
	Query	   *parse = root->parse;
	jdbcFdwRelationInfo *ifpinfo = input_rel->fdw_private;
	jdbcFdwRelationInfo *fpinfo = grouped_rel->fdw_private;
	ForeignPath *grouppath;
	double		rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;

	/*
	 * Nothing to be done, if there is no aggregation required. JDBC does not
	 * support GROUP BY, GROUPING SET, HAVING, so also return when there are
	 * those clauses.
	 */
	if (parse->groupClause ||
		parse->groupingSets ||
		root->hasHavingQual ||
		!parse->hasAggs)
		return;

#if (PG_VERSION_NUM >= 110000)
	Assert(extra->patype == PARTITIONWISE_AGGREGATE_NONE ||
		   extra->patype == PARTITIONWISE_AGGREGATE_FULL);
#endif

	/* save the input_rel as outerrel in fpinfo */
	fpinfo->outerrel = input_rel;

	/*
	 * Copy foreign table, foreign server, user mapping, FDW options etc.
	 * details from the input relation's fpinfo.
	 */
	fpinfo->table = ifpinfo->table;
	fpinfo->server = ifpinfo->server;
	fpinfo->user = ifpinfo->user;

	/*
	 * Assess if it is safe to push down aggregation and grouping.
	 *
	 * Use HAVING qual from extra. In case of child partition, it will have
	 * translated Vars.
	 */
	if (!jdbc_foreign_grouping_ok(root, grouped_rel))
		return;

	/*
	 * Compute the selectivity and cost of the local_conds, so we don't have
	 * to do it over again for each path.  (Currently we create just a single
	 * path here, but in future it would be possible that we build more paths
	 * such as pre-sorted paths as in postgresGetForeignPaths and
	 * postgresGetForeignJoinPaths.)  The best we can do for these conditions
	 * is to estimate selectivity on the basis of local statistics.
	 */
	fpinfo->local_conds_sel = clauselist_selectivity(root,
													 fpinfo->local_conds,
													 0,
													 JOIN_INNER,
													 NULL);

	/* Use small cost to push down aggregate always */
	rows = width = startup_cost = total_cost = 1;

	/* Now update this information in the fpinfo */
	fpinfo->rows = rows;
	fpinfo->width = width;
	fpinfo->startup_cost = startup_cost;
	fpinfo->total_cost = total_cost;

	/* Create and add foreign path to the grouping relation. */
#if (PG_VERSION_NUM >= 120000)
	grouppath = create_foreign_upper_path(root,
										  grouped_rel,
										  grouped_rel->reltarget,
										  rows,
										  startup_cost,
										  total_cost,
										  NIL,	/* no pathkeys */
										  NULL,
										  NIL); /* no fdw_private */
#else
	grouppath = create_foreignscan_path(root,
										grouped_rel,
										root->upper_targets[UPPERREL_GROUP_AGG],
										rows,
										startup_cost,
										total_cost,
										NIL,	/* no pathkeys */
										NULL,	/* no required_outer */
										NULL,
										NIL);	/* no fdw_private */
#endif

	/* Add generated path into grouped_rel by add_path(). */
	add_path(grouped_rel, (Path *) grouppath);

}

/*
 * jdbc_add_foreign_final_paths Add foreign paths for performing the final
 * processing remotely.
 *
 * Given input_rel contains the source-data Paths.  The paths are added to
 * the given final_rel.
 */
static void
jdbc_add_foreign_final_paths(PlannerInfo *root, RelOptInfo *input_rel,
							 RelOptInfo *final_rel
#if (PG_VERSION_NUM >= 120000)
							 ,FinalPathExtraData *extra
#endif
)
{
	Query	   *parse = root->parse;
	jdbcFdwRelationInfo *ifpinfo = (jdbcFdwRelationInfo *) input_rel->fdw_private;
	jdbcFdwRelationInfo *fpinfo = (jdbcFdwRelationInfo *) final_rel->fdw_private;
	bool		has_final_sort = false;
	List	   *pathkeys = NIL;
	double		rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;
	List	   *fdw_private;
	ForeignPath *final_path;

	/*
	 * Currently, we only support this for SELECT commands
	 */
	if (parse->commandType != CMD_SELECT)
		return;

	/*
	 * Currently, we do not support FOR UPDATE/SHARE
	 */
	if (parse->rowMarks)
		return;

	/*
	 * No work if there is no FOR UPDATE/SHARE clause and if there is no need
	 * to add a LIMIT node
	 */
	if (!parse->rowMarks
#if (PG_VERSION_NUM >= 120000)
		&& !extra->limit_needed
#endif
		)
		return;

#if (PG_VERSION_NUM >= 100000)
	/* We don't support cases where there are any SRFs in the targetlist */
	if (parse->hasTargetSRFs)
		return;
#endif
	/* Save the input_rel as outerrel in fpinfo */
	fpinfo->outerrel = input_rel;

	/*
	 * Copy foreign table, foreign server, user mapping, FDW options etc.
	 * details from the input relation's fpinfo.
	 */
	fpinfo->table = ifpinfo->table;
	fpinfo->server = ifpinfo->server;
	fpinfo->user = ifpinfo->user;

#if (PG_VERSION_NUM >= 120000)

	/*
	 * If there is no need to add a LIMIT node, there might be a ForeignPath
	 * in the input_rel's pathlist that implements all behavior of the query.
	 * Note: we would already have accounted for the query's FOR UPDATE/SHARE
	 * (if any) before we get here.
	 */
	if (!extra->limit_needed)
	{
		ListCell   *lc;

		Assert(parse->rowMarks);

		/*
		 * Grouping and aggregation are not supported with FOR UPDATE/SHARE,
		 * so the input_rel should be a base, join, or ordered relation; and
		 * if it's an ordered relation, its input relation should be a base or
		 * join relation.
		 */
		Assert(input_rel->reloptkind == RELOPT_BASEREL ||
			   input_rel->reloptkind == RELOPT_JOINREL ||
			   (input_rel->reloptkind == RELOPT_UPPER_REL &&
				ifpinfo->stage == UPPERREL_ORDERED &&
				(ifpinfo->outerrel->reloptkind == RELOPT_BASEREL ||
				 ifpinfo->outerrel->reloptkind == RELOPT_JOINREL)));

		foreach(lc, input_rel->pathlist)
		{
			Path	   *path = (Path *) lfirst(lc);

			/*
			 * apply_scanjoin_target_to_paths() uses create_projection_path()
			 * to adjust each of its input paths if needed, whereas
			 * create_ordered_paths() uses apply_projection_to_path() to do
			 * that.  So the former might have put a ProjectionPath on top of
			 * the ForeignPath; look through ProjectionPath and see if the
			 * path underneath it is ForeignPath.
			 */
			if (IsA(path, ForeignPath) ||
				(IsA(path, ProjectionPath) &&
				 IsA(((ProjectionPath *) path)->subpath, ForeignPath)))
			{
				/*
				 * Create foreign final path; this gets rid of a
				 * no-longer-needed outer plan (if any), which makes the
				 * EXPLAIN output look cleaner
				 */
#if (PG_VERSION_NUM >= 120000)
				final_path = create_foreign_upper_path(root,
													   path->parent,
													   path->pathtarget,
													   path->rows,
													   path->startup_cost,
													   path->total_cost,
													   path->pathkeys,
													   NULL,	/* no extra plan */
													   NULL);	/* no fdw_private */
#else
				final_path = create_foreignscan_path(root,
													 input_rel,
													 root->upper_targets[UPPERREL_FINAL],
													 rows,
													 startup_cost,
													 total_cost,
													 pathkeys,
													 NULL,	/* no required_outer */
													 NULL,	/* no extra plan */
													 fdw_private);
#endif
				/* and add it to the final_rel */
				add_path(final_rel, (Path *) final_path);

				/* Safe to push down */
				fpinfo->pushdown_safe = true;

				return;
			}
		}

		/*
		 * If we get here it means no ForeignPaths; since we would already
		 * have considered pushing down all operations for the query to the
		 * remote server, give up on it.
		 */
		return;
	}

	Assert(extra->limit_needed);
#endif

	/*
	 * If the input_rel is an ordered relation, replace the input_rel with its
	 * input relation
	 */
	if (input_rel->reloptkind == RELOPT_UPPER_REL &&
		ifpinfo->stage == UPPERREL_ORDERED)
	{
		input_rel = ifpinfo->outerrel;
		ifpinfo = (jdbcFdwRelationInfo *) input_rel->fdw_private;
		has_final_sort = true;
		pathkeys = root->sort_pathkeys;
	}

	/* The input_rel should be a base, join, or grouping relation */
	Assert(input_rel->reloptkind == RELOPT_BASEREL ||
		   input_rel->reloptkind == RELOPT_JOINREL ||
		   (input_rel->reloptkind == RELOPT_UPPER_REL &&
			ifpinfo->stage == UPPERREL_GROUP_AGG));

	/*
	 * We try to create a path below by extending a simple foreign path for
	 * the underlying base, join, or grouping relation to perform the final
	 * sort (if has_final_sort) and the LIMIT restriction remotely, which is
	 * stored into the fdw_private list of the resulting path. (We re-estimate
	 * the costs of sorting the underlying relation, if has_final_sort.)
	 */

	/*
	 * Assess if it is safe to push down the LIMIT and OFFSET to the remote
	 * server
	 */

	/*
	 * If the underlying relation has any local conditions, the LIMIT/OFFSET
	 * cannot be pushed down.
	 */
	if (ifpinfo->local_conds)
		return;

	/*
	 * When query contains OFFSET but no LIMIT, do not push down because JDBC
	 * does not support.
	 */
	if (!parse->limitCount && parse->limitOffset)
		return;

	/*
	 * Also, the LIMIT/OFFSET cannot be pushed down, if their expressions are
	 * not safe to remote.
	 */
	if (!jdbc_is_foreign_expr(root, input_rel, (Expr *) parse->limitOffset /* , true */ ) ||
		!jdbc_is_foreign_expr(root, input_rel, (Expr *) parse->limitCount /* , true */ ))
		return;

	/* Safe to push down */
	fpinfo->pushdown_safe = true;

	/* Use small cost to push down limit always */
	rows = width = startup_cost = total_cost = 1;
	/* Now update this information in the fpinfo */
	fpinfo->rows = rows;
	fpinfo->width = width;
	fpinfo->startup_cost = startup_cost;
	fpinfo->total_cost = total_cost;

	/*
	 * Build the fdw_private list that will be used by postgresGetForeignPlan.
	 * Items in the list must match order in enum FdwPathPrivateIndex.
	 */
#if PG_VERSION_NUM >= 150000
	fdw_private = list_make2(makeBoolean(has_final_sort),
							 makeBoolean(extra->limit_needed));
#elif (PG_VERSION_NUM >= 120000)
    fdw_private = list_make2(makeInteger(has_final_sort),
							 makeInteger(extra->limit_needed));
#else
    fdw_private = list_make2(makeInteger(has_final_sort),
                             makeInteger(false));
#endif

	/*
	 * Create foreign final path; this gets rid of a no-longer-needed outer
	 * plan (if any), which makes the EXPLAIN output look cleaner
	 */
#if (PG_VERSION_NUM >= 120000)
	final_path = create_foreign_upper_path(root,
										   input_rel,
										   root->upper_targets[UPPERREL_FINAL],
										   rows,
										   startup_cost,
										   total_cost,
										   pathkeys,
										   NULL,	/* no extra plan */
										   fdw_private);
#else
	final_path = create_foreignscan_path(root,
										 input_rel,
										 root->upper_targets[UPPERREL_FINAL],
										 rows,
										 startup_cost,
										 total_cost,
										 pathkeys,
										 NULL,	/* no required_outer */
										 NULL,	/* no extra plan */
										 fdw_private);
#endif

	/* and add it to the final_rel */
	add_path(final_rel, (Path *) final_path);
}

/*
 * jdbcGetForeignUpperPaths Add paths for post-join operations like
 * aggregation, grouping etc. if corresponding operations are safe to push
 * down. Currently, we only support push down LIMIT...OFFSET
 */
static void
jdbcGetForeignUpperPaths(PlannerInfo *root, UpperRelationKind stage,
						 RelOptInfo *input_rel, RelOptInfo *output_rel
#if (PG_VERSION_NUM >= 110000)
						 ,
						 void *extra
#endif
)
{
	jdbcFdwRelationInfo *fpinfo;

	/*
	 * If input rel is not safe to pushdown, then simply return as we cannot
	 * perform any post-join operations on the foreign server.
	 */
	if (!input_rel->fdw_private ||
		!((jdbcFdwRelationInfo *) input_rel->fdw_private)->pushdown_safe)
		return;

	/*
	 * Ignore stages we don't support; and skip any duplicate calls. We only
	 * support LIMIT...OFFSET and aggregation push down
	 */
	if ((stage != UPPERREL_GROUP_AGG &&
		 stage != UPPERREL_FINAL) ||
		output_rel->fdw_private)
		return;

	fpinfo = (jdbcFdwRelationInfo *) palloc0(sizeof(jdbcFdwRelationInfo));
	fpinfo->pushdown_safe = false;
	fpinfo->stage = stage;
	output_rel->fdw_private = fpinfo;

	switch (stage)
	{
		case UPPERREL_GROUP_AGG:
			jdbc_add_foreign_grouping_paths(root, input_rel, output_rel
#if (PG_VERSION_NUM >= 110000)
											,(GroupPathExtraData *) extra
#endif
				);
			break;
		case UPPERREL_FINAL:
			jdbc_add_foreign_final_paths(root, input_rel, output_rel
#if (PG_VERSION_NUM >= 120000)
										 ,(FinalPathExtraData *) extra
#endif
				);
			break;
		default:
			elog(ERROR, "unexpected upper relation: %d", (int) stage);
			break;
	}
}

/*
 * estimate_path_cost_size Get cost and size estimates for a foreign scan
 *
 * We assume that all the baserestrictinfo clauses will be applied, plus any
 * join clauses listed in join_conds.
 */
static void
estimate_path_cost_size(PlannerInfo *root,
						RelOptInfo *baserel,
						List *join_conds,
						double *p_rows, int *p_width,
						Cost *p_startup_cost,
						Cost *p_total_cost,
						char *q_char)
{
	jdbcFdwRelationInfo *fpinfo = (jdbcFdwRelationInfo *) baserel->fdw_private;
	double		rows;
	double		retrieved_rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;
	Cost		run_cost;
	Cost		cpu_per_tuple;

	/*
	 * If the table or the server is configured to use remote estimates,
	 * connect to the foreign server and execute EXPLAIN to estimate the
	 * number of rows selected by the restriction+join clauses. Otherwise,
	 * estimate rows using whatever statistics we have locally, in a way
	 * similar to ordinary tables.
	 */
	if (fpinfo->use_remote_estimate)
	{
		List	   *remote_join_conds;
		List	   *local_join_conds;
		StringInfoData sql;
		List	   *retrieved_attrs;
		Jconn	   *conn;
		Selectivity local_sel;
		QualCost	local_cost;
		List	   *fdw_scan_tlist = NIL;
		List	   *remote_conds;

		/*
		 * join_conds might contain both clauses that are safe to send across,
		 * and clauses that aren't.
		 */
		jdbc_classify_conditions(root, baserel, join_conds,
								 &remote_join_conds, &local_join_conds);

		/*
		 * Build the list of columns to be fetched from the foreign server.
		 */
		if (IS_JOIN_REL(baserel) || IS_UPPER_REL(baserel))
			fdw_scan_tlist = jdbc_build_tlist_to_deparse(baserel);
		else
			fdw_scan_tlist = NIL;

		/*
		 * The complete list of remote conditions includes everything from
		 * baserestrictinfo plus any extra join_conds relevant to this
		 * particular path.
		 */
		remote_conds = list_concat(remote_join_conds,
								   fpinfo->remote_conds);

		/*
		 * Construct EXPLAIN query including the desired SELECT, FROM, and
		 * WHERE clauses.  Params and other-relation Vars are replaced by
		 * dummy values.
		 */
		initStringInfo(&sql);
		appendStringInfoString(&sql, "EXPLAIN ");
		jdbc_deparse_select_stmt_for_rel(&sql, root, baserel, remote_conds,
										 NULL, &retrieved_attrs, NULL, fdw_scan_tlist,
										 NULL, true, fpinfo->remote_conds,
										 remote_join_conds, q_char);

		/* Get the remote estimate */
		conn = jdbc_get_connection(fpinfo->server, fpinfo->user, false);
		get_remote_estimate(sql.data, conn, &rows, &width,
							&startup_cost, &total_cost);
		jdbc_release_connection(conn);

		retrieved_rows = rows;

		/* Factor in the selectivity of the locally-checked quals */
		local_sel = clauselist_selectivity(root,
										   local_join_conds,
										   baserel->relid,
										   JOIN_INNER,
										   NULL);
		local_sel *= fpinfo->local_conds_sel;

		rows = clamp_row_est(rows * local_sel);

		/* Add in the eval cost of the locally-checked quals */
		startup_cost += fpinfo->local_conds_cost.startup;
		total_cost += fpinfo->local_conds_cost.per_tuple * retrieved_rows;
		cost_qual_eval(&local_cost, local_join_conds, root);
		startup_cost += local_cost.startup;
		total_cost += local_cost.per_tuple * retrieved_rows;
	}
	else
	{
		/*
		 * We don't support join conditions in this mode (hence, no
		 * parameterized paths can be made).
		 */
		Assert(join_conds == NIL);

		/*
		 * Use rows/width estimates made by set_baserel_size_estimates.
		 */
		rows = baserel->rows;
		width = baserel->reltarget->width;

		/*
		 * Back into an estimate of the number of retrieved rows. Just in case
		 * this is nuts, clamp to at most baserel->tuples.
		 */
		retrieved_rows = clamp_row_est(rows / fpinfo->local_conds_sel);
		retrieved_rows = Min(retrieved_rows, baserel->tuples);

		/*
		 * Cost as though this were a seqscan, which is pessimistic. We
		 * effectively imagine the local_conds are being evaluated remotely,
		 * too.
		 */
		startup_cost = 0;
		run_cost = 0;
		run_cost += seq_page_cost * baserel->pages;

		startup_cost += baserel->baserestrictcost.startup;
		cpu_per_tuple = cpu_tuple_cost + baserel->baserestrictcost.per_tuple;
		run_cost += cpu_per_tuple * baserel->tuples;

		total_cost = startup_cost + run_cost;
	}

	/*
	 * Add some additional cost factors to account for connection overhead
	 * (fdw_startup_cost), transferring data across the network
	 * (fdw_tuple_cost per retrieved row), and local manipulation of the data
	 * (cpu_tuple_cost per retrieved row).
	 */
	startup_cost += fpinfo->fdw_startup_cost;
	total_cost += fpinfo->fdw_startup_cost;
	total_cost += fpinfo->fdw_tuple_cost * retrieved_rows;
	total_cost += cpu_tuple_cost * retrieved_rows;

	/* Return results. */
	*p_rows = rows;
	*p_width = width;
	*p_startup_cost = startup_cost;
	*p_total_cost = total_cost;
}

/*
 * Estimate costs of executing a SQL statement remotely. The given "sql" must
 * be an EXPLAIN command.
 */
static void
get_remote_estimate(const char *sql, Jconn * conn,
					double *rows, int *width,
					Cost *startup_cost, Cost *total_cost)
{
	Jresult    *volatile res = NULL;

	/* Jresult must be released before leaving this function. */
	PG_TRY();
	{
		char	   *line;
		char	   *p;
		int			n;

		/*
		 * Execute EXPLAIN remotely.
		 */
		res = jq_exec(conn, sql);
		if (*res != PGRES_TUPLES_OK)
			jdbc_fdw_report_error(ERROR, res, conn, false, sql);

		/*
		 * Extract cost numbers for topmost plan node.  Note we search for a
		 * left paren from the end of the line to avoid being confused by
		 * other uses of parentheses.
		 */
		line = jq_get_value(res, 0, 0);
		p = strrchr(line, '(');
		if (p == NULL)
			elog(ERROR, "could not interpret EXPLAIN output: \"%s\"", line);
		n = sscanf(p, "(cost=%lf..%lf rows=%lf width=%d)",
				   startup_cost, total_cost, rows, width);
		if (n != 4)
			elog(ERROR, "could not interpret EXPLAIN output: \"%s\"", line);

		jq_clear(res);
		res = NULL;
	}
	PG_CATCH();
	{
		if (res)
			jq_clear(res);
		PG_RE_THROW();
	}
	PG_END_TRY();
}

/*
 * Force assorted GUC parameters to settings that ensure that we'll output
 * data values in a form that is unambiguous to the remote server.
 *
 * This is rather expensive and annoying to do once per row, but there's
 * little choice if we want to be sure values are transmitted accurately; we
 * can't leave the settings in place between rows for fear of affecting
 * user-visible computations.
 *
 * We use the equivalent of a function SET option to allow the settings to
 * persist only until the caller calls jdbc_reset_transmission_modes().  If
 * an error is thrown in between, guc.c will take care of undoing the
 * settings.
 *
 * The return value is the nestlevel that must be passed to
 * jdbc_reset_transmission_modes() to undo things.
 */
int
jdbc_set_transmission_modes(void)
{
	int			nestlevel = NewGUCNestLevel();

	/*
	 * The values set here should match what pg_dump does.  See also
	 * configure_remote_session in connection.c.
	 */
	if (DateStyle != USE_ISO_DATES)
		(void) set_config_option("datestyle", "ISO",
								 PGC_USERSET, PGC_S_SESSION,
								 GUC_ACTION_SAVE, true, 0, false);
	if (IntervalStyle != INTSTYLE_POSTGRES)
		(void) set_config_option("intervalstyle", "postgres",
								 PGC_USERSET, PGC_S_SESSION,
								 GUC_ACTION_SAVE, true, 0, false);
	if (extra_float_digits < 3)
		(void) set_config_option("extra_float_digits", "3",
								 PGC_USERSET, PGC_S_SESSION,
								 GUC_ACTION_SAVE, true, 0, false);
	/*
	 * In addition force restrictive search_path, in case there are any
	 * regproc or similar constants to be printed.
	 */
	(void) set_config_option("search_path", "pg_catalog",
							 PGC_USERSET, PGC_S_SESSION,
							 GUC_ACTION_SAVE, true, 0, false);

	return nestlevel;
}

/*
 * Undo the effects of jdbc_set_transmission_modes().
 */
void
jdbc_reset_transmission_modes(int nestlevel)
{
	AtEOXact_GUC(true, nestlevel);
}

/*
 * Utility routine to close a cursor.
 */
static void
jdbc_close_cursor(Jconn * conn, unsigned int cursor_number)
{
	char		sql[64];
	Jresult    *res;

	/* TODO: Make sure I don't need this at all */
	return;

	snprintf(sql, sizeof(sql), "CLOSE c%u", cursor_number);

	/*
	 * We don't use a PG_TRY block here, so be careful not to throw error
	 * without releasing the Jresult.
	 */
	res = jq_exec(conn, sql);
	if (*res != PGRES_COMMAND_OK)
		jdbc_fdw_report_error(ERROR, res, conn, true, sql);
	jq_clear(res);
}

/*
 * jdbc_prepare_foreign_modify Establish a prepared statement for execution
 * of INSERT/UPDATE/DELETE
 */
static void
jdbc_prepare_foreign_modify(jdbcFdwModifyState * fmstate)
{
	char		prep_name[NAMEDATALEN];
	Jresult    *res;

	/* Construct name we'll use for the prepared statement. */
	snprintf(prep_name, sizeof(prep_name), "pgsql_fdw_prep_%u",
			 jdbc_get_prep_stmt_number(fmstate->conn));

	ereport(DEBUG3, (errmsg("In jdbc_prepare_foreign_modify")));

	/*
	 * We intentionally do not specify parameter types here, but leave the
	 * remote server to derive them by default.  This avoids possible problems
	 * with the remote server using different type OIDs than we do.  All of
	 * the prepared statements we use in this module are simple enough that
	 * the remote server will make the right choices.
	 *
	 * We don't use a PG_TRY block here, so be careful not to throw error
	 * without releasing the Jresult.
	 */
	res = jq_prepare(fmstate->conn,
					 fmstate->query,
					 NULL,
					 &fmstate->resultSetID);

	if (*res != PGRES_COMMAND_OK)
		jdbc_fdw_report_error(ERROR, res, fmstate->conn, true, fmstate->query);
	jq_clear(res);

	/* This action shows that the prepare has been done. */
	fmstate->is_prepared = true;
}

/*
 * jdbcAnalyzeForeignTable Test whether analyzing this foreign table is
 * supported
 */
static bool
jdbcAnalyzeForeignTable(Relation relation,
						AcquireSampleRowsFunc *func,
						BlockNumber *totalpages)
{
	/* Not support now. */
	return false;
}


/*
 * Import a foreign schema
 */
static List *
jdbcImportForeignSchema(ImportForeignSchemaStmt *stmt, Oid serverOid)
{
	List	   *commands = NIL;
	List	   *commands_drop = NIL;
	bool		recreate = false;
	ForeignServer *server;
	UserMapping *user;
	Jconn	   *conn;
	StringInfoData buf;
	ListCell   *lc;
	ListCell   *table_lc;
	ListCell   *column_lc;
	List	   *schema_list = NIL;
	bool		first_column;

	elog(DEBUG1, "jdbc_fdw : %s", __func__);

	/* Parse statement options */
	foreach(lc, stmt->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "recreate") == 0)
			recreate = defGetBoolean(def);
		else
			ereport(ERROR,
					(errcode(ERRCODE_FDW_INVALID_OPTION_NAME),
					 errmsg("invalid option \"%s\"", def->defname)));
	}

	server = GetForeignServer(serverOid);
	user = GetUserMapping(GetUserId(), server->serverid);
	conn = jdbc_get_connection(server, user, false);

	schema_list = jq_get_schema_info(conn);
	if (schema_list != NIL)
	{
		initStringInfo(&buf);
		/* schema_list includes tablename and tableinfos */
		foreach(table_lc, schema_list)
		{
			JtableInfo *tmpTableInfo = (JtableInfo *) lfirst(table_lc);

			resetStringInfo(&buf);
			if (recreate)
			{
				appendStringInfo(&buf, "DROP FOREIGN TABLE IF EXISTS %s", tmpTableInfo->table_name);
				commands_drop = lappend(commands_drop, pstrdup(buf.data));
				resetStringInfo(&buf);
				appendStringInfo(&buf, "CREATE FOREIGN TABLE %s(", tmpTableInfo->table_name);
			}
			else
			{
				appendStringInfo(&buf, "CREATE FOREIGN TABLE IF NOT EXISTS %s(", tmpTableInfo->table_name);
			}
			first_column = true;
			foreach(column_lc, tmpTableInfo->column_info)
			{
				JcolumnInfo *columnInfo = (JcolumnInfo *) lfirst(column_lc);

				/* add ',' between columns */
				if (first_column)
				{
					first_column = false;
				}
				else
				{
					appendStringInfoString(&buf, ", ");
				}
				if (!strcmp(columnInfo->column_type, "UNKNOWN"))
				{
					elog(WARNING, "table: %s has unrecognizable column type for JDBC; skipping", tmpTableInfo->table_name);
					goto NEXT_COLUMN;
				}
				/* Print column name and type */
				appendStringInfo(&buf, "%s %s",
								 columnInfo->column_name,
								 columnInfo->column_type);
				/* Add option if the column is rowkey. */
				if (columnInfo->primary_key)
					appendStringInfoString(&buf, " OPTIONS (key 'true')");
			}
			appendStringInfo(&buf, ") SERVER %s;", quote_identifier(server->servername));
			commands = lappend(commands, pstrdup(buf.data));
	NEXT_COLUMN:
			resetStringInfo(&buf);
		}
		if (recreate)
		{
			jdbc_execute_commands(commands_drop);
			list_free_deep(commands_drop);
		}
	}
	return commands;
}

/*
 * Executes commands given by an argument.
 */
static void
jdbc_execute_commands(List *cmd_list)
{
	ListCell   *lc;

	if (SPI_connect() != SPI_OK_CONNECT)
		elog(WARNING, "SPI_connect failed");

	foreach(lc, cmd_list)
	{
		char	   *cmd = (char *) lfirst(lc);

		if (SPI_exec(cmd, 0) != SPI_OK_UTILITY)
			elog(WARNING, "SPI_exec failed: %s", cmd);
	}

	if (SPI_finish() != SPI_OK_FINISH)
		elog(WARNING, "SPI_finish failed");
}
