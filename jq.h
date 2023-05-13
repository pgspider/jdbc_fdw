/*
 * --------------------------------------------- jq.h Low level JDBC based
 * functions replacing the libpq-fe functions
 *
 * Heimir Sverrisson, 2015-04-13
 *
 * Portions Copyright (c) 2021, TOSHIBA CORPORATION
 *
 * ---------------------------------------------
 */
#ifndef JQ_H
#define JQ_H

#include "libpq-fe.h"
#include "jni.h"
#include "executor/tuptable.h"
#include "nodes/execnodes.h"

typedef struct jdbcFdwExecutionState
{
	char	   *query;
	int			NumberOfRows;
}			jdbcFdwExecutionState;

/* JDBC connection, same role as PGconn */
typedef struct Jconn
{
	jobject		JDBCUtilsObject;
	ConnStatusType status;
	jdbcFdwExecutionState *festate;
	char	   *q_char;
}			Jconn;

/* result status from JDBC */
typedef ExecStatusType Jresult;

/* JDBC columnInfo */
typedef struct JcolumnInfo
{
	char	   *column_name;
	char	   *column_type;
	bool		primary_key;
}			JcolumnInfo;

/* JDBC tableInfo */
typedef struct JtableInfo
{
	char	   *table_name;
	List	   *column_info;
}			JtableInfo;

/*
 * Replacement for libpq-fe.h functions
 */
extern Jresult * jq_exec(Jconn * conn, const char *query);
extern Jresult * jq_exec_id(Jconn * conn, const char *query, int *resultSetID);
extern void *jq_release_resultset_id(Jconn * conn, int resultSetID);
extern Jresult * jq_exec_prepared(Jconn * conn, const int *paramLengths,
								  const int *paramFormats, int resultFormat, int resultSetID);
extern void jq_clear(Jresult * res);
extern char *jq_cmd_tuples(Jresult * res);
extern char *jq_get_value(const Jresult * res, int tup_num, int field_num);
extern Jresult * jq_prepare(Jconn * conn, const char *query,
							const Oid * paramTypes, int *resultSetID);
extern int	jq_nfields(const Jresult * res);
extern int	jq_get_is_null(const Jresult * res, int tup_num, int field_num);
extern Jconn * jq_connect_db_params(const ForeignServer * server, const UserMapping * user, const char *const *keywords,
									const char *const *values);
extern ConnStatusType jq_status(const Jconn * conn);
extern char *jq_error_message(const Jconn * conn);
extern int	jq_connection_used_password(const Jconn * conn);
extern void jq_finish(Jconn * conn);
extern int	jq_server_version(const Jconn * conn);
extern char *jq_result_error_field(const Jresult * res, int fieldcode);
extern PGTransactionStatusType jq_transaction_status(const Jconn * conn);
extern TupleTableSlot * jq_iterate(Jconn * conn, ForeignScanState * node, List * retrieved_attrs, int resultSetID);
extern void jq_iterate_all_row(FunctionCallInfo fcinfo, Jconn * conn, TupleDesc tupleDescriptor, int resultSetID);
extern List * jq_get_column_infos_without_key(Jconn * conn, int *resultSetID, int *column_num);
extern void *jq_bind_sql_var(Jconn * conn, Oid type, int attnum, Datum value, bool *isnull, int resultSetID);
extern Datum jdbc_convert_to_pg(Oid pgtyp, int pgtypmod, char *value);
extern List * jq_get_schema_info(Jconn * conn);
extern void jdbc_jvm_init(const ForeignServer * server, const UserMapping * user);
#endif							/* JQ_H */
