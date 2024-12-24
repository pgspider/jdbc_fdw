--Testcase 111:
CREATE EXTENSION IF NOT EXISTS :DB_EXTENSIONNAME;
--Testcase 112:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME OPTIONS(
drivername :DB_DRIVERNAME,
url :DB_URL,
querytimeout '15',
jarfile :DB_DRIVERPATH,
maxheapsize '600'
);
--Testcase 113:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS(username :DB_USER,password :DB_PASS);
--Testcase 114:
CREATE FOREIGN TABLE INT4_TBL(id serial OPTIONS (key 'true'), f1 int4) SERVER :DB_SERVERNAME OPTIONS (table_name 'int4_tbl');
--Testcase 115:
CREATE FOREIGN TABLE INT4_TMP(id serial OPTIONS (key 'true'), a int4, b int4) SERVER :DB_SERVERNAME;

DELETE FROM INT4_TBL;
DELETE FROM INT4_TMP;

--Testcase 1:
INSERT INTO INT4_TBL(f1) VALUES ('   0  ');

--Testcase 2:
INSERT INTO INT4_TBL(f1) VALUES ('123456     ');

--Testcase 3:
INSERT INTO INT4_TBL(f1) VALUES ('    -123456');

--Testcase 4:
INSERT INTO INT4_TBL(f1) VALUES ('34.5');

-- largest and smallest values
--Testcase 5:
INSERT INTO INT4_TBL(f1) VALUES ('2147483647');

--Testcase 6:
INSERT INTO INT4_TBL(f1) VALUES ('-2147483647');

-- bad input values -- should give errors
--Testcase 7:
INSERT INTO INT4_TBL(f1) VALUES ('1000000000000');
--Testcase 8:
INSERT INTO INT4_TBL(f1) VALUES ('asdf');
--Testcase 9:
INSERT INTO INT4_TBL(f1) VALUES ('     ');
--Testcase 10:
INSERT INTO INT4_TBL(f1) VALUES ('   asdf   ');
--Testcase 11:
INSERT INTO INT4_TBL(f1) VALUES ('- 1234');
--Testcase 12:
INSERT INTO INT4_TBL(f1) VALUES ('123       5');
--Testcase 13:
INSERT INTO INT4_TBL(f1) VALUES ('');


--Testcase 14:
SELECT f1 FROM INT4_TBL;

--Testcase 15:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 <> int2 '0';

--Testcase 16:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 <> int4 '0';

--Testcase 17:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 = int2 '0';

--Testcase 18:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 = int4 '0';

--Testcase 19:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 < int2 '0';

--Testcase 20:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 < int4 '0';

--Testcase 21:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 <= int2 '0';

--Testcase 22:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 <= int4 '0';

--Testcase 23:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 > int2 '0';

--Testcase 24:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 > int4 '0';

--Testcase 25:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 >= int2 '0';

--Testcase 26:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 >= int4 '0';

-- positive odds
--Testcase 27:
SELECT i.f1 FROM INT4_TBL i WHERE (i.f1 % int2 '2') = int2 '1';

-- any evens
--Testcase 28:
SELECT i.f1 FROM INT4_TBL i WHERE (i.f1 % int4 '2') = int2 '0';

--Testcase 29:
SELECT i.f1, i.f1 * int2 '2' AS x FROM INT4_TBL i;

--Testcase 30:
SELECT i.f1, i.f1 * int2 '2' AS x FROM INT4_TBL i
WHERE abs(f1) < 1073741824;

--Testcase 31:
SELECT i.f1, i.f1 * int4 '2' AS x FROM INT4_TBL i;

--Testcase 32:
SELECT i.f1, i.f1 * int4 '2' AS x FROM INT4_TBL i
WHERE abs(f1) < 1073741824;

--Testcase 33:
SELECT i.f1, i.f1 + int2 '2' AS x FROM INT4_TBL i;

--Testcase 34:
SELECT i.f1, i.f1 + int2 '2' AS x FROM INT4_TBL i
WHERE f1 < 2147483646;

--Testcase 35:
SELECT i.f1, i.f1 + int4 '2' AS x FROM INT4_TBL i;

--Testcase 36:
SELECT i.f1, i.f1 + int4 '2' AS x FROM INT4_TBL i
WHERE f1 < 2147483646;

--Testcase 37:
SELECT i.f1, i.f1 - int2 '2' AS x FROM INT4_TBL i;

--Testcase 38:
SELECT i.f1, i.f1 - int2 '2' AS x FROM INT4_TBL i
WHERE f1 > -2147483647;

--Testcase 39:
SELECT i.f1, i.f1 - int4 '2' AS x FROM INT4_TBL i;

--Testcase 40:
SELECT i.f1, i.f1 - int4 '2' AS x FROM INT4_TBL i
WHERE f1 > -2147483647;

--Testcase 41:
SELECT i.f1, i.f1 / int2 '2' AS x FROM INT4_TBL i;

--Testcase 42:
SELECT i.f1, i.f1 / int4 '2' AS x FROM INT4_TBL i;

--
-- more complex expressions
--
ALTER FOREIGN TABLE INT4_TBL OPTIONS (SET table_name 'int4_tbl_temp');

-- variations on unary minus parsing

--Testcase 43:
DELETE FROM INT4_TBL;
--Testcase 44:
INSERT INTO INT4_TBL(f1) VALUES (-2);
--Testcase 45:
SELECT (f1+3) as one FROM INT4_TBL;

--Testcase 46:
DELETE FROM INT4_TBL;
--Testcase 47:
INSERT INTO INT4_TBL(f1) VALUES (4);
--Testcase 48:
SELECT (f1-2) as two FROM INT4_TBL;

--Testcase 49:
DELETE FROM INT4_TBL;
--Testcase 50:
INSERT INTO INT4_TBL(f1) VALUES (2);
--Testcase 51:
SELECT (f1- -1) as three FROM INT4_TBL;

--Testcase 52:
DELETE FROM INT4_TBL;
--Testcase 53:
INSERT INTO INT4_TBL(f1) VALUES (2);
--Testcase 54:
SELECT (f1 - -2) as four FROM INT4_TBL;

--Testcase 55:
DELETE FROM INT4_TMP;
--Testcase 56:
INSERT INTO INT4_TMP(a, b) VALUES (int2 '2' * int2 '2', int2 '16' / int2 '4');
--Testcase 57:
SELECT (a = b) as true FROM INT4_TMP;

--Testcase 58:
DELETE FROM INT4_TMP;
--Testcase 59:
INSERT INTO INT4_TMP(a, b) VALUES (int4 '2' * int2 '2', int2 '16' / int4 '4');
--Testcase 60:
SELECT (a = b) as true FROM INT4_TMP;

--Testcase 61:
DELETE FROM INT4_TMP;
--Testcase 62:
INSERT INTO INT4_TMP(a, b) VALUES (int2 '2' * int4 '2', int4 '16' / int2 '4');
--Testcase 63:
SELECT (a = b) as true FROM INT4_TMP;

--Testcase 64:
DELETE FROM INT4_TMP;
--Testcase 65:
INSERT INTO INT4_TMP(a, b) VALUES (int4 '1000', int4 '999');
--Testcase 66:
SELECT (a < b) as false FROM INT4_TMP;

--Testcase 73:
DELETE FROM INT4_TBL;
--Testcase 74:
INSERT INTO INT4_TBL(f1) VALUES (1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1);
--Testcase 75:
SELECT f1 as ten FROM INT4_TBL;



--Testcase 76:
DELETE FROM INT4_TBL;
--Testcase 77:
INSERT INTO INT4_TBL(f1) VALUES (2 + 2 / 2);
--Testcase 78:
SELECT f1 as three FROM INT4_TBL;



--Testcase 79:
DELETE FROM INT4_TBL;
--Testcase 80:
INSERT INTO INT4_TBL(f1) VALUES ((2 + 2) / 2);
--Testcase 81:
SELECT f1 as two FROM INT4_TBL;


-- corner case

--Testcase 82:
DELETE FROM INT4_TBL;
--Testcase 83:
INSERT INTO INT4_TBL(f1) VALUES ((-1::int4<<31));
--Testcase 116:
SELECT f1::text AS text FROM INT4_TBL;
--Testcase 84:
--Testcase 85:
SELECT (f1+1)::text FROM INT4_TBL;


-- check sane handling of INT_MIN overflow cases

--Testcase 86:
DELETE FROM INT4_TBL;
--Testcase 87:
INSERT INTO INT4_TBL(f1) VALUES ((-2147483648)::int4);
--Testcase 88:
SELECT (f1 * (-1)::int4) FROM INT4_TBL;


--Testcase 89:
DELETE FROM INT4_TBL;
--Testcase 90:
INSERT INTO INT4_TBL(f1) VALUES ((-2147483648)::int4);
--Testcase 91:
SELECT (f1 / (-1)::int4) FROM INT4_TBL;


--Testcase 92:
DELETE FROM INT4_TBL;
--Testcase 93:
INSERT INTO INT4_TBL(f1) VALUES ((-2147483648)::int4);
--Testcase 94:
SELECT (f1 % (-1)::int4) FROM INT4_TBL;


--Testcase 95:
DELETE FROM INT4_TBL;
--Testcase 96:
INSERT INTO INT4_TBL(f1) VALUES ((-2147483648)::int4);
--Testcase 97:
SELECT (f1 * (-1)::int2) FROM INT4_TBL;


--Testcase 98:
DELETE FROM INT4_TBL;
--Testcase 99:
INSERT INTO INT4_TBL(f1) VALUES ((-2147483648)::int4);
--Testcase 100:
SELECT (f1 / (-1)::int2) FROM INT4_TBL;


--Testcase 101:
DELETE FROM INT4_TBL;
--Testcase 102:
INSERT INTO INT4_TBL(f1) VALUES ((-2147483648)::int4);
--Testcase 103:
SELECT (f1 % (-1)::int2) FROM INT4_TBL;


-- check rounding when casting from float
--Testcase 117:
CREATE FOREIGN TABLE FLOAT8_TBL(id serial OPTIONS (key 'true'), f1 float8) SERVER :DB_SERVERNAME OPTIONS (table_name 'float8_tbl'); 

--Testcase 104:
DELETE FROM FLOAT8_TBL;
--Testcase 105:
INSERT INTO FLOAT8_TBL(f1) VALUES 
	(-2.5::float8),
        (-1.5::float8),
        (-0.5::float8),
        (0.0::float8),
        (0.5::float8),
        (1.5::float8),
        (2.5::float8);
--Testcase 106:
SELECT f1 as x, f1::int4 AS int4_value FROM FLOAT8_TBL;


-- check rounding when casting from numeric

--Testcase 107:
DELETE FROM FLOAT8_TBL;
--Testcase 108:
INSERT INTO FLOAT8_TBL(f1) VALUES 
	(-2.5::numeric),
        (-1.5::numeric),
        (-0.5::numeric),
        (0.0::numeric),
        (0.5::numeric),
        (1.5::numeric),
        (2.5::numeric);
--Testcase 109:
SELECT f1::numeric as x, f1::numeric::int4 AS int4_value FROM FLOAT8_TBL;


-- test gcd()

--Testcase 118:
DELETE FROM INT4_TMP;
--Testcase 119:
INSERT INTO INT4_TMP(a, b) VALUES (0::int4, 0::int4);
--Testcase 120:
INSERT INTO INT4_TMP(a, b) VALUES (0::int4, 6410818::int4);
--Testcase 121:
INSERT INTO INT4_TMP(a, b) VALUES (61866666::int4, 6410818::int4);
--Testcase 122:
INSERT INTO INT4_TMP(a, b) VALUES (-61866666::int4, 6410818::int4);
--Testcase 123:
INSERT INTO INT4_TMP(a, b) VALUES ((-2147483648)::int4, 1::int4);
--Testcase 124:
INSERT INTO INT4_TMP(a, b) VALUES ((-2147483648)::int4, 2147483647::int4);
--Testcase 125:
INSERT INTO INT4_TMP(a, b) VALUES ((-2147483648)::int4, 1073741824::int4);
--Testcase 126:
SELECT a, b, gcd(a, b), gcd(a, -b), gcd(b, a), gcd(-b, a) FROM INT4_TMP;



--Testcase 127:
DELETE FROM INT4_TMP;
--Testcase 128:
INSERT INTO INT4_TMP(a, b) VALUES ((-2147483648)::int4, 0::int4);
--Testcase 129:
SELECT gcd(a, b) FROM INT4_TMP;    -- overflow



--Testcase 130:
DELETE FROM INT4_TMP;
--Testcase 131:
INSERT INTO INT4_TMP(a, b) VALUES ((-2147483648)::int4, (-2147483648)::int4);
--Testcase 132:
SELECT gcd(a, b) FROM INT4_TMP;    -- overflow


-- test lcm()

--Testcase 133:
DELETE FROM INT4_TMP;
--Testcase 134:
INSERT INTO INT4_TMP(a, b) VALUES (0::int4, 0::int4);
--Testcase 135:
INSERT INTO INT4_TMP(a, b) VALUES (0::int4, 42::int4);
--Testcase 136:
INSERT INTO INT4_TMP(a, b) VALUES (42::int4, 42::int4);
--Testcase 137:
INSERT INTO INT4_TMP(a, b) VALUES (330::int4, 462::int4);
--Testcase 138:
INSERT INTO INT4_TMP(a, b) VALUES (-330::int4, 462::int4);
--Testcase 139:
INSERT INTO INT4_TMP(a, b) VALUES ((-2147483648)::int4, 0::int4);
--Testcase 140:
SELECT a, b, lcm(a, b), lcm(a, -b), lcm(b, a), lcm(-b, a) FROM INT4_TMP;



--Testcase 141:
DELETE FROM INT4_TMP;
--Testcase 142:
INSERT INTO INT4_TMP(a, b) VALUES ((-2147483648)::int4, 1::int4);
--Testcase 143:
SELECT lcm(a, b) FROM INT4_TMP;    -- overflow



--Testcase 144:
DELETE FROM INT4_TMP;
--Testcase 145:
INSERT INTO INT4_TMP(a, b) VALUES (2147483647::int4, 2147483646::int4);
--Testcase 146:
SELECT lcm(a, b) FROM INT4_TMP;    -- overflow


DELETE FROM INT4_TBL;
DELETE FROM INT4_TMP;
DELETE FROM FLOAT8_TBL;

--Testcase 147:
DROP FOREIGN TABLE INT4_TMP;
--Testcase 148:
DROP FOREIGN TABLE INT4_TBL;
--Testcase 149:
DROP FOREIGN TABLE FLOAT8_TBL;
--Testcase 150:
DROP USER MAPPING FOR public SERVER :DB_SERVERNAME;
--Testcase 151:
DROP SERVER :DB_SERVERNAME;
--Testcase 152:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
