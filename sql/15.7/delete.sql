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
CREATE FOREIGN TABLE delete_test (
    id serial OPTIONS (key 'true'),
    a INT,
    b text
) SERVER :DB_SERVERNAME OPTIONS ( table_name 'delete_test');

INSERT INTO delete_test (a) VALUES (10);
INSERT INTO delete_test (a, b) VALUES (50, repeat('x', 10000));
INSERT INTO delete_test (a) VALUES (100);

-- allow an alias to be specified for DELETE's target table
--Testcase 5:
EXPLAIN VERBOSE DELETE FROM delete_test AS dt WHERE dt.a > 75;
--Testcase 6:
DELETE FROM delete_test AS dt WHERE dt.a > 75;

-- if an alias is specified, don't allow the original table name
-- to be referenced
--Testcase 7:
EXPLAIN VERBOSE DELETE FROM delete_test dt WHERE delete_test.a > 25;
--Testcase 8:
DELETE FROM delete_test dt WHERE delete_test.a > 25;

--Testcase 10:
SELECT id, a, char_length(b) FROM delete_test;

-- delete a row with a TOASTed value
--Testcase 11:
EXPLAIN VERBOSE DELETE FROM delete_test WHERE a > 25;
--Testcase 12:
DELETE FROM delete_test WHERE a > 25;
--Testcase 13:
SELECT id, a, char_length(b) FROM delete_test;

--Testcase 15:
DROP FOREIGN TABLE delete_test;
--Testcase 16:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 17:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
