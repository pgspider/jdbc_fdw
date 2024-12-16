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

-- jdbc_fdw does not support array type
-- Make the same tests with domains over the array and composite fields

-- create domain insert_pos_ints as int[] check (value[1] > 0);

-- create domain insert_test_domain as insert_test_type
--   check ((value).if2[1] is not null);

-- create table inserttesta (f1 int, f2 insert_pos_ints);
-- create table inserttestb (f3 insert_test_domain, f4 insert_test_domain[]);

-- insert into inserttesta (f2[1], f2[2]) values (1,2);
-- insert into inserttesta (f2[1], f2[2]) values (3,4), (5,6);
-- insert into inserttesta (f2[1], f2[2]) select 7,8;
-- insert into inserttesta (f2[1], f2[2]) values (1,default);  -- not supported
-- insert into inserttesta (f2[1], f2[2]) values (0,2);
-- insert into inserttesta (f2[1], f2[2]) values (3,4), (0,6);
-- insert into inserttesta (f2[1], f2[2]) select 0,8;

-- insert into inserttestb (f3.if1, f3.if2) values (1,array['foo']);
-- insert into inserttestb (f3.if1, f3.if2) values (1,'{foo}'), (2,'{bar}');
-- insert into inserttestb (f3.if1, f3.if2) select 3, '{baz,quux}';
-- insert into inserttestb (f3.if1, f3.if2) values (1,default);  -- not supported
-- insert into inserttestb (f3.if1, f3.if2) values (1,array[null]);
-- insert into inserttestb (f3.if1, f3.if2) values (1,'{null}'), (2,'{bar}');
-- insert into inserttestb (f3.if1, f3.if2) select 3, '{null,quux}';

-- insert into inserttestb (f3.if2[1], f3.if2[2]) values ('foo', 'bar');
-- insert into inserttestb (f3.if2[1], f3.if2[2]) values ('foo', 'bar'), ('baz', 'quux');
-- insert into inserttestb (f3.if2[1], f3.if2[2]) select 'bear', 'beer';

-- insert into inserttestb (f3, f4[1].if2[1], f4[1].if2[2]) values (row(1,'{x}'), 'foo', 'bar');
-- insert into inserttestb (f3, f4[1].if2[1], f4[1].if2[2]) values (row(1,'{x}'), 'foo', 'bar'), (row(2,'{y}'), 'baz', 'quux');
-- insert into inserttestb (f3, f4[1].if2[1], f4[1].if2[2]) select row(1,'{x}')::insert_test_domain, 'bear', 'beer';

-- select * from inserttesta;
-- select * from inserttestb;

-- -- also check reverse-listing
-- create table inserttest2 (f1 bigint, f2 text);
-- create rule irule1 as on insert to inserttest2 do also
--   insert into inserttestb (f3.if2[1], f3.if2[2])
--   values (new.f1,new.f2);
-- create rule irule2 as on insert to inserttest2 do also
--   insert into inserttestb (f4[1].if1, f4[1].if2[2])
--   values (1,'fool'),(new.f1,new.f2);
-- create rule irule3 as on insert to inserttest2 do also
--   insert into inserttestb (f4[1].if1, f4[1].if2[2])
--   select new.f1, new.f2;
-- \d+ inserttest2

-- drop table inserttest2;
-- drop table inserttesta;
-- drop table inserttestb;
-- drop domain insert_pos_ints;
-- drop domain insert_test_domain;

-- Verify that multiple inserts to subfields of a domain-over-container
-- check the domain constraints only on the finished value

-- create domain insert_nnarray as int[]
--   check (value[1] is not null and value[2] is not null);

-- create domain insert_test_domain as insert_test_type
--   check ((value).if1 is not null and (value).if2 is not null);

-- create table inserttesta (f1 insert_nnarray);
-- insert into inserttesta (f1[1]) values (1);  -- fail
-- insert into inserttesta (f1[1], f1[2]) values (1, 2);

-- create table inserttestb (f1 insert_test_domain);
-- insert into inserttestb (f1.if1) values (1);  -- fail
-- insert into inserttestb (f1.if1, f1.if2) values (1, '{foo}');

-- drop table inserttesta;
-- drop table inserttestb;
-- drop domain insert_nnarray;
-- drop type insert_test_type cascade;

--Testcase 35:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 36:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
