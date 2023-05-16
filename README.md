JDBC Foreign Data Wrapper for PostgreSQL
============================================

This is a foreign data wrapper (FDW) to connect [PostgreSQL](https://www.postgresql.org/)
to any Java DataBase Connectivity (JDBC) data source.

This `jdbc_fdw` is based on [JDBC\_FDW](http://github.com/atris/JDBC_FDW.git) and [jdbc2\_fdw](https://github.com/heimir-sverrisson/jdbc2_fdw).

<img src="https://upload.wikimedia.org/wikipedia/commons/2/29/Postgresql_elephant.svg" align="center" height="100" alt="PostgreSQL"/>	+	<img src="https://1000logos.net/wp-content/uploads/2020/09/Java-Logo-500x313.png" align="center" height="100" alt="JDBC"/>


Contents
--------

1. [Features](#features)
2. [Supported platforms](#supported-platforms)
3. [Installation](#installation)
4. [Usage](#usage)
5. [Functions](#functions)
6. [Identifier case handling](#identifier-case-handling)
7. [Generated columns](#generated-columns)
8. [Character set handling](#character-set-handling)
9. [Examples](#examples)
10. [Limitations](#limitations)
11. [Contributing](#contributing)
12. [Useful links](#useful-links)
13. [License](#license)

Features
--------
### Common features

#### Write-able FDW
The existing JDBC FDWs are only read-only, this version provides the write capability.
The user can now issue an insert, update, and delete statement for the foreign tables using the jdbc_fdw.

#### Arbitrary SQL query execution via function
Support execute the whole sql query and get results from the DB behind jdbc connection. This function returns a set of records.

Syntax:
```
jdbc_exec(text connname, text sql);
```

Example:  
To get a set of record, use the below sql query:
```
SELECT jdbc_exec(jdbc_svr, 'SELECT * FROM tbl');
              jdbc_exec                 
----------------------------------------
 (1,abc,"Fri Dec 31 16:00:00 1999 PST")
 (2,def,"Fri Dec 31 16:00:00 1999 PST")
 ```
To get a set of record with separate data for each column, use the below sql query:
```
SELECT * FROM jdbc_exec(jdbc_svr, 'SELECT * FROM tbl') as t(id int, c1 text, c2 timestamptz);
 id |  c1 |              c2              
----+-----+------------------------------
  1 | abc | Fri Dec 31 16:00:00 1999 PST
  2 | def | Fri Dec 31 16:00:00 1999 PST
```

### Pushdowning

#### WHERE clause push-down
The jdbc_fdw will push-down the foreign table where clause to the foreign server.
The where condition on the foreign table will be executed on the foreign server, hence there will be fewer rows to bring across to PostgreSQL.
This is a performance feature.

#### Column push-down
The existing JDBC FDWs are fetching all the columns from the target foreign table.
The latest version does the column push-down and only brings back the columns that are part of the select target list.
This is a performance feature.

#### Aggregate function push-down
List of aggregate functions push-down:
```
sum, avg, stddev, stddev_pop, stddev_samp, var_pop, var_samp, variance, max, min, count.
```
### Notes about features

#### Maximum digits storing float value of MySQL
Maximum digits storing float value of MySQL is 6 digits. The stored value may not be the same as the value inserted.

#### Variance function
Variance function: For MySQL, variance function is alias for var_pop(). For PostgreSQL/GridDB, variance function is alias for var_samp(). Due to the different meaning of variance function between MySQL and PostgreSQL/GridDB, the result will be different.

#### Concatenation Operator
The || operator as a concatenation operator is standard SQL, however in MySQL, it represents the OR operator (logical operator). If the PIPES_AS_CONCAT SQL mode is enabled, || signifies the SQL-standard string concatenation operator (like CONCAT()). User needs to enable PIPES_AS_CONCAT mode in MySQL for concatenation.

#### Timestamp range
The MySQL timestamp range is not the same as the PostgreSQL timestamp range, so be careful if using this type. In MySQL, TIMESTAMP has a range of '1970-01-01 00:00:01' UTC to '2038-01-19 03:14:07' UTC.

#### Write-able FDW
The user can issue an update and delete statement for the foreign table, which has set the primary key option.


Supported platforms
-------------------

`jdbc_fdw` was developed on Linux, and should run on any
reasonably POSIX-compliant system.

`jdbc_fdw` is designed to be compatible with PostgreSQL 10 ~ 15.
Java 5 or later is required (Confirmed version is Java OpenJDK 1.8.0).

Installation
------------

### Source installation

Prerequisites:

- JDBC driver(.jar file) of the database is needed.
For example, jar file can be found from below:
[PostgreSQL](https://jdbc.postgresql.org/)
[GridDB](https://github.com/griddb/jdbc)

1. To build jdbc_fdw, you need to symbolic link the jvm library to your path.

```
sudo ln -s /usr/lib/jvm/[java version]/jre/lib/amd64/server/libjvm.so /usr/lib64/libjvm.so
```

2. Build
```
make clean
make install
```
You may have to change to root/installation privileges before executing 'make install'

Usage
-----

## CREATE SERVER options

`jdbc_fdw` accepts the following options via the `CREATE SERVER` command:

- **drivername** as *string*
		
  The name of the JDBC driver.
  Note that the driver name has to be specified for jdbc_fdw to work.
  It can be found in JDBC driver documentation.
  * [PostgreSQL](https://jdbc.postgresql.org/documentation/head/load.html) `drivername 'org.postgresql.Driver'`
  * [GridDB](http://www.toshiba-sol.co.jp/en/pro/griddb/docs-en/v4_1/GridDB_AE_JDBC_DriverGuide.html) `drivername 'com.toshiba.mwcloud.gs.sql.Driver'`

- **url** as *string*

  The JDBC URL that shall be used to connect to the foreign database.
  Note that URL has to be specified for jdbc_fdw to work.
  It can be found in JDBC driver documentation.
  * [PostgreSQL](https://jdbc.postgresql.org/documentation/head/load.html) `url 'jdbc:postgresql://[host]:[port]/[database]'`
  * [GridDB](http://www.toshiba-sol.co.jp/en/pro/griddb/docs-en/v4_1/GridDB_AE_JDBC_DriverGuide.html) `url 'jdbc:gs://[host]:[port]/[clusterName]/[databaseName]'`

- **querytimeout** as *integer*

  The number of seconds that an SQL statement may execute before timing out.
  The option can be used for terminating hung queries.

- **jarfile** as *string*

  The path and name(e.g. folder1/folder2/abc.jar) of the JAR file of the JDBC driver to be used of the foreign database.
Note that the path must be absolute path.
```
/[path]/[jarfilename].jar
```

- **maxheapsize** as *integer*
  
  The value of the option shall be set to the maximum heap size of the JVM which is being used in jdbc fdw. It can be set from 1 Mb onwards. This option is used for setting the maximum heap size of the JVM manually.


## CREATE USER MAPPING options

`jdbc_fdw` accepts the following options via the `CREATE USER MAPPING`
command:

- **username**

  The JDBC username to connect as.

- **password**


  The JDBC user's password.

## CREATE FOREIGN TABLE options

`jdbc_fdw` accepts the no table-level options via the
`CREATE FOREIGN TABLE` command.

The following column-level options are available:

- **key** as *boolean*

  The primary key options can be set while creating a JDBC foreign table object with OPTIONS(key 'true')
```
CREATE FOREIGN TABLE [table name]([column name] [column type] OPTIONS(key 'true')) SERVER [server name];
```
Note that while PostgreSQL allows a foreign table to be defined without
any columns, `jdbc_fdw` *can* raise an error as soon as any operations
are carried out on it.


## IMPORT FOREIGN SCHEMA options

`jdbc_fdw` supports [IMPORT FOREIGN SCHEMA](https://www.postgresql.org/docs/current/sql-importforeignschema.html)
(when running with PostgreSQL 9.5 or later) and accepts the following custom options:

- **recreate** as *boolean*

  If 'true', table schema will be updated.
After schema is imported, we can access tables.

## TRUNCATE support

`jdbc_fdw` yet don't implements the foreign data wrapper `TRUNCATE` API, available
from PostgreSQL 14.

Functions
---------

Functions from this FDW in PostgreSQL catalog are **yet not described**.


Identifier case handling
------------------------

PostgreSQL folds identifiers to lower case by default, JDBC data source can have different behaviour.
Rules and problems **yet not tested and described**.

Generated columns
-----------------

Behaviour within generated columns **yet not tested and described**. 

`jdbc_fdw` potentially can provide support for PostgreSQL's generated
columns (PostgreSQL 12+).

Note that while `jdbc_fdw` will insert or update the generated column value
in JDBC, there is nothing to stop the value being modified within JDBC,
and hence no guarantee that in subsequent `SELECT` operations the column will
still contain the expected generated value. This limitation also applies to
`postgres_fdw`.

For more details on generated columns see:

- [Generated Columns](https://www.postgresql.org/docs/current/ddl-generated-columns.html)
- [CREATE FOREIGN TABLE](https://www.postgresql.org/docs/current/sql-createforeigntable.html)


Character set handling
----------------------

**Yet not described**. JDBC is UTF-8 by default.

Examples
--------

Install the extension:

    CREATE EXTENSION jdbc_fdw;

Create a foreign server with appropriate configuration:

	CREATE SERVER [server_name] FOREIGN DATA WRAPPER jdbc_fdw
		OPTIONS(
			drivername '[JDBC drivername]',
			url '[JDBC url]',
			querytimeout '[querytimeout]',
			jarfile '[the path of jarfile]',
			maxheapsize '[maxheapsize]'
		);

Create an appropriate user mapping:

    CREATE USER MAPPING FOR CURRENT_USER SERVER [server name] 
    	OPTIONS(username '[username]',password '[password]');

Create a foreign table referencing the JDBC table `fdw_test`:

	CREATE FOREIGN TABLE [table name] (id int) SERVER [server name]);


Query the foreign table.

	SELECT * FROM [table name];

Import a JDBC schema:

	IMPORT FOREIGN SCHEMA public
	  FROM SERVER [server name]
	  INTO public
	  OPTIONS (recreate 'true');


Limitations
-----------
#### Unsupported clause
The following clasues are not support in jdbc_fdw:
RETURNING, GROUPBY, ORDER BY clauses, casting type, transaction control

#### Array Type
Currently, jdbc_fdw doesn't support array type.

#### Floating-point value comparison
Floating-point numbers are approximate and not stored as exact values. A floating-point value as written in an SQL statement may not be the same as the value represented internally.

For example:

```
SELECT float4.f1 FROM FLOAT4_TBL tbl06 WHERE float4.f1 <> '1004.3';
     f1
-------------
           0
      1004.3
      -34.84
 1.23457e+20
 1.23457e-20
(5 rows)
```
In order to get correct result, can decide on an acceptable tolerance for differences between the numbers and then do the comparison against the tolerance value to that can get the correct result.
```
SELECT float4.f1 FROM tbl06 float4 WHERE float4.f1 <> '1004.3' GROUP BY float4.id, float4.f1 HAVING abs(f1 - 1004.3) > 0.001 ORDER BY float4.id;
     f1
-------------
           0
      -34.84
 1.23457e+20
 1.23457e-20
(4 rows)
```

#### IMPORT FOREIGN SCHEMA
Currently, IMPORT FOREIGN SCHEMA works only with GridDB.

Contributing
------------
Opening issues and pull requests on GitHub are welcome.

Useful links
------------

### Source code

 - [JDBC\_FDW](http://github.com/atris/JDBC_FDW.git)
 - [jdbc2\_fdw](https://github.com/heimir-sverrisson/jdbc2_fdw)
 
 Reference FDW realisation, `postgres_fdw`
 - https://git.postgresql.org/gitweb/?p=postgresql.git;a=tree;f=contrib/postgres_fdw;hb=HEAD

### General FDW Documentation

 - https://www.postgresql.org/docs/current/ddl-foreign-data.html
 - https://www.postgresql.org/docs/current/sql-createforeigndatawrapper.html
 - https://www.postgresql.org/docs/current/sql-createforeigntable.html
 - https://www.postgresql.org/docs/current/sql-importforeignschema.html
 - https://www.postgresql.org/docs/current/fdwhandler.html
 - https://www.postgresql.org/docs/current/postgres-fdw.html

### Other FDWs

 - https://wiki.postgresql.org/wiki/Fdw
 - https://pgxn.org/tag/fdw/
 
License
-------
Copyright (c) 2021, TOSHIBA CORPORATION
Copyright (c) 2012 - 2016, Atri Sharma atri.jiit@gmail.com

Permission to use, copy, modify, and distribute this software and its documentation for any purpose, without fee, and without a written agreement is hereby granted, provided that the above copyright notice and this paragraph and the following two paragraphs appear in all copies.

See the [`LICENSE`][1] file for full details.

[1]: LICENSE.md 
