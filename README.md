JDBC Foreign Data Wrapper for PostgreSQL
=========================================
* This PostgreSQL extension is a Foreign Data Wrapper (FDW) for JDBC.
* The current version can work with PostgreSQL 14.
* Java 5 or later is required (Confirmed version is Java OpenJDK 1.8.0).
* This jdbc_fdw is based on [JDBC\_FDW](http://github.com/atris/JDBC_FDW.git), [jdbc2\_fdw](https://github.com/heimir-sverrisson/jdbc2_fdw).  


Preparation
-----------

JDBC driver(.jar file) of the database is needed.  
For example, jar file can be found from below:  
[PostgreSQL](https://jdbc.postgresql.org/)  
[GridDB](https://github.com/griddb/jdbc)  


Installation
------------
### 1. To build jdbc_fdw, you need to symbolic link the jvm library to your path.  
```
sudo ln -s /usr/lib/jvm/[java version]/jre/lib/amd64/server/libjvm.so /usr/lib64/libjvm.so
```

### 2. Build
```
make clean
make install
```
You may have to change to root/installation privileges before executing 'make install'


### 3. Create jdbc_fdw extension.
```
CREATE EXTENSION jdbc_fdw;
```

### 4. Create a server that uses jdbc_fdw.
```
CREATE SERVER [server_name] FOREIGN DATA WRAPPER jdbc_fdw OPTIONS(
drivername '[JDBC drivername]',
url '[JDBC url]',
querytimeout '[querytimeout]',
jarfile '[the path of jarfile]',
maxheapsize '[maxheapsize]'
);
```
#### [JDBC drivername]
The name of the JDBC driver.  
Note that the driver name has to be specified for jdbc_fdw to work.  
It can be found in JDBC driver documentation.  
[PostgreSQL](https://jdbc.postgresql.org/documentation/head/load.html)
```
drivername 'org.postgresql.Driver'
```
[GridDB](http://www.toshiba-sol.co.jp/en/pro/griddb/docs-en/v4_1/GridDB_AE_JDBC_DriverGuide.html)
```
drivername 'com.toshiba.mwcloud.gs.sql.Driver'
```

#### [JDBC url]:  
The JDBC URL that shall be used to connect to the foreign database.  
Note that URL has to be specified for jdbc_fdw to work.  
It can be found in JDBC driver documentation.  
[PostgreSQL](https://jdbc.postgresql.org/documentation/head/load.html)
```
url 'jdbc:postgresql://[host]:[port]/[database]'
```
[GridDB](http://www.toshiba-sol.co.jp/en/pro/griddb/docs-en/v4_1/GridDB_AE_JDBC_DriverGuide.html)
```
url 'jdbc:gs://[host]:[port]/[clusterName]/[databaseName]'
```
#### [querytimeout]
The number of seconds that an SQL statement may execute before timing out.  
The option can be used for terminating hung queries. 

#### [the path of jarfile]  
The path and name(e.g. folder1/folder2/abc.jar) of the JAR file of the JDBC driver to be used of the foreign database. 
Note that the path must be absolute path.
```
/[path]/[jarfilename].jar
```

#### [maxheapsize]
The value of the option shall be set to the maximum heap size of the JVM which is being used in jdbc fdw. It can be set from 1 Mb onwards.  
This option is used for setting the maximum heap size of the JVM manually.

### 5. Create a user mapping for the server.
```
CREATE USER MAPPING FOR CURRENT_USER SERVER [server name] OPTIONS(username '[username]',password '[password]');
```

### 6. Create a foreign table on the server.
Example:
```
CREATE FOREIGN TABLE [table name] (id int) SERVER [server name]);
```

### 7. Query the foreign table.
Example:
```
SELECT * FROM [table name];
```

Feature
-------
#### Write-able FDW
The existing JDBC FDWs are only read-only, this version provides the write capability.  
The user can now issue an insert, update, and delete statement for the foreign tables using the jdbc_fdw. 

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
#### Arbitrary SQL query execution via function
Support execute the whole sql query and get results from the DB behind jdbc connection. This function returns a set of records.

Usage
-----
#### Write-able FDW
The user can issue an update and delete statement for the foreign table, which has set the primary key option. 

#### Primary Key
The primary key options can be set while creating a JDBC foreign table object with OPTIONS(key 'true')
```
CREATE FOREIGN TABLE [table name]([column name] [column type] OPTIONS(key 'true')) SERVER [server name];
```
#### Arbitrary SQL query execution via function
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

#### IMPORT FOREIGN SCHEMA
The following parameter is optional for import schema:  
recreate : 'true' or 'false'. If 'true', table schema will be updated.  
After schema is imported, we can access tables.  
To use CREATE FOREIGN TABLE is not recommended.  
```
IMPORT FOREIGN SCHEMA public
  FROM SERVER [server name] INTO public OPTIONS (recreate 'true');
```

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

Usage Notes
-----------
#### Maximum digits storing float value of MySQL
Maximum digits storing float value of MySQL is 6 digits. The stored value may not be the same as the value inserted.

#### Variance function
Variance function: For MySQL, variance function is alias for var_pop(). For PostgreSQL/GridDB, variance function is alias for var_samp(). Due to the different meaning of variance function between MySQL and PostgreSQL/GridDB, the result will be different.

#### Concatenation Operator
The || operator as a concatenation operator is standard SQL, however in MySQL, it represents the OR operator (logical operator). If the PIPES_AS_CONCAT SQL mode is enabled, || signifies the SQL-standard string concatenation operator (like CONCAT()). User needs to enable PIPES_AS_CONCAT mode in MySQL for concatenation.

#### Timestamp range
The MySQL timestamp range is not the same as the PostgreSQL timestamp range, so be careful if using this type. In MySQL, TIMESTAMP has a range of '1970-01-01 00:00:01' UTC to '2038-01-19 03:14:07' UTC.

Reference
---------
[JDBC\_FDW](http://github.com/atris/JDBC_FDW.git)  
[jdbc2\_fdw](https://github.com/heimir-sverrisson/jdbc2_fdw)  

Contributing
------------
Opening issues and pull requests on GitHub are welcome.

License
-------
Copyright (c) 2021, TOSHIBA CORPORATION  
Copyright (c) 2012 - 2016, Atri Sharma atri.jiit@gmail.com  

Permission to use, copy, modify, and distribute this software and its documentation for any purpose, without fee, and without a written agreement is hereby granted, provided that the above copyright notice and this paragraph and the following two paragraphs appear in all copies.

See the [`LICENSE`][1] file for full details.

[1]: LICENSE.md
