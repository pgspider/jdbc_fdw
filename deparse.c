/*-------------------------------------------------------------------------
 *
 * deparse.c
 *		  Query deparser for jdbc_fdw
 *
 * This file includes functions that examine query WHERE clauses to see
 * whether they're safe to send to the remote server for execution, as
 * well as functions to construct the query text to be sent.  The latter
 * functionality is annoyingly duplicative of ruleutils.c, but there are
 * enough special considerations that it seems best to keep this separate.
 * One saving grace is that we only need deparse logic for node types that
 * we consider safe to send.
 *
 * We assume that the remote session's search_path is exactly "pg_catalog",
 * and thus we need schema-qualify all and only names outside pg_catalog.
 *
 * We do not consider that it is ever safe to send COLLATE expressions to
 * the remote server: it might not have the same collation names we do.
 * (Later we might consider it safe to send COLLATE "C", but even that would
 * fail on old remote servers.)  An expression is considered safe to send only
 * if all collations used in it are traceable to Var(s) of the foreign table.
 * That implies that if the remote server gets a different answer than we do,
 * the foreign table's columns are not marked with collations that match the
 * remote table's columns, which we can consider to be user error.
 *
 * Portions Copyright (c) 2012-2014, PostgreSQL Global Development Group
 *
 * Portions Copyright (c) 2021, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/jdbc_fdw/deparse.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "jdbc_fdw.h"

#include "access/heapam.h"
#include "access/htup_details.h"
#include "access/sysattr.h"
#include "access/transam.h"
#include "catalog/pg_collation.h"
#include "catalog/pg_namespace.h"
#include "catalog/pg_operator.h"
#include "catalog/pg_proc.h"
#include "catalog/pg_type.h"
#include "catalog/pg_aggregate.h"
#include "common/keywords.h"
#include "commands/defrem.h"
#include "nodes/nodeFuncs.h"
#include "optimizer/clauses.h"
#if PG_VERSION_NUM < 120000
#include "optimizer/var.h"
#else
#include "optimizer/optimizer.h"
#endif
#include "parser/parsetree.h"
#include "utils/builtins.h"
#include "utils/lsyscache.h"
#include "utils/syscache.h"
#include "utils/typcache.h"
#include "optimizer/tlist.h"


/*
 * Global context for jdbc_foreign_expr_walker's search of an expression
 * tree.
 */
typedef struct foreign_glob_cxt
{
	PlannerInfo *root;			/* global planner state */
	RelOptInfo *foreignrel;		/* the foreign relation we are planning for */
	Relids		relids;			/* relids of base relations in the underlying
								 * scan */
} foreign_glob_cxt;

/*
 * Local (per-tree-level) context for jdbc_foreign_expr_walker's search. This
 * is concerned with identifying collations used in the expression.
 */
typedef enum
{
	FDW_COLLATE_NONE,			/* expression is of a noncollatable type */
	FDW_COLLATE_SAFE,			/* collation derives from a foreign Var */
	FDW_COLLATE_UNSAFE			/* collation derives from something else */
} FDWCollateState;

typedef struct foreign_loc_cxt
{
	Oid			collation;		/* OID of current collation, if any */
	FDWCollateState state;		/* state of current collation choice */
} foreign_loc_cxt;

/*
 * Context for jdbc_deparse_expr
 */
typedef struct deparse_expr_cxt
{
	PlannerInfo *root;			/* global planner state */
	RelOptInfo *foreignrel;		/* the foreign relation we are planning for */
	RelOptInfo *scanrel;		/* the underlying scan relation. Same as
								 * foreignrel, when that represents a join or
								 * a base relation. */
	StringInfo	buf;			/* output buffer to append to */
	List	  **params_list;	/* exprs that will become remote Params */
	jdbcAggref *aggref;
	char	   *q_char;			/* Default identifier quote char */
} deparse_expr_cxt;

/*
 * Functions to determine whether an expression can be evaluated safely on
 * remote server.
 */
static bool jdbc_foreign_expr_walker(Node *node,
									 foreign_glob_cxt *glob_cxt,
									 foreign_loc_cxt *outer_cxt);
static bool jdbc_is_builtin(Oid procid);

/*
 * Functions to construct string representation of a node tree.
 */
static void jdbc_deparse_target_list(StringInfo buf,
									 PlannerInfo *root,
									 Index rtindex,
									 Relation rel,
									 Bitmapset *attrs_used,
									 bool qualify_col,
									 List **retrieved_attrs,
									 char *q_char);
static void jdbc_deparse_column_ref(StringInfo buf, int varno, int varattno,
									PlannerInfo *root, bool qualify_col, char *q_char);
static void jdbc_deparse_aggref(Aggref *node, deparse_expr_cxt *context);
static void jdbc_deparse_relation(StringInfo buf, Relation rel, char *q_char);
static void jdbc_deparse_string_literal(StringInfo buf, const char *val);
static void jdbc_deparse_expr(Expr *expr, deparse_expr_cxt *context);
static void jdbc_deparse_var(Var *node, deparse_expr_cxt *context);
static void jdbc_deparse_const(Const *node, deparse_expr_cxt *context);
#if PG_VERSION_NUM < 120000
static void jdbc_deparse_array_ref(ArrayRef * node, deparse_expr_cxt *context);
#else
static void jdbc_deparse_array_ref(SubscriptingRef *node, deparse_expr_cxt *context);
#endif
static void jdbc_deparse_func_expr(FuncExpr *node, deparse_expr_cxt *context);
static void jdbc_deparse_op_expr(OpExpr *node, deparse_expr_cxt *context);
static void jdbc_deparse_operator_name(StringInfo buf, Form_pg_operator opform);
static void jdbc_deparse_distinct_expr(DistinctExpr *node, deparse_expr_cxt *context);
static void jdbc_deparse_scalar_array_op_expr(ScalarArrayOpExpr *node,
											  deparse_expr_cxt *context);
static void jdbc_deparse_relabel_type(RelabelType *node, deparse_expr_cxt *context);
static void jdbc_deparse_bool_expr(BoolExpr *node, deparse_expr_cxt *context);
static void jdbc_deparse_null_test(NullTest *node, deparse_expr_cxt *context);
static void jdbc_append_limit_clause(deparse_expr_cxt *context);
static void jdbc_deparse_array_expr(ArrayExpr *node, deparse_expr_cxt *context);
static void jdbc_append_function_name(Oid funcid, deparse_expr_cxt *context);
static const char *jdbc_quote_identifier(const char *ident,
										 char *q_char,
										 bool quote_all_identifiers);
static bool jdbc_func_exist_in_list(char *funcname, const char **funclist);

/*
 * JdbcSupportedBuiltinAggFunction
 * List of supported builtin aggregate functions for Jdbc
 */
static const char *JdbcSupportedBuiltinAggFunction[] = {
	"sum",
	"avg",
	"max",
	"min",
	"count",
	"stddev",
	"stddev_pop",
	"stddev_samp",
	"var_pop",
	"var_samp",
	"variance",
	NULL};

/*
 * Deparse given targetlist and append it to context->buf.
 *
 * tlist is list of TargetEntry's which in turn contain Var nodes.
 *
 * retrieved_attrs is the list of continuously increasing integers starting
 * from 1. It has same number of entries as tlist.
 *
 */
static void
deparseExplicitTargetList(List *tlist,
						  bool is_returning,
						  List **retrieved_attrs,
						  deparse_expr_cxt *context)
{
	ListCell   *lc;
	StringInfo	buf = context->buf;
	int			i = 0;

	*retrieved_attrs = NIL;

	foreach(lc, tlist)
	{
		TargetEntry *tle = lfirst_node(TargetEntry, lc);

		if (i > 0)
			appendStringInfoString(buf, ", ");

		jdbc_deparse_expr((Expr *) tle->expr, context);

		*retrieved_attrs = lappend_int(*retrieved_attrs, i + 1);
		i++;
	}

	if (i == 0 && !is_returning)
		appendStringInfoString(buf, "NULL");
}


/*
 * Examine each qual clause in input_conds, and classify them into two
 * groups, which are returned as two lists: - remote_conds contains
 * expressions that can be evaluated remotely - local_conds contains
 * expressions that can't be evaluated remotely
 */
void
jdbc_classify_conditions(PlannerInfo *root,
						 RelOptInfo *baserel,
						 List *input_conds,
						 List **remote_conds,
						 List **local_conds)
{
	ListCell   *lc;

	*remote_conds = NIL;
	*local_conds = NIL;

	foreach(lc, input_conds)
	{
		RestrictInfo *ri = (RestrictInfo *) lfirst(lc);

		if (jdbc_is_foreign_expr(root, baserel, ri->clause))
			*remote_conds = lappend(*remote_conds, ri);
		else
			*local_conds = lappend(*local_conds, ri);
	}
}

/*
 * Deparse LIMIT/OFFSET clause.
 */
static void
jdbc_append_limit_clause(deparse_expr_cxt *context)
{
	PlannerInfo *root = context->root;
	StringInfo	buf = context->buf;
	int			nestlevel;

	/* Make sure any constants in the exprs are printed portably */
	nestlevel = jdbc_set_transmission_modes();

	if (root->parse->limitCount)
	{
		appendStringInfoString(buf, " LIMIT ");
		jdbc_deparse_expr((Expr *) root->parse->limitCount, context);
	}
	if (root->parse->limitOffset)
	{
		appendStringInfoString(buf, " OFFSET ");
		jdbc_deparse_expr((Expr *) root->parse->limitOffset, context);
	}

	jdbc_reset_transmission_modes(nestlevel);
}

/*
 * Returns true if given expr is safe to evaluate on the foreign server.
 */
bool
jdbc_is_foreign_expr(PlannerInfo *root,
					 RelOptInfo *baserel,
					 Expr *expr)
{
	foreign_glob_cxt glob_cxt;
	foreign_loc_cxt loc_cxt;

	/*
	 * Check that the expression consists of nodes that are safe to execute
	 * remotely.
	 */
	glob_cxt.root = root;
	glob_cxt.foreignrel = baserel;
	loc_cxt.collation = InvalidOid;
	loc_cxt.state = FDW_COLLATE_NONE;
	if (!jdbc_foreign_expr_walker((Node *) expr, &glob_cxt, &loc_cxt))
		return false;

	/* Expressions examined here should be boolean, ie noncollatable */
	Assert(loc_cxt.collation == InvalidOid);
	Assert(loc_cxt.state == FDW_COLLATE_NONE);

	/*
	 * An expression which includes any mutable functions can't be sent over
	 * because its result is not stable.  For example, sending now() remote
	 * side could cause confusion from clock offsets.  Future versions might
	 * be able to make this choice with more granularity. (We check this last
	 * because it requires a lot of expensive catalog lookups.)
	 */
	if (contain_mutable_functions((Node *) expr))
		return false;

	/* OK to evaluate on the remote server */
	return true;
}

/*
 * Returns true if given expr is something we'd have to send the value of to
 * the foreign server.
 *
 * This should return true when the expression is a shippable node that
 * jdbc_deparse_expr would add to context->params_list.  Note that we don't
 * care if the expression *contains* such a node, only whether one appears at
 * top level.  We need this to detect cases where setrefs.c would recognize a
 * false match between an fdw_exprs item (which came from the params_list)
 * and an entry in fdw_scan_tlist (which we're considering putting the given
 * expression into).
 */
bool
jdbc_is_foreign_param(PlannerInfo *root,
					  RelOptInfo *baserel,
					  Expr *expr)
{
	if (expr == NULL)
		return false;

	switch (nodeTag(expr))
	{
		case T_Var:
			{
				/* It would have to be sent unless it's a foreign Var */
				Var		   *var = (Var *) expr;
				jdbcFdwRelationInfo *fpinfo = (jdbcFdwRelationInfo *) (baserel->fdw_private);
				Relids		relids;

				if (IS_UPPER_REL(baserel))
					relids = fpinfo->outerrel->relids;
				else
					relids = baserel->relids;

				if (bms_is_member(var->varno, relids) && var->varlevelsup == 0)
					return false;	/* foreign Var, so not a param */
				else
					return true;	/* it'd have to be a param */
				break;
			}
		case T_Param:
			/* Params always have to be sent to the foreign server */
			return true;
		default:
			break;
	}
	return false;
}

/*
 * Check if expression is safe to execute remotely, and return true if so.
 *
 * In addition, *outer_cxt is updated with collation information.
 *
 * We must check that the expression contains only node types we can deparse,
 * that all types/functions/operators are safe to send (which we approximate
 * as being built-in), and that all collations used in the expression derive
 * from Vars of the foreign table.  Because of the latter, the logic is
 * pretty close to assign_collations_walker() in parse_collate.c, though we
 * can assume here that the given expression is valid.
 */
static bool
jdbc_foreign_expr_walker(Node *node,
						 foreign_glob_cxt *glob_cxt,
						 foreign_loc_cxt *outer_cxt)
{
	bool		check_type = true;
	foreign_loc_cxt inner_cxt;
	Oid			collation;
	FDWCollateState state;

	/* Need do nothing for empty subexpressions */
	if (node == NULL)
		return true;

	/* Set up inner_cxt for possible recursion to child nodes */
	inner_cxt.collation = InvalidOid;
	inner_cxt.state = FDW_COLLATE_NONE;

	switch (nodeTag(node))
	{
		case T_Var:
			{
				Var		   *var = (Var *) node;

				/*
				 * If the Var is from the foreign table, we consider its
				 * collation (if any) safe to use.  If it is from another
				 * table, we treat its collation the same way as we would a
				 * Param's collation, ie it's not safe for it to have a
				 * non-default collation.
				 */
				if (var->varno == glob_cxt->foreignrel->relid &&
					var->varlevelsup == 0)
				{
					/* Var belongs to foreign table */

					/*
					 * System columns other than ctid should not be sent to
					 * the remote, since we don't make any effort to ensure
					 * that local and remote values match (tableoid, in
					 * particular, almost certainly doesn't match).
					 */
					if (var->varattno < 0 &&
						var->varattno != SelfItemPointerAttributeNumber)
						return false;

					/* Else check the collation */
					collation = var->varcollid;
					state = OidIsValid(collation) ? FDW_COLLATE_SAFE : FDW_COLLATE_NONE;
				}
				else
				{
					/* Var belongs to some other table */
					if (var->varcollid != InvalidOid &&
						var->varcollid != DEFAULT_COLLATION_OID)
						return false;

					/*
					 * We can consider that it doesn't set collation
					 */
					collation = InvalidOid;
					state = FDW_COLLATE_NONE;
				}
			}
			break;
		case T_Const:
			{
				Const	   *c = (Const *) node;

				/*
				 * If the constant has nondefault collation, either it's of a
				 * non-builtin type, or it reflects folding of a CollateExpr;
				 * either way, it's unsafe to send to the remote.
				 */
				if (c->constcollid != InvalidOid &&
					c->constcollid != DEFAULT_COLLATION_OID)
					return false;

				/*
				 * Otherwise, we can consider that it doesn't set collation
				 */
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
			}
			break;
		case T_Param:
			{
				/* Parameter is unsupported */
				return false;
			}
			break;
#if PG_VERSION_NUM < 120000
		case T_ArrayRef:
			{
				ArrayRef   *ar = (ArrayRef *) node;;
#else
		case T_SubscriptingRef:
			{
				SubscriptingRef *ar = (SubscriptingRef *) node;
#endif

				/* Assignment should not be in restrictions. */
				if (ar->refassgnexpr != NULL)
					return false;

				/*
				 * Recurse into the remaining subexpressions.  The container
				 * subscripts will not affect collation of the SubscriptingRef
				 * result, so do those first and reset inner_cxt afterwards.
				 */
				if (!jdbc_foreign_expr_walker((Node *) ar->refupperindexpr,
											  glob_cxt, &inner_cxt))
					return false;
				inner_cxt.collation = InvalidOid;
				inner_cxt.state = FDW_COLLATE_NONE;
				if (!jdbc_foreign_expr_walker((Node *) ar->reflowerindexpr,
											  glob_cxt, &inner_cxt))
					return false;
				inner_cxt.collation = InvalidOid;
				inner_cxt.state = FDW_COLLATE_NONE;
				if (!jdbc_foreign_expr_walker((Node *) ar->refexpr,
											  glob_cxt, &inner_cxt))
					return false;

				/*
				 * Array subscripting should yield same collation as input,
				 * but for safety use same logic as for function nodes.
				 */
				collation = ar->refcollid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_FuncExpr:
			{
				FuncExpr   *fe = (FuncExpr *) node;

				/* Does not support push down explicit cast function */
				if (fe->funcformat == COERCE_EXPLICIT_CAST)
					return false;

				/*
				 * If function used by the expression is not built-in, it
				 * can't be sent to remote because it might have incompatible
				 * semantics on remote side.
				 */
				if (!jdbc_is_builtin(fe->funcid))
					return false;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!jdbc_foreign_expr_walker((Node *) fe->args,
											  glob_cxt, &inner_cxt))
					return false;

				/*
				 * If function's input collation is not derived from a foreign
				 * Var, it can't be sent to remote.
				 */
				if (fe->inputcollid == InvalidOid)
					 /* OK, inputs are all noncollatable */ ;
				else if (inner_cxt.state != FDW_COLLATE_SAFE ||
						 fe->inputcollid != inner_cxt.collation)
					return false;

				/*
				 * Detect whether node is introducing a collation not derived
				 * from a foreign Var.  (If so, we just mark it unsafe for now
				 * rather than immediately returning false, since the parent
				 * node might not care.)
				 */
				collation = fe->funccollid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_OpExpr:
		case T_DistinctExpr:	/* struct-equivalent to OpExpr */
			{
				OpExpr	   *oe = (OpExpr *) node;

				/*
				 * Similarly, only built-in operators can be sent to remote.
				 * (If the operator is, surely its underlying function is
				 * too.)
				 */
				if (!jdbc_is_builtin(oe->opno))
					return false;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!jdbc_foreign_expr_walker((Node *) oe->args,
											  glob_cxt, &inner_cxt))
					return false;

				/*
				 * If operator's input collation is not derived from a foreign
				 * Var, it can't be sent to remote.
				 */
				if (oe->inputcollid == InvalidOid)
					 /* OK, inputs are all noncollatable */ ;
				else if (inner_cxt.state != FDW_COLLATE_SAFE ||
						 oe->inputcollid != inner_cxt.collation)
					return false;

				/* Result-collation handling is same as for functions */
				collation = oe->opcollid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_ScalarArrayOpExpr:
			{
				ScalarArrayOpExpr *oe = (ScalarArrayOpExpr *) node;

				/*
				 * Again, only built-in operators can be sent to remote.
				 */
				if (!jdbc_is_builtin(oe->opno))
					return false;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!jdbc_foreign_expr_walker((Node *) oe->args,
											  glob_cxt, &inner_cxt))
					return false;

				/*
				 * If operator's input collation is not derived from a foreign
				 * Var, it can't be sent to remote.
				 */
				if (oe->inputcollid == InvalidOid)
					 /* OK, inputs are all noncollatable */ ;
				else if (inner_cxt.state != FDW_COLLATE_SAFE ||
						 oe->inputcollid != inner_cxt.collation)
					return false;

				/* Output is always boolean and so noncollatable. */
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
			}
			break;
		case T_RelabelType:
			{
				RelabelType *r = (RelabelType *) node;

				/*
				 * Recurse to input subexpression.
				 */
				if (!jdbc_foreign_expr_walker((Node *) r->arg,
											  glob_cxt, &inner_cxt))
					return false;

				/*
				 * RelabelType must not introduce a collation not derived from
				 * an input foreign Var.
				 */
				collation = r->resultcollid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_BoolExpr:
			{
				BoolExpr   *b = (BoolExpr *) node;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!jdbc_foreign_expr_walker((Node *) b->args,
											  glob_cxt, &inner_cxt))
					return false;

				/* Output is always boolean and so noncollatable. */
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
			}
			break;
		case T_NullTest:
			{
				NullTest   *nt = (NullTest *) node;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!jdbc_foreign_expr_walker((Node *) nt->arg,
											  glob_cxt, &inner_cxt))
					return false;

				/* Output is always boolean and so noncollatable. */
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
			}
			break;
		case T_ArrayExpr:
			{
				ArrayExpr  *a = (ArrayExpr *) node;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!jdbc_foreign_expr_walker((Node *) a->elements,
											  glob_cxt, &inner_cxt))
					return false;

				/*
				 * ArrayExpr must not introduce a collation not derived from
				 * an input foreign Var.
				 */
				collation = a->array_collid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_List:
			{
				List	   *l = (List *) node;
				ListCell   *lc;

				/*
				 * Recurse to component subexpressions.
				 */
				foreach(lc, l)
				{
					if (!jdbc_foreign_expr_walker((Node *) lfirst(lc),
												  glob_cxt, &inner_cxt))
						return false;
				}

				/*
				 * When processing a list, collation state just bubbles up
				 * from the list elements.
				 */
				collation = inner_cxt.collation;
				state = inner_cxt.state;

				/* Don't apply exprType() to the list. */
				check_type = false;
			}
			break;
		case T_Aggref:
			{
				Aggref	   *agg = (Aggref *) node;
				ListCell   *lc;
				char	   *opername = NULL;
				HeapTuple	tuple;

				/* get function name */
				tuple = SearchSysCache1(PROCOID, ObjectIdGetDatum(agg->aggfnoid));
				if (!HeapTupleIsValid(tuple))
				{
					elog(ERROR, "cache lookup failed for function %u", agg->aggfnoid);
				}
				opername = pstrdup(((Form_pg_proc) GETSTRUCT(tuple))->proname.data);
				ReleaseSysCache(tuple);

				/* Only function exist in JdbcSupportedBuiltinAggFunction can be passed to JDBC */
				if (!jdbc_func_exist_in_list(opername, JdbcSupportedBuiltinAggFunction))
					return false;

				/* Not safe to pushdown when not in grouping context */
				if (glob_cxt->foreignrel->reloptkind != RELOPT_UPPER_REL)
					return false;

				/* Only non-split aggregates are pushable. */
				if (agg->aggsplit != AGGSPLIT_SIMPLE)
					return false;

				/*
				 * Does not push down DISTINCT inside aggregate function
				 * because of undefined behavior of the GridDB JDBC driver.
				 * TODO: We may hanlde DISTINCT in future with new release
				 * of GridDB JDBC driver.
				 */
				if (agg->aggdistinct != NIL)
					return false;

				/*
				 * Recurse to input args. aggdirectargs, aggorder and
				 * aggdistinct are all present in args, so no need to check
				 * their shippability explicitly.
				 */
				foreach(lc, agg->args)
				{
					Node	   *n = (Node *) lfirst(lc);

					/*
					 * If TargetEntry, extract the expression from it
					 */
					if (IsA(n, TargetEntry))
					{
						TargetEntry *tle = (TargetEntry *) n;

						n = (Node *) tle->expr;
					}

					if (!jdbc_foreign_expr_walker(n, glob_cxt, &inner_cxt))
						return false;
				}

				if (agg->aggorder || agg->aggfilter)
				{
					return false;
				}

				/*
				 * If aggregate's input collation is not derived from a
				 * foreign Var, it can't be sent to remote.
				 */
				if (agg->inputcollid == InvalidOid)
					 /* OK, inputs are all noncollatable */ ;
				else if (inner_cxt.state != FDW_COLLATE_SAFE ||
						 agg->inputcollid != inner_cxt.collation)
					return false;

				/*
				 * Detect whether node is introducing a collation not derived
				 * from a foreign Var.  (If so, we just mark it unsafe for now
				 * rather than immediately returning false, since the parent
				 * node might not care.)
				 */
				collation = agg->aggcollid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else if (collation == DEFAULT_COLLATION_OID)
					state = FDW_COLLATE_NONE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		default:

			/*
			 * If it's anything else, assume it's unsafe.  This list can be
			 * expanded later, but don't forget to add deparse support below.
			 */
			return false;
	}

	/*
	 * If result type of given expression is not built-in, it can't be sent to
	 * remote because it might have incompatible semantics on remote side.
	 */
	if (check_type && !jdbc_is_builtin(exprType(node)))
		return false;

	/*
	 * Now, merge my collation information into my parent's state.
	 */
	if (state > outer_cxt->state)
	{
		/* Override previous parent state */
		outer_cxt->collation = collation;
		outer_cxt->state = state;
	}
	else if (state == outer_cxt->state)
	{
		/* Merge, or detect error if there's a collation conflict */
		switch (state)
		{
			case FDW_COLLATE_NONE:
				/* Nothing + nothing is still nothing */
				break;
			case FDW_COLLATE_SAFE:
				if (collation != outer_cxt->collation)
				{
					/*
					 * Non-default collation always beats default.
					 */
					if (outer_cxt->collation == DEFAULT_COLLATION_OID)
					{
						/* Override previous parent state */
						outer_cxt->collation = collation;
					}
					else if (collation != DEFAULT_COLLATION_OID)
					{
						/*
						 * Conflict; show state as indeterminate.  We don't
						 * want to "return false" right away, since parent
						 * node might not care about collation.
						 */
						outer_cxt->state = FDW_COLLATE_UNSAFE;
					}
				}
				break;
			case FDW_COLLATE_UNSAFE:
				/* We're still conflicted ... */
				break;
		}
	}

	/* It looks OK */
	return true;
}

/*
 * Deparse SELECT statement for given relation into buf.
 */
void
jdbc_deparse_select_stmt_for_rel(StringInfo buf,
								 PlannerInfo *root,
								 RelOptInfo *baserel,
								 List *remote_conds,
								 List *pathkeys,
								 List **retrieved_attrs,
								 List **params_list,
								 List *tlist,
								 bool has_limit,
								 bool use_remote_estimate,
								 List *fpinfo_remote_conds,
								 List *remote_join_conds,
								 char *q_char)
{
	jdbcFdwRelationInfo *fpinfo = (jdbcFdwRelationInfo *) baserel->fdw_private;
	List	   *quals;
	deparse_expr_cxt context;

	/* Fill portions of context common to join and base relation */
	context.buf = buf;
	context.root = root;
	context.foreignrel = baserel;
	context.params_list = params_list;
	context.scanrel = IS_UPPER_REL(baserel) ? fpinfo->outerrel : baserel;


	jdbc_deparse_select_sql(buf, root, baserel, remote_conds,
							pathkeys, retrieved_attrs, params_list,
							tlist, has_limit, q_char);


	/*
	 * For upper relations, the WHERE clause is built from the remote
	 * conditions of the underlying scan relation; otherwise, we can use the
	 * supplied list of remote conditions directly.
	 */
	if (IS_UPPER_REL(baserel))
	{
		jdbcFdwRelationInfo *ofpinfo;

		ofpinfo = (jdbcFdwRelationInfo *) fpinfo->outerrel->fdw_private;
		quals = ofpinfo->remote_conds;
	}
	else
		quals = remote_conds;

	/*
	 * Construct WHERE clause
	 */
	if (use_remote_estimate)
	{
		if (fpinfo_remote_conds)
			jdbc_append_where_clause(buf, root, baserel, fpinfo_remote_conds,
									 true, NULL, q_char);
		if (remote_join_conds)
			jdbc_append_where_clause(buf, root, baserel, remote_join_conds,
									 (fpinfo_remote_conds == NIL), NULL, q_char);
	}
	else
	{
		if (quals)
		{
			jdbc_append_where_clause(buf, root, baserel, quals,
									 true, params_list, q_char);
		}
	}

	/* Add LIMIT clause if necessary */
	if (has_limit)
		jdbc_append_limit_clause(&context);


}

/*
 * Return true if given object is one of PostgreSQL's built-in objects.
 *
 * We use FirstBootstrapObjectId as the cutoff, so that we only consider
 * objects with hand-assigned OIDs to be "built in", not for instance any
 * function or type defined in the information_schema.
 *
 * Our constraints for dealing with types are tighter than they are for
 * functions or operators: we want to accept only types that are in
 * pg_catalog, else format_type might incorrectly fail to schema-qualify
 * their names. (This could be fixed with some changes to format_type, but
 * for now there's no need.)  Thus we must exclude information_schema types.
 *
 * XXX there is a problem with this, which is that the set of built-in
 * objects expands over time.  Something that is built-in to us might not be
 * known to the remote server, if it's of an older version.  But keeping
 * track of that would be a huge exercise.
 */
static bool
jdbc_is_builtin(Oid oid)
{
	return (oid < FirstGenbkiObjectId);
}


/*
 * Construct a simple SELECT statement that retrieves desired columns of the
 * specified foreign table, and append it to "buf".  The output contains just
 * "SELECT ... FROM tablename".
 *
 * We also create an integer List of the columns being retrieved, which is
 * returned to *retrieved_attrs.
 */
void
jdbc_deparse_select_sql(StringInfo buf,
						PlannerInfo *root,
						RelOptInfo *baserel,
						List *remote_conds,
						List *pathkeys,
						List **retrieved_attrs,
						List **params_list,
						List *tlist,
						bool has_limit,
						char *q_char)
{
	RangeTblEntry *rte;
	Relation	rel;
	jdbcFdwRelationInfo *fpinfo = (jdbcFdwRelationInfo *) baserel->fdw_private;
	deparse_expr_cxt context;

	/* Fill portions of context common to join and base relation */
	context.buf = buf;
	context.root = root;
	context.foreignrel = baserel;
	context.params_list = params_list;
	context.scanrel = IS_UPPER_REL(baserel) ? fpinfo->outerrel : baserel;
	context.q_char = q_char;

	rte = planner_rt_fetch(context.scanrel->relid, root);

	/*
	 * Core code already has some lock on each rel being planned, so we can
	 * use NoLock here.
	 */
#if PG_VERSION_NUM < 130000
	rel = heap_open(rte->relid, NoLock);
#else
	rel = table_open(rte->relid, NoLock);
#endif

	/*
	 * Construct SELECT list
	 */
	appendStringInfoString(buf, "SELECT ");
	if (IS_UPPER_REL(baserel) || fpinfo->is_tlist_func_pushdown == true)
	{
		deparseExplicitTargetList(tlist, false, retrieved_attrs, &context);
	}
	else
	{
		jdbc_deparse_target_list(buf, root, baserel->relid, rel, fpinfo->attrs_used,
								 false, retrieved_attrs, q_char);
	}

	/*
	 * Construct FROM clause
	 */
	appendStringInfoString(buf, " FROM ");
	jdbc_deparse_relation(buf, rel, q_char);

#if PG_VERSION_NUM < 130000
	heap_close(rel, NoLock);
#else
	table_close(rel, NoLock);
#endif
}

/*
 * Emit a target list that retrieves the columns specified in attrs_used.
 * This is used for both SELECT and RETURNING targetlists.
 *
 * The tlist text is appended to buf, and we also create an integer List of
 * the columns being retrieved, which is returned to *retrieved_attrs.
 *
 * If qualify_col is true, add relation alias before the column name.
 */
static void
jdbc_deparse_target_list(StringInfo buf,
						 PlannerInfo *root,
						 Index rtindex,
						 Relation rel,
						 Bitmapset *attrs_used,
						 bool qualify_col,
						 List **retrieved_attrs,
						 char *q_char)
{
	TupleDesc	tupdesc = RelationGetDescr(rel);
	bool		have_wholerow;
	bool		first;
	int			i;

	*retrieved_attrs = NIL;

	/* If there's a whole-row reference, we'll need all the columns. */
	have_wholerow = bms_is_member(0 - FirstLowInvalidHeapAttributeNumber,
								  attrs_used);

	first = true;
	for (i = 1; i <= tupdesc->natts; i++)
	{
		Form_pg_attribute attr = TupleDescAttr(tupdesc, i - 1);

		/* Ignore dropped attributes. */
		if (attr->attisdropped)
			continue;

		if (have_wholerow ||
			bms_is_member(i - FirstLowInvalidHeapAttributeNumber,
						  attrs_used))
		{
			if (!first)
				appendStringInfoString(buf, ", ");
			first = false;

			jdbc_deparse_column_ref(buf, rtindex, i, root, qualify_col, q_char);

			*retrieved_attrs = lappend_int(*retrieved_attrs, i);
		}
	}

	/* Don't generate bad syntax if no undropped columns */
	if (first)
		appendStringInfoString(buf, "NULL");
}

/*
 * Deparse WHERE clauses in given list of RestrictInfos and append them to
 * buf.
 *
 * baserel is the foreign table we're planning for.
 *
 * If no WHERE clause already exists in the buffer, is_first should be true.
 *
 * If params is not NULL, it receives a list of Params and other-relation
 * Vars used in the clauses; these values must be transmitted to the remote
 * server as parameter values.
 *
 * If params is NULL, we're generating the query for EXPLAIN purposes, so
 * Params and other-relation Vars should be replaced by dummy values.
 */
void
jdbc_append_where_clause(StringInfo buf,
						 PlannerInfo *root,
						 RelOptInfo *baserel,
						 List *exprs,
						 bool is_first,
						 List **params,
						 char *q_char)
{
	deparse_expr_cxt context;
	int			nestlevel;
	ListCell   *lc;
	jdbcFdwRelationInfo *fpinfo = (jdbcFdwRelationInfo *) baserel->fdw_private;

	if (params)
		*params = NIL;			/* initialize result list to empty */

	/* Set up context struct for recursion */
	context.root = root;
	context.foreignrel = baserel;
	context.buf = buf;
	context.params_list = params;
	context.scanrel = IS_UPPER_REL(baserel) ? fpinfo->outerrel : baserel;
	context.q_char = q_char;

	/* Make sure any constants in the exprs are printed portably */
	nestlevel = jdbc_set_transmission_modes();

	foreach(lc, exprs)
	{
		RestrictInfo *ri = (RestrictInfo *) lfirst(lc);

		/*
		 * Connect expressions with "AND" and parenthesize each condition.
		 */
		if (is_first)
			appendStringInfoString(buf, " WHERE ");
		else
			appendStringInfoString(buf, " AND ");

		appendStringInfoChar(buf, '(');
		jdbc_deparse_expr(ri->clause, &context);
		appendStringInfoChar(buf, ')');

		is_first = false;
	}

	jdbc_reset_transmission_modes(nestlevel);
}

/*
 * deparse remote INSERT statement
 *
 * The statement text is appended to buf, and we also create an integer List
 * of the columns being retrieved by RETURNING (if any), which is returned to
 * *retrieved_attrs.
 */
void
jdbc_deparse_insert_sql(StringInfo buf, PlannerInfo *root,
						Index rtindex, Relation rel,
						List *targetAttrs, List *returningList,
						List **retrieved_attrs, char *q_char)
{
	AttrNumber	pindex;
	bool		first;
	ListCell   *lc;

	appendStringInfoString(buf, "INSERT INTO ");
	jdbc_deparse_relation(buf, rel, q_char);

	if (targetAttrs)
	{
		appendStringInfoChar(buf, '(');

		first = true;
		foreach(lc, targetAttrs)
		{
			int			attnum = lfirst_int(lc);

			if (!first)
				appendStringInfoString(buf, ", ");
			first = false;

			jdbc_deparse_column_ref(buf, rtindex, attnum, root, false, q_char);
		}

		appendStringInfoString(buf, ") VALUES (");

		pindex = 1;
		first = true;
		foreach(lc, targetAttrs)
		{
			if (!first)
				appendStringInfoString(buf, ", ");
			first = false;

			appendStringInfo(buf, "?");
			pindex++;
		}

		appendStringInfoChar(buf, ')');
	}
	else
		appendStringInfoString(buf, " DEFAULT VALUES");
}

/*
 * deparse remote UPDATE statement
 *
 * The statement text is appended to buf, and we also create an integer List
 * of the columns being retrieved by RETURNING (if any), which is returned to
 * *retrieved_attrs.
 */
void
jdbc_deparse_update_sql(StringInfo buf, PlannerInfo *root,
						Index rtindex, Relation rel,
						List *targetAttrs, List *attnums,
						char *q_char)
{
	bool		first;
	ListCell   *lc;
	int			i;

	appendStringInfoString(buf, "UPDATE ");
	jdbc_deparse_relation(buf, rel, q_char);
	appendStringInfoString(buf, " SET ");

	first = true;
	foreach(lc, targetAttrs)
	{
		int			attnum = lfirst_int(lc);

		if (!first)
			appendStringInfoString(buf, ", ");
		first = false;

		jdbc_deparse_column_ref(buf, rtindex, attnum, root, false, q_char);
		appendStringInfo(buf, " = ?");
	}
	i = 0;
	foreach(lc, attnums)
	{
		int			attnum = lfirst_int(lc);

		appendStringInfo(buf, i == 0 ? " WHERE " : " AND ");
		jdbc_deparse_column_ref(buf, rtindex, attnum, root, false, q_char);
		appendStringInfo(buf, "=?");
		i++;
	}
}

/*
 * deparse remote DELETE statement
 *
 * The statement text is appended to buf, and we also create an integer List
 * of the columns being retrieved by RETURNING (if any), which is returned to
 * *retrieved_attrs.
 */
void
jdbc_deparse_delete_sql(StringInfo buf, PlannerInfo *root,
						Index rtindex, Relation rel,
						List *attname, char *q_char)
{
	int			i = 0;
	ListCell   *lc;

	appendStringInfoString(buf, "DELETE FROM ");
	jdbc_deparse_relation(buf, rel, q_char);
	foreach(lc, attname)
	{
		int			attnum = lfirst_int(lc);

		appendStringInfo(buf, i == 0 ? " WHERE " : " AND ");
		jdbc_deparse_column_ref(buf, rtindex, attnum, root, false, q_char);
		appendStringInfo(buf, "=?");
		i++;
	}
}

/*
 * Construct SELECT statement to acquire sample rows of given relation.
 *
 * SELECT command is appended to buf, and list of columns retrieved is
 * returned to *retrieved_attrs.
 */
void
jdbc_deparse_analyze_sql(StringInfo buf, Relation rel, List **retrieved_attrs, char *q_char)
{
	Oid			relid = RelationGetRelid(rel);
	TupleDesc	tupdesc = RelationGetDescr(rel);
	int			i;
	char	   *colname;
	List	   *options;
	ListCell   *lc;
	bool		first = true;

	*retrieved_attrs = NIL;

	appendStringInfoString(buf, "SELECT ");
	for (i = 0; i < tupdesc->natts; i++)
	{
		Form_pg_attribute attr = TupleDescAttr(tupdesc, i - 1);

		/* Ignore dropped columns. */
		if (attr->attisdropped)
			continue;

		if (!first)
			appendStringInfoString(buf, ", ");
		first = false;

		/* Use attribute name or column_name option. */
		colname = NameStr(TupleDescAttr(tupdesc, i)->attname);
		options = GetForeignColumnOptions(relid, i + 1);

		foreach(lc, options)
		{
			DefElem    *def = (DefElem *) lfirst(lc);

			if (strcmp(def->defname, "column_name") == 0)
			{
				colname = defGetString(def);
				break;
			}
		}

		appendStringInfoString(buf, jdbc_quote_identifier(colname, q_char, false));

		*retrieved_attrs = lappend_int(*retrieved_attrs, i + 1);
	}

	/* Don't generate bad syntax for zero-column relation. */
	if (first)
		appendStringInfoString(buf, "NULL");

	/*
	 * Construct FROM clause
	 */
	appendStringInfoString(buf, " FROM ");
	jdbc_deparse_relation(buf, rel, q_char);
}

/*
 * Construct name to use for given column, and emit it into buf. If it has a
 * column_name FDW option, use that instead of attribute name.
 */
static void
jdbc_deparse_column_ref(StringInfo buf, int varno, int varattno, PlannerInfo *root,
						bool qualify_col, char *q_char)
{
	RangeTblEntry *rte;
	char	   *colname = NULL;
	List	   *options;
	ListCell   *lc;

	/* varno must not be any of OUTER_VAR, INNER_VAR and INDEX_VAR. */
	Assert(!IS_SPECIAL_VARNO(varno));

	/* Get RangeTblEntry from array in PlannerInfo. */
	rte = planner_rt_fetch(varno, root);

	/*
	 * If it's a column of a foreign table, and it has the column_name FDW
	 * option, use that value.
	 */
	options = GetForeignColumnOptions(rte->relid, varattno);
	foreach(lc, options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "column_name") == 0)
		{
			colname = defGetString(def);
			break;
		}
	}

	/*
	 * If it's a column of a regular table or it doesn't have column_name FDW
	 * option, use attribute name.
	 */
	if (colname == NULL)
#if PG_VERSION_NUM >= 110000
		colname = get_attname(rte->relid, varattno, false);
#else
		colname = get_relid_attribute_name(rte->relid, varattno);
#endif

	appendStringInfoString(buf, jdbc_quote_identifier(colname, q_char, false));
}

/*
 * Build the targetlist for given relation to be deparsed as SELECT clause.
 *
 * The output targetlist contains the columns that need to be fetched from
 * the foreign server for the given relation.  If foreignrel is an upper
 * relation, then the output targetlist can also contain expressions to be
 * evaluated on foreign server.
 */
List *
jdbc_build_tlist_to_deparse(RelOptInfo *foreignrel)
{
	List	   *tlist = NIL;
	jdbcFdwRelationInfo *fpinfo = (jdbcFdwRelationInfo *) foreignrel->fdw_private;
	ListCell   *lc;

	/*
	 * For an upper relation, we have already built the target list while
	 * checking shippability, so just return that.
	 */
	if (IS_UPPER_REL(foreignrel))
		return fpinfo->grouped_tlist;

	/*
	 * We require columns specified in foreignrel->reltarget->exprs and those
	 * required for evaluating the local conditions.
	 */
	tlist = add_to_flat_tlist(tlist,
							  pull_var_clause((Node *) foreignrel->reltarget->exprs,
											  PVC_RECURSE_PLACEHOLDERS));
	foreach(lc, fpinfo->local_conds)
	{
		RestrictInfo *rinfo = lfirst_node(RestrictInfo, lc);

		tlist = add_to_flat_tlist(tlist,
								  pull_var_clause((Node *) rinfo->clause,
												  PVC_RECURSE_PLACEHOLDERS));
	}

	return tlist;
}

/*
 * Deparse an Aggref node.
 */
static void
jdbc_deparse_aggref(Aggref *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	bool		use_variadic;

	/* Only basic, non-split aggregation accepted. */
	Assert(node->aggsplit == AGGSPLIT_SIMPLE);

	/* Check if need to print VARIADIC (cf. ruleutils.c) */
	use_variadic = node->aggvariadic;

	/* Find aggregate name from aggfnoid which is a pg_proc entry */
	jdbc_append_function_name(node->aggfnoid, context);
	appendStringInfoChar(buf, '(');

	/* Add DISTINCT */
	appendStringInfoString(buf, (node->aggdistinct != NIL) ? "DISTINCT " : "");

	/* aggstar can be set only in zero-argument aggregates */
	if (node->aggstar)
	{
		appendStringInfoChar(buf, '*');
	}
	else
	{
		ListCell   *arg;
		bool		first = true;

		/* Add all the arguments */
		foreach(arg, node->args)
		{
			TargetEntry *tle = (TargetEntry *) lfirst(arg);
			Node	   *n = (Node *) tle->expr;

			if (tle->resjunk)
				continue;

			if (!first)
				appendStringInfoString(buf, ", ");
			first = false;

			/* Add VARIADIC */
#if PG_VERSION_NUM < 130000
			if (use_variadic && lnext(arg) == NULL)
#else
			if (use_variadic && lnext(node->args, arg) == NULL)
#endif
				appendStringInfoString(buf, "VARIADIC ");

			jdbc_deparse_expr((Expr *) n, context);
		}
	}


	/* Add FILTER (WHERE ..) */
	if (node->aggfilter != NULL)
	{
		appendStringInfoString(buf, ") FILTER (WHERE ");
		jdbc_deparse_expr((Expr *) node->aggfilter, context);
	}

	appendStringInfoChar(buf, ')');
}

/*
 * Append remote name of specified foreign table to buf. Use value of
 * table_name FDW option (if any) instead of relation's name. Similarly,
 * schema_name FDW option overrides schema name.
 */
static void
jdbc_deparse_relation(StringInfo buf, Relation rel, char *q_char)
{
	ForeignTable *table;
	const char *nspname = NULL;
	const char *relname = NULL;
	ListCell   *lc;

	/* obtain additional catalog information. */
	table = GetForeignTable(RelationGetRelid(rel));

	/*
	 * Use value of FDW options if any, instead of the name of object itself.
	 */
	foreach(lc, table->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "schema_name") == 0)
			nspname = defGetString(def);
		else if (strcmp(def->defname, "table_name") == 0)
			relname = defGetString(def);
	}

	/*
	 * Note: we could skip printing the schema name if it's pg_catalog, but
	 * that doesn't seem worth the trouble.
	 */

	if (relname == NULL)
	{
		relname = RelationGetRelationName(rel);
	}

	if (nspname == NULL)
	{
		appendStringInfo(buf, "%s", jdbc_quote_identifier(relname, q_char, false));
	}
	else if (strlen(nspname) == 0)
	{
		appendStringInfo(buf, "%s", jdbc_quote_identifier(relname, q_char, false));
	}
	else
	{
		appendStringInfo(buf, "%s.%s", jdbc_quote_identifier(nspname, q_char, false),
						 jdbc_quote_identifier(relname, q_char, false));
	}

}

/*
 * Append a SQL string literal representing "val" to buf.
 */
static void
jdbc_deparse_string_literal(StringInfo buf, const char *val)
{
	const char *valptr;

	/*
	 * Rather than making assumptions about the remote server's value of
	 * standard_conforming_strings, always use E'foo' syntax if there are any
	 * backslashes.  This will fail on remote servers before 8.1, but those
	 * are long out of support.
	 */
	if (strchr(val, '\\') != NULL)
		appendStringInfoChar(buf, ESCAPE_STRING_SYNTAX);
	appendStringInfoChar(buf, '\'');
	for (valptr = val; *valptr; valptr++)
	{
		char		ch = *valptr;

		if (SQL_STR_DOUBLE(ch, true))
			appendStringInfoChar(buf, ch);
		appendStringInfoChar(buf, ch);
	}
	appendStringInfoChar(buf, '\'');
}

/*
 * Deparse given expression into context->buf.
 *
 * This function must support all the same node types that
 * jdbc_foreign_expr_walker accepts.
 *
 * Note: unlike ruleutils.c, we just use a simple hard-wired parenthesization
 * scheme: anything more complex than a Var, Const, function call or cast
 * should be self-parenthesized.
 */
static void
jdbc_deparse_expr(Expr *node, deparse_expr_cxt *context)
{
	if (node == NULL)
		return;

	switch (nodeTag(node))
	{
		case T_Var:
			jdbc_deparse_var((Var *) node, context);
			break;
		case T_Const:
			jdbc_deparse_const((Const *) node, context);
			break;
		case T_Param:

			/*
			 * Does not reach here because foreign_expr_walker returns false.
			 */
			elog(ERROR, "Parameter is unsupported");
			Assert(false);
			break;
#if PG_VERSION_NUM < 120000
		case T_ArrayRef:
			jdbc_deparse_array_ref((ArrayRef *) node, context);
			break;
#else
		case T_SubscriptingRef:
			jdbc_deparse_array_ref((SubscriptingRef *) node, context);
			break;
#endif
		case T_FuncExpr:
			jdbc_deparse_func_expr((FuncExpr *) node, context);
			break;
		case T_OpExpr:
			jdbc_deparse_op_expr((OpExpr *) node, context);
			break;
		case T_DistinctExpr:
			jdbc_deparse_distinct_expr((DistinctExpr *) node, context);
			break;
		case T_ScalarArrayOpExpr:
			jdbc_deparse_scalar_array_op_expr((ScalarArrayOpExpr *) node, context);
			break;
		case T_RelabelType:
			jdbc_deparse_relabel_type((RelabelType *) node, context);
			break;
		case T_BoolExpr:
			jdbc_deparse_bool_expr((BoolExpr *) node, context);
			break;
		case T_NullTest:
			jdbc_deparse_null_test((NullTest *) node, context);
			break;
		case T_ArrayExpr:
			jdbc_deparse_array_expr((ArrayExpr *) node, context);
			break;
		case T_Aggref:
			jdbc_deparse_aggref((Aggref *) node, context);
			break;
		default:
			elog(ERROR, "unsupported expression type for deparse: %d",
				 (int) nodeTag(node));
			break;
	}
}

/*
 * Deparse given Var node into context->buf.
 *
 * If the Var belongs to the foreign relation, just print its remote name.
 * Otherwise, it's effectively a Param (and will in fact be a Param at run
 * time).
 */
static void
jdbc_deparse_var(Var *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	Relids		relids = context->scanrel->relids;

	/* Qualify columns when multiple relations are involved. */
	bool		qualify_col = (bms_membership(relids) == BMS_MULTIPLE);

	if (bms_is_member(node->varno, relids) && node->varlevelsup == 0)
	{
		/* Var belongs to foreign table */
		jdbc_deparse_column_ref(buf, node->varno, node->varattno, context->root, qualify_col, context->q_char);
	}
	else
	{
		/* Does not reach here. */
		elog(ERROR, "Parameter is unsupported");
		Assert(false);
	}
}

/*
 * Deparse given constant value into context->buf.
 *
 * This function has to be kept in sync with ruleutils.c's get_const_expr.
 */
static void
jdbc_deparse_const(Const *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	Oid			typoutput;
	bool		typIsVarlena;
	char	   *extval;

	if (node->constisnull)
	{
		appendStringInfoString(buf, "NULL");
		return;
	}

	getTypeOutputInfo(node->consttype,
					  &typoutput, &typIsVarlena);
	extval = OidOutputFunctionCall(typoutput, node->constvalue);

	switch (node->consttype)
	{
		case INT2OID:
		case INT4OID:
		case INT8OID:
		case OIDOID:
		case FLOAT4OID:
		case FLOAT8OID:
		case NUMERICOID:
			{
				/*
				 * No need to quote unless it's a special value such as 'NaN'.
				 * See comments in get_const_expr().
				 */
				if (strspn(extval, "0123456789+-eE.") == strlen(extval))
				{
					if (extval[0] == '+' || extval[0] == '-')
						appendStringInfo(buf, "(%s)", extval);
					else
						appendStringInfoString(buf, extval);
				}
				else
					appendStringInfo(buf, "'%s'", extval);
			}
			break;
		case BITOID:
		case VARBITOID:
			appendStringInfo(buf, "B'%s'", extval);
			break;
		case BOOLOID:
			if (strcmp(extval, "t") == 0)
				appendStringInfoString(buf, "true");
			else
				appendStringInfoString(buf, "false");
			break;
		default:
			jdbc_deparse_string_literal(buf, extval);
			break;
	}

	/*
	 * Append ::typename unless the constant will be implicitly typed as the
	 * right type when it is read in.
	 *
	 * XXX this code has to be kept in sync with the behavior of the parser,
	 * especially make_const.
	 */

	/*
	 * switch (node->consttype) { case BOOLOID: case INT4OID: case UNKNOWNOID:
	 * needlabel = false; break; case NUMERICOID: needlabel = !isfloat ||
	 * (node->consttypmod >= 0); break; default: needlabel = true; break; }
	 */

	/*
	 * if (needlabel) appendStringInfo(buf, "::%s",
	 * format_type_with_typemod(node->consttype, node->consttypmod));
	 */
}

/*
 * Deparse an array subscript expression.
 */
static void
#if PG_VERSION_NUM < 120000
jdbc_deparse_array_ref(ArrayRef * node, deparse_expr_cxt *context)
#else
jdbc_deparse_array_ref(SubscriptingRef *node, deparse_expr_cxt *context)
#endif
{
	StringInfo	buf = context->buf;
	ListCell   *lowlist_item;
	ListCell   *uplist_item;

	/* Always parenthesize the expression. */
	appendStringInfoChar(buf, '(');

	/*
	 * Deparse referenced array expression first.  If that expression includes
	 * a cast, we have to parenthesize to prevent the array subscript from
	 * being taken as typename decoration.  We can avoid that in the typical
	 * case of subscripting a Var, but otherwise do it.
	 */
	if (IsA(node->refexpr, Var))
		jdbc_deparse_expr(node->refexpr, context);
	else
	{
		appendStringInfoChar(buf, '(');
		jdbc_deparse_expr(node->refexpr, context);
		appendStringInfoChar(buf, ')');
	}

	/* Deparse subscript expressions. */
	lowlist_item = list_head(node->reflowerindexpr);	/* could be NULL */
	foreach(uplist_item, node->refupperindexpr)
	{
		appendStringInfoChar(buf, '[');
		if (lowlist_item)
		{
			jdbc_deparse_expr(lfirst(lowlist_item), context);
			appendStringInfoChar(buf, ':');
#if PG_VERSION_NUM < 130000
			lowlist_item = lnext(lowlist_item);
#else
			lowlist_item = lnext(node->reflowerindexpr, lowlist_item);
#endif
		}
		jdbc_deparse_expr(lfirst(uplist_item), context);
		appendStringInfoChar(buf, ']');
	}

	appendStringInfoChar(buf, ')');
}

/*
 * Deparse a function call.
 */
static void
jdbc_deparse_func_expr(FuncExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	HeapTuple	proctup;
	Form_pg_proc procform;
	const char *proname;
	bool		use_variadic;
	bool		first;
	ListCell   *arg;
	char	   *q_char = context->q_char;

	/*
	 * If the function call came from an implicit coercion, then just show the
	 * first argument.
	 */
	if (node->funcformat == COERCE_IMPLICIT_CAST)
	{
		jdbc_deparse_expr((Expr *) linitial(node->args), context);
		return;
	}

	/*
	 * Normal function: display as proname(args).
	 */
	proctup = SearchSysCache1(PROCOID, ObjectIdGetDatum(node->funcid));
	if (!HeapTupleIsValid(proctup))
		elog(ERROR, "cache lookup failed for function %u", node->funcid);
	procform = (Form_pg_proc) GETSTRUCT(proctup);

	/* Check if need to print VARIADIC (cf. ruleutils.c) */
	use_variadic = node->funcvariadic;

	/* Print schema name only if it's not pg_catalog */
	if (procform->pronamespace != PG_CATALOG_NAMESPACE)
	{
		const char *schemaname;

		schemaname = get_namespace_name(procform->pronamespace);
		appendStringInfo(buf, "%s.", jdbc_quote_identifier(schemaname, q_char, false));
	}

	/* Deparse the function name ... */
	proname = NameStr(procform->proname);
	appendStringInfo(buf, "%s(", jdbc_quote_identifier(proname, q_char, false));
	/* ... and all the arguments */
	first = true;
	foreach(arg, node->args)
	{
		if (!first)
			appendStringInfoString(buf, ", ");
#if PG_VERSION_NUM < 130000
		if (use_variadic && lnext(arg) == NULL)
			appendStringInfoString(buf, "VARIADIC ");
#else
		if (use_variadic && lnext(node->args, arg) == NULL)
			appendStringInfoString(buf, "VARIADIC ");
#endif
		jdbc_deparse_expr((Expr *) lfirst(arg), context);
		first = false;
	}
	appendStringInfoChar(buf, ')');

	ReleaseSysCache(proctup);
}

/*
 * Deparse given operator expression.   To avoid problems around priority of
 * operations, we always parenthesize the arguments.
 */
static void
jdbc_deparse_op_expr(OpExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	HeapTuple	tuple;
	Form_pg_operator form;
	char		oprkind;

	/* Retrieve information about the operator from system catalog. */
	tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(node->opno));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for operator %u", node->opno);
	form = (Form_pg_operator) GETSTRUCT(tuple);
	oprkind = form->oprkind;

	/* Sanity check. */
#if PG_VERSION_NUM < 140000
	Assert((oprkind == 'r' && list_length(node->args) == 1) ||
		   (oprkind == 'l' && list_length(node->args) == 1) ||
		   (oprkind == 'b' && list_length(node->args) == 2));
#else
	Assert((oprkind == 'l' && list_length(node->args) == 1) ||
		   (oprkind == 'b' && list_length(node->args) == 2));
#endif

	/* Always parenthesize the expression. */
	appendStringInfoChar(buf, '(');

	/* Deparse left operand. */
#if PG_VERSION_NUM < 140000
	if (oprkind == 'r' || oprkind == 'b')
#else
	if (oprkind == 'b')
#endif
	{
		jdbc_deparse_expr(linitial(node->args), context);
		appendStringInfoChar(buf, ' ');
	}

	/* Deparse operator name. */
	jdbc_deparse_operator_name(buf, form);

	/* Deparse right operand. */
#if PG_VERSION_NUM < 140000
	if (oprkind == 'l' || oprkind == 'b')
	{
#endif
		appendStringInfoChar(buf, ' ');
		jdbc_deparse_expr(llast(node->args), context);
#if PG_VERSION_NUM < 140000
	}
#endif

	appendStringInfoChar(buf, ')');

	ReleaseSysCache(tuple);
}

/*
 * Print the name of an operator.
 */
static void
jdbc_deparse_operator_name(StringInfo buf, Form_pg_operator opform)
{
	char	   *cur_opname;

	/* opname is not a SQL identifier, so we should not quote it. */
	cur_opname = NameStr(opform->oprname);

	/* Print schema name only if it's not pg_catalog */
	if (opform->oprnamespace != PG_CATALOG_NAMESPACE)
	{
		elog(ERROR, "OPERATOR is not supported");
	}
	else
	{
		if (strcmp(cur_opname, "~~") == 0)
		{
			appendStringInfoString(buf, "LIKE");
		}
		else if (strcmp(cur_opname, "!~~") == 0)
		{
			appendStringInfoString(buf, "NOT LIKE");
		}
		else if (strcmp(cur_opname, "~~*") == 0 ||
				 strcmp(cur_opname, "!~~*") == 0 ||
				 strcmp(cur_opname, "~") == 0 ||
				 strcmp(cur_opname, "!~") == 0 ||
				 strcmp(cur_opname, "~*") == 0 ||
				 strcmp(cur_opname, "!~*") == 0)
		{
			elog(ERROR, "OPERATOR is not supported");
		}
		else
		{
			appendStringInfoString(buf, cur_opname);
		}
	}
}

/*
 * Deparse IS DISTINCT FROM.
 */
static void
jdbc_deparse_distinct_expr(DistinctExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;

	Assert(list_length(node->args) == 2);

	appendStringInfoChar(buf, '(');
	jdbc_deparse_expr(linitial(node->args), context);
	appendStringInfoString(buf, " IS DISTINCT FROM ");
	jdbc_deparse_expr(lsecond(node->args), context);
	appendStringInfoChar(buf, ')');
}

/*
 * Deparse given ScalarArrayOpExpr expression.  To avoid problems around
 * priority of operations, we always parenthesize the arguments.
 */
static void
jdbc_deparse_scalar_array_op_expr(ScalarArrayOpExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	HeapTuple	tuple;
	Expr	   *arg1;
	Expr	   *arg2;
	Form_pg_operator form;
	char	   *opname = NULL;
	Oid			typoutput;
	bool		typIsVarlena;
	char	   *extval;
	bool		useIn = false;

	/* Retrieve information about the operator from system catalog. */
	tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(node->opno));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for operator %u", node->opno);
	form = (Form_pg_operator) GETSTRUCT(tuple);

	/* Sanity check. */
	Assert(list_length(node->args) == 2);

	opname = pstrdup(NameStr(form->oprname));
	ReleaseSysCache(tuple);

	/* Using IN clause for '= ANY' and NOT IN clause for '<> ALL' */
	if ((strcmp(opname, "=") == 0 && node->useOr == true) ||
		(strcmp(opname, "<>") == 0 && node->useOr == false))
		useIn = true;

	/* Get left and right argument for deparsing */
	arg1 = linitial(node->args);
	arg2 = lsecond(node->args);

	if (useIn)
	{
		/* Deparse left operand. */
		jdbc_deparse_expr(arg1, context);
		appendStringInfoChar(buf, ' ');

		/* Add IN clause */
		if (strcmp(opname, "<>") == 0)
		{
			appendStringInfoString(buf, "NOT IN (");
		}
		else if (strcmp(opname, "=") == 0)
		{
			appendStringInfoString(buf, "IN (");
		}
	}

	switch (nodeTag((Node *) arg2))
	{
		case T_Const:
			{
				Const	   *c = (Const *) arg2;
				bool		isstr = false;
				const char *valptr;
				int			i = -1;
				bool		deparseLeft = true;

				if (!c->constisnull)
				{
					getTypeOutputInfo(c->consttype,
									  &typoutput, &typIsVarlena);
					extval = OidOutputFunctionCall(typoutput, c->constvalue);

					/* Determine array type */
					switch (c->consttype)
					{
						case INT4ARRAYOID:
						case OIDARRAYOID:
							isstr = false;
							break;
						default:
							isstr = true;
							break;
					}

					for (valptr = extval; *valptr; valptr++)
					{
						char		ch = *valptr;

						i++;

						if (useIn)
						{
							if (i == 0 && isstr)
								appendStringInfoChar(buf, '\'');
						}
						else if (deparseLeft)
						{
							/* Deparse left operand. */
							jdbc_deparse_expr(arg1, context);
							/* Append operator */
							appendStringInfo(buf, " %s ", opname);
							if (isstr)
								appendStringInfoChar(buf, '\'');
							deparseLeft = false;
						}

						/*
						 * Remove '{', '}' and \" character from the string.
						 * Because this syntax is not recognize by the remote
						 * Sqlite server.
						 */
						if ((ch == '{' && i == 0) || (ch == '}' && (i == (strlen(extval) - 1))) || ch == '\"')
							continue;

						if (ch == ',')
						{
							if (useIn)
							{
								if (isstr)
									appendStringInfoChar(buf, '\'');
								appendStringInfoChar(buf, ch);
								appendStringInfoChar(buf, ' ');
								if (isstr)
									appendStringInfoChar(buf, '\'');
							}
							else
							{
								if (isstr)
									appendStringInfoChar(buf, '\'');
								if (node->useOr)
									appendStringInfoString(buf, " OR ");
								else
									appendStringInfoString(buf, " AND ");
								deparseLeft = true;
							}
							continue;
						}
						appendStringInfoChar(buf, ch);
					}

					if (isstr)
						appendStringInfoChar(buf, '\'');
				}
				else
				{
					appendStringInfoString(buf, " NULL");
					return;
				}
			}
			break;
		case T_ArrayExpr:
			{
				bool		first = true;
				ListCell   *lc;

				foreach(lc, ((ArrayExpr *) arg2)->elements)
				{
					if (!first)
					{
						if (useIn)
						{
							appendStringInfoString(buf, ", ");
						}
						else
						{
							if (node->useOr)
								appendStringInfoString(buf, " OR ");
							else
								appendStringInfoString(buf, " AND ");
						}
					}

					if (useIn)
					{
						jdbc_deparse_expr(lfirst(lc), context);
					}
					else
					{
						/* Deparse left argument */
						appendStringInfoChar(buf, '(');
						jdbc_deparse_expr(arg1, context);

						appendStringInfo(buf, " %s ", opname);

						/*
						 * Deparse each element in right argument
						 */
						jdbc_deparse_expr(lfirst(lc), context);
						appendStringInfoChar(buf, ')');
					}
					first = false;
				}
				break;
			}
		default:
			elog(ERROR, "unsupported expression type for deparse: %d", (int) nodeTag(node));
			break;
	}

	/* Close IN clause */
	if (useIn)
		appendStringInfoChar(buf, ')');
}

/*
 * Deparse a RelabelType (binary-compatible cast) node.
 */
static void
jdbc_deparse_relabel_type(RelabelType *node, deparse_expr_cxt *context)
{
	jdbc_deparse_expr(node->arg, context);
}

/*
 * Deparse a BoolExpr node.
 *
 * Note: by the time we get here, AND and OR expressions have been flattened
 * into N-argument form, so we'd better be prepared to deal with that.
 */
static void
jdbc_deparse_bool_expr(BoolExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	const char *op = NULL;		/* keep compiler quiet */
	bool		first;
	ListCell   *lc;

	switch (node->boolop)
	{
		case AND_EXPR:
			op = "AND";
			break;
		case OR_EXPR:
			op = "OR";
			break;
		case NOT_EXPR:
			appendStringInfoString(buf, "(NOT ");
			jdbc_deparse_expr(linitial(node->args), context);
			appendStringInfoChar(buf, ')');
			return;
	}

	appendStringInfoChar(buf, '(');
	first = true;
	foreach(lc, node->args)
	{
		if (!first)
			appendStringInfo(buf, " %s ", op);
		jdbc_deparse_expr((Expr *) lfirst(lc), context);
		first = false;
	}
	appendStringInfoChar(buf, ')');
}

/*
 * Deparse IS [NOT] NULL expression.
 */
static void
jdbc_deparse_null_test(NullTest *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;

	appendStringInfoChar(buf, '(');
	jdbc_deparse_expr(node->arg, context);
	if (node->nulltesttype == IS_NULL)
		appendStringInfoString(buf, " IS NULL)");
	else
		appendStringInfoString(buf, " IS NOT NULL)");
}

/*
 * Deparse ARRAY[...] construct.
 */
static void
jdbc_deparse_array_expr(ArrayExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	bool		first = true;
	ListCell   *lc;

	appendStringInfoString(buf, "ARRAY[");
	foreach(lc, node->elements)
	{
		if (!first)
			appendStringInfoString(buf, ", ");
		jdbc_deparse_expr(lfirst(lc), context);
		first = false;
	}
	appendStringInfoChar(buf, ']');
}

/*
 * jdbc_append_function_name Deparses function name from given function oid.
 */
static void
jdbc_append_function_name(Oid funcid, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	HeapTuple	proctup;
	Form_pg_proc procform;
	const char *proname;
	char	   *q_char = context->q_char;

	proctup = SearchSysCache1(PROCOID, ObjectIdGetDatum(funcid));
	if (!HeapTupleIsValid(proctup))
		elog(ERROR, "cache lookup failed for function %u", funcid);
	procform = (Form_pg_proc) GETSTRUCT(proctup);

	/* Always print the function name */
	proname = NameStr(procform->proname);
	appendStringInfoString(buf, jdbc_quote_identifier(proname, q_char, false));

	ReleaseSysCache(proctup);
}

/*
 * jdbc_quote_identifier - Quote an identifier only if needed
 *
 * When quotes are needed, we palloc the required space; slightly
 * space-wasteful but well worth it for notational simplicity.
 * refer: PostgreSQL 13.0 src/backend/utils/adt/ruleutils.c L10730
 */
static const char *
jdbc_quote_identifier(const char *ident, char *q_char, bool quote_all_identifiers)
{
	/*
	 * Can avoid quoting if ident starts with a lowercase letter or underscore
	 * and contains only lowercase letters, digits, and underscores, *and* is
	 * not any SQL keyword.  Otherwise, supply quotes.
	 */
	int			nquotes = 0;
	bool		safe;
	const char *ptr;
	char	   *result;
	char	   *optr;

	/*
	 * Verify q_char get from remote server
	 */
	if (strlen(q_char) == 1)
	{
		/* q_char is a char value */
		if (strcmp(q_char, " ") == 0)
		{
			/* remote server not support identifier quote string */
			return ident;		/* no change needed */
		}
	}
	else
	{
		/*
		 * q_char is a string value. Currently, we do not handle this case.
		 */
		elog(ERROR, "jdbc_fdw: Not support quote string \"%s\".", q_char);
	}

	/*
	 * would like to use <ctype.h> macros here, but they might yield unwanted
	 * locale-specific results...
	 */
	safe = ((ident[0] >= 'a' && ident[0] <= 'z') || ident[0] == '_');

	for (ptr = ident; *ptr; ptr++)
	{
		char		ch = *ptr;

		if ((ch >= 'a' && ch <= 'z') ||
			(ch >= '0' && ch <= '9') ||
			(ch == '_'))
		{
			/* okay */
		}
		else
		{
			safe = false;
			if (ch == *q_char)
				nquotes++;
		}
	}

	if (quote_all_identifiers)
		safe = false;

	if (safe)
	{
		/*
		 * Check for keyword.  We quote keywords except for unreserved ones.
		 * (In some cases we could avoid quoting a col_name or type_func_name
		 * keyword, but it seems much harder than it's worth to tell that.)
		 *
		 * Note: ScanKeywordLookup() does case-insensitive comparison, but
		 * that's fine, since we already know we have all-lower-case.
		 */
		int			kwnum = ScanKeywordLookup(ident, &ScanKeywords);

		if (kwnum >= 0 && ScanKeywordCategories[kwnum] != UNRESERVED_KEYWORD)
			safe = false;
	}

	if (safe)
		return ident;			/* no change needed */

	/* -----
	 * Create new ident:
	 * - Enclose by q_char arg
	 * - Add escape for quotes char
	 *
	 * Note:
	 * - nquote: number of quote char need to escape
	 * - 2: number of outer quote.
	 * - 1: null terminator.
	 * -----
	 */
	result = (char *) palloc0(strlen(ident) + nquotes + 2 + 1);

	optr = result;
	*optr++ = *q_char;
	for (ptr = ident; *ptr; ptr++)
	{
		char		ch = *ptr;

		if (ch == *q_char)
			*optr++ = *q_char;
		*optr++ = ch;
	}
	*optr++ = *q_char;
	*optr = '\0';

	return result;
}

/*
 * Return true if function name existed in list of function
 */
static bool
jdbc_func_exist_in_list(char *funcname, const char **funclist)
{
	int			i;

	if (funclist == NULL ||		/* NULL list */
		funclist[0] == NULL ||	/* List length = 0 */
		funcname == NULL)		/* Input function name = NULL */
		return false;

	for (i = 0; funclist[i]; i++)
	{
		if (strcmp(funcname, funclist[i]) == 0)
			return true;
	}
	return false;
}
