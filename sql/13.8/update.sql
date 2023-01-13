--
-- UPDATE syntax tests
--
--Testcase 1:
CREATE EXTENSION :DB_EXTENSIONNAME;
--Testcase 2:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME OPTIONS(
drivername :DB_DRIVERNAME,
url :DB_URL,
querytimeout '15',
jarfile :DB_DRIVERPATH,
maxheapsize '600'
);
--Testcase 3:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS(username :DB_USER,password :DB_PASS);

--Testcase 4:
CREATE FOREIGN TABLE update_test (
    id  serial OPTIONS (key 'true'),
	  a   INT DEFAULT 10,
    b   INT,
    c   TEXT
) SERVER :DB_SERVERNAME OPTIONS ( table_name 'update_test');

--Testcase 6:
EXPLAIN VERBOSE
INSERT INTO update_test(a, b, c) VALUES (5, 10, 'foo');
--Testcase 7:
INSERT INTO update_test(a, b, c)  VALUES (5, 10, 'foo');
--Testcase 8:
EXPLAIN VERBOSE
INSERT INTO update_test(b, a) VALUES (15, 10);
--Testcase 9:
INSERT INTO update_test(b, a) VALUES (15, 10);
--Testcase 10:
EXPLAIN VERBOSE
SELECT a, b, c FROM update_test;
--Testcase 11:
SELECT a, b, c FROM update_test;
--Testcase 12:
EXPLAIN VERBOSE
UPDATE update_test SET a = DEFAULT, b = DEFAULT;
--Testcase 13:
UPDATE update_test SET a = DEFAULT, b = DEFAULT;
--Testcase 14:
EXPLAIN VERBOSE
SELECT a, b, c FROM update_test;
--Testcase 15:
SELECT a, b, c FROM update_test;
-- aliases for the UPDATE target table
--Testcase 16:
EXPLAIN VERBOSE
UPDATE update_test AS t SET b = 10 WHERE t.a = 10;
--Testcase 17:
UPDATE update_test AS t SET b = 10 WHERE t.a = 10;
--Testcase 18:
EXPLAIN VERBOSE
SELECT a, b, c FROM update_test;
--Testcase 19:
SELECT a, b, c FROM update_test;
--Testcase 20:
EXPLAIN VERBOSE
UPDATE update_test t SET b = t.b + 10 WHERE t.a = 10;
--Testcase 21:
UPDATE update_test t SET b = t.b + 10 WHERE t.a = 10;
--Testcase 22:
EXPLAIN VERBOSE
SELECT a, b, c FROM update_test;
--Testcase 23:
SELECT a, b, c FROM update_test;
--
-- Test VALUES in FROM
--
--Testcase 24:
EXPLAIN VERBOSE
UPDATE update_test SET a=v.i FROM (VALUES(100, 20)) AS v(i, j)
  WHERE update_test.b = v.j;
--Testcase 25:
UPDATE update_test SET a=v.i FROM (VALUES(100, 20)) AS v(i, j)
  WHERE update_test.b = v.j;
--Testcase 26:
EXPLAIN VERBOSE
SELECT a, b, c FROM update_test;
--Testcase 27:
SELECT a, b, c FROM update_test;
-- fail, wrong data type:
--Testcase 28:
EXPLAIN VERBOSE
UPDATE update_test SET a = v.* FROM (VALUES(100, 20)) AS v(i, j)
  WHERE update_test.b = v.j;
--Testcase 29:
UPDATE update_test SET a = v.* FROM (VALUES(100, 20)) AS v(i, j)
  WHERE update_test.b = v.j;
--
-- Test multiple-set-clause syntax
--
--Testcase 30:
EXPLAIN VERBOSE
INSERT INTO update_test(a, b, c)  SELECT a,b+1,c FROM update_test;
--Testcase 31:
INSERT INTO update_test(a, b, c)  SELECT a,b+1,c FROM update_test;
--Testcase 32:
EXPLAIN VERBOSE
SELECT a, b, c FROM update_test;
--Testcase 33:
SELECT a, b, c FROM update_test;
--Testcase 34:
EXPLAIN VERBOSE
UPDATE update_test SET (c,b,a) = ('bugle', b+11, DEFAULT) WHERE c = 'foo';
--Testcase 35:
UPDATE update_test SET (c,b,a) = ('bugle', b+11, DEFAULT) WHERE c = 'foo';
--Testcase 36:
EXPLAIN VERBOSE
SELECT a, b, c FROM update_test;
--Testcase 37:
SELECT a, b, c FROM update_test;
--Testcase 38:
EXPLAIN VERBOSE
UPDATE update_test SET (c,b) = ('car', a+b), a = a + 1 WHERE a = 10;
--Testcase 39:
UPDATE update_test SET (c,b) = ('car', a+b), a = a + 1 WHERE a = 10;
--Testcase 40:
EXPLAIN VERBOSE
SELECT a, b, c FROM update_test;
--Testcase 41:
SELECT a, b, c FROM update_test;
-- fail, multi assignment to same column:
--Testcase 42:
EXPLAIN VERBOSE
UPDATE update_test SET (c,b) = ('car', a+b), b = a + 1 WHERE a = 10;
--Testcase 43:
UPDATE update_test SET (c,b) = ('car', a+b), b = a + 1 WHERE a = 10;
-- uncorrelated sub-select:
--Testcase 44:
EXPLAIN VERBOSE
UPDATE update_test
  SET (b,a) = (select a,b from update_test where b = 41 and c = 'car')
  WHERE a = 100 AND b = 20;
--Testcase 45:
UPDATE update_test
  SET (b,a) = (select a,b from update_test where b = 41 and c = 'car')
  WHERE a = 100 AND b = 20;
--Testcase 46:
EXPLAIN VERBOSE
SELECT a, b, c FROM update_test;
--Testcase 47:
SELECT a, b, c FROM update_test;
-- correlated sub-select:
--Testcase 48:
EXPLAIN VERBOSE
UPDATE update_test o
  SET (b,a) = (select a+1,b from update_test i
               where i.a=o.a and i.b=o.b and i.c is not distinct from o.c);
--Testcase 49:
UPDATE update_test o
  SET (b,a) = (select a+1,b from update_test i
               where i.a=o.a and i.b=o.b and i.c is not distinct from o.c);
--Testcase 50:
EXPLAIN VERBOSE
SELECT a, b, c FROM update_test;
--Testcase 51:
SELECT a, b, c FROM update_test;
-- fail, multiple rows supplied:
--Testcase 52:
EXPLAIN VERBOSE
UPDATE update_test SET (b,a) = (select a+1,b from update_test);
--Testcase 53:
UPDATE update_test SET (b,a) = (select a+1,b from update_test);
-- set to null if no rows supplied:
--Testcase 54:
EXPLAIN VERBOSE
UPDATE update_test SET (b,a) = (select a+1,b from update_test where a = 1000)
  WHERE a = 11;
--Testcase 55:
UPDATE update_test SET (b,a) = (select a+1,b from update_test where a = 1000)
  WHERE a = 11;
--Testcase 56:
EXPLAIN VERBOSE
SELECT a, b, c FROM update_test;
--Testcase 57:
SELECT a, b, c FROM update_test;
-- *-expansion should work in this context:
--Testcase 58:
EXPLAIN VERBOSE
UPDATE update_test SET (a,b) = ROW(v.*) FROM (VALUES(21, 100)) AS v(i, j)
  WHERE update_test.a = v.i;
--Testcase 59:
UPDATE update_test SET (a,b) = ROW(v.*) FROM (VALUES(21, 100)) AS v(i, j)
  WHERE update_test.a = v.i;
-- you might expect this to work, but syntactically it's not a RowExpr:
--Testcase 60:
EXPLAIN VERBOSE
UPDATE update_test SET (a,b) = (v.*) FROM (VALUES(21, 101)) AS v(i, j)
  WHERE update_test.a = v.i;
--Testcase 61:
UPDATE update_test SET (a,b) = (v.*) FROM (VALUES(21, 101)) AS v(i, j)
  WHERE update_test.a = v.i;
-- if an alias for the target table is specified, don't allow references
-- to the original table name
--Testcase 62:
EXPLAIN VERBOSE
UPDATE update_test AS t SET b = update_test.b + 10 WHERE t.a = 10;
--Testcase 63:
UPDATE update_test AS t SET b = update_test.b + 10 WHERE t.a = 10;
-- Make sure that we can update to a TOASTed value.
--Testcase 64:
EXPLAIN VERBOSE
UPDATE update_test SET c = repeat('x', 10000) WHERE c = 'car';
--Testcase 65:
UPDATE update_test SET c = repeat('x', 10000) WHERE c = 'car';
--Testcase 66:
EXPLAIN VERBOSE
SELECT a, b, char_length(c) FROM update_test;
--Testcase 67:
SELECT a, b, char_length(c) FROM update_test;
-- Check multi-assignment with a Result node to handle a one-time filter.
--Testcase 68:
EXPLAIN (VERBOSE, COSTS OFF)
UPDATE update_test t
  SET (a, b) = (SELECT b, a FROM update_test s WHERE s.a = t.a)
  WHERE CURRENT_USER = SESSION_USER;
--Testcase 69:
UPDATE update_test t
  SET (a, b) = (SELECT b, a FROM update_test s WHERE s.a = t.a)
  WHERE CURRENT_USER = SESSION_USER;
--Testcase 70:
EXPLAIN VERBOSE
SELECT a, b, char_length(c) FROM update_test;
--Testcase 71:
SELECT a, b, char_length(c) FROM update_test;

--Testcase 74:
DROP FOREIGN TABLE update_test;

--Testcase 76:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 77:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
