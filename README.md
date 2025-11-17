# Postgres High Availability with Patroni Training

Welcome to this free, self paced training documentation offered by Postgres Solutions! This comprehensive material is designed to guide you through the critical concepts and practical implementation of running a highly available database cluster using Postgres, orchestrated by Patroni, and leveraging etcd for distributed consensus.

We aim to break down complex topics, clarify common pitfalls (like quorum sizing), and provide step by step instructions to build a resilient system.

## License and Credit

This documentation is provided for personal, self paced training. If you plan to utilize this documentation outside of self training, for instance, as a base for creating additional training materials, tutorials, or public documentation you **must** give credit to postgressolutions.com and Jorge Torralba. Your cooperation helps support the creation of future educational content.

## Support Our Work

If you find significant value in this free training and feel that it has enhanced your understanding of high availability Postgres, please consider making a donation. Your support goes a long way toward producing and maintaining additional high quality, free training materials. You can donate here:

https://www.paypal.com/donate/?hosted_button_id=J2HWPPWX8EBNC


## About this tutorial

If you're reading this or expressing an interest in this topic, you are likely already familiar with Patroni. This powerful tool elegantly solves the problem of high availability for Postgres by orchestrating replication, failover, and self healing. Patroni's primary function is to turn a collection of standard Postgres instances into a robust, resilient cluster.

This tutorial is designed not only to guide you through setting up a highly available Postgres cluster with Patroni, but also to equip you with the fundamental concepts needed to avoid the critical pitfalls that plague many production deployments. 

To focus purely on the architecture and consensus mechanics without complex installation steps, we will be leveraging Docker containers. These containers conveniently include Postgres, Patroni, and etcd with many necessary dependencies pre-configured. We will carefully walk through the configuration and setup process, ensuring you gain a complete and clear understanding of how these components interact and how to properly secure your critical quorum for true high availability.

# Lets get this out of the way first!

## The etcd Mystery and Critical Misconception. Your etcd Quorum

### Don't skip this section. Even if you think you already know about quorums.

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


***With that said, our tutorial and examples used throughout this documentation will be based on 3 postgres servers running etcd and 2 additional etcd servers to make up the needed difference.*** 


## Setting up your docker environment


To begin the setup for the Postgres cluster, we will utilize Docker. All the necessary Dockerfiles and resources for this tutorial are available in the repository: https://github.com/jtorral/rocky9-pg17-bundle.

You can clone the repo from here:

    git clone git@github.com:jtorral/rocky9-pg17-bundle.git

This repository contains the setup needed to run a complete, feature rich Rocky Linux 9-based environment that includes Postgres 17 and Patroni.

**Creating the Docker image**

You will need to clone the repository and build the base Docker image from the provided files. The image name you will create is rocky9-pg17-bundle.

**Clone the Repository**

    git clone git@github.com:jtorral/rocky9-pg17-bundle.git
    
    cd rocky9-pg17-bundle

**Build the Image:**

    docker build -t rocky9-pg17-bundle .

**Image notes**

It's important to note that the resulting rocky9-pg17-bundle image is not a lightweight image. While modern container practices often favor minimal base images, this particular image is feature packed.

It includes the Rocky 9 operating system as its base and contains additional packages and tools necessary for complex database administration tasks, debugging, and advanced Patroni features (like pgBackRest integration, though we won't fully configure it yet). This robust foundation ensures that all necessary utilities for managing Patroni and Postgres are readily available throughout the training, simplifying the environment setup and allowing us to focus on the cluster's high-availability logic.


## Simplifying Deployment with genDeploy

To make the environment setup smoother, the cloned repository includes a helper script called genDeploy

This script is designed to streamline the creation of all the necessary docker run commands for your etcd and Patroni nodes. Instead of manually writing and managing complex command line arguments for each of the containers and , you simply pass a few key parameters to genDeploy.

When executed, genDeploy does not immediately run the containers. Instead, it generates a new file based on container name you declare ( e.g., DockerRunThis.pgha ) which contains all the configured docker run commands. This generated file gives you a convenient way to manage your entire deployed environment, acting similar to a custom, albeit less advanced, version of a docker-compose file.

Note: Using genDeploy is not required for this tutorial. You could manually construct all the docker run commands yourself. However, using the script is highly recommended as it eliminates potential configuration errors and makes stopping, starting, and cleaning up your deployment significantly easier.

## Service Management and Configuration Formats

As we are running our services within Docker containers, we will indeed bypass system level service managers like systemctl. Instead, we will be manually starting and stopping the services (Patroni and etcd) as needed within our environment.

### The etcd Configuration File Format Pitfall

A major point of confusion for users deploying etcd is the variability of its configuration file format, which depends entirely on how the service is launched.

- **Plain Text/Shell Format (Default)** When etcd is launched via a standard script or systemd unit file (like the ones typically managed by systemctl), its configuration often consists of plain text where flags are defined directly.

- **YAML Format (Required for --config-file)** If you launch the etcd executable and explicitly use the --config-file flag to specify a configuration file location, that file must be in YAML format.

**Simplified Setup with etcdSetup**

To help you navigate this inconsistency, the repository includes the helper script etcdSetup. This script will generate the necessary configuration files for your etcd nodes. Again, like the other script files, this is not a requirement but it makes the configuration less prone to typos and significantly easier.

Crucially, the script supports an optional parameter

If you execute the script without the YAML flag, it generates the configuration suitable for starting and stopping etcd with systemctl.

If you pass the **-y** flag (e.g., **etcdSetup -y**), it will generate the YAML version of the configuration file, ready to be used with the **--config-file** flag which is the method used for this tutorial.

This ensures you have the correct file format, regardless of how you choose to run etcd in the future.


## Getting started


After completing the above steps of cloning the repo and creating the Docker image,  we will now use the genDeploy script to create our Docker environment.

For reference only, here are the options for running genDeploy.

    Usage: genDeploy options
    
    Description:
    
    A for generating docker run files used by images created from the repo this was pulled from.
    The generated run file can be used to manage your deploy. Similar to what you can do with a docker-compose file.
    
    When used with a -g option. It can be used for any generic version of postgres images. It will only create run commands with network, ip and nodenames.
    Good if you just want to deploy multiple containers of your own.
    
    Options:
      -m                    Setup postgres environment to use md5 password_encription."
      -p <password>         Password for user postgres. If usinmg special characters like #! etc .. escape them with a \ default = \"postgres\""
      -n <number>           number of of containers to create. Default is 1. "
      -r                    Start postgres in containers automatically. Otherwise you have to manually start postgres.
      -g                    Use as a generic run-command generator for images not part of this repo.
    
    Required Options:
      -c <name>             The name container/node names to use. This should be a prefix. For example if you want 3 postgres containers"
                            pg1, pg2 and pg3. Simply provide \"pg\" since this script will know how to name them."
      -w <network>          The name of the network to bind the containers to. You can provide an existing network name or a new one to create."
      -s <subnet>           If creating a new network, provide the first 3 octets for the subnet to use with the new network. For example: 192.168.50"
      -i <image>            docker image to use. If you created your own image tage, set it here."

Now that you see what flags are for genDeploy,  lets run it for our environment keeping in mind we will be needing 5 containers in total as noted above in the explanation of etcd quorum and the section labeled **Don't skip this section**.

### Create your deployment files

    ./genDeploy -m -n 5 -c pgha -w pghanet -s 192.168.50 -i rocky9-pg17-bundle

    The following docker deploy utility manager file: DockerRunThis.pgha has been created. To manage your new deploy run the file "./DockerRunThis.pgha"

**A breakdown of the command and flags,**

- **-m** sets up Postgres to use password_encryption of md5
- **-n 5** creates a total of 5 containers
- **-c pgha** the name each container will be given with a unique identifier behind it. ( ie. pgha1, pgha2 )
- **- w pghanet** will create a dedicated docker network called pghanet for our containers to run under
- **-s 192.168.50** will assign that subnet to the custom network pghanet
- **-i rocky-pg17-bundle** is the image to use for creating the container

The above command will have generated the file **DockerRunThis.pgha** which is how we will manage our deploy.


## Important Note on IP Address Management with genDeploy

It's critical to understand how the genDeploy script manages network addresses to prevent conflicts in your Docker environment.

The genDeploy script attempts to create a unique and stable deployment by performing a basic check.  It looks at the currently running Docker containers to identify IP addresses and ports that are actively in use. Based on this information, it then generates unique IP addresses and port numbers for the new containers it intends to define.

### The Risk of Conflicts

This approach works best when your environment is clean, or when all containers are running. If some of your old containers or test deployments are currently stopped (not running):

genDeploy may not detect the IP addresses those stopped containers reserved when they were last run.

It may then generate a new deployment file that uses an IP address that is technically reserved by a stopped container.

When you attempt to start an old container that has a conflicting IP address with one of your new genDeploy nodes, you will encounter a network error.

If this conflict occurs, you will have to manually resolve it by either deleting the conflicting old container or editing the IP addresses in the genDeploy generated script.  **Editing the genDeploy generated script file with different IP's will be the easiest and most straight forward solution.**

For a hassle-free experience, ensure all old, unused containers are completely removed before running genDeploy.

### Create the containers

    ./DockerRunThis.pgha create
    cb7f102af4e3d54edd19764f1e79f3948f5c5fb547f60e925f94033b13dce959
    b816537cb7f2d0bbc8690824c0c5a7c314619b873e34cfedebb0aec36d63a248
    6847606b00f28bac21125704f7f0699481b0fba04c512f908dbf49fbd57679de
    523c02af489ee35f2eb1264faa9b38586bcfb5006224969ff4e8b231e463843e
    2d02ce33a6e8c86f255b43bfe6890a6dc7c56a5ce1d81dc82d58efacd57ed96a
    6ac8bb0f29430d88a2630702b3d9e567f9ede1d45466c34f84ab6e91c2938cef

### Start the containers

     ./DockerRunThis.pgha start
    Starting containers  pgha1 pgha2 pgha3 pgha4 pgha5
    pgha1
    pgha2
    pgha3
    pgha4
    pgha5


### Naming convention

At this point, we've established a naming convention for our containers using the prefix pgha (e.g., pgha1, pgha2, etc.).

Since all of these containers are placed onto the same dedicated Docker network we created (which we will refer to as **pghanet** ), they benefit from Docker's embedded DNS server. This means that every container can resolve every other container using its unique container name (e.g., pgha1 can reach pgha5 simply by using the name pgha5).

### Hostname Options

You have flexibility in how you refer to your nodes within configuration files.

- **Use Existing Container Names** You can directly use the hostnames generated when you created the containers (e.g., pgha1 through pgha5) in your Patroni and etcd configurations. Since they are all on the pghanet network, these names will resolve correctly without any additional changes.

- **Create Aliases for Clarity** To make your configuration files slightly more intuitive and easier to follow, you can create aliases. For example, you can map the Patroni nodes to etcd1 through etcd5 within the /etc/hosts file of the relevant containers. This practice can make the cluster topology more obvious when reading configuration files or logs.




## Create the aliases ( Optional for this tutorial )
***This is optional as we will be using the host names for the etcd and patroni configurations.  It is included here solely to provide you with a complete understanding of the underlying setup processes.***

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

## setup logging folders and permissions.
***This is optional as it has already been configured as part of the rocky9-pg17-bundle Docker image. It is included here solely to provide you with a complete understanding of the underlying setup processes.***

On each of the nodes, run the following commands

    mkdir -p /pgha/{config,certs,data/{etcd,postgres}}
    chown -R postgres:postgres /pgha
    mkdir -p /var/log/etcd
    chmod 700 /var/log/etcd
    mkdir -p /var/log/patroni
    chmod 700 /var/log/patroni
    chown postgres:postgres /var/log/etcd
    chown postgres:postgres /var/log/patroni

## Create etcd configuration files

If we were to start etcd using systemctl our etcd config file would be a simple text file with the necessary parameters and values. However, since this tutorial is using docker and we do not have systemd the etcd config file needs to be a yaml file.

Included in the repo, is a file called **etcdSetup.sh** which you can use to generate the config files for our deployment. Otherwise you would have to tediously create a custom version for each node in the cluster.

This script is included in the **rocky9-pg17-bundle Docker image** and located in **/** directory. 

At this point you are logged into the container as user root.  There is an environment variable called **NODELIST** which is contains the names and IP addresses of all the containers we just created with the **genDeploy** script.   

Since most of the services we will be running are going to be under the account of the user postgres, we need to perform following actions as user postgres.  We also **need access to the NODELIST environment variable**.   In order to preserve the environment variable when we **su** to user postgres, we will sudo to postgres using the following command instead.

    sudo -E -u postgres /bin/bash -l

The above sudo command will preserve the environment variables form the previous shell, and load the postgres specific settings as well.

We can now create the etcd.yaml file using the **etcdSetup** script with the **-y** option

    /etcdSetup.sh -y

This will output something similar to the following

    name: pgha1
    initial-cluster: "pgha1=http://192.168.50.10:2380,pgha2=http://192.168.50.11:2380,pgha3=http://192.168.50.12:2380,pgha4=http://192.168.50.13:2380,pgha5=http://192.168.50.14:2380"
    initial-cluster-token: pgha-token
    data-dir: /pgha/data/etcd
    initial-cluster-state: new
    initial-advertise-peer-urls: "http://192.168.50.10:2380"
    listen-peer-urls: "http://192.168.50.10:2380"
    listen-client-urls: "http://192.168.50.10:2379,http://localhost:2379"
    advertise-client-urls: "http://192.168.50.10:2379"
    
    
    Add the following environment variable to your profile for easy access to the etcd endpoints
    
            export ENDPOINTS="pgha1:2380,pgha2:2380,pgha3:2380,pgha4:2380,pgha5:2380"

**Take note of the export command at the end. Copy and run it now or add it to the  profile .pgsql_profile file.**

The output above also shows the content of the **/pgha/config/etcd.yaml**  generated.

**Take note of the above etcd.yaml file. If you do not use the script, you would have to create the above file on each of the nodes in the cluster and make the changes to reflect the proper hostname and ip address of the node. This is why using the file makes deployment easier**

## Create the etcd configuration file on remaining nodes in cluster

Since we have ssh enabled and configured for the user postgres on all the containers, we can easily perform the above action on the additional servers using ssh. However, prior to running the ssh commands below,  we need to determine what the NODELIST environment variable is set to so we can pass it in our ssh command to the other nodes.

    echo $NODELIST
    pgha1:192.168.50.10 pgha2:192.168.50.11 pgha3:192.168.50.12 pgha4:192.168.50.13 pgha5:192.168.50.14

As you can see, it's just a list of servers and ip addresses.  We will copy the node list above and export it as part of our ssh command as you can see below.


    ssh pgha2 "export NODELIST='pgha1:192.168.50.10 pgha2:192.168.50.11 pgha3:192.168.50.12 pgha4:192.168.50.13 pgha5:192.168.50.14'; /etcdSetup.sh -y"
    ssh pgha3 "export NODELIST='pgha1:192.168.50.10 pgha2:192.168.50.11 pgha3:192.168.50.12 pgha4:192.168.50.13 pgha5:192.168.50.14'; /etcdSetup.sh -y"
    ssh pgha4 "export NODELIST='pgha1:192.168.50.10 pgha2:192.168.50.11 pgha3:192.168.50.12 pgha4:192.168.50.13 pgha5:192.168.50.14'; /etcdSetup.sh -y"
    ssh pgha5 "export NODELIST='pgha1:192.168.50.10 pgha2:192.168.50.11 pgha3:192.168.50.12 pgha4:192.168.50.13 pgha5:192.168.50.14'; /etcdSetup.sh -y"


Run a quick validation on any of the other nodes

    ssh pgha5 "cat /pgha/config/etcd.yaml"

Should show you the config file for pgha5

    name: pgha5
    initial-cluster: "pgha1=http://192.168.50.10:2380,pgha2=http://192.168.50.11:2380,pgha3=http://192.168.50.12:2380,pgha4=http://192.168.50.13:2380,pgha5=http://192.168.50.14:2380"
    initial-cluster-token: pgha-token
    data-dir: /pgha/data/etcd
    initial-cluster-state: new
    initial-advertise-peer-urls: "http://192.168.50.14:2380"
    listen-peer-urls: "http://192.168.50.14:2380"
    listen-client-urls: "http://192.168.50.14:2379,http://localhost:2379"
    advertise-client-urls: "http://192.168.50.14:2379"

As you can see, it is configured correctly with the proper node name and ip addresses.


## Start etcd

At this point we are ready to start etcd. Since we are **not using systemctl**, we will be starting it as a background process. Since in this tutorial, we use custom configurations, we will need to specify the config file to use with the --config-file option.  Another reason for the yaml format we used.

On pgha1 run the following command.

    nohup etcd --config-file /pgha/config/etcd.yaml > /var/log/etcd/etcd-standalone.log 2>&1 &

You can monitor the etcd log file **/var/log/etcd/etcd-standalone.log** for messages

## Start etcd on the remaining nodes.

    ssh pgha2 "nohup etcd --config-file /pgha/config/etcd.yaml > /var/log/etcd/etcd-standalone.log 2>&1 &"
    ssh pgha3 "nohup etcd --config-file /pgha/config/etcd.yaml > /var/log/etcd/etcd-standalone.log 2>&1 &"
    ssh pgha4 "nohup etcd --config-file /pgha/config/etcd.yaml > /var/log/etcd/etcd-standalone.log 2>&1 &"
    ssh pgha5 "nohup etcd --config-file /pgha/config/etcd.yaml > /var/log/etcd/etcd-standalone.log 2>&1 &"

## View the etcd member list

    etcdctl  member list

The output should be similar to the following:

    29111f285fc78706, started, pgha4, http://192.168.50.13:2380, http://192.168.50.13:2379, false
    4ec2b2668990565b, started, pgha2, http://192.168.50.11:2380, http://192.168.50.11:2379, false
    ab6c7f1736bd6eb0, started, pgha5, http://192.168.50.14:2380, http://192.168.50.14:2379, false
    c96171b99f7cfa68, started, pgha1, http://192.168.50.10:2380, http://192.168.50.10:2379, false
    cebc84bd6d4d9d4b, started, pgha3, http://192.168.50.12:2380, http://192.168.50.12:2379, false


## Check etcd status

We can also check the status of etcd using the ENDPOINTS environment variable we exported earlier.  

Remember, when you ran etcdSetup.sh, it should have been generated an output with the needed export command.

     export ENDPOINTS="pgha1:2380,pgha2:2380,pgha3:2380,pgha4:2380,pgha5:2380"
     
Check the etcd status

    etcdctl --write-out=table --endpoints=$ENDPOINTS endpoint status
    +------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    |  ENDPOINT  |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
    +------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    | pgha1:2380 | c96171b99f7cfa68 |  3.5.17 |   20 kB |     false |      false |         2 |         13 |                 13 |        |
    | pgha2:2380 | 4ec2b2668990565b |  3.5.17 |   20 kB |      true |      false |         2 |         13 |                 13 |        |
    | pgha3:2380 | cebc84bd6d4d9d4b |  3.5.17 |   20 kB |     false |      false |         2 |         13 |                 13 |        |
    | pgha4:2380 | 29111f285fc78706 |  3.5.17 |   20 kB |     false |      false |         2 |         13 |                 13 |        |
    | pgha5:2380 | ab6c7f1736bd6eb0 |  3.5.17 |   20 kB |     false |      false |         2 |         13 |                 13 |        |
    +------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
       

## Patroni setup


To simplify the deployment process, the **patroniSetup.sh** script is included in the rocky9-pg17-bundle Docker image. We will be using this script in the tutorial as it is designed to reduce the tedium of manual configuration and make deployments easier.

However, for your learning and complete understanding, we will also explain in detail the underlying configuration and settings contained within the resulting patroni.yml file. This ensures you gain a full conceptual grasp of the environment and can customize it later if needed.


### Copy the createRoles.sh script

While still logged in to pgha1, **as user postgres**

     cp -p /createRoles.sh /pgha/config/

As of Patroni version 4, role creation within the patroni configuration file has been removed. You must now run a post bootstrap command to perform any additional role creation on the database cluster. 

The createRoles.sh script contains the necessary roles needed for this tutorial.

### Empty the postgres data directory

Patroni will initialize a fresh cluster and to do this, it will need an empty data directory. 

    echo $PGDATA
    /pgdata/17/data

Empty the directory.

    rm -rf /pgdata/17/data

When we ran the etcdSetup.sh script it created the file **/pgha/config/patroniVars.** 

    ETCD_NODES="pgha1:2379,pgha2:2379,pgha3:2379,pgha4:2379,pgha5:2379"
    NODE_NAME="pgha1"
    PATRONI_CFG="/pgha/config/patroni.yaml"
    DATADIR="/pgdata/17/data"
    CFG_DIR="/pgha/config"
    PG_BIN_DIR="/usr/pgsql-17/bin/"
    NAMESPACE="pgha"
    SCOPE="pgha_patroni_cluster"

The file contains values we need to generate the patroni config files dynamically across all nodes.  Otherwise, you would have to manually create each file individually.  The patroniSetup.sh sources /pgha/config/patroniVars to read these settings

### Run the setupPatroni.sh script

At this time we have done all the prework needed to run the script.

    /patroniSetup.sh
    Configuration loaded successfully from /pgha/config/patroniVars.


### Start patroni manually in the background

    nohup patroni /pgha/config/patroni.yaml > patroni.log 2>&1 &

Validate patroni is running using patronictl

    patronictl -c /pgha/config/patroni.yaml list
    
    + Cluster: pgha_patroni_cluster (7573485601442316865) -+-----+------------+-----+
    | Member |  Host |  Role  |  State  | TL | Receive LSN | Lag | Replay LSN | Lag |
    +--------+-------+--------+---------+----+-------------+-----+------------+-----+
    | pgha1  | pgha1 | Leader | running |  1 |             |     |            |     |
    +--------+-------+--------+---------+----+-------------+-----+------------+-----+

You can also check the log file

    cd /var/log/patroni
    cat patroni.log
    2025-11-17 00:32:07,075 INFO: Selected new etcd server http://192.168.50.13:2379
    2025-11-17 00:32:07,084 INFO: No PostgreSQL configuration items changed, nothing to reload.
    2025-11-17 00:32:07,085 INFO: Systemd integration is not supported
    2025-11-17 00:32:07,130 INFO: Lock owner: None; I am pgha1
    2025-11-17 00:32:07,222 INFO: trying to bootstrap a new cluster
    2025-11-17 00:32:07,897 INFO: postmaster pid=585
    2025-11-17 00:32:08,928 INFO: establishing a new patroni heartbeat connection to postgres
    2025-11-17 00:32:09,025 INFO: running post_bootstrap
    2025-11-17 00:32:09,291 INFO: initialized a new cluster
    2025-11-17 00:32:19,161 INFO: no action. I am (pgha1), the leader with the lock
    2025-11-17 00:32:29,201 INFO: no action. I am (pgha1), the leader with the lock
    2025-11-17 00:32:39,108 INFO: no action. I am (pgha1), the leader with the lock
    2025-11-17 00:32:49,107 INFO: no action. I am (pgha1), the leader with the lock
    2025-11-17 00:32:59,108 INFO: no action. I am (pgha1), the leader with the lock

So far so good,

### Start patroni on the remaining nodes 1 at a time.  

Lets once again take advantage of our preconfigured ssh setup with this Docker environment and repeat the above process for the remaining nodes. 

From pgha1, still as user postgres run the following ssh command.

    ssh pgha2 "cp -p /createRoles.sh /pgha/config; rm -rf /pgdata/17/data/; /patroniSetup.sh"

If it worked, you should see the message

    Configuration loaded successfully from /pgha/config/patroniVars.

Now lets start it from ssh as well.

    ssh pgha2 "nohup patroni /pgha/config/patroni.yaml > patroni.log 2>&1 &"

Validate it was added to the patroni cluster.  Again, we use patronictl. We can do this from any of the servers in our cluster.

    patronictl -c /pgha/config/patroni.yaml list
    
    + Cluster: pgha_patroni_cluster (7573485601442316865) --+-----+------------+-----+
    | Member |  Host |   Role  |  State  | TL | Receive LSN | Lag | Replay LSN | Lag |
    +--------+-------+---------+---------+----+-------------+-----+------------+-----+
    | pgha1  | pgha1 | Leader  | running |  1 |             |     |            |     |
    | pgha2  | pgha2 | Replica | running |  1 |   0/4000000 |   0 |  0/4000000 |   0 |
    +--------+-------+---------+---------+----+-------------+-----+------------+-----+

So at this point we have two of our 3 patroni database servers up and running now.

Lets repeat the process for node pgha3

    ssh pgha3 "cp -p /createRoles.sh /pgha/config; rm -rf /pgdata/17/data/; /patroniSetup.sh"

Now start it

    ssh pgha3 "nohup patroni /pgha/config/patroni.yaml > patroni.log 2>&1 &"

And finally validate

     patronictl -c /pgha/config/patroni.yaml list
     
    + Cluster: pgha_patroni_cluster (7573485601442316865) ----+-----+------------+-----+
    | Member |  Host |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+
    | pgha1  | pgha1 | Leader  | running   |  1 |             |     |            |     |
    | pgha2  | pgha2 | Replica | streaming |  1 |   0/6000060 |   0 |  0/6000060 |   0 |
    | pgha3  | pgha3 | Replica | running   |  1 |   0/6000000 |   0 |  0/6000000 |   0 |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+


It takes a moment for it to build the replica and enter it's streaming state. 

Repeat the check 

     patronictl -c /pgha/config/patroni.yaml list
     
    + Cluster: pgha_patroni_cluster (7573485601442316865) ----+-----+------------+-----+
    | Member |  Host |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+
    | pgha1  | pgha1 | Leader  | running   |  1 |             |     |            |     |
    | pgha2  | pgha2 | Replica | streaming |  1 |   0/6000060 |   0 |  0/6000060 |   0 |
    | pgha3  | pgha3 | Replica | streaming |  1 |   0/6000060 |   0 |  0/6000060 |   0 |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+

As you can see, we now have all 3 postgres database servers running and managed by patroni with **pgha1 as the primary**.


## Some patroni administrative tasks


For the purposes of this tutorial, we have purposely omitted the necessary entry for the highly privileged postgres superuser from the pg_hba.conf file in our Patroni cluster's dynamic configuration.

This omission is deliberate, as it allows us to successfully demonstrate and practice the correct,  method for modifying pg_hba.conf entries in a Patroni managed environment by using the **patronictl edit-config** command.

Managing this configuration through patronictl ensures the changes are centrally stored in the DCS (Distributed Configuration Store) and automatically propagated to all Primary and Replica nodes, maintaining cluster consistency.


**Personal Side Note:** 

***While Patroni is an absolutely awesome high availability tool, its architecture, which involves taking over almost all Postgres administrative and configuration tasks, can sometimes feel overwhelming for newcomers. For those seeking similar high-availability functionality like connection pooling, load balancing, and replication management without Patroni's deep integration and complexity, I personally lean towards pgpool. pgpool sits between the client and Postgres, offering powerful features without completely taking over the underlying database administration. I will be publishing a pgpool tutorial as well***


### Adjusting pg_hba.conf

As you can see, if I try to psql directly to phga2 from pgha1, I receive the following error.


    psql -h pgha2
    
    psql: error: connection to server at "pgha2" (192.168.50.11), port 5432 failed: FATAL:  no pg_hba.conf entry for host "192.168.50.10", user "postgres", database "postgres", no encryption

This is a very typical and easy to resolve issue by editing the pg_hba.conf file and reloading postgres. However, with patroni taking over all aspects of managing postgres, we should never directly make changes to postgres confion or runtime parameters as you normally would.  You need to perform the change using the Patroni control utility, patronictl edit-config, to ensure the rule is stored in the DCS and automatically propagated to all nodes in the cluster.



    patronictl -c /pgha/config/patroni.yaml edit-config

Opens up your editor with the following file in yaml format

    loop_wait: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      parameters:
        archive_command: /bin/true
        archive_mode: true
        archive_timeout: 600s
        hot_standby: true
        log_filename: postgresql-%a.log
        log_line_prefix: '%m [%r] [%p]: [%l-1] user=%u,db=%d,host=%h '
        log_lock_waits: 'on'
        log_min_duration_statement: 500
        logging_collector: 'on'
        max_replication_slots: 10
        max_wal_senders: 10
        max_wal_size: 1GB
        wal_keep_size: 4096
        wal_level: logical
        wal_log_hints: true
      use_pg_rewind: true
      use_slots: true
    retry_timeout: 10
    ttl: 30

Make the necessary changes to include the pg_hba.conf setting.

    loop_wait: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      parameters:
        archive_command: /bin/true
        archive_mode: true
        archive_timeout: 600s
        hot_standby: true
        log_filename: postgresql-%a.log
        log_line_prefix: '%m [%r] [%p]: [%l-1] user=%u,db=%d,host=%h '
        log_lock_waits: 'on'
        log_min_duration_statement: 500
        logging_collector: 'on'
        max_replication_slots: 10
        max_wal_senders: 10
        max_wal_size: 1GB
        wal_keep_size: 4096
        wal_level: logical
        wal_log_hints: true
      pg_hba:
      - host all postgres 192.168.50.0/24 md5
      use_pg_rewind: true
      use_slots: true
    retry_timeout: 10
    ttl: 30

You will be asked to confirm the changes. 

Once confirmed, Patroni will propagate the changes to the other nodes in the cluster. And once it does, we should be good to go.

    [postgres@pgha1 data]$ psql -h pgha2
    psql (17.6)
    Type "help" for help.
    
    postgres=#

Now we can do a simple test to see replication working.

First query pgha1. The primary.

    psql -h pgha1 -c "select datname from pg_stat_database"
      datname
    -----------
    
     postgres
     template1
     template0
    (4 rows)

Now query one of the replicas, pgha2

    psql -h pgha2 -c "select datname from pg_stat_database"
      datname
    -----------
    
     postgres
     template1
     template0
    (4 rows)

As you can see, they both have the same databases. Nothing has been created on the primary yet.

Now, lets create a new database on the primary.

    psql -h pgha1 -c "create database foobar"
    CREATE DATABASE

Now lets see if it was replicated to pgha2

     psql -h pgha2 -c "select datname from pg_stat_database"
      datname
    -----------
    
     postgres
     foobar
     template1
     template0
    (5 rows)
 
 As you can see it has been replicated.


