--
-- FLOAT8
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
CREATE FOREIGN TABLE FLOAT8_TBL(id int4 OPTIONS (key 'true'), f1 float8) SERVER :DB_SERVERNAME OPTIONS (table_name 'float8_tbl');
--Testcase 5:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (1, '    0.0   ');
--Testcase 6:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (1, '    0.0   ');
--Testcase 7:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (2, '1004.30  ');
--Testcase 8:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (2, '1004.30  ');
--Testcase 9:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (3, '   -34.84');
--Testcase 10:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (3, '   -34.84');
--Testcase 11:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (4, '1.2345678901234e+200');
--Testcase 12:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (4, '1.2345678901234e+200');
--Testcase 13:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (5, '1.2345678901234e-200');
--Testcase 14:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (5, '1.2345678901234e-200');
-- bad input
--Testcase 15:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (6, '');
--Testcase 16:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (6, '');
--Testcase 17:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (7, '     ');
--Testcase 18:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (7, '     ');
--Testcase 19:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (8, 'xyz');
--Testcase 20:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (8, 'xyz');
--Testcase 21:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (9, '5.0.0');
--Testcase 22:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (9, '5.0.0');
--Testcase 23:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (10, '5 . 0');
--Testcase 24:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (10, '5 . 0');
--Testcase 25:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (11, '5.   0');
--Testcase 26:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (11, '5.   0');
--Testcase 27:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (12, '    - 3');
--Testcase 28:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (12, '    - 3');
--Testcase 29:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (13, '123           5');
--Testcase 30:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (13, '123           5');
--Testcase 31:
EXPLAIN VERBOSE
SELECT f1 FROM FLOAT8_TBL;
--Testcase 32:
SELECT f1 FROM FLOAT8_TBL;
--Testcase 33:
EXPLAIN VERBOSE
SELECT f.f1 FROM FLOAT8_TBL f WHERE f.f1 <> '1004.3';
--Testcase 34:
SELECT f.f1 FROM FLOAT8_TBL f WHERE f.f1 <> '1004.3';
--Testcase 35:
EXPLAIN VERBOSE
SELECT f.f1 FROM FLOAT8_TBL f WHERE f.f1 = '1004.3';
--Testcase 36:
SELECT f.f1 FROM FLOAT8_TBL f WHERE f.f1 = '1004.3';
--Testcase 37:
EXPLAIN VERBOSE
SELECT f.f1 FROM FLOAT8_TBL f WHERE '1004.3' > f.f1;
--Testcase 38:
SELECT f.f1 FROM FLOAT8_TBL f WHERE '1004.3' > f.f1;
--Testcase 39:
EXPLAIN VERBOSE
SELECT f.f1 FROM FLOAT8_TBL f WHERE  f.f1 < '1004.3';
--Testcase 40:
SELECT f.f1 FROM FLOAT8_TBL f WHERE  f.f1 < '1004.3';
--Testcase 41:
EXPLAIN VERBOSE
SELECT f.f1 FROM FLOAT8_TBL f WHERE '1004.3' >= f.f1;
--Testcase 42:
SELECT f.f1 FROM FLOAT8_TBL f WHERE '1004.3' >= f.f1;
--Testcase 43:
EXPLAIN VERBOSE
SELECT f.f1 FROM FLOAT8_TBL f WHERE  f.f1 <= '1004.3';
--Testcase 44:
SELECT f.f1 FROM FLOAT8_TBL f WHERE  f.f1 <= '1004.3';
--Testcase 45:
EXPLAIN VERBOSE
SELECT f.f1, f.f1 * '-10' AS x
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 46:
SELECT f.f1, f.f1 * '-10' AS x
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 47:
EXPLAIN VERBOSE
SELECT f.f1, f.f1 + '-10' AS x
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 48:
SELECT f.f1, f.f1 + '-10' AS x
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 49:
EXPLAIN VERBOSE
SELECT f.f1, f.f1 / '-10' AS x
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 50:
SELECT f.f1, f.f1 / '-10' AS x
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 51:
EXPLAIN VERBOSE
SELECT f.f1, f.f1 - '-10' AS x
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 52:
SELECT f.f1, f.f1 - '-10' AS x
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 53:
EXPLAIN VERBOSE
SELECT f.f1 ^ '2.0' AS square_f1
   FROM FLOAT8_TBL f where f.f1 = '1004.3';
--Testcase 54:
SELECT f.f1 ^ '2.0' AS square_f1
   FROM FLOAT8_TBL f where f.f1 = '1004.3';
-- absolute value
--Testcase 55:
EXPLAIN VERBOSE
SELECT f.f1, @f.f1 AS abs_f1
   FROM FLOAT8_TBL f;
--Testcase 56:
SELECT f.f1, @f.f1 AS abs_f1
   FROM FLOAT8_TBL f;
-- truncate
--Testcase 57:
EXPLAIN VERBOSE
SELECT f.f1, trunc(f.f1) AS trunc_f1
   FROM FLOAT8_TBL f;
--Testcase 58:
SELECT f.f1, trunc(f.f1) AS trunc_f1
   FROM FLOAT8_TBL f;
-- round
--Testcase 59:
EXPLAIN VERBOSE
SELECT f.f1, round(f.f1) AS round_f1
   FROM FLOAT8_TBL f;
--Testcase 60:
SELECT f.f1, round(f.f1) AS round_f1
   FROM FLOAT8_TBL f;
-- ceil / ceiling
--Testcase 61:
EXPLAIN VERBOSE
select ceil(f1) as ceil_f1 from float8_tbl f;
--Testcase 62:
select ceil(f1) as ceil_f1 from float8_tbl f;
--Testcase 63:
EXPLAIN VERBOSE
select ceiling(f1) as ceiling_f1 from float8_tbl f;
--Testcase 64:
select ceiling(f1) as ceiling_f1 from float8_tbl f;
-- floor
--Testcase 65:
EXPLAIN VERBOSE
select floor(f1) as floor_f1 from float8_tbl f;
--Testcase 66:
select floor(f1) as floor_f1 from float8_tbl f;
-- sign
--Testcase 67:
EXPLAIN VERBOSE
select sign(f1) as sign_f1 from float8_tbl f;
--Testcase 68:
select sign(f1) as sign_f1 from float8_tbl f;
-- avoid bit-exact output here because operations may not be bit-exact.
--Testcase 69:
SET extra_float_digits = 0;
-- square root
--Testcase 70:
EXPLAIN VERBOSE
SELECT sqrt(float8 '64') AS eight;
--Testcase 71:
SELECT sqrt(float8 '64') AS eight;
--Testcase 72:
EXPLAIN VERBOSE
SELECT |/ float8 '64' AS eight;
--Testcase 73:
SELECT |/ float8 '64' AS eight;
--Testcase 74:
EXPLAIN VERBOSE
SELECT f.f1, |/f.f1 AS sqrt_f1
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 75:
SELECT f.f1, |/f.f1 AS sqrt_f1
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';

-- take exp of ln(f.f1)
--Testcase 76:
EXPLAIN VERBOSE
SELECT f.f1, exp(ln(f.f1)) AS exp_ln_f1
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 77:
SELECT f.f1, exp(ln(f.f1)) AS exp_ln_f1
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';

-- cube root
--Testcase 78:
EXPLAIN VERBOSE
SELECT f.f1, ||/f.f1 AS cbrt_f1 FROM FLOAT8_TBL f;
--Testcase 79:
SELECT f.f1, ||/f.f1 AS cbrt_f1 FROM FLOAT8_TBL f;
--Testcase 80:
EXPLAIN VERBOSE
SELECT f1 FROM FLOAT8_TBL;
--Testcase 81:
SELECT f1 FROM FLOAT8_TBL;
--Testcase 82:
EXPLAIN VERBOSE
UPDATE FLOAT8_TBL
   SET f1 = FLOAT8_TBL.f1 * '-1'
   WHERE FLOAT8_TBL.f1 > '0.0';
--Testcase 83:
UPDATE FLOAT8_TBL
   SET f1 = FLOAT8_TBL.f1 * '-1'
   WHERE FLOAT8_TBL.f1 > '0.0';
--Testcase 84:
EXPLAIN VERBOSE
SELECT f.f1 * '1e200' from FLOAT8_TBL f;
--Testcase 85:
SELECT f.f1 * '1e200' from FLOAT8_TBL f;
--Testcase 86:
EXPLAIN VERBOSE
SELECT f.f1 ^ '1e200' from FLOAT8_TBL f;
--Testcase 87:
SELECT f.f1 ^ '1e200' from FLOAT8_TBL f;
--Testcase 88:
EXPLAIN VERBOSE
SELECT 0 ^ 0 + 0 ^ 1 + 0 ^ 0.0 + 0 ^ 0.5;
--Testcase 89:
SELECT 0 ^ 0 + 0 ^ 1 + 0 ^ 0.0 + 0 ^ 0.5;
--Testcase 90:
EXPLAIN VERBOSE
SELECT ln(f.f1) from FLOAT8_TBL f where f.f1 = '0.0' ;
--Testcase 91:
SELECT ln(f.f1) from FLOAT8_TBL f where f.f1 = '0.0' ;
--Testcase 92:
EXPLAIN VERBOSE
SELECT ln(f.f1) from FLOAT8_TBL f where f.f1 < '0.0' ;
--Testcase 93:
SELECT ln(f.f1) from FLOAT8_TBL f where f.f1 < '0.0' ;
--Testcase 94:
EXPLAIN VERBOSE
SELECT exp(f.f1) from FLOAT8_TBL f;
--Testcase 95:
SELECT exp(f.f1) from FLOAT8_TBL f;
--Testcase 96:
EXPLAIN VERBOSE
SELECT f.f1 / '0.0' from FLOAT8_TBL f;
--Testcase 97:
SELECT f.f1 / '0.0' from FLOAT8_TBL f;
--Testcase 98:
EXPLAIN VERBOSE
SELECT f1 FROM FLOAT8_TBL;
--Testcase 99:
SELECT f1 FROM FLOAT8_TBL;
--Testcase 100:
RESET extra_float_digits;
-- test for over- and underflow
--Testcase 101:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (14, '10e400');
--Testcase 102:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (14, '10e400');
--Testcase 103:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (15, '-10e400');
--Testcase 104:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (15, '-10e400');
--Testcase 105:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (16, '10e-400');
--Testcase 106:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (16, '10e-400');
--Testcase 107:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (17, '-10e-400');
--Testcase 108:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (17, '-10e-400');
-- maintain external table consistency across platforms
-- delete all values and reinsert well-behaved ones
--Testcase 109:
EXPLAIN VERBOSE
DELETE FROM FLOAT8_TBL;
--Testcase 110:
DELETE FROM FLOAT8_TBL;
--Testcase 111:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (1, '0.0');
--Testcase 112:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (1, '0.0');
--Testcase 113:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (2, '-34.84');
--Testcase 114:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (2, '-34.84');
--Testcase 115:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (3, '-1004.30');
--Testcase 116:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (3, '-1004.30');
--Testcase 117:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (4, '-1.2345678901234e+200');
--Testcase 118:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (4, '-1.2345678901234e+200');
--Testcase 119:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(id, f1) VALUES (5, '-1.2345678901234e-200');
--Testcase 120:
INSERT INTO FLOAT8_TBL(id, f1) VALUES (5, '-1.2345678901234e-200');
--Testcase 121:
EXPLAIN VERBOSE
SELECT f1 FROM FLOAT8_TBL;
--Testcase 122:
SELECT f1 FROM FLOAT8_TBL;
--Testcase 123:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 124:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
