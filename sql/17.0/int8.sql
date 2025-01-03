--Testcase 229:
CREATE EXTENSION IF NOT EXISTS :DB_EXTENSIONNAME;
--Testcase 230:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME OPTIONS(
drivername :DB_DRIVERNAME,
url :DB_URL,
querytimeout '15',
jarfile :DB_DRIVERPATH,
maxheapsize '600'
);
--Testcase 231:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS(username :DB_USER,password :DB_PASS);

--Testcase 232:
CREATE FOREIGN TABLE INT8_TBL(id serial OPTIONS (key 'true'), q1 int8, q2 int8) SERVER :DB_SERVERNAME; 

--Testcase 268:
DELETE FROM INT8_TBL;
--Testcase 1:
INSERT INTO INT8_TBL(q1, q2) VALUES('  123   ','  456');
--Testcase 2:
INSERT INTO INT8_TBL(q1, q2) VALUES('123   ','4567890123456789');
--Testcase 3:
INSERT INTO INT8_TBL(q1, q2) VALUES('4567890123456789','123');
--Testcase 4:
INSERT INTO INT8_TBL(q1, q2) VALUES(+4567890123456789,'4567890123456789');
--Testcase 5:
INSERT INTO INT8_TBL(q1, q2) VALUES('+4567890123456789','-4567890123456789');

-- bad inputs
--Testcase 6:
INSERT INTO INT8_TBL(q1) VALUES ('      ');
--Testcase 7:
INSERT INTO INT8_TBL(q1) VALUES ('xxx');
--Testcase 8:
INSERT INTO INT8_TBL(q1) VALUES ('3908203590239580293850293850329485');
--Testcase 9:
INSERT INTO INT8_TBL(q1) VALUES ('-1204982019841029840928340329840934');
--Testcase 10:
INSERT INTO INT8_TBL(q1) VALUES ('- 123');
--Testcase 11:
INSERT INTO INT8_TBL(q1) VALUES ('  345     5');
--Testcase 12:
INSERT INTO INT8_TBL(q1) VALUES ('');

--Testcase 13:
SELECT q1, q2 FROM INT8_TBL;

-- Also try it with non-error-throwing API
--Testcase 280:
CREATE FOREIGN TABLE text_tmp (id serial OPTIONS (key 'true'), c1 text) SERVER :DB_SERVERNAME OPTIONS (table_name 'text_tmp');

--Testcase 281:
DELETE FROM text_tmp;
--Testcase 282:
INSERT INTO text_tmp(c1) VALUES ('34');
--Testcase 283:
EXPLAIN VERBOSE
SELECT pg_input_is_valid(c1, 'int8') FROM text_tmp;
--Testcase 284:
SELECT pg_input_is_valid(c1, 'int8') FROM text_tmp;

--Testcase 285:
DELETE FROM text_tmp;
--Testcase 286:
INSERT INTO text_tmp(c1) VALUES ('asdf');
--Testcase 287:
EXPLAIN VERBOSE
SELECT pg_input_is_valid(c1, 'int8') FROM text_tmp;
--Testcase 288:
SELECT pg_input_is_valid(c1, 'int8') FROM text_tmp;

--Testcase 289:
DELETE FROM text_tmp;
--Testcase 290:
INSERT INTO text_tmp(c1) VALUES ('10000000000000000000');
--Testcase 291:
EXPLAIN VERBOSE
SELECT pg_input_is_valid(c1, 'int8') FROM text_tmp;
--Testcase 292:
SELECT pg_input_is_valid(c1, 'int8') FROM text_tmp;

--Testcase 293:
DELETE FROM text_tmp;
--Testcase 294:
INSERT INTO text_tmp(c1) VALUES ('10000000000000000000');
--Testcase 295:
EXPLAIN VERBOSE
SELECT * FROM text_tmp, pg_input_error_info(text_tmp.c1, 'int8');
--Testcase 296:
SELECT * FROM text_tmp, pg_input_error_info(text_tmp.c1, 'int8');

-- clean-up
--Testcase 297:
DELETE FROM text_tmp;
--Testcase 298:
DROP FOREIGN TABLE text_tmp;

-- int8/int8 cmp
--Testcase 14:
SELECT q1, q2 FROM INT8_TBL WHERE q2 = 4567890123456789;
--Testcase 15:
SELECT q1, q2 FROM INT8_TBL WHERE q2 <> 4567890123456789;
--Testcase 16:
SELECT q1, q2 FROM INT8_TBL WHERE q2 < 4567890123456789;
--Testcase 17:
SELECT q1, q2 FROM INT8_TBL WHERE q2 > 4567890123456789;
--Testcase 18:
SELECT q1, q2 FROM INT8_TBL WHERE q2 <= 4567890123456789;
--Testcase 19:
SELECT q1, q2 FROM INT8_TBL WHERE q2 >= 4567890123456789;

-- int8/int4 cmp
--Testcase 20:
SELECT q1, q2 FROM INT8_TBL WHERE q2 = 456;
--Testcase 21:
SELECT q1, q2 FROM INT8_TBL WHERE q2 <> 456;
--Testcase 22:
SELECT q1, q2 FROM INT8_TBL WHERE q2 < 456;
--Testcase 23:
SELECT q1, q2 FROM INT8_TBL WHERE q2 > 456;
--Testcase 24:
SELECT q1, q2 FROM INT8_TBL WHERE q2 <= 456;
--Testcase 25:
SELECT q1, q2 FROM INT8_TBL WHERE q2 >= 456;

-- int4/int8 cmp
--Testcase 26:
SELECT q1, q2 FROM INT8_TBL WHERE 123 = q1;
--Testcase 27:
SELECT q1, q2 FROM INT8_TBL WHERE 123 <> q1;
--Testcase 28:
SELECT q1, q2 FROM INT8_TBL WHERE 123 < q1;
--Testcase 29:
SELECT q1, q2 FROM INT8_TBL WHERE 123 > q1;
--Testcase 30:
SELECT q1, q2 FROM INT8_TBL WHERE 123 <= q1;
--Testcase 31:
SELECT q1, q2 FROM INT8_TBL WHERE 123 >= q1;

-- int8/int2 cmp
--Testcase 32:
SELECT q1, q2 FROM INT8_TBL WHERE q2 = '456'::int2;
--Testcase 33:
SELECT q1, q2 FROM INT8_TBL WHERE q2 <> '456'::int2;
--Testcase 34:
SELECT q1, q2 FROM INT8_TBL WHERE q2 < '456'::int2;
--Testcase 35:
SELECT q1, q2 FROM INT8_TBL WHERE q2 > '456'::int2;
--Testcase 36:
SELECT q1, q2 FROM INT8_TBL WHERE q2 <= '456'::int2;
--Testcase 37:
SELECT q1, q2 FROM INT8_TBL WHERE q2 >= '456'::int2;

-- int2/int8 cmp
--Testcase 38:
SELECT q1, q2 FROM INT8_TBL WHERE '123'::int2 = q1;
--Testcase 39:
SELECT q1, q2 FROM INT8_TBL WHERE '123'::int2 <> q1;
--Testcase 40:
SELECT q1, q2 FROM INT8_TBL WHERE '123'::int2 < q1;
--Testcase 41:
SELECT q1, q2 FROM INT8_TBL WHERE '123'::int2 > q1;
--Testcase 42:
SELECT q1, q2 FROM INT8_TBL WHERE '123'::int2 <= q1;
--Testcase 43:
SELECT q1, q2 FROM INT8_TBL WHERE '123'::int2 >= q1;


--Testcase 44:
SELECT q1 AS plus, -q1 AS minus FROM INT8_TBL;

--Testcase 45:
SELECT q1, q2, q1 + q2 AS plus FROM INT8_TBL;
--Testcase 46:
SELECT q1, q2, q1 - q2 AS minus FROM INT8_TBL;
--Testcase 47:
SELECT q1, q2, q1 * q2 AS multiply FROM INT8_TBL;
--Testcase 48:
SELECT q1, q2, q1 * q2 AS multiply FROM INT8_TBL
 WHERE q1 < 1000 or (q2 > 0 and q2 < 1000);
--Testcase 49:
SELECT q1, q2, q1 / q2 AS divide, q1 % q2 AS mod FROM INT8_TBL;

--Testcase 50:
SELECT q1, float8(q1) FROM INT8_TBL;
--Testcase 51:
SELECT q2, float8(q2) FROM INT8_TBL;

--Testcase 52:
SELECT 37 + q1 AS plus4 FROM INT8_TBL;
--Testcase 53:
SELECT 37 - q1 AS minus4 FROM INT8_TBL;
--Testcase 54:
SELECT 2 * q1 AS "twice int4" FROM INT8_TBL;
--Testcase 55:
SELECT q1 * 2 AS "twice int4" FROM INT8_TBL;

-- int8 op int4
--Testcase 56:
SELECT q1 + 42::int4 AS "8plus4", q1 - 42::int4 AS "8minus4", q1 * 42::int4 AS "8mul4", q1 / 42::int4 AS "8div4" FROM INT8_TBL;
-- int4 op int8
--Testcase 57:
SELECT 246::int4 + q1 AS "4plus8", 246::int4 - q1 AS "4minus8", 246::int4 * q1 AS "4mul8", 246::int4 / q1 AS "4div8" FROM INT8_TBL;

-- int8 op int2
--Testcase 58:
SELECT q1 + 42::int2 AS "8plus2", q1 - 42::int2 AS "8minus2", q1 * 42::int2 AS "8mul2", q1 / 42::int2 AS "8div2" FROM INT8_TBL;
-- int2 op int8
--Testcase 59:
SELECT 246::int2 + q1 AS "2plus8", 246::int2 - q1 AS "2minus8", 246::int2 * q1 AS "2mul8", 246::int2 / q1 AS "2div8" FROM INT8_TBL;

--Testcase 60:
SELECT q2, abs(q2) FROM INT8_TBL;
--Testcase 61:
SELECT min(q1), min(q2) FROM INT8_TBL;
--Testcase 62:
SELECT max(q1), max(q2) FROM INT8_TBL;


-- TO_CHAR()
--
--Testcase 63:
SELECT to_char(q1, '9G999G999G999G999G999'), to_char(q2, '9,999,999,999,999,999')
	FROM INT8_TBL;

--Testcase 64:
SELECT to_char(q1, '9G999G999G999G999G999D999G999'), to_char(q2, '9,999,999,999,999,999.999,999')
	FROM INT8_TBL;

--Testcase 65:
SELECT to_char( (q1 * -1), '9999999999999999PR'), to_char( (q2 * -1), '9999999999999999.999PR')
	FROM INT8_TBL;

--Testcase 66:
SELECT to_char( (q1 * -1), '9999999999999999S'), to_char( (q2 * -1), 'S9999999999999999')
	FROM INT8_TBL;

--Testcase 67:
SELECT to_char(q2, 'MI9999999999999999')     FROM INT8_TBL;
--Testcase 68:
SELECT to_char(q2, 'FMS9999999999999999')    FROM INT8_TBL;
--Testcase 69:
SELECT to_char(q2, 'FM9999999999999999THPR') FROM INT8_TBL;
--Testcase 70:
SELECT to_char(q2, 'SG9999999999999999th')   FROM INT8_TBL;
--Testcase 71:
SELECT to_char(q2, '0999999999999999')       FROM INT8_TBL;
--Testcase 72:
SELECT to_char(q2, 'S0999999999999999')      FROM INT8_TBL;
--Testcase 73:
SELECT to_char(q2, 'FM0999999999999999')     FROM INT8_TBL;
--Testcase 74:
SELECT to_char(q2, 'FM9999999999999999.000') FROM INT8_TBL;
--Testcase 75:
SELECT to_char(q2, 'L9999999999999999.000')  FROM INT8_TBL;
--Testcase 76:
SELECT to_char(q2, 'FM9999999999999999.999') FROM INT8_TBL;
--Testcase 77:
SELECT to_char(q2, 'S 9 9 9 9 9 9 9 9 9 9 9 9 9 9 9 9 . 9 9 9') FROM INT8_TBL;
--Testcase 78:
SELECT to_char(q2, E'99999 "text" 9999 "9999" 999 "\\"text between quote marks\\"" 9999') FROM INT8_TBL;
--Testcase 79:
SELECT to_char(q2, '999999SG9999999999')     FROM INT8_TBL;

-- check min/max values and overflow behavior

-- save data of foreign table INT8_TBL
--Testcase 269:
CREATE TABLE INT8_TBL_TMP (id int, q1 int8, q2 int8);
--Testcase 270:
INSERT INTO INT8_TBL_TMP SELECT id, q1, q2 FROM INT8_TBL;

--Testcase 80:
DELETE FROM INT8_TBL;
--Testcase 81:
INSERT INTO INT8_TBL(q1) VALUES ('-9223372036854775808'::int8);
--Testcase 82:
SELECT q1 FROM INT8_TBL;



--Testcase 83:
DELETE FROM INT8_TBL;
--Testcase 84:
INSERT INTO INT8_TBL(q1) VALUES ('-9223372036854775809'::int8);



--Testcase 86:
DELETE FROM INT8_TBL;
--Testcase 87:
INSERT INTO INT8_TBL(q1) VALUES ('9223372036854775807'::int8);
--Testcase 88:
SELECT q1 FROM INT8_TBL;



--Testcase 89:
DELETE FROM INT8_TBL;
--Testcase 90:
INSERT INTO INT8_TBL(q1) VALUES ('9223372036854775808'::int8);



--Testcase 92:
DELETE FROM INT8_TBL;
--Testcase 93:
INSERT INTO INT8_TBL(q1) VALUES (-('-9223372036854775807'::int8));
--Testcase 94:
SELECT q1 FROM INT8_TBL;



--Testcase 95:
DELETE FROM INT8_TBL;
--Testcase 96:
INSERT INTO INT8_TBL(q1) VALUES (-('-9223372036854775808'::int8));



--Testcase 98:
DELETE FROM INT8_TBL;
--Testcase 99:
INSERT INTO INT8_TBL(q1) VALUES ('9223372036854775800'::int8 + '9223372036854775800'::int8);



--Testcase 101:
DELETE FROM INT8_TBL;
--Testcase 102:
INSERT INTO INT8_TBL(q1) VALUES ('-9223372036854775800'::int8 + '-9223372036854775800'::int8);



--Testcase 104:
DELETE FROM INT8_TBL;
--Testcase 105:
INSERT INTO INT8_TBL(q1) VALUES ('9223372036854775800'::int8 - '-9223372036854775800'::int8);



--Testcase 107:
DELETE FROM INT8_TBL;
--Testcase 108:
INSERT INTO INT8_TBL(q1) VALUES ('-9223372036854775800'::int8 - '9223372036854775800'::int8);



--Testcase 110:
DELETE FROM INT8_TBL;
--Testcase 111:
INSERT INTO INT8_TBL(q1) VALUES ('9223372036854775800'::int8 * '9223372036854775800'::int8);



--Testcase 113:
DELETE FROM INT8_TBL;
--Testcase 114:
INSERT INTO INT8_TBL(q1) VALUES ('9223372036854775800'::int8 / '0'::int8);



--Testcase 116:
DELETE FROM INT8_TBL;
--Testcase 117:
INSERT INTO INT8_TBL(q1) VALUES ('9223372036854775800'::int8 % '0'::int8);



--Testcase 119:
DELETE FROM INT8_TBL;
--Testcase 120:
INSERT INTO INT8_TBL(q1) VALUES (abs('-9223372036854775808'::int8));



--Testcase 122:
DELETE FROM INT8_TBL;
--Testcase 123:
INSERT INTO INT8_TBL(q1) VALUES ('9223372036854775800'::int8 + '100'::int4);



--Testcase 125:
DELETE FROM INT8_TBL;
--Testcase 126:
INSERT INTO INT8_TBL(q1) VALUES ('-9223372036854775800'::int8 - '100'::int4);



--Testcase 128:
DELETE FROM INT8_TBL;
--Testcase 129:
INSERT INTO INT8_TBL(q1) VALUES ('9223372036854775800'::int8 * '100'::int4);



--Testcase 131:
DELETE FROM INT8_TBL;
--Testcase 132:
INSERT INTO INT8_TBL(q1) VALUES ('100'::int4 + '9223372036854775800'::int8);



--Testcase 134:
DELETE FROM INT8_TBL;
--Testcase 135:
INSERT INTO INT8_TBL(q1) VALUES ('-100'::int4 - '9223372036854775800'::int8);



--Testcase 137:
DELETE FROM INT8_TBL;
--Testcase 138:
INSERT INTO INT8_TBL(q1) VALUES ('100'::int4 * '9223372036854775800'::int8);



--Testcase 140:
DELETE FROM INT8_TBL;
--Testcase 141:
INSERT INTO INT8_TBL(q1) VALUES ('9223372036854775800'::int8 + '100'::int2);



--Testcase 143:
DELETE FROM INT8_TBL;
--Testcase 144:
INSERT INTO INT8_TBL(q1) VALUES ('-9223372036854775800'::int8 - '100'::int2);



--Testcase 146:
DELETE FROM INT8_TBL;
--Testcase 147:
INSERT INTO INT8_TBL(q1) VALUES ('9223372036854775800'::int8 * '100'::int2);



--Testcase 149:
DELETE FROM INT8_TBL;
--Testcase 150:
INSERT INTO INT8_TBL(q1) VALUES ('-9223372036854775808'::int8 / '0'::int2);



--Testcase 152:
DELETE FROM INT8_TBL;
--Testcase 153:
INSERT INTO INT8_TBL(q1) VALUES ('100'::int2 + '9223372036854775800'::int8);



--Testcase 155:
DELETE FROM INT8_TBL;
--Testcase 156:
INSERT INTO INT8_TBL(q1) VALUES ('-100'::int2 - '9223372036854775800'::int8);



--Testcase 158:
DELETE FROM INT8_TBL;
--Testcase 159:
INSERT INTO INT8_TBL(q1) VALUES ('100'::int2 * '9223372036854775800'::int8);



--Testcase 161:
DELETE FROM INT8_TBL;
--Testcase 162:
INSERT INTO INT8_TBL(q1) VALUES ('100'::int2 / '0'::int8);

-- revert change from INT8_TBL
--Testcase 271:
DELETE FROM INT8_TBL;
--Testcase 272:
INSERT INTO INT8_TBL SELECT id, q1, q2 FROM INT8_TBL_TMP;

--Testcase 164:
SELECT CAST(q1 AS int4) FROM int8_tbl WHERE q2 = 456;
--Testcase 165:
SELECT CAST(q1 AS int4) FROM int8_tbl WHERE q2 <> 456;

--Testcase 166:
SELECT CAST(q1 AS int2) FROM int8_tbl WHERE q2 = 456;
--Testcase 167:
SELECT CAST(q1 AS int2) FROM int8_tbl WHERE q2 <> 456;


--Testcase 168:
DELETE FROM INT8_TBL;
--Testcase 169:
INSERT INTO INT8_TBL(q1,q2) VALUES ('42'::int2, '-37'::int2);
--Testcase 170:
SELECT CAST(q1 AS int8), CAST(q2 AS int8) FROM INT8_TBL;

-- revert change from INT8_TBL
--Testcase 273:
DELETE FROM INT8_TBL;
--Testcase 274:
INSERT INTO INT8_TBL SELECT id, q1, q2 FROM INT8_TBL_TMP;
--Testcase 171:
SELECT CAST(q1 AS float4), CAST(q2 AS float8) FROM INT8_TBL;


--Testcase 172:
DELETE FROM INT8_TBL;
--Testcase 173:
INSERT INTO INT8_TBL(q1) VALUES ('36854775807.0'::float4);
--Testcase 174:
SELECT CAST(q1::float4 AS int8) FROM INT8_TBL;



--Testcase 175:
DELETE FROM INT8_TBL;
--Testcase 176:
INSERT INTO INT8_TBL(q1) VALUES ('922337203685477580700.0'::float8);
--Testcase 177:
SELECT CAST(q1::float8 AS int8) FROM INT8_TBL;

-- revert change from INT8_TBL
--Testcase 275:
DELETE FROM INT8_TBL;
--Testcase 276:
INSERT INTO INT8_TBL SELECT id, q1, q2 FROM INT8_TBL_TMP;
--Testcase 178:
SELECT CAST(q1 AS oid) FROM INT8_TBL;

-- bit operations

--Testcase 179:
SELECT q1, q2, q1 & q2 AS "and", q1 | q2 AS "or", q1 # q2 AS "xor", ~q1 AS "not" FROM INT8_TBL;
--Testcase 180:
SELECT q1, q1 << 2 AS "shl", q1 >> 3 AS "shr" FROM INT8_TBL;

-- generate_series


--Testcase 181:
DELETE FROM INT8_TBL;
--Testcase 182:
INSERT INTO INT8_TBL(q1) SELECT q1 FROM generate_series('+4567890123456789'::int8, '+4567890123456799'::int8) q1;
--Testcase 183:
SELECT q1 AS generate_series FROM INT8_TBL;



--Testcase 184:
DELETE FROM INT8_TBL;
--Testcase 185:
INSERT INTO INT8_TBL(q1) SELECT q1 FROM generate_series('+4567890123456789'::int8, '+4567890123456799'::int8, 0) q1; -- should error
--Testcase 186:
SELECT q1 AS generate_series FROM INT8_TBL;



--Testcase 187:
DELETE FROM INT8_TBL;
--Testcase 188:
INSERT INTO INT8_TBL(q1) SELECT q1 FROM generate_series('+4567890123456789'::int8, '+4567890123456799'::int8, 2) q1;
--Testcase 189:
SELECT q1 AS generate_series FROM INT8_TBL;


-- corner case

--Testcase 190:
DELETE FROM INT8_TBL;
--Testcase 191:
INSERT INTO INT8_TBL(q1) VALUES(-1::int8<<63);
--Testcase 192:
SELECT q1::text AS text FROM INT8_TBL;
--Testcase 195:
SELECT (q1+1)::text FROM INT8_TBL;


-- check sane handling of INT64_MIN overflow cases

--Testcase 196:
DELETE FROM INT8_TBL;
--Testcase 197:
INSERT INTO INT8_TBL(q1) VALUES ((-9223372036854775808)::int8);
--Testcase 198:
SELECT (q1 * (-1)::int8) FROM INT8_TBL;



--Testcase 199:
DELETE FROM INT8_TBL;
--Testcase 200:
INSERT INTO INT8_TBL(q1) VALUES ((-9223372036854775808)::int8);
--Testcase 201:
SELECT (q1 / (-1)::int8) FROM INT8_TBL;



--Testcase 202:
DELETE FROM INT8_TBL;
--Testcase 203:
INSERT INTO INT8_TBL(q1) VALUES ((-9223372036854775808)::int8);
--Testcase 204:
SELECT (q1 % (-1)::int8) FROM INT8_TBL;



--Testcase 205:
DELETE FROM INT8_TBL;
--Testcase 206:
INSERT INTO INT8_TBL(q1) VALUES ((-9223372036854775808)::int8);
--Testcase 207:
SELECT (q1 * (-1)::int4) FROM INT8_TBL;



--Testcase 208:
DELETE FROM INT8_TBL;
--Testcase 209:
INSERT INTO INT8_TBL(q1) VALUES ((-9223372036854775808)::int8);
--Testcase 210:
SELECT (q1 / (-1)::int4) FROM INT8_TBL;



--Testcase 211:
DELETE FROM INT8_TBL;
--Testcase 212:
INSERT INTO INT8_TBL(q1) VALUES ((-9223372036854775808)::int8);
--Testcase 213:
SELECT (q1 % (-1)::int4) FROM INT8_TBL;



--Testcase 214:
DELETE FROM INT8_TBL;
--Testcase 215:
INSERT INTO INT8_TBL(q1) VALUES ((-9223372036854775808)::int8);
--Testcase 216:
SELECT (q1 * (-1)::int2) FROM INT8_TBL;



--Testcase 217:
DELETE FROM INT8_TBL;
--Testcase 218:
INSERT INTO INT8_TBL(q1) VALUES ((-9223372036854775808)::int8);
--Testcase 219:
SELECT (q1 / (-1)::int2) FROM INT8_TBL;



--Testcase 220:
DELETE FROM INT8_TBL;
--Testcase 221:
INSERT INTO INT8_TBL(q1) VALUES ((-9223372036854775808)::int8);
--Testcase 222:
SELECT (q1 % (-1)::int2) FROM INT8_TBL;


-- check rounding when casting from float
--Testcase 233:
CREATE FOREIGN TABLE FLOAT8_TBL(id serial OPTIONS (key 'true'), f1 float8) SERVER :DB_SERVERNAME;

--Testcase 223:
DELETE FROM FLOAT8_TBL;
--Testcase 224:
INSERT INTO FLOAT8_TBL(f1) VALUES
	     (-2.5::float8),
             (-1.5::float8),
             (-0.5::float8),
             (0.0::float8),
             (0.5::float8),
             (1.5::float8),
             (2.5::float8);
--Testcase 225:
SELECT f1 as x, f1::int8 AS int8_value FROM FLOAT8_TBL;

 
-- check rounding when casting from numeric

--Testcase 226:
DELETE FROM FLOAT8_TBL;
--Testcase 227:
INSERT INTO FLOAT8_TBL(f1) VALUES
	     (-2.5::numeric),
             (-1.5::numeric),
             (-0.5::numeric),
             (0.0::numeric),
             (0.5::numeric),
             (1.5::numeric),
             (2.5::numeric);
--Testcase 228:
SELECT f1::numeric as x, f1::numeric::int8 AS int8_value FROM FLOAT8_TBL;


-- test gcd()

--Testcase 234:
DELETE FROM INT8_TBL;
--Testcase 235:
INSERT INTO INT8_TBL(q1, q2) VALUES (0::int8, 0::int8);
--Testcase 236:
INSERT INTO INT8_TBL(q1, q2) VALUES (0::int8, 29893644334::int8);
--Testcase 237:
INSERT INTO INT8_TBL(q1, q2) VALUES (288484263558::int8, 29893644334::int8);
--Testcase 238:
INSERT INTO INT8_TBL(q1, q2) VALUES (-288484263558::int8, 29893644334::int8);
--Testcase 239:
INSERT INTO INT8_TBL(q1, q2) VALUES ((-9223372036854775808)::int8, 1::int8);
--Testcase 240:
INSERT INTO INT8_TBL(q1, q2) VALUES ((-9223372036854775808)::int8, 9223372036854775807::int8);
--Testcase 241:
INSERT INTO INT8_TBL(q1, q2) VALUES ((-9223372036854775808)::int8, 4611686018427387904::int8);
--Testcase 242:
SELECT q1 AS a, q2 AS b, gcd(q1, q2), gcd(q1, -q2), gcd(q2, q1), gcd(-q2, q1) FROM INT8_TBL;



--Testcase 243:
DELETE FROM INT8_TBL;
--Testcase 244:
INSERT INTO INT8_TBL(q1, q2) VALUES ((-9223372036854775808)::int8, 0::int8);
--Testcase 245:
SELECT gcd(q1, q2) FROM INT8_TBL;    -- overflow



--Testcase 246:
DELETE FROM INT8_TBL;
--Testcase 247:
INSERT INTO INT8_TBL(q1, q2) VALUES ((-9223372036854775808)::int8, (-9223372036854775808)::int8);
--Testcase 248:
SELECT gcd(q1, q2) FROM INT8_TBL;    -- overflow


-- test lcm()

--Testcase 249:
DELETE FROM INT8_TBL;
--Testcase 250:
INSERT INTO INT8_TBL(q1, q2) VALUES (0::int8, 0::int8);
--Testcase 251:
INSERT INTO INT8_TBL(q1, q2) VALUES (0::int8, 29893644334::int8);
--Testcase 252:
INSERT INTO INT8_TBL(q1, q2) VALUES (29893644334::int8, 29893644334::int8);
--Testcase 253:
INSERT INTO INT8_TBL(q1, q2) VALUES (288484263558::int8, 29893644334::int8);
--Testcase 254:
INSERT INTO INT8_TBL(q1, q2) VALUES (-288484263558::int8, 29893644334::int8);
--Testcase 255:
INSERT INTO INT8_TBL(q1, q2) VALUES ((-9223372036854775808)::int8, 0::int8);
--Testcase 256:
SELECT q1 AS a, q2 AS b, lcm(q1, q2), lcm(q1, -q2), lcm(q2, q1), lcm(-q2, q1) FROM INT8_TBL;



--Testcase 257:
DELETE FROM INT8_TBL;
--Testcase 258:
INSERT INTO INT8_TBL(q1, q2) VALUES ((-9223372036854775808)::int8, 1::int8);
--Testcase 259:
SELECT lcm(q1, q2) FROM INT8_TBL;    -- overflow



--Testcase 260:
DELETE FROM INT8_TBL;
--Testcase 261:
INSERT INTO INT8_TBL(q1, q2) VALUES (9223372036854775807::int8, 9223372036854775806::int8);
--Testcase 262:
SELECT lcm(q1, q2) FROM INT8_TBL;    -- overflow

-- non-decimal literals
--Testcase 299:
CREATE FOREIGN TABLE text_tmp (id serial OPTIONS (key 'true'), c1 text) SERVER :DB_SERVERNAME OPTIONS (table_name 'text_tmp');

--Testcase 300:
DELETE FROM text_tmp;
--Testcase 301:
INSERT INTO text_tmp(c1) VALUES ('0b100101');
--Testcase 302:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 303:
SELECT int8(c1) FROM text_tmp;

--Testcase 304:
DELETE FROM text_tmp;
--Testcase 305:
INSERT INTO text_tmp(c1) VALUES ('0o273');
--Testcase 306:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 307:
SELECT int8(c1) FROM text_tmp;

--Testcase 308:
DELETE FROM text_tmp;
--Testcase 309:
INSERT INTO text_tmp(c1) VALUES ('0x42F');
--Testcase 310:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 311:
SELECT int8(c1) FROM text_tmp;

--Testcase 312:
DELETE FROM text_tmp;
--Testcase 313:
INSERT INTO text_tmp(c1) VALUES ('0b');
--Testcase 314:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 315:
SELECT int8(c1) FROM text_tmp;

--Testcase 316:
DELETE FROM text_tmp;
--Testcase 317:
INSERT INTO text_tmp(c1) VALUES ('0o');
--Testcase 318:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 319:
SELECT int8(c1) FROM text_tmp;

--Testcase 320:
DELETE FROM text_tmp;
--Testcase 321:
INSERT INTO text_tmp(c1) VALUES ('0x');
--Testcase 322:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 323:
SELECT int8(c1) FROM text_tmp;

-- cases near overflow
--Testcase 324:
DELETE FROM text_tmp;
--Testcase 325:
INSERT INTO text_tmp(c1) VALUES ('0b111111111111111111111111111111111111111111111111111111111111111');
--Testcase 326:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 327:
SELECT int8(c1) FROM text_tmp;

--Testcase 328:
DELETE FROM text_tmp;
--Testcase 329:
INSERT INTO text_tmp(c1) VALUES ('0b1000000000000000000000000000000000000000000000000000000000000000');
--Testcase 330:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 331:
SELECT int8(c1) FROM text_tmp;

--Testcase 332:
DELETE FROM text_tmp;
--Testcase 333:
INSERT INTO text_tmp(c1) VALUES ('0o777777777777777777777');
--Testcase 334:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 335:
SELECT int8(c1) FROM text_tmp;

--Testcase 336:
DELETE FROM text_tmp;
--Testcase 337:
INSERT INTO text_tmp(c1) VALUES ('0o1000000000000000000000');
--Testcase 338:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 339:
SELECT int8(c1) FROM text_tmp;

--Testcase 340:
DELETE FROM text_tmp;
--Testcase 341:
INSERT INTO text_tmp(c1) VALUES ('0x7FFFFFFFFFFFFFFF');
--Testcase 342:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 343:
SELECT int8(c1) FROM text_tmp;

--Testcase 344:
DELETE FROM text_tmp;
--Testcase 345:
INSERT INTO text_tmp(c1) VALUES ('0x8000000000000000');
--Testcase 346:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 347:
SELECT int8(c1) FROM text_tmp;


--Testcase 348:
DELETE FROM text_tmp;
--Testcase 349:
INSERT INTO text_tmp(c1) VALUES ('-0b1000000000000000000000000000000000000000000000000000000000000000');
--Testcase 350:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 351:
SELECT int8(c1) FROM text_tmp;

--Testcase 352:
DELETE FROM text_tmp;
--Testcase 353:
INSERT INTO text_tmp(c1) VALUES ('-0b1000000000000000000000000000000000000000000000000000000000000001');
--Testcase 354:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 355:
SELECT int8(c1) FROM text_tmp;

--Testcase 356:
DELETE FROM text_tmp;
--Testcase 357:
INSERT INTO text_tmp(c1) VALUES ('-0o1000000000000000000000');
--Testcase 358:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 359:
SELECT int8(c1) FROM text_tmp;

--Testcase 360:
DELETE FROM text_tmp;
--Testcase 361:
INSERT INTO text_tmp(c1) VALUES ('-0o1000000000000000000001');
--Testcase 362:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 363:
SELECT int8(c1) FROM text_tmp;

--Testcase 364:
DELETE FROM text_tmp;
--Testcase 365:
INSERT INTO text_tmp(c1) VALUES ('-0x8000000000000000');
--Testcase 366:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 367:
SELECT int8(c1) FROM text_tmp;

--Testcase 368:
DELETE FROM text_tmp;
--Testcase 369:
INSERT INTO text_tmp(c1) VALUES ('-0x8000000000000001');
--Testcase 370:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 371:
SELECT int8(c1) FROM text_tmp;


-- underscores


--Testcase 372:
DELETE FROM text_tmp;
--Testcase 373:
INSERT INTO text_tmp(c1) VALUES ('1_000_000');
--Testcase 374:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 375:
SELECT int8(c1) FROM text_tmp;

--Testcase 376:
DELETE FROM text_tmp;
--Testcase 377:
INSERT INTO text_tmp(c1) VALUES ('1_2_3');
--Testcase 378:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 379:
SELECT int8(c1) FROM text_tmp;

--Testcase 380:
DELETE FROM text_tmp;
--Testcase 381:
INSERT INTO text_tmp(c1) VALUES ('0x1EEE_FFFF');
--Testcase 382:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 383:
SELECT int8(c1) FROM text_tmp;

--Testcase 384:
DELETE FROM text_tmp;
--Testcase 385:
INSERT INTO text_tmp(c1) VALUES ('0o2_73');
--Testcase 386:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 387:
SELECT int8(c1) FROM text_tmp;

--Testcase 388:
DELETE FROM text_tmp;
--Testcase 389:
INSERT INTO text_tmp(c1) VALUES ('0b_10_0101');
--Testcase 390:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 391:
SELECT int8(c1) FROM text_tmp;

-- error cases

--Testcase 392:
DELETE FROM text_tmp;
--Testcase 393:
INSERT INTO text_tmp(c1) VALUES ('_100');
--Testcase 394:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 395:
SELECT int8(c1) FROM text_tmp;

--Testcase 396:
DELETE FROM text_tmp;
--Testcase 397:
INSERT INTO text_tmp(c1) VALUES ('100_');
--Testcase 398:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 399:
SELECT int8(c1) FROM text_tmp;

--Testcase 400:
DELETE FROM text_tmp;
--Testcase 401:
INSERT INTO text_tmp(c1) VALUES ('100__000');
--Testcase 402:
EXPLAIN VERBOSE
SELECT int8(c1) FROM text_tmp;
--Testcase 403:
SELECT int8(c1) FROM text_tmp;

-- revert change from INT8_TBL
--Testcase 277:
DELETE FROM INT8_TBL;
--Testcase 278:
INSERT INTO INT8_TBL SELECT id, q1, q2 FROM INT8_TBL_TMP;

--Testcase 279:
DROP TABLE int8_tbl_tmp CASCADE;
--Testcase 263:
DROP FOREIGN TABLE FLOAT8_TBL;
--Testcase 264:
DROP FOREIGN TABLE INT8_TBL;
--Testcase 265:
DROP USER MAPPING FOR public SERVER :DB_SERVERNAME;
--Testcase 266:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 267:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
