--
-- insert with DEFAULT in the target_list
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
create foreign table inserttest (id serial OPTIONS (key 'true'), col1 int4, col2 int4 NOT NULL, col3 text default 'testing') SERVER :DB_SERVERNAME OPTIONS ( table_name 'inserttest');
--Testcase 5:
EXPLAIN VERBOSE
insert into inserttest (col1, col2, col3) values (DEFAULT, DEFAULT, DEFAULT);
--Testcase 6:
insert into inserttest (col1, col2, col3) values (DEFAULT, DEFAULT, DEFAULT);
--Testcase 7:
EXPLAIN VERBOSE
insert into inserttest (col2, col3) values (3, DEFAULT);
--Testcase 8:
insert into inserttest (col2, col3) values (3, DEFAULT);
--Testcase 9:
EXPLAIN VERBOSE
insert into inserttest (col1, col2, col3) values (DEFAULT, 5, DEFAULT);
--Testcase 10:
insert into inserttest (col1, col2, col3) values (DEFAULT, 5, DEFAULT);
--Testcase 11:
EXPLAIN VERBOSE
insert into inserttest(col1, col2, col3) values (DEFAULT, 5, 'test');
--Testcase 12:
insert into inserttest(col1, col2, col3) values (DEFAULT, 5, 'test');
--Testcase 13:
EXPLAIN VERBOSE
insert into inserttest(col1, col2) values (DEFAULT, 7);
--Testcase 14:
insert into inserttest(col1, col2) values (DEFAULT, 7);
--Testcase 15:
select col1, col2, col3 from inserttest;

--
-- insert with similar expression / target_list values (all fail)
--
--Testcase 16:
EXPLAIN VERBOSE
insert into inserttest (col1, col2, col3) values (DEFAULT, DEFAULT);
--Testcase 17:
insert into inserttest (col1, col2, col3) values (DEFAULT, DEFAULT);
--Testcase 18:
EXPLAIN VERBOSE
insert into inserttest (col1, col2, col3) values (1, 2);
--Testcase 19:
insert into inserttest (col1, col2, col3) values (1, 2);
--Testcase 20:
EXPLAIN VERBOSE
insert into inserttest (col1) values (1, 2);
--Testcase 21:
insert into inserttest (col1) values (1, 2);
--Testcase 22:
EXPLAIN VERBOSE
insert into inserttest (col1) values (DEFAULT, DEFAULT);
--Testcase 23:
insert into inserttest (col1) values (DEFAULT, DEFAULT);
--Testcase 24:
EXPLAIN VERBOSE
select col1, col2, col3 from inserttest;
--Testcase 25:
select col1, col2, col3 from inserttest;
--
-- VALUES test
--
--Testcase 26:
EXPLAIN VERBOSE
insert into inserttest(col1, col2, col3) values(10, 20, '40'), ( -1, 2, DEFAULT),
    ((select 2), (select i from (values(3)) as foo (i)), 'values are fun!');
--Testcase 27:
insert into inserttest(col1, col2, col3) values(10, 20, '40'), (-1, 2, DEFAULT),
    ( (select 2), (select i from (values(3)) as foo (i)), 'values are fun!');
--Testcase 28:
EXPLAIN VERBOSE
select col1, col2, col3 from inserttest;
--Testcase 29:
select col1, col2, col3 from inserttest;
--
-- TOASTed value test
--
--Testcase 30:
EXPLAIN VERBOSE
insert into inserttest values(11, 30, 50, repeat('x', 10000));
--Testcase 31:
insert into inserttest values(11, 30, 50, repeat('x', 10000));
--Testcase 32:
EXPLAIN VERBOSE
select col1, col2, char_length(col3) from inserttest;
--Testcase 33:
select col1, col2, char_length(col3) from inserttest;
--Testcase 34:
drop foreign table inserttest;

--Testcase 35:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 36:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
