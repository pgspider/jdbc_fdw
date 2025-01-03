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

--Testcase 211:
CREATE FOREIGN TABLE v (id serial OPTIONS(key 'true'), v int) SERVER :DB_SERVERNAME OPTIONS ( table_name 'v');

--Testcase 212:
DELETE FROM v;
--Testcase 213:
INSERT INTO v(v) VALUES (1), (2), (3);
--Testcase 214:
EXPLAIN VERBOSE
SELECT any_value(v) FROM v;
--Testcase 215:
SELECT any_value(v) FROM v;

--Testcase 216:
DELETE FROM v;
--Testcase 217:
INSERT INTO v(v) VALUES (NULL);
--Testcase 218:
EXPLAIN VERBOSE
SELECT any_value(v) FROM v;
--Testcase 219:
SELECT any_value(v) FROM v;

--Testcase 220:
DELETE FROM v;
--Testcase 221:
INSERT INTO v(v) VALUES (NULL), (1), (2);
--Testcase 222:
EXPLAIN VERBOSE
SELECT any_value(v) FROM v;
--Testcase 223:
SELECT any_value(v) FROM v;

-- jdbc_fdw does not support array
-- SELECT any_value(v) FROM (VALUES (array['hello', 'world'])) AS v (v);

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

-- DISTINCT can also trigger wrong answers with hash aggregation (bug #18465)
begin;
set local enable_sort = off;
--Testcase 262:
explain (costs off)
  select f1, (select distinct min(t1.f1) from int4_tbl t1 where t1.f1 = t0.f1)
  from int4_tbl t0;
--Testcase 263:
select f1, (select distinct min(t1.f1) from int4_tbl t1 where t1.f1 = t0.f1)
from int4_tbl t0;
rollback;

--Testcase 224:
EXPLAIN VERBOSE
select avg((select avg(a1.col1 order by (select avg(a2.col2) from tenk1 a3))
            from tenk1 a1(col1)))
from tenk1 a2(col2);
--Testcase 225:
select avg((select avg(a1.col1 order by (select avg(a2.col2) from tenk1 a3))
            from tenk1 a1(col1)))
from tenk1 a2(col2);

--
-- Test GROUP BY matching of join columns that are type-coerced due to USING
--
--Testcase 226:
CREATE FOREIGN TABLE temp_t1(f1 int, f2 int) SERVER :DB_SERVERNAME;
--Testcase 227:
CREATE FOREIGN TABLE temp_t2(f1 int, f2 oid) SERVER :DB_SERVERNAME;

--Testcase 228:
select f1 from temp_t1 left join temp_t2 using (f1) group by f1;
--Testcase 229:
select f1 from temp_t1 left join temp_t2 using (f1) group by temp_t1.f1;
--Testcase 230:
select temp_t1.f1 from temp_t1 left join temp_t2 using (f1) group by temp_t1.f1;
-- only this one should fail:
--Testcase 231:
select temp_t1.f1 from temp_t1 left join temp_t2 using (f1) group by f1;

-- check case where we have to inject nullingrels into coerced join alias
--Testcase 232:
select f1, count(*) from
temp_t1 x(x0,x1) left join (temp_t1 left join temp_t2 using(f1)) on (x0 = 0)
group by f1;

-- same, for a RelabelType coercion
--Testcase 233:
select f2, count(*) from
temp_t1 x(x0,x1) left join (temp_t1 left join temp_t2 using(f2)) on (x0 = 0)
group by f2;

--Testcase 234:
drop foreign table temp_t1, temp_t2;

--
-- Test planner's selection of pathkeys for ORDER BY aggregates
--

-- Ensure we order by four.  This suits the most aggregate functions.
--Testcase 235:
explain (verbose, costs off)
select sum(two order by two),max(four order by four), min(four order by four)
from tenk1;

-- Ensure we order by two.  It's a tie between ordering by two and four but
-- we tiebreak on the aggregate's position.
--Testcase 236:
explain (costs off)
select
  sum(two order by two), max(four order by four),
  min(four order by four), max(two order by two)
from tenk1;

-- Similar to above, but tiebreak on ordering by four
--Testcase 237:
explain (costs off)
select
  max(four order by four), sum(two order by two),
  min(four order by four), max(two order by two)
from tenk1;

-- Ensure this one orders by ten since there are 3 aggregates that require ten
-- vs two that suit two and four.
--Testcase 238:
explain (costs off)
select
  max(four order by four), sum(two order by two),
  min(four order by four), max(two order by two),
  sum(ten order by ten), min(ten order by ten), max(ten order by ten)
from tenk1;

-- Try a case involving a GROUP BY clause where the GROUP BY column is also
-- part of an aggregate's ORDER BY clause.  We want a sort order that works
-- for the GROUP BY along with the first and the last aggregate.
--Testcase 239:
explain (costs off)
select
  sum(unique1 order by ten, two), sum(unique1 order by four),
  sum(unique1 order by two, four)
from tenk1
group by ten;

-- Ensure that we never choose to provide presorted input to an Aggref with
-- a volatile function in the ORDER BY / DISTINCT clause.  We want to ensure
-- these sorts are performed individually rather than at the query level.
--Testcase 240:
explain (costs off)
select
  sum(unique1 order by two), sum(unique1 order by four),
  sum(unique1 order by four, two), sum(unique1 order by two, random()),
  sum(unique1 order by two, random(), random() + 1)
from tenk1
group by ten;

-- Ensure consecutive NULLs are properly treated as distinct from each other
--Testcase 241:
select array_agg(distinct val)
from (select null as val from generate_series(1, 2));

-- Ensure no ordering is requested when enable_presorted_aggregate is off
set enable_presorted_aggregate to off;
--Testcase 242:
explain (costs off)
select sum(two order by two) from tenk1;
reset enable_presorted_aggregate;
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

-- test a more complex permutation that has previous caused issues
--Testcase 264:
CREATE FOREIGN TABLE agg_t22(id int, c1 text) SERVER :DB_SERVERNAME
  OPTIONS (table_name 'agg_t22');
--Testcase 280:
CREATE FOREIGN TABLE agg_t23(id int) SERVER :DB_SERVERNAME
  OPTIONS (table_name 'agg_t23');
--Testcase 281:
INSERT INTO agg_t22 values (1, 'a');
--Testcase 282:
INSERT INTO agg_t23 values (1);
--Testcase 283:
select
    string_agg(distinct c1, ','),
    sum((
        select sum(b.id)
        from agg_t23 b
        where a.id = b.id
)) from agg_t22 a;

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

-- Test parallel string_agg and array_agg
-- autovacuum is not supported for foreign tables.
-- Therefore we does not add 'with (autovacuum_enabled = off)' into this test case
--Testcase 243:
create foreign table pagg_test (id serial OPTIONS (key 'true'), x int, y int) SERVER :DB_SERVERNAME
  OPTIONS (table_name 'pagg_test');
--Testcase 244:
insert into pagg_test (x, y)
select (case x % 4 when 1 then null else x end), x % 10
from generate_series(1,5000) x;

set parallel_setup_cost TO 0;
set parallel_tuple_cost TO 0;
set parallel_leader_participation TO 0;
set min_parallel_table_scan_size = 0;
set bytea_output = 'escape';
set max_parallel_workers_per_gather = 2;

-- create a view as we otherwise have to repeat this query a few times.
--Testcase 245:
create view v_pagg_test AS
select
	y,
	min(t) AS tmin,max(t) AS tmax,count(distinct t) AS tndistinct,
	min(b) AS bmin,max(b) AS bmax,count(distinct b) AS bndistinct,
	min(a) AS amin,max(a) AS amax,count(distinct a) AS andistinct,
	min(aa) AS aamin,max(aa) AS aamax,count(distinct aa) AS aandistinct
from (
	select
		y,
		unnest(regexp_split_to_array(a1.t, ','))::int AS t,
		unnest(regexp_split_to_array(a1.b::text, ',')) AS b,
		unnest(a1.a) AS a,
		unnest(a1.aa) AS aa
	from (
		select
			y,
			string_agg(x::text, ',') AS t,
			string_agg(x::text::bytea, ',') AS b,
			array_agg(x) AS a,
			array_agg(ARRAY[x]) AS aa
		from pagg_test
		group by y
	) a1
) a2
group by y;

-- Ensure results are correct.
--Testcase 246:
select * from v_pagg_test order by y;

-- Ensure parallel aggregation is actually being used.
--Testcase 247:
explain (verbose, costs off) select * from v_pagg_test order by y;

set max_parallel_workers_per_gather = 0;

-- Ensure results are the same without parallel aggregation.
--Testcase 248:
select * from v_pagg_test order by y;

-- GROUP BY optimization by reordering GROUP BY clauses
--Testcase 265:
CREATE FOREIGN TABLE btg (id serial OPTIONS (key 'true'), x int, y int, z text, w int) SERVER :DB_SERVERNAME OPTIONS ( table_name 'btg_groupby');
--Testcase 266:
INSERT INTO btg (x, y, z, w)
  SELECT
    i % 10 AS x,
    i % 10 AS y,
    'abc' || i % 10 AS z,
    i AS w
  FROM generate_series(1, 100) AS i;

-- CREATE INDEX is not supported for foreign tables.
-- CREATE INDEX btg_x_y_idx ON btg(x, y);
-- ANALYZE btg;

SET enable_hashagg = off;
SET enable_seqscan = off;

-- Because CREATE INDEX is not supported for foreign tables, we cannot utilize the ordering of index scan to avoid a Sort operation.
-- Therefore, the plan still is: Sort Key: y, x.
-- Utilize the ordering of index scan to avoid a Sort operation
--Testcase 267:
EXPLAIN (COSTS OFF)
SELECT count(*) FROM btg GROUP BY y, x;

-- Engage incremental sort
--Testcase 268:
EXPLAIN (COSTS OFF)
SELECT count(*) FROM btg GROUP BY z, y, w, x;

-- Utilize the ordering of subquery scan to avoid a Sort operation
--Testcase 269:
EXPLAIN (COSTS OFF) SELECT count(*)
FROM (SELECT * FROM btg ORDER BY x, y, w, z) AS q1
GROUP BY w, x, z, y;

-- Utilize the ordering of merge join to avoid a full Sort operation
SET enable_hashjoin = off;
SET enable_nestloop = off;
--Testcase 270:
EXPLAIN (COSTS OFF)
SELECT count(*)
  FROM btg t1 JOIN btg t2 ON t1.z = t2.z AND t1.w = t2.w AND t1.x = t2.x
  GROUP BY t1.x, t1.y, t1.z, t1.w;
RESET enable_nestloop;
RESET enable_hashjoin;

-- Should work with and without GROUP-BY optimization
--Testcase 271:
EXPLAIN (COSTS OFF)
SELECT count(*) FROM btg GROUP BY w, x, z, y ORDER BY y, x, z, w;

-- Utilize incremental sort to make the ORDER BY rule a bit cheaper
--Testcase 272:
EXPLAIN (COSTS OFF)
SELECT count(*) FROM btg GROUP BY w, x, y, z ORDER BY x*x, z;

-- Test the case where the number of incoming subtree path keys is more than
-- the number of grouping keys.
-- CREATE INDEX is not supported for foreign tables.
-- CREATE INDEX btg_y_x_w_idx ON btg(y, x, w);
--Testcase 273:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT y, x, array_agg(distinct w)
  FROM btg WHERE y < 0 GROUP BY x, y;

-- Ensure that we do not select the aggregate pathkeys instead of the grouping
-- pathkeys
--Testcase 274:
CREATE FOREIGN TABLE group_agg_pk (id serial OPTIONS (key 'true'), x int, y int, z int, w int, f int) SERVER :DB_SERVERNAME OPTIONS ( table_name 'group_agg_pk');
--Testcase 275:
INSERT INTO group_agg_pk (x, y, z, w, f)
  SELECT
    i % 10 AS x,
    i % 2 AS y,
    i % 2 AS z,
    2 AS w,
    i % 10 AS f
  FROM generate_series(1,100) AS i;

-- ANALYZE group_agg_pk;
SET enable_nestloop = off;
SET enable_hashjoin = off;

--Testcase 276:
EXPLAIN (COSTS OFF)
SELECT avg(c1.f ORDER BY c1.x, c1.y)
FROM group_agg_pk c1 JOIN group_agg_pk c2 ON c1.x = c2.x
GROUP BY c1.w, c1.z;
--Testcase 277:
SELECT avg(c1.f ORDER BY c1.x, c1.y)
FROM group_agg_pk c1 JOIN group_agg_pk c2 ON c1.x = c2.x
GROUP BY c1.w, c1.z;

-- Pathkeys, built in a subtree, can be used to optimize GROUP-BY clause
-- ordering.  Also, here we check that it doesn't depend on the initial clause
-- order in the GROUP-BY list.
--Testcase 284:
EXPLAIN (COSTS OFF)
SELECT c1.y,c1.x FROM group_agg_pk c1
  JOIN group_agg_pk c2
  ON c1.x = c2.x
GROUP BY c1.y,c1.x,c2.x;
--Testcase 285:
EXPLAIN (COSTS OFF)
SELECT c1.y,c1.x FROM group_agg_pk c1
  JOIN group_agg_pk c2
  ON c1.x = c2.x
GROUP BY c1.y,c2.x,c1.x;

RESET enable_nestloop;
RESET enable_hashjoin;
--Testcase 278:
DROP FOREIGN TABLE group_agg_pk;

-- UNIQUE INDEX not support foreign table
-- -- Test the case where the ordering of the scan matches the ordering within the
-- -- aggregate but cannot be found in the group-by list
-- CREATE TABLE agg_sort_order (c1 int PRIMARY KEY, c2 int);
-- CREATE UNIQUE INDEX agg_sort_order_c2_idx ON agg_sort_order(c2);
-- INSERT INTO agg_sort_order SELECT i, i FROM generate_series(1,100)i;
-- ANALYZE agg_sort_order;

-- EXPLAIN (COSTS OFF)
-- SELECT array_agg(c1 ORDER BY c2),c2
-- FROM agg_sort_order WHERE c2 < 100 GROUP BY c1 ORDER BY 2;

-- DROP TABLE FOREIGN TABLE agg_sort_order CASCADE;

--Testcase 279:
DROP FOREIGN TABLE btg;

RESET enable_hashagg;
RESET enable_seqscan;

-- Clean up
reset max_parallel_workers_per_gather;
reset bytea_output;
reset min_parallel_table_scan_size;
reset parallel_leader_participation;
reset parallel_tuple_cost;
reset parallel_setup_cost;

--Testcase 249:
drop view v_pagg_test;
--Testcase 250:
drop foreign table pagg_test;

-- FILTER tests
--Testcase 150:
EXPLAIN VERBOSE select min(unique1) filter (where unique1 > 100) from tenk1;
--Testcase 151:
select min(unique1) filter (where unique1 > 100) from tenk1;
--Testcase 152:
EXPLAIN VERBOSE select sum(1/ten) filter (where ten > 0) from tenk1;
--Testcase 153:
select sum(1/ten) filter (where ten > 0) from tenk1;

--Testcase 251:
DELETE FROM v;
--Testcase 252:
INSERT INTO v(v) VALUES (1), (2), (3);
--Testcase 253:
select any_value(v) filter (where v > 2) from (values (1), (2), (3)) as v (v);

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

-- test multiple usage of an aggregate whose finalfn returns a R/W datum
BEGIN;

--Testcase 254:
CREATE FUNCTION rwagg_sfunc(x anyarray, y anyarray) RETURNS anyarray
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
    RETURN array_fill(y[1], ARRAY[4]);
END;
$$;

--Testcase 255:
CREATE FUNCTION rwagg_finalfunc(x anyarray) RETURNS anyarray
LANGUAGE plpgsql STRICT IMMUTABLE AS $$
DECLARE
    res x%TYPE;
BEGIN
    -- assignment is essential for this test, it expands the array to R/W
    res := array_fill(x[1], ARRAY[4]);
    RETURN res;
END;
$$;

--Testcase 256:
CREATE AGGREGATE rwagg(anyarray) (
    STYPE = anyarray,
    SFUNC = rwagg_sfunc,
    FINALFUNC = rwagg_finalfunc
);

--Testcase 257:
CREATE FUNCTION eatarray(x real[]) RETURNS real[]
LANGUAGE plpgsql STRICT IMMUTABLE AS $$
BEGIN
    x[1] := x[1] + 1;
    RETURN x;
END;
$$;

--Testcase 258:
DELETE FROM v;
--Testcase 259:
INSERT INTO v(v) VALUES (1);
--Testcase 260:
EXPLAIN VERBOSE
SELECT eatarray(rwagg(ARRAY[v::real])), eatarray(rwagg(ARRAY[v::real])) FROM v;
--Testcase 261:
SELECT eatarray(rwagg(ARRAY[v::real])), eatarray(rwagg(ARRAY[v::real])) FROM v;

ROLLBACK;

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
