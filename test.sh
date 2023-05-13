#!/bin/bash

CMDNAME=`basename $0`

while getopts t: OPT
do
  case $OPT in
     t) TARGET_DB="$OPTARG";;
     *) echo "-t (griddb/mysql/postgresql)";exit 0;;
  esac
done

mkdir -p /tmp/jdbc/
rm /tmp/jdbc/*.data
cp data/*.data /tmp/jdbc/

# this is the test case for jdbc_fdw to test on databases
# before running test, you have to: 
# install DBs and download the JDBC DB drivers
# update the db connection info in init/make_check_initializer_griddb/init.sh, init/postgresql_init.sh and init/mysql_init.sh
# update the config file in sql/configs/*.conf

case "$TARGET_DB" in
  "griddb" )
    sed -i 's/REGRESS =.*/REGRESS = griddb\/new_test griddb\/aggregates griddb\/float8 griddb\/insert griddb\/select griddb\/update griddb\/delete griddb\/float4 griddb\/int4 griddb\/int8 griddb\/ported_postgres_fdw griddb\/exec_function /' Makefile
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$(pwd)/init/make_check_initializer_griddb/griddb/bin/
    cd init/make_check_initializer_griddb
    chmod +x ./*.sh || true
    ./init.sh
    cd ../..;;
  "mysql" )
    sed -i 's/REGRESS =.*/REGRESS = mysql\/new_test mysql\/aggregates mysql\/float8 mysql\/insert mysql\/select mysql\/update mysql\/delete mysql\/float4 mysql\/int4 mysql\/int8 mysql\/ported_postgres_fdw mysql\/exec_function /' Makefile
    ./init/mysql_init.sh ;;
  "postgresql" )
    sed -i 's/REGRESS =.*/REGRESS = postgresql\/new_test postgresql\/aggregates postgresql\/float8 postgresql\/insert postgresql\/select postgresql\/update postgresql\/delete postgresql\/float4 postgresql\/int4 postgresql\/int8 postgresql\/ported_postgres_fdw postgresql\/exec_function /' Makefile
    ./init/postgresql_init.sh --start;;
  *)
    sed -i 's/REGRESS =.*/REGRESS = griddb\/new_test griddb\/aggregates griddb\/float8 griddb\/insert griddb\/select griddb\/update griddb\/delete griddb\/float4 griddb\/int4 griddb\/int8 griddb\/ported_postgres_fdw griddb\/exec_function mysql\/new_test mysql\/aggregates mysql\/float8 mysql\/insert mysql\/select mysql\/update mysql\/delete mysql\/float4 mysql\/int4 mysql\/int8 mysql\/ported_postgres_fdw mysql\/exec_function postgresql\/new_test postgresql\/aggregates postgresql\/float8 postgresql\/insert postgresql\/select postgresql\/update postgresql\/delete postgresql\/float4 postgresql\/int4 postgresql\/int8 postgresql\/ported_postgres_fdw postgresql\/exec_function /' Makefile
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$(pwd)/init/make_check_initializer_griddb/griddb/bin/
    cd init/make_check_initializer_griddb
    chmod +x ./*.sh || true
    ./init.sh
    cd ../..
    ./init/postgresql_init.sh
    ./init/mysql_init.sh ;;
esac

make clean
make install
make check | tee make_check.out
