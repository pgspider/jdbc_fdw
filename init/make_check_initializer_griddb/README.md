# Initializer for GridDB Foreign Data Wrapper

This tool features:
>1. Create containers on GridDB used for "make check".
>2. If a container already exists, it is re-created.
>3. Connection parameters (like host, port, clusterName, username, password) are embedded (=fixed value).

## 1. Installation
This tool requires GridDB's C client library. This library can be downloaded from the [GridDB][1] website on github[1].

### 1.1. Preapre GridDB's C client
    Download GridDB's C client and unpack it into griddb_fdw directory as griddb.
    Build GridDB's C client  
    -> gridstore.h should be in griddb_fdw/griddb/client/c/include.
    -> libgridstore.so should be in griddb/bin.

### 1.2. Build the tool.
Change into the griddb_fdw/make_check_initializer directory.<br />
<pre>
$ make
</pre>
It creates `griddb_init` executable file.


## 2. Usage
### 2.1. Run automatically using init.sh script

We have to specify the following environment variables:<br />
GRIDDB_HOME : GridDB source directory, this source is already compiled<br />
```
export GRIDDB_HOME=${HOME}/src/griddb_nosql_4.0.0
```

Run the script:<br />
```
./init.sh
```

These informations are embedded in the script:<br />
>host : 239.0.0.1<br />
>port : 31999<br />
>clusterName : griddbfdwTestCluster<br />
>GridDB username : admin<br />
>GridDB password : testadmin<br />

### 2.2. Run manually

Change to GridDB source directory. Specify the cluster name to `griddbfdwTestCluster`<br />
```
vi ./conf/gs_cluster.json
# find the "clusterName:" and change the line to:
"clusterName":"griddbfdwTestCluster"
```

GridDB server's `admin` password have to be `testadmin`<br />

Start the node and join the cluster:<br />
```
./bin/gs_startnode -w -u admin/testadmin
./bin/gs_joincluster -w -c griddbfdwTestCluster -u admin/testadmin
```

Change to griddb_fdw/make_check_initializer directory.<br />
Initialize the containers for GridDB FDW test:<br />
```
./griddb_init host=239.0.0.1 port=31999 cluster=griddbfdwTestCluster user=admin passwd=testadmin
```
It should display message: "Initialize all containers sucessfully."
