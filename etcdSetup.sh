#!/bin/bash


# This script is based on the use of the word etcd followed by a numeric value such as etcd1 as node names for the etcs servers
# and thier entries in /etc/hosts file.
# Therefore, we will use etcd1 for nodename, etcd2 ....  Even if we are on a node named after the database server such as patronidb1.
#
# for example, this is what our hosts file looks like after you have made the necessary edits.

#192.168.50.10   patronidb1 etcd1
#192.168.50.11   patronidb2 etcd2
#192.168.50.12   patronidb3 etcd3
#192.168.50.13   etcd4
#192.168.50.14   etcd5

yaml=0
confFile="/pgha/config/etcd.conf"

if [[ "$#" -ge 1 && "$1" == "-y" ]]; then
        yaml=1
        confFile="/pgha/config/etcd.yaml"
fi

thisNodeIp=$(hostname -i)
thisNode=$(hostname)

# Get the etcd alias name from /etc/hosts based on this nodes realname
# -o only-matching, in grep makes sure that only the match is printed and not the whole line
# -E extended-regex, in grep allows for moe use of + operator. In our case we are looking for one or more digits after etcd
# \b ensures the match starts with exactly etcd and ends with a digit. This avoids other similar words like myetcd1

etcdNodeName=$(grep "$thisNode" /etc/hosts | grep -oE '\betcd[0-9]+\b')

if [ "$etcdNodeName" == "" ]; then
        echo "No etcd node name or alias found in /etc/hosts for server $thisNode"
        exit
fi

initialCluster=""
endPoints="export ENDPOINTS=\""
patroniEtcdNodes=""
tokenName="pgha-token"
etcdDataDir="/pgha/data/etcd"
confBaseDir="/pgha/"
patroniVarFile="/pgha/config/patroniVars"
patroniConf="/pgha/config/patroni.yaml"

if [ ! -d "$confBaseDir" ]; then
    echo -e "ERROR: The directory '$confBaseDir' or it's sub directories do not exist."
    echo -e "Please create the necessary directory structure needed for this deploy"
    echo -e
    echo -e "\tmkdir -p /pgha/{config,certs,data/{etcd,postgres}}"
    echo -e "\tchown -R postgres:postgres /pgha"
    echo -e
    exit
fi



for i in {1..5}; do
   node="etcd${i}"
   nodeIp=$(grep "$node" /etc/hosts | awk '{print $1; exit}')
   initialCluster=$initialCluster"${node}=http://${nodeIp}:2380,"
   patroniEtcdNodes=$patroniEtcdNodes"${node}:2379,"
   endPoints=$endPoints"${node}:2380,"
done;

initialCluster="${initialCluster%,}"   # -- Remove last comma
patroniEtcdNodes="${patroniEtcdNodes%,}"   # -- Remove last comma
endPoints="${endPoints%,}""\""   # -- Remove last comma and close the double quotes

if [ $yaml -eq 0 ]; then

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


if [ $yaml -eq 1 ]; then

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

echo "ETCD_NODES=\"${patroniEtcdNodes}\"" > $patroniVarFile
echo "NODE_NAME=\"${thisNode}\"" >> $patroniVarFile
echo "PATRONI_CFG=\"${patroniConf}\"" >> $patroniVarFile
echo "DATADIR=\"${PGDATA}\"" >> $patroniVarFile
echo "CFG_DIR=\"/pgha/config\"" >> $patroniVarFile
echo "PG_BIN_DIR=\"/usr/pgsql-17/bin/\"" >> $patroniVarFile
echo "NAMESPACE=\"pgha\"" >> $patroniVarFile
echo "SCOPE=\"pgha_patroni_cluster\"" >> $patroniVarFile
