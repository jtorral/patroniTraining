#!/bin/bash

function usage() {
cat << EOF

Usage: $(basename "$0") options

Description:

Use this script to generate the etcd config file for boot strapping your system. etcd Config files are plain text or yaml files
based on the way you start the etcd service. If you are manually starting etcd and specifying a config file location especially if
you are using the Docker image rocky9-pg17-bundle you will need the yaml file version.

There is an environment variable called NODELIST which is set at Docker run. This variable is used to determine the host names of all
the containers in your cluster if you decide to use the actual hostnames of each container instead of the etcd alias for the etcd
and patroni configs.

When you docker exec into a container, the variable is set there. You are most likely logged in as root or a user other than postgres.
To su as user postgres from that initial shell, and preseve that environment variable, use:

        sudo -E -u postgres /bin/bash -l

You can disregard this if you plan on using etcd alias names in /etc/hosts instead. Just make sure the alias starts with etcd and ends with a
number like etcd1, etcd2, etcd3 and so on.



Options:
  -y    Generate a yaml config file. ( Needed when starting etcd with the --config-file option )
  -e    Use etcd names instead of actual hostname. Requires alias entries in /etc/hosts that have an etcd name alias
        next to each hostname. For example:

                192.168.50.10   hostname   etcd1

EOF
exit 1
}

useYaml=0
confFile="/pgha/config/etcd.conf"
#confFile="/tmp/etcd.conf"

useEtcd=0

while getopts ye option
do                                                                                                                                                  case $option in
      y) useYaml=1;;
      e) useEtcd=1;;
      *) usage;;
   esac
done
shift $(($OPTIND - 1))

if [ $useYaml -eq 1 ]; then
        yaml=1
        confFile="/pgha/config/etcd.yaml"
        #confFile="/tmp/etcd.yaml"
fi

# ---------------------
# Define some variables
# ---------------------

thisNodeIp=$(hostname -i)
thisNode=$(hostname)
initialCluster=""
endPoints="export ENDPOINTS=\""
patroniEtcdNodes=""
tokenName="pgha-token"
etcdDataDir="/pgha/data/etcd"
confBaseDir="/pgha/"
patroniVarFile="/pgha/config/patroniVars"
#patroniVarFile="/tmp/patroniVars"
patroniConf="/pgha/config/patroni.yaml"
#patroniConf="/tmp/patroni.yaml"

if [ ! -d "$confBaseDir" ]; then
    echo -e
    echo -e "ERROR: The directory '$confBaseDir' or it's sub directories do not exist."
    echo -e "Please create the necessary directory structure needed for this deploy"
    echo -e
    echo -e "\tmkdir -p /pgha/{config,certs,data/{etcd,postgres}}"
    echo -e "\tchown -R postgres:postgres /pgha"
    echo -e
    exit 1
fi

# ---------------------------------------------------------------
# Are we using the names etcd1 ... or th hostnames for the config
# ---------------------------------------------------------------

if [ $useEtcd -eq 1 ]; then

   # -------------------------------------------------------------------------------------------------------------------------
   # Get the etcd alias name from /etc/hosts based on this nodes realname
   # -o only-matching, in grep makes sure that only the match is printed and not the whole line
   # -E extended-regex, in grep allows for moe use of + operator. In our case we are looking for one or more digits after etcd
   # \b ensures the match starts with exactly etcd and ends with a digit. This avoids other similar words like myetcd1
   # -------------------------------------------------------------------------------------------------------------------------

   etcdNodeName=$(grep "$thisNode" /etc/hosts | grep -oE '\betcd[0-9]+\b')

   if [ "$etcdNodeName" == "" ]; then
      echo -e
      echo -e "\tNo etcd alias name found in /etc/hosts for server $thisNode"
      echo -e "\tYou will need entries in the /etc/host file for each node in your cluster similiar to:"
      echo -e
      echo -e "\t$thisNodeIp   $thisNode etcd1"
      echo -e
      echo -e "\tNotice the etcd1 alias after the $thisNode"
      echo -e
      exit 1
   fi

   nodeCount=$(echo $NODELIST | wc -w )
   for (( i=1; i<=$nodeCount; i++ )); do
      node="etcd${i}"
      nodeIp=$(grep "$node" /etc/hosts | awk '{print $1; exit}')
      initialCluster=$initialCluster"${node}=http://${nodeIp}:2380,"
      patroniEtcdNodes=$patroniEtcdNodes"${node}:2379,"
      endPoints=$endPoints"${node}:2380,"
   done;
fi


if [ $useEtcd -eq 0 ]; then

   if [[ -z "$NODELIST" ]]; then
      echo -e
      echo -e "\tERROR: Environment variable NODELIST is UNSET or EMPTY."
      echo -e
      echo -e "\tIf you are running this as user postgres, you most likely ran \"su - postgres\" from the root shell"
      echo -e "\tExit this shell and run \"sudo -E -u postgres /bin/bash -l\" instead. This will preseve previous shell environment variables."
      echo -e "\tOr, just set the environment variable NODELIST directly in this shell."
      echo -e
      exit 1
   fi

   etcdNodeName=$thisNode
   for node_pair in $NODELIST; do
      IFS=':' read -r hostname ip <<< "$node_pair"
      node="$hostname"
      nodeIp="$ip"
      initialCluster=$initialCluster"${node}=http://${nodeIp}:2380,"
      patroniEtcdNodes=$patroniEtcdNodes"${node}:2379,"
      endPoints=$endPoints"${node}:2380,"
   done
fi

# --------------------------------------------------------------------------------
# Clean up the generated variables and remove trailing comas or add closing quotes
# --------------------------------------------------------------------------------

initialCluster="${initialCluster%,}"   # -- Remove last comma
patroniEtcdNodes="${patroniEtcdNodes%,}"   # -- Remove last comma
endPoints="${endPoints%,}""\""   # -- Remove last comma and close the double quotes

# ---------------------------------------------------
# Are we generating yaml or regular text config files
# ---------------------------------------------------

if [ $useYaml -eq 0 ]; then

cat << EOF > $confFile

ETCD_NAME=$etcdNodeName
ETCD_INITIAL_CLUSTER="$initialCluster"
ETCD_INITIAL_CLUSTER_TOKEN="$tokenName"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://${thisNodeIp}:2380"
ETCD_DATA_DIR="${etcdDataDir}"
ETCD_LISTEN_PEER_URLS="http://${thisNodeIp}:2380"
ETCD_LISTEN_CLIENT_URLS="http://${thisNodeIp}:2379,http://localhost:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://${thisNodeIp}:2379"

EOF

fi

if [ $useYaml -eq 1 ]; then

cat << EOF > $confFile

name: $etcdNodeName
initial-cluster: "$initialCluster"
initial-cluster-token: $tokenName
data-dir: ${etcdDataDir}
initial-cluster-state: new
initial-advertise-peer-urls: "http://${thisNodeIp}:2380"
listen-peer-urls: "http://${thisNodeIp}:2380"
listen-client-urls: "http://${thisNodeIp}:2379,http://localhost:2379"
advertise-client-urls: "http://${thisNodeIp}:2379"

EOF


fi


chown postgres:postgres $confFile

cat $confFile

echo
echo -e "Add the following environment variable to your profile for easy access to the etcd endpoints"
echo -e
echo -e "\t$endPoints"
echo -e


# ---------------------------------------------------------------------------------------------
# Write variables to a file that will be sourced by the scriptthat generates the patroni config
# ---------------------------------------------------------------------------------------------

echo "ETCD_NODES=\"${patroniEtcdNodes}\"" > $patroniVarFile
echo "NODE_NAME=\"${thisNode}\"" >> $patroniVarFile
echo "PATRONI_CFG=\"${patroniConf}\"" >> $patroniVarFile
echo "DATADIR=\"${PGDATA}\"" >> $patroniVarFile
echo "CFG_DIR=\"/pgha/config\"" >> $patroniVarFile
echo "PG_BIN_DIR=\"/usr/pgsql-17/bin/\"" >> $patroniVarFile
echo "NAMESPACE=\"pgha\"" >> $patroniVarFile
echo "SCOPE=\"pgha_patroni_cluster\"" >> $patroniVarFile
