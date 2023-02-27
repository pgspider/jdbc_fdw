/*-------------------------------------------------------------------------
 *
 * jdbc_fdw.h
 *        Foreign-data wrapper for remote PostgreSQL servers
 *
 * Portions Copyright (c) 2012-2014, PostgreSQL Global Development Group
 *
 * Portions Copyright (c) 2021, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *        contrib/jdbc_fdw/jdbc_fdw.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef jdbc_fdw_H
#define jdbc_fdw_H

#include "access/tupdesc.h"
#if (PG_VERSION_NUM >= 120000)
#include "nodes/pathnodes.h"
#include "access/table.h"
#include "utils/float.h"
#include "optimizer/optimizer.h"
#else
#include "nodes/relation.h"
#include "optimizer/var.h"
#endif

#include "fmgr.h"
#include "foreign/foreign.h"
#include "lib/stringinfo.h"
#include "utils/rel.h"

#include "libpq-fe.h"
#include "jq.h"

#define CODE_VERSION	301
typedef struct jdbcAggref
{
	StringInfo	aggname;
	StringInfo	columnname;
}			jdbcAggref;

/*
 * FDW-specific planner information kept in RelOptInfo.fdw_private for a
 * foreign table.  This information is collected by jdbcGetForeignRelSize.
 */
typedef struct jdbcFdwRelationInfo
{
	/*
	 * True means that the relation can be pushed down. Always true for simple
	 * foreign scan.
	 */
	bool		pushdown_safe;

	/*
	 * baserestrictinfo clauses, broken down into safe and unsafe subsets.
	 */
	List	   *remote_conds;
	List	   *local_conds;

	/* Bitmap of attr numbers we need to fetch from the remote server. */
	Bitmapset  *attrs_used;

	/* Cost and selectivity of local_conds. */
	QualCost	local_conds_cost;
	Selectivity local_conds_sel;

	/* Estimated size and cost for a scan with baserestrictinfo quals. */
	double		rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;

	/*
	 * Costs excluding costs for transferring data from the foreign server
	 */
	Cost		rel_startup_cost;
	Cost		rel_total_cost;

	/* Options extracted from catalogs. */
	bool		use_remote_estimate;
	double		retrieved_rows;
	Cost		fdw_startup_cost;
	Cost		fdw_tuple_cost;
	List	   *shippable_extensions;	/* OIDs of whitelisted extensions */

	/* Cached catalog information. */
	ForeignTable *table;
	ForeignServer *server;
	UserMapping *user;			/* only set in use_remote_estimate mode */


	int			fetch_size;		/* fetch size for this remote table */

	/*
	 * Name of the relation, for use while EXPLAINing ForeignScan.  It is used
	 * for join and upper relations but is set for all relations. For a base
	 * relation, this is really just the RT index as a string; we convert that
	 * while producing EXPLAIN output.  For join and upper relations, the name
	 * indicates which base foreign tables are included and the join type or
	 * aggregation type used.
	 */
	StringInfo	relation_name;

	RelOptInfo *outerrel;
	/* Upper relation information */
	UpperRelationKind stage;

	/* Grouping information */
	List	   *grouped_tlist;

	/* Function pushdown surppot in target list */
	bool		is_tlist_func_pushdown;
}			jdbcFdwRelationInfo;


/* in jdbc_fdw.c */
extern int	jdbc_set_transmission_modes(void);
extern void jdbc_reset_transmission_modes(int nestlevel);

/* in connection.c */
extern Jconn * jdbc_get_connection(ForeignServer *server, UserMapping *user,
								   bool will_prep_stmt);
extern void jdbc_release_connection(Jconn * conn);
extern unsigned int jdbc_get_cursor_number(Jconn * conn);
extern unsigned int jdbc_get_prep_stmt_number(Jconn * conn);
extern void jdbc_fdw_report_error(int elevel, Jresult * res, Jconn * conn,
								  bool clear, const char *sql);

/* in option.c */
extern int	jdbc_extract_connection_options(List *defelems,
											const char **keywords,
											const char **values);

/* in deparse.c */
extern void jdbc_classify_conditions(PlannerInfo *root,
									 RelOptInfo *baserel,
									 List *input_conds,
									 List **remote_conds,
									 List **local_conds);
extern bool jdbc_is_foreign_expr(PlannerInfo *root,
								 RelOptInfo *baserel,
								 Expr *expr);
extern bool jdbc_is_foreign_param(PlannerInfo *root,
								  RelOptInfo *baserel,
								  Expr *expr);
extern void jdbc_deparse_select_stmt_for_rel(StringInfo buf, PlannerInfo *root,
											 RelOptInfo *foreignrel, List *remote_conds,
											 List *pathkeys, List **retrieved_attrs,
											 List **params_list, List *tlist, bool has_limit,
											 bool use_remote_estimate, List *fpinfo_remote_conds,
											 List *remote_join_conds, char *q_char);
extern void jdbc_deparse_select_sql(StringInfo buf, PlannerInfo *root,
									RelOptInfo *foreignrel, List *remote_conds,
									List *pathkeys, List **retrieved_attrs,
									List **params_list, List *tlist, bool has_limit,
									char *q_char);
extern void jdbc_append_where_clause(StringInfo buf,
									 PlannerInfo *root,
									 RelOptInfo *baserel,
									 List *exprs,
									 bool is_first,
									 List **params,
									 char *q_char);
extern void jdbc_deparse_insert_sql(StringInfo buf, PlannerInfo *root,
									Index rtindex, Relation rel,
									List *targetAttrs, List *returningList,
									List **retrieved_attrs, char *q_char);
extern void jdbc_deparse_update_sql(StringInfo buf, PlannerInfo *root,
									Index rtindex, Relation rel,
									List *targetAttrs, List *attnums,
									char *q_char);
extern void jdbc_deparse_delete_sql(StringInfo buf, PlannerInfo *root,
									Index rtindex, Relation rel,
									List *attname, char *q_char);
extern void jdbc_deparse_analyze_sql(StringInfo buf, Relation rel,
									 List **retrieved_attrs, char *q_char);
extern List *jdbc_build_tlist_to_deparse(RelOptInfo *foreignrel);

#endif							/* jdbc_fdw_H */
