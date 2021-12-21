Usage
-----------
#### Variance function
For MySQL, variance function is alias for var_pop().

For example:

```
SELECT variance(c1) FROM tbl04 WHERE c3 <> 'aef';
      variance      
--------------------
 194362960.38635424
(1 row)
```

For PostgreSQL/GridDB, variance function is alias for var_samp().

For example:
```
SELECT variance(c1) FROM tbl04 WHERE c3 <> 'aef';
     variance      
-------------------
 218658330.4346485
(1 row)
```

#### Storing float value
[Maximum digits storing float value](https://bugs.mysql.com/bug.php?id=87794) is 6 digits. The stored value may not be the same as the value inserted.

For example:
```
INSERT INTO float4_tbl(f1) VALUES (2147483647);
SELECT f1 FROM float4_tbl;
     f1       
------------
 2147480000
```

Due to the different meaning of variance function between MySQL and PostgreSQL/GridDB, so the result in MySQL will be different.

#### Concatenation Operator
The `||` operator as a concatenation operator is standard SQL, however in MySQL, it represents the OR operator (logical operator)
If the PIPES_AS_CONCAT SQL mode is enabled, || signifies the SQL-standard string concatenation operator (like CONCAT()).
User needs to enable PIPES_AS_CONCAT mode in MySQL for concatenation.

#### Timestamp range
The MySQL timestamp range is not the same as the PostgreSQL timestamp range, so be careful if using this type.   
[Timestamp range](https://dev.mysql.com/doc/refman/8.0/en/datetime.html) in MySQL:
```
TIMESTAMP has a range of '1970-01-01 00:00:01' UTC to '2038-01-19 03:14:07' UTC.
```
