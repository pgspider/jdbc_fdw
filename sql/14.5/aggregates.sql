--
-- AGGREGATES
--
--Testcase 1:
CREATE EXTENSION :DB_EXTENSIONNAME;
--Testcase 2:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME OPTIONS(
drivername :DB_DRIVERNAME,
url :DB_URL,
querytimeout '10',
jarfile :DB_DRIVERPATH,
maxheapsize '600'
);
--Testcase 3:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS(username :DB_USER,password :DB_PASS);
--Testcase 4:
CREATE FOREIGN TABLE onek (
  unique1   int4,
  unique2   int4,
  two       int4,
  four      int4,
  ten       int4,
  twenty    int4,
  hundred   int4,
  thousand  int4,
  twothousand int4,
  fivethous int4,
  tenthous  int4,
  odd       int4,
  even      int4,
  stringu1  name,
  stringu2  name,
  string4   name) SERVER :DB_SERVERNAME OPTIONS ( table_name 'onek');
--Testcase 5:
CREATE FOREIGN TABLE aggtest (
  id      int4,
  a       int2,
  b     float4
) SERVER :DB_SERVERNAME OPTIONS ( table_name 'aggtest');
--Testcase 6:
CREATE FOREIGN TABLE tenk1 (
  unique1   int4,
  unique2   int4,
  two     int4,
  four    int4,
  ten     int4,
  twenty    int4,
  hundred   int4,
  thousand  int4,
  twothousand int4,
  fivethous int4,
  tenthous  int4,
  odd     int4,
  even    int4,
  stringu1  text,
  stringu2  text,
  string4   text
) SERVER :DB_SERVERNAME OPTIONS ( table_name 'tenk1');
--Testcase 7:
CREATE FOREIGN TABLE int8_tbl (id int, q1 int8, q2 int8) SERVER :DB_SERVERNAME OPTIONS ( table_name 'int8_tbl');
--Testcase 8:
CREATE FOREIGN TABLE int4_tbl (id int, f1 int4) SERVER :DB_SERVERNAME OPTIONS ( table_name 'int4_tbl');  
-- avoid bit-exact output here because operations may not be bit-exact.
--Testcase 9:
SET extra_float_digits = 0;
--Testcase 10:
EXPLAIN VERBOSE SELECT avg(four) AS avg_1 FROM onek;
--Testcase 11:
SELECT avg(four) AS avg_1 FROM onek;
--Testcase 12:
EXPLAIN VERBOSE SELECT avg(a) AS avg_32 FROM aggtest WHERE a < 100;
--Testcase 13:
SELECT avg(a) AS avg_32 FROM aggtest WHERE a < 100;

-- In 7.1, avg(float4) is computed using float8 arithmetic.
-- Round the result to 3 digits to avoid platform-specific results.
--Testcase 14:
EXPLAIN VERBOSE SELECT avg(b)::numeric(10,3) AS avg_107_943 FROM aggtest;
--Testcase 15:
SELECT avg(b)::numeric(10,3) AS avg_107_943 FROM aggtest;

--Testcase 16:
EXPLAIN VERBOSE SELECT sum(four) AS sum_1500 FROM onek;
--Testcase 17:
SELECT sum(four) AS sum_1500 FROM onek;
--Testcase 18:
EXPLAIN VERBOSE SELECT sum(a) AS sum_198 FROM aggtest;
--Testcase 19:
SELECT sum(a) AS sum_198 FROM aggtest;
--Testcase 20:
EXPLAIN VERBOSE SELECT sum(b) AS avg_431_773 FROM aggtest;
--Testcase 21:
SELECT sum(b) AS avg_431_773 FROM aggtest;
--Testcase 22:
EXPLAIN VERBOSE SELECT max(four) AS max_3 FROM onek;
--Testcase 23:
SELECT max(four) AS max_3 FROM onek;
--Testcase 24:
EXPLAIN VERBOSE SELECT max(a) AS max_100 FROM aggtest;
--Testcase 25:
SELECT max(a) AS max_100 FROM aggtest;
--Testcase 26:
EXPLAIN VERBOSE SELECT max(aggtest.b) AS max_324_78 FROM aggtest;
--Testcase 27:
SELECT max(aggtest.b) AS max_324_78 FROM aggtest;
--Testcase 28:
EXPLAIN VERBOSE SELECT stddev_pop(b) FROM aggtest;
--Testcase 29:
SELECT stddev_pop(b) FROM aggtest;
--Testcase 30:
EXPLAIN VERBOSE SELECT stddev_samp(b) FROM aggtest;
--Testcase 31:
SELECT stddev_samp(b) FROM aggtest;
--Testcase 32:
EXPLAIN VERBOSE SELECT var_pop(b) FROM aggtest;
--Testcase 33:
SELECT var_pop(b) FROM aggtest;
--Testcase 34:
EXPLAIN VERBOSE SELECT var_samp(b) FROM aggtest;
--Testcase 35:
SELECT var_samp(b) FROM aggtest;
--Testcase 36:
EXPLAIN VERBOSE SELECT stddev_pop(b::numeric) FROM aggtest;
--Testcase 37:
SELECT stddev_pop(b::numeric) FROM aggtest;
--Testcase 38:
EXPLAIN VERBOSE SELECT stddev_samp(b::numeric) FROM aggtest;
--Testcase 39:
SELECT stddev_samp(b::numeric) FROM aggtest;
--Testcase 40:
EXPLAIN VERBOSE SELECT var_pop(b::numeric) FROM aggtest;
--Testcase 41:
SELECT var_pop(b::numeric) FROM aggtest;
--Testcase 42:
EXPLAIN VERBOSE SELECT var_samp(b::numeric) FROM aggtest;
--Testcase 43:
SELECT var_samp(b::numeric) FROM aggtest;

-- SQL2003 binary aggregates
--Testcase 44:
EXPLAIN VERBOSE SELECT regr_count(b, a) FROM aggtest;
--Testcase 45:
SELECT regr_count(b, a) FROM aggtest;
--Testcase 46:
EXPLAIN VERBOSE SELECT regr_sxx(b, a) FROM aggtest;
--Testcase 47:
SELECT regr_sxx(b, a) FROM aggtest;
--Testcase 48:
EXPLAIN VERBOSE SELECT regr_syy(b, a) FROM aggtest;
--Testcase 49:
SELECT regr_syy(b, a) FROM aggtest;
--Testcase 50:
EXPLAIN VERBOSE SELECT regr_sxy(b, a) FROM aggtest;
--Testcase 51:
SELECT regr_sxy(b, a) FROM aggtest;
--Testcase 52:
EXPLAIN VERBOSE SELECT regr_avgx(b, a), regr_avgy(b, a) FROM aggtest;
--Testcase 53:
SELECT regr_avgx(b, a), regr_avgy(b, a) FROM aggtest;
--Testcase 54:
EXPLAIN VERBOSE SELECT regr_r2(b, a) FROM aggtest;
--Testcase 55:
SELECT regr_r2(b, a) FROM aggtest;
--Testcase 56:
EXPLAIN VERBOSE SELECT regr_slope(b, a), regr_intercept(b, a) FROM aggtest;
--Testcase 57:
SELECT regr_slope(b, a), regr_intercept(b, a) FROM aggtest;
--Testcase 58:
EXPLAIN VERBOSE SELECT covar_pop(b, a), covar_samp(b, a) FROM aggtest;
--Testcase 59:
SELECT covar_pop(b, a), covar_samp(b, a) FROM aggtest;
--Testcase 60:
EXPLAIN VERBOSE SELECT corr(b, a) FROM aggtest;
--Testcase 61:
SELECT corr(b, a) FROM aggtest;

-- test accum and combine functions directly
--Testcase 62:
CREATE FOREIGN TABLE regr_test (id int, x float8, y float8) SERVER :DB_SERVERNAME
  OPTIONS (table_name 'regr_test');
--Testcase 63:
EXPLAIN VERBOSE SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test WHERE x IN (10,20,30,80);
--Testcase 64:
SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test WHERE x IN (10,20,30,80);
--Testcase 65:
EXPLAIN VERBOSE SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x) FROM regr_test;
--Testcase 66:
SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x) FROM regr_test;
--Testcase 67:
EXPLAIN VERBOSE SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test WHERE x IN (10,20,30);
--Testcase 68:
SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test WHERE x IN (10,20,30);
--Testcase 69:
EXPLAIN VERBOSE SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test WHERE x IN (80,100);
--Testcase 70:
SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test WHERE x IN (80,100);
--Testcase 71:
DROP FOREIGN TABLE regr_test;

-- test count, distinct
--Testcase 72:
EXPLAIN VERBOSE SELECT count(four) AS cnt_1000 FROM onek;
--Testcase 73:
SELECT count(four) AS cnt_1000 FROM onek;
--Testcase 74:
EXPLAIN VERBOSE SELECT count(DISTINCT four) AS cnt_4 FROM onek;
--Testcase 75:
SELECT count(DISTINCT four) AS cnt_4 FROM onek;

-- test for outer-level aggregates
-- Test handling of sublinks within outer-level aggregates.
-- Per bug report from Daniel Grace.
--Testcase 76:
EXPLAIN VERBOSE select
  (select max((select i.unique2 from tenk1 i where i.unique1 = o.unique1)))
from tenk1 o;
--Testcase 77:
select
  (select max((select i.unique2 from tenk1 i where i.unique1 = o.unique1)))
from tenk1 o;

--
-- test boolean aggregates
--
-- first test all possible transition and final states

--Testcase 78:
CREATE FOREIGN TABLE bool_test(
  id serial OPTIONS (key 'true'), 
  b1 BOOL,
  b2 BOOL,
  b3 BOOL,
  b4 BOOL) SERVER :DB_SERVERNAME OPTIONS (table_name 'bool_test');

-- empty case
--Testcase 79:
SELECT
  BOOL_AND(b1)   AS "n",
  BOOL_OR(b3)    AS "n"
FROM bool_test;

--Testcase 183:
INSERT INTO bool_test(b1, b2, b3, b4) VALUES
  (TRUE, null, FALSE, null),
  (FALSE, TRUE, null, null),
  (null, TRUE, FALSE, null);
--Testcase 80:
SELECT
  BOOL_AND(b1)     AS "f",
  BOOL_AND(b2)     AS "t",
  BOOL_AND(b3)     AS "f",
  BOOL_AND(b4)     AS "n",
  BOOL_AND(NOT b2) AS "f",
  BOOL_AND(NOT b3) AS "t"
FROM bool_test;

--Testcase 81:
SELECT
  EVERY(b1)     AS "f",
  EVERY(b2)     AS "t",
  EVERY(b3)     AS "f",
  EVERY(b4)     AS "n",
  EVERY(NOT b2) AS "f",
  EVERY(NOT b3) AS "t"
FROM bool_test;

--Testcase 82:
SELECT
  BOOL_OR(b1)      AS "t",
  BOOL_OR(b2)      AS "t",
  BOOL_OR(b3)      AS "f",
  BOOL_OR(b4)      AS "n",
  BOOL_OR(NOT b2)  AS "f",
  BOOL_OR(NOT b3)  AS "t"
FROM bool_test;

--
-- Test cases that should be optimized into indexscans instead of
-- the generic aggregate implementation.
--

-- Basic cases
--Testcase 83:
explain (costs off)
  select min(unique1) from tenk1;
--Testcase 84:
select min(unique1) from tenk1;
--Testcase 85:
explain (costs off)
  select max(unique1) from tenk1;
--Testcase 86:
select max(unique1) from tenk1;
--Testcase 87:
explain (costs off)
  select max(unique1) from tenk1 where unique1 < 42;
--Testcase 88:
select max(unique1) from tenk1 where unique1 < 42;
--Testcase 89:
explain (costs off)
  select max(unique1) from tenk1 where unique1 > 42;
--Testcase 90:
select max(unique1) from tenk1 where unique1 > 42;

-- the planner may choose a generic aggregate here if parallel query is
-- enabled, since that plan will be parallel safe and the "optimized"
-- plan, which has almost identical cost, will not be.  we want to test
-- the optimized plan, so temporarily disable parallel query.
-- multi-column index (uses tenk1_thous_tenthous)
--Testcase 91:
explain (costs off)
  select max(tenthous) from tenk1 where thousand = 33;
--Testcase 92:
select max(tenthous) from tenk1 where thousand = 33;
--Testcase 93:
explain (costs off)
  select min(tenthous) from tenk1 where thousand = 33;
--Testcase 94:
select min(tenthous) from tenk1 where thousand = 33;

-- check parameter propagation into an indexscan subquery
--Testcase 95:
explain (costs off)
  select f1, (select min(unique1) from tenk1 where unique1 > f1) AS gt
    from int4_tbl;
--Testcase 96:
select f1, (select min(unique1) from tenk1 where unique1 > f1) AS gt
  from int4_tbl;

-- check some cases that were handled incorrectly in 8.3.0
--Testcase 97:
explain (costs off)
  select distinct max(unique2) from tenk1;
--Testcase 98:
select distinct max(unique2) from tenk1;

-- interesting corner case: constant gets optimized into a seqscan
--Testcase 99:
explain (costs off)
  select max(100) from tenk1;
--Testcase 100:
select max(100) from tenk1;

-- check for correct detection of nested-aggregate errors
--Testcase 101:
EXPLAIN VERBOSE select max(min(unique1)) from tenk1;
--Testcase 102:
select max(min(unique1)) from tenk1;
--Testcase 103:
EXPLAIN VERBOSE select (select max(min(unique1)) from int8_tbl) from tenk1;
--Testcase 104:
select (select max(min(unique1)) from int8_tbl) from tenk1;

--
-- Test combinations of DISTINCT and/or ORDER BY
--
--Testcase 105:
CREATE FOREIGN TABLE agg_fns_1(id int, a int) SERVER :DB_SERVERNAME
  OPTIONS (table_name 'agg_fns_1');

--Testcase 184:
INSERT INTO agg_fns_1 VALUES (1, 1);
--Testcase 185:
INSERT INTO agg_fns_1 VALUES (2, 2);
--Testcase 186:
INSERT INTO agg_fns_1 VALUES (3, 1);
--Testcase 187:
INSERT INTO agg_fns_1 VALUES (4, 3);
--Testcase 188:
INSERT INTO agg_fns_1 VALUES (5, null);
--Testcase 189:
INSERT INTO agg_fns_1 VALUES (6, 2);

--Testcase 106:
select array_agg(distinct a) from agg_fns_1;

-- check node I/O via view creation and usage, also deparsing logic
--Testcase 107:
CREATE FOREIGN TABLE agg_fns_2(a int, b int, c text) SERVER :DB_SERVERNAME
  OPTIONS (table_name 'agg_fns_2');
--Testcase 190:
INSERT INTO agg_fns_2 VALUES (1, 3, 'foo');
--Testcase 191:
INSERT INTO agg_fns_2 VALUES (0, null, null);
--Testcase 192:
INSERT INTO agg_fns_2 VALUES (2, 2, 'bar');
--Testcase 193:
INSERT INTO agg_fns_2 VALUES (3, 1, 'baz');

--Testcase 108:
create type aggtype as (a integer, b integer, c text);
--Testcase 109:
create function aggfns_trans(aggtype[],integer,integer,text) returns aggtype[]
as 'select array_append($1,ROW($2,$3,$4)::aggtype)'
language sql immutable;

--Testcase 110:
create aggregate aggfns(integer,integer,text) (
   sfunc = aggfns_trans, stype = aggtype[], sspace = 10000,
   initcond = '{}'
);

--Testcase 111:
create view agg_view1 as
  select aggfns(a,b,c) from agg_fns_2;

--Testcase 112:
EXPLAIN VERBOSE select * from agg_view1;
--Testcase 113:
select * from agg_view1;
--Testcase 114:
EXPLAIN VERBOSE select pg_get_viewdef('agg_view1'::regclass);
--Testcase 115:
select pg_get_viewdef('agg_view1'::regclass);

--Testcase 116:
create or replace view agg_view1 as
  select aggfns(distinct a,b,c) from agg_fns_2, generate_series(1,3) i;

--Testcase 117:
EXPLAIN VERBOSE select * from agg_view1;
--Testcase 118:
select * from agg_view1;
--Testcase 119:
EXPLAIN VERBOSE select pg_get_viewdef('agg_view1'::regclass);
--Testcase 120:
select pg_get_viewdef('agg_view1'::regclass);

--Testcase 121:
drop view agg_view1;

-- string_agg tests
--Testcase 122:
CREATE FOREIGN TABLE string_agg1(id int, a text) SERVER :DB_SERVERNAME
  OPTIONS (table_name 'string_agg1');

--Testcase 194:
INSERT INTO string_agg1 VALUES (1, 'aaaa');
--Testcase 195:
INSERT INTO string_agg1 VALUES (2, 'bbbb');
--Testcase 196:
INSERT INTO string_agg1 VALUES (3, 'cccc');

--Testcase 123:
CREATE FOREIGN TABLE string_agg2(id int, a text) SERVER :DB_SERVERNAME
  OPTIONS (table_name 'string_agg2');

--Testcase 197:
INSERT INTO string_agg2 VALUES (1, 'aaaa');
--Testcase 198:
INSERT INTO string_agg2 VALUES (2, null);
--Testcase 199:
INSERT INTO string_agg2 VALUES (3, 'bbbb');
--Testcase 200:
INSERT INTO string_agg2 VALUES (4, 'cccc');

--Testcase 124:
CREATE FOREIGN TABLE string_agg3(id int, a text) SERVER :DB_SERVERNAME
  OPTIONS ( table_name 'string_agg3');

--Testcase 201:
INSERT INTO string_agg3 VALUES (1, null);
--Testcase 202:
INSERT INTO string_agg3 VALUES (2, null);
--Testcase 203:
INSERT INTO string_agg3 VALUES (3, 'bbbb');
--Testcase 204:
INSERT INTO string_agg3 VALUES (4, 'cccc');

--Testcase 125:
CREATE FOREIGN TABLE string_agg4(id int, a text) SERVER :DB_SERVERNAME
  OPTIONS (table_name 'string_agg4');

--Testcase 205:
INSERT INTO string_agg4 VALUES (1, null);
--Testcase 206:
INSERT INTO string_agg4 VALUES (2, null);

--Testcase 126:
EXPLAIN VERBOSE select string_agg(a,',') from string_agg1;
--Testcase 127:
select string_agg(a,',') from string_agg1;
--Testcase 128:
EXPLAIN VERBOSE select string_agg(a,',') from string_agg2;
--Testcase 129:
select string_agg(a,',') from string_agg2;
--Testcase 130:
EXPLAIN VERBOSE select string_agg(a,'AB') from string_agg3;
--Testcase 131:
select string_agg(a,'AB') from string_agg3;
--Testcase 132:
EXPLAIN VERBOSE select string_agg(a,',') from string_agg4;
--Testcase 133:
select string_agg(a,',') from string_agg4;

-- string_agg bytea tests
--Testcase 134:
create foreign table bytea_test_table(id int OPTIONS (key 'true'), v bytea) SERVER :DB_SERVERNAME
  OPTIONS (table_name 'bytea_test_table');
--Testcase 135:
EXPLAIN VERBOSE select string_agg(v, '') from bytea_test_table;
--Testcase 136:
select string_agg(v, '') from bytea_test_table;
--Testcase 137:
EXPLAIN VERBOSE insert into bytea_test_table (id, v) values(1, decode('ff','hex'));
--Testcase 138:
insert into bytea_test_table (id, v) values(1, decode('ff','hex'));
--Testcase 139:
EXPLAIN VERBOSE select string_agg(v, '') from bytea_test_table;
--Testcase 140:
select string_agg(v, '') from bytea_test_table;
--Testcase 141:
EXPLAIN VERBOSE insert into bytea_test_table (id, v) values(2, decode('aa','hex'));
--Testcase 142:
insert into bytea_test_table (id, v) values(2, decode('aa','hex'));
--Testcase 143:
EXPLAIN VERBOSE select string_agg(v, '') from bytea_test_table;
--Testcase 144:
select string_agg(v, '') from bytea_test_table;
--Testcase 145:
EXPLAIN VERBOSE select string_agg(v, NULL) from bytea_test_table;
--Testcase 146:
select string_agg(v, NULL) from bytea_test_table;
--Testcase 147:
EXPLAIN VERBOSE select string_agg(v, decode('ee', 'hex')) from bytea_test_table;
--Testcase 148:
select string_agg(v, decode('ee', 'hex')) from bytea_test_table;

--Testcase 149:
drop foreign table bytea_test_table;

-- FILTER tests
--Testcase 150:
EXPLAIN VERBOSE select min(unique1) filter (where unique1 > 100) from tenk1;
--Testcase 151:
select min(unique1) filter (where unique1 > 100) from tenk1;
--Testcase 152:
EXPLAIN VERBOSE select sum(1/ten) filter (where ten > 0) from tenk1;
--Testcase 153:
select sum(1/ten) filter (where ten > 0) from tenk1;

-- outer reference in FILTER (PostgreSQL extension)
--Testcase 154:
EXPLAIN VERBOSE
select
  (select max((select i.unique2 from tenk1 i where i.unique1 = o.unique1))
     filter (where o.unique1 < 10))
from tenk1 o;	
--Testcase 155:
select
  (select max((select i.unique2 from tenk1 i where i.unique1 = o.unique1))
     filter (where o.unique1 < 10))
from tenk1 o;					-- outer query is aggregation query

-- subquery in FILTER clause (PostgreSQL extension)
--Testcase 156:
EXPLAIN VERBOSE
select sum(unique1) FILTER (WHERE
  unique1 IN (SELECT unique1 FROM onek where unique1 < 100)) FROM tenk1;
--Testcase 157:
select sum(unique1) FILTER (WHERE
  unique1 IN (SELECT unique1 FROM onek where unique1 < 100)) FROM tenk1;

-- variadic aggregates
--Testcase 158:
create function least_accum(int8, int8) returns int8 language sql as
  'select least($1, $2)';

--Testcase 159:
create function least_accum(anyelement, variadic anyarray)
returns anyelement language sql as
  'select least($1, min($2[i])) from generate_subscripts($2,1) g(i)';
--Testcase 160:
create function cleast_accum(anycompatible, variadic anycompatiblearray)
returns anycompatible language sql as
  'select least($1, min($2[i])) from generate_subscripts($2,1) g(i)';

--Testcase 161:
create aggregate least_agg(int8) (
  stype = int8, sfunc = least_accum
);
--Testcase 162:
create aggregate least_agg(variadic items anyarray) (
  stype = anyelement, sfunc = least_accum
);
--Testcase 163:
create aggregate cleast_agg(variadic items anycompatiblearray) (
  stype = anycompatible, sfunc = cleast_accum
);
--Testcase 164:
EXPLAIN VERBOSE select least_agg(q1,q2) from int8_tbl;
--Testcase 165:
select least_agg(q1,q2) from int8_tbl;
--Testcase 166:
EXPLAIN VERBOSE select least_agg(variadic array[q1,q2]) from int8_tbl;
--Testcase 167:
select least_agg(variadic array[q1,q2]) from int8_tbl;
--Testcase 168:
EXPLAIN VERBOSE select cleast_agg(q1,q2) from int8_tbl;
--Testcase 169:
select cleast_agg(q1,q2) from int8_tbl;
--Testcase 170:
EXPLAIN VERBOSE select cleast_agg(4.5,f1) from int4_tbl;
--Testcase 171:
select cleast_agg(4.5,f1) from int4_tbl;
--Testcase 172:
EXPLAIN VERBOSE select cleast_agg(variadic array[4.5,f1]) from int4_tbl;
--Testcase 173:
select cleast_agg(variadic array[4.5,f1]) from int4_tbl;
--Testcase 174:
EXPLAIN VERBOSE select pg_typeof(cleast_agg(variadic array[4.5,f1])) from int4_tbl;
--Testcase 175:
select pg_typeof(cleast_agg(variadic array[4.5,f1])) from int4_tbl;

--Drop because other test file also create this function
--Testcase 179:
DROP AGGREGATE least_agg(variadic items anyarray);
--Testcase 180:
DROP AGGREGATE least_agg(int8);
--Testcase 181:
DROP FUNCTION least_accum(anyelement, variadic anyarray);
--Testcase 182:
DROP FUNCTION least_accum(int8, int8);

-- Make sure that generation of HashAggregate for uniqification purposes
-- does not lead to array overflow due to unexpected duplicate hash keys
-- see CAFeeJoKKu0u+A_A9R9316djW-YW3-+Gtgvy3ju655qRHR3jtdA@mail.gmail.com
--Testcase 209:
set enable_memoize to off;
--Testcase 176:
explain (costs off)
  select 1 from tenk1
   where (hundred, thousand) in (select twothousand, twothousand from onek);
--Testcase 210:
reset enable_memoize;  

--Testcase 207:
DROP TYPE aggtype CASCADE;
--Testcase 208:
DROP FUNCTION cleast_accum CASCADE;
--Testcase 177:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 178:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
