#!/bin/bash

GRIDDB_HOME=${HOME}/99_Setup/griddb-4.6.0

if [[ ! -d "${GRIDDB_HOME}" ]]; then
  echo "GRIDDB_HOME environment variable not set"
  exit 1
fi

# Start GridDB server
export GS_HOME=${GRIDDB_HOME}
export GS_LOG=${GRIDDB_HOME}/log
export no_proxy=127.0.0.1

if pgrep -x "gsserver" > /dev/null
then
  ${GRIDDB_HOME}/bin/gs_leavecluster -w -f -u admin/testadmin
  ${GRIDDB_HOME}/bin/gs_stopnode -w -u admin/testadmin
fi
sleep 1
rm -rf ${GS_HOME}/data/* ${GS_LOG}/*
echo "Starting GridDB server..."
sed -i 's/\"clusterName\":.*/\"clusterName\":\"griddbfdwTestCluster\",/' ${GRIDDB_HOME}/conf/gs_cluster.json
${GRIDDB_HOME}/bin/gs_startnode -w -u admin/testadmin
${GRIDDB_HOME}/bin/gs_joincluster -w -c griddbfdwTestCluster -u admin/testadmin

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PWD/../griddb/bin/
make clean && make
echo "Init data for GridDB..."
rm /tmp/jdbc/*.data
cp ../../data/*.data /tmp/jdbc/

result="$?"
if [[ "$result" -eq 0 ]]; then
	./griddb_init host=239.0.0.1 port=31999 cluster=griddbfdwTestCluster user=admin passwd=testadmin
fi
