--Testcase 83:
CREATE EXTENSION :DB_EXTENSIONNAME;
--Testcase 84:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME OPTIONS(
drivername :DB_DRIVERNAME,
url :DB_URL,
querytimeout '15',
jarfile :DB_DRIVERPATH,
maxheapsize '600'
);
--Testcase 85:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS(username :DB_USER,password :DB_PASS);

-- DB containers must be created for this test on DB server
-- CREATE TABLE IF NOT EXISTS department_tbl (department_id integer primary key, department_name text);
-- CREATE TABLE IF NOT EXISTS employee_tbl (emp_id integer primary key, emp_name text, emp_dept_id integer);
-- CREATE TABLE IF NOT EXISTS empdata_tbl (emp_id integer primary key, emp_dat bytea);
-- CREATE TABLE IF NOT EXISTS numbers_tbl (a integer primary key, b text);
-- CREATE TABLE IF NOT EXISTS shorty_tbl (id integer primary key, c text);
-- CREATE TABLE IF NOT EXISTS evennumbers_tbl (a integer primary key, b text);

-- create foreign
CREATE FOREIGN TABLE IF NOT EXISTS department (department_id integer OPTIONS (key 'true'), department_name text) SERVER :DB_SERVERNAME;
CREATE FOREIGN TABLE employee (emp_id integer OPTIONS (key 'true'), emp_name text, emp_dept_id integer) SERVER :DB_SERVERNAME;
CREATE FOREIGN TABLE empdata (emp_id integer OPTIONS (key 'true'), emp_dat bytea) SERVER :DB_SERVERNAME;
CREATE FOREIGN TABLE numbers (a integer OPTIONS (key 'true'), b text) SERVER :DB_SERVERNAME;
CREATE FOREIGN TABLE shorty (id integer OPTIONS (key 'true'), c text) SERVER :DB_SERVERNAME;
CREATE FOREIGN TABLE evennumbers (a integer OPTIONS (key 'true'), b text) SERVER :DB_SERVERNAME;


--Testcase 1:
DELETE FROM department;
--Testcase 2:
DELETE FROM employee;
--Testcase 3:
DELETE FROM empdata;
--Testcase 4:
DELETE FROM numbers;
--Testcase 5:
DELETE FROM evennumbers;

--Testcase 6:
--SELECT * FROM department LIMIT 10;
--Testcase 7:
--SELECT * FROM employee LIMIT 10;
--Testcase 8:
--SELECT * FROM empdata LIMIT 10;

--Testcase 9:
INSERT INTO department VALUES(generate_series(1,100), 'dept - ' || generate_series(1,100));
--Testcase 10:
INSERT INTO employee VALUES(generate_series(1,100), 'emp - ' || generate_series(1,100), generate_series(1,100));
--Testcase 11:
INSERT INTO empdata  VALUES(1, decode ('01234567', 'hex'));

--Testcase 12:
INSERT INTO numbers VALUES(1, 'One');
--Testcase 13:
INSERT INTO numbers VALUES(2, 'Two');
--Testcase 14:
INSERT INTO numbers VALUES(3, 'Three');
--Testcase 15:
INSERT INTO numbers VALUES(4, 'Four');
--Testcase 16:
INSERT INTO numbers VALUES(5, 'Five');
--Testcase 17:
INSERT INTO numbers VALUES(6, 'Six');
--Testcase 18:
INSERT INTO numbers VALUES(7, 'Seven');
--Testcase 19:
INSERT INTO numbers VALUES(8, 'Eight');
--Testcase 20:
INSERT INTO numbers VALUES(9, 'Nine');

--Testcase 21:
INSERT INTO evennumbers VALUES(2, 'Two');
--Testcase 22:
INSERT INTO evennumbers VALUES(4, 'Four');
--Testcase 23:
INSERT INTO evennumbers VALUES(6, 'Six');
--Testcase 24:
INSERT INTO evennumbers VALUES(8, 'Eight');

--Testcase 25:
SELECT count(*) FROM department;
--Testcase 26:
SELECT count(*) FROM employee;
--Testcase 27:
SELECT count(*) FROM empdata;

-- Join
--Testcase 28:
SELECT * FROM department d, employee e WHERE d.department_id = e.emp_dept_id LIMIT 10;
-- Subquery
--Testcase 29:
SELECT * FROM department d, employee e WHERE d.department_id IN (SELECT department_id FROM department) LIMIT 10;
--Testcase 30:
--SELECT * FROM empdata;
-- Delete single row
--Testcase 31:
DELETE FROM employee WHERE emp_id = 10;

--Testcase 32:
SELECT COUNT(*) FROM department LIMIT 10;
--Testcase 33:
SELECT COUNT(*) FROM employee WHERE emp_id = 10;
-- Update single row
--Testcase 34:
UPDATE employee SET emp_name = 'Updated emp' WHERE emp_id = 20;
--Testcase 35:
SELECT emp_id, emp_name FROM employee WHERE emp_name like 'Updated emp';

--Testcase 36:
UPDATE empdata SET emp_dat = decode ('0123', 'hex');
--Testcase 37:
--SELECT * FROM empdata;

--Testcase 38:
SELECT * FROM employee LIMIT 10;
--Testcase 39:
SELECT * FROM employee WHERE emp_id IN (1);
--Testcase 40:
SELECT * FROM employee WHERE emp_id IN (1,3,4,5);
--Testcase 41:
SELECT * FROM employee WHERE emp_id IN (10000,1000);

--Testcase 42:
SELECT * FROM employee WHERE emp_id NOT IN (1) LIMIT 5;
--Testcase 43:
SELECT * FROM employee WHERE emp_id NOT IN (1,3,4,5) LIMIT 5;
--Testcase 44:
SELECT * FROM employee WHERE emp_id NOT IN (10000,1000) LIMIT 5;

--Testcase 45:
SELECT * FROM employee WHERE emp_id NOT IN (SELECT emp_id FROM employee WHERE emp_id IN (1,10));
--Testcase 46:
SELECT * FROM employee WHERE emp_name NOT IN ('emp - 1', 'emp - 2') LIMIT 5;
--Testcase 47:
SELECT * FROM employee WHERE emp_name NOT IN ('emp - 10') LIMIT 5;

-- --Testcase 86:
-- CREATE OR REPLACE FUNCTION test_param_where() RETURNS void AS $$
-- DECLARE
--   n varchar;
-- BEGIN
--   FOR x IN 1..9 LOOP
-- --Testcase 87:
--     SELECT b INTO n FROM numbers WHERE a=x;
--     RAISE NOTICE 'Found number %', n;
--   END LOOP;
--   RETURN;
-- END
-- $$ LANGUAGE plpgsql;

--Testcase 48:
-- SELECT test_param_where();

-- ALTER FOREIGN TABLE numbers OPTIONS (table_name 'evennumbers');
--Testcase 49:
INSERT INTO numbers VALUES(10, 'Ten');
--Testcase 50:
SELECT * FROM numbers;

-- SET griddbfdw.enable_partial_execution TO TRUE;
--Testcase 51:
SELECT * FROM numbers;
-- SET griddbfdw.enable_partial_execution TO FALSE;

--Testcase 52:
DELETE FROM employee;
--Testcase 53:
DELETE FROM department;
--Testcase 54:
DELETE FROM empdata;
--Testcase 55:
DELETE FROM numbers;

-- --Testcase 88:
-- DROP FUNCTION test_param_where();
--Testcase 89:
DROP FOREIGN TABLE numbers;
--Testcase 90:
DROP FOREIGN TABLE department;
--Testcase 91:
DROP FOREIGN TABLE employee;
--Testcase 92:
DROP FOREIGN TABLE empdata;

-- -----------------------------------------------------------------------------
--Testcase 56:
DELETE FROM shorty;
--Testcase 57:
INSERT INTO shorty (id, c) VALUES (1, 'Z');
--Testcase 58:
INSERT INTO shorty (id, c) VALUES (2, 'Y');
--Testcase 59:
INSERT INTO shorty (id, c) VALUES (5, 'A');
--Testcase 60:
INSERT INTO shorty (id, c) VALUES (3, 'X');
--Testcase 61:
INSERT INTO shorty (id, c) VALUES (4, 'B');

-- ORDER BY.
--Testcase 62:
SELECT c FROM shorty ORDER BY id;

-- Transaction INSERT

--Testcase 63:
INSERT INTO shorty (id, c) VALUES (6, 'T');

--Testcase 64:
SELECT id, c FROM shorty;

-- Transaction UPDATE single row

--Testcase 65:
UPDATE shorty SET c = 'd' WHERE id = 5;

--Testcase 66:
SELECT id, c FROM shorty;

-- Transaction UPDATE all

--Testcase 67:
UPDATE shorty SET c = 'd';

--Testcase 68:
SELECT id, c FROM shorty;

-- Transaction DELETE single row

--Testcase 69:
DELETE FROM shorty WHERE id = 1;

--Testcase 70:
SELECT id, c FROM shorty;

-- Transaction DELETE all

--Testcase 71:
DELETE FROM shorty;

--Testcase 72:
SELECT id, c FROM shorty;

-- -- Use of NULL value
-- 
-- --Testcase 73:
-- INSERT INTO shorty VALUES(99, NULL);
-- --Testcase 74:
-- UPDATE shorty SET c = NULL WHERE id = 3;
-- --Testcase 75:
-- SELECT id FROM shorty WHERE c IS NULL;
-- 

-- parameters.
--Testcase 76:
PREPARE stmt(integer) AS SELECT * FROM shorty WHERE id = $1;
--Testcase 77:
EXECUTE stmt(1);
--Testcase 78:
EXECUTE stmt(2);
DEALLOCATE stmt;

-- test NULL parameter
--Testcase 79:
SELECT id FROM shorty WHERE c = (SELECT NULL::text);

-- Use of system column
--Testcase 80:
SELECT tableoid::regclass, * from shorty WHERE id = 1;
--Testcase 81:
SELECT * from shorty WHERE id = 1 AND tableoid = 'shorty'::regclass;

-- Clean up
--Testcase 93:
DROP FOREIGN TABLE shorty;

--Testcase 94:
CREATE OR REPLACE FUNCTION drop_all_foreign_tables() RETURNS void AS $$
DECLARE
  tbl_name varchar;
  cmd varchar;
BEGIN
  FOR tbl_name IN SELECT foreign_table_name FROM information_schema._pg_foreign_tables LOOP
    cmd := 'DROP FOREIGN TABLE ' || quote_ident(tbl_name);
--Testcase 95:
    EXECUTE cmd;
  END LOOP;
  RETURN;
END
$$ LANGUAGE plpgsql;
--Testcase 82:
SELECT drop_all_foreign_tables();

--Testcase 96:
DROP USER MAPPING FOR public SERVER :DB_SERVERNAME;
--Testcase 97:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 98:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
