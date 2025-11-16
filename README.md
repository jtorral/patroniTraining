

# Postgres High Availability with Patroni.  


If you're reading this, you are likely already familiar with Patroni. This powerful tool elegantly solves the problem of high availability for Postgres by orchestrating replication, failover, and self healing. Patroni's primary function is to turn a collection of standard Postgres instances into a robust, resilient cluster.

This tutorial is designed not only to guide you through setting up a highly available Postgres cluster with Patroni, but also to equip you with the fundamental concepts needed to avoid the critical pitfalls that plague many production deployments. To focus purely on the architecture and consensus mechanics without complex installation steps, we will be leveraging Docker containers. These containers conveniently include Postgres, Patroni, and etcd with many necessary dependencies pre-configured. We will carefully walk through the configuration and setup process, ensuring you gain a complete and clear understanding of how these components interact and how to properly secure your critical quorum for true high availability.


## A Critical Misconception. Your etcd Quorum

There is a fundamental part of the Patroni architecture that is often **grossly** **overlooked** or **misunderstood**, the role and sizing of the Distributed Consensus Store. In the context of Patroni, this is typically etcd.

Patroni uses etcd to elect the primary, register cluster members, and ensure that only one node believes it is the leader at any given time, a concept known as a quorum. **If you come from the mindset that the number of etcd nodes you need is simply based on the number of Postgres nodes divided by two, plus one, you have been profoundly misled.**

***etcd nodes = ( postgres nodes / 2 ) + 1***

This rule of thumb is a common source of confusion and instability! **The size of your etcd cluster is independent of your Postgres node count** and is governed only by the need to maintain a reliable quorum for etcd itself. 

Understanding why and how to size your etcd cluster correctly is essential for true high availability, and you **must** read the following to learn the proper methodology.

## Why Your Patroni Node Count Doesn't Determine Your etcd Quorum

The core misunderstanding is failing to distinguish between the Patroni cluster (your data layer) and the etcd cluster (your consensus layer).

**Patroni/Postgres Nodes (Data):**

*These nodes are the actual database servers. Their count determines how many copies of the data you have and where the Primary can run.*

**etcd Nodes (Consensus):** 

*These nodes hold the metadata about the cluster (who the current Primary is, who the members are, etc.). They use an algorithm like Raft to ensure this metadata is consistently agreed upon by a quorum.*

The availability of your Patroni cluster relies entirely on the availability of its etcd quorum. If the etcd cluster loses its quorum, Patroni cannot safely elect a new Primary or switch roles, even if the underlying Postgres data nodes are healthy.

On a side note, this heavy dependency on etcd and the Patroni layer managing Postgres, is why I favor pgPool in some cases.

## The Correct etcd Quorum Sizing Rule

The sizing of the etcd cluster is based on the concept of fault tolerance, defined by the number of simultaneous etcd node failures. 

Lets take the common misconception of a scenario where you have a Postgres cluster of 3 database servers managed by Patroni.  Most likely, you placed the etcd service on each of the Postgres database server.  You probably think that you just need 3 etcd nodes.  Why not use the Postgres servers to host them. After all, the etcd footprint is fairly light. No big deal.

***Ceiling of ( 3 / 2 ) + 1 = 3*** 

Well, if more than one of your Postgres servers were to go down, you would be in a crisis trying to find out why you cannot reach the last database server out of 3. 

The fact is, you have to take into account how many etcd node failures  you are willing to tolerate in order to do a proper calculation.

If you have etcd running on the 3 database servers, and 2 of the database servers go down, you have just lost 2 of your etcd nodes leaving you with just 1. Well, 1 won't cut it for a quorum.

**To survive 2 failures, you need to have a system where the remaining nodes can still form a majority.**

The correct formula for determining the number of etcd nodes needed to survive 2 out of 3 etcd node failures is as follow:

***N = ( 2 * F ) + 1***

If F = 2  (two failures), then N = (2  * 2) + 1 = 5 

You need to add enough extra nodes to your quorum so that even when two are taken away, you still have the minimum quorum number left over.

Lets break it down.

- Total etcd nodes needed  = 5
- Quorum needed = 3  (since ceil of  5/2  + 1 = 3)
- Failures Allowed =  2
- If 2 nodes fail, 3 are left.  
- The remaining 3 nodes are still a majority of the original 5, so they can keep operating.
- Lastly,  5 nodes needed minus the original 3 nodes, means **you need an extra 2 etcd nodes**. The original 3 on each database server, plus two additional stand alone etcd nodes.


With the above explained, our tutorial and examples used in this documentation will be based on 3 postgres servers running etcd and 2 additional etcd servers to make up the needed difference.

## Containerized Service Management

Since we are deploying etcd within Docker containers, we won't be using host level service managers like systemctl to start, stop, or manage the processes. The lifecycle of the etcd process will be entirely managed by the Docker runtime itself and you starting and stopping it as needed.


**Clone the following repo**

https://github.com/jtorral/rocky9-pg17-bundle

Which includes all the necessary files, scripts and packages.  It is based on Rocky 9 ( redhat ) and Postgres 17.

You will need to create the docker image from the repo in order to continue with this self guided tutorial.

    docker build -t rocky9-pg17-bundle .


After you create the docker image, use the included genDeploy script to create the necessary fi;es and docker management scripts.

    ./genDeploy -m -n 5 -c pgha -w pghanet -s 192.168.50 -i rocky9-pg17-bundle

    The following docker deploy utility manager file: DockerRunThis.pgha has been created. To manage your new deploy run the file "./DockerRunThis.pgha"

Now create the containers

    ./DockerRunThis.pgha create
    cb7f102af4e3d54edd19764f1e79f3948f5c5fb547f60e925f94033b13dce959
    b816537cb7f2d0bbc8690824c0c5a7c314619b873e34cfedebb0aec36d63a248
    6847606b00f28bac21125704f7f0699481b0fba04c512f908dbf49fbd57679de
    523c02af489ee35f2eb1264faa9b38586bcfb5006224969ff4e8b231e463843e
    2d02ce33a6e8c86f255b43bfe6890a6dc7c56a5ce1d81dc82d58efacd57ed96a
    6ac8bb0f29430d88a2630702b3d9e567f9ede1d45466c34f84ab6e91c2938cef

Now start them

     ./DockerRunThis.pgha start
    Starting containers  pgha1 pgha2 pgha3 pgha4 pgha5
    pgha1
    pgha2
    pgha3
    pgha4
    pgha5

At this point we have named all of our containers with the prefix pgha. Since all the containers are on the same docker network we created ( pghanet ) they can all be resolved within the embedded dns server.

Docker automatically injects a DNS server into each custom network. This DNS server is accessible to all containers connected to that specific network. Therefore, no changes are really needed to the /etc/hosts file.

## Prework needed


We can use the existing host names we generated when we create the containers  pgha1 ... pgha5 without any additional changes or we can make things a little more obvious by creating aliases like etcd1 ... etcd5.

### As the user root

To create the aliases so we can reference the nodes by the names etcd1, etcd2 ... we just need to make a minor change to the /etc/hosts file

    192.168.50.10   pgha1 etcd1
    192.168.50.11   pgha2 etcd2
    192.168.50.12   pgha3 etcd3
    192.168.50.13   pgha4 etcd4
    192.168.50.14   pgha5 etcd5

Simply remove any reference to the host name in /etc/hosts that already exists in the list above then add the above entries. Do this on all containers.

The /etc/hosts file should look like this:

    127.0.0.1       localhost
    ::1     localhost ip6-localhost ip6-loopback
    fe00::  ip6-localnet
    ff00::  ip6-mcastprefix
    ff02::1 ip6-allnodes
    ff02::2 ip6-allrouters
    
    192.168.50.10   pgha1 etcd1
    192.168.50.11   pgha2 etcd2
    192.168.50.12   pgha3 etcd3
    192.168.50.13   pgha4 etcd4
    192.168.50.14   pgha5 etcd5

### Some additional mods needed

On each of the nodes, run the following commands

    mkdir -p /pgha/{config,certs,data/{etcd,postgres}}
    chown -R postgres:postgres /pgha
    mkdir -p /var/log/etcd
    chmod 700 /var/log/etcd
    chown postgres:postgres /var/log/etcd

### Create etcd config files

If we were to start etcd using systemctl our etcd config file would be a simple text file with the necessary parameters and values. However, since this tutorial is using docker and we do not have systemd the etcd config file needs to be a yaml file.

Included in the repo, is a file called **etcdSetup.sh** which you can use to generate the config files for our deployment. Otherwise you would have to create a slightly different one for each node.

The best way to do this is to cut and paste the file shown below into **/tmp/etcdSetup.sh** on the host etcd1 / pgha1

    #!/bin/bash
    
    yaml=0
    confFile="/pgha/config/etcd.conf"
    
    if [[ "$#" -ge 1 && "$1" == "-y" ]]; then
            yaml=1
            confFile="/pgha/config/etcd.yaml"
    fi
    
    thisNodeIp=$(hostname -i)
    thisNode=$(hostname)
    
    etcdNodeName=$(grep "$thisNode" /etc/hosts | grep -oE '\betcd[0-9]+\b')
    
    if [ "$etcdNodeName" == "" ]; then
            echo "No etcd node name or alias found in /etc/hosts for server $thisNode"
            exit
    fi
    
    initialCluster=""
    endPoints="export ENDPOINTS=\""
    tokenName="pgha-token"
    etcdDataDir="/pgha/data/etcd"
    confBaseDir="/pgha/"
    
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
       endPoints=$endPoints"${node}:2380,"
    done;
    
    initialCluster="${initialCluster%,}"   # -- Remove last comma
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



After you create the file on pgha1 / etcd1 change ownership and privileges 

    chmod 777 /tmp/etcdSetup.sh
    chown postgres:postgres /tmp/etcdSetup.sh

The reason we are doing this is because the user postgres has already been configured with the necessary ssh keys as part of the docker image you are using.  Therefore, we can easily copy files and run ssh commands between servers as user postgres. It just makes life a little easier :)

Now lets get things done as the user postgres from the node pgha1 / etcd1

Create the etcd.yaml file we will be using by running the etcdSetup script with the -y option

    ./etcdSetup.sh -y

This will generate the file /pgha/config/etcd.yaml withthe following content.

    name: etcd1
    
    initial-cluster: "etcd1=http://192.168.50.10:2380,etcd2=http://192.168.50.11:2380,etcd3=http://192.168.50.12:2380,etcd4=http://192.168.50.13:2380,etcd5=http://192.168.50.14:2380"
    
    initial-cluster-token: pgha-token
    
    data-dir: /pgha/data/etcd
    
    initial-cluster-state: new
    
    initial-advertise-peer-urls: "http://192.168.50.10:2380"
    
    listen-peer-urls: "http://192.168.50.10:2380"
    
    listen-client-urls: "http://192.168.50.10:2379,http://localhost:2379"
    
    advertise-client-urls: "http://192.168.50.10:2379"

Copy the etcdSetup.sh file to the other nodes. 

    su - postgres
    cd /tmp
    scp etcdSetup.sh etcd2:/tmp
    scp etcdSetup.sh etcd3:/tmp
    scp etcdSetup.sh etcd4:/tmp
    scp etcdSetup.sh etcd5:/tmp

Generate the etcd.yaml file on the remaining nodes

    ssh etcd2 "/tmp/etcdSetup.sh -y"
    ssh etcd3 "/tmp/etcdSetup.sh -y"
    ssh etcd4 "/tmp/etcdSetup.sh -y"
    ssh etcd5 "/tmp/etcdSetup.sh -y"

Run a quick validation on any of the other nodes

    ssh etcd5 "cat /pgha/config/etcd.yaml"

Should show you the config file for etcd5 

    name: etcd5
    
    initial-cluster: "etcd1=http://192.168.50.10:2380,etcd2=http://192.168.50.11:2380,etcd3=http://192.168.50.12:2380,etcd4=http://192.168.50.13:2380,etcd5=http://192.168.50.14:2380"
    
    initial-cluster-token: pgha-token
    
    data-dir: /pgha/data/etcd
    
    initial-cluster-state: new
    
    initial-advertise-peer-urls: "http://192.168.50.14:2380"
    
    listen-peer-urls: "http://192.168.50.14:2380"
    
    listen-client-urls: "http://192.168.50.14:2379,http://localhost:2379"
    
    advertise-client-urls: "http://192.168.50.14:2379"

At this point we are ready to start etcd

As user postgres

On the etcd1 server run 

    nohup etcd --config-file /pgha/config/etcd.yaml > /var/log/etcd/etcd-standalone.log 2>&1 &

Afterwards, start the service on the remaining nodes.

    ssh etcd2  "nohup etcd --config-file /pgha/config/etcd.yaml > /var/log/etcd/etcd-standalone.log 2>&1 &"
    ssh etcd3  "nohup etcd --config-file /pgha/config/etcd.yaml > /var/log/etcd/etcd-standalone.log 2>&1 &"
    ssh etcd4  "nohup etcd --config-file /pgha/config/etcd.yaml > /var/log/etcd/etcd-standalone.log 2>&1 &"
    ssh etcd5  "nohup etcd --config-file /pgha/config/etcd.yaml > /var/log/etcd/etcd-standalone.log 2>&1 &"

Finally, we should be able to see the members up and running.  

    etcdctl  member list

The output should be similar to the following:

    29111f285fc78706, started, etcd4, http://192.168.50.13:2380, http://192.168.50.13:2379, false
    4ec2b2668990565b, started, etcd2, http://192.168.50.11:2380, http://192.168.50.11:2379, false
    ab6c7f1736bd6eb0, started, etcd5, http://192.168.50.14:2380, http://192.168.50.14:2379, false
    c96171b99f7cfa68, started, etcd1, http://192.168.50.10:2380, http://192.168.50.10:2379, false
    cebc84bd6d4d9d4b, started, etcd3, http://192.168.50.12:2380, http://192.168.50.12:2379, false


We can also check the status.  You need your endpoints defined. The following export command should be generated for you when you ran the `etcdSetup.sh`.  You can add it to your .profile or just export it in your session.

     export ENDPOINTS="etcd1:2380,etcd2:2380,etcd3:2380,etcd4:2380,etcd5:2380"

Check the etcd status

     etcdctl --write-out=table --endpoints=$ENDPOINTS endpoint status
    +------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    |  ENDPOINT  |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
    +------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    | etcd1:2380 | c96171b99f7cfa68 |  3.5.17 |   20 kB |     false |      false |         2 |         13 |                 13 |        |
    | etcd2:2380 | 4ec2b2668990565b |  3.5.17 |   20 kB |     false |      false |         2 |         13 |                 13 |        |
    | etcd3:2380 | cebc84bd6d4d9d4b |  3.5.17 |   20 kB |      true |      false |         2 |         13 |                 13 |        |
    | etcd4:2380 | 29111f285fc78706 |  3.5.17 |   20 kB |     false |      false |         2 |         13 |                 13 |        |
    | etcd5:2380 | ab6c7f1736bd6eb0 |  3.5.17 |   20 kB |     false |      false |         2 |         13 |                 13 |        |
    +------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+

