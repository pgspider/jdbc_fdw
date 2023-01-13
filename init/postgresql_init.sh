#!/bin/sh
export PDB_PORT="5444"
export PDB_NAME="testdb"
export PGS_BIN_DIR="/home/jenkins/01_PostgreSQL/postgres-REL_13_0/PGS/"
export FDW_DIR="/home/jenkins/01_PostgreSQL/postgres-REL_13_0/contrib/jdbc_fdw"

cd $PGS_BIN_DIR/bin

if [[ "--start" == $1 ]]
then
    #Start Postgres
    if ! [ -d "../test_jdbc_database" ];
    then
        ./initdb ../test_jdbc_database
        sed -i "s~#port = 5432.*~port = $PDB_PORT~g" ../test_jdbc_database/postgresql.conf
        ./pg_ctl -D ../test_jdbc_database -l /dev/null start
        sleep 2
        ./createdb -p $PDB_PORT $PDB_NAME
    fi
    if ! ./pg_isready -p $PDB_PORT
    then
        echo "Start PostgreSQL"
        ./pg_ctl -D ../test_jdbc_database -l /dev/null start
        sleep 2
    fi
fi
./dropdb -p $PDB_PORT $PDB_NAME
./createdb -p $PDB_PORT $PDB_NAME
./psql -q -A -t -d $PDB_NAME -p $PDB_PORT -f $FDW_DIR/init/postgresql_init_post.sql
./psql -q -A -t -d $PDB_NAME -p $PDB_PORT -f $FDW_DIR/init/postgresql_init_core.sql
./psql -q -A -t -d $PDB_NAME -p $PDB_PORT -f $FDW_DIR/init/postgresql_init_extra.sql

