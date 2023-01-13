-- SET consistant time zones;
--Testcase 1:
SET timezone = 'PST8PDT';
-- ===================================================================
-- create FDW objects
-- ===================================================================

--Testcase 2:
CREATE EXTENSION :DB_EXTENSIONNAME;

--Testcase 3:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
            OPTIONS (drivername :DB_DRIVERNAME,
                    url :DB_URL,
					querytimeout '15',
					jarfile :DB_DRIVERPATH,
					maxheapsize '600'
			);
--Testcase 4:
CREATE SERVER :DB_SERVERNAME2 FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
            OPTIONS (drivername :DB_DRIVERNAME,
                    url :DB_URL,
					querytimeout '15',
					jarfile :DB_DRIVERPATH,
					maxheapsize '600'
			);


--Testcase 5:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS(username :DB_USER,password :DB_PASS);
--Testcase 6:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME2 OPTIONS(username :DB_USER,password :DB_PASS);

-- ===================================================================
-- create objects used through FDW postgres_svr server
-- ===================================================================
--Testcase 7:
CREATE TYPE user_enum AS ENUM ('foo', 'bar', 'buz');
--Testcase 8:
CREATE SCHEMA "S 1";
IMPORT FOREIGN SCHEMA public FROM SERVER :DB_SERVERNAME INTO "S 1"; -- BUG: can not import foreign schema

-- temp fix: create foreign table in schema "S 1"

--Testcase 829:
CREATE FOREIGN TABLE "S 1"."T1" (
	"C_1" int OPTIONS (key 'true'),
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 text
) SERVER :DB_SERVERNAME OPTIONS (table_name 'T1');

--Testcase 826:
INSERT INTO "S 1"."T1"
	SELECT id,
	       id % 10,
	       to_char(id, 'FM00000'),
	       '1970-01-01 00:00:01'::timestamptz + ((id % 100) || ' days')::interval,
	       '1970-01-01 00:00:01'::timestamp + ((id % 100) || ' days')::interval,
	       id % 10,
	       id % 10,
	       'foo'
	FROM generate_series(1, 1000) id;

--Testcase 830:
CREATE FOREIGN TABLE "S 1"."T2" (
	c1 int OPTIONS (key 'true'),
	c2 text
) SERVER :DB_SERVERNAME OPTIONS (table_name 'T2');
--Testcase 831:
INSERT INTO "S 1"."T2"
	SELECT id,
	       'AAA' || to_char(id, 'FM000')
	FROM generate_series(1, 100) id;

--Testcase 832:
CREATE FOREIGN TABLE "S 1"."T3" (
	c1 int OPTIONS (key 'true'),
	c2 int NOT NULL,
	c3 text
) SERVER :DB_SERVERNAME OPTIONS (table_name 'T3');

--Testcase 9:
INSERT INTO "S 1"."T3"
	SELECT id,
	       id + 1,
	       'AAA' || to_char(id, 'FM000')
	FROM generate_series(1, 100) id;
--Testcase 10:
DELETE FROM "S 1"."T3" WHERE c1 % 2 != 0;	-- delete for outer join tests

--Testcase 11:
CREATE FOREIGN TABLE "S 1"."T4" (
	c1 int OPTIONS (key 'true'),
	c2 int NOT NULL,
	c3 text
) SERVER :DB_SERVERNAME OPTIONS (table_name 'T4');
--Testcase 12:
INSERT INTO "S 1"."T4"
	SELECT id,
	       id + 1,
	       'AAA' || to_char(id, 'FM000')
	FROM generate_series(1, 100) id;
--Testcase 13:
DELETE FROM "S 1"."T4" WHERE c1 % 3 != 0;	-- delete for outer join tests

-- ===================================================================
-- create foreign tables
-- ===================================================================
--Testcase 14:
CREATE FOREIGN TABLE ft1 (
	c0 int,
	c1 int OPTIONS (key 'true'),
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 user_enum
) SERVER :DB_SERVERNAME;
--Testcase 15:
ALTER FOREIGN TABLE ft1 DROP COLUMN c0;

--Testcase 16:
CREATE FOREIGN TABLE ft2 (
	c1 int OPTIONS (key 'true'),
	c2 int NOT NULL,
	cx int,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft2',
	c8 user_enum
) SERVER :DB_SERVERNAME;
--Testcase 17:
ALTER FOREIGN TABLE ft2 DROP COLUMN cx;

--Testcase 18:
CREATE FOREIGN TABLE ft4 (
	c1 int OPTIONS (key 'true'),
	c2 int NOT NULL,
	c3 text
) SERVER :DB_SERVERNAME OPTIONS (table_name 'T3');

--Testcase 19:
CREATE FOREIGN TABLE ft5 (
	c1 int OPTIONS (key 'true'),
	c2 int NOT NULL,
	c3 text
) SERVER :DB_SERVERNAME OPTIONS (table_name 'T4');

--Testcase 20:
CREATE FOREIGN TABLE ft6 (
	c1 int OPTIONS (key 'true'),
	c2 int NOT NULL,
	c3 text
) SERVER :DB_SERVERNAME2 OPTIONS (table_name 'T4');

-- ===================================================================
-- tests for validator
-- ===================================================================
-- requiressl and some other parameters are omitted because
-- valid values for them depend on configure options
-- ALTER SERVER :DB_SERVERNAME OPTIONS (
-- 	use_remote_estimate 'false',
-- 	updatable 'true',
-- 	fdw_startup_cost '123.456',
-- 	fdw_tuple_cost '0.123',
-- 	service 'value',
-- 	connect_timeout 'value',
-- 	dbname 'value',
-- 	host 'value',
-- 	hostaddr 'value',
-- 	port 'value',
-- 	--client_encoding 'value',
-- 	application_name 'value',
-- 	--fallback_application_name 'value',
-- 	keepalives 'value',
-- 	keepalives_idle 'value',
-- 	keepalives_interval 'value',
-- 	tcp_user_timeout 'value',
-- 	-- requiressl 'value',
-- 	sslcompression 'value',
-- 	sslmode 'value',
-- 	sslcert 'value',
-- 	sslkey 'value',
-- 	sslrootcert 'value',
-- 	sslcrl 'value',
-- 	--requirepeer 'value',
-- 	krbsrvname 'value',
-- 	gsslib 'value'
-- 	--replication 'value'
-- );

-- Error, invalid list syntax
--Testcase 21:
ALTER SERVER :DB_SERVERNAME OPTIONS (ADD extensions 'foo; bar');

-- OK but gets a warning
--Testcase 22:
ALTER SERVER :DB_SERVERNAME OPTIONS (ADD extensions 'foo, bar');
--Testcase 23:
ALTER SERVER :DB_SERVERNAME OPTIONS (DROP extensions);

--Testcase 24:
ALTER USER MAPPING FOR public SERVER :DB_SERVERNAME
	OPTIONS (DROP user, DROP password);

-- Attempt to add a valid option that's not allowed in a user mapping
--Testcase 25:
ALTER USER MAPPING FOR public SERVER :DB_SERVERNAME
	OPTIONS (ADD sslmode 'require');

-- But we can add valid ones fine
--Testcase 26:
ALTER USER MAPPING FOR public SERVER :DB_SERVERNAME
	OPTIONS (ADD sslpassword 'dummy');

-- Ensure valid options we haven't used in a user mapping yet are
-- permitted to check validation.
--Testcase 27:
ALTER USER MAPPING FOR public SERVER :DB_SERVERNAME
	OPTIONS (ADD sslkey 'value', ADD sslcert 'value');

--Testcase 28:
ALTER FOREIGN TABLE ft1 OPTIONS (table_name 'T1');
--Testcase 29:
ALTER FOREIGN TABLE ft2 OPTIONS (table_name 'T1');
--Testcase 30:
ALTER FOREIGN TABLE ft1 ALTER COLUMN c1 OPTIONS (column_name 'C_1');
--Testcase 31:
ALTER FOREIGN TABLE ft2 ALTER COLUMN c1 OPTIONS (column_name 'C_1');
--Testcase 32:
\det+
-- Test that alteration of server options causes reconnection
-- Remote's errors might be non-English, so hide them to ensure stable results
\set VERBOSITY terse
--Testcase 33:
SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should work
-- jdbc_fdw not have dbname option, use url option instead
--Testcase 34:
ALTER SERVER :DB_SERVERNAME OPTIONS (SET url 'no such database');
--Testcase 35:
SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should work because of cache connection
--Testcase 36:
ALTER SERVER :DB_SERVERNAME OPTIONS (SET url :DB_URL);
--Testcase 37:
SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should work again

-- Test that alteration of user mapping options causes reconnection
-- ALTER USER MAPPING FOR CURRENT_USER SERVER :DB_SERVERNAME
--   OPTIONS (ADD user 'no such user');
-- SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should fail
-- ALTER USER MAPPING FOR CURRENT_USER SERVER :DB_SERVERNAME
--   OPTIONS (DROP user);
-- SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should work again
\set VERBOSITY default

-- Now we should be able to run ANALYZE.
-- To exercise multiple code paths, we use local stats on ft1
-- and remote-estimate mode on ft2.
-- ALTER FOREIGN TABLE ft2 OPTIONS (use_remote_estimate 'true'); --BUG: 

-- ===================================================================
-- test error case for create publication on foreign table
-- ===================================================================
--Testcase 865:
CREATE PUBLICATION testpub_ftbl FOR TABLE ft1;  -- should fail

-- ===================================================================
-- simple queries
-- ===================================================================
-- single table without alias
--Testcase 38:
EXPLAIN (COSTS OFF) SELECT * FROM ft1 ORDER BY c3, c1 OFFSET 100 LIMIT 10;
--Testcase 39:
SELECT * FROM ft1 ORDER BY c3, c1 OFFSET 100 LIMIT 10;
-- single table with alias - also test that tableoid sort is not pushed to remote side
--Testcase 40:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 ORDER BY t1.c3, t1.c1, t1.tableoid OFFSET 100 LIMIT 10;
--Testcase 41:
SELECT * FROM ft1 t1 ORDER BY t1.c3, t1.c1, t1.tableoid OFFSET 100 LIMIT 10;
-- whole-row reference
--Testcase 42:
EXPLAIN (VERBOSE, COSTS OFF) SELECT t1 FROM ft1 t1 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 43:
SELECT t1 FROM ft1 t1 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- empty result
--Testcase 44:
SELECT * FROM ft1 WHERE false;
-- with WHERE clause
--Testcase 45:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE t1.c1 = 101 AND t1.c6 = '1' AND t1.c7 >= '1';
--Testcase 46:
SELECT * FROM ft1 t1 WHERE t1.c1 = 101 AND t1.c6 = '1' AND t1.c7 >= '1';
-- with FOR UPDATE/SHARE
--Testcase 47:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = 101 FOR UPDATE;
--Testcase 48:
SELECT * FROM ft1 t1 WHERE c1 = 101 FOR UPDATE;
--Testcase 49:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = 102 FOR SHARE;
--Testcase 50:
SELECT * FROM ft1 t1 WHERE c1 = 102 FOR SHARE;
-- aggregate
--Testcase 51:
SELECT COUNT(*) FROM ft1 t1;
-- subquery
--Testcase 52:
SELECT * FROM ft1 t1 WHERE t1.c3 IN (SELECT c3 FROM ft2 t2 WHERE c1 <= 10) ORDER BY c1;
-- subquery+MAX
--Testcase 53:
SELECT * FROM ft1 t1 WHERE t1.c3 = (SELECT MAX(c3) FROM ft2 t2) ORDER BY c1;
-- used in CTE
--Testcase 54:
WITH t1 AS (SELECT * FROM ft1 WHERE c1 <= 10) SELECT t2.c1, t2.c2, t2.c3, t2.c4 FROM t1, ft2 t2 WHERE t1.c1 = t2.c1 ORDER BY t1.c1;
-- fixed values
--Testcase 55:
SELECT 'fixed', NULL FROM ft1 t1 WHERE c1 = 1;
-- Test forcing the remote server to produce sorted data for a merge join.
--Testcase 56:
SET enable_hashjoin TO false;
--Testcase 57:
SET enable_nestloop TO false;
-- inner join; expressions in the clauses appear in the equivalence class list
--Testcase 58:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1.c1, t2."C_1" FROM ft2 t1 JOIN "S 1"."T1" t2 ON (t1.c1 = t2."C_1") OFFSET 100 LIMIT 10;
--Testcase 59:
SELECT t1.c1, t2."C_1" FROM ft2 t1 JOIN "S 1"."T1" t2 ON (t1.c1 = t2."C_1") OFFSET 100 LIMIT 10;
-- outer join; expressions in the clauses do not appear in equivalence class
-- list but no output change as compared to the previous query
--Testcase 60:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1.c1, t2."C_1" FROM ft2 t1 LEFT JOIN "S 1"."T1" t2 ON (t1.c1 = t2."C_1") OFFSET 100 LIMIT 10;
--Testcase 61:
SELECT t1.c1, t2."C_1" FROM ft2 t1 LEFT JOIN "S 1"."T1" t2 ON (t1.c1 = t2."C_1") OFFSET 100 LIMIT 10;
-- A join between local table and foreign join. ORDER BY clause is added to the
-- foreign join so that the local table can be joined using merge join strategy.
--Testcase 62:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C_1" FROM "S 1"."T1" t1 left join ft1 t2 join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C_1") OFFSET 100 LIMIT 10;
--Testcase 63:
SELECT t1."C_1" FROM "S 1"."T1" t1 left join ft1 t2 join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C_1") OFFSET 100 LIMIT 10;
-- Test similar to above, except that the full join prevents any equivalence
-- classes from being merged. This produces single relation equivalence classes
-- included in join restrictions.
--Testcase 64:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C_1", t2.c1, t3.c1 FROM "S 1"."T1" t1 left join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C_1") OFFSET 100 LIMIT 10;
--Testcase 65:
SELECT t1."C_1", t2.c1, t3.c1 FROM "S 1"."T1" t1 left join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C_1") OFFSET 100 LIMIT 10;
-- Test similar to above with all full outer joins
--Testcase 66:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C_1", t2.c1, t3.c1 FROM "S 1"."T1" t1 full join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C_1") OFFSET 100 LIMIT 10;
--Testcase 67:
SELECT t1."C_1", t2.c1, t3.c1 FROM "S 1"."T1" t1 full join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C_1") OFFSET 100 LIMIT 10;
--Testcase 68:
RESET enable_hashjoin;
--Testcase 69:
RESET enable_nestloop;

-- Test executing assertion in estimate_path_cost_size() that makes sure that
-- retrieved_rows for foreign rel re-used to cost pre-sorted foreign paths is
-- a sensible value even when the rel has tuples=0
--Testcase 838:
CREATE FOREIGN TABLE ft_empty (c1 int OPTIONS (key 'true') NOT NULL, c2 text)
  SERVER :DB_SERVERNAME OPTIONS (table_name 'loct_empty');
--Testcase 839:
INSERT INTO ft_empty
  SELECT id, 'AAA' || to_char(id, 'FM000') FROM generate_series(1, 100) id;
--Testcase 840:
DELETE FROM ft_empty;
-- ANALYZE ft_empty;
--Testcase 841:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft_empty ORDER BY c1;

-- ===================================================================
-- WHERE with remotely-executable conditions
-- ===================================================================
--Testcase 70:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE t1.c1 = 1;         -- Var, OpExpr(b), Const
--Testcase 71:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE t1.c1 = 100 AND t1.c2 = 0; -- BoolExpr
--Testcase 72:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 IS NULL;        -- NullTest
--Testcase 73:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 IS NOT NULL;    -- NullTest
--Testcase 74:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE round(abs(c1), 0) = 1; -- FuncExpr
--Testcase 75:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = -c1;          -- OpExpr(l)
--Testcase 77:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE (c1 IS NOT NULL) IS DISTINCT FROM (c1 IS NOT NULL); -- DistinctExpr
--Testcase 78:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = ANY(ARRAY[c2, 1, c1 + 0]); -- ScalarArrayOpExpr
--Testcase 79:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = (ARRAY[c1,c2,3])[1]; -- SubscriptingRef
--Testcase 80:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c6 = E'foo''s\\bar';  -- check special chars
--Testcase 81:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c8 = 'foo';  -- can't be sent to remote
-- parameterized remote path for foreign table
--Testcase 82:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM "S 1"."T1" a, ft2 b WHERE a."C_1" = 47 AND b.c1 = a.c2;
--Testcase 83:
SELECT * FROM ft2 a, ft2 b WHERE a.c1 = 47 AND b.c1 = a.c2;

-- check both safe and unsafe join conditions
--Testcase 84:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft2 a, ft2 b
  WHERE a.c2 = 6 AND b.c1 = a.c1 AND a.c8 = 'foo' AND b.c7 = upper(a.c7);
--Testcase 85:
SELECT * FROM ft2 a, ft2 b
WHERE a.c2 = 6 AND b.c1 = a.c1 AND a.c8 = 'foo' AND b.c7 = upper(a.c7);
-- bug before 9.3.5 due to sloppy handling of remote-estimate parameters
--Testcase 86:
SELECT * FROM ft1 WHERE c1 = ANY (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 87:
SELECT * FROM ft2 WHERE c1 = ANY (ARRAY(SELECT c1 FROM ft1 WHERE c1 < 5));
-- we should not push order by clause with volatile expressions or unsafe
-- collations
--Testcase 88:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT * FROM ft2 ORDER BY ft2.c1, random();
--Testcase 89:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT * FROM ft2 ORDER BY ft2.c1, ft2.c3 collate "C";

-- user-defined operator/function
--Testcase 90:
CREATE FUNCTION postgres_fdw_abs(int) RETURNS int AS $$
BEGIN
RETURN abs($1);
END
$$ LANGUAGE plpgsql IMMUTABLE;
--Testcase 91:
CREATE OPERATOR === (
    LEFTARG = int,
    RIGHTARG = int,
    PROCEDURE = int4eq,
    COMMUTATOR = ===
);

-- built-in operators and functions can be shipped for remote execution
--Testcase 92:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = abs(t1.c2);
--Testcase 93:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = abs(t1.c2);
--Testcase 94:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = t1.c2;
--Testcase 95:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = t1.c2;

-- by default, user-defined ones cannot
--Testcase 96:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = postgres_fdw_abs(t1.c2);
--Testcase 97:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = postgres_fdw_abs(t1.c2);
--Testcase 98:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;
--Testcase 99:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;

-- ORDER BY can be shipped, though
--Testcase 100:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;
--Testcase 101:
SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;

-- but let's put them in an extension ...
--Testcase 102:
ALTER EXTENSION :DB_EXTENSIONNAME ADD FUNCTION postgres_fdw_abs(int);
--Testcase 103:
ALTER EXTENSION :DB_EXTENSIONNAME ADD OPERATOR === (int, int);
--Testcase 104:
-- Option 'extensions' is not supported
-- ALTER SERVER :DB_SERVERNAME OPTIONS (ADD extensions :DB_EXTENSIONNAME);

-- ... now they can be shipped
--Testcase 105:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = postgres_fdw_abs(t1.c2);
--Testcase 106:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = postgres_fdw_abs(t1.c2);
--Testcase 107:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;
--Testcase 108:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;

-- and both ORDER BY and LIMIT can be shipped
--Testcase 109:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;
--Testcase 110:
SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;

-- Test CASE pushdown
-- JDBC does not support push down CASE WHEN
--Testcase 877:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT c1,c2,c3 FROM ft2 WHERE CASE WHEN c1 > 990 THEN c1 END < 1000 ORDER BY c1;
--Testcase 878:
SELECT c1,c2,c3 FROM ft2 WHERE CASE WHEN c1 > 990 THEN c1 END < 1000 ORDER BY c1;

-- Nested CASE
--Testcase 879:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT c1,c2,c3 FROM ft2 WHERE CASE CASE WHEN c2 > 0 THEN c2 END WHEN 100 THEN 601 WHEN c2 THEN c2 ELSE 0 END > 600 ORDER BY c1;

--Testcase 880:
SELECT c1,c2,c3 FROM ft2 WHERE CASE CASE WHEN c2 > 0 THEN c2 END WHEN 100 THEN 601 WHEN c2 THEN c2 ELSE 0 END > 600 ORDER BY c1;

-- CASE arg WHEN
--Testcase 881:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 WHERE c1 > (CASE mod(c1, 4) WHEN 0 THEN 1 WHEN 2 THEN 50 ELSE 100 END);

-- CASE cannot be pushed down because of unshippable arg clause
--Testcase 882:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 WHERE c1 > (CASE random()::integer WHEN 0 THEN 1 WHEN 2 THEN 50 ELSE 100 END);

-- these are shippable
--Testcase 883:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 WHERE CASE c6 WHEN 'foo' THEN true ELSE c3 < 'bar' END;
--Testcase 884:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 WHERE CASE c3 WHEN c6 THEN true ELSE c3 < 'bar' END;

-- but this is not because of collation
--Testcase 885:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 WHERE CASE c3 COLLATE "C" WHEN c6 THEN true ELSE c3 < 'bar' END;

-- check schema-qualification of regconfig constant
--Testcase 886:
CREATE TEXT SEARCH CONFIGURATION public.custom_search
  (COPY = pg_catalog.english);
--Testcase 887:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT c1, to_tsvector('custom_search'::regconfig, c3) FROM ft1
WHERE c1 = 642 AND length(to_tsvector('custom_search'::regconfig, c3)) > 0;
-- JDBC_FDW always push down built-in function of PostgreSQL to remote server.
-- to_tsvector is not exist in MySQL and GridDB.
-- text search configuration "public.custom_search" does not exist in Postgres
-- So this test case will get error.
--Testcase 888:
SELECT c1, to_tsvector('custom_search'::regconfig, c3) FROM ft1
WHERE c1 = 642 AND length(to_tsvector('custom_search'::regconfig, c3)) > 0;
--Testcase 889:
DROP TEXT SEARCH CONFIGURATION public.custom_search;

-- ===================================================================
-- JOIN queries
-- ===================================================================
-- Analyze ft4 and ft5 so that we have better statistics. These tables do not
-- have use_remote_estimate set.
-- ANALYZE ft4;
-- ANALYZE ft5;

-- join two tables
--Testcase 111:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 112:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- join three tables
--Testcase 113:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) JOIN ft4 t3 ON (t3.c1 = t1.c1) ORDER BY t1.c3, t1.c1 OFFSET 10 LIMIT 10;
--Testcase 114:
SELECT t1.c1, t2.c2, t3.c3 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) JOIN ft4 t3 ON (t3.c1 = t1.c1) ORDER BY t1.c3, t1.c1 OFFSET 10 LIMIT 10;
-- left outer join
--Testcase 115:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 116:
SELECT t1.c1, t2.c1 FROM ft4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
-- left outer join three tables
--Testcase 117:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 118:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- left outer join + placement of clauses.
-- clauses within the nullable side are not pulled up, but top level clause on
-- non-nullable side is pushed into non-nullable side
--Testcase 119:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1) WHERE t1.c1 < 10;
--Testcase 120:
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1) WHERE t1.c1 < 10;
-- clauses within the nullable side are not pulled up, but the top level clause
-- on nullable side is not pushed down into nullable side
--Testcase 121:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1)
			WHERE (t2.c1 < 10 OR t2.c1 IS NULL) AND t1.c1 < 10;
--Testcase 122:
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1)
			WHERE (t2.c1 < 10 OR t2.c1 IS NULL) AND t1.c1 < 10;
-- right outer join
--Testcase 123:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft5 t1 RIGHT JOIN ft4 t2 ON (t1.c1 = t2.c1) ORDER BY t2.c1, t1.c1 OFFSET 10 LIMIT 10;
--Testcase 124:
SELECT t1.c1, t2.c1 FROM ft5 t1 RIGHT JOIN ft4 t2 ON (t1.c1 = t2.c1) ORDER BY t2.c1, t1.c1 OFFSET 10 LIMIT 10;
-- right outer join three tables
--Testcase 125:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 126:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join
--Testcase 127:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 45 LIMIT 10;
--Testcase 128:
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 45 LIMIT 10;
-- full outer join with restrictions on the joining relations
-- a. the joining relations are both base relations
--Testcase 129:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1;
--Testcase 130:
SELECT t1.c1, t2.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1;
--Testcase 131:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT 1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (TRUE) OFFSET 10 LIMIT 10;
--Testcase 132:
SELECT 1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (TRUE) OFFSET 10 LIMIT 10;
-- b. one of the joining relations is a base relation and the other is a join
-- relation
--Testcase 133:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM ft4 t2 LEFT JOIN ft5 t3 ON (t2.c1 = t3.c1) WHERE (t2.c1 between 50 and 60)) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
--Testcase 134:
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM ft4 t2 LEFT JOIN ft5 t3 ON (t2.c1 = t3.c1) WHERE (t2.c1 between 50 and 60)) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
-- c. test deparsing the remote query as nested subqueries
--Testcase 135:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
--Testcase 136:
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
-- d. test deparsing rowmarked relations as subqueries
--Testcase 137:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM "S 1"."T3" WHERE c1 = 50) t1 INNER JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (TRUE) ORDER BY t1.c1, ss.a, ss.b FOR UPDATE OF t1;
--Testcase 138:
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM "S 1"."T3" WHERE c1 = 50) t1 INNER JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (TRUE) ORDER BY t1.c1, ss.a, ss.b FOR UPDATE OF t1;
-- full outer join + inner join
--Testcase 139:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1, t3.c1 FROM ft4 t1 INNER JOIN ft5 t2 ON (t1.c1 = t2.c1 + 1 and t1.c1 between 50 and 60) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1, t2.c1, t3.c1 LIMIT 10;
--Testcase 140:
SELECT t1.c1, t2.c1, t3.c1 FROM ft4 t1 INNER JOIN ft5 t2 ON (t1.c1 = t2.c1 + 1 and t1.c1 between 50 and 60) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1, t2.c1, t3.c1 LIMIT 10;
-- full outer join three tables
--Testcase 141:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 142:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join + right outer join
--Testcase 143:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 144:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- right outer join + full outer join
--Testcase 145:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 146:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join + left outer join
--Testcase 147:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 148:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- left outer join + full outer join
--Testcase 149:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 150:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 842:
SET enable_memoize TO off;
-- right outer join + left outer join
--Testcase 151:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 152:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 843:
RESET enable_memoize;
-- left outer join + right outer join
--Testcase 153:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 154:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join + WHERE clause, only matched rows
--Testcase 155:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) WHERE (t1.c1 = t2.c1 OR t1.c1 IS NULL) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 156:
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) WHERE (t1.c1 = t2.c1 OR t1.c1 IS NULL) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
-- full outer join + WHERE clause with shippable extensions set
--Testcase 157:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t1.c3 FROM ft1 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE postgres_fdw_abs(t1.c1) > 0 OFFSET 10 LIMIT 10;
--Testcase 158:
-- Option 'extensions' is not supported
-- ALTER SERVER :DB_SERVERNAME OPTIONS (DROP extensions);
-- full outer join + WHERE clause with shippable extensions not set
--Testcase 159:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t1.c3 FROM ft1 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE postgres_fdw_abs(t1.c1) > 0 OFFSET 10 LIMIT 10;
--Testcase 160:
-- ALTER SERVER :DB_SERVERNAME OPTIONS (ADD extensions :DB_EXTENSIONNAME);
-- join two tables with FOR UPDATE clause
-- tests whole-row reference for row marks
--Testcase 161:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE OF t1;
--Testcase 162:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE OF t1;
--Testcase 163:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE;
--Testcase 164:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE;
-- join two tables with FOR SHARE clause
--Testcase 165:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE OF t1;
--Testcase 166:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE OF t1;
--Testcase 167:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE;
--Testcase 168:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE;
-- join in CTE
--Testcase 169:
EXPLAIN (VERBOSE, COSTS OFF)
WITH t (c1_1, c1_3, c2_1) AS MATERIALIZED (SELECT t1.c1, t1.c3, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) SELECT c1_1, c2_1 FROM t ORDER BY c1_3, c1_1 OFFSET 100 LIMIT 10;
--Testcase 170:
WITH t (c1_1, c1_3, c2_1) AS MATERIALIZED (SELECT t1.c1, t1.c3, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) SELECT c1_1, c2_1 FROM t ORDER BY c1_3, c1_1 OFFSET 100 LIMIT 10;
-- ctid with whole-row reference
--Testcase 171:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.ctid, t1, t2, t1.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- SEMI JOIN, not pushed down
--Testcase 172:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1 FROM ft1 t1 WHERE EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c1) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
--Testcase 173:
SELECT t1.c1 FROM ft1 t1 WHERE EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c1) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
-- ANTI JOIN, not pushed down
--Testcase 174:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1 FROM ft1 t1 WHERE NOT EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c2) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
--Testcase 175:
SELECT t1.c1 FROM ft1 t1 WHERE NOT EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c2) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
-- CROSS JOIN can be pushed down
--Testcase 176:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 CROSS JOIN ft2 t2 ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
--Testcase 177:
SELECT t1.c1, t2.c1 FROM ft1 t1 CROSS JOIN ft2 t2 ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
-- different server, not pushed down. No result expected.
--Testcase 178:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft5 t1 JOIN ft6 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
--Testcase 179:
SELECT t1.c1, t2.c1 FROM ft5 t1 JOIN ft6 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
-- unsafe join conditions (c8 has a UDT), not pushed down. Practically a CROSS
-- JOIN since c8 in both tables has same value.
--Testcase 180:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c8 = t2.c8) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
--Testcase 181:
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c8 = t2.c8) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
-- unsafe conditions on one side (c8 has a UDT), not pushed down.
--Testcase 182:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = 'foo' ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 183:
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = 'foo' ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- join where unsafe to pushdown condition in WHERE clause has a column not
-- in the SELECT clause. In this test unsafe clause needs to have column
-- references from both joining sides so that the clause is not pushed down
-- into one of the joining sides.
--Testcase 184:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = t2.c8 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 185:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = t2.c8 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- Aggregate after UNION, for testing setrefs
--Testcase 186:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1c1, avg(t1c1 + t2c1) FROM (SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) UNION SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) AS t (t1c1, t2c1) GROUP BY t1c1 ORDER BY t1c1 OFFSET 100 LIMIT 10;
--Testcase 187:
SELECT t1c1, avg(t1c1 + t2c1) FROM (SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) UNION SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) AS t (t1c1, t2c1) GROUP BY t1c1 ORDER BY t1c1 OFFSET 100 LIMIT 10;
-- join with lateral reference
--Testcase 188:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1."C_1" FROM "S 1"."T1" t1, LATERAL (SELECT DISTINCT t2.c1, t3.c1 FROM ft1 t2, ft2 t3 WHERE t2.c1 = t3.c1 AND t2.c2 = t1.c2) q ORDER BY t1."C_1" OFFSET 10 LIMIT 10;
--Testcase 189:
SELECT t1."C_1" FROM "S 1"."T1" t1, LATERAL (SELECT DISTINCT t2.c1, t3.c1 FROM ft1 t2, ft2 t3 WHERE t2.c1 = t3.c1 AND t2.c2 = t1.c2) q ORDER BY t1."C_1" OFFSET 10 LIMIT 10;

-- non-Var items in targetlist of the nullable rel of a join preventing
-- push-down in some cases
-- unable to push {ft1, ft2}
--Testcase 190:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT q.a, ft2.c1 FROM (SELECT 13 FROM ft1 WHERE c1 = 13) q(a) RIGHT JOIN ft2 ON (q.a = ft2.c1) WHERE ft2.c1 BETWEEN 10 AND 15;
--Testcase 191:
SELECT q.a, ft2.c1 FROM (SELECT 13 FROM ft1 WHERE c1 = 13) q(a) RIGHT JOIN ft2 ON (q.a = ft2.c1) WHERE ft2.c1 BETWEEN 10 AND 15;

-- ok to push {ft1, ft2} but not {ft1, ft2, ft4}
--Testcase 192:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ft4.c1, q.* FROM ft4 LEFT JOIN (SELECT 13, ft1.c1, ft2.c1 FROM ft1 RIGHT JOIN ft2 ON (ft1.c1 = ft2.c1) WHERE ft1.c1 = 12) q(a, b, c) ON (ft4.c1 = q.b) WHERE ft4.c1 BETWEEN 10 AND 15;
--Testcase 193:
SELECT ft4.c1, q.* FROM ft4 LEFT JOIN (SELECT 13, ft1.c1, ft2.c1 FROM ft1 RIGHT JOIN ft2 ON (ft1.c1 = ft2.c1) WHERE ft1.c1 = 12) q(a, b, c) ON (ft4.c1 = q.b) WHERE ft4.c1 BETWEEN 10 AND 15 ORDER BY ft4.c1;

-- join with nullable side with some columns with null values
--Testcase 194:
UPDATE ft5 SET c3 = null where c1 % 9 = 0;
--Testcase 195:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ft5, ft5.c1, ft5.c2, ft5.c3, ft4.c1, ft4.c2 FROM ft5 left join ft4 on ft5.c1 = ft4.c1 WHERE ft4.c1 BETWEEN 10 and 30 ORDER BY ft5.c1, ft4.c1;
--Testcase 196:
SELECT ft5, ft5.c1, ft5.c2, ft5.c3, ft4.c1, ft4.c2 FROM ft5 left join ft4 on ft5.c1 = ft4.c1 WHERE ft4.c1 BETWEEN 10 and 30 ORDER BY ft5.c1, ft4.c1;

-- multi-way join involving multiple merge joins
-- (this case used to have EPQ-related planning problems)
--Testcase 197:
CREATE TABLE local_tbl (c1 int NOT NULL, c2 int NOT NULL, c3 text, CONSTRAINT local_tbl_pkey PRIMARY KEY (c1));
--Testcase 198:
INSERT INTO local_tbl SELECT id, id % 10, to_char(id, 'FM0000') FROM generate_series(1, 1000) id;
ANALYZE local_tbl;
--Testcase 199:
SET enable_nestloop TO false;
--Testcase 200:
SET enable_hashjoin TO false;
--Testcase 201:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1, ft2, ft4, ft5, local_tbl WHERE ft1.c1 = ft2.c1 AND ft1.c2 = ft4.c1
    AND ft1.c2 = ft5.c1 AND ft1.c2 = local_tbl.c1 AND ft1.c1 < 100 AND ft2.c1 < 100 FOR UPDATE;
--Testcase 202:
SELECT * FROM ft1, ft2, ft4, ft5, local_tbl WHERE ft1.c1 = ft2.c1 AND ft1.c2 = ft4.c1
    AND ft1.c2 = ft5.c1 AND ft1.c2 = local_tbl.c1 AND ft1.c1 < 100 AND ft2.c1 < 100 FOR UPDATE;
--Testcase 203:
RESET enable_nestloop;
--Testcase 204:
RESET enable_hashjoin;

-- test that add_paths_with_pathkeys_for_rel() arranges for the epq_path to
-- return columns needed by the parent ForeignScan node
-- EXPLAIN (VERBOSE, COSTS OFF)
-- SELECT * FROM local_tbl LEFT JOIN (SELECT ft1.*, COALESCE(ft1.c3 || ft2.c3, 'foobar') FROM ft1 INNER JOIN ft2 ON (ft1.c1 = ft2.c1 AND ft1.c1 < 100)) ss ON (local_tbl.c1 = ss.c1) ORDER BY local_tbl.c1 FOR UPDATE OF local_tbl;

-- ALTER SERVER loopback OPTIONS (DROP extensions);
-- ALTER SERVER loopback OPTIONS (ADD fdw_startup_cost '10000.0');
-- EXPLAIN (VERBOSE, COSTS OFF)
-- SELECT * FROM local_tbl LEFT JOIN (SELECT ft1.* FROM ft1 INNER JOIN ft2 ON (ft1.c1 = ft2.c1 AND ft1.c1 < 100 AND ft1.c1 = jdbc_fdw_abs(ft2.c2))) ss ON (local_tbl.c3 = ss.c3) ORDER BY local_tbl.c1 FOR UPDATE OF local_tbl;
-- ALTER SERVER loopback OPTIONS (DROP fdw_startup_cost);
-- ALTER SERVER loopback OPTIONS (ADD extensions 'jdbc_fdw');
--Testcase 205:
DROP TABLE local_tbl;

-- check join pushdown in situations where multiple userids are involved
--Testcase 206:
CREATE ROLE regress_view_owner SUPERUSER;
--Testcase 207:
CREATE USER MAPPING FOR regress_view_owner SERVER :DB_SERVERNAME;
GRANT SELECT ON ft4 TO regress_view_owner;
GRANT SELECT ON ft5 TO regress_view_owner;

--Testcase 208:
CREATE VIEW v4 AS SELECT * FROM ft4;
--Testcase 209:
CREATE VIEW v5 AS SELECT * FROM ft5;
--Testcase 210:
ALTER VIEW v5 OWNER TO regress_view_owner;
--Testcase 211:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can't be pushed down, different view owners
--Testcase 212:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 213:
ALTER VIEW v4 OWNER TO regress_view_owner;
--Testcase 214:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can be pushed down
--Testcase 215:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;

--Testcase 216:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can't be pushed down, view owner not current user
--Testcase 217:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 218:
ALTER VIEW v4 OWNER TO CURRENT_USER;
--Testcase 219:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can be pushed down
--Testcase 220:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 221:
ALTER VIEW v4 OWNER TO regress_view_owner;

-- cleanup
--Testcase 222:
DROP OWNED BY regress_view_owner;
--Testcase 223:
DROP ROLE regress_view_owner;


-- ===================================================================
-- Aggregate and grouping queries
-- ===================================================================

-- Simple aggregates
--Testcase 224:
explain (verbose, costs off)
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2;
--Testcase 225:
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2;

--Testcase 226:
explain (verbose, costs off)
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2 limit 1;
--Testcase 227:
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2 limit 1;

-- Aggregate is not pushed down as aggregation contains random()
--Testcase 228:
explain (verbose, costs off)
select sum(c1 * (random() <= 1)::int) as sum, avg(c1) from ft1;

-- Aggregate over join query
--Testcase 229:
explain (verbose, costs off)
select count(*), sum(t1.c1), avg(t2.c1) from ft1 t1 inner join ft1 t2 on (t1.c2 = t2.c2) where t1.c2 = 6;
--Testcase 230:
select count(*), sum(t1.c1), avg(t2.c1) from ft1 t1 inner join ft1 t2 on (t1.c2 = t2.c2) where t1.c2 = 6;

-- Not pushed down due to local conditions present in underneath input rel
--Testcase 231:
explain (verbose, costs off)
select sum(t1.c1), count(t2.c1) from ft1 t1 inner join ft2 t2 on (t1.c1 = t2.c1) where ((t1.c1 * t2.c1)/(t1.c1 * t2.c1)) * random() <= 1;

-- GROUP BY clause having expressions
--Testcase 232:
explain (verbose, costs off)
select c2/2, sum(c2) * (c2/2) from ft1 group by c2/2 order by c2/2;
--Testcase 233:
select c2/2, sum(c2) * (c2/2) from ft1 group by c2/2 order by c2/2;

-- Aggregates in subquery are pushed down.
--Testcase 234:
explain (verbose, costs off)
select count(x.a), sum(x.a) from (select c2 a, sum(c1) b from ft1 group by c2, sqrt(c1) order by 1, 2) x;
--Testcase 235:
select count(x.a), sum(x.a) from (select c2 a, sum(c1) b from ft1 group by c2, sqrt(c1) order by 1, 2) x;

-- Aggregate is still pushed down by taking unshippable expression out
--Testcase 236:
explain (verbose, costs off)
select c2 * (random() <= 1)::int as sum1, sum(c1) * c2 as sum2 from ft1 group by c2 order by 1, 2;
--Testcase 237:
select c2 * (random() <= 1)::int as sum1, sum(c1) * c2 as sum2 from ft1 group by c2 order by 1, 2;

-- Aggregate with unshippable GROUP BY clause are not pushed
--Testcase 238:
explain (verbose, costs off)
select c2 * (random() <= 1)::int as c2 from ft2 group by c2 * (random() <= 1)::int order by 1;

-- GROUP BY clause in various forms, cardinal, alias and constant expression
--Testcase 239:
explain (verbose, costs off)
select count(c2) w, c2 x, 5 y, 7.0 z from ft1 group by 2, y, 9.0::int order by 2;
--Testcase 240:
select count(c2) w, c2 x, 5 y, 7.0 z from ft1 group by 2, y, 9.0::int order by 2;

-- GROUP BY clause referring to same column multiple times
-- Also, ORDER BY contains an aggregate function
--Testcase 241:
explain (verbose, costs off)
select c2, c2 from ft1 where c2 > 6 group by 1, 2 order by sum(c1);
--Testcase 242:
select c2, c2 from ft1 where c2 > 6 group by 1, 2 order by sum(c1);

-- Testing HAVING clause shippability
--Testcase 243:
explain (verbose, costs off)
select c2, sum(c1) from ft2 group by c2 having avg(c1) < 500 and sum(c1) < 49800 order by c2;
--Testcase 244:
select c2, sum(c1) from ft2 group by c2 having avg(c1) < 500 and sum(c1) < 49800 order by c2;

-- Unshippable HAVING clause will be evaluated locally, and other qual in HAVING clause is pushed down
--Testcase 245:
explain (verbose, costs off)
select count(*) from (select c5, count(c1) from ft1 group by c5, sqrt(c2) having (avg(c1) / avg(c1)) * random() <= 1 and avg(c1) < 500) x;
--Testcase 246:
select count(*) from (select c5, count(c1) from ft1 group by c5, sqrt(c2) having (avg(c1) / avg(c1)) * random() <= 1 and avg(c1) < 500) x;

-- Aggregate in HAVING clause is not pushable, and thus aggregation is not pushed down
--Testcase 247:
explain (verbose, costs off)
select sum(c1) from ft1 group by c2 having avg(c1 * (random() <= 1)::int) > 100 order by 1;

-- Remote aggregate in combination with a local Param (for the output
-- of an initplan) can be trouble, per bug #15781
--Testcase 248:
explain (verbose, costs off)
select exists(select 1 from pg_enum), sum(c1) from ft1;
--Testcase 249:
select exists(select 1 from pg_enum), sum(c1) from ft1;

--Testcase 250:
explain (verbose, costs off)
select exists(select 1 from pg_enum), sum(c1) from ft1 group by 1;
--Testcase 251:
select exists(select 1 from pg_enum), sum(c1) from ft1 group by 1;


-- Testing ORDER BY, DISTINCT, FILTER, Ordered-sets and VARIADIC within aggregates

-- ORDER BY within aggregate, same column used to order
--Testcase 252:
explain (verbose, costs off)
select array_agg(c1 order by c1) from ft1 where c1 < 100 group by c2 order by 1;
--Testcase 253:
select array_agg(c1 order by c1) from ft1 where c1 < 100 group by c2 order by 1;

-- ORDER BY within aggregate, different column used to order also using DESC
--Testcase 254:
explain (verbose, costs off)
select array_agg(c5 order by c1 desc) from ft2 where c2 = 6 and c1 < 50;
--Testcase 255:
select array_agg(c5 order by c1 desc) from ft2 where c2 = 6 and c1 < 50;

-- DISTINCT within aggregate
--Testcase 256:
explain (verbose, costs off)
select array_agg(distinct (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;
--Testcase 257:
select array_agg(distinct (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;

-- DISTINCT combined with ORDER BY within aggregate
--Testcase 258:
explain (verbose, costs off)
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;
--Testcase 259:
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;

--Testcase 260:
explain (verbose, costs off)
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5 desc nulls last) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;
--Testcase 261:
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5 desc nulls last) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;

-- FILTER within aggregate
--Testcase 262:
explain (verbose, costs off)
select sum(c1) filter (where c1 < 100 and c2 > 5) from ft1 group by c2 order by 1 nulls last;
--Testcase 263:
select sum(c1) filter (where c1 < 100 and c2 > 5) from ft1 group by c2 order by 1 nulls last;

-- DISTINCT, ORDER BY and FILTER within aggregate
--Testcase 264:
explain (verbose, costs off)
select sum(c1%3), sum(distinct c1%3 order by c1%3) filter (where c1%3 < 2), c2 from ft1 where c2 = 6 group by c2;
--Testcase 265:
select sum(c1%3), sum(distinct c1%3 order by c1%3) filter (where c1%3 < 2), c2 from ft1 where c2 = 6 group by c2;

-- Outer query is aggregation query
--Testcase 266:
explain (verbose, costs off)
select distinct (select count(*) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;
--Testcase 267:
select distinct (select count(*) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;
-- Inner query is aggregation query
--Testcase 268:
explain (verbose, costs off)
select distinct (select count(t1.c1) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;
--Testcase 269:
select distinct (select count(t1.c1) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;

-- Aggregate not pushed down as FILTER condition is not pushable
--Testcase 270:
explain (verbose, costs off)
select sum(c1) filter (where (c1 / c1) * random() <= 1) from ft1 group by c2 order by 1;
--Testcase 271:
explain (verbose, costs off)
select sum(c2) filter (where c2 in (select c2 from ft1 where c2 < 5)) from ft1;

-- Ordered-sets within aggregate
--Testcase 272:
explain (verbose, costs off)
select c2, rank('10'::varchar) within group (order by c6), percentile_cont(c2/10::numeric) within group (order by c1) from ft1 where c2 < 10 group by c2 having percentile_cont(c2/10::numeric) within group (order by c1) < 500 order by c2;
--Testcase 273:
select c2, rank('10'::varchar) within group (order by c6), percentile_cont(c2/10::numeric) within group (order by c1) from ft1 where c2 < 10 group by c2 having percentile_cont(c2/10::numeric) within group (order by c1) < 500 order by c2;

-- Using multiple arguments within aggregates
--Testcase 274:
explain (verbose, costs off)
select c1, rank(c1, c2) within group (order by c1, c2) from ft1 group by c1, c2 having c1 = 6 order by 1;
--Testcase 275:
select c1, rank(c1, c2) within group (order by c1, c2) from ft1 group by c1, c2 having c1 = 6 order by 1;

-- User defined function for user defined aggregate, VARIADIC
--Testcase 276:
create function least_accum(anyelement, variadic anyarray)
returns anyelement language sql as
  'select least($1, min($2[i])) from generate_subscripts($2,1) g(i)';
--Testcase 277:
create aggregate least_agg(variadic items anyarray) (
  stype = anyelement, sfunc = least_accum
);

-- Disable hash aggregation for plan stability.
--Testcase 278:
set enable_hashagg to false;

-- Not pushed down due to user defined aggregate
--Testcase 279:
explain (verbose, costs off)
select c2, least_agg(c1) from ft1 group by c2 order by c2;

-- Add function and aggregate into extension
--Testcase 280:
alter extension :DB_EXTENSIONNAME add function least_accum(anyelement, variadic anyarray);
--Testcase 281:
alter extension :DB_EXTENSIONNAME add aggregate least_agg(variadic items anyarray);
--Testcase 282:
-- alter server :DB_SERVERNAME options (set extensions :DB_EXTENSIONNAME);

-- Now aggregate will be pushed.  Aggregate will display VARIADIC argument.
--Testcase 283:
explain (verbose, costs off)
select c2, least_agg(c1) from ft1 where c2 < 100 group by c2 order by c2;
--Testcase 284:
select c2, least_agg(c1) from ft1 where c2 < 100 group by c2 order by c2;

-- Remove function and aggregate from extension
--Testcase 285:
alter extension :DB_EXTENSIONNAME drop function least_accum(anyelement, variadic anyarray);
--Testcase 286:
alter extension :DB_EXTENSIONNAME drop aggregate least_agg(variadic items anyarray);
--Testcase 287:
-- alter server :DB_SERVERNAME options (set extensions :DB_EXTENSIONNAME);

-- Not pushed down as we have dropped objects from extension.
--Testcase 288:
explain (verbose, costs off)
select c2, least_agg(c1) from ft1 group by c2 order by c2;

-- Cleanup
--Testcase 289:
reset enable_hashagg;
--Testcase 290:
drop aggregate least_agg(variadic items anyarray);
--Testcase 291:
drop function least_accum(anyelement, variadic anyarray);


-- Testing USING OPERATOR() in ORDER BY within aggregate.
-- For this, we need user defined operators along with operator family and
-- operator class.  Create those and then add them in extension.  Note that
-- user defined objects are considered unshippable unless they are part of
-- the extension.
--Testcase 292:
create operator public.<^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4eq
);

--Testcase 293:
create operator public.=^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4lt
);

--Testcase 294:
create operator public.>^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4gt
);

--Testcase 295:
create operator family my_op_family using btree;

--Testcase 296:
create function my_op_cmp(a int, b int) returns int as
  $$begin return btint4cmp(a, b); end $$ language plpgsql;

--Testcase 297:
create operator class my_op_class for type int using btree family my_op_family as
 operator 1 public.<^,
 operator 3 public.=^,
 operator 5 public.>^,
 function 1 my_op_cmp(int, int);

-- This will not be pushed as user defined sort operator is not part of the
-- extension yet.
--Testcase 298:
explain (verbose, costs off)
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;

-- This should not be pushed either.
--Testcase 866:
explain (verbose, costs off)
select * from ft2 order by c1 using operator(public.<^);

-- Update local stats on ft2
ANALYZE ft2;

-- Add into extension
--Testcase 299:
alter extension :DB_EXTENSIONNAME add operator class my_op_class using btree;
--Testcase 300:
alter extension :DB_EXTENSIONNAME add function my_op_cmp(a int, b int);
--Testcase 301:
alter extension :DB_EXTENSIONNAME add operator family my_op_family using btree;
--Testcase 302:
alter extension :DB_EXTENSIONNAME add operator public.<^(int, int);
--Testcase 303:
alter extension :DB_EXTENSIONNAME add operator public.=^(int, int);
--Testcase 304:
alter extension :DB_EXTENSIONNAME add operator public.>^(int, int);
--Testcase 305:
-- alter server :DB_SERVERNAME options (set extensions :DB_EXTENSIONNAME);

-- Now this will be pushed as sort operator is part of the extension.
--Testcase 306:
explain (verbose, costs off)
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;
--Testcase 307:
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;

-- This should be pushed too.
-- JDBC does not support push down user defined function
--Testcase 867:
explain (verbose, costs off)
select * from ft2 order by c1 using operator(public.<^);

-- Remove from extension
--Testcase 308:
alter extension :DB_EXTENSIONNAME drop operator class my_op_class using btree;
--Testcase 309:
alter extension :DB_EXTENSIONNAME drop function my_op_cmp(a int, b int);
--Testcase 310:
alter extension :DB_EXTENSIONNAME drop operator family my_op_family using btree;
--Testcase 311:
alter extension :DB_EXTENSIONNAME drop operator public.<^(int, int);
--Testcase 312:
alter extension :DB_EXTENSIONNAME drop operator public.=^(int, int);
--Testcase 313:
alter extension :DB_EXTENSIONNAME drop operator public.>^(int, int);
--Testcase 314:
-- alter server :DB_SERVERNAME options (set extensions :DB_EXTENSIONNAME);

-- This will not be pushed as sort operator is now removed from the extension.
--Testcase 315:
explain (verbose, costs off)
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;

-- Cleanup
--Testcase 316:
drop operator class my_op_class using btree;
--Testcase 317:
drop function my_op_cmp(a int, b int);
--Testcase 318:
drop operator family my_op_family using btree;
--Testcase 319:
drop operator public.>^(int, int);
--Testcase 320:
drop operator public.=^(int, int);
--Testcase 321:
drop operator public.<^(int, int);

-- Input relation to aggregate push down hook is not safe to pushdown and thus
-- the aggregate cannot be pushed down to foreign server.
--Testcase 322:
explain (verbose, costs off)
select count(t1.c3) from ft2 t1 left join ft2 t2 on (t1.c1 = random() * t2.c2);

-- Subquery in FROM clause having aggregate
--Testcase 323:
explain (verbose, costs off)
select count(*), x.b from ft1, (select c2 a, sum(c1) b from ft1 group by c2) x where ft1.c2 = x.a group by x.b order by 1, 2;
--Testcase 324:
select count(*), x.b from ft1, (select c2 a, sum(c1) b from ft1 group by c2) x where ft1.c2 = x.a group by x.b order by 1, 2;

-- FULL join with IS NULL check in HAVING
--Testcase 325:
explain (verbose, costs off)
select avg(t1.c1), sum(t2.c1) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) group by t2.c1 having (avg(t1.c1) is null and sum(t2.c1) < 10) or sum(t2.c1) is null order by 1 nulls last, 2;
--Testcase 326:
select avg(t1.c1), sum(t2.c1) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) group by t2.c1 having (avg(t1.c1) is null and sum(t2.c1) < 10) or sum(t2.c1) is null order by 1 nulls last, 2;

-- Aggregate over FULL join needing to deparse the joining relations as
-- subqueries.
--Testcase 327:
explain (verbose, costs off)
select count(*), sum(t1.c1), avg(t2.c1) from (select c1 from ft4 where c1 between 50 and 60) t1 full join (select c1 from ft5 where c1 between 50 and 60) t2 on (t1.c1 = t2.c1);
--Testcase 328:
select count(*), sum(t1.c1), avg(t2.c1) from (select c1 from ft4 where c1 between 50 and 60) t1 full join (select c1 from ft5 where c1 between 50 and 60) t2 on (t1.c1 = t2.c1);

-- ORDER BY expression is part of the target list but not pushed down to
-- foreign server.
--Testcase 329:
explain (verbose, costs off)
select sum(c2) * (random() <= 1)::int as sum from ft1 order by 1;
--Testcase 330:
select sum(c2) * (random() <= 1)::int as sum from ft1 order by 1;

-- LATERAL join, with parameterization
--Testcase 331:
set enable_hashagg to false;
--Testcase 332:
explain (verbose, costs off)
select c2, sum from "S 1"."T1" t1, lateral (select sum(t2.c1 + t1."C_1") sum from ft2 t2 group by t2.c1) qry where t1.c2 * 2 = qry.sum and t1.c2 < 3 and t1."C_1" < 100 order by 1;
--Testcase 333:
select c2, sum from "S 1"."T1" t1, lateral (select sum(t2.c1 + t1."C_1") sum from ft2 t2 group by t2.c1) qry where t1.c2 * 2 = qry.sum and t1.c2 < 3 and t1."C_1" < 100 order by 1;
--Testcase 334:
reset enable_hashagg;

-- bug #15613: bad plan for foreign table scan with lateral reference
--Testcase 335:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ref_0.c2, subq_1.*
FROM
    "S 1"."T1" AS ref_0,
    LATERAL (
        SELECT ref_0."C_1" c1, subq_0.*
        FROM (SELECT ref_0.c2, ref_1.c3
              FROM ft1 AS ref_1) AS subq_0
             RIGHT JOIN ft2 AS ref_3 ON (subq_0.c3 = ref_3.c3)
    ) AS subq_1
WHERE ref_0."C_1" < 10 AND subq_1.c3 = '00001'
ORDER BY ref_0."C_1";

--Testcase 336:
SELECT ref_0.c2, subq_1.*
FROM
    "S 1"."T1" AS ref_0,
    LATERAL (
        SELECT ref_0."C_1" c1, subq_0.*
        FROM (SELECT ref_0.c2, ref_1.c3
              FROM ft1 AS ref_1) AS subq_0
             RIGHT JOIN ft2 AS ref_3 ON (subq_0.c3 = ref_3.c3)
    ) AS subq_1
WHERE ref_0."C_1" < 10 AND subq_1.c3 = '00001'
ORDER BY ref_0."C_1";

-- Check with placeHolderVars
--Testcase 337:
explain (verbose, costs off)
select sum(q.a), count(q.b) from ft4 left join (select 13, avg(ft1.c1), sum(ft2.c1) from ft1 right join ft2 on (ft1.c1 = ft2.c1)) q(a, b, c) on (ft4.c1 <= q.b);
--Testcase 338:
select sum(q.a), count(q.b) from ft4 left join (select 13, avg(ft1.c1), sum(ft2.c1) from ft1 right join ft2 on (ft1.c1 = ft2.c1)) q(a, b, c) on (ft4.c1 <= q.b);


-- Not supported cases
-- Grouping sets
--Testcase 339:
explain (verbose, costs off)
select c2, sum(c1) from ft1 where c2 < 3 group by rollup(c2) order by 1 nulls last;
--Testcase 340:
select c2, sum(c1) from ft1 where c2 < 3 group by rollup(c2) order by 1 nulls last;
--Testcase 341:
explain (verbose, costs off)
select c2, sum(c1) from ft1 where c2 < 3 group by cube(c2) order by 1 nulls last;
--Testcase 342:
select c2, sum(c1) from ft1 where c2 < 3 group by cube(c2) order by 1 nulls last;
--Testcase 343:
explain (verbose, costs off)
select c2, c6, sum(c1) from ft1 where c2 < 3 group by grouping sets(c2, c6) order by 1 nulls last, 2 nulls last;
--Testcase 344:
select c2, c6, sum(c1) from ft1 where c2 < 3 group by grouping sets(c2, c6) order by 1 nulls last, 2 nulls last;
--Testcase 345:
explain (verbose, costs off)
select c2, sum(c1), grouping(c2) from ft1 where c2 < 3 group by c2 order by 1 nulls last;
--Testcase 346:
select c2, sum(c1), grouping(c2) from ft1 where c2 < 3 group by c2 order by 1 nulls last;

-- DISTINCT itself is not pushed down, whereas underneath aggregate is pushed
--Testcase 347:
explain (verbose, costs off)
select distinct sum(c1)/1000 s from ft2 where c2 < 6 group by c2 order by 1;
--Testcase 348:
select distinct sum(c1)/1000 s from ft2 where c2 < 6 group by c2 order by 1;

-- WindowAgg
--Testcase 349:
explain (verbose, costs off)
select c2, sum(c2), count(c2) over (partition by c2%2) from ft2 where c2 < 10 group by c2 order by 1;
--Testcase 350:
select c2, sum(c2), count(c2) over (partition by c2%2) from ft2 where c2 < 10 group by c2 order by 1;
--Testcase 351:
explain (verbose, costs off)
select c2, array_agg(c2) over (partition by c2%2 order by c2 desc) from ft1 where c2 < 10 group by c2 order by 1;
--Testcase 352:
select c2, array_agg(c2) over (partition by c2%2 order by c2 desc) from ft1 where c2 < 10 group by c2 order by 1;
--Testcase 353:
explain (verbose, costs off)
select c2, array_agg(c2) over (partition by c2%2 order by c2 range between current row and unbounded following) from ft1 where c2 < 10 group by c2 order by 1;
--Testcase 354:
select c2, array_agg(c2) over (partition by c2%2 order by c2 range between current row and unbounded following) from ft1 where c2 < 10 group by c2 order by 1;


-- ===================================================================
-- parameterized queries
-- ===================================================================
-- simple join
--Testcase 355:
PREPARE st1(int, int) AS SELECT t1.c3, t2.c3 FROM ft1 t1, ft2 t2 WHERE t1.c1 = $1 AND t2.c1 = $2;
--Testcase 356:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st1(1, 2);
--Testcase 357:
EXECUTE st1(1, 1);
--Testcase 358:
EXECUTE st1(101, 101);
-- subquery using stable function (can't be sent to remote)
--Testcase 359:
PREPARE st2(int) AS SELECT * FROM ft1 t1 WHERE t1.c1 < $2 AND t1.c3 IN (SELECT c3 FROM ft2 t2 WHERE c1 > $1 AND date(c4) = '1970-01-17'::date) ORDER BY c1;
--Testcase 360:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st2(10, 20);
--Testcase 361:
EXECUTE st2(10, 20);
--Testcase 362:
EXECUTE st2(101, 121);
-- subquery using immutable function (can be sent to remote)
--Testcase 363:
PREPARE st3(int) AS SELECT * FROM ft1 t1 WHERE t1.c1 < $2 AND t1.c3 IN (SELECT c3 FROM ft2 t2 WHERE c1 > $1 AND date(c5) = '1970-01-17'::date) ORDER BY c1;
--Testcase 364:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st3(10, 20);
--Testcase 365:
EXECUTE st3(10, 20);
--Testcase 366:
EXECUTE st3(20, 30);
-- custom plan should be chosen initially
--Testcase 367:
PREPARE st4(int) AS SELECT * FROM ft1 t1 WHERE t1.c1 = $1;
--Testcase 368:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 369:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 370:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 371:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 372:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
-- once we try it enough times, should switch to generic plan
--Testcase 373:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
-- value of $1 should not be sent to remote
--Testcase 374:
PREPARE st5(user_enum,int) AS SELECT * FROM ft1 t1 WHERE c8 = $1 and c1 = $2;
--Testcase 375:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 376:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 377:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 378:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 379:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 380:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 381:
EXECUTE st5('foo', 1);

-- altering FDW options requires replanning
--Testcase 382:
PREPARE st6 AS SELECT * FROM ft1 t1 WHERE t1.c1 = t1.c2;
--Testcase 383:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st6;
--Testcase 384:
PREPARE st7 AS INSERT INTO ft1 (c1,c2,c3) VALUES (1001,101,'foo');
--Testcase 385:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st7;
-- ALTER TABLE "S 1"."T1" RENAME TO "T 0";
-- ALTER FOREIGN TABLE ft1 OPTIONS (SET table_name 'T 0');
--Testcase 386:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st6;
--Testcase 387:
EXECUTE st6;
--Testcase 388:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st7;
-- ALTER TABLE "S 1"."T 0" RENAME TO "T1";
-- ALTER FOREIGN TABLE ft1 OPTIONS (SET table_name 'T 1');

--Testcase 389:
PREPARE st8 AS SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;
--Testcase 390:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st8;
--Testcase 391:
-- ALTER SERVER :DB_SERVERNAME OPTIONS (DROP extensions);
--Testcase 392:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st8;
--Testcase 393:
EXECUTE st8;
--Testcase 394:
-- ALTER SERVER :DB_SERVERNAME OPTIONS (ADD extensions :DB_EXTENSIONNAME);

-- cleanup
DEALLOCATE st1;
DEALLOCATE st2;
DEALLOCATE st3;
DEALLOCATE st4;
DEALLOCATE st5;
DEALLOCATE st6;
DEALLOCATE st7;
DEALLOCATE st8;

-- System columns, except ctid and oid, should not be sent to remote
--Testcase 395:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 t1 WHERE t1.tableoid = 'pg_class'::regclass LIMIT 1;
--Testcase 396:
SELECT * FROM ft1 t1 WHERE t1.tableoid = 'ft1'::regclass LIMIT 1;
--Testcase 397:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT tableoid::regclass, * FROM ft1 t1 LIMIT 1;
--Testcase 398:
SELECT tableoid::regclass, * FROM ft1 t1 LIMIT 1;
--Testcase 399:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 t1 WHERE t1.ctid = '(0,2)';
--Testcase 400:
-- Does not support system column ctid return invalid value
--Testcase 844:
SELECT * FROM ft1 t1 WHERE t1.ctid = '(0,2)';
--Testcase 401:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ctid, * FROM ft1 t1 LIMIT 1;
--Testcase 402:
SELECT ctid, * FROM ft1 t1 LIMIT 1;

-- ===================================================================
-- used in PL/pgSQL function
-- ===================================================================
--Testcase 826:
CREATE OR REPLACE FUNCTION f_test(p_c1 int) RETURNS int AS $$
DECLARE
	v_c1 int;
BEGIN
--Testcase 834:
    SELECT c1 INTO v_c1 FROM ft1 WHERE c1 = p_c1 LIMIT 1;
    PERFORM c1 FROM ft1 WHERE c1 = p_c1 AND p_c1 = v_c1 LIMIT 1;
    RETURN v_c1;
END;
$$ LANGUAGE plpgsql;
--Testcase 827:
SELECT f_test(100);
--Testcase 828:
DROP FUNCTION f_test(int);

-- ===================================================================
-- REINDEX
-- ===================================================================
-- remote table is not created here
--Testcase 845:
CREATE FOREIGN TABLE reindex_foreign (c1 int, c2 int)
  SERVER :DB_SERVERNAME OPTIONS (table_name 'reindex_local');
REINDEX TABLE reindex_foreign; -- error
REINDEX TABLE CONCURRENTLY reindex_foreign; -- error
--Testcase 846:
DROP FOREIGN TABLE reindex_foreign;
-- partitions and foreign tables
--Testcase 847:
CREATE TABLE reind_fdw_parent (c1 int) PARTITION BY RANGE (c1);
--Testcase 848:
CREATE TABLE reind_fdw_0_10 PARTITION OF reind_fdw_parent
  FOR VALUES FROM (0) TO (10);
--Testcase 849:
CREATE FOREIGN TABLE reind_fdw_10_20 PARTITION OF reind_fdw_parent
  FOR VALUES FROM (10) TO (20)
  SERVER :DB_SERVERNAME OPTIONS (table_name 'reind_local_10_20');
REINDEX TABLE reind_fdw_parent; -- ok
REINDEX TABLE CONCURRENTLY reind_fdw_parent; -- ok
--Testcase 850:
DROP TABLE reind_fdw_parent;

-- ===================================================================
-- conversion error
-- ===================================================================
--Testcase 403:
ALTER FOREIGN TABLE ft1 ALTER COLUMN c8 TYPE int;
--Testcase 404:
SELECT * FROM ft1 ftx(x1,x2,x3,x4,x5,x6,x7,x8) WHERE x1 = 1;  -- ERROR
--Testcase 405:
SELECT  ftx.x1,  ft2.c2, ftx.x8 FROM ft1 ftx(x1,x2,x3,x4,x5,x6,x7,x8), ft2 WHERE ftx.x1 = ft2.c1 AND ftx.x1 = 1; -- ERROR
--Testcase 406:
SELECT  ftx.x1,  ft2.c2, ftx FROM ft1 ftx(x1,x2,x3,x4,x5,x6,x7,x8), ft2 WHERE ftx.x1 = ft2.c1 AND ftx.x1 = 1; -- ERROR
--Testcase 407:
SELECT sum(c2), array_agg(c8) FROM ft1 GROUP BY c8; -- ERROR
ANALYZE ft1; -- ERROR
--Testcase 868:
ALTER FOREIGN TABLE ft1 ALTER COLUMN c8 TYPE user_enum;

-- ===================================================================
-- local type can be different from remote type in some cases,
-- in particular if similarly-named operators do equivalent things
-- ===================================================================
--Testcase 869:
ALTER FOREIGN TABLE ft1 ALTER COLUMN c8 TYPE text;
--Testcase 870:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 WHERE c8 = 'foo' LIMIT 1;
--Testcase 871:
SELECT * FROM ft1 WHERE c8 = 'foo' LIMIT 1;
--Testcase 872:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 WHERE 'foo' = c8 LIMIT 1;
--Testcase 873:
SELECT * FROM ft1 WHERE 'foo' = c8 LIMIT 1;
-- we declared c8 to be text locally, but it's still the same type on
-- the remote which will balk if we try to do anything incompatible
-- with that remote type
-- Postgres, MySQL, GridDB returns result because type of column c8 in both remote and local are the same
--Testcase 874:
SELECT * FROM ft1 WHERE c8 LIKE 'foo' LIMIT 1; -- ERROR
--Testcase 875:
SELECT * FROM ft1 WHERE c8::text LIKE 'foo' LIMIT 1; -- ERROR; cast not pushed down
--Testcase 408:
ALTER FOREIGN TABLE ft1 ALTER COLUMN c8 TYPE user_enum;

-- does not support savepoint
-- ===================================================================
-- subtransaction
--  + local/remote error doesn't break cursor
-- ===================================================================
-- BEGIN;
-- DECLARE c CURSOR FOR SELECT * FROM ft1 ORDER BY c1;
-- FETCH c;
-- SAVEPOINT s;
-- ERROR OUT;          -- ERROR
-- ROLLBACK TO s;
-- FETCH c;
-- SAVEPOINT s;
-- SELECT * FROM ft1 WHERE 1 / (c1 - 1) > 0;  -- ERROR
-- ROLLBACK TO s;
-- FETCH c;
-- SELECT * FROM ft1 ORDER BY c1 LIMIT 1;
-- COMMIT;

-- ===================================================================
-- test handling of collations
-- ===================================================================
--Testcase 409:
create table loct3 (f1 text collate "C" unique, f2 text, f3 varchar(10) unique);
--Testcase 410:
create foreign table ft3 (f1 text collate "C", f2 text, f3 varchar(10))
  server :DB_SERVERNAME options (table_name 'loct3', use_remote_estimate 'false');

-- can be sent to remote
--Testcase 411:
explain (verbose, costs off) select * from ft3 where f1 = 'foo';
--Testcase 412:
explain (verbose, costs off) select * from ft3 where f1 COLLATE "C" = 'foo';
--Testcase 413:
explain (verbose, costs off) select * from ft3 where f2 = 'foo';
--Testcase 414:
explain (verbose, costs off) select * from ft3 where f3 = 'foo';
--Testcase 415:
explain (verbose, costs off) select * from ft3 f, loct3 l
  where f.f3 = l.f3 and l.f1 = 'foo';
-- can't be sent to remote
--Testcase 416:
explain (verbose, costs off) select * from ft3 where f1 COLLATE "POSIX" = 'foo';
--Testcase 417:
explain (verbose, costs off) select * from ft3 where f1 = 'foo' COLLATE "C";
--Testcase 418:
explain (verbose, costs off) select * from ft3 where f2 COLLATE "C" = 'foo';
--Testcase 419:
explain (verbose, costs off) select * from ft3 where f2 = 'foo' COLLATE "C";
--Testcase 420:
explain (verbose, costs off) select * from ft3 f, loct3 l
  where f.f3 = l.f3 COLLATE "POSIX" and l.f1 = 'foo';

-- ===================================================================
-- test writable foreign table stuff
-- ===================================================================
--Testcase 421:
EXPLAIN (verbose, costs off)
INSERT INTO ft2 (c1,c2,c3) SELECT c1+1000,c2+100, c3 || c3 FROM ft2 LIMIT 20;
--Testcase 422:
INSERT INTO ft2 (c1,c2,c3) SELECT c1+1000,c2+100, c3 || c3 FROM ft2 LIMIT 20;
--Testcase 423:
INSERT INTO ft2 (c1,c2,c3)
  VALUES (1101,201,'aaa'), (1102,202,'bbb'), (1103,203,'ccc');
--Testcase 424:
SELECT * FROM ft2 WHERE c1 >= 1101 and c1 <= 1103;
--Testcase 425:
INSERT INTO ft2 (c1,c2,c3) VALUES (1104,204,'ddd'), (1105,205,'eee');
--Testcase 426:
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c2 = c2 + 300, c3 = c3 || '_update3' WHERE c1 % 10 = 3;              -- can be pushed down
--Testcase 427:
UPDATE ft2 SET c2 = c2 + 300, c3 = c3 || '_update3' WHERE c1 % 10 = 3;
--Testcase 428:
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c2 = c2 + 400, c3 = c3 || '_update7' WHERE c1 % 10 = 7;  -- can be pushed down
--Testcase 429:
UPDATE ft2 SET c2 = c2 + 400, c3 = c3 || '_update7' WHERE c1 % 10 = 7;
--Testcase 430:
SELECT * FROM ft2 WHERE c1 % 10 = 7;
--Testcase 431:
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c2 = ft2.c2 + 500, c3 = ft2.c3 || '_update9', c7 = DEFAULT
  FROM ft1 WHERE ft1.c1 = ft2.c2 AND ft1.c1 % 10 = 9;                               -- can be pushed down
--Testcase 432:
UPDATE ft2 SET c2 = ft2.c2 + 500, c3 = ft2.c3 || '_update9', c7 = DEFAULT
  FROM ft1 WHERE ft1.c1 = ft2.c2 AND ft1.c1 % 10 = 9;
--Testcase 433:
EXPLAIN (verbose, costs off)
  DELETE FROM ft2 WHERE c1 % 10 = 5;                               -- can be pushed down
--Testcase 434:
SELECT c1, c4 FROM ft2 WHERE c1 % 10 = 5;
--Testcase 435:
DELETE FROM ft2 WHERE c1 % 10 = 5;
--Testcase 436:
EXPLAIN (verbose, costs off)
DELETE FROM ft2 USING ft1 WHERE ft1.c1 = ft2.c2 AND ft1.c1 % 10 = 2;                -- can be pushed down
--Testcase 437:
DELETE FROM ft2 USING ft1 WHERE ft1.c1 = ft2.c2 AND ft1.c1 % 10 = 2;
--Testcase 438:
SELECT c1,c2,c3,c4 FROM ft2 ORDER BY c1;
--Testcase 439:
EXPLAIN (verbose, costs off)
INSERT INTO ft2 (c1,c2,c3) VALUES (1200,999,'foo');
--Testcase 440:
INSERT INTO ft2 (c1,c2,c3) VALUES (1200,999,'foo');
--Testcase 441:
SELECT tableoid::regclass FROM ft2 WHERE c1 = 1200;
--Testcase 442:
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c3 = 'bar' WHERE c1 = 1200;             -- can be pushed down
--Testcase 443:
UPDATE ft2 SET c3 = 'bar' WHERE c1 = 1200;
--Testcase 444:
SELECT tableoid::regclass FROM ft2 WHERE c1 = 1200;
--Testcase 445:
EXPLAIN (verbose, costs off)
DELETE FROM ft2 WHERE c1 = 1200;                       -- can be pushed down
--Testcase 446:
SELECT tableoid::regclass FROM ft2 WHERE c1 = 1200;
--Testcase 447:
DELETE FROM ft2 WHERE c1 = 1200;

-- Test UPDATE/DELETE with RETURNING on a three-table join
--Testcase 448:
INSERT INTO ft2 (c1,c2,c3)
  SELECT id, id - 1200, to_char(id, 'FM00000') FROM generate_series(1201, 1300) id;
--Testcase 449:
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c3 = 'foo'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 1200 AND ft2.c2 = ft4.c1;       -- can be pushed down
--Testcase 450:
UPDATE ft2 SET c3 = 'foo'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 1200 AND ft2.c2 = ft4.c1;
--Testcase 451:
SELECT ft2, ft2.*, ft4, ft4.* FROM ft2, ft4, ft5 WHERE (ft4.c1 = ft5.c1) AND (ft2.c1 > 1200) AND (ft2.c2 = ft4.c1);
--Testcase 452:
EXPLAIN (verbose, costs off)
DELETE FROM ft2
  USING ft4 LEFT JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 1200 AND ft2.c1 % 10 = 0 AND ft2.c2 = ft4.c1;                          -- can be pushed down
--Testcase 453:
DELETE FROM ft2
  USING ft4 LEFT JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 1200 AND ft2.c1 % 10 = 0 AND ft2.c2 = ft4.c1;
--Testcase 454:
DELETE FROM ft2 WHERE ft2.c1 > 1200;

-- Test UPDATE with a MULTIEXPR sub-select
-- (maybe someday this'll be remotely executable, but not today)
--Testcase 455:
EXPLAIN (verbose, costs off)
UPDATE ft2 AS target SET (c2, c7) = (
    SELECT c2 * 10, c7
        FROM ft2 AS src
        WHERE target.c1 = src.c1
) WHERE c1 > 1100;
--Testcase 456:
UPDATE ft2 AS target SET (c2, c7) = (
    SELECT c2 * 10, c7
        FROM ft2 AS src
        WHERE target.c1 = src.c1
) WHERE c1 > 1100;

--Testcase 457:
UPDATE ft2 AS target SET (c2) = (
    SELECT c2 / 10
        FROM ft2 AS src
        WHERE target.c1 = src.c1
) WHERE c1 > 1100;

-- Test UPDATE involving a join that can be pushed down,
-- but a SET clause that can't be
--Testcase 851:
EXPLAIN (VERBOSE, COSTS OFF)
UPDATE ft2 d SET c2 = CASE WHEN random() >= 0 THEN d.c2 ELSE 0 END
  FROM ft2 AS t WHERE d.c1 = t.c1 AND d.c1 > 1000;
--Testcase 852:
UPDATE ft2 d SET c2 = CASE WHEN random() >= 0 THEN d.c2 ELSE 0 END
  FROM ft2 AS t WHERE d.c1 = t.c1 AND d.c1 > 1000;

-- Test UPDATE/DELETE with WHERE or JOIN/ON conditions containing
-- user-defined operators/functions
--Testcase 458:
ALTER SERVER :DB_SERVERNAME OPTIONS (DROP extensions);
--Testcase 459:
INSERT INTO ft2 (c1,c2,c3)
  SELECT id, id % 10, to_char(id, 'FM00000') FROM generate_series(2001, 2010) id;
--Testcase 460:
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c3 = 'bar' WHERE postgres_fdw_abs(c1) > 2000;            -- can't be pushed down
--Testcase 461:
UPDATE ft2 SET c3 = 'bar' WHERE postgres_fdw_abs(c1) > 2000;
--Testcase 462:
SELECT * FROM ft2 WHERE postgres_fdw_abs(c1) > 2000;
--Testcase 463:
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c3 = 'baz'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 2000 AND ft2.c2 === ft4.c1;                                                    -- can't be pushed down
--Testcase 464:
UPDATE ft2 SET c3 = 'baz'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 2000 AND ft2.c2 === ft4.c1;
--Testcase 465:
SELECT ft2.*, ft4.*, ft5.* FROM ft2, ft4, ft5 
  WHERE (ft4.c1 = ft5.c1) AND (ft2.c1 > 2000) AND (ft2.c2 === ft4.c1);
--Testcase 466:
EXPLAIN (verbose, costs off)
DELETE FROM ft2
  USING ft4 INNER JOIN ft5 ON (ft4.c1 === ft5.c1)
  WHERE ft2.c1 > 2000 AND ft2.c2 = ft4.c1;       -- can't be pushed down
--Testcase 467:
DELETE FROM ft2
  USING ft4 INNER JOIN ft5 ON (ft4.c1 === ft5.c1)
  WHERE ft2.c1 > 2000 AND ft2.c2 = ft4.c1;
--Testcase 468:
DELETE FROM ft2 WHERE ft2.c1 > 2000;
--Testcase 469:
-- ALTER SERVER :DB_SERVERNAME OPTIONS (ADD extensions :DB_EXTENSIONNAME);

-- Test that trigger on remote table works as expected
--Testcase 470:
CREATE OR REPLACE FUNCTION F_BRTRIG() RETURNS trigger AS $$
BEGIN
    NEW.c3 = NEW.c3 || '_trig_update';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
--Testcase 471:
CREATE TRIGGER t1_br_insert BEFORE INSERT OR UPDATE
    ON ft1 FOR EACH ROW EXECUTE PROCEDURE F_BRTRIG();
--Testcase 472:
CREATE TRIGGER t2_br_insert BEFORE INSERT OR UPDATE
    ON ft2 FOR EACH ROW EXECUTE PROCEDURE F_BRTRIG();

--Testcase 473:
INSERT INTO ft2 (c1,c2,c3) VALUES (1208, 818, 'fff');
--Testcase 835:
SELECT * FROM ft2 WHERE c1 = 1208;
--Testcase 474:
INSERT INTO ft2 (c1,c2,c3,c6) VALUES (1218, 818, 'ggg', '(--;');
--Testcase 836:
SELECT * FROM ft2 WHERE c1 = 1218;
--Testcase 475:
UPDATE ft2 SET c2 = c2 + 600 WHERE c1 % 10 = 8 AND c1 < 1200;

--Testcase 476:
SELECT * FROM ft2 WHERE c1 % 10 = 8 AND c1 < 1200;
-- Test errors thrown on remote side during update
-- Does not support CHECK
--Testcase 477:
ALTER TABLE ft1 ADD CONSTRAINT c2positive CHECK (c2 >= 0);

--Testcase 478:
INSERT INTO ft1(c1, c2) VALUES(11, 12);  -- duplicate key
--Testcase 479:
-- Does not support ON CONFLICT DO NOTHING
--Testcase 837:
INSERT INTO ft1(c1, c2) VALUES(11, 12) ON CONFLICT DO NOTHING; -- error
--Testcase 480:
INSERT INTO ft1(c1, c2) VALUES(11, 12) ON CONFLICT (c1, c2) DO NOTHING; -- unsupported
--Testcase 481:
INSERT INTO ft1(c1, c2) VALUES(11, 12) ON CONFLICT (c1, c2) DO UPDATE SET c3 = 'ffg'; -- unsupported
-- INSERT INTO ft1(c1, c2) VALUES(1111, -2);  -- c2positive
-- -- UPDATE ft1 SET c2 = -c2 WHERE c1 = 1;  -- c2positive

-- -- Test savepoint/rollback behavior
-- not supprort transaction
-- --Testcase 482:
-- select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- --Testcase 483:
-- select c2, count(*) from "S 1"."T1" where c2 < 500 group by 1 order by 1;
-- -- begin;
-- --Testcase 484:
-- update ft2 set c2 = 42 where c2 = 0;
-- --Testcase 485:
-- select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- -- savepoint s1;
-- --Testcase 486:
-- update ft2 set c2 = 44 where c2 = 4;
-- --Testcase 487:
-- select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- -- release savepoint s1;
-- --Testcase 488:
-- select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- -- savepoint s2;
-- --Testcase 489:
-- update ft2 set c2 = 46 where c2 = 6;
-- --Testcase 490:
-- select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- -- rollback to savepoint s2;
-- --Testcase 491:
-- update ft2 set c2 = 6 where c2 = 46; -- rollback testcase 485
-- select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- -- release savepoint s2;
-- --Testcase 492:
-- select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- -- savepoint s3;
-- -- update ft2 set c2 = -2 where c2 = 42 and c1 = 10; -- fail on remote side
-- -- rollback to savepoint s3;
-- --Testcase 493:
-- select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- -- release savepoint s3;
-- --Testcase 494:
-- select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- -- none of the above is committed yet remotely
-- --Testcase 495:
-- select c2, count(*) from "S 1"."T1" where c2 < 500 group by 1 order by 1;
-- -- commit;
-- --Testcase 496:
-- select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- --Testcase 497:
-- select c2, count(*) from "S 1"."T1" where c2 < 500 group by 1 order by 1;

-- VACUUM ANALYZE "S 1"."T1";

-- Above DMLs add data with c6 as NULL in ft1, so test ORDER BY NULLS LAST and NULLs
-- FIRST behavior here.
-- ORDER BY DESC NULLS LAST options
--Testcase 498:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY c6 DESC NULLS LAST, c1 OFFSET 795 LIMIT 10;
--Testcase 499:
SELECT * FROM ft1 ORDER BY c6 DESC NULLS LAST, c1 OFFSET 795  LIMIT 10;
-- ORDER BY DESC NULLS FIRST options
--Testcase 500:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY c6 DESC NULLS FIRST, c1 OFFSET 15 LIMIT 10;
--Testcase 501:
SELECT * FROM ft1 ORDER BY c6 DESC NULLS FIRST, c1 OFFSET 15 LIMIT 10;
-- ORDER BY ASC NULLS FIRST options
--Testcase 502:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY c6 ASC NULLS FIRST, c1 OFFSET 15 LIMIT 10;
--Testcase 503:
SELECT * FROM ft1 ORDER BY c6 ASC NULLS FIRST, c1 OFFSET 15 LIMIT 10;

-- ===================================================================
-- test check constraints
-- ===================================================================

-- Consistent check constraints provide consistent results
--Testcase 504:
ALTER FOREIGN TABLE ft1 ADD CONSTRAINT ft1_c2positive CHECK (c2 >= 0);
--Testcase 505:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 < 0;
--Testcase 506:
SELECT count(*) FROM ft1 WHERE c2 < 0;
--Testcase 507:
SET constraint_exclusion = 'on';
--Testcase 508:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 < 0;
--Testcase 509:
SELECT count(*) FROM ft1 WHERE c2 < 0;
--Testcase 510:
RESET constraint_exclusion;
-- check constraint is enforced on the remote side, not locally
-- INSERT INTO ft1(c1, c2) VALUES(1111, -2);  -- c2positive
-- UPDATE ft1 SET c2 = -c2 WHERE c1 = 1;  -- c2positive
--Testcase 511:
ALTER FOREIGN TABLE ft1 DROP CONSTRAINT ft1_c2positive;

-- But inconsistent check constraints provide inconsistent results
--Testcase 512:
ALTER FOREIGN TABLE ft1 ADD CONSTRAINT ft1_c2negative CHECK (c2 < 0);
--Testcase 513:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 >= 0;
--Testcase 514:
SELECT count(*) FROM ft1 WHERE c2 >= 0;
--Testcase 515:
SET constraint_exclusion = 'on';
--Testcase 516:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 >= 0;
--Testcase 517:
SELECT count(*) FROM ft1 WHERE c2 >= 0;
--Testcase 518:
RESET constraint_exclusion;
-- local check constraint is not actually enforced
--Testcase 519:
INSERT INTO ft1(c1, c2) VALUES(1111, 2);
--Testcase 520:
UPDATE ft1 SET c2 = c2 + 1 WHERE c1 = 1;
--Testcase 521:
ALTER FOREIGN TABLE ft1 DROP CONSTRAINT ft1_c2negative;

-- ===================================================================
-- test WITH CHECK OPTION constraints
-- ===================================================================
--Testcase 522:
CREATE FUNCTION row_before_insupd_trigfunc() RETURNS trigger AS $$BEGIN NEW.a := NEW.a + 10; RETURN NEW; END$$ LANGUAGE plpgsql;
--Testcase 523:
CREATE FOREIGN TABLE foreign_tbl (id serial OPTIONS(key 'true'), a int, b int)
  SERVER :DB_SERVERNAME OPTIONS (table_name 'base_tbl');
--Testcase 524:
CREATE TRIGGER row_before_insupd_trigger BEFORE INSERT OR UPDATE ON foreign_tbl FOR EACH ROW EXECUTE PROCEDURE row_before_insupd_trigfunc();
--Testcase 525:
CREATE VIEW rw_view AS SELECT * FROM foreign_tbl
  WHERE a < b WITH CHECK OPTION;
--Testcase 526:
\d+ rw_view

--Testcase 527:
EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO rw_view(a, b) VALUES (0, 5);
-- Bug: data is inserted to table even FDW reports failed
--Testcase 528:
INSERT INTO rw_view(a, b) VALUES (0, 5); -- should fail
--Testcase 529:
EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO rw_view(a, b) VALUES (0, 15);
--Testcase 530:
INSERT INTO rw_view(a, b) VALUES (0, 15); -- ok
--Testcase 531:
SELECT a, b FROM foreign_tbl;

--Testcase 532:
EXPLAIN (VERBOSE, COSTS OFF)
UPDATE rw_view SET b = b + 5;
--Testcase 533:
UPDATE rw_view SET b = b + 5; -- should fail
--Testcase 534:
EXPLAIN (VERBOSE, COSTS OFF)
UPDATE rw_view SET b = b + 15;
--Testcase 535:
UPDATE rw_view SET b = b + 15; -- ok
--Testcase 536:
SELECT a, b FROM foreign_tbl;

-- We don't allow batch insert when there are any WCO constraints
-- ALTER SERVER loopback OPTIONS (ADD batch_size '10');
-- EXPLAIN (VERBOSE, COSTS OFF)
-- INSERT INTO rw_view VALUES (0, 15), (0, 5);
-- INSERT INTO rw_view VALUES (0, 15), (0, 5); -- should fail
-- SELECT * FROM foreign_tbl;
-- ALTER SERVER loopback OPTIONS (DROP batch_size);

--Testcase 537:
DROP FOREIGN TABLE foreign_tbl CASCADE;
-- DROP TRIGGER row_before_insupd_trigger ON base_tbl;
-- DROP TABLE base_tbl;

-- Does not support patition table (regarding tuple routing)
-- test WCO for partitions

-- -- CREATE FOREIGN TABLE foreign_tbl (a int OPTIONS (key 'true'), b int)
--   SERVER :DB_SERVERNAME OPTIONS (table_name 'child_tbl');

-- -- CREATE TABLE parent_tbl (a int, b int) PARTITION BY RANGE(a);
-- -- ALTER TABLE parent_tbl ATTACH PARTITION foreign_tbl FOR VALUES FROM (0) TO (100);

-- -- Detach and re-attach once, to stress the concurrent detach case.
-- ALTER TABLE parent_tbl DETACH PARTITION foreign_tbl CONCURRENTLY;
-- ALTER TABLE parent_tbl ATTACH PARTITION foreign_tbl FOR VALUES FROM (0) TO (100);

-- -- CREATE VIEW rw_view AS SELECT * FROM parent_tbl
--   WHERE a < b WITH CHECK OPTION;
-- -- \d+ rw_view

-- -- EXPLAIN (VERBOSE, COSTS OFF)
-- INSERT INTO rw_view VALUES (0, 5);
-- INSERT INTO rw_view VALUES (0, 5); -- should fail
-- -- EXPLAIN (VERBOSE, COSTS OFF)
-- INSERT INTO rw_view VALUES (0, 15);
-- INSERT INTO rw_view VALUES (0, 15); -- ok
-- -- SELECT * FROM foreign_tbl;

-- -- EXPLAIN (VERBOSE, COSTS OFF)
-- UPDATE rw_view SET b = b + 5;
-- -- UPDATE rw_view SET b = b + 5; -- should fail
-- -- EXPLAIN (VERBOSE, COSTS OFF)
-- UPDATE rw_view SET b = b + 15;
-- -- UPDATE rw_view SET b = b + 15; -- ok
-- -- SELECT * FROM foreign_tbl;

-- We don't allow batch insert when there are any WCO constraints
-- ALTER SERVER loopback OPTIONS (ADD batch_size '10');
-- EXPLAIN (VERBOSE, COSTS OFF)
-- INSERT INTO rw_view VALUES (0, 15), (0, 5);
-- INSERT INTO rw_view VALUES (0, 15), (0, 5); -- should fail
-- SELECT * FROM foreign_tbl;
-- ALTER SERVER loopback OPTIONS (DROP batch_size);

-- -- DROP FOREIGN TABLE foreign_tbl CASCADE;
-- -- DROP TRIGGER row_before_insupd_trigger ON child_tbl;
-- -- DROP TABLE parent_tbl CASCADE;

-- DROP FUNCTION row_before_insupd_trigfunc;

-- ===================================================================
-- test serial columns (ie, sequence-based defaults)
-- ===================================================================
--Testcase 538:
create foreign table loc1 (f1 serial OPTIONS(key 'true'), f2 text)
  server :DB_SERVERNAME options(table_name 'loc1');
--Testcase 539:
create foreign table rem1 (f1 serial OPTIONS(key 'true'), f2 text)
  server :DB_SERVERNAME options(table_name 'loc1');
--Testcase 540:
select pg_catalog.setval('rem1_f1_seq', 10, false);
--Testcase 541:
insert into loc1(f2) values('hi');
--Testcase 542:
insert into rem1(f2) values('hi remote');
--Testcase 543:
insert into loc1(f2) values('bye');
--Testcase 544:
insert into rem1(f2) values('bye remote');
--Testcase 545:
select f1, f2 from loc1;
--Testcase 546:
select f1, f2 from rem1;

-- ===================================================================
-- test generated columns
-- ===================================================================
--Testcase 547:
create foreign table grem1 (
  id serial OPTIONS(key 'true'),
  a int,
  b int generated always as (a * 2) stored)
  server :DB_SERVERNAME options(table_name 'gloc1');
--Testcase 548:
explain (verbose, costs off)
insert into grem1 (a) values (1), (2);
--Testcase 853:
insert into grem1 (a) values (1), (2);
--Testcase 549:
explain (verbose, costs off)
update grem1 set a = 22 where a = 2;
--Testcase 854:
update grem1 set a = 22 where a = 2;
--Testcase 550:
select a, b from grem1;


-- -- test copy from (BeginForeignInsert is not supported)
-- copy grem1 from stdin;
-- 1
-- 2
-- \.
-- select * from gloc1;
-- select * from grem1;
-- delete from grem1;

-- -- test batch insert
-- alter server loopback options (add batch_size '10');
-- explain (verbose, costs off)
-- insert into grem1 (a) values (1), (2);
-- insert into grem1 (a) values (1), (2);
-- select * from gloc1;
-- select * from grem1;
-- delete from grem1;
-- alter server loopback options (drop batch_size);

-- ===================================================================
-- test local triggers
-- ===================================================================

-- Trigger functions "borrowed" from triggers regress test.
--Testcase 551:
CREATE FUNCTION trigger_func() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
	RAISE NOTICE 'trigger_func(%) called: action = %, when = %, level = %',
		TG_ARGV[0], TG_OP, TG_WHEN, TG_LEVEL;
	RETURN NULL;
END;$$;

--Testcase 552:
CREATE TRIGGER trig_stmt_before BEFORE DELETE OR INSERT OR UPDATE ON rem1
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--Testcase 553:
CREATE TRIGGER trig_stmt_after AFTER DELETE OR INSERT OR UPDATE ON rem1
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();

--Testcase 554:
CREATE OR REPLACE FUNCTION trigger_data()  RETURNS trigger
LANGUAGE plpgsql AS $$

declare
	oldnew text[];
	relid text;
    argstr text;
begin

	relid := TG_relid::regclass;
	argstr := '';
	for i in 0 .. TG_nargs - 1 loop
		if i > 0 then
			argstr := argstr || ', ';
		end if;
		argstr := argstr || TG_argv[i];
	end loop;

    RAISE NOTICE '%(%) % % % ON %',
		tg_name, argstr, TG_when, TG_level, TG_OP, relid;
    oldnew := '{}'::text[];
	if TG_OP != 'INSERT' then
		oldnew := array_append(oldnew, format('OLD: %s', OLD));
	end if;

	if TG_OP != 'DELETE' then
		oldnew := array_append(oldnew, format('NEW: %s', NEW));
	end if;

    RAISE NOTICE '%', array_to_string(oldnew, ',');

	if TG_OP = 'DELETE' then
		return OLD;
	else
		return NEW;
	end if;
end;
$$;

-- Test basic functionality
--Testcase 555:
CREATE TRIGGER trig_row_before
BEFORE INSERT OR UPDATE OR DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 556:
CREATE TRIGGER trig_row_after
AFTER INSERT OR UPDATE OR DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 557:
delete from rem1;
--Testcase 558:
insert into rem1 values(1,'insert');
--Testcase 559:
update rem1 set f2  = 'update' where f1 = 1;
--Testcase 560:
update rem1 set f2 = f2 || f2;


-- cleanup
--Testcase 561:
DROP TRIGGER trig_row_before ON rem1;
--Testcase 562:
DROP TRIGGER trig_row_after ON rem1;
--Testcase 563:
DROP TRIGGER trig_stmt_before ON rem1;
--Testcase 564:
DROP TRIGGER trig_stmt_after ON rem1;

--Testcase 565:
DELETE from rem1;

-- Test multiple AFTER ROW triggers on a foreign table
--Testcase 566:
CREATE TRIGGER trig_row_after1
AFTER INSERT OR UPDATE OR DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 567:
CREATE TRIGGER trig_row_after2
AFTER INSERT OR UPDATE OR DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 568:
insert into rem1 values(1,'insert');
--Testcase 569:
update rem1 set f2  = 'update' where f1 = 1;
--Testcase 570:
update rem1 set f2 = f2 || f2;
--Testcase 571:
delete from rem1;

-- cleanup
--Testcase 572:
DROP TRIGGER trig_row_after1 ON rem1;
--Testcase 573:
DROP TRIGGER trig_row_after2 ON rem1;

-- Test WHEN conditions

--Testcase 574:
CREATE TRIGGER trig_row_before_insupd
BEFORE INSERT OR UPDATE ON rem1
FOR EACH ROW
WHEN (NEW.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 575:
CREATE TRIGGER trig_row_after_insupd
AFTER INSERT OR UPDATE ON rem1
FOR EACH ROW
WHEN (NEW.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

-- Insert or update not matching: nothing happens
--Testcase 576:
INSERT INTO rem1 values(1, 'insert');
--Testcase 577:
UPDATE rem1 set f2 = 'test';

-- Insert or update matching: triggers are fired
--Testcase 578:
INSERT INTO rem1 values(2, 'update');
--Testcase 579:
UPDATE rem1 set f2 = 'update update' where f1 = '2';

--Testcase 580:
CREATE TRIGGER trig_row_before_delete
BEFORE DELETE ON rem1
FOR EACH ROW
WHEN (OLD.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 581:
CREATE TRIGGER trig_row_after_delete
AFTER DELETE ON rem1
FOR EACH ROW
WHEN (OLD.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

-- Trigger is fired for f1=2, not for f1=1
--Testcase 582:
DELETE FROM rem1;

-- cleanup
--Testcase 583:
DROP TRIGGER trig_row_before_insupd ON rem1;
--Testcase 584:
DROP TRIGGER trig_row_after_insupd ON rem1;
--Testcase 585:
DROP TRIGGER trig_row_before_delete ON rem1;
--Testcase 586:
DROP TRIGGER trig_row_after_delete ON rem1;


-- Test various RETURN statements in BEFORE triggers.

--Testcase 587:
CREATE FUNCTION trig_row_before_insupdate() RETURNS TRIGGER AS $$
  BEGIN
    NEW.f2 := NEW.f2 || ' triggered !';
    RETURN NEW;
  END
$$ language plpgsql;

--Testcase 588:
CREATE TRIGGER trig_row_before_insupd
BEFORE INSERT OR UPDATE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

-- The new values should have 'triggered' appended
--Testcase 589:
INSERT INTO rem1 values(1, 'insert');
--Testcase 590:
SELECT * from loc1;
--Testcase 591:
INSERT INTO rem1 values(2, 'insert');
--Testcase 592:
SELECT * from loc1;
--Testcase 593:
UPDATE rem1 set f2 = '';
--Testcase 594:
SELECT * from loc1;
--Testcase 595:
UPDATE rem1 set f2 = 'skidoo';
--Testcase 596:
SELECT * from loc1;

--Testcase 597:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f1 = 10;          -- all columns should be transmitted
--Testcase 598:
UPDATE rem1 set f1 = 10;
--Testcase 599:
SELECT * from loc1;

--Testcase 600:
DELETE FROM rem1;

-- Add a second trigger, to check that the changes are propagated correctly
-- from trigger to trigger
--Testcase 601:
CREATE TRIGGER trig_row_before_insupd2
BEFORE INSERT OR UPDATE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

--Testcase 602:
INSERT INTO rem1 values(1, 'insert');
--Testcase 603:
SELECT * from loc1;
--Testcase 604:
INSERT INTO rem1 values(2, 'insert');
--Testcase 605:
SELECT * from loc1;
--Testcase 606:
UPDATE rem1 set f2 = '';
--Testcase 607:
SELECT * from loc1;
--Testcase 608:
UPDATE rem1 set f2 = 'skidoo';
--Testcase 609:
SELECT * from loc1;

--Testcase 610:
DROP TRIGGER trig_row_before_insupd ON rem1;
--Testcase 611:
DROP TRIGGER trig_row_before_insupd2 ON rem1;

--Testcase 612:
DELETE from rem1;

--Testcase 613:
INSERT INTO rem1 VALUES (1, 'test');

-- Test with a trigger returning NULL
--Testcase 614:
CREATE FUNCTION trig_null() RETURNS TRIGGER AS $$
  BEGIN
    RETURN NULL;
  END
$$ language plpgsql;

--Testcase 615:
CREATE TRIGGER trig_null
BEFORE INSERT OR UPDATE OR DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trig_null();

-- Nothing should have changed.
--Testcase 616:
INSERT INTO rem1 VALUES (2, 'test2');

--Testcase 617:
SELECT * from loc1;

--Testcase 618:
UPDATE rem1 SET f2 = 'test2';

--Testcase 619:
SELECT * from loc1;

--Testcase 620:
DELETE from rem1;

--Testcase 621:
SELECT * from loc1;

--Testcase 622:
DROP TRIGGER trig_null ON rem1;
--Testcase 623:
DELETE from rem1;

-- Test a combination of local and remote triggers
--Testcase 624:
CREATE TRIGGER trig_row_before
BEFORE INSERT OR UPDATE OR DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 625:
CREATE TRIGGER trig_row_after
AFTER INSERT OR UPDATE OR DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 626:
CREATE TRIGGER trig_local_before BEFORE INSERT OR UPDATE ON loc1
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

--Testcase 627:
INSERT INTO rem1(f2) VALUES ('test');
--Testcase 628:
UPDATE rem1 SET f2 = 'testo';

-- Test returning a system attribute
--Testcase 629:
INSERT INTO rem1(f2) VALUES ('test');

-- cleanup
--Testcase 630:
DROP TRIGGER trig_row_before ON rem1;
--Testcase 631:
DROP TRIGGER trig_row_after ON rem1;
--Testcase 632:
DROP TRIGGER trig_local_before ON loc1;


-- Test direct foreign table modification functionality
--Testcase 855:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can be pushed down
--Testcase 856:
EXPLAIN (verbose, costs off)
DELETE FROM rem1 WHERE false;     -- currently can't be pushed down

-- Test with statement-level triggers
--Testcase 633:
CREATE TRIGGER trig_stmt_before
	BEFORE DELETE OR INSERT OR UPDATE ON rem1
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--Testcase 634:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 635:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can be pushed down
--Testcase 636:
DROP TRIGGER trig_stmt_before ON rem1;

--Testcase 637:
CREATE TRIGGER trig_stmt_after
	AFTER DELETE OR INSERT OR UPDATE ON rem1
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--Testcase 638:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 639:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can be pushed down
--Testcase 640:
DROP TRIGGER trig_stmt_after ON rem1;

-- Test with row-level ON INSERT triggers
--Testcase 641:
CREATE TRIGGER trig_row_before_insert
BEFORE INSERT ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 642:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 643:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can be pushed down
--Testcase 644:
DROP TRIGGER trig_row_before_insert ON rem1;

--Testcase 645:
CREATE TRIGGER trig_row_after_insert
AFTER INSERT ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 646:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 647:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can be pushed down
--Testcase 648:
DROP TRIGGER trig_row_after_insert ON rem1;

-- Test with row-level ON UPDATE triggers
--Testcase 649:
CREATE TRIGGER trig_row_before_update
BEFORE UPDATE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 650:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f2 = '';          -- can't be pushed down
--Testcase 651:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can be pushed down
--Testcase 652:
DROP TRIGGER trig_row_before_update ON rem1;

--Testcase 653:
CREATE TRIGGER trig_row_after_update
AFTER UPDATE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 654:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f2 = '';          -- can't be pushed down
--Testcase 655:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can be pushed down
--Testcase 656:
DROP TRIGGER trig_row_after_update ON rem1;

-- Test with row-level ON DELETE triggers
--Testcase 657:
CREATE TRIGGER trig_row_before_delete
BEFORE DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 658:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 659:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can't be pushed down
--Testcase 660:
DROP TRIGGER trig_row_before_delete ON rem1;

--Testcase 661:
CREATE TRIGGER trig_row_after_delete
AFTER DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 662:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 663:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can't be pushed down
--Testcase 664:
DROP TRIGGER trig_row_after_delete ON rem1;

-- ===================================================================
-- test inheritance features
-- ===================================================================

--Testcase 665:
CREATE TABLE a (aa TEXT);
--Testcase 666:
ALTER TABLE a SET (autovacuum_enabled = 'false');
--Testcase 667:
CREATE FOREIGN TABLE b (bb TEXT, id serial OPTIONS(key 'true')) INHERITS (a)
  SERVER :DB_SERVERNAME OPTIONS (table_name 'loct');

--Testcase 668:
INSERT INTO a(aa) VALUES('aaa');
--Testcase 669:
INSERT INTO a(aa) VALUES('aaaa');
--Testcase 670:
INSERT INTO a(aa) VALUES('aaaaa');

--Testcase 671:
INSERT INTO b(aa) VALUES('bbb');
--Testcase 672:
INSERT INTO b(aa) VALUES('bbbb');
--Testcase 673:
INSERT INTO b(aa) VALUES('bbbbb');

--Testcase 674:
SELECT tableoid::regclass, * FROM a;
--Testcase 675:
SELECT tableoid::regclass, aa, bb FROM b;
--Testcase 676:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 677:
UPDATE a SET aa = 'zzzzzz' WHERE aa LIKE 'aaaa%';

--Testcase 678:
SELECT tableoid::regclass, * FROM a;
--Testcase 679:
SELECT tableoid::regclass, aa, bb FROM b;
--Testcase 680:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 681:
UPDATE b SET aa = 'new';

--Testcase 682:
SELECT tableoid::regclass, * FROM a;
--Testcase 683:
SELECT tableoid::regclass, aa, bb FROM b;
--Testcase 684:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 685:
UPDATE a SET aa = 'newtoo';

--Testcase 686:
SELECT tableoid::regclass, * FROM a;
--Testcase 687:
SELECT tableoid::regclass, aa, bb FROM b;
--Testcase 688:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 689:
DELETE FROM a;

--Testcase 690:
SELECT tableoid::regclass, * FROM a;
--Testcase 691:
SELECT tableoid::regclass, aa, bb FROM b;
--Testcase 692:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 693:
DROP TABLE a CASCADE;
-- DROP TABLE loct;

-- Check SELECT FOR UPDATE/SHARE with an inherited source table

--Testcase 694:
create table foo (f1 int, f2 int);
--Testcase 695:
create foreign table foo2 (f3 int OPTIONS (key 'true')) inherits (foo)
  server :DB_SERVERNAME options (table_name 'loct1');
--Testcase 696:
create table bar (f1 int, f2 int);
--Testcase 697:
create foreign table bar2 (f3 int OPTIONS (key 'true')) inherits (bar)
  server :DB_SERVERNAME options (table_name 'loct2');

--Testcase 698:
alter table foo set (autovacuum_enabled = 'false');
--Testcase 699:
alter table bar set (autovacuum_enabled = 'false');

--Testcase 700:
insert into foo values(1,1);
--Testcase 701:
insert into foo values(3,3);
--Testcase 702:
insert into foo2 values(2,2,2);
--Testcase 703:
insert into foo2 values(4,4,4);
--Testcase 704:
insert into bar values(1,11);
--Testcase 705:
insert into bar values(2,22);
--Testcase 706:
insert into bar values(6,66);
--Testcase 707:
insert into bar2 values(3,33,33);
--Testcase 708:
insert into bar2 values(4,44,44);
--Testcase 709:
insert into bar2 values(7,77,77);

--Testcase 710:
explain (verbose, costs off)
select * from bar where f1 in (select f1 from foo) for update;
--Testcase 711:
select * from bar where f1 in (select f1 from foo) for update;

--Testcase 712:
explain (verbose, costs off)
select * from bar where f1 in (select f1 from foo) for share;
--Testcase 713:
select * from bar where f1 in (select f1 from foo) for share;

-- Now check SELECT FOR UPDATE/SHARE with an inherited source table,
-- where the parent is itself a foreign table
--Testcase 857:
create foreign table foo2child (f3 int) inherits (foo2)
  server :DB_SERVERNAME options (table_name 'loct4_2');

--Testcase 858:
explain (verbose, costs off)
select * from bar where f1 in (select f1 from foo2) for share;
--Testcase 859:
select * from bar where f1 in (select f1 from foo2) for share;

--Testcase 860:
drop foreign table foo2child;

-- And with a local child relation of the foreign table parent
--Testcase 861:
create table foo2child (f3 int) inherits (foo2);

--Testcase 862:
explain (verbose, costs off)
select * from bar where f1 in (select f1 from foo2) for share;
--Testcase 863:
select * from bar where f1 in (select f1 from foo2) for share;

--Testcase 864:
drop table foo2child;

-- Check UPDATE with inherited target and an inherited source table
--Testcase 714:
explain (verbose, costs off)
update bar set f2 = f2 + 100 where f1 in (select f1 from foo);
--Testcase 715:
update bar set f2 = f2 + 100 where f1 in (select f1 from foo);

--Testcase 716:
select tableoid::regclass, * from bar order by 1,2;

-- Check UPDATE with inherited target and an appendrel subquery
--Testcase 717:
explain (verbose, costs off)
update bar set f2 = f2 + 100
from
  ( select f1 from foo union all select f1+3 from foo ) ss
where bar.f1 = ss.f1;
--Testcase 718:
update bar set f2 = f2 + 100
from
  ( select f1 from foo union all select f1+3 from foo ) ss
where bar.f1 = ss.f1;

--Testcase 719:
select tableoid::regclass, * from bar order by 1,2;

-- Test forcing the remote server to produce sorted data for a merge join,
-- but the foreign table is an inheritance child.
-- truncate table loct1;
--Testcase 720:
delete from foo2;
truncate table only foo;
\set num_rows_foo 2000
--Testcase 721:
insert into foo2 select generate_series(0, :num_rows_foo, 2), generate_series(0, :num_rows_foo, 2), generate_series(0, :num_rows_foo, 2);
--Testcase 722:
insert into foo select generate_series(1, :num_rows_foo, 2), generate_series(1, :num_rows_foo, 2);
--Testcase 723:
SET enable_hashjoin to false;
--Testcase 724:
SET enable_nestloop to false;
--Testcase 725:
alter foreign table foo2 options (use_remote_estimate 'false');
--Testcase 726:
create index i_foo2_f1 on foo2(f1);
--Testcase 727:
create index i_foo_f1 on foo(f1);
analyze foo;
-- analyze foo2;
-- inner join; expressions in the clauses appear in the equivalence class list
--Testcase 728:
explain (verbose, costs off)
	select foo.f1, foo2.f1 from foo join foo2 on (foo.f1 = foo2.f1) order by foo.f2 offset 10 limit 10;
--Testcase 729:
select foo.f1, foo2.f1 from foo join foo2 on (foo.f1 = foo2.f1) order by foo.f2 offset 10 limit 10;
-- outer join; expressions in the clauses do not appear in equivalence class
-- list but no output change as compared to the previous query
--Testcase 730:
explain (verbose, costs off)
	select foo.f1, foo2.f1 from foo left join foo2 on (foo.f1 = foo2.f1) order by foo.f2 offset 10 limit 10;
--Testcase 731:
select foo.f1, foo2.f1 from foo left join foo2 on (foo.f1 = foo2.f1) order by foo.f2 offset 10 limit 10;
--Testcase 732:
RESET enable_hashjoin;
--Testcase 733:
RESET enable_nestloop;

-- Test that WHERE CURRENT OF is not supported
-- begin;
-- declare c cursor for select * from bar where f1 = 7;
-- fetch from c;
-- update bar set f2 = null where current of c;
-- rollback;

--Testcase 734:
explain (verbose, costs off)
delete from foo where f1 < 5;
--Testcase 735:
delete from foo where f1 < 5;
--Testcase 736:
explain (verbose, costs off)
update bar set f2 = f2 + 100;
--Testcase 737:
update bar set f2 = f2 + 100;

-- Test that UPDATE/DELETE with inherited target works with row-level triggers
--Testcase 738:
CREATE TRIGGER trig_row_before
BEFORE UPDATE OR DELETE ON bar2
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 739:
CREATE TRIGGER trig_row_after
AFTER UPDATE OR DELETE ON bar2
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 740:
explain (verbose, costs off)
update bar set f2 = f2 + 100;
--Testcase 741:
update bar set f2 = f2 + 100;

--Testcase 742:
explain (verbose, costs off)
delete from bar where f2 < 400;
--Testcase 743:
delete from bar where f2 < 400;

-- cleanup
--Testcase 744:
drop table foo cascade;
--Testcase 745:
drop table bar cascade;
-- drop table loct1;
-- drop table loct2;

-- Test pushing down UPDATE/DELETE joins to the remote server
--Testcase 746:
create table parent (a int, b text);
--Testcase 747:
create foreign table loct1_2 (a int OPTIONS (key 'true'), b text)
  server :DB_SERVERNAME options (table_name 'loct1_2');
--Testcase 748:
create foreign table loct2_2 (a int OPTIONS (key 'true'), b text)
  server :DB_SERVERNAME options (table_name 'loct2_2');
--Testcase 749:
create foreign table remt1 (a int OPTIONS (key 'true'), b text)
  server :DB_SERVERNAME options (table_name 'loct1_2');
--Testcase 750:
create foreign table remt2 (a int OPTIONS (key 'true'), b text)
  server :DB_SERVERNAME options (table_name 'loct2_2');
--Testcase 751:
alter foreign table remt1 inherit parent;

--Testcase 752:
insert into remt1 values (1, 'foo');
--Testcase 753:
insert into remt1 values (2, 'bar');
--Testcase 754:
insert into remt2 values (1, 'foo');
--Testcase 755:
insert into remt2 values (2, 'bar');

analyze remt1;
analyze remt2;

--Testcase 756:
explain (verbose, costs off)
update parent set b = parent.b || remt2.b from remt2 where parent.a = remt2.a;
--Testcase 757:
update parent set b = parent.b || remt2.b from remt2 where parent.a = remt2.a;
--Testcase 758:
explain (verbose, costs off)
delete from parent using remt2 where parent.a = remt2.a;
--Testcase 759:
delete from parent using remt2 where parent.a = remt2.a;

-- cleanup
--Testcase 760:
drop foreign table remt1;
--Testcase 761:
drop foreign table remt2;
--Testcase 762:
drop table parent;

/*
-- Does not support tuple routing/COPY (BeginForeignInsert is not supported)
-- ===================================================================
-- test tuple routing for foreign-table partitions
-- ===================================================================

-- Test insert tuple routing
create table itrtest (a int, b text) partition by list (a);
create foreign table loct1_3 (a int check (a in (1)), b text) server :DB_SERVERNAME options (table_name 'loct1_3');
create foreign table remp1 (a int check (a in (1)), b text) server :DB_SERVERNAME options (table_name 'loct1_3');
create foreign table loct2_3 (b text, a int check (a in (2))) server :DB_SERVERNAME options (table_name 'loct2_3');
create foreign table remp2 (b text, a int check (a in (2))) server :DB_SERVERNAME options (table_name 'loct2_3');
alter table itrtest attach partition remp1 for values in (1);
alter table itrtest attach partition remp2 for values in (2);

insert into itrtest values (1, 'foo');
insert into itrtest values (1, 'bar');
insert into itrtest values (2, 'baz');
insert into itrtest values (2, 'qux');
insert into itrtest values (1, 'test1'), (2, 'test2');

select tableoid::regclass, * FROM itrtest;
select tableoid::regclass, * FROM remp1;
select tableoid::regclass, * FROM remp2;

delete from itrtest;

create unique index loct1_idx on loct1_3 (a);

-- DO NOTHING without an inference specification is supported
insert into itrtest values (1, 'foo') on conflict do nothing;
insert into itrtest values (1, 'foo') on conflict do nothing;

-- But other cases are not supported
insert into itrtest values (1, 'bar') on conflict (a) do nothing;
insert into itrtest values (1, 'bar') on conflict (a) do update set b = excluded.b;

select tableoid::regclass, * FROM itrtest;

delete from itrtest;

drop index loct1_idx;

-- Test that remote triggers work with insert tuple routing
create function br_insert_trigfunc() returns trigger as $$
begin
	new.b := new.b || ' triggered !';
	return new;
end
$$ language plpgsql;
create trigger loct1_br_insert_trigger before insert on loct1_3
	for each row execute procedure br_insert_trigfunc();
create trigger loct2_br_insert_trigger before insert on loct2_3
	for each row execute procedure br_insert_trigfunc();

-- The new values are concatenated with ' triggered !'
insert into itrtest values (1, 'foo');
insert into itrtest values (2, 'qux');
insert into itrtest values (1, 'test1'), (2, 'test2');
with result as (insert into itrtest values (1, 'test1'), (2, 'test2')) select * from result;

drop trigger loct1_br_insert_trigger on loct1_3;
drop trigger loct2_br_insert_trigger on loct2_3;

drop table itrtest;
-- drop table loct1;
-- drop table loct2;

-- Test update tuple routing
create table utrtest (a int, b text) partition by list (a);
create foreign table loct_2 (a int check (a in (1)), b text) server :DB_SERVERNAME options (table_name 'loct_2');
create foreign table remp (a int check (a in (1)), b text) server :DB_SERVERNAME options (table_name 'loct_2');
create table locp (a int check (a in (2)), b text);
alter table utrtest attach partition remp for values in (1);
alter table utrtest attach partition locp for values in (2);

insert into utrtest values (1, 'foo');
insert into utrtest values (2, 'qux');

select tableoid::regclass, * FROM utrtest;
select tableoid::regclass, * FROM remp;
select tableoid::regclass, * FROM locp;

-- It's not allowed to move a row from a partition that is foreign to another
update utrtest set a = 2 where b = 'foo';

-- But the reverse is allowed
update utrtest set a = 1 where b = 'qux';

select tableoid::regclass, * FROM utrtest;
select tableoid::regclass, * FROM remp;
select tableoid::regclass, * FROM locp;

-- The executor should not let unexercised FDWs shut down
update utrtest set a = 1 where b = 'foo';

-- Test that remote triggers work with update tuple routing
create trigger loct_br_insert_trigger before insert on loct_2
	for each row execute procedure br_insert_trigfunc();

delete from utrtest;
insert into utrtest values (2, 'qux');

-- Check case where the foreign partition is a subplan target rel
explain (verbose, costs off)
update utrtest set a = 1 where a = 1 or a = 2;
-- The new values are concatenated with ' triggered !'
update utrtest set a = 1 where a = 1 or a = 2;

delete from utrtest;
insert into utrtest values (2, 'qux');

-- Check case where the foreign partition isn't a subplan target rel
explain (verbose, costs off)
update utrtest set a = 1 where a = 2;
-- The new values are concatenated with ' triggered !'
update utrtest set a = 1 where a = 2;

drop trigger loct_br_insert_trigger on loct_2;

-- We can move rows to a foreign partition that has been updated already,
-- but can't move rows to a foreign partition that hasn't been updated yet

delete from utrtest;
insert into utrtest values (1, 'foo');
insert into utrtest values (2, 'qux');

-- Test the former case:
-- with a direct modification plan
explain (verbose, costs off)
update utrtest set a = 1;
update utrtest set a = 1;

delete from utrtest;
insert into utrtest values (1, 'foo');
insert into utrtest values (2, 'qux');

-- with a non-direct modification plan
explain (verbose, costs off)
update utrtest set a = 1 from (values (1), (2)) s(x) where a = s.x;
update utrtest set a = 1 from (values (1), (2)) s(x) where a = s.x;

-- Change the definition of utrtest so that the foreign partition get updated
-- after the local partition
delete from utrtest;
alter table utrtest detach partition remp;
drop foreign table remp;
alter foreign table loct_2 drop constraint loct_2_a_check;
alter foreign table loct_2 add check (a in (3));
create foreign table remp (a int check (a in (3)), b text) server :DB_SERVERNAME options (table_name 'loct_2');
alter table utrtest attach partition remp for values in (3);
insert into utrtest values (2, 'qux');
insert into utrtest values (3, 'xyzzy');

-- Test the latter case:
-- with a direct modification plan
explain (verbose, costs off)
update utrtest set a = 3;
update utrtest set a = 3; -- ERROR

-- with a non-direct modification plan
explain (verbose, costs off)
update utrtest set a = 3 from (values (2), (3)) s(x) where a = s.x;
update utrtest set a = 3 from (values (2), (3)) s(x) where a = s.x; -- ERROR

drop table utrtest;
-- drop table loct;

-- Test copy tuple routing
create table ctrtest (a int, b text) partition by list (a);
create foreign table loct1_4 (a int check (a in (1)), b text) server :DB_SERVERNAME options (table_name 'loct1_4');
create foreign table remp1 (a int check (a in (1)), b text) server :DB_SERVERNAME options (table_name 'loct1_4');
create foreign table loct2_4 (b text, a int check (a in (2))) server :DB_SERVERNAME options (table_name 'loct2_4');
create foreign table remp2 (b text, a int check (a in (2))) server :DB_SERVERNAME options (table_name 'loct2_4');
alter table ctrtest attach partition remp1 for values in (1);
alter table ctrtest attach partition remp2 for values in (2);

copy ctrtest from stdin;
1	foo
2	qux
\.

select tableoid::regclass, * FROM ctrtest;
select tableoid::regclass, * FROM remp1;
select tableoid::regclass, * FROM remp2;

-- Copying into foreign partitions directly should work as well
copy remp1 from stdin;
1	bar
\.

select tableoid::regclass, * FROM remp1;

drop table ctrtest;
-- drop table loct1;
-- drop table loct2;

-- ===================================================================
-- test COPY FROM
-- ===================================================================

create foreign table loc2 (f1 int, f2 text) server :DB_SERVERNAME options(table_name 'loc2');
create foreign table rem2 (f1 int, f2 text) server :DB_SERVERNAME options(table_name 'loc2');

-- Test basic functionality
copy rem2 from stdin;
1	foo
2	bar
\.
select * from rem2;

delete from rem2;

-- Test check constraints
alter foreign table loc2 add constraint loc2_f1positive check (f1 >= 0);
alter foreign table rem2 add constraint rem2_f1positive check (f1 >= 0);

-- check constraint is enforced on the remote side, not locally
copy rem2 from stdin;
1	foo
2	bar
\.
copy rem2 from stdin; -- ERROR
-1	xyzzy
\.
select * from rem2;

alter foreign table rem2 drop constraint rem2_f1positive;
alter foreign table loc2 drop constraint loc2_f1positive;

delete from rem2;

-- Test local triggers
create trigger trig_stmt_before before insert on rem2
	for each statement execute procedure trigger_func();
create trigger trig_stmt_after after insert on rem2
	for each statement execute procedure trigger_func();
create trigger trig_row_before before insert on rem2
	for each row execute procedure trigger_data(23,'skidoo');
create trigger trig_row_after after insert on rem2
	for each row execute procedure trigger_data(23,'skidoo');

copy rem2 from stdin;
1	foo
2	bar
\.
select * from rem2;

drop trigger trig_row_before on rem2;
drop trigger trig_row_after on rem2;
drop trigger trig_stmt_before on rem2;
drop trigger trig_stmt_after on rem2;

delete from rem2;

create trigger trig_row_before_insert before insert on rem2
	for each row execute procedure trig_row_before_insupdate();

-- The new values are concatenated with ' triggered !'
copy rem2 from stdin;
1	foo
2	bar
\.
select * from rem2;

drop trigger trig_row_before_insert on rem2;

delete from rem2;

create trigger trig_null before insert on rem2
	for each row execute procedure trig_null();

-- Nothing happens
copy rem2 from stdin;
1	foo
2	bar
\.
select * from rem2;

drop trigger trig_null on rem2;

delete from rem2;

-- Test remote triggers
create trigger trig_row_before_insert before insert on loc2
	for each row execute procedure trig_row_before_insupdate();

-- The new values are concatenated with ' triggered !'
copy rem2 from stdin;
1	foo
2	bar
\.
select * from rem2;

drop trigger trig_row_before_insert on loc2;

delete from rem2;

create trigger trig_null before insert on loc2
	for each row execute procedure trig_null();

-- Nothing happens
copy rem2 from stdin;
1	foo
2	bar
\.
select * from rem2;

drop trigger trig_null on loc2;

delete from rem2;

-- Test a combination of local and remote triggers
create trigger rem2_trig_row_before before insert on rem2
	for each row execute procedure trigger_data(23,'skidoo');
create trigger rem2_trig_row_after after insert on rem2
	for each row execute procedure trigger_data(23,'skidoo');
create trigger loc2_trig_row_before_insert before insert on loc2
	for each row execute procedure trig_row_before_insupdate();

copy rem2 from stdin;
1	foo
2	bar
\.
select * from rem2;

drop trigger rem2_trig_row_before on rem2;
drop trigger rem2_trig_row_after on rem2;
drop trigger loc2_trig_row_before_insert on loc2;

delete from rem2;

-- test COPY FROM with foreign table created in the same transaction
-- begin;
create foreign table loc3 (f1 int, f2 text)
	server :DB_SERVERNAME options(table_name 'loc3');
create foreign table rem3 (f1 int, f2 text)
	server :DB_SERVERNAME options(table_name 'loc3');
copy rem3 from stdin;
1	foo
2	bar
\.
-- commit;
select * from rem3;
drop foreign table rem3;
-- drop table loc3;
*/

-- ===================================================================
-- test for TRUNCATE
-- ===================================================================
-- CREATE TABLE tru_rtable0 (id int primary key);
-- CREATE FOREIGN TABLE tru_ftable (id int)
--        SERVER loopback OPTIONS (table_name 'tru_rtable0');
-- INSERT INTO tru_rtable0 (SELECT x FROM generate_series(1,10) x);

-- CREATE TABLE tru_ptable (id int) PARTITION BY HASH(id);
-- CREATE TABLE tru_ptable__p0 PARTITION OF tru_ptable
--                             FOR VALUES WITH (MODULUS 2, REMAINDER 0);
-- CREATE TABLE tru_rtable1 (id int primary key);
-- CREATE FOREIGN TABLE tru_ftable__p1 PARTITION OF tru_ptable
--                                     FOR VALUES WITH (MODULUS 2, REMAINDER 1)
--        SERVER loopback OPTIONS (table_name 'tru_rtable1');
-- INSERT INTO tru_ptable (SELECT x FROM generate_series(11,20) x);

-- CREATE TABLE tru_pk_table(id int primary key);
-- CREATE TABLE tru_fk_table(fkey int references tru_pk_table(id));
-- INSERT INTO tru_pk_table (SELECT x FROM generate_series(1,10) x);
-- INSERT INTO tru_fk_table (SELECT x % 10 + 1 FROM generate_series(5,25) x);
-- CREATE FOREIGN TABLE tru_pk_ftable (id int)
--        SERVER loopback OPTIONS (table_name 'tru_pk_table');

-- CREATE TABLE tru_rtable_parent (id int);
-- CREATE TABLE tru_rtable_child (id int);
-- CREATE FOREIGN TABLE tru_ftable_parent (id int)
--        SERVER loopback OPTIONS (table_name 'tru_rtable_parent');
-- CREATE FOREIGN TABLE tru_ftable_child () INHERITS (tru_ftable_parent)
--        SERVER loopback OPTIONS (table_name 'tru_rtable_child');
-- INSERT INTO tru_rtable_parent (SELECT x FROM generate_series(1,8) x);
-- INSERT INTO tru_rtable_child  (SELECT x FROM generate_series(10, 18) x);

-- -- normal truncate
-- SELECT sum(id) FROM tru_ftable;        -- 55
-- TRUNCATE tru_ftable;
-- SELECT count(*) FROM tru_rtable0;		-- 0
-- SELECT count(*) FROM tru_ftable;		-- 0

-- -- 'truncatable' option
-- ALTER SERVER loopback OPTIONS (ADD truncatable 'false');
-- TRUNCATE tru_ftable;			-- error
-- ALTER FOREIGN TABLE tru_ftable OPTIONS (ADD truncatable 'true');
-- TRUNCATE tru_ftable;			-- accepted
-- ALTER FOREIGN TABLE tru_ftable OPTIONS (SET truncatable 'false');
-- TRUNCATE tru_ftable;			-- error
-- ALTER SERVER loopback OPTIONS (DROP truncatable);
-- ALTER FOREIGN TABLE tru_ftable OPTIONS (SET truncatable 'false');
-- TRUNCATE tru_ftable;			-- error
-- ALTER FOREIGN TABLE tru_ftable OPTIONS (SET truncatable 'true');
-- TRUNCATE tru_ftable;			-- accepted

-- -- partitioned table with both local and foreign tables as partitions
-- SELECT sum(id) FROM tru_ptable;        -- 155
-- TRUNCATE tru_ptable;
-- SELECT count(*) FROM tru_ptable;		-- 0
-- SELECT count(*) FROM tru_ptable__p0;	-- 0
-- SELECT count(*) FROM tru_ftable__p1;	-- 0
-- SELECT count(*) FROM tru_rtable1;		-- 0

-- -- 'CASCADE' option
-- SELECT sum(id) FROM tru_pk_ftable;      -- 55
-- TRUNCATE tru_pk_ftable;	-- failed by FK reference
-- TRUNCATE tru_pk_ftable CASCADE;
-- SELECT count(*) FROM tru_pk_ftable;    -- 0
-- SELECT count(*) FROM tru_fk_table;		-- also truncated,0

-- -- truncate two tables at a command
-- INSERT INTO tru_ftable (SELECT x FROM generate_series(1,8) x);
-- INSERT INTO tru_pk_ftable (SELECT x FROM generate_series(3,10) x);
-- SELECT count(*) from tru_ftable; -- 8
-- SELECT count(*) from tru_pk_ftable; -- 8
-- TRUNCATE tru_ftable, tru_pk_ftable CASCADE;
-- SELECT count(*) from tru_ftable; -- 0
-- SELECT count(*) from tru_pk_ftable; -- 0

-- -- truncate with ONLY clause
-- -- Since ONLY is specified, the table tru_ftable_child that inherits
-- -- tru_ftable_parent locally is not truncated.
-- TRUNCATE ONLY tru_ftable_parent;
-- SELECT sum(id) FROM tru_ftable_parent;  -- 126
-- TRUNCATE tru_ftable_parent;
-- SELECT count(*) FROM tru_ftable_parent; -- 0

-- -- in case when remote table has inherited children
-- CREATE TABLE tru_rtable0_child () INHERITS (tru_rtable0);
-- INSERT INTO tru_rtable0 (SELECT x FROM generate_series(5,9) x);
-- INSERT INTO tru_rtable0_child (SELECT x FROM generate_series(10,14) x);
-- SELECT sum(id) FROM tru_ftable;   -- 95

-- -- Both parent and child tables in the foreign server are truncated
-- -- even though ONLY is specified because ONLY has no effect
-- -- when truncating a foreign table.
-- TRUNCATE ONLY tru_ftable;
-- SELECT count(*) FROM tru_ftable;   -- 0

-- INSERT INTO tru_rtable0 (SELECT x FROM generate_series(21,25) x);
-- INSERT INTO tru_rtable0_child (SELECT x FROM generate_series(26,30) x);
-- SELECT sum(id) FROM tru_ftable;		-- 255
-- TRUNCATE tru_ftable;			-- truncate both of parent and child
-- SELECT count(*) FROM tru_ftable;    -- 0

-- -- cleanup
-- DROP FOREIGN TABLE tru_ftable_parent, tru_ftable_child, tru_pk_ftable,tru_ftable__p1,tru_ftable;
-- DROP TABLE tru_rtable0, tru_rtable1, tru_ptable, tru_ptable__p0, tru_pk_table, tru_fk_table,
-- tru_rtable_parent,tru_rtable_child, tru_rtable0_child;

-- ===================================================================
-- test IMPORT FOREIGN SCHEMA
-- ===================================================================
--Testcase 763:
CREATE TYPE "Colors" AS ENUM ('red', 'green', 'blue');
--Testcase 764:
CREATE TYPE typ1 AS (m1 int, m2 varchar);
--Testcase 765:
CREATE SCHEMA import_dest1;
IMPORT FOREIGN SCHEMA import_source FROM SERVER :DB_SERVERNAME INTO import_dest1;
--Testcase 766:
\det+ import_dest1.*
--Testcase 767:
\d import_dest1.*

-- Options
--Testcase 768:
CREATE SCHEMA import_dest2;
IMPORT FOREIGN SCHEMA import_source FROM SERVER :DB_SERVERNAME INTO import_dest2
  OPTIONS (import_default 'true');
--Testcase 769:
\det+ import_dest2.*
--Testcase 770:
\d import_dest2.*
--Testcase 771:
CREATE SCHEMA import_dest3;
IMPORT FOREIGN SCHEMA import_source FROM SERVER :DB_SERVERNAME INTO import_dest3
  OPTIONS (import_collate 'false', import_generated 'false', import_not_null 'false');
--Testcase 772:
\det+ import_dest3.*
--Testcase 773:
\d import_dest3.*

-- Check LIMIT TO and EXCEPT
--Testcase 774:
CREATE SCHEMA import_dest4;
IMPORT FOREIGN SCHEMA import_source LIMIT TO (t1, nonesuch, t4_part)
  FROM SERVER :DB_SERVERNAME INTO import_dest4;
--Testcase 775:
\det+ import_dest4.*
IMPORT FOREIGN SCHEMA import_source EXCEPT (t1, "x 4", nonesuch, t4_part)
  FROM SERVER :DB_SERVERNAME INTO import_dest4;
--Testcase 776:
\det+ import_dest4.*

-- Assorted error cases
IMPORT FOREIGN SCHEMA import_source FROM SERVER :DB_SERVERNAME INTO import_dest4;
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER :DB_SERVERNAME INTO import_dest4;
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER :DB_SERVERNAME INTO notthere;
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER nowhere INTO notthere;

-- Check case of a type present only on the remote server.
-- We can fake this by dropping the type locally in our transaction.
--Testcase 777:
CREATE TABLE import_source.t5 (c1 int, c2 text collate "C", "Col" "Colors");

--Testcase 778:
CREATE SCHEMA import_dest5;
-- BEGIN;
--Testcase 779:
DROP TYPE "Colors" CASCADE;
IMPORT FOREIGN SCHEMA import_source LIMIT TO (t5)
  FROM SERVER :DB_SERVERNAME INTO import_dest5;  -- ERROR

-- ===================================================================
-- test partitionwise joins
-- ===================================================================
--Testcase 790:
SET enable_partitionwise_join=on;

--Testcase 791:
CREATE TABLE fprt1 (a int, b int, c varchar) PARTITION BY RANGE(a);
--Testcase 792:
CREATE FOREIGN TABLE ftprt1_p1 PARTITION OF fprt1 FOR VALUES FROM (0) TO (250)
	SERVER :DB_SERVERNAME OPTIONS (table_name 'fprt1_p1', use_remote_estimate 'false');
--Testcase 793:
CREATE FOREIGN TABLE ftprt1_p2 PARTITION OF fprt1 FOR VALUES FROM (250) TO (500)
	SERVER :DB_SERVERNAME OPTIONS (TABLE_NAME 'fprt1_p2');
-- ANALYZE fprt1;
-- ANALYZE fprt1_p1;
-- ANALYZE fprt1_p2;

--Testcase 794:
CREATE TABLE fprt2 (a int, b int, c varchar) PARTITION BY RANGE(b);
--Testcase 795:
CREATE FOREIGN TABLE ftprt2_p1 (b int, c varchar, a int)
	SERVER :DB_SERVERNAME OPTIONS (table_name 'fprt2_p1', use_remote_estimate 'false');
--Testcase 796:
ALTER TABLE fprt2 ATTACH PARTITION ftprt2_p1 FOR VALUES FROM (0) TO (250);
--Testcase 797:
CREATE FOREIGN TABLE ftprt2_p2 PARTITION OF fprt2 FOR VALUES FROM (250) TO (500)
	SERVER :DB_SERVERNAME OPTIONS (table_name 'fprt2_p2', use_remote_estimate 'false');

-- inner join three tables
--Testcase 798:
EXPLAIN (COSTS OFF)
SELECT t1.a,t2.b,t3.c FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) INNER JOIN fprt1 t3 ON (t2.b = t3.a) WHERE t1.a % 25 =0 ORDER BY 1,2,3;
--Testcase 799:
SELECT t1.a,t2.b,t3.c FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) INNER JOIN fprt1 t3 ON (t2.b = t3.a) WHERE t1.a % 25 =0 ORDER BY 1,2,3;

-- left outer join + nullable clause
--Testcase 800:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.a,t2.b,t2.c FROM fprt1 t1 LEFT JOIN (SELECT * FROM fprt2 WHERE a < 10) t2 ON (t1.a = t2.b and t1.b = t2.a) WHERE t1.a < 10 ORDER BY 1,2,3;
--Testcase 801:
SELECT t1.a,t2.b,t2.c FROM fprt1 t1 LEFT JOIN (SELECT * FROM fprt2 WHERE a < 10) t2 ON (t1.a = t2.b and t1.b = t2.a) WHERE t1.a < 10 ORDER BY 1,2,3;

-- with whole-row reference; partitionwise join does not apply
--Testcase 802:
EXPLAIN (COSTS OFF)
SELECT t1.wr, t2.wr FROM (SELECT t1 wr, a FROM fprt1 t1 WHERE t1.a % 25 = 0) t1 FULL JOIN (SELECT t2 wr, b FROM fprt2 t2 WHERE t2.b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY 1,2;
--Testcase 803:
SELECT t1.wr, t2.wr FROM (SELECT t1 wr, a FROM fprt1 t1 WHERE t1.a % 25 = 0) t1 FULL JOIN (SELECT t2 wr, b FROM fprt2 t2 WHERE t2.b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY 1,2;

-- join with lateral reference
--Testcase 804:
EXPLAIN (COSTS OFF)
SELECT t1.a,t1.b FROM fprt1 t1, LATERAL (SELECT t2.a, t2.b FROM fprt2 t2 WHERE t1.a = t2.b AND t1.b = t2.a) q WHERE t1.a%25 = 0 ORDER BY 1,2;
--Testcase 805:
SELECT t1.a,t1.b FROM fprt1 t1, LATERAL (SELECT t2.a, t2.b FROM fprt2 t2 WHERE t1.a = t2.b AND t1.b = t2.a) q WHERE t1.a%25 = 0 ORDER BY 1,2;

-- with PHVs, partitionwise join selected but no join pushdown
--Testcase 806:
EXPLAIN (COSTS OFF)
SELECT t1.a, t1.phv, t2.b, t2.phv FROM (SELECT 't1_phv' phv, * FROM fprt1 WHERE a % 25 = 0) t1 FULL JOIN (SELECT 't2_phv' phv, * FROM fprt2 WHERE b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY t1.a, t2.b;
--Testcase 807:
SELECT t1.a, t1.phv, t2.b, t2.phv FROM (SELECT 't1_phv' phv, * FROM fprt1 WHERE a % 25 = 0) t1 FULL JOIN (SELECT 't2_phv' phv, * FROM fprt2 WHERE b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY t1.a, t2.b;

-- test FOR UPDATE; partitionwise join does not apply
--Testcase 808:
EXPLAIN (COSTS OFF)
SELECT t1.a, t2.b FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) WHERE t1.a % 25 = 0 ORDER BY 1,2 FOR UPDATE OF t1;
--Testcase 809:
SELECT t1.a, t2.b FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) WHERE t1.a % 25 = 0 ORDER BY 1,2 FOR UPDATE OF t1;

--Testcase 810:
RESET enable_partitionwise_join;


-- ===================================================================
-- test partitionwise aggregates
-- ===================================================================

--Testcase 811:
CREATE TABLE pagg_tab (a int, b int, c text) PARTITION BY RANGE(a);

-- Create foreign partitions
--Testcase 812:
CREATE FOREIGN TABLE fpagg_tab_p1 PARTITION OF pagg_tab FOR VALUES FROM (0) TO (10) SERVER :DB_SERVERNAME OPTIONS (table_name 'pagg_tab_p1');
--Testcase 813:
CREATE FOREIGN TABLE fpagg_tab_p2 PARTITION OF pagg_tab FOR VALUES FROM (10) TO (20) SERVER :DB_SERVERNAME OPTIONS (table_name 'pagg_tab_p2');
--Testcase 814:
CREATE FOREIGN TABLE fpagg_tab_p3 PARTITION OF pagg_tab FOR VALUES FROM (20) TO (30) SERVER :DB_SERVERNAME OPTIONS (table_name 'pagg_tab_p3');


-- When GROUP BY clause matches with PARTITION KEY.
-- Plan with partitionwise aggregates is disabled
--Testcase 815:
SET enable_partitionwise_aggregate TO false;
--Testcase 816:
EXPLAIN (COSTS OFF)
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- Plan with partitionwise aggregates is enabled
--Testcase 817:
SET enable_partitionwise_aggregate TO true;
--Testcase 818:
EXPLAIN (COSTS OFF)
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;
--Testcase 819:
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- Check with whole-row reference
-- Should have all the columns in the target list for the given relation
--Testcase 820:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT a, count(t1) FROM pagg_tab t1 GROUP BY a HAVING avg(b) < 22 ORDER BY 1;
--Testcase 821:
SELECT a, count(t1) FROM pagg_tab t1 GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- When GROUP BY clause does not match with PARTITION KEY.
--Testcase 822:
EXPLAIN (COSTS OFF)
SELECT b, avg(a), max(a), count(*) FROM pagg_tab GROUP BY b HAVING sum(a) < 700 ORDER BY 1;

-- ===================================================================
-- access rights and superuser
-- ===================================================================

-- -- Non-superuser cannot create a FDW without a password in the connstr
-- CREATE ROLE regress_nosuper NOSUPERUSER;

-- GRANT USAGE ON FOREIGN DATA WRAPPER :DB_EXTENSIONNAME TO regress_nosuper;

-- SET ROLE regress_nosuper;

-- SHOW is_superuser;

-- -- This will be OK, we can create the FDW
-- DO $d$
--     BEGIN
--         EXECUTE $$CREATE SERVER loopback_nopw FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
--             OPTIONS (dbname '$$||current_database()||$$',
--                      port '$$||current_setting('port')||$$'
--             )$$;
--     END;
-- $d$;

-- -- But creation of user mappings for non-superusers should fail
-- CREATE USER MAPPING FOR public SERVER loopback_nopw;
-- CREATE USER MAPPING FOR CURRENT_USER SERVER loopback_nopw;

-- CREATE FOREIGN TABLE pg_temp.ft1_nopw (
-- 	c1 int NOT NULL,
-- 	c2 int NOT NULL,
-- 	c3 text,
-- 	c4 timestamptz,
-- 	c5 timestamp,
-- 	c6 varchar(10),
-- 	c7 char(10) default 'ft1',
-- 	c8 user_enum
-- ) SERVER loopback_nopw OPTIONS (schema_name 'public', table_name 'ft1');

-- SELECT 1 FROM ft1_nopw LIMIT 1;

-- -- If we add a password to the connstr it'll fail, because we don't allow passwords
-- -- in connstrs only in user mappings.

-- DO $d$
--     BEGIN
--         EXECUTE $$ALTER SERVER loopback_nopw OPTIONS (ADD password 'dummypw')$$;
--     END;
-- $d$;

-- -- If we add a password for our user mapping instead, we should get a different
-- -- error because the password wasn't actually *used* when we run with trust auth.
-- --
-- -- This won't work with installcheck, but neither will most of the FDW checks.

-- ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD password 'dummypw');

-- SELECT 1 FROM ft1_nopw LIMIT 1;

-- -- Unpriv user cannot make the mapping passwordless
-- ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD password_required 'false');


-- SELECT 1 FROM ft1_nopw LIMIT 1;

-- RESET ROLE;

-- -- But the superuser can
-- ALTER USER MAPPING FOR regress_nosuper SERVER loopback_nopw OPTIONS (ADD password_required 'false');

-- SET ROLE regress_nosuper;

-- -- Should finally work now
-- SELECT 1 FROM ft1_nopw LIMIT 1;

-- -- unpriv user also cannot set sslcert / sslkey on the user mapping
-- -- first set password_required so we see the right error messages
-- ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (SET password_required 'true');
-- ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD sslcert 'foo.crt');
-- ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD sslkey 'foo.key');

-- -- We're done with the role named after a specific user and need to check the
-- -- changes to the public mapping.
-- DROP USER MAPPING FOR CURRENT_USER SERVER loopback_nopw;

-- -- This will fail again as it'll resolve the user mapping for public, which
-- -- lacks password_required=false
-- SELECT 1 FROM ft1_nopw LIMIT 1;

-- RESET ROLE;

-- -- The user mapping for public is passwordless and lacks the password_required=false
-- -- mapping option, but will work because the current user is a superuser.
-- SELECT 1 FROM ft1_nopw LIMIT 1;

-- -- cleanup
-- DROP USER MAPPING FOR public SERVER loopback_nopw;
-- DROP OWNED BY regress_nosuper;
-- DROP ROLE regress_nosuper;

-- -- Clean-up
-- RESET enable_partitionwise_aggregate;

-- -- Two-phase transactions are not supported.
-- BEGIN;
-- SELECT count(*) FROM ft1;
-- -- error here
-- PREPARE TRANSACTION 'fdw_tpc';
-- ROLLBACK;

/*
-- ===================================================================
-- reestablish new connection
-- ===================================================================

-- Change application_name of remote connection to special one
-- so that we can easily terminate the connection later.
ALTER SERVER loopback OPTIONS (application_name 'fdw_retry_check');

-- If debug_discard_caches is active, it results in
-- dropping remote connections after every transaction, making it
-- impossible to test termination meaningfully.  So turn that off
-- for this test.
SET debug_discard_caches = 0;

-- Make sure we have a remote connection.
SELECT 1 FROM ft1 LIMIT 1;

-- Terminate the remote connection and wait for the termination to complete.
SELECT pg_terminate_backend(pid, 180000) FROM pg_stat_activity
	WHERE application_name = 'fdw_retry_check';

-- This query should detect the broken connection when starting new remote
-- transaction, reestablish new connection, and then succeed.
BEGIN;
SELECT 1 FROM ft1 LIMIT 1;

-- If we detect the broken connection when starting a new remote
-- subtransaction, we should fail instead of establishing a new connection.
-- Terminate the remote connection and wait for the termination to complete.
SELECT pg_terminate_backend(pid, 180000) FROM pg_stat_activity
	WHERE application_name = 'fdw_retry_check';
SAVEPOINT s;
-- The text of the error might vary across platforms, so only show SQLSTATE.
\set VERBOSITY sqlstate
SELECT 1 FROM ft1 LIMIT 1;    -- should fail
\set VERBOSITY default
COMMIT;

RESET debug_discard_caches;

-- =============================================================================
-- test connection invalidation cases and postgres_fdw_get_connections function
-- =============================================================================
-- Let's ensure to close all the existing cached connections.
SELECT 1 FROM postgres_fdw_disconnect_all();
-- No cached connections, so no records should be output.
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
-- This test case is for closing the connection in pgfdw_xact_callback
BEGIN;
-- Connection xact depth becomes 1 i.e. the connection is in midst of the xact.
SELECT 1 FROM ft1 LIMIT 1;
SELECT 1 FROM ft7 LIMIT 1;
-- List all the existing cached connections. loopback and loopback3 should be
-- output.
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
-- Connections are not closed at the end of the alter and drop statements.
-- That's because the connections are in midst of this xact,
-- they are just marked as invalid in pgfdw_inval_callback.
ALTER SERVER loopback OPTIONS (ADD use_remote_estimate 'off');
DROP SERVER loopback3 CASCADE;
-- List all the existing cached connections. loopback and loopback3
-- should be output as invalid connections. Also the server name for
-- loopback3 should be NULL because the server was dropped.
SELECT * FROM postgres_fdw_get_connections() ORDER BY 1;
-- The invalid connections get closed in pgfdw_xact_callback during commit.
COMMIT;
-- All cached connections were closed while committing above xact, so no
-- records should be output.
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;

-- =======================================================================
-- test postgres_fdw_disconnect and postgres_fdw_disconnect_all functions
-- =======================================================================
BEGIN;
-- Ensure to cache loopback connection.
SELECT 1 FROM ft1 LIMIT 1;
-- Ensure to cache loopback2 connection.
SELECT 1 FROM ft6 LIMIT 1;
-- List all the existing cached connections. loopback and loopback2 should be
-- output.
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
-- Issue a warning and return false as loopback connection is still in use and
-- can not be closed.
SELECT postgres_fdw_disconnect('loopback');
-- List all the existing cached connections. loopback and loopback2 should be
-- output.
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
-- Return false as connections are still in use, warnings are issued.
-- But disable warnings temporarily because the order of them is not stable.
SET client_min_messages = 'ERROR';
SELECT postgres_fdw_disconnect_all();
RESET client_min_messages;
COMMIT;
-- Ensure that loopback2 connection is closed.
SELECT 1 FROM postgres_fdw_disconnect('loopback2');
SELECT server_name FROM postgres_fdw_get_connections() WHERE server_name = 'loopback2';
-- Return false as loopback2 connection is closed already.
SELECT postgres_fdw_disconnect('loopback2');
-- Return an error as there is no foreign server with given name.
SELECT postgres_fdw_disconnect('unknownserver');
-- Let's ensure to close all the existing cached connections.
SELECT 1 FROM postgres_fdw_disconnect_all();
-- No cached connections, so no records should be output.
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;

-- =============================================================================
-- test case for having multiple cached connections for a foreign server
-- =============================================================================
CREATE ROLE regress_multi_conn_user1 SUPERUSER;
CREATE ROLE regress_multi_conn_user2 SUPERUSER;
CREATE USER MAPPING FOR regress_multi_conn_user1 SERVER loopback;
CREATE USER MAPPING FOR regress_multi_conn_user2 SERVER loopback;

BEGIN;
-- Will cache loopback connection with user mapping for regress_multi_conn_user1
SET ROLE regress_multi_conn_user1;
SELECT 1 FROM ft1 LIMIT 1;
RESET ROLE;

-- Will cache loopback connection with user mapping for regress_multi_conn_user2
SET ROLE regress_multi_conn_user2;
SELECT 1 FROM ft1 LIMIT 1;
RESET ROLE;

-- Should output two connections for loopback server
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
COMMIT;
-- Let's ensure to close all the existing cached connections.
SELECT 1 FROM postgres_fdw_disconnect_all();
-- No cached connections, so no records should be output.
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;

-- Clean up
DROP USER MAPPING FOR regress_multi_conn_user1 SERVER loopback;
DROP USER MAPPING FOR regress_multi_conn_user2 SERVER loopback;
DROP ROLE regress_multi_conn_user1;
DROP ROLE regress_multi_conn_user2;

-- ===================================================================
-- Test foreign server level option keep_connections
-- ===================================================================
-- By default, the connections associated with foreign server are cached i.e.
-- keep_connections option is on. Set it to off.
ALTER SERVER loopback OPTIONS (keep_connections 'off');
-- connection to loopback server is closed at the end of xact
-- as keep_connections was set to off.
SELECT 1 FROM ft1 LIMIT 1;
-- No cached connections, so no records should be output.
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
ALTER SERVER loopback OPTIONS (SET keep_connections 'on');

-- ===================================================================
-- batch insert
-- ===================================================================

BEGIN;

CREATE SERVER batch10 FOREIGN DATA WRAPPER postgres_fdw OPTIONS( batch_size '10' );

SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'batch10'
AND srvoptions @> array['batch_size=10'];

ALTER SERVER batch10 OPTIONS( SET batch_size '20' );

SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'batch10'
AND srvoptions @> array['batch_size=10'];

SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'batch10'
AND srvoptions @> array['batch_size=20'];

CREATE FOREIGN TABLE table30 ( x int ) SERVER batch10 OPTIONS ( batch_size '30' );

SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30'::regclass
AND ftoptions @> array['batch_size=30'];

ALTER FOREIGN TABLE table30 OPTIONS ( SET batch_size '40');

SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30'::regclass
AND ftoptions @> array['batch_size=30'];

SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30'::regclass
AND ftoptions @> array['batch_size=40'];

ROLLBACK;

CREATE TABLE batch_table ( x int );

CREATE FOREIGN TABLE ftable ( x int ) SERVER loopback OPTIONS ( table_name 'batch_table', batch_size '10' );
EXPLAIN (VERBOSE, COSTS OFF) INSERT INTO ftable SELECT * FROM generate_series(1, 10) i;
INSERT INTO ftable SELECT * FROM generate_series(1, 10) i;
INSERT INTO ftable SELECT * FROM generate_series(11, 31) i;
INSERT INTO ftable VALUES (32);
INSERT INTO ftable VALUES (33), (34);
SELECT COUNT(*) FROM ftable;
TRUNCATE batch_table;
DROP FOREIGN TABLE ftable;

-- try if large batches exceed max number of bind parameters
CREATE FOREIGN TABLE ftable ( x int ) SERVER loopback OPTIONS ( table_name 'batch_table', batch_size '100000' );
INSERT INTO ftable SELECT * FROM generate_series(1, 70000) i;
SELECT COUNT(*) FROM ftable;
TRUNCATE batch_table;
DROP FOREIGN TABLE ftable;

-- Disable batch insert
CREATE FOREIGN TABLE ftable ( x int ) SERVER loopback OPTIONS ( table_name 'batch_table', batch_size '1' );
EXPLAIN (VERBOSE, COSTS OFF) INSERT INTO ftable VALUES (1), (2);
INSERT INTO ftable VALUES (1), (2);
SELECT COUNT(*) FROM ftable;

-- Disable batch inserting into foreign tables with BEFORE ROW INSERT triggers
-- even if the batch_size option is enabled.
ALTER FOREIGN TABLE ftable OPTIONS ( SET batch_size '10' );
CREATE TRIGGER trig_row_before BEFORE INSERT ON ftable
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
EXPLAIN (VERBOSE, COSTS OFF) INSERT INTO ftable VALUES (3), (4);
INSERT INTO ftable VALUES (3), (4);
SELECT COUNT(*) FROM ftable;

-- Clean up
DROP TRIGGER trig_row_before ON ftable;
DROP FOREIGN TABLE ftable;
DROP TABLE batch_table;

-- Use partitioning
CREATE TABLE batch_table ( x int ) PARTITION BY HASH (x);

CREATE TABLE batch_table_p0 (LIKE batch_table);
CREATE FOREIGN TABLE batch_table_p0f
	PARTITION OF batch_table
	FOR VALUES WITH (MODULUS 3, REMAINDER 0)
	SERVER loopback
	OPTIONS (table_name 'batch_table_p0', batch_size '10');

CREATE TABLE batch_table_p1 (LIKE batch_table);
CREATE FOREIGN TABLE batch_table_p1f
	PARTITION OF batch_table
	FOR VALUES WITH (MODULUS 3, REMAINDER 1)
	SERVER loopback
	OPTIONS (table_name 'batch_table_p1', batch_size '1');

CREATE TABLE batch_table_p2
	PARTITION OF batch_table
	FOR VALUES WITH (MODULUS 3, REMAINDER 2);

INSERT INTO batch_table SELECT * FROM generate_series(1, 66) i;
SELECT COUNT(*) FROM batch_table;

-- Check that enabling batched inserts doesn't interfere with cross-partition
-- updates
CREATE TABLE batch_cp_upd_test (a int) PARTITION BY LIST (a);
CREATE TABLE batch_cp_upd_test1 (LIKE batch_cp_upd_test);
CREATE FOREIGN TABLE batch_cp_upd_test1_f
	PARTITION OF batch_cp_upd_test
	FOR VALUES IN (1)
	SERVER loopback
	OPTIONS (table_name 'batch_cp_upd_test1', batch_size '10');
CREATE TABLE batch_cp_up_test1 PARTITION OF batch_cp_upd_test
	FOR VALUES IN (2);
INSERT INTO batch_cp_upd_test VALUES (1), (2);

-- The following moves a row from the local partition to the foreign one
UPDATE batch_cp_upd_test t SET a = 1 FROM (VALUES (1), (2)) s(a) WHERE t.a = s.a;
SELECT tableoid::regclass, * FROM batch_cp_upd_test;

-- Clean up
DROP TABLE batch_table, batch_cp_upd_test, batch_table_p0, batch_table_p1 CASCADE;

-- Use partitioning
ALTER SERVER loopback OPTIONS (ADD batch_size '10');

CREATE TABLE batch_table ( x int, field1 text, field2 text) PARTITION BY HASH (x);

CREATE TABLE batch_table_p0 (LIKE batch_table);
ALTER TABLE batch_table_p0 ADD CONSTRAINT p0_pkey PRIMARY KEY (x);
CREATE FOREIGN TABLE batch_table_p0f
	PARTITION OF batch_table
	FOR VALUES WITH (MODULUS 2, REMAINDER 0)
	SERVER loopback
	OPTIONS (table_name 'batch_table_p0');

CREATE TABLE batch_table_p1 (LIKE batch_table);
ALTER TABLE batch_table_p1 ADD CONSTRAINT p1_pkey PRIMARY KEY (x);
CREATE FOREIGN TABLE batch_table_p1f
	PARTITION OF batch_table
	FOR VALUES WITH (MODULUS 2, REMAINDER 1)
	SERVER loopback
	OPTIONS (table_name 'batch_table_p1');

INSERT INTO batch_table SELECT i, 'test'||i, 'test'|| i FROM generate_series(1, 50) i;
SELECT COUNT(*) FROM batch_table;
SELECT * FROM batch_table ORDER BY x;

ALTER SERVER loopback OPTIONS (DROP batch_size);

-- ===================================================================
-- test asynchronous execution
-- ===================================================================

ALTER SERVER loopback OPTIONS (DROP extensions);
ALTER SERVER loopback OPTIONS (ADD async_capable 'true');
ALTER SERVER loopback2 OPTIONS (ADD async_capable 'true');

CREATE TABLE async_pt (a int, b int, c text) PARTITION BY RANGE (a);
CREATE TABLE base_tbl1 (a int, b int, c text);
CREATE TABLE base_tbl2 (a int, b int, c text);
CREATE FOREIGN TABLE async_p1 PARTITION OF async_pt FOR VALUES FROM (1000) TO (2000)
  SERVER loopback OPTIONS (table_name 'base_tbl1');
CREATE FOREIGN TABLE async_p2 PARTITION OF async_pt FOR VALUES FROM (2000) TO (3000)
  SERVER loopback2 OPTIONS (table_name 'base_tbl2');
INSERT INTO async_p1 SELECT 1000 + i, i, to_char(i, 'FM0000') FROM generate_series(0, 999, 5) i;
INSERT INTO async_p2 SELECT 2000 + i, i, to_char(i, 'FM0000') FROM generate_series(0, 999, 5) i;
ANALYZE async_pt;

-- simple queries
CREATE TABLE result_tbl (a int, b int, c text);

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO result_tbl SELECT * FROM async_pt WHERE b % 100 = 0;
INSERT INTO result_tbl SELECT * FROM async_pt WHERE b % 100 = 0;

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;
INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO result_tbl SELECT a, b, 'AAA' || c FROM async_pt WHERE b === 505;
INSERT INTO result_tbl SELECT a, b, 'AAA' || c FROM async_pt WHERE b === 505;

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

-- Check case where multiple partitions use the same connection
CREATE TABLE base_tbl3 (a int, b int, c text);
CREATE FOREIGN TABLE async_p3 PARTITION OF async_pt FOR VALUES FROM (3000) TO (4000)
  SERVER loopback2 OPTIONS (table_name 'base_tbl3');
INSERT INTO async_p3 SELECT 3000 + i, i, to_char(i, 'FM0000') FROM generate_series(0, 999, 5) i;
ANALYZE async_pt;

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;
INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

DROP FOREIGN TABLE async_p3;
DROP TABLE base_tbl3;

-- Check case where the partitioned table has local/remote partitions
CREATE TABLE async_p3 PARTITION OF async_pt FOR VALUES FROM (3000) TO (4000);
INSERT INTO async_p3 SELECT 3000 + i, i, to_char(i, 'FM0000') FROM generate_series(0, 999, 5) i;
ANALYZE async_pt;

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;
INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

-- partitionwise joins
SET enable_partitionwise_join TO true;

CREATE TABLE join_tbl (a1 int, b1 int, c1 text, a2 int, b2 int, c2 text);

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO join_tbl SELECT * FROM async_pt t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;
INSERT INTO join_tbl SELECT * FROM async_pt t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;

SELECT * FROM join_tbl ORDER BY a1;
DELETE FROM join_tbl;

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO join_tbl SELECT t1.a, t1.b, 'AAA' || t1.c, t2.a, t2.b, 'AAA' || t2.c FROM async_pt t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;
INSERT INTO join_tbl SELECT t1.a, t1.b, 'AAA' || t1.c, t2.a, t2.b, 'AAA' || t2.c FROM async_pt t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;

SELECT * FROM join_tbl ORDER BY a1;
DELETE FROM join_tbl;

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO join_tbl SELECT t1.a, t1.b, 'AAA' || t1.c, t2.a, t2.b, 'AAA' || t2.c FROM async_pt t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;
INSERT INTO join_tbl SELECT t1.a, t1.b, 'AAA' || t1.c, t2.a, t2.b, 'AAA' || t2.c FROM async_pt t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;

SELECT * FROM join_tbl ORDER BY a1;
DELETE FROM join_tbl;

RESET enable_partitionwise_join;

-- Test rescan of an async Append node with do_exec_prune=false
SET enable_hashjoin TO false;

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO join_tbl SELECT * FROM async_p1 t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;
INSERT INTO join_tbl SELECT * FROM async_p1 t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;

SELECT * FROM join_tbl ORDER BY a1;
DELETE FROM join_tbl;

RESET enable_hashjoin;

-- Test interaction of async execution with plan-time partition pruning
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM async_pt WHERE a < 3000;

EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM async_pt WHERE a < 2000;

-- Test interaction of async execution with run-time partition pruning
SET plan_cache_mode TO force_generic_plan;

PREPARE async_pt_query (int, int) AS
  INSERT INTO result_tbl SELECT * FROM async_pt WHERE a < $1 AND b === $2;

EXPLAIN (VERBOSE, COSTS OFF)
EXECUTE async_pt_query (3000, 505);
EXECUTE async_pt_query (3000, 505);

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

EXPLAIN (VERBOSE, COSTS OFF)
EXECUTE async_pt_query (2000, 505);
EXECUTE async_pt_query (2000, 505);

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

RESET plan_cache_mode;

CREATE TABLE local_tbl(a int, b int, c text);
INSERT INTO local_tbl VALUES (1505, 505, 'foo'), (2505, 505, 'bar');
ANALYZE local_tbl;

CREATE INDEX base_tbl1_idx ON base_tbl1 (a);
CREATE INDEX base_tbl2_idx ON base_tbl2 (a);
CREATE INDEX async_p3_idx ON async_p3 (a);
ANALYZE base_tbl1;
ANALYZE base_tbl2;
ANALYZE async_p3;

ALTER FOREIGN TABLE async_p1 OPTIONS (use_remote_estimate 'true');
ALTER FOREIGN TABLE async_p2 OPTIONS (use_remote_estimate 'true');

EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM local_tbl, async_pt WHERE local_tbl.a = async_pt.a AND local_tbl.c = 'bar';
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY OFF, TIMING OFF)
SELECT * FROM local_tbl, async_pt WHERE local_tbl.a = async_pt.a AND local_tbl.c = 'bar';
SELECT * FROM local_tbl, async_pt WHERE local_tbl.a = async_pt.a AND local_tbl.c = 'bar';

ALTER FOREIGN TABLE async_p1 OPTIONS (DROP use_remote_estimate);
ALTER FOREIGN TABLE async_p2 OPTIONS (DROP use_remote_estimate);

DROP TABLE local_tbl;
DROP INDEX base_tbl1_idx;
DROP INDEX base_tbl2_idx;
DROP INDEX async_p3_idx;

-- UNION queries
EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO result_tbl
(SELECT a, b, 'AAA' || c FROM async_p1 ORDER BY a LIMIT 10)
UNION
(SELECT a, b, 'AAA' || c FROM async_p2 WHERE b < 10);
INSERT INTO result_tbl
(SELECT a, b, 'AAA' || c FROM async_p1 ORDER BY a LIMIT 10)
UNION
(SELECT a, b, 'AAA' || c FROM async_p2 WHERE b < 10);

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO result_tbl
(SELECT a, b, 'AAA' || c FROM async_p1 ORDER BY a LIMIT 10)
UNION ALL
(SELECT a, b, 'AAA' || c FROM async_p2 WHERE b < 10);
INSERT INTO result_tbl
(SELECT a, b, 'AAA' || c FROM async_p1 ORDER BY a LIMIT 10)
UNION ALL
(SELECT a, b, 'AAA' || c FROM async_p2 WHERE b < 10);

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

-- Disable async execution if we use gating Result nodes for pseudoconstant
-- quals
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM async_pt WHERE CURRENT_USER = SESSION_USER;

EXPLAIN (VERBOSE, COSTS OFF)
(SELECT * FROM async_p1 WHERE CURRENT_USER = SESSION_USER)
UNION ALL
(SELECT * FROM async_p2 WHERE CURRENT_USER = SESSION_USER);

EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ((SELECT * FROM async_p1 WHERE b < 10) UNION ALL (SELECT * FROM async_p2 WHERE b < 10)) s WHERE CURRENT_USER = SESSION_USER;

-- Test that pending requests are processed properly
SET enable_mergejoin TO false;
SET enable_hashjoin TO false;

EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM async_pt t1, async_p2 t2 WHERE t1.a = t2.a AND t1.b === 505;
SELECT * FROM async_pt t1, async_p2 t2 WHERE t1.a = t2.a AND t1.b === 505;

CREATE TABLE local_tbl (a int, b int, c text);
INSERT INTO local_tbl VALUES (1505, 505, 'foo');
ANALYZE local_tbl;

EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM local_tbl t1 LEFT JOIN (SELECT *, (SELECT count(*) FROM async_pt WHERE a < 3000) FROM async_pt WHERE a < 3000) t2 ON t1.a = t2.a;
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY OFF, TIMING OFF)
SELECT * FROM local_tbl t1 LEFT JOIN (SELECT *, (SELECT count(*) FROM async_pt WHERE a < 3000) FROM async_pt WHERE a < 3000) t2 ON t1.a = t2.a;
SELECT * FROM local_tbl t1 LEFT JOIN (SELECT *, (SELECT count(*) FROM async_pt WHERE a < 3000) FROM async_pt WHERE a < 3000) t2 ON t1.a = t2.a;

EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM async_pt t1 WHERE t1.b === 505 LIMIT 1;
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY OFF, TIMING OFF)
SELECT * FROM async_pt t1 WHERE t1.b === 505 LIMIT 1;
SELECT * FROM async_pt t1 WHERE t1.b === 505 LIMIT 1;

-- Check with foreign modify
CREATE TABLE base_tbl3 (a int, b int, c text);
CREATE FOREIGN TABLE remote_tbl (a int, b int, c text)
  SERVER loopback OPTIONS (table_name 'base_tbl3');
INSERT INTO remote_tbl VALUES (2505, 505, 'bar');

CREATE TABLE base_tbl4 (a int, b int, c text);
CREATE FOREIGN TABLE insert_tbl (a int, b int, c text)
  SERVER loopback OPTIONS (table_name 'base_tbl4');

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO insert_tbl (SELECT * FROM local_tbl UNION ALL SELECT * FROM remote_tbl);
INSERT INTO insert_tbl (SELECT * FROM local_tbl UNION ALL SELECT * FROM remote_tbl);

SELECT * FROM insert_tbl ORDER BY a;

-- Check with direct modify
EXPLAIN (VERBOSE, COSTS OFF)
WITH t AS (UPDATE remote_tbl SET c = c || c RETURNING *)
INSERT INTO join_tbl SELECT * FROM async_pt LEFT JOIN t ON (async_pt.a = t.a AND async_pt.b = t.b) WHERE async_pt.b === 505;
WITH t AS (UPDATE remote_tbl SET c = c || c RETURNING *)
INSERT INTO join_tbl SELECT * FROM async_pt LEFT JOIN t ON (async_pt.a = t.a AND async_pt.b = t.b) WHERE async_pt.b === 505;

SELECT * FROM join_tbl ORDER BY a1;
DELETE FROM join_tbl;

DROP TABLE local_tbl;
DROP FOREIGN TABLE remote_tbl;
DROP FOREIGN TABLE insert_tbl;
DROP TABLE base_tbl3;
DROP TABLE base_tbl4;

RESET enable_mergejoin;
RESET enable_hashjoin;

-- Test that UPDATE/DELETE with inherited target works with async_capable enabled
EXPLAIN (VERBOSE, COSTS OFF)
UPDATE async_pt SET c = c || c WHERE b = 0 RETURNING *;
UPDATE async_pt SET c = c || c WHERE b = 0 RETURNING *;
EXPLAIN (VERBOSE, COSTS OFF)
DELETE FROM async_pt WHERE b = 0 RETURNING *;
DELETE FROM async_pt WHERE b = 0 RETURNING *;

-- Check EXPLAIN ANALYZE for a query that scans empty partitions asynchronously
DELETE FROM async_p1;
DELETE FROM async_p2;
DELETE FROM async_p3;

EXPLAIN (ANALYZE, COSTS OFF, SUMMARY OFF, TIMING OFF)
SELECT * FROM async_pt;

-- Clean up
DROP TABLE async_pt;
DROP TABLE base_tbl1;
DROP TABLE base_tbl2;
DROP TABLE result_tbl;
DROP TABLE join_tbl;

-- Test that an asynchronous fetch is processed before restarting the scan in
-- ReScanForeignScan
CREATE TABLE base_tbl (a int, b int);
INSERT INTO base_tbl VALUES (1, 11), (2, 22), (3, 33);
CREATE FOREIGN TABLE foreign_tbl (b int)
  SERVER loopback OPTIONS (table_name 'base_tbl');
CREATE FOREIGN TABLE foreign_tbl2 () INHERITS (foreign_tbl)
  SERVER loopback OPTIONS (table_name 'base_tbl');

EXPLAIN (VERBOSE, COSTS OFF)
SELECT a FROM base_tbl WHERE a IN (SELECT a FROM foreign_tbl);
SELECT a FROM base_tbl WHERE a IN (SELECT a FROM foreign_tbl);

-- Clean up
DROP FOREIGN TABLE foreign_tbl CASCADE;
DROP TABLE base_tbl;

ALTER SERVER loopback OPTIONS (DROP async_capable);
ALTER SERVER loopback2 OPTIONS (DROP async_capable);

-- ===================================================================
-- test invalid server, foreign table and foreign data wrapper options
-- ===================================================================
-- Invalid fdw_startup_cost option
CREATE SERVER inv_scst FOREIGN DATA WRAPPER postgres_fdw
	OPTIONS(fdw_startup_cost '100$%$#$#');
-- Invalid fdw_tuple_cost option
CREATE SERVER inv_scst FOREIGN DATA WRAPPER postgres_fdw
	OPTIONS(fdw_tuple_cost '100$%$#$#');
-- Invalid fetch_size option
CREATE FOREIGN TABLE inv_fsz (c1 int )
	SERVER loopback OPTIONS (fetch_size '100$%$#$#');
-- Invalid batch_size option
CREATE FOREIGN TABLE inv_bsz (c1 int )
	SERVER loopback OPTIONS (batch_size '100$%$#$#');
*/

-- No option is allowed to be specified at foreign data wrapper level
--Testcase 876:
ALTER FOREIGN DATA WRAPPER :DB_EXTENSIONNAME OPTIONS (nonexistent 'fdw');

-- -- ===================================================================
-- -- test postgres_fdw.application_name GUC
-- -- ===================================================================
-- --- Turn debug_discard_caches off for this test to make sure that
-- --- the remote connection is alive when checking its application_name.
-- SET debug_discard_caches = 0;

-- -- Specify escape sequences in application_name option of a server
-- -- object so as to test that they are replaced with status information
-- -- expectedly.
-- --
-- -- Since pg_stat_activity.application_name may be truncated to less than
-- -- NAMEDATALEN characters, note that substring() needs to be used
-- -- at the condition of test query to make sure that the string consisting
-- -- of database name and process ID is also less than that.
-- ALTER SERVER loopback2 OPTIONS (application_name 'fdw_%d%p');
-- SELECT 1 FROM ft6 LIMIT 1;
-- SELECT pg_terminate_backend(pid, 180000) FROM pg_stat_activity
--   WHERE application_name =
--     substring('fdw_' || current_database() || pg_backend_pid() for
--       current_setting('max_identifier_length')::int);

-- -- postgres_fdw.application_name overrides application_name option
-- -- of a server object if both settings are present.
-- SET postgres_fdw.application_name TO 'fdw_%a%u%%';
-- SELECT 1 FROM ft6 LIMIT 1;
-- SELECT pg_terminate_backend(pid, 180000) FROM pg_stat_activity
--   WHERE application_name =
--     substring('fdw_' || current_setting('application_name') ||
--       CURRENT_USER || '%' for current_setting('max_identifier_length')::int);

-- -- Test %c (session ID) and %C (cluster name) escape sequences.
-- SET postgres_fdw.application_name TO 'fdw_%C%c';
-- SELECT 1 FROM ft6 LIMIT 1;
-- SELECT pg_terminate_backend(pid, 180000) FROM pg_stat_activity
--   WHERE application_name =
--     substring('fdw_' || current_setting('cluster_name') ||
--       to_hex(trunc(EXTRACT(EPOCH FROM (SELECT backend_start FROM
--       pg_stat_get_activity(pg_backend_pid()))))::integer) || '.' ||
--       to_hex(pg_backend_pid())
--       for current_setting('max_identifier_length')::int);

-- --Clean up
-- RESET postgres_fdw.application_name;
-- RESET debug_discard_caches;

-- -- ===================================================================
-- -- test parallel commit
-- -- ===================================================================
-- ALTER SERVER loopback OPTIONS (ADD parallel_commit 'true');
-- ALTER SERVER loopback2 OPTIONS (ADD parallel_commit 'true');

-- CREATE TABLE ploc1 (f1 int, f2 text);
-- CREATE FOREIGN TABLE prem1 (f1 int, f2 text)
--   SERVER loopback OPTIONS (table_name 'ploc1');
-- CREATE TABLE ploc2 (f1 int, f2 text);
-- CREATE FOREIGN TABLE prem2 (f1 int, f2 text)
--   SERVER loopback2 OPTIONS (table_name 'ploc2');

-- BEGIN;
-- INSERT INTO prem1 VALUES (101, 'foo');
-- INSERT INTO prem2 VALUES (201, 'bar');
-- COMMIT;
-- SELECT * FROM prem1;
-- SELECT * FROM prem2;

-- BEGIN;
-- SAVEPOINT s;
-- INSERT INTO prem1 VALUES (102, 'foofoo');
-- INSERT INTO prem2 VALUES (202, 'barbar');
-- RELEASE SAVEPOINT s;
-- COMMIT;
-- SELECT * FROM prem1;
-- SELECT * FROM prem2;

-- -- This tests executing DEALLOCATE ALL against foreign servers in parallel
-- -- during pre-commit
-- BEGIN;
-- SAVEPOINT s;
-- INSERT INTO prem1 VALUES (103, 'baz');
-- INSERT INTO prem2 VALUES (203, 'qux');
-- ROLLBACK TO SAVEPOINT s;
-- RELEASE SAVEPOINT s;
-- INSERT INTO prem1 VALUES (104, 'bazbaz');
-- INSERT INTO prem2 VALUES (204, 'quxqux');
-- COMMIT;
-- SELECT * FROM prem1;
-- SELECT * FROM prem2;

-- ALTER SERVER loopback OPTIONS (DROP parallel_commit);
-- ALTER SERVER loopback2 OPTIONS (DROP parallel_commit);

--Testcase 838:
DROP TYPE user_enum CASCADE;
--Testcase 839:
DROP SCHEMA "S 1" CASCADE;
--Testcase 840:
DROP TABLE loct3 CASCADE;
--Testcase 841:
DROP TYPE typ1 CASCADE;
--Testcase 842:
DROP SCHEMA import_dest1 CASCADE;
--Testcase 843:
DROP SCHEMA import_dest2 CASCADE;
--Testcase 844:
DROP SCHEMA import_dest3 CASCADE;
--Testcase 845:
DROP SCHEMA import_dest4 CASCADE;
--Testcase 846:
DROP SCHEMA import_dest5 CASCADE;
--Testcase 847:
DROP TABLE fprt1 CASCADE;
--Testcase 848:
DROP TABLE fprt2 CASCADE;
--Testcase 849:
DROP TABLE pagg_tab CASCADE;
--Testcase 850:
DROP FUNCTION row_before_insupd_trigfunc CASCADE;
--Testcase 851:
DROP FUNCTION trigger_func CASCADE;
--Testcase 852:
DROP FUNCTION trig_row_before_insupdate CASCADE;
--Testcase 853:
DROP FUNCTION trig_null CASCADE;
--Testcase 823:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 824:
DROP SERVER :DB_SERVERNAME2 CASCADE;
--Testcase 825:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
