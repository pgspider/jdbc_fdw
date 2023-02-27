#include <gridstore.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>

#define STRING_MAX_LENGTH 1000

typedef struct
{
	GSContainer *container;
	GSContainerInfo info;
}			table_info;

GSResult	set_tableInfo(GSGridStore * store,
						  const GSChar * tbl_name,
						  table_info * tbl_info,
						  size_t column_count,...);

GSResult	insert_recordsFromTSV(GSGridStore * store,
								  table_info * tbl_info,
								  char *file_path);

GSResult	griddb_init(const char *addr,
						const char *port,
						const char *cluster_name,
						const char *user,
						const char *passwd);

/**
 * Create table info
 * Arguments: GridStore instance, table name, table info, number of column, [ column1_name, column1_type, column1_options, column2_name, column2_type, column2_options,...
 */
GSResult
set_tableInfo(GSGridStore * store,
			  const GSChar * tbl_name,
			  table_info * tbl_info,
			  size_t column_count,...)
{
	GSResult	ret = GS_RESULT_OK;
	int			i;
	va_list		valist;

	/* Set column info */
	GSColumnInfo column_info = GS_COLUMN_INFO_INITIALIZER;
	GSColumnInfo *column_info_list = calloc(column_count, sizeof(GSColumnInfo));

	tbl_info->info = (GSContainerInfo) GS_CONTAINER_INFO_INITIALIZER;
	tbl_info->info.type = GS_CONTAINER_COLLECTION;
	tbl_info->info.name = tbl_name;
	tbl_info->info.columnCount = column_count;
	va_start(valist, column_count);
	for (i = 0; i < column_count; i++)
	{
		column_info.name = va_arg(valist, GSChar *);
		column_info.type = va_arg(valist, GSType);
		column_info.options = va_arg(valist, GSTypeOption);
		column_info_list[i] = column_info;
	}
	va_end(valist);
	tbl_info->info.columnInfoList = column_info_list;
	tbl_info->info.rowKeyAssigned = GS_TRUE;
	/* Drop the old container if it existed */
	ret = gsDropContainer(store, tbl_info->info.name);
	if (!GS_SUCCEEDED(ret))
	{
		printf("Can not drop container \"%s\"\n", tbl_name);
		return ret;
	}
	/* Create a Collection (Delete if schema setting is NULL) */
	ret = gsPutContainerGeneral(store, NULL, &(tbl_info->info), GS_FALSE, &(tbl_info->container));
	if (!GS_SUCCEEDED(ret))
	{
		printf("Create container \"%s\" failed\n", tbl_name);
		return ret;
	}
	/* Set the autocommit mode to OFF */
	ret = gsSetAutoCommit(tbl_info->container, GS_FALSE);
	if (!GS_SUCCEEDED(ret))
	{
		printf("Set autocommit for container %s failed\n", tbl_name);
		return ret;
	}

	return GS_RESULT_OK;
}

/**
 * Create table info
 * Arguments: GridStore instance, table name, table info, number of column, [ column1_name, column1_type, column1_options, column2_name, column2_type, column2_options,...
 */
GSResult
set_tableInfo_timeseries(GSGridStore * store,
						 const GSChar * tbl_name,
						 table_info * tbl_info,
						 size_t column_count,...)
{
	GSResult	ret = GS_RESULT_OK;
	int			i;
	va_list		valist;

	/* Set column info */
	GSColumnInfo column_info = GS_COLUMN_INFO_INITIALIZER;
	GSColumnInfo *column_info_list = calloc(column_count, sizeof(GSColumnInfo));

	tbl_info->info = (GSContainerInfo) GS_CONTAINER_INFO_INITIALIZER;
	tbl_info->info.type = GS_CONTAINER_TIME_SERIES;
	tbl_info->info.name = tbl_name;
	tbl_info->info.columnCount = column_count;
	va_start(valist, column_count);
	for (i = 0; i < column_count; i++)
	{
		column_info.name = va_arg(valist, GSChar *);
		column_info.type = va_arg(valist, GSType);
		column_info.options = va_arg(valist, GSTypeOption);
		column_info_list[i] = column_info;
	}
	va_end(valist);
	tbl_info->info.columnInfoList = column_info_list;
	tbl_info->info.rowKeyAssigned = GS_TRUE;
	/* Drop the old container if it existed */
	ret = gsDropContainer(store, tbl_info->info.name);
	if (!GS_SUCCEEDED(ret))
	{
		printf("Can not drop container \"%s\"\n", tbl_name);
		return ret;
	}
	/* Create a Collection (Delete if schema setting is NULL) */
	ret = gsPutContainerGeneral(store, NULL, &(tbl_info->info), GS_FALSE, &(tbl_info->container));
	if (!GS_SUCCEEDED(ret))
	{
		printf("Create container \"%s\" failed\n", tbl_name);
		return ret;
	}
	/* Set the autocommit mode to OFF */
	ret = gsSetAutoCommit(tbl_info->container, GS_FALSE);
	if (!GS_SUCCEEDED(ret))
	{
		printf("Set autocommit for container %s failed\n", tbl_name);
		return ret;
	}

	return GS_RESULT_OK;
}

/**
 * Insert records from TSV file
 * Arguments: GridStore instance, table info, TSV file path
 */
GSResult
insert_recordsFromTSV(GSGridStore * store,
					  table_info * tbl_info,
					  char *file_path)
{
	GSResult	ret = GS_RESULT_OK;
	int			i;
	char	  **record_cols;
	char		line[STRING_MAX_LENGTH];
	char	   *data;
	int			offset;
	FILE	   *infile;
	GSRow	   *row;

	/* Create an array to save a record */
	record_cols = (char **) malloc(tbl_info->info.columnCount * sizeof(char *));
	if (!record_cols)
	{
		printf("Couldn't allocate the array to save record\n");
		return !GS_RESULT_OK;
	}
	for (i = 0; i < tbl_info->info.columnCount; i++)
	{
		record_cols[i] = (char *) malloc(STRING_MAX_LENGTH * sizeof(char));
		if (!record_cols[i])
		{
			printf("Couldn't allocate the array to save record\n");
			return !GS_RESULT_OK;
		}
	}

	/* Open .data file (tab-separated values file) */
	infile = fopen(file_path, "r");
	if (!infile)
	{
		printf("Couldn't open \"%s\" file for reading\n", file_path);
		return !GS_RESULT_OK;
	}

	/* Get data from TSV file and save to the corresponding table */
	while (fgets(line, sizeof(line), infile) != NULL)
	{
		while (line[strlen(line) - 1] == '\n' || line[strlen(line) - 1] == '\r')
			line[strlen(line) - 1] = '\0';

		data = line;
		i = 0;
		while (sscanf(data, "%[^\t]\t%n", record_cols[i], &offset) == 1)
		{
			data += offset;
			i++;
		}

		/* Prepare data for a Row */
		ret = gsCreateRowByStore(store, &(tbl_info->info), &row);
		if (!GS_SUCCEEDED(ret))
		{
			printf("Create new GSRow with table \"%s\" failed\n", tbl_info->info.name);
			return ret;
		}
		for (i = 0; i < tbl_info->info.columnCount; i++)
		{
			switch (tbl_info->info.columnInfoList[i].type)
			{
				case GS_TYPE_STRING:
					ret = gsSetRowFieldByString(row, i, record_cols[i]);
					break;
				case GS_TYPE_BOOL:
					ret = gsSetRowFieldByBool(row, i, atoi(record_cols[i]));
					break;
				case GS_TYPE_BYTE:
					ret = gsSetRowFieldByByte(row, i, (int8_t) atoi(record_cols[i]));
					break;
				case GS_TYPE_SHORT:
					ret = gsSetRowFieldByShort(row, i, (int16_t) atoi(record_cols[i]));
					break;
				case GS_TYPE_INTEGER:
					ret = gsSetRowFieldByInteger(row, i, (int32_t) atoi(record_cols[i]));
					break;
				case GS_TYPE_LONG:
					ret = gsSetRowFieldByLong(row, i, atol(record_cols[i]));
					break;
				case GS_TYPE_FLOAT:
					ret = gsSetRowFieldByFloat(row, i, strtof(record_cols[i], NULL));
					break;
				case GS_TYPE_DOUBLE:
					ret = gsSetRowFieldByDouble(row, i, strtod(record_cols[i], NULL));
					break;
				case GS_TYPE_TIMESTAMP:
					{
						GSBool		status;
						GSTimestamp timestamp;

						status = gsParseTime(record_cols[i], &timestamp);
						if (status == GS_FALSE)
						{
							printf("failed convert timestamp: %s\n", record_cols[i]);
						}

						ret = gsSetRowFieldByTimestamp(row, i, timestamp);
						break;
					}
				default:
					break;
					/* if needed */
					/* case GS_TYPE_TIMESTAMP: */
					/* gsSetRowFieldByTimestamp(row, i, ); */
					/* break; */
					/* case GS_TYPE_GEOMETRY: */
					/* gsSetRowFieldByGeometry(row, i, ); */
					/* break; */
					/* case GS_TYPE_BLOB: */
					/* gsSetRowFieldByBlob(row, i, ); */
					/* break; */
			}

			if (!GS_SUCCEEDED(ret))
			{
				return ret;
			}
		}

		/* Add row to the corresponding table */
		ret = gsPutRow(tbl_info->container, NULL, row, NULL);
		if (!GS_SUCCEEDED(ret))
		{
			printf("Add new row to table \"%s\" failed\n", tbl_info->info.name);
			return ret;
		}

		gsCloseRow(&row);
	}

	/* Commit the transaction (Release the lock) */
	ret = gsCommit(tbl_info->container);
	if (!GS_SUCCEEDED(ret))
	{
		printf("Commit data to the table \"%s\" failed\n", tbl_info->info.name);
		return ret;
	}

	return GS_RESULT_OK;
}

/**
 * Connect to GridDB cluster and insert data to the database
 * Arguments: IP address, port, cluster name, username, password
 */
GSResult
griddb_init(const char *addr,
			const char *port,
			const char *cluster_name,
			const char *user,
			const char *passwd)
{
	GSGridStore *store;
	GSResult	ret = GS_RESULT_OK;

	/* For griddb_fdw */
	table_info	btg,
				department,
				employee,
				empdata,
				numbers,
				evennumbers,
				shorty,
				rowkey_tbl,
				time_series_tbl,
				time_series2;

	/* For griddb_fdw_data_type */
	table_info	type_string,
				type_boolean,
				type_byte,
				type_short,
				type_integer,
				type_long,
				type_float,
				type_double,
				type_timestamp,
				type_blob,
				type_string_array,
				type_bool_array,
				type_byte_array,
				type_short_array,
				type_integer_array,
				type_long_array,
				type_float_array,
				type_double_array,
				type_timestamp_array;

	/* For griddb_fdw_post */
	table_info	T0,
				T1,
				T2,
				T3,
				T4,
				ft1,
				ft2,
				ft4,
				ft5,
				base_tbl,
				child_tbl,
				loc1,
				loct13,
				gloc1,
				loc2,
				loc3,
				loct,
				loct1,
				loct2,
				loct3,
				loct4,
				loct1_2,
				loct2_2,
				loct1_3,
				loct1_4,
				loct2_3,
				loct2_4,
				loct_2,
				loct_empty,
				loct4_2,
				locp1,
				locp2,
				fprt1_p1,
				fprt1_p2,
				fprt2_p1,
				fprt2_p2,
				pagg_tab_p1,
				pagg_tab_p2,
				pagg_tab_p3,
				local_tbl;

	/* For delete */
	table_info	delete_test;

	/* For float4 */
	table_info	FLOAT4_TBL,
				FLOAT4_TBL_TEMP;
	table_info	test_data;

	/* For float8 */
	table_info	FLOAT8_TBL,
				FLOAT8_TBL_TEMP,
				FLOAT8_TMP;

	/* For int4 */
	table_info	INT4_TBL,
				INT4_TBL_TEMP,
				INT4_TMP;


	/* For int8 */
	table_info	INT8_TBL,
				INT8_TBL_TEMP;

	/* For join */
	table_info	J1_TBL,
				J2_TBL,
				b0,
				tenk,
				tenk1,
				tenk2,
				INT2_TBL,
				t11,
				t21,
				t31,
				x,
				y,
				t12,
				t22,
				t32,
				tt1,
				tt2,
				tt3,
				tt4,
				tt4x,
				tt5,
				tt6,
				xx,
				yy,
				zt1,
				zt2,
				zt3,
				a1,
				b1,
				a2,
				b2,
				c2,
				nt1,
				nt2,
				nt3,
				text_tbl,
				a3,
				b3,
				c3,
				d3,
				parent,
				child,
				a4,
				b4,
				innertab,
				uniquetbl,
				join_pt1p2,
				join_pt1p1p1,
				join_ut1,
				fkest,
				fkest1,
				j11,
				j21,
				j31,
				j12,
				j22,
				j32,
				onek,
				simple,
				bigger_than_it_looks,
				extremely_skewed,
				wide,
				join_foo,
				join_bar,
				q1,
				q2;

	/* For select_having */
	table_info	test_having;

	/* For select */
	table_info	onek2,
				person,
				foo,
				bar;

	/* For aggregates */
	table_info	aggtest,
				student,
				multi_arg_agg,
				bitwise_test,
				bool_test,
				minmaxtest,
				agg_t0,
				agg_t1,
				agg_t2,
				agg_t3,
				agg_t4,
				agg_t5,
				agg_t6,
				VARCHAR_TBL,
				bytea_test_table,
				regr_test,
				regr_test_array,
				bool_test_a,
				bool_test_b,
				agg_data_2k,
				agg_data_20k,
				agg_group_1,
				agg_group_2,
				agg_group_3,
				agg_group_4,
				agg_hash_1,
				agg_hash_2,
				agg_hash_3,
				agg_hash_4,
				agg_fns_1,
				agg_fns_2,
				string_agg1,
				string_agg2,
				string_agg3,
				string_agg4;

	/* For prepare */
	table_info	road,
				road_tmp;

	/* For numeric */
	table_info	num_data,
				num_exp_add,
				num_exp_sub,
				num_exp_div,
				num_exp_mul,
				num_exp_sqrt,
				num_exp_ln,
				num_exp_log10,
				num_exp_power_10_ln,
				num_result,
				ceil_floor_round,
				width_bucket_tbl,
				width_bucket_test,
				num_input_test,
				num_test_calc,
				fract_only,
				to_number_test;

	/* For update */
	table_info	update_test,
				part_b_1_b_10,
				part_a_10_a_20,
				part_a_1_a_10,
				part_d_1_15,
				part_d_15_20,
				list_part1,
				list_default,
				hpart1,
				hpart2,
				hpart3,
				hpart4,
				part_def1;

	/* For insert */
	table_info	inserttest01,
				inserttest,
				part1,
				part2,
				part3,
				part4,
				part_aa_bb,
				part_cc_dd,
				part_null,
				part_ee_ff1,
				part_ee_ff2,
				part_xx_yy_p1,
				part_xx_yy_defpart,
				part_default_p1,
				part_default_p2,
				part_def,
				hpart10,
				hpart11,
				hpart12,
				hpart13,
				part_default,
				lparted_nonullpart_a,
				mlparted12,
				mlparted3,
				mlparted_def1,
				mlparted_def2,
				mlparted_defd,
				mlparted5_a,
				mcrparted0,
				mcrparted1,
				mcrparted2,
				mcrparted3,
				mcrparted4,
				mcrparted5,
				donothingbrtrig_test1,
				donothingbrtrig_test2,
				mcrparted1_lt_b,
				mcrparted2_b,
				mcrparted3_c_to_common,
				mcrparted4_common_lt_0,
				mcrparted5_common_0_to_10,
				mcrparted6_common_ge_10,
				mcrparted7_gt_common_lt_d,
				mcrparted8_ge_d,
				inserttest3,
				brtrigpartcon1,
				returningwrtest1,
				returningwrtest2;

	table_info	tbl01,
				tbl02,
				tbl03,
				tbl04,
				tbl05,
				tbl06,
				test_explicit_cast;
	const		GSPropertyEntry props[] = {
		{"notificationAddress", addr},
		{"notificationPort", port},
		{"clusterName", cluster_name},
		{"user", user},
		{"password", passwd}
	};
	const size_t prop_count = sizeof(props) / sizeof(*props);

	/* Create a GridStore instance */
	ret = gsGetGridStore(gsGetDefaultFactory(), props, prop_count, &store);
	if (!GS_SUCCEEDED(ret))
	{
		printf("Get GridDB instance failed\n");
		goto EXIT;
	}

	/*
	 * CREATE TABLE btg(id int primary key, p int, v text, c float, d float, e int);
	 */
	ret = set_tableInfo(store, "btg", &btg,
						6,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"p", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"v", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_FLOAT, GS_TYPE_OPTION_NULLABLE,
						"d", GS_TYPE_FLOAT, GS_TYPE_OPTION_NULLABLE,
						"e", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	/*
	 * CREATE TABLE department (department_id integer primary key,
	 * department_name text)
	 */
	ret = set_tableInfo(store, "department", &department,
						2,
						"department_id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"department_name", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	/*
	 * CREATE TABLE time_series (date timestamp, value1 integer, value2
	 * double, blobCol Blob)
	 */
	ret = set_tableInfo_timeseries(store, "time_series", &time_series_tbl,
								   3,
								   "date", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NOT_NULL,
								   "value1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
								   "value2", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo_timeseries(store, "time_series2", &time_series2,
								   20,
								   "date", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NOT_NULL,
								   "date2", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NOT_NULL,
								   "strcol", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
								   "booleancol", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
								   "bytecol", GS_TYPE_BYTE, GS_TYPE_OPTION_NULLABLE,
								   "shortcol", GS_TYPE_SHORT, GS_TYPE_OPTION_NULLABLE,
								   "intcol", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
								   "longcol", GS_TYPE_LONG, GS_TYPE_OPTION_NULLABLE,
								   "floatcol", GS_TYPE_FLOAT, GS_TYPE_OPTION_NULLABLE,
								   "doublecol", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
								   "blobcol", GS_TYPE_BLOB, GS_TYPE_OPTION_NULLABLE,
								   "stringarray", GS_TYPE_STRING_ARRAY, GS_TYPE_OPTION_NULLABLE,
								   "boolarray", GS_TYPE_BOOL_ARRAY, GS_TYPE_OPTION_NULLABLE,
								   "bytearray", GS_TYPE_BYTE_ARRAY, GS_TYPE_OPTION_NULLABLE,
								   "shortarray", GS_TYPE_SHORT_ARRAY, GS_TYPE_OPTION_NULLABLE,
								   "integerarray", GS_TYPE_INTEGER_ARRAY, GS_TYPE_OPTION_NULLABLE,
								   "longarray", GS_TYPE_LONG_ARRAY, GS_TYPE_OPTION_NULLABLE,
								   "floatarray", GS_TYPE_FLOAT_ARRAY, GS_TYPE_OPTION_NULLABLE,
								   "doublearray", GS_TYPE_DOUBLE_ARRAY, GS_TYPE_OPTION_NULLABLE,
								   "timestamparray", GS_TYPE_TIMESTAMP_ARRAY, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	/*
	 * CREATE TABLE employee (emp_id integer primary key, emp_name text,
	 * emp_dept_id integer)
	 */
	ret = set_tableInfo(store, "employee", &employee,
						3,
						"emp_id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"emp_name", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"emp_dept_id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE empdata (emp_id integer primary key, emp_dat blob) */
	ret = set_tableInfo(store, "empdata", &empdata,
						2,
						"emp_id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"emp_dat", GS_TYPE_BLOB, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE numbers (a integer primary key, b text) */
	ret = set_tableInfo(store, "numbers", &numbers,
						2,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE evennumbers (a integer primary key, b text) */
	ret = set_tableInfo(store, "evennumbers", &evennumbers,
						2,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE shorty (id integer primary key, c text) */
	ret = set_tableInfo(store, "shorty", &shorty,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE rowkey_tbl (a integer primary key, b integer) */
	ret = set_tableInfo(store, "rowkey_tbl", &rowkey_tbl,
						2,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE type_string (col1 text primary key, col2 text) */
	ret = set_tableInfo(store, "type_string", &type_string,
						2,
						"col1", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE type_boolean (col1 integer primary key, col2 boolean) */
	ret = set_tableInfo(store, "type_boolean", &type_boolean,
						2,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE type_byte (col1 integer primary key, col2 char) */
	ret = set_tableInfo(store, "type_byte", &type_byte,
						2,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_BYTE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE type_short (col1 integer primary key, col2 short) */
	ret = set_tableInfo(store, "type_short", &type_short,
						2,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_SHORT, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE type_integer (col1 integer primary key, col2 integer) */
	ret = set_tableInfo(store, "type_integer", &type_integer,
						2,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE type_long (col1 long primary key, col2 long) */
	ret = set_tableInfo(store, "type_long", &type_long,
						2,
						"col1", GS_TYPE_LONG, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_LONG, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE type_float (col1 integer primary key, col2 float) */
	ret = set_tableInfo(store, "type_float", &type_float,
						2,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_FLOAT, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE type_double (col1 integer primary key, col2 double) */
	ret = set_tableInfo(store, "type_double", &type_double,
						2,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	/*
	 * CREATE TABLE type_timestamp (col1 timestamp primary key, col2
	 * timestamp)
	 */
	ret = set_tableInfo(store, "type_timestamp", &type_timestamp,
						2,
						"col1", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE type_blob (col1 integer primary key, col2 blob) */
	ret = set_tableInfo(store, "type_blob", &type_blob,
						2,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_BLOB, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE type_string_array (col1 integer primary key, col2 text[]) */
	ret = set_tableInfo(store, "type_string_array", &type_string_array,
						2,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_STRING_ARRAY, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE type_bool_array (col1 integer primary key, col2 boolean[]) */
	ret = set_tableInfo(store, "type_bool_array", &type_bool_array,
						2,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_BOOL_ARRAY, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE type_byte_array (col1 integer primary key, col2 char[]) */
	ret = set_tableInfo(store, "type_byte_array", &type_byte_array,
						2,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_BYTE_ARRAY, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE type_short_array (col1 integer primary key, col2 short[]) */
	ret = set_tableInfo(store, "type_short_array", &type_short_array,
						2,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_SHORT_ARRAY, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	/*
	 * CREATE TABLE type_integer_array (col1 integer primary key, col2
	 * integer[])
	 */
	ret = set_tableInfo(store, "type_integer_array", &type_integer_array,
						2,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_INTEGER_ARRAY, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE type_long_array (col1 integer primary key, col2 long[]) */
	ret = set_tableInfo(store, "type_long_array", &type_long_array,
						2,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_LONG_ARRAY, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	/* CREATE TABLE type_float_array (col1 integer primary key, col2 float[]) */
	ret = set_tableInfo(store, "type_float_array", &type_float_array,
						2,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_FLOAT_ARRAY, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	/*
	 * CREATE TABLE type_double_array (col1 integer primary key, col2
	 * double[])
	 */
	ret = set_tableInfo(store, "type_double_array", &type_double_array,
						2,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_DOUBLE_ARRAY, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	/*
	 * CREATE TABLE type_timestamp_array (col1 integer primary key, col2
	 * timestamp[])
	 */
	ret = set_tableInfo(store, "type_timestamp_array", &type_timestamp_array,
						2,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col2", GS_TYPE_TIMESTAMP_ARRAY, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "T0", &T0,
						8,
						"C_1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c3", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"c4", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NULLABLE,
						"c5", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NULLABLE,
						"c6", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"c7", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"c8", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "T1", &T1,
						8,
						"C_1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c3", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"c4", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NULLABLE,
						"c5", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NULLABLE,
						"c6", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"c7", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"c8", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "T2", &T2,
						2,
						"c1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c2", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "T3", &T3,
						3,
						"c1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c3", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "T4", &T4,
						3,
						"c1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c3", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "ft1", &ft1,
						8,
						"c1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c3", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"c4", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NULLABLE,
						"c5", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NULLABLE,
						"c6", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"c7", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"c8", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "ft2", &ft2,
						2,
						"c1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c2", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "ft4", &ft4,
						3,
						"c1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c3", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "ft5", &ft5,
						3,
						"c1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c3", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "base_tbl", &base_tbl,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "child_tbl", &child_tbl,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "loc1", &loc1,
						2,
						"f1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f2", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "loct13", &loct13,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f2", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "gloc1", &gloc1,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "loc2", &loc2,
						2,
						"f1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f2", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "loc3", &loc3,
						2,
						"f1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f2", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "loct", &loct,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"aa", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"bb", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "loct1", &loct1,
						3,
						"f1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"f3", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "loct2", &loct2,
						3,
						"f1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"f3", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "loct3", &loct3,
						3,
						"f1", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"f2", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"f3", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "loct4", &loct4,
						2,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "loct1_2", &loct1_2,
						2,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "loct2_2", &loct2_2,
						2,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "loct1_3", &loct1_3,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	ret = set_tableInfo(store, "loct_2", &loct_2,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	ret = set_tableInfo(store, "loct1_4", &loct1_4,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "loct2_3", &loct2_3,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
	ret = set_tableInfo(store, "loct2_4", &loct2_4,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "locp1", &locp1,
						3,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "locp2", &locp2,
						3,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "fprt1_p1", &fprt1_p1,
						3,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "fprt1_p2", &fprt1_p2,
						3,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "fprt2_p1", &fprt2_p1,
						3,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "fprt2_p2", &fprt2_p2,
						3,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "pagg_tab_p1", &pagg_tab_p1,
						4,
						"t", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "pagg_tab_p2", &pagg_tab_p2,
						4,
						"t", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "pagg_tab_p3", &pagg_tab_p3,
						4,
						"t", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "delete_test", &delete_test,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "FLOAT4_TBL", &FLOAT4_TBL,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f1", GS_TYPE_FLOAT, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "FLOAT4_TBL_TEMP", &FLOAT4_TBL_TEMP,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f1", GS_TYPE_FLOAT, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "test_data", &test_data,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"bits", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "FLOAT8_TBL", &FLOAT8_TBL,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f1", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "FLOAT8_TBL_TEMP", &FLOAT8_TBL_TEMP,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f1", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "FLOAT8_TMP", &FLOAT8_TMP,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f1", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"f2", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "INT4_TBL", &INT4_TBL,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "INT4_TBL_TEMP", &INT4_TBL_TEMP,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "INT4_TMP", &INT4_TMP,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "INT8_TBL", &INT8_TBL,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"q1", GS_TYPE_LONG, GS_TYPE_OPTION_NULLABLE,
						"q2", GS_TYPE_LONG, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "INT8_TBL_TEMP", &INT8_TBL_TEMP,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"q1", GS_TYPE_LONG, GS_TYPE_OPTION_NULLABLE,
						"q2", GS_TYPE_LONG, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "J1_TBL", &J1_TBL,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"i", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"j", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"t", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "J2_TBL", &J2_TBL,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"i", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"k", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "b0", &b0,
						2,
						"aa", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"bb", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "tenk", &tenk,
						16,
						"unique1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"unique2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"two", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"four", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"ten", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"twenty", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"hundred", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"thousand", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"twothousand", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"fivethous", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"tenthous", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"odd", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"even", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"stringu1", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"stringu2", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"string4", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "tenk1", &tenk1,
						16,
						"unique1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"unique2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"two", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"four", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"ten", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"twenty", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"hundred", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"thousand", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"twothousand", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"fivethous", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"tenthous", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"odd", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"even", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"stringu1", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"stringu2", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"string4", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "tenk2", &tenk2,
						16,
						"unique1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"unique2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"two", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"four", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"ten", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"twenty", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"hundred", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"thousand", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"twothousand", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"fivethous", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"tenthous", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"odd", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"even", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"stringu1", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"stringu2", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"string4", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "INT2_TBL", &INT2_TBL,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f1", GS_TYPE_SHORT, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "t11", &t11,
						2,
						"name", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"n", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "t21", &t21,
						2,
						"name", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"n", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "t31", &t31,
						2,
						"name", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"n", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "x", &x,
						2,
						"x1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"x2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "y", &y,
						2,
						"y1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"y2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "t12", &t12,
						2,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "t22", &t22,
						2,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "t32", &t32,
						2,
						"x", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"y", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "tt1", &tt1,
						2,
						"tt1_id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"joincol", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "tt2", &tt2,
						2,
						"tt2_id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"joincol", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "tt3", &tt3,
						2,
						"tt1_id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"joincol", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "tt4", &tt4,
						1,
						"f1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "tt4x", &tt4x,
						1,
						"c1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c3", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "tt5", &tt5,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"f2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "tt6", &tt6,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"f2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "xx", &xx,
						1,
						"pkxx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "yy", &yy,
						2,
						"pkyy", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"pkxx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "zt1", &zt1,
						1,
						"f1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "zt2", &zt2,
						1,
						"f2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "zt3", &zt3,
						1,
						"f3", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "a1", &a1,
						1,
						"i", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "b1", &b1,
						2,
						"x", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"y", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "a2", &a2,
						1,
						"code", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "b2", &b2,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"num", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "c2", &c2,
						2,
						"name", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "nt1", &nt1,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a1", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"a2", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "nt2", &nt2,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"nt1_id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b1", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"b2", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "nt3", &nt3,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"nt2_id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c1", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "text_tbl", &text_tbl,
						1,
						"f1", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "loct_empty", &loct_empty,
						2,
						"c1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c2", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "loct4_2", &loct4_2,
						3,
						"f1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"f3", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "a3", &a3,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b_id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "b3", &b3,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c_id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "c3", &c3,
						1,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "d3", &d3,
						2,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "parent", &parent,
						2,
						"k", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"pd", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "child", &child,
						2,
						"k", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"cd", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "a4", &a4,
						1,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "b4", &b4,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a_id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "innertab", &innertab,
						2,
						"id", GS_TYPE_LONG, GS_TYPE_OPTION_NOT_NULL,
						"dat1", GS_TYPE_LONG, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "uniquetbl", &uniquetbl,
						1,
						"f1", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "join_pt1p2", &join_pt1p2,
						3,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "join_pt1p1p1", &join_pt1p1p1,
						3,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "join_ut1", &join_ut1,
						3,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "fkest", &fkest,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "fkest1", &fkest1,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "j11", &j11,
						2,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "j21", &j21,
						2,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "j31", &j31,
						2,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "j12", &j12,
						3,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"id2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "j22", &j22,
						3,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"id2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "j32", &j32,
						3,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"id2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "onek", &onek,
						16,
						"unique1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"unique2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"two", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"four", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"ten", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"twenty", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"hundred", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"thousand", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"twothousand", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"fivethous", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"tenthous", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"odd", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"even", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"stringu1", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"stringu2", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"string4", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "simple", &simple,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"t", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "bigger_than_it_looks", &bigger_than_it_looks,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"t", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "extremely_skewed", &extremely_skewed,
						3,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"t", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "wide", &wide,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"t", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "join_foo", &join_foo,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"t", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "q1", &q1,
						1,
						"q1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "q2", &q2,
						1,
						"q2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "join_bar", &join_bar,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"t", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "test_having", &test_having,
						4,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"d", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "onek2", &onek2,
						16,
						"unique1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"unique2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"two", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"four", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"ten", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"twenty", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"hundred", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"thousand", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"twothousand", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"fivethous", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"tenthous", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"odd", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"even", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"stringu1", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"stringu2", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"string4", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "person", &person,
						3,
						"name", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"age", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"location", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "foo", &foo,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"f1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "bar", &bar,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "aggtest", &aggtest,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_SHORT, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_FLOAT, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "student", &student,
						4,
						"name", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"age", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"location", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"gpa", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "multi_arg_agg", &multi_arg_agg,
						3,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "bitwise_test", &bitwise_test,
						7,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"i2", GS_TYPE_SHORT, GS_TYPE_OPTION_NULLABLE,
						"i4", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"i8", GS_TYPE_LONG, GS_TYPE_OPTION_NULLABLE,
						"i", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"x", GS_TYPE_SHORT, GS_TYPE_OPTION_NULLABLE,
						"y", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "bool_test", &bool_test,
						5,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b1", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"b2", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"b3", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"b4", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "minmaxtest", &minmaxtest,
						1,
						"f1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_t0", &agg_t0,
						2,
						"foo", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"bar", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_t1", &agg_t1,
						4,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"d", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_t2", &agg_t2,
						1,
						"inner_c", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_t3", &agg_t3,
						1,
						"inner_c", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_t4", &agg_t4,
						1,
						"outer_c", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_t5", &agg_t5,
						1,
						"x", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_t6", &agg_t6,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"x", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "VARCHAR_TBL", &VARCHAR_TBL,
						1,
						"f1", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "bytea_test_table", &bytea_test_table,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"v", GS_TYPE_BLOB, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "regr_test", &regr_test,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"x", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"y", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "regr_test_array", &regr_test_array,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"x", GS_TYPE_DOUBLE_ARRAY, GS_TYPE_OPTION_NULLABLE,
						"y", GS_TYPE_DOUBLE_ARRAY, GS_TYPE_OPTION_NULLABLE);

	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "bool_test_a", &bool_test_a,
						10,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a1", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"a2", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"a3", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"a4", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"a5", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"a6", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"a7", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"a8", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"a9", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE);

	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "bool_test_b", &bool_test_b,
						10,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b1", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"b2", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"b3", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"b4", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"b5", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"b6", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"b7", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"b8", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"b9", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE);

	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_data_2k", &agg_data_2k,
						1,
						"g", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);

	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_data_20k", &agg_data_20k,
						1,
						"g", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);

	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_group_1", &agg_group_1,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c2", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"c3", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_group_2", &agg_group_2,
						5,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c1", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"c2", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"c3", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_group_3", &agg_group_3,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c1", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"c2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c3", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_group_4", &agg_group_4,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c1", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"c2", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"c3", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_hash_1", &agg_hash_1,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c2", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"c3", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_hash_2", &agg_hash_2,
						5,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c1", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"c2", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"c3", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_hash_3", &agg_hash_3,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c1", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"c2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c3", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_hash_4", &agg_hash_4,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c1", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"c2", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"c3", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "road", &road,
						2,
						"name", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"path", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "road_tmp", &road_tmp,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "num_data", &num_data,
						3,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"val", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "num_exp_add", &num_exp_add,
						4,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"id2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"expected", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "num_exp_sub", &num_exp_sub,
						4,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"id2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"expected", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "num_exp_div", &num_exp_div,
						4,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"id2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"expected", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "num_exp_mul", &num_exp_mul,
						4,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"id2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"expected", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "num_exp_sqrt", &num_exp_sqrt,
						3,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"expected", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "num_exp_ln", &num_exp_ln,
						3,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"expected", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "num_exp_log10", &num_exp_log10,
						3,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"expected", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "num_exp_power_10_ln", &num_exp_power_10_ln,
						3,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"expected", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "num_result", &num_result,
						4,
						"idx", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"id2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"result", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "ceil_floor_round", &ceil_floor_round,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "width_bucket_tbl", &width_bucket_tbl,
						5,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"id1", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"id2", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"id3", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"id4", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "width_bucket_test", &width_bucket_test,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"operand_num", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"operand_f8", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "num_input_test", &num_input_test,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"n1", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "num_test_calc", &num_test_calc,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"n1", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"n2", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "fract_only", &fract_only,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"val", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "to_number_test", &to_number_test,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"val", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"fmt", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);

	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "update_test", &update_test,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_b_1_b_10", &part_b_1_b_10,
						6,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"d", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"e", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_a_10_a_20", &part_a_10_a_20,
						6,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"d", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"e", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_a_1_a_10", &part_a_1_a_10,
						6,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"d", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"e", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_d_1_15", &part_d_1_15,
						6,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"d", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"e", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_d_15_20", &part_d_15_20,
						6,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"d", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"e", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "list_part1", &list_part1,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "list_default", &list_default,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "hpart1", &hpart1,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "hpart2", &hpart2,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "hpart3", &hpart3,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "hpart4", &hpart4,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_def1", &part_def1,
						6,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"d", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"e", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "inserttest", &inserttest,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"col2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col3", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "inserttest01", &inserttest01,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"col2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"col3", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part1", &part1,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part2", &part2,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part3", &part3,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part4", &part4,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_aa_bb", &part_aa_bb,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_cc_dd", &part_cc_dd,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_null", &part_null,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_ee_ff1", &part_ee_ff1,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_ee_ff2", &part_ee_ff2,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_xx_yy_p1", &part_xx_yy_p1,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_xx_yy_defpart", &part_xx_yy_defpart,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_default_p1", &part_default_p1,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "lparted_nonullpart_a", &lparted_nonullpart_a,
						2,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mlparted12", &mlparted12,
						2,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mlparted3", &mlparted3,
						2,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mlparted_def1", &mlparted_def1,
						4,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"d", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mlparted_def2", &mlparted_def2,
						4,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"d", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mlparted_defd", &mlparted_defd,
						4,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"d", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mlparted5_a", &mlparted5_a,
						4,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"d", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_default_p2", &part_default_p2,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_def", &part_def,
						3,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "hpart10", &hpart10,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "hpart11", &hpart11,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "hpart12", &hpart12,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "hpart13", &hpart13,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "part_default", &part_default,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mcrparted0", &mcrparted0,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mcrparted1", &mcrparted1,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mcrparted2", &mcrparted2,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mcrparted3", &mcrparted3,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mcrparted4", &mcrparted4,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mcrparted5", &mcrparted5,
						4,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "donothingbrtrig_test1", &donothingbrtrig_test1,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "donothingbrtrig_test2", &donothingbrtrig_test2,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mcrparted1_lt_b", &mcrparted1_lt_b,
						2,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mcrparted2_b", &mcrparted2_b,
						2,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mcrparted3_c_to_common", &mcrparted3_c_to_common,
						2,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mcrparted4_common_lt_0", &mcrparted4_common_lt_0,
						2,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mcrparted5_common_0_to_10", &mcrparted5_common_0_to_10,
						2,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mcrparted6_common_ge_10", &mcrparted6_common_ge_10,
						2,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mcrparted7_gt_common_lt_d", &mcrparted7_gt_common_lt_d,
						2,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "mcrparted8_ge_d", &mcrparted8_ge_d,
						2,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "inserttest3", &inserttest3,
						3,
						"f1", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"f2", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"f3", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "brtrigpartcon1", &brtrigpartcon1,
						2,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "returningwrtest1", &returningwrtest1,
						1,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "returningwrtest2", &returningwrtest2,
						2,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "local_tbl", &local_tbl,
						3,
						"c1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c2", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c3", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_fns_1", &agg_fns_1,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "agg_fns_2", &agg_fns_2,
						3,
						"a", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"b", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "string_agg1", &string_agg1,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "string_agg2", &string_agg2,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "string_agg3", &string_agg3,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "string_agg4", &string_agg4,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"a", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "tbl01", &tbl01,
						2,
						"id", GS_TYPE_LONG, GS_TYPE_OPTION_NOT_NULL,
						"c1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "tbl02", &tbl02,
						4,
						"id", GS_TYPE_STRING, GS_TYPE_OPTION_NOT_NULL,
						"c1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
						"c2", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"c3", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "tbl03", &tbl03,
						2,
						"id", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NOT_NULL,
						"c1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "tbl04", &tbl04,
						6,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c1", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"c2", GS_TYPE_LONG, GS_TYPE_OPTION_NULLABLE,
						"c3", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"c4", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"c5", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "tbl05", &tbl05,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"v", GS_TYPE_BLOB, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "tbl06", &tbl06,
						6,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c1", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
						"c2", GS_TYPE_LONG, GS_TYPE_OPTION_NULLABLE,
						"c3", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
						"c4", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
						"c5", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = set_tableInfo(store, "test_explicit_cast", &test_explicit_cast,
						2,
						"id", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL,
						"c1", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE);
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	/* Initialize data for some tables */
	ret = insert_recordsFromTSV(store, &INT2_TBL, "/tmp/jdbc/int2.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &INT4_TBL, "/tmp/jdbc/int4_tbl.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &INT8_TBL, "/tmp/jdbc/int8_tbl.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &time_series_tbl, "/tmp/jdbc/time_series.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &onek, "/tmp/jdbc/onek.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &onek2, "/tmp/jdbc/onek.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &tenk, "/tmp/jdbc/tenk.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &tenk1, "/tmp/jdbc/tenk.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &tenk2, "/tmp/jdbc/tenk.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &aggtest, "/tmp/jdbc/agg.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &regr_test, "/tmp/jdbc/regr_test.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &student, "/tmp/jdbc/student.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &person, "/tmp/jdbc/person.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &road, "/tmp/jdbc/streets.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &VARCHAR_TBL, "/tmp/jdbc/varchar_tbl.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &text_tbl, "/tmp/jdbc/text_tbl.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &tbl04, "/tmp/jdbc/tbl04.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;

	ret = insert_recordsFromTSV(store, &tbl06, "/tmp/jdbc/tbl06.data");
	if (!GS_SUCCEEDED(ret))
		goto EXIT;
EXIT:
	/* Release the resource */
	gsCloseGridStore(&store, GS_TRUE);
	return ret;
}

/* Main funtion */
GSResult
main(int argc, char *argv[])
{
	GSResult	ret = !GS_RESULT_OK;
	int			i = 0;
	char	   *key,
			   *value;
	char	   *host,
			   *port,
			   *cluster,
			   *user,
			   *passwd;

	if (argc < 6)
	{
		printf("Missing arguments\n");
		goto TERMINATE;
	}
	else
	{
		for (i = 1; i < argc; i++)
		{
			/* Argument format: key=value */
			key = strtok(argv[i], "=");
			value = strtok(NULL, " ");
			if (value == NULL)
			{
				printf("Invalid options\n"
					   "Usage:\n    ./griddb_init host=a port=b cluster=c user=d passwd=e\n");
				goto TERMINATE;
			}
			else
			{
				if (strcmp(key, "host") == 0)
				{
					host = value;
				}
				else if (strcmp(key, "port") == 0)
				{
					/* Validate port number limitation */
					if (atoi(value) > 65535 || atoi(value) < 0)
					{
						printf("Invalid port number\n");
						goto TERMINATE;
					}
					port = value;
				}
				else if (strcmp(key, "cluster") == 0)
				{
					cluster = value;
				}
				else if (strcmp(key, "user") == 0)
				{
					user = value;
				}
				else if (strcmp(key, "passwd") == 0)
				{
					passwd = value;
				}
				else
				{
					printf("Invalid options\n"
						   "Usage:\n    ./griddb_init host=a port=b cluster=c user=d passwd=e\n");
					goto TERMINATE;
				}
			}
		}
	}
	ret = griddb_init(host, port, cluster, user, passwd);
	if (GS_SUCCEEDED(ret))
	{
		printf("Initialize all containers sucessfully.\n");
	}
	else
	{
		printf("Initializer has some problems!\n");
	}
TERMINATE:
	return ret;
}
