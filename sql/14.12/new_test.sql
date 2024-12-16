--
-- TIMESTAMP
--
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

--Primary key options
--Testcase 4:
CREATE FOREIGN TABLE tbl01 (id bigint  OPTIONS (key 'true'), c1 int) SERVER :DB_SERVERNAME OPTIONS ( table_name 'tbl01');
--Testcase 5:
EXPLAIN VERBOSE
INSERT INTO tbl01 VALUES (166565, 1);
--Testcase 6:
INSERT INTO tbl01 VALUES (166565, 1);
--Testcase 7:
EXPLAIN VERBOSE
INSERT INTO tbl01 (c1) VALUES (3);
--Testcase 8:
INSERT INTO tbl01 (c1) VALUES (3);
--Testcase 9:
EXPLAIN VERBOSE
INSERT INTO tbl01 VALUES (null, 4);
--Testcase 10:
INSERT INTO tbl01 VALUES (null, 4);
--Testcase 11:
EXPLAIN VERBOSE
INSERT INTO tbl01 VALUES (166565, 7);
--Testcase 12:
INSERT INTO tbl01 VALUES (166565, 7);
--Testcase 13:
CREATE FOREIGN TABLE tbl02 (id char(255)  OPTIONS (key 'true'), c1 INT, c2 float8, c3 boolean) SERVER :DB_SERVERNAME OPTIONS ( table_name 'tbl02');
--Testcase 14:
EXPLAIN VERBOSE
INSERT INTO tbl02 VALUES (repeat('a', 255), 1, 12112.12, true);
--Testcase 15:
INSERT INTO tbl02 VALUES (repeat('a', 255), 1, 12112.12, true);
--Testcase 16:
EXPLAIN VERBOSE
INSERT INTO tbl02 VALUES (NULL, 2, -12.23, false);
--Testcase 17:
INSERT INTO tbl02 VALUES (NULL, 2, -12.23, false);
--Testcase 18:
EXPLAIN VERBOSE
INSERT INTO tbl02(c1) VALUES (3);
--Testcase 19:
INSERT INTO tbl02(c1) VALUES (3);
--Testcase 20:
ALTER FOREIGN TABLE tbl02 ALTER COLUMN c2 SET NOT NULL;
--Testcase 21:
EXPLAIN VERBOSE
SELECT * FROM tbl02;
--Testcase 22:
SELECT * FROM tbl02;
--Testcase 23:
ALTER FOREIGN TABLE tbl02 ALTER c2 OPTIONS (key 'true');
--Testcase 24:
EXPLAIN VERBOSE
SELECT * FROM tbl02;
--Testcase 25:
SELECT * FROM tbl02;
--Testcase 26:
ALTER FOREIGN TABLE tbl02 ALTER c2 OPTIONS (SET key 'false');
--Testcase 27:
EXPLAIN VERBOSE
SELECT * FROM tbl02;
--Testcase 28:
SELECT * FROM tbl02;
--Testcase 29:
ALTER FOREIGN TABLE tbl02 ALTER c3 OPTIONS (key 'true');
--Testcase 30:
EXPLAIN VERBOSE
SELECT * FROM tbl02;
--Testcase 31:
SELECT * FROM tbl02;
--Testcase 32:
CREATE FOREIGN TABLE tbl03 (id timestamp  OPTIONS (key 'true'), c1 int) SERVER :DB_SERVERNAME OPTIONS ( table_name 'tbl03');
--Testcase 33:
EXPLAIN VERBOSE
INSERT INTO tbl03 VALUES ('2000-01-01 00:00:00', 0);
--Testcase 34:
INSERT INTO tbl03 VALUES ('2000-01-01 00:00:00', 0);
--Testcase 35:
EXPLAIN VERBOSE
INSERT INTO tbl03 VALUES ('2000-01-01 00:00:00', 1);
--Testcase 36:
INSERT INTO tbl03 VALUES ('2000-01-01 00:00:00', 1);
--WHERE clause push-down with functions in WHERE
--Testcase 37:
CREATE FOREIGN TABLE tbl04 (id INT  OPTIONS (key 'true'),  c1 float8, c2 bigint, c3 text, c4 boolean, c5 timestamp) SERVER :DB_SERVERNAME OPTIONS ( table_name 'tbl04');
--Testcase 38:
EXPLAIN VERBOSE
SELECT * FROM tbl04 WHERE abs(c1) > 3233;
--Testcase 39:
SELECT * FROM tbl04 WHERE abs(c1) > 3233;
--Testcase 40:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE sqrt(c2) > sqrt(c1) AND c1 >= 0 AND c2 > 0;
--Testcase 41:
SELECT id, c1, c2 FROM tbl04 WHERE sqrt(c2) > sqrt(c1) AND c1 >= 0 AND c2 > 0;
--Testcase 42:
EXPLAIN VERBOSE
SELECT c1, c2 FROM tbl04 WHERE c3 || c3 != 'things thing';
--Testcase 43:
SELECT c1, c2 FROM tbl04 WHERE c3 || c3 != 'things thing';
--Testcase 44:
EXPLAIN VERBOSE
SELECT c1, id, c3 || c3 FROM tbl04 WHERE abs(c2) <> abs(c1);
--Testcase 45:
SELECT c1, id, c3 || c3 FROM tbl04 WHERE abs(c2) <> abs(c1);
--Testcase 46:
EXPLAIN VERBOSE
SELECT id + id, c2, c3 || 'afas' FROM tbl04 WHERE floor(c2) > 0;
--Testcase 47:
SELECT id + id, c2, c3 || 'afas' FROM tbl04 WHERE floor(c2) > 0;
--Testcase 48:
EXPLAIN VERBOSE
SELECT c2, c3, c4, c5 FROM tbl04 WHERE c5 > '2000-01-01';
--Testcase 49:
SELECT c2, c3, c4, c5 FROM tbl04 WHERE c5 > '2000-01-01';
--Testcase 50:
EXPLAIN VERBOSE
SELECT c5, c4, c2 FROM tbl04 WHERE c5 IN ('2000-01-01', '2010-11-01 00:00:00');
--Testcase 51:
SELECT c5, c4, c2 FROM tbl04 WHERE c5 IN ('2000-01-01', '2010-11-01 00:00:00');
--Testcase 52:
EXPLAIN VERBOSE
SELECT c3, c5, c1 FROM tbl04 WHERE c1 > ALL(SELECT id FROM tbl04 WHERE c4 = true);
--Testcase 53:
SELECT c3, c5, c1 FROM tbl04 WHERE c1 > ALL(SELECT id FROM tbl04 WHERE c4 = true);
--Testcase 54:
EXPLAIN VERBOSE
SELECT c1, c5, c3, c2 FROM tbl04 WHERE c1 = ANY (SELECT c1 FROM tbl04 WHERE c4 != false) AND c1 > 0 OR c2 < 0;
--Testcase 55:
SELECT c1, c5, c3, c2 FROM tbl04 WHERE c1 = ANY (SELECT c1 FROM tbl04 WHERE c4 != false) AND c1 > 0 OR c2 < 0;
--aggregation function push-down: add variance
--Testcase 56:
EXPLAIN VERBOSE
SELECT variance(c1), variance(c2) FROM tbl04;
--Testcase 57:
SELECT variance(c1), variance(c2) FROM tbl04;
--Testcase 58:
EXPLAIN VERBOSE
SELECT variance(c1) FROM tbl04 WHERE c3 <> 'aef';
--Testcase 59:
SELECT variance(c1) FROM tbl04 WHERE c3 <> 'aef';
--Testcase 60:
EXPLAIN VERBOSE
SELECT max(id), min(c1), variance(c2) FROM tbl04;
--Testcase 61:
SELECT max(id), min(c1), variance(c2) FROM tbl04;
--Testcase 62:
EXPLAIN VERBOSE
SELECT variance(c2), variance(c1) FROM tbl04;
--Testcase 63:
SELECT variance(c2), variance(c1) FROM tbl04;
--Testcase 64:
EXPLAIN VERBOSE
SELECT sum(c1), variance(c1) FROM tbl04 WHERE id <= 10;
--Testcase 65:
SELECT sum(c1), variance(c1) FROM tbl04 WHERE id <= 10;

----aggregation function push-down: count(var)
--Testcase 83:
EXPLAIN VERBOSE
SELECT count(c1), sum(c2), variance(c2) FROM tbl04;
--Testcase 84:
SELECT count(c1), sum(c2), variance(c2) FROM tbl04;

----aggregation function push-down: count(*)
--Testcase 85:
EXPLAIN VERBOSE
SELECT count(*) FROM tbl04;
--Testcase 86:
SELECT count(*) FROM tbl04;

--aggregation function push-down: having
--Testcase 66:
EXPLAIN VERBOSE
SELECT count(c1), sum(c2), variance(c2) FROM tbl04 HAVING (count(c1) > 0);
--Testcase 67:
SELECT count(c1), sum(c2), variance(c2) FROM tbl04 HAVING (count(c1) > 0);
--Testcase 68:
EXPLAIN VERBOSE
SELECT count(c1) + sum (c2), variance(c2)/2.12 FROM tbl04 HAVING count(c4) != 0 AND variance(c2) > 55.54;
--Testcase 69:
SELECT count(c1) + sum (c2), variance(c2)/2.12 FROM tbl04 HAVING count(c4) != 0 AND variance(c2) > 55.54;

--aggregation function push-down: non push-down case
--Testcase 95:
EXPLAIN VERBOSE
SELECT bit_and(id) FROM tbl04;
--Testcase 96:
SELECT bit_and(id) FROM tbl04;

--Testcase 97:
EXPLAIN VERBOSE
SELECT bit_or(id) FROM tbl04;
--Testcase 98:
SELECT bit_or(id) FROM tbl04;

--Testcase 99:
EXPLAIN VERBOSE
SELECT corr(id, c1) FROM tbl04;
--Testcase 100:
SELECT corr(id, c1) FROM tbl04;

--Test Long Varbinary type (Mysql)
--Testcase 72:
CREATE FOREIGN TABLE tbl05 (id INT  OPTIONS (key 'true'),  v BYTEA) SERVER :DB_SERVERNAME OPTIONS ( table_name 'tbl05');
--Testcase 73:
INSERT INTO tbl05 (id, v) VALUES (1, decode('ff','hex'));
--Testcase 74:
EXPLAIN VERBOSE SELECT string_agg(v, '') FROM tbl05;
--Testcase 75:
SELECT string_agg(v, '') FROM tbl05;

-- The floating-point types are float and double, which are conceptually associated with the single-precision 32-bit 
-- and double-precision 64-bit format IEEE 754 values and operations as specified in IEEE Standard for Binary Floating-Point Arithmetic.
-- A floating-point value as written in an SQL statement may not be the same as the value represented internally. 
-- With limitation about floating-point value, in order to get correct result, can decide on an acceptable tolerance 
-- for differences between the numbers and then do the comparison against the tolerance value.
--Testcase 76:
CREATE FOREIGN TABLE tbl06(id serial OPTIONS (key 'true'), f1 float4) SERVER :DB_SERVERNAME OPTIONS (table_name 'float4_tbl');
--Testcase 77:
INSERT INTO tbl06(f1) VALUES ('    0.0');
--Testcase 78:
INSERT INTO tbl06(f1) VALUES ('1004.30   ');
--Testcase 79:
INSERT INTO tbl06(f1) VALUES ('     -34.84    ');
--Testcase 80:
INSERT INTO tbl06(f1) VALUES ('1.2345678901234e+20');
--Testcase 81:
INSERT INTO tbl06(f1) VALUES ('1.2345678901234e-20');
--Testcase 82:
SELECT '' AS four, f.f1 FROM tbl06 f WHERE f.f1 <> '1004.3' GROUP BY f.id, f.f1 HAVING abs(f1 - 1004.3) > 0.001 ORDER BY f.id;

--Testcase 87:
CREATE FOREIGN TABLE test_explicit_cast (id serial OPTIONS (key 'true'), c1 text) SERVER :DB_SERVERNAME OPTIONS ( table_name 'test_explicit_cast');
--Testcase 88:
INSERT INTO test_explicit_cast(c1) VALUES ('1'), ('1.5'), ('1.6');
-- jdbc_fdw does not support push-down aggregate function if it has explicit cast inside
--Testcase 89:
EXPLAIN VERBOSE
SELECT var_samp(c1::numeric) FROM test_explicit_cast; -- Does not push down
--Testcase 90:
SELECT var_samp(c1::numeric) FROM test_explicit_cast; -- Does not push down
--Testcase 92:
EXPLAIN VERBOSE
SELECT sum(c1::float8) FROM test_explicit_cast; -- Does not push down
--Testcase 93:
SELECT sum(c1::float8) FROM test_explicit_cast; -- Does not push down
--Testcase 94:
SELECT * FROM public.jdbc_fdw_version();
--Testcase 95:
SELECT jdbc_fdw_version();

--Testcase 70:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 71:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
