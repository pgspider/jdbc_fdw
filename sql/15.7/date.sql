--
-- DATE
--

-- This file execute with PostgreSQL and MySQL. GridDB does not support DATE data type.

CREATE EXTENSION :DB_EXTENSIONNAME;
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
OPTIONS (drivername :DB_DRIVERNAME,
url :DB_URL,
querytimeout '15',
jarfile :DB_DRIVERPATH,
maxheapsize '600');
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS (username :DB_USER,password :DB_PASS);

CREATE FOREIGN TABLE DATE_TBL (id int OPTIONS (key 'true'), f1 date) SERVER :DB_SERVERNAME OPTIONS (table_name 'date_tbl');

INSERT INTO DATE_TBL VALUES (1, '1957-04-09');
INSERT INTO DATE_TBL VALUES (2, '1957-06-13');
INSERT INTO DATE_TBL VALUES (3, '1996-02-28');
INSERT INTO DATE_TBL VALUES (4, '1996-02-29');
INSERT INTO DATE_TBL VALUES (5, '1996-03-01');
INSERT INTO DATE_TBL VALUES (6, '1996-03-02');
INSERT INTO DATE_TBL VALUES (7, '1997-02-28');
INSERT INTO DATE_TBL VALUES (8, '1997-02-29');
INSERT INTO DATE_TBL VALUES (9, '1997-03-01');
INSERT INTO DATE_TBL VALUES (10, '1997-03-02');
INSERT INTO DATE_TBL VALUES (11, '2000-04-01');
INSERT INTO DATE_TBL VALUES (12, '2000-04-02');
INSERT INTO DATE_TBL VALUES (13, '2000-04-03');
INSERT INTO DATE_TBL VALUES (14, '2038-04-08');
INSERT INTO DATE_TBL VALUES (15, '2039-04-09');
INSERT INTO DATE_TBL VALUES (16, '2040-04-10');
-- Comment out this test case because java.sql.Date.valueOf() cannot convert a string that has formatted like '2040-04-10 BC'
-- INSERT INTO DATE_TBL VALUES ('2040-04-10 BC');

SELECT f1 FROM DATE_TBL;

SELECT f1 FROM DATE_TBL WHERE f1 < '2000-01-01';

SELECT f1 FROM DATE_TBL
  WHERE f1 BETWEEN '2000-01-01' AND '2001-01-01';

-- Comment out these test cases because they are not relate to jdbc_fdw
-- --
-- -- Check all the documented input formats
-- --
-- SET datestyle TO iso;  -- display results in ISO

-- SET datestyle TO ymd;

-- SELECT date 'January 8, 1999';
-- SELECT date '1999-01-08';
-- SELECT date '1999-01-18';
-- SELECT date '1/8/1999';
-- SELECT date '1/18/1999';
-- SELECT date '18/1/1999';
-- SELECT date '01/02/03';
-- SELECT date '19990108';
-- SELECT date '990108';
-- SELECT date '1999.008';
-- SELECT date 'J2451187';
-- SELECT date 'January 8, 99 BC';

-- SELECT date '99-Jan-08';
-- SELECT date '1999-Jan-08';
-- SELECT date '08-Jan-99';
-- SELECT date '08-Jan-1999';
-- SELECT date 'Jan-08-99';
-- SELECT date 'Jan-08-1999';
-- SELECT date '99-08-Jan';
-- SELECT date '1999-08-Jan';

-- SELECT date '99 Jan 08';
-- SELECT date '1999 Jan 08';
-- SELECT date '08 Jan 99';
-- SELECT date '08 Jan 1999';
-- SELECT date 'Jan 08 99';
-- SELECT date 'Jan 08 1999';
-- SELECT date '99 08 Jan';
-- SELECT date '1999 08 Jan';

-- SELECT date '99-01-08';
-- SELECT date '1999-01-08';
-- SELECT date '08-01-99';
-- SELECT date '08-01-1999';
-- SELECT date '01-08-99';
-- SELECT date '01-08-1999';
-- SELECT date '99-08-01';
-- SELECT date '1999-08-01';

-- SELECT date '99 01 08';
-- SELECT date '1999 01 08';
-- SELECT date '08 01 99';
-- SELECT date '08 01 1999';
-- SELECT date '01 08 99';
-- SELECT date '01 08 1999';
-- SELECT date '99 08 01';
-- SELECT date '1999 08 01';

-- SET datestyle TO dmy;

-- SELECT date 'January 8, 1999';
-- SELECT date '1999-01-08';
-- SELECT date '1999-01-18';
-- SELECT date '1/8/1999';
-- SELECT date '1/18/1999';
-- SELECT date '18/1/1999';
-- SELECT date '01/02/03';
-- SELECT date '19990108';
-- SELECT date '990108';
-- SELECT date '1999.008';
-- SELECT date 'J2451187';
-- SELECT date 'January 8, 99 BC';

-- SELECT date '99-Jan-08';
-- SELECT date '1999-Jan-08';
-- SELECT date '08-Jan-99';
-- SELECT date '08-Jan-1999';
-- SELECT date 'Jan-08-99';
-- SELECT date 'Jan-08-1999';
-- SELECT date '99-08-Jan';
-- SELECT date '1999-08-Jan';

-- SELECT date '99 Jan 08';
-- SELECT date '1999 Jan 08';
-- SELECT date '08 Jan 99';
-- SELECT date '08 Jan 1999';
-- SELECT date 'Jan 08 99';
-- SELECT date 'Jan 08 1999';
-- SELECT date '99 08 Jan';
-- SELECT date '1999 08 Jan';

-- SELECT date '99-01-08';
-- SELECT date '1999-01-08';
-- SELECT date '08-01-99';
-- SELECT date '08-01-1999';
-- SELECT date '01-08-99';
-- SELECT date '01-08-1999';
-- SELECT date '99-08-01';
-- SELECT date '1999-08-01';

-- SELECT date '99 01 08';
-- SELECT date '1999 01 08';
-- SELECT date '08 01 99';
-- SELECT date '08 01 1999';
-- SELECT date '01 08 99';
-- SELECT date '01 08 1999';
-- SELECT date '99 08 01';
-- SELECT date '1999 08 01';

-- SET datestyle TO mdy;

-- SELECT date 'January 8, 1999';
-- SELECT date '1999-01-08';
-- SELECT date '1999-01-18';
-- SELECT date '1/8/1999';
-- SELECT date '1/18/1999';
-- SELECT date '18/1/1999';
-- SELECT date '01/02/03';
-- SELECT date '19990108';
-- SELECT date '990108';
-- SELECT date '1999.008';
-- SELECT date 'J2451187';
-- SELECT date 'January 8, 99 BC';

-- SELECT date '99-Jan-08';
-- SELECT date '1999-Jan-08';
-- SELECT date '08-Jan-99';
-- SELECT date '08-Jan-1999';
-- SELECT date 'Jan-08-99';
-- SELECT date 'Jan-08-1999';
-- SELECT date '99-08-Jan';
-- SELECT date '1999-08-Jan';

-- SELECT date '99 Jan 08';
-- SELECT date '1999 Jan 08';
-- SELECT date '08 Jan 99';
-- SELECT date '08 Jan 1999';
-- SELECT date 'Jan 08 99';
-- SELECT date 'Jan 08 1999';
-- SELECT date '99 08 Jan';
-- SELECT date '1999 08 Jan';

-- SELECT date '99-01-08';
-- SELECT date '1999-01-08';
-- SELECT date '08-01-99';
-- SELECT date '08-01-1999';
-- SELECT date '01-08-99';
-- SELECT date '01-08-1999';
-- SELECT date '99-08-01';
-- SELECT date '1999-08-01';

-- SELECT date '99 01 08';
-- SELECT date '1999 01 08';
-- SELECT date '08 01 99';
-- SELECT date '08 01 1999';
-- SELECT date '01 08 99';
-- SELECT date '01 08 1999';
-- SELECT date '99 08 01';
-- SELECT date '1999 08 01';

-- -- Check upper and lower limits of date range
-- SELECT date '4714-11-24 BC';
-- SELECT date '4714-11-23 BC';  -- out of range
-- SELECT date '5874897-12-31';
-- SELECT date '5874898-01-01';  -- out of range

-- RESET datestyle;

--
-- Simple math
-- Leave most of it for the horology tests
--

SELECT f1 - date '2000-01-01' AS "Days From 2K" FROM DATE_TBL;

SELECT f1 - date 'epoch' AS "Days From Epoch" FROM DATE_TBL;

-- Comment out these test cases because they are not relate to jdbc_fdw
-- SELECT date 'yesterday' - date 'today' AS "One day";

-- SELECT date 'today' - date 'tomorrow' AS "One day";

-- SELECT date 'yesterday' - date 'tomorrow' AS "Two days";

-- SELECT date 'tomorrow' - date 'today' AS "One day";

-- SELECT date 'today' - date 'yesterday' AS "One day";

-- SELECT date 'tomorrow' - date 'yesterday' AS "Two days";

--
-- test extract!
--
SELECT f1 as "date",
    date_part('year', f1) AS year,
    date_part('month', f1) AS month,
    date_part('day', f1) AS day,
    date_part('quarter', f1) AS quarter,
    date_part('decade', f1) AS decade,
    date_part('century', f1) AS century,
    date_part('millennium', f1) AS millennium,
    date_part('isoyear', f1) AS isoyear,
    date_part('week', f1) AS week,
    date_part('dow', f1) AS dow,
    date_part('isodow', f1) AS isodow,
    date_part('doy', f1) AS doy,
    date_part('julian', f1) AS julian,
    date_part('epoch', f1) AS epoch
    FROM date_tbl;
-- Comment out these test cases because they are not relate to jdbc_fdw
-- --
-- -- epoch
-- --
-- SELECT EXTRACT(EPOCH FROM DATE        '1970-01-01');     --  0
-- --
-- -- century
-- --
-- SELECT EXTRACT(CENTURY FROM DATE '0101-12-31 BC'); -- -2
-- SELECT EXTRACT(CENTURY FROM DATE '0100-12-31 BC'); -- -1
-- SELECT EXTRACT(CENTURY FROM DATE '0001-12-31 BC'); -- -1
-- SELECT EXTRACT(CENTURY FROM DATE '0001-01-01');    --  1
-- SELECT EXTRACT(CENTURY FROM DATE '0001-01-01 AD'); --  1
-- SELECT EXTRACT(CENTURY FROM DATE '1900-12-31');    -- 19
-- SELECT EXTRACT(CENTURY FROM DATE '1901-01-01');    -- 20
-- SELECT EXTRACT(CENTURY FROM DATE '2000-12-31');    -- 20
-- SELECT EXTRACT(CENTURY FROM DATE '2001-01-01');    -- 21
-- SELECT EXTRACT(CENTURY FROM CURRENT_DATE)>=21 AS True;     -- true
-- --
-- -- millennium
-- --
-- SELECT EXTRACT(MILLENNIUM FROM DATE '0001-12-31 BC'); -- -1
-- SELECT EXTRACT(MILLENNIUM FROM DATE '0001-01-01 AD'); --  1
-- SELECT EXTRACT(MILLENNIUM FROM DATE '1000-12-31');    --  1
-- SELECT EXTRACT(MILLENNIUM FROM DATE '1001-01-01');    --  2
-- SELECT EXTRACT(MILLENNIUM FROM DATE '2000-12-31');    --  2
-- SELECT EXTRACT(MILLENNIUM FROM DATE '2001-01-01');    --  3
-- -- next test to be fixed on the turn of the next millennium;-)
-- SELECT EXTRACT(MILLENNIUM FROM CURRENT_DATE);         --  3
-- --
-- -- decade
-- --
-- SELECT EXTRACT(DECADE FROM DATE '1994-12-25');    -- 199
-- SELECT EXTRACT(DECADE FROM DATE '0010-01-01');    --   1
-- SELECT EXTRACT(DECADE FROM DATE '0009-12-31');    --   0
-- SELECT EXTRACT(DECADE FROM DATE '0001-01-01 BC'); --   0
-- SELECT EXTRACT(DECADE FROM DATE '0002-12-31 BC'); --  -1
-- SELECT EXTRACT(DECADE FROM DATE '0011-01-01 BC'); --  -1
-- SELECT EXTRACT(DECADE FROM DATE '0012-12-31 BC'); --  -2
-- --
-- -- all possible fields
-- --
-- SELECT EXTRACT(MICROSECONDS  FROM DATE '2020-08-11');
-- SELECT EXTRACT(MILLISECONDS  FROM DATE '2020-08-11');
-- SELECT EXTRACT(SECOND        FROM DATE '2020-08-11');
-- SELECT EXTRACT(MINUTE        FROM DATE '2020-08-11');
-- SELECT EXTRACT(HOUR          FROM DATE '2020-08-11');
-- SELECT EXTRACT(DAY           FROM DATE '2020-08-11');
-- SELECT EXTRACT(MONTH         FROM DATE '2020-08-11');
-- SELECT EXTRACT(YEAR          FROM DATE '2020-08-11');
-- SELECT EXTRACT(YEAR          FROM DATE '2020-08-11 BC');
-- SELECT EXTRACT(DECADE        FROM DATE '2020-08-11');
-- SELECT EXTRACT(CENTURY       FROM DATE '2020-08-11');
-- SELECT EXTRACT(MILLENNIUM    FROM DATE '2020-08-11');
-- SELECT EXTRACT(ISOYEAR       FROM DATE '2020-08-11');
-- SELECT EXTRACT(ISOYEAR       FROM DATE '2020-08-11 BC');
-- SELECT EXTRACT(QUARTER       FROM DATE '2020-08-11');
-- SELECT EXTRACT(WEEK          FROM DATE '2020-08-11');
-- SELECT EXTRACT(DOW           FROM DATE '2020-08-11');
-- SELECT EXTRACT(DOW           FROM DATE '2020-08-16');
-- SELECT EXTRACT(ISODOW        FROM DATE '2020-08-11');
-- SELECT EXTRACT(ISODOW        FROM DATE '2020-08-16');
-- SELECT EXTRACT(DOY           FROM DATE '2020-08-11');
-- SELECT EXTRACT(TIMEZONE      FROM DATE '2020-08-11');
-- SELECT EXTRACT(TIMEZONE_M    FROM DATE '2020-08-11');
-- SELECT EXTRACT(TIMEZONE_H    FROM DATE '2020-08-11');
-- SELECT EXTRACT(EPOCH         FROM DATE '2020-08-11');
-- SELECT EXTRACT(JULIAN        FROM DATE '2020-08-11');
-- --
-- -- test trunc function!
-- --
-- SELECT DATE_TRUNC('MILLENNIUM', TIMESTAMP '1970-03-20 04:30:00.00000'); -- 1001
-- SELECT DATE_TRUNC('MILLENNIUM', DATE '1970-03-20'); -- 1001-01-01
-- SELECT DATE_TRUNC('CENTURY', TIMESTAMP '1970-03-20 04:30:00.00000'); -- 1901
-- SELECT DATE_TRUNC('CENTURY', DATE '1970-03-20'); -- 1901
-- SELECT DATE_TRUNC('CENTURY', DATE '2004-08-10'); -- 2001-01-01
-- SELECT DATE_TRUNC('CENTURY', DATE '0002-02-04'); -- 0001-01-01
-- SELECT DATE_TRUNC('CENTURY', DATE '0055-08-10 BC'); -- 0100-01-01 BC
-- SELECT DATE_TRUNC('DECADE', DATE '1993-12-25'); -- 1990-01-01
-- SELECT DATE_TRUNC('DECADE', DATE '0004-12-25'); -- 0001-01-01 BC
-- SELECT DATE_TRUNC('DECADE', DATE '0002-12-31 BC'); -- 0011-01-01 BC
-- --
-- -- test infinity
-- --
-- select 'infinity'::date, '-infinity'::date;
-- select 'infinity'::date > 'today'::date as t;
-- select '-infinity'::date < 'today'::date as t;
-- select isfinite('infinity'::date), isfinite('-infinity'::date), isfinite('today'::date);
-- --
-- -- oscillating fields from non-finite date:
-- --
-- SELECT EXTRACT(DAY FROM DATE 'infinity');      -- NULL
-- SELECT EXTRACT(DAY FROM DATE '-infinity');     -- NULL
-- -- all supported fields
-- SELECT EXTRACT(DAY           FROM DATE 'infinity');    -- NULL
-- SELECT EXTRACT(MONTH         FROM DATE 'infinity');    -- NULL
-- SELECT EXTRACT(QUARTER       FROM DATE 'infinity');    -- NULL
-- SELECT EXTRACT(WEEK          FROM DATE 'infinity');    -- NULL
-- SELECT EXTRACT(DOW           FROM DATE 'infinity');    -- NULL
-- SELECT EXTRACT(ISODOW        FROM DATE 'infinity');    -- NULL
-- SELECT EXTRACT(DOY           FROM DATE 'infinity');    -- NULL
-- --
-- -- monotonic fields from non-finite date:
-- --
-- SELECT EXTRACT(EPOCH FROM DATE 'infinity');         --  Infinity
-- SELECT EXTRACT(EPOCH FROM DATE '-infinity');        -- -Infinity
-- -- all supported fields
-- SELECT EXTRACT(YEAR       FROM DATE 'infinity');    --  Infinity
-- SELECT EXTRACT(DECADE     FROM DATE 'infinity');    --  Infinity
-- SELECT EXTRACT(CENTURY    FROM DATE 'infinity');    --  Infinity
-- SELECT EXTRACT(MILLENNIUM FROM DATE 'infinity');    --  Infinity
-- SELECT EXTRACT(JULIAN     FROM DATE 'infinity');    --  Infinity
-- SELECT EXTRACT(ISOYEAR    FROM DATE 'infinity');    --  Infinity
-- SELECT EXTRACT(EPOCH      FROM DATE 'infinity');    --  Infinity
-- --
-- -- wrong fields from non-finite date:
-- --
-- SELECT EXTRACT(MICROSEC  FROM DATE 'infinity');     -- error

-- -- test constructors
-- select make_date(2013, 7, 15);
-- select make_date(-44, 3, 15);
-- select make_time(8, 20, 0.0);
-- -- should fail
-- select make_date(0, 7, 15);
-- select make_date(2013, 2, 30);
-- select make_date(2013, 13, 1);
-- select make_date(2013, 11, -1);
-- select make_time(10, 55, 100.1);
-- select make_time(24, 0, 2.1);

--
-- Extern test case for inserting with other DateStyle and DateOrder
--
show datestyle;
SET datestyle TO ISO, MDY;

DELETE FROM DATE_TBL;

-- ISO 8601; January 8 in any mode
INSERT INTO DATE_TBL VALUES (1, '1999-01-08');
SELECT * FROM DATE_TBL WHERE id = 1;

-- unambiguous in any datestyle input mode
INSERT INTO DATE_TBL VALUES (2, 'January 8, 1999');
SELECT * FROM DATE_TBL WHERE id = 2;

-- January 8 in MDY mode; August 1 in DMY mode
INSERT INTO DATE_TBL VALUES (3, '1/8/1999');
SELECT * FROM DATE_TBL WHERE id = 3;

SET datestyle TO DMY;
INSERT INTO DATE_TBL VALUES (4, '1/8/1999');
SELECT * FROM DATE_TBL WHERE id = 4;

-- January 18 in MDY mode; rejected in other modes
SET datestyle TO MDY;
INSERT INTO DATE_TBL VALUES (5, '1/18/1999');
SELECT * FROM DATE_TBL WHERE id = 5;

SET datestyle TO YMD;
INSERT INTO DATE_TBL VALUES (6, '1/18/1999');
SELECT * FROM DATE_TBL WHERE id = 6;

-- January 2, 2003 in MDY mode; February 1, 2003 in DMY mode; February 3, 2001 in YMD mode
SET datestyle TO MDY;
INSERT INTO DATE_TBL VALUES (7, '01/02/03');
SELECT * FROM DATE_TBL WHERE id = 7;

SET datestyle TO DMY;
INSERT INTO DATE_TBL VALUES (8, '01/02/03');
SELECT * FROM DATE_TBL WHERE id = 8;

SET datestyle TO YMD;
INSERT INTO DATE_TBL VALUES (9, '01/02/03');
SELECT * FROM DATE_TBL WHERE id = 9;

-- January 8 in any mode
INSERT INTO DATE_TBL VALUES (10, '1999-Jan-08');
INSERT INTO DATE_TBL VALUES (11, 'Jan-08-1999');
INSERT INTO DATE_TBL VALUES (12, '08-Jan-1999');
SELECT * FROM DATE_TBL WHERE 10 <= id AND id <= 12;

-- January 8 in YMD mode, else error
SET datestyle TO YMD;
INSERT INTO DATE_TBL VALUES (13, '99-Jan-08');
SELECT * FROM DATE_TBL WHERE id = 13;

SET datestyle TO MDY;
INSERT INTO DATE_TBL VALUES (14, '99-Jan-08');
SELECT * FROM DATE_TBL WHERE id = 14;

-- January 8, except error in YMD mode
SET datestyle TO YMD;
INSERT INTO DATE_TBL VALUES (15, '08-Jan-99');
SELECT * FROM DATE_TBL WHERE id = 15;

SET datestyle TO MDY;
INSERT INTO DATE_TBL VALUES (16, '08-Jan-99');
SELECT * FROM DATE_TBL WHERE id = 16;

-- January 8, except error in YMD mode
SET datestyle TO YMD;
INSERT INTO DATE_TBL VALUES (17, 'Jan-08-99');
SELECT * FROM DATE_TBL WHERE id = 17;

SET datestyle TO MDY;
INSERT INTO DATE_TBL VALUES (18, 'Jan-08-99');
SELECT * FROM DATE_TBL WHERE id = 18;

-- ISO 8601; January 8, 1999 in any mode
SET datestyle TO MDY;
INSERT INTO DATE_TBL VALUES (19, '19990108');
SELECT * FROM DATE_TBL WHERE id = 19;

INSERT INTO DATE_TBL VALUES (20, '990108');
SELECT * FROM DATE_TBL WHERE id = 20;

-- year and day of year
INSERT INTO DATE_TBL VALUES (21, '1999.008');
SELECT * FROM DATE_TBL WHERE id = 21;

-- Julian date
INSERT INTO DATE_TBL VALUES (22, 'J2451187');
SELECT * FROM DATE_TBL WHERE id = 22;

--
-- Clean-up
--
DROP FOREIGN TABLE DATE_TBL CASCADE;
DROP USER MAPPING FOR public SERVER :DB_SERVERNAME;
DROP SERVER :DB_SERVERNAME;
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
