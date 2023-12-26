--Testcase 1:
CREATE EXTENSION :DB_EXTENSIONNAME;
--Testcase 2:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
OPTIONS (drivername :DB_DRIVERNAME,
url :DB_URL,
querytimeout '15',
jarfile :DB_DRIVERPATH,
maxheapsize '600');
--Testcase 3:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS (username :DB_USER,password :DB_PASS);

-- ===================================================================
-- Select without condition clause, without alias
-- ===================================================================
-- select all
--Testcase 5:
EXPLAIN VERBOSE
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06');
--Testcase 6:
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06');

-- select column
--Testcase 7:
EXPLAIN VERBOSE
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT id, c1, c2, c3 FROM tbl06');
--Testcase 8:
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT id, c1, c2, c3 FROM tbl06');
-- aggregate function
--Testcase 9:
EXPLAIN VERBOSE
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT avg(c1) FROM tbl06');
--Testcase 10:
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT avg(c1) FROM tbl06');
--Testcase 11:
EXPLAIN VERBOSE
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT sum(c1) FROM tbl06');
--Testcase 12:
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT sum(c1) FROM tbl06');
--Testcase 13:
EXPLAIN VERBOSE
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT max(c1) FROM tbl06');
--Testcase 14:
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT max(c1) FROM tbl06');

-- ===================================================================
-- Select without condition clause, with alias
-- ===================================================================
-- select all
--Testcase 15:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz);
--Testcase 16:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz);
-- select column
--Testcase 17:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT id, c1, c2, c3 FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text);
--Testcase 18:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT id, c1, c2, c3 FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text);
-- aggregate function
--Testcase 19:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT avg(c1) FROM tbl06') as t(result double precision);
--Testcase 20:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT avg(c1) FROM tbl06') as t(result double precision);
--Testcase 21:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT sum(c1) FROM tbl06') as t(result double precision);
--Testcase 22:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT sum(c1) FROM tbl06') as t(result double precision);
--Testcase 23:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT max(c1) FROM tbl06') as t(result double precision);
--Testcase 24:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT max(c1) FROM tbl06') as t(result double precision);
--Testcase 25:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT avg(c1), sum(c1), max(c1) FROM tbl06') as t(avg_result double precision, sum_result double precision, max_result double precision);
--Testcase 26:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT avg(c1), sum(c1), max(c1) FROM tbl06') as t(avg_result double precision, sum_result double precision, max_result double precision);

-- ===================================================================
-- Select with condition clause, without alias
-- ===================================================================
-- select with limit
--Testcase 27:
EXPLAIN VERBOSE
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 LIMIT 5');
--Testcase 28:
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 LIMIT 5');
--Testcase 29:
EXPLAIN VERBOSE
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT id, c1, c2, c3 FROM tbl06 LIMIT 5');
--Testcase 30:
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT id, c1, c2, c3 FROM tbl06 LIMIT 5');
-- where clause
--Testcase 31:
EXPLAIN VERBOSE
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 WHERE id < 7');
--Testcase 32:
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 WHERE id < 7');

--Testcase 71:
EXPLAIN VERBOSE
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 WHERE id < 7 AND c4 = TRUE');

--Testcase 72:
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 WHERE id < 7 AND c4 = TRUE');

--Testcase 73:
EXPLAIN VERBOSE
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 WHERE id < 7 AND (c1 < 0 OR c1 > 1000)');

--Testcase 74:
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 WHERE id < 7 AND (c1 < 0 OR c1 > 1000)');

--Testcase 75:
EXPLAIN VERBOSE
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT COUNT(id), c3 FROM tbl06 GROUP BY c3 HAVING COUNT(id) > 1');

--Testcase 76:
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT COUNT(id), c3 FROM tbl06 GROUP BY c3 HAVING COUNT(id) > 1');

-- order by
--Testcase 33:
EXPLAIN VERBOSE
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 ORDER BY id');
--Testcase 34:
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 ORDER BY id');
--Testcase 35:
EXPLAIN VERBOSE
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 ORDER BY id DESC');
--Testcase 36:
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 ORDER BY id DESC');

-- ===================================================================
-- Select with condition clause, with alias
-- ===================================================================
-- select with limit
--Testcase 37:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 LIMIT 5') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz);
--Testcase 38:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 LIMIT 5') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz);
--Testcase 39:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz) LIMIT 5;
--Testcase 40:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz) LIMIT 5;
--Testcase 41:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT id, c1, c2, c3 FROM tbl06 LIMIT 5') as t(id int, c1 double precision, c2 bigint, c3 text);
--Testcase 42:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT id, c1, c2, c3 FROM tbl06 LIMIT 5') as t(id int, c1 double precision, c2 bigint, c3 text);
--Testcase 43:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT id, c1, c2, c3 FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text) LIMIT 5;
--Testcase 44:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT id, c1, c2, c3 FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text) LIMIT 5;
-- where clause
--Testcase 45:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 WHERE id < 7') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz);
--Testcase 46:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 WHERE id < 7') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz);
--Testcase 47:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz) WHERE id < 7;
--Testcase 48:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz) WHERE id < 7;

--Testcase 77:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 WHERE id < 7 AND c4 = TRUE') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz);

--Testcase 78:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 WHERE id < 7 AND c4 = TRUE') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz);

--Testcase 79:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz) WHERE id < 7 AND c4 = TRUE;

--Testcase 80:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz) WHERE id < 7 AND c4 = TRUE;

--Testcase 81:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 WHERE id < 7 AND (c1 < 0 OR c1 > 1000)') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz);

--Testcase 82:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 WHERE id < 7 AND (c1 < 0 OR c1 > 1000)') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz);

--Testcase 83:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz) WHERE id < 7 AND (c1 < 0 OR c1 > 1000);

--Testcase 84:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz) WHERE id < 7 AND (c1 < 0 OR c1 > 1000);

--Testcase 85:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT COUNT(id), c3 FROM tbl06 GROUP BY c3 HAVING COUNT(id) > 1') as t(id bigint, c3 text);

--Testcase 86:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT COUNT(id), c3 FROM tbl06 GROUP BY c3 HAVING COUNT(id) > 1') as t(id bigint, c3 text);

-- order by
--Testcase 49:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 ORDER BY id') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz);
--Testcase 50:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 ORDER BY id') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz);
--Testcase 51:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz) ORDER BY id;
--Testcase 52:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz) ORDER BY id;
--Testcase 53:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 ORDER BY id DESC') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz);
--Testcase 54:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06 ORDER BY id DESC') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz);
--Testcase 55:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz) ORDER BY id DESC;
--Testcase 56:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT * FROM tbl06') as t(id int, c1 double precision, c2 bigint, c3 text, c4 boolean, c5 timestamptz) ORDER BY id DESC;
-- aggregate function, where clause
--Testcase 57:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT avg(c1) FROM tbl06 WHERE id < 4') as t(result double precision);
--Testcase 58:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT avg(c1) FROM tbl06 WHERE id < 4') as t(result double precision);
--Testcase 59:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT sum(c1) FROM tbl06 WHERE id < 4') as t(result double precision);
--Testcase 60:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT sum(c1) FROM tbl06 WHERE id < 4') as t(result double precision);
--Testcase 61:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT max(c1) FROM tbl06 WHERE id < 4') as t(result double precision);
--Testcase 62:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT max(c1) FROM tbl06 WHERE id < 4') as t(result double precision);
--Testcase 63:
EXPLAIN VERBOSE
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT avg(c1), sum(c1), max(c1) FROM tbl06 WHERE id < 4') as t(avg_result double precision, sum_result double precision, max_result double precision);
--Testcase 64:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT avg(c1), sum(c1), max(c1) FROM tbl06 WHERE id < 4') as t(avg_result double precision, sum_result double precision, max_result double precision);

-- ===================================================================
-- Exception cases
-- ===================================================================
-- There are not enough argument
--Testcase 65:
SELECT jdbc_exec('SELECT * FROM tbl06'); -- failed

-- Server is invalid
--Testcase 66:
SELECT jdbc_exec('', 'SELECT * FROM tbl06'); -- failed

-- Wrong sql query
--Testcase 67:
SELECT jdbc_exec(:DB_EXEC_PARAM, 'wrong sql query'); -- failed, error syntax in remote server

--Testcase 87:
SELECT jdbc_exec(:DB_EXEC_PARAM, 'SELECT non_existed_column FROM tbl06'); -- failed, error syntax in remote server

--Testcase 88:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT id, c1, c2, c3 FROM tbl06') as t(id int, c1 double precision); -- failed, less column than actual result

--Testcase 89:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT id FROM tbl06') as t(id int, c1 double precision); -- failed, more column than actual result

--Testcase 90:
SELECT * FROM jdbc_exec(:DB_EXEC_PARAM, 'SELECT id, c1, c2 FROM tbl06') as t(id int, c1 double precision, c2 text); -- failed, wrong data type

--Testcase 68:
SELECT jdbc_exec(:DB_EXEC_PARAM, 'DELETE FROM tbl06'); -- failed, DELETE sql query does not produce result sets

-- Clean-up
--Testcase 69:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 70:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
