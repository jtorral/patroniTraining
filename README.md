## Table of Contents

- [Deploying and Securing High Availability Postgres with Patroni and pgBackrest](#deploying-and-securing-high-availability-postgres-with-patroni-and-pgbackrest)
  - [License and Credit](#license-and-credit)
  - [Support Our Work](#support-our-work)
  - [About this tutorial](#about-this-tutorial)
- [First things first](#first-things-first)
  - [Do not skip this section](#do-not-skip-this-section)
  - [The etcd Mystery and Critical Misconception](#the-etcd-mystery-and-critical-misconception)
  - [Your patroni node count does not determine your etcd quorum](#your-patroni-node-count-does-not-determine-your-etcd-quorum)
  - [The correct etcd quorum sizing rule](#the-correct-etcd-quorum-sizing-rule)
  - [A word about the Docker deployment for this tutorial](#a-word-about-the-docker-deployment-for-this-tutorial)
    - [Centralized Administration via /pgha](#centralized-administration-via-pgha)
  - [Setting up your docker environment](#setting-up-your-docker-environment)
  - [Simplifying deployment with genDeploy](#simplifying-deployment-with-gendeploy)
  - [Service Management and Configuration Formats](#service-management-and-configuration-formats)
    - [The etcd Configuration File Format Pitfall](#the-etcd-configuration-file-format-pitfall)
  - [Getting started](#getting-started)
  - [Create your deployment files](#create-your-deployment-files)
  - [Important Note on IP Address Management with genDeploy](#important-note-on-ip-address-management-with-gendeploy)
    - [The Risk of Conflicts](#the-risk-of-conflicts)
    - [Create the containers](#create-the-containers)
    - [Start the containers](#start-the-containers)
    - [Naming convention](#naming-convention)
    - [Hostname Options](#hostname-options)
  - [Create the aliases](#create-the-aliases)
  - [setup logging folders and permissions](#setup-logging-folders-and-permissions)
  - [Create etcd configuration files](#create-etcd-configuration-files)
  - [Create the etcd configuration file on remaining nodes in cluster](#create-the-etcd-configuration-file-on-remaining-nodes-in-cluster)
  - [What do all the etcd settings mean](#what-do-all-the-etcd-settings-mean)
  - [Do I need to change the cluster state to existing from new](#do-i-need-to-change-the-cluster-state-to-existing-from-new)
  - [When do I use existing](#when-do-i-use-existing)
  - [Start etcd](#start-etcd)
  - [Start etcd on the remaining nodes](#start-etcd-on-the-remaining-nodes)
  - [View the etcd member list](#view-the-etcd-member-list)
  - [Check the etcd status](#check-the-etcd-status)
  - [Patroni setup](#patroni-setup)
    - [Copy the createRoles.sh script](#copy-the-createroles-sh-script)
    - [Empty the postgres data directory](#empty-the-postgres-data-directory)
    - [Run the setupPatroni script](#run-the-setuppatroni-script)
    - [The generated patroni config file](#the-generated-patroni-config-file)
  - [Understanding the patroni configuration file](#understanding-the-patroni-configuration-file)
    - [Cluster Identity and Logging](#cluster-identity-and-logging)
    - [Management Interfaces (restapi and etcd3)](#management-interfaces-restapi-and-etcd3)
    - [Bootstrap Configuration](#bootstrap-configuration)
    - [Tags](#tags)
  - [Starting patroni](#starting-patroni)
    - [Start patroni on the remaining nodes 1 at a time.](#start-patroni-on-the-remaining-nodes-1-at-a-time)
  - [Some patroni administrative tasks](#some-patroni-administrative-tasks)
    - [Change a postgres setting with patronictl](#change-a-postgres-setting-with-patronictl)
    - [Changing the pg_hba config file](#changing-the-pg_hba-config-file)
    - [patronictl  (Failover vs Switchover)](#patronictl-failover-vs-switchover)
      - [Failover](#failover)
      - [Switchover](#switchover)
      - [Running patronictl with failover](#running-patronictl-with-failover)
      - [Running patronictl with switchover](#running-patronictl-with-switchover)
  - [Connecting to the database and using libpq's built in functionality](#connecting-to-the-database-and-using-libpqs-built-in-functionality)
    - [Connection String Load Balancing Parameters](#connection-string-load-balancing-parameters)
  - [What is pgBackRest](#what-is-pgbackrest)
  - [pgbackrest setup](#pgbackrest-setup)
    - [Create a backup server](#create-a-backup-server)
    - [Create pgbackrest configuration file](#create-pgbackrest-configuration-file)
    - [Explanation of the settings](#explanation-of-the-settings)
    - [Create pgbackrest.conf on database servers](#create-pgbackrest-conf-on-database-servers)
    - [Create the stanza](#create-the-stanza)
    - [Update postgres config using patronictl to use pgbackrest](#update-postgres-config-using-patronictl-to-use-pgbackrest)
    - [Create a backup](#create-a-backup)
    - [pgBackrest Online Documentation](#pgbackrest-online-documentation)
  - [Apendix](#apendix)
    - [Manual setup process](#manual-setup-process)
      - [Directory structure for centralized configuration.](#directory-structure-for-centralized-configuration)
      - [Creating a separate server for the pgBackrest repo server ( pgbackrest1 )](#creating-a-separate-server-for-the-pgbackrest-repo-server-pgbackrest1)
  - [More to come ...](#more-to-come)


# Deploying and Securing High Availability Postgres with Patroni and pgBackrest

Welcome to this free, self paced training documentation offered by Postgres Solutions! This comprehensive material is designed to guide you through the critical concepts and practical implementation of running a highly available database cluster using Postgres, orchestrated by Patroni, and leveraging etcd for distributed consensus.

We aim to break down complex topics, clarify common pitfalls (like quorum sizing), and provide step by step instructions to build a resilient system.

## License and Credit

This documentation is provided for personal, self paced training. If you plan to utilize this documentation outside of self training, for instance, as a base for creating additional training materials, tutorials, or public documentation you **must** give credit to postgressolutions.com and Jorge Torralba. Your cooperation helps support the creation of future educational content.

## Support Our Work

If you find significant value in this free training and feel that it has enhanced your understanding of high availability Postgres, please consider making a donation. Your support goes a long way toward producing and maintaining additional high quality, free training materials. You can donate here:

https://www.paypal.com/donate/?hosted_button_id=J2HWPPWX8EBNC


## About this tutorial

If you're reading this or expressing an interest in this topic, you are likely already familiar with Patroni. This powerful tool elegantly solves the problem of high availability for Postgres by orchestrating replication, failover, and self healing. Patroni's primary function is to turn a collection of standard Postgres instances into a robust, resilient cluster.

This comprehensive tutorial guides you through setting up a highly available (HA) Postgres cluster using Patroni. You'll not only learn the practical steps but also gain the fundamental concepts required to avoid common pitfalls in production deployments. We'll also integrate pgBackrest to ensure you have a robust, reliable backup and recovery strategy because high availability is incomplete without reliable data protection.

To focus purely on the architecture and consensus mechanics without complex installation steps, we will be leveraging Docker containers. These containers conveniently include Postgres, Patroni, and etcd with many necessary dependencies pre configured. We will carefully walk through the configuration and setup process, ensuring you gain a complete and clear understanding of how these components interact and how to properly secure your critical quorum for true high availability.


# First things first

**While etcd serves as the primary Distributed Consensus Store (DCS) for Patroni, its deployment is frequently misconfigured. I've observed numerous deployments where administrators run etcd directly alongside the Postgres database instance. This common setup leads to a false sense of security, as it demonstrates a fundamental misunderstanding of quorum and eliminates the failover protection that a DCS is meant to provide.**

## Do not skip this section

## The etcd Mystery and Critical Misconception

There is a fundamental part of the Patroni architecture that is often **grossly** **overlooked** or **misunderstood**, the role and sizing of the Distributed Consensus Store. In the context of Patroni, this is typically etcd.

Patroni uses etcd to elect the primary, register cluster members, and ensure that only one node believes it is the leader at any given time, a concept known as a quorum. **If you come from the mindset that the number of etcd nodes you need is simply based on the number of Postgres nodes divided by two, plus one, you have been profoundly misled.**

***etcd nodes = ( postgres nodes / 2 ) + 1***

This rule of thumb is a common source of confusion and instability! **The size of your etcd cluster is independent of your Postgres node count** and is governed only by the need to maintain a reliable quorum for etcd itself.

Understanding why and how to size your etcd cluster correctly is essential for true high availability, and you **must** read the following to learn the proper methodology.

## Your patroni node count does not determine your etcd quorum

The core misunderstanding is failing to distinguish between the Patroni cluster (your data layer) and the etcd cluster (your consensus layer).

**Patroni/Postgres Nodes (Data):**

*These nodes are the actual database servers. Their count determines how many copies of the data you have and where the Primary can run.*

**etcd Nodes (Consensus):**

*These nodes hold the metadata about the cluster (who the current Primary is, who the members are, etc.). They use an algorithm like Raft to ensure this metadata is consistently agreed upon by a quorum.*

The availability of your Patroni cluster relies entirely on the availability of its etcd quorum. If the etcd cluster loses its quorum, Patroni cannot safely elect a new Primary or switch roles, even if the underlying Postgres data nodes are healthy.

On a side note, this heavy dependency on etcd and the Patroni layer managing Postgres, is why I favor pgPool in some cases.

## The correct etcd quorum sizing rule

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


**With that said, our tutorial and examples used throughout this documentation will be based on 3 postgres servers running etcd and 2 additional etcd servers to make up the needed difference.**


## A word about the Docker deployment for this tutorial

### Centralized Administration via /pgha

For this tutorial, we are simplifying administration by deviating from typical Postgres and service configurations. We centralize most essential components including configuration files (patroni.yaml), application data (etcd and Postgres), and necessary scripts into a single root directory: /pgha.

This approach makes administrative and troubleshooting tasks significantly easier since almost everything required to manage the Patroni, Postgres, and etcd services is located in one predictable place.



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


## Simplifying deployment with genDeploy

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

## Create your deployment files

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




## Create the aliases

Even though we wont be using the etcd aliases for our config, we will be using the pgbackrest1 alias for our pgbackrest server. With thatsaid, lets make the necessary changes to /etc/hosts

**As the user root**

To create the aliases so we can reference the nodes by the names etcd1, etcd2 ... we just need to make a minor change to the /etc/hosts file

    192.168.50.10   pgha1 etcd1
    192.168.50.11   pgha2 etcd2
    192.168.50.12   pgha3 etcd3
    192.168.50.13   pgha4 etcd4
    192.168.50.14   pgha5 etcd5 pgbackrest1

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
    192.168.50.14   pgha5 etcd5 pgbackrest1

Now copy the file to the other servers

    scp /etc/hosts pgha2:/etc/
    scp /etc/hosts pgha3:/etc/
    scp /etc/hosts pgha4:/etc/
    scp /etc/hosts pgha5:/etc/

At this point we should now be able to access the servers using the aliases and not just the host names.

Keep in mind, this was all optional incase you want to setup etcd and pgBackrest for access using a more descriptive name.


## setup logging folders and permissions

**The necessary configuration has already been implemented within the rocky9-pg17-bundle Docker image, making this step optional. Should you wish to gain a thorough understanding of the underlying process, please consult the Appendix below for details.**


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

Which generates the following config file using the host names .

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

If you wanted to create the etcd config using the aliases we added to the /etc/hosts file you would add the -e flag to the etcdSetup script.

     /etcdSetup.sh -y -e

Which generates the following config file using the etcd names .

    name: etcd1
    initial-cluster: "etcd1=http://192.168.50.10:2380,etcd2=http://192.168.50.11:2380,etcd3=http://192.168.50.12:2380,etcd4=http://192.168.50.13:2380,etcd5=http://192.168.50.14:2380"
    initial-cluster-token: pgha-token
    data-dir: /pgha/data/etcd
    initial-cluster-state: new
    initial-advertise-peer-urls: "http://192.168.50.10:2380"
    listen-peer-urls: "http://192.168.50.10:2380"
    listen-client-urls: "http://192.168.50.10:2379,http://localhost:2379"
    advertise-client-urls: "http://192.168.50.10:2379"

Notice how it is now using the name etcd1 ... etcd5 instead of the actual host name of pgha1 ... pgha5

**Take note of the export command at the end. Copy and run it now or add it to the  profile .pgsql_profile file.**

The output above also shows the content of the **/pgha/config/etcd.yaml**  generated.

**Moving forward, we will be using the regular hostname for our configuration.**

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


## What do all the etcd settings mean


    name:       pgha1

This is the human readable name for this specific etcd member instance. It must be unique within the cluster. Patroni uses this DCS to manage its cluster, so naming the etcd nodes clearly (e.g., pgha1, pgha2, etc.) is helpful.

    initial-cluster: pgha1=http://192.168.50.10:2380,pgha2=http://192.168.50.11:2380,pgha3=http://192.168.50.12:2380,pgha4=http://192.168.50.13:2380,pgha5=http://192.168.50.14:2380

This defines the complete list of all members in the etcd cluster and their corresponding peer URLs (where they listen for inter node communication). This is essential for bootstrapping the cluster for the first time.

    initial-cluster-token:      pgha-token

A unique string that helps etcd distinguish this cluster from other etcd clusters. This prevents accidental merging of two separate clusters during bootstrapping.

    data-dir:   /pgha/data/etcd



The file system directory where etcd stores all its data, including the write-ahead log (WAL) and the backend database. This directory should be persistent.

    initial-cluster-state:       new


When set to new, etcd knows it's initiating a brand new cluster based on the members listed in initial-cluster. This should only be used when starting the cluster for the very first time.

    initial-advertise-peer-urls:        http://192.168.50.10:2380

This is the URL that this etcd member (pgha1) uses to advertise itself to the other members of the cluster. It's the address the other nodes will use to communicate with it. Port 2380 is the standard etcd peer port.

    listen-peer-urls:   http://192.168.50.10:2380

This is the URL(s) on which this etcd member listens for communication from other etcd members (i.e., cluster traffic). This address must be reachable by other members.

    listen-client-urls: http://192.168.50.10:2379,http://localhost:2379

This is the URL(s) on which this etcd member listens for client requests (e.g., Patroni, etcdctl, or other applications) that need to read or write data. Port 2379 is the standard etcd client port.

    advertise-client-urls:      http://192.168.50.10:2379

This is the base URL that this etcd member advertises to clients (like Patroni) so they know how to connect to it. Patroni needs this address to interact with the DCS.

## Do I need to change the cluster state to existing from new

The very very short answer is **No.**

Why?  You may ask.

When you start your etcd cluster for the very first time using static bootstrapping like our 5 node cluster,  you must set initial-cluster-state: new for all nodes. This tells etcd to perform the necessary steps to form a brand new cluster using the provided configuration.

After the etcd cluster has been successfully formed and started once,  all cluster metadata is persisted in the data-dir **/pgha/data/etcd** .  On any subsequent restart of an existing member, etcd reads this persistent data, recognizes itself as part of the cluster, and ignores the initial-cluster and initial-cluster-state flags.

## When do I use existing

The initial-cluster-state: existing  is primarily used in two scenarios:

Adding a new member to an already running cluster (runtime reconfiguration). The new member is told to join the existing cluster.

Restoring from a backup or performing disaster recovery, though this often involves using the --force-new-cluster flag instead.

In our case restarting an existing member, the flag is effectively ignored once the data directory exists. We are safe to keep the configuration as it is.


## Start etcd

At this point we are ready to start etcd. Since we are **not using systemctl**, we will be starting it as a background process. Since in this tutorial, we use custom configurations, we will need to specify the config file to use with the --config-file option.  Another reason for the yaml format we used.

On pgha1 run the following command.

    nohup etcd --config-file /pgha/config/etcd.yaml > /var/log/etcd/etcd-standalone.log 2>&1 &

You can monitor the etcd log file **/var/log/etcd/etcd-standalone.log** for messages

## Start etcd on the remaining nodes

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


## Check the etcd status

We can also check the status of etcd using the **ENDPOINTS** environment variable we exported earlier.

Remember, when you ran etcdSetup.sh, it should have generated an output with the needed export command.

     export ENDPOINTS="pgha1:2380,pgha2:2380,pgha3:2380,pgha4:2380,pgha5:2380"

Again. consider adding it to your .profile for sourcing.

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

As of Patroni version 4, role creation within the patroni configuration file has been removed. You must now run a post bootstrap command to perform any additional role creation on the database cluster. For this tutorial, the post bootstrap script is createRoles.sh

The createRoles.sh script contains the necessary roles needed for this tutorial. Feel free to inspect it.

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

### Run the setupPatroni script

At this time we have done all the prework needed to run the script.

    /patroniSetup.sh
    Configuration loaded successfully from /pgha/config/patroniVars.

The above command created the configuration file **/pgha/config/patroni.yaml**. Without the script, you would have to create the file from scratch and it can be a bit overwhelming especially in it's yaml format where even 1 space can cause issues.

### The generated patroni config file

    namespace: pgha
    scope: pgha_patroni_cluster
    name: pgha2

    log:
      dir: /var/log/patroni
      filename: patroni.log
      level: INFO
      file_size: 26214400
      file_num: 4

    restapi:
        listen: 0.0.0.0:8008
        connect_address: pgha2:8008

    etcd3:
        hosts: pgha1:2379,pgha2:2379,pgha3:2379,pgha4:2379,pgha5:2379

    bootstrap:
        dcs:
            ttl: 30
            loop_wait: 10
            retry_timeout: 10
            maximum_lag_on_failover: 1048576
            postgresql:
                use_pg_rewind: true
                use_slots: true
                parameters:
                    wal_level: logical
                    hot_standby: on
                    wal_keep_size: 4096
                    max_wal_senders: 10
                    max_replication_slots: 10
                    wal_log_hints: on
                    archive_mode: on
                    archive_command: /bin/true
                    archive_timeout: 600s
                    logging_collector: 'on'
                    log_line_prefix: '%m [%r] [%p]: [%l-1] user=%u,db=%d,host=%h '
                    log_filename: 'postgresql-%a.log'
                    log_lock_waits: 'on'
                    log_min_duration_statement: 500
                    max_wal_size: 1GB

                #recovery_conf:
                    #recovery_target_timeline: latest
                    #restore_command: pgbackrest --config=/pgha/config/pgbackrest.conf --stanza= archive-get %f "%p"

        # some desired options for 'initdb'
        initdb:
            - encoding: UTF8
            - data-checksums

        post_bootstrap: /pgha/config/createRoles.sh

        pg_hba: # Add the following lines to pg_hba.conf after running 'initdb'
            - local all all trust
            - host all postgres 127.0.0.1/32 trust
            - host all postgres 0.0.0.0/0 md5
            - host replication replicator 127.0.0.1/32 trust
            - host replication replicator 0.0.0.0/0 md5

        # Users are now created in post bootstrap section

    postgresql:
        cluster_name: pgha_patroni_cluster
        listen: 0.0.0.0:5432
        connect_address: pgha2:5432
        data_dir: /pgdata/17/data
        bin_dir: /usr/pgsql-17/bin/
        pgpass: /pgha/config/pgpass

        authentication:
            replication:
                username: replicator
                password: replicator
            superuser:
                username: postgres
                password: postgres

        parameters:
            unix_socket_directories: /var/run/postgresql/

        create_replica_methods:
            - pgbackrest
            - basebackup

        #pgbackrest:
            #command: pgbackrest --config=/pgha/config/pgbackrest.conf --stanza=stanza= --delta restore
            #keep_data: True
            #no_params: True

        #recovery_conf:
            #recovery_target_timeline: latest
            #restore_command: pgbackrest --config=/pgha/config/pgbackrest.conf --stanza= archive-get %f \"%p\"

        basebackup:
            checkpoint: 'fast'
            wal-method: 'stream'

    tags:
        nofailover: false
        noloadbalance: false
        clonefrom: false
        nosync: false



## Understanding the patroni configuration file

### Cluster Identity and Logging

This top section defines the identity of the cluster and how Patroni itself should handle logging.

**namespace: pgha**

This is the top level directory/key prefix in the DCS (etcd) where Patroni stores all data related to its clusters. It ensures multiple Patroni installations can share the same DCS without conflicts.

**scope: pgha_patroni_cluster**

This is the unique identifier for the entire Patroni cluster. All members of this HA group must have the same scope. It is used to form the key /pgha/pgha_patroni_cluster/ in etcd.

**name: pgha1**

This is the unique name of this specific Patroni member (the node Patroni is running on).

**log:**

Standard logging controls for the Patroni process itself (**not the Postgres logs**). It dictates where the patroni.log file is written, its size limits and the level of detail.

### Management Interfaces (restapi and etcd3)

These sections define how Patroni communicates with the outside world (for health checks/management) and with the Distributed Configuration Store (DCS).

**restapi:**

**listen: 0.0.0.0:8008**

The IP address and port where the Patroni REST API listens for connections. This is crucial for health checks, service discovery, and management tools (like patronictl).

**connect_address: pgha1:8008**

The IP/hostname and port that Patroni advertises to the DCS as its contact address. Load balancers and other tools use this to find the node's REST API.

**etcd3** (or zookeeper, consul etc. for other DCS types):

**hosts: pgha1:2379,pgha2:2379,...**

A list of client connection URLs for the etcd cluster. Patroni uses these addresses to read and write the cluster state (which node is primary, which are replicas, etc.).

### Bootstrap Configuration

The bootstrap section contains settings used only when a new cluster is being initialized, or a new member is joining a cluster for the first time.

**bootstrap.dcs:**

These settings primarily control Patroni's behavior during cluster management.

**ttl:** Time To Live (in seconds). This is the interval at which a Patroni member must update its entry in the DCS to show it's alive. If the entry expires, Patroni is considered dead, triggering a failover.

**loop_wait:** The time Patroni waits between checking the cluster state and performing necessary actions (like promoting a replica or checking health).

**retry_timeout:**  How long Patroni waits to retry a failed operation on the DCS.

**maximum_lag_on_failover:**  The maximum lag (in bytes) a replica can have before it is considered ineligible to become the new primary during an automatic failover.

**bootstrap.dcs.postgresql:** Contains initial Postgres parameters Patroni uses when performing initdb or when managing the cluster for the first time.

**bootstrap.initdb:**

Contains command-line options passed directly to the initdb utility when a new cluster is created (e.g., -E UTF8, --data-checksums).

**bootstrap.post_bootstrap:**

/pgha/config/createRoles.sh

A script Patroni executes once on the initial primary node immediately after initdb has been successfully run. This is commonly used to create superusers, replication users, and databases.

**bootstrap.pg_hba:**

Defines the initial entries written to the pg_hba.conf file when Patroni runs initdb. Once the cluster is running, you should use patronictl edit-config to manage pg_hba rules dynamically.

### Tags

The tags section allows you to assign custom roles and properties to individual Patroni members. Patroni and load balancers use these to make intelligent routing and failover decisions.

**nofailover: false**

If set to true, Patroni will never select this node to become the primary during an automatic failover. This is useful for nodes dedicated to analytics or backups.

**noloadbalance: false**

If set to true, this replica will be excluded from the list of candidates returned to clients for read-only load balancing (useful if the replica has high latency).

**clonefrom: false**

If set to true, this node can be used as a source for other replicas to stream data from during initial setup.

**nosync: false**

If set to true, this node will not be considered for synchronous replication.



## Starting patroni

The Docker image contains the scripts **/startPatroni** and **/stopPatroni**. We can use these scripts to control our patroni service on the Docker container. 

    /startPatroni

Or you can start it manually using the following command.  You will need to keep track of the pid for stopping it later.  The provided script do this for you. 

    patroni /pgha/config/patroni.yaml >> /var/log/patroni/patroni.log 2>&1 &

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

Lets use ssh so we do not have to log on to each server to do this.

Again, you can use the scripts provided.

    ssh pgha2 "/startPatroni"

Or ...

    ssh pgha2 "patroni /pgha/config/patroni.yaml >> /var/log/patroni/patroni.log 2>&1 &"

Validate it was added to the patroni cluster.  Again, we use patronictl. We can do this from any of the servers in our cluster.

    patronictl -c /pgha/config/patroni.yaml list

    + Cluster: pgha_patroni_cluster (7573485601442316865) --+-----+------------+-----+
    | Member |  Host |   Role  |  State  | TL | Receive LSN | Lag | Replay LSN | Lag |
    +--------+-------+---------+---------+----+-------------+-----+------------+-----+
    | pgha1  | pgha1 | Leader  | running |  1 |             |     |            |     |
    | pgha2  | pgha2 | Replica | running |  1 |   0/4000000 |   0 |  0/4000000 |   0 |
    +--------+-------+---------+---------+----+-------------+-----+------------+-----+

At this point we have two of our 3 patroni database servers up and running now.

Lets repeat the process for node pgha3

    ssh pgha3 "cp -p /createRoles.sh /pgha/config; rm -rf /pgdata/17/data/; /patroniSetup.sh"

Now start it

    ssh pgha3 "/startPatroni"

Or ...

ssh pgha3 "nohup patroni /pgha/config/patroni.yaml > patroni.log 2>&1 &"

Final validation

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


Utilizing patroni for HA requires relinquishing direct control over local postgres configuration files. This architectural choice represents a fundamental shift in operations, committing you to patroni's control plane. This process necessitates interacting with the cluster via the patroni utility (patronictl) to modify parameters like those in postgresql.conf or pg_hba.conf.

While this new management layer introduces an initial learning curve and can feel restrictive compared to traditional manual editing, it is the essential mechanism that ensures configuration integrity and state enforcement across all nodes in the HA cluster.


**Personal Side Note:**

***While Patroni is an absolutely awesome high availability tool, its architecture, which involves taking over almost all Postgres administrative and configuration tasks, can sometimes feel overwhelming for newcomers. For those seeking similar high availability functionality including connection pooling, load balancing, and replication management without Patroni's deep integration and complexity, I personally lean towards pgpool. pgpool sits between the client and Postgres, offering powerful features without completely taking over the underlying database administration. I will be publishing a pgpool tutorial as well***


### Change a postgres setting with patronictl

Our deploy, is using the default value of 128MB for shared_buffers.

    psql -c "show shared_buffers"

     shared_buffers
    ----------------
     128MB
    (1 row)

If we wanted to change shared_buffers to 256MB we would have to run:

     patronictl -c /pgha/config/patroni.yaml edit-config

Which would then open up the editor with the current configuration as stored in the DCS as you can see below.
Add the entry for **shared_buffers: 256MB**, save and confirm the changes when prompted.

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
        shared_buffers: 256MB
        wal_keep_size: 4096
        wal_level: logical
        wal_log_hints: true
      pg_hba:
      - host all bubba 0.0.0.0/0 md5
      - local all all trust
      - host all postgres 127.0.0.1/32 trust
      - host all postgres 0.0.0.0/0 md5
      - host replication replicator 127.0.0.1/32 trust
      - host replication replicator 0.0.0.0/0 md5
      use_pg_rewind: true
      use_slots: true
    retry_timeout: 10
    ttl: 30

Once the above has been saved and confirmed, it will be propagated to the other nodes.  And as you may already know, a change to **shared_buffers** requires a restart.

Lets see the status of the cluster after making the change.

    patronictl -c /pgha/config/patroni.yaml list

    + Cluster: pgha_patroni_cluster (7575415324175827441) ----+-----+------------+-----+-----------------+------------------------------+
    | Member |  Host |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag | Pending restart |    Pending restart reason    |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+-----------------+------------------------------+
    | pgha1  | pgha1 | Leader  | running   |  4 |             |     |            |     | *               | shared_buffers: 128MB->256MB |
    | pgha2  | pgha2 | Replica | streaming |  4 |   0/8000168 |   0 |  0/8000168 |   0 | *               | shared_buffers: 128MB->256MB |
    | pgha3  | pgha3 | Replica | streaming |  4 |   0/8000168 |   0 |  0/8000168 |   0 | *               | shared_buffers: 128MB->256MB |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+-----------------+------------------------------+

As you can see, it is advising the changes are waiting for a restart before they take effect.

This is how we restart the cluster.


    patronictl -c /pgha/config/patroni.yaml restart pgha_patroni_cluster

    + Cluster: pgha_patroni_cluster (7575415324175827441) ----+-----+------------+-----+-----------------+------------------------------+
    | Member |  Host |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag | Pending restart |    Pending restart reason    |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+-----------------+------------------------------+
    | pgha1  | pgha1 | Leader  | running   |  4 |             |     |            |     | *               | shared_buffers: 128MB->256MB |
    | pgha2  | pgha2 | Replica | streaming |  4 |   0/8000168 |   0 |  0/8000168 |   0 | *               | shared_buffers: 128MB->256MB |
    | pgha3  | pgha3 | Replica | streaming |  4 |   0/8000168 |   0 |  0/8000168 |   0 | *               | shared_buffers: 128MB->256MB |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+-----------------+------------------------------+

    When should the restart take place (e.g. 2025-11-22T06:46)  [now]:
    Are you sure you want to restart members pgha1, pgha2, pgha3? [y/N]: y
    Restart if the PostgreSQL version is less than provided (e.g. 9.5.2)  []:
    Success: restart on member pgha1
    Success: restart on member pgha2
    Success: restart on member pgha3

Another list, shows us we are good.

     patronictl -c /pgha/config/patroni.yaml list

    + Cluster: pgha_patroni_cluster (7575415324175827441) ----+-----+------------+-----+
    | Member |  Host |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+
    | pgha1  | pgha1 | Leader  | running   |  4 |             |     |            |     |
    | pgha2  | pgha2 | Replica | streaming |  4 |   0/9000ED8 |   0 |  0/9000ED8 |   0 |
    | pgha3  | pgha3 | Replica | streaming |  4 |   0/9000ED8 |   0 |  0/9000ED8 |   0 |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+

And we can now see the change has been applied.

     psql -c "show shared_buffers"

     shared_buffers
    ----------------
     256MB
    (1 row)

### Changing the pg_hba config file

To modify the pg_hba.conf rules in a patroni controlled cluster, you must use the patronictl edit-config command.

Preserve your existing rules! When editing the configuration via patronictl edit-config, you must ensure that your existing pg_hba entries are included in the new configuration block. If you only provide the new entry, all previous rules will be overwritten and lost when patroni applies the change.

It is strongly recommended to review the current rules by examining the database configuration before editing. You can view the currently enforced configuration by running:

    cat $PGDATA/pg_hba.conf

Then, carefully integrate these existing rules with your new modifications within the edit-config session if they are not visible in the pg_hba block.

Changes to connection authentication (pg_hba) require postgres to reload its configuration. After saving your changes in patronictl edit-config, you must execute a non-disruptive reload on the cluster:

    patronictl reload <cluster_name>

Note: A full restart is often not necessary for pg_hba changes, but a reload is required.  Validate this by once again running 

    cat $PGDATA/pg_hba.conf

In the rare occasion that you do not see the changes in the file, you may have to restart the service instaed using 

    patronictl reload <cluster_name>


### patronictl Failover vs Switchover

The primary difference between a failover and a switchover in Patroni lies in who initiates the action and the intent behind the role change.

#### Failover

A failover is an unplanned, automatic process where Patroni detects that the current Primary node is unavailable or unhealthy (based on the cluster's health checks and loop_wait settings).

 - Patroni's cluster members notice the primary's status key in the DCS  (etcd) has expired.
 - The remaining healthy replica nodes race to  acquire the leader key from etcd.
 - The winning replica is promoted to  the new primary.
 - The remaining replicas reconfigure themselves to  stream data from the new primary.

The goal of a failover is to maintain service availability with the highest priority, assuming the old Primary is dead.

#### Switchover

A switchover is a controlled, planned process initiated manually by the database administrator using the patronictl switchover command.

- The administrator specifies the current primary and the desired target replica to be promoted.
- Patroni confirms that the target replica is fully synchronized with the current primary (zero lag).
- Patroni contacts the current primary and instructs it to demote itself to a replica and stop accepting writes.
- Patroni promotes the healthy target replica to the new Primary.
- The old primary and all other replicas automatically reconfigure themselves to follow the new primary.

The switchover is executed to minimize downtime for tasks like OS patching, hardware migration, or verifying that the failover mechanism works smoothly.

**Why have a failover option with patronictl if it's automatic?**

Patroni provides commands to trigger both a manual switchover (**patronictl switchover**) and a manual failover (**patronictl failover**) is to give you, the administrator complete control over the cluster's state during maintenance, recovery, or testing scenarios that fall outside of the normal automatic processes.

Here we can see the current state of our cluster.  It shows us that pgha3 is the **Leader** ( Primary )

    patronictl -c /pgha/config/patroni.yaml list

    + Cluster: pgha_patroni_cluster (7573485601442316865) ----+-----+------------+-----+
    | Member |  Host |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+
    | pgha1  | pgha1 | Replica | streaming |  5 |   0/F000000 |   0 |  0/F000000 |   0 |
    | pgha2  | pgha2 | Replica | streaming |  5 |   0/F000000 |   0 |  0/F000000 |   0 |
    | pgha3  | pgha3 | Leader  | running   |  5 |             |     |            |     |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+

#### Running patronictl with failover

If we wanted to make pgha1 the new primary, we could simply run the following command with the following prompts and results.

 patronictl -c /pgha/config/patroni.yaml failover


    Current cluster topology
    + Cluster: pgha_patroni_cluster (7573485601442316865) ----+-----+------------+-----+
    | Member |  Host |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+
    | pgha1  | pgha1 | Replica | streaming |  5 |   0/F000000 |   0 |  0/F000000 |   0 |
    | pgha2  | pgha2 | Replica | streaming |  5 |   0/F000000 |   0 |  0/F000000 |   0 |
    | pgha3  | pgha3 | Leader  | running   |  5 |             |     |            |     |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+

    Candidate ['pgha1', 'pgha2'] []: pgha1
    Are you sure you want to failover cluster pgha_patroni_cluster, demoting current leader pgha3? [y/N]: y
    2025-11-19 04:25:03.59276 Successfully failed over to "pgha1"

    + Cluster: pgha_patroni_cluster (7573485601442316865) --+-----+------------+-----+
    | Member |  Host |   Role  |  State  | TL | Receive LSN | Lag | Replay LSN | Lag |
    +--------+-------+---------+---------+----+-------------+-----+------------+-----+
    | pgha1  | pgha1 | Leader  | running |  5 |             |     |            |     |
    | pgha2  | pgha2 | Replica | running |  5 |  0/100000A0 |   0 | 0/100000A0 |   0 |
    | pgha3  | pgha3 | Replica | stopped |    |     unknown |     |    unknown |     |
    +--------+-------+---------+---------+----+-------------+-----+------------+-----+

Notice the old Leader is not yet in a stable state, it is rebuilding itself.

Running the following once more, shows us that all is now operating as expected.

patronictl -c /pgha/config/patroni.yaml list

    + Cluster: pgha_patroni_cluster (7573485601442316865) ----+-----+------------+-----+
    | Member |  Host |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+
    | pgha1  | pgha1 | Leader  | running   |  6 |             |     |            |     |
    | pgha2  | pgha2 | Replica | streaming |  6 |  0/100001E0 |   0 | 0/100001E0 |   0 |
    | pgha3  | pgha3 | Replica | streaming |  6 |  0/100001E0 |   0 | 0/100001E0 |   0 |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+

#### Running patronictl with switchover

     patronictl -c /pgha/config/patroni.yaml switchover

    Current cluster topology
    + Cluster: pgha_patroni_cluster (7573485601442316865) ----+-----+------------+-----+
    | Member |  Host |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+
    | pgha1  | pgha1 | Leader  | running   |  6 |             |     |            |     |
    | pgha2  | pgha2 | Replica | streaming |  6 |  0/100001E0 |   0 | 0/100001E0 |   0 |
    | pgha3  | pgha3 | Replica | streaming |  6 |  0/100001E0 |   0 | 0/100001E0 |   0 |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+

    Primary [pgha1]:
    Candidate ['pgha2', 'pgha3'] []: pgha2
    When should the switchover take place (e.g. 2025-11-19T05:27 )  [now]:
    Are you sure you want to switchover cluster pgha_patroni_cluster, demoting current leader pgha1? [y/N]: y

    2025-11-19 04:27:57.58415 Successfully switched over to "pgha2"

    + Cluster: pgha_patroni_cluster (7573485601442316865) --+-----+------------+-----+
    | Member |  Host |   Role  |  State  | TL | Receive LSN | Lag | Replay LSN | Lag |
    +--------+-------+---------+---------+----+-------------+-----+------------+-----+
    | pgha1  | pgha1 | Replica | stopped |    |     unknown |     |    unknown |     |
    | pgha2  | pgha2 | Leader  | running |  7 |             |     |            |     |
    | pgha3  | pgha3 | Replica | running |  6 |  0/110000A0 |   0 | 0/110000A0 |   0 |
    +--------+-------+---------+---------+----+-------------+-----+------------+-----+

And now our new Leader is pgha2

    patronictl -c /pgha/config/patroni.yaml list

    + Cluster: pgha_patroni_cluster (7573485601442316865) ----+-----+------------+-----+
    | Member |  Host |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+
    | pgha1  | pgha1 | Replica | streaming |  7 |  0/110001E0 |   0 | 0/110001E0 |   0 |
    | pgha2  | pgha2 | Leader  | running   |  7 |             |     |            |     |
    | pgha3  | pgha3 | Replica | streaming |  7 |  0/110001E0 |   0 | 0/110001E0 |   0 |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+


## Connecting to the database and using libpq's built in functionality

Using a psql connection string to achieve client side load balancing and failover across multiple Postgres servers is possible by leveraging specific connection parameters, namely host, load_balance_hosts, and target_session_attrs.

This functionality is built into the libpq library, which psql and many other Postgres clients use.

We can now access our patroni cluster from the host machine without being inside a docker container.  We achieve this by using the mapped ports to postgres.

### Connection String Load Balancing Parameters

The general format involves listing multiple servers in the host parameter and then specifying how libpq should choose which one to connect to.

**The host Parameter (Multiple Entries)**

Instead of listing a single IP or hostname, you provide a comma-separated list of server addresses.

    host=pgha1,pgha2,pgha3

**The target_session_attrs Parameter (Failover/Load Balancing)**

This parameter tells the client the desired state (or role) of the server it intends to connect to. This is crucial for distinguishing between the Primary and Replica nodes.

This connects to the first available server regardless of its role, attempting them in the order listed.

    psql "host=pgha1,pgha2,pgha3 dbname=foobar user=bubba target_session_attrs=any"


This is a typical setup for a primary seeking client. It attempts to connect to any host, starting with a random selection, but only if that host is the writeable Primary server.

    psql "host=pgha1,pgha2,pgha3 dbname=foobar user=bubba target_session_attrs=read-write load_balance_hosts=random"

This setup is ideal for connecting read-intensive clients. It randomly selects one of the replica hosts (pgha2, pgha3) and ensures it connects only to a read-only server.


    psql "host=pgha1,pgha2,pgha3   port=5432,5432,5432  dbname=foobar user=bubba  target_session_attrs=read-only  load_balance_hosts=random"


In order to connect to the servers from outside of the container, we can use the port mappings defined in our docker run command which is showin in the file DockerRunThis.pgha


     docker ps
    CONTAINER ID   IMAGE                COMMAND                  CREATED        STATUS        PORTS                                                                                                                                                                                                                   NAMES
    0678ebcc6897   rocky9-pg17-bundle   "/bin/bash -c /entry…"   31 hours ago   Up 31 hours   22/tcp, 80/tcp, 443/tcp, 2379-2380/tcp, 5000-5001/tcp, 6032-6033/tcp, 6132-6133/tcp, 7000/tcp, 8008/tcp, 8432/tcp, 9898/tcp, 0.0.0.0:6436->5432/tcp, [::]:6436->5432/tcp, 0.0.0.0:9996->9999/tcp, [::]:9996->9999/tcp   pgha5
    3d4176eb4ad6   rocky9-pg17-bundle   "/bin/bash -c /entry…"   31 hours ago   Up 31 hours   22/tcp, 80/tcp, 443/tcp, 2379-2380/tcp, 5000-5001/tcp, 6032-6033/tcp, 6132-6133/tcp, 7000/tcp, 8008/tcp, 8432/tcp, 9898/tcp, 0.0.0.0:6435->5432/tcp, [::]:6435->5432/tcp, 0.0.0.0:9995->9999/tcp, [::]:9995->9999/tcp   pgha4
    fe0d666b46c4   rocky9-pg17-bundle   "/bin/bash -c /entry…"   31 hours ago   Up 31 hours   22/tcp, 80/tcp, 443/tcp, 2379-2380/tcp, 5000-5001/tcp, 6032-6033/tcp, 6132-6133/tcp, 7000/tcp, 8008/tcp, 8432/tcp, 9898/tcp, 0.0.0.0:6434->5432/tcp, [::]:6434->5432/tcp, 0.0.0.0:9994->9999/tcp, [::]:9994->9999/tcp   pgha3
    ad917ca32d0a   rocky9-pg17-bundle   "/bin/bash -c /entry…"   31 hours ago   Up 31 hours   22/tcp, 80/tcp, 443/tcp, 2379-2380/tcp, 5000-5001/tcp, 6032-6033/tcp, 6132-6133/tcp, 7000/tcp, 8008/tcp, 8432/tcp, 9898/tcp, 0.0.0.0:6433->5432/tcp, [::]:6433->5432/tcp, 0.0.0.0:9993->9999/tcp, [::]:9993->9999/tcp   pgha2
    a312b7253c47   rocky9-pg17-bundle   "/bin/bash -c /entry…"   31 hours ago   Up 7 hours    22/tcp, 80/tcp, 443/tcp, 2379-2380/tcp, 5000-5001/tcp, 6032-6033/tcp, 6132-6133/tcp, 7000/tcp, 8008/tcp, 8432/tcp, 9898/tcp, 0.0.0.0:6432->5432/tcp, [::]:6432->5432/tcp, 0.0.0.0:9992->9999/tcp, [::]:9992->9999/tcp   pgha1


 You can see that for pgha1, pgha2 and pgha3 we are mapping ports 6432, 6433 and 6434 to postgres port 5432 inside the containers.

So if we wanted to connect directly to pgha1, we simply use the following connections string for psql

    psql -h localhost -p 6432 -U postgres
    Password for user postgres:
    psql (17.6)
    Type "help" for help.

    postgres=# select inet_server_addr();
     inet_server_addr
    ------------------
     192.168.50.10
    (1 row)

To use postgres built in load balancing connection string with the latest version of **libpq** , the postgres client library, we use the following connection string.

    psql 'host=localhost,localhost,localhost port=6432,6433,6434 user=postgres password=postgres load_balance_hosts=random target_session_attrs=any'

Notice the list of hosts are all the same. Localhost. However, the list of ports are different.  The list of ports are in the same order as the host list. So the first port listed (6432) would be associated with the first localhost listed.

Lets break this down and how it works


As you can see, every time we execute the command, we get a random server from the list specified in our connections string.

    psql 'host=localhost,localhost,localhost port=6432,6433,6434 user=postgres password=postgres load_balance_hosts=random target_session_attrs=any' -c "select inet_server_addr()"
     inet_server_addr
    ------------------
     192.168.50.12

And another selection

     psql 'host=localhost,localhost,localhost port=6432,6433,6434 user=postgres password=postgres load_balance_hosts=random target_session_attrs=any' -c "select inet_server_addr()"
     inet_server_addr
    ------------------
     192.168.50.11
    (1 row)



## What is pgBackrest

pgBackrest is a backup and restore utility designed specifically for Postgres. Unlike generic file system backup tools, pgBackrest is postgres aware. It understands the database's architecture, including its WAL, which allows it to perform non disruptive, consistent backups and, crucially, enable Point In Time Recovery (PITR).

It facilitates full, differential, and incremental backups along with the continuous archival of WAL files, which, when combined with a full backup, lets you restore your database to any point in time right down to the second since the last full backup.

In our architecture for this tutorial , we introduce a dedicated repository server (backup host we will call **pgbackrest1**) that plays the central role in our backup strategy.

This dedicated server will host the pgbackrest repository, which is a centralized location where all our backups and WAL archives will be stored.

We will primarily run the pgbackrest backup command from the repository server. This command initiates a secure, network based connection via SSH to the Patroni cluster nodes. Lucky for us,  we already have SSH setup in our Docker containers.

We will configure the postgres via patroni to use pgbackrests's archive push command for its archive_command. This means that every time postgres generates a WAL file, it is immediately and automatically sent to the pgbackrest repository on the backup server, ensuring we have a continuous, up to the second recovery stream.

By centralizing the repository on a dedicated server, we isolate the backups from potential failures of the database cluster nodes, creating a resilient and scalable disaster recovery solution.

## pgbackrest setup

This docker image has been configured to setup the necessary directories and file permissions needed for configuring pgBackrest and other services. Therefore, we will skip some of the tedious setup tasks.  These steps will be added later to the tutorial for a better understanding.

With all that out of the way, lets start.

### Create a backup server

Since we already have two extra nodes on our cluster for etcd, we will use one of those nodes for the pgbackrest repo host.  At the beginning of this tutorial,  we configured the /etc/hosts file to use the alias pgbackrest1 with the host pgha5.  With that in mind,  pgha5 will be the server we will run pgbackrest on and there is no need to create an extra pgbackrest repo server.



### Create pgbackrest configuration file

On pgha5 as user postgres edit the **/pgha/config/pgbackrest.conf** file and add the following to it.

    [global]

    repo1-path=/pgha/data/pgbackrest
    repo1-retention-archive-type=full
    repo1-retention-full=2

    process-max=2
    log-level-console=info
    log-level-file=info
    start-fast=y
    delta=y
    backup-standby=y

    [pgha]

    pg1-host=pgha1
    pg1-port=5432
    pg1-path=/pgdata/17/data

    pg2-host=pgha2
    pg2-port=5432
    pg2-path=/pgdata/17/data

    pg3-host=pgha3
    pg3-port=5432
    pg3-path=/pgdata/17/data


### Explanation of the settings

- **repo1-path** defines the absolute path of where our backups will be saved on the repository server which in our tutorial here is pgbackrest1.
- **repo1-retention-archive-type** defines how the retention policy is applied to the archived WAL segments. Setting it to full means that all WAL segments required to restore any retained full backup will be kept. If you delete a full backup, all WAL files associated only with that backup will be removed.
- **repo1-retention-full** defines how many full backups to retain
- **process-max** defines the max number of parallel jobs that can be run for the backups, archiving, restoring etc ...
- **start-fast** attempt to skip recovery and bring the restored cluster online faster by relying on the built in Postgres recovery process to complete the transition to a consistent state
- **delta** enables delta restore, where pgBackRest only copies the files that have changed, saving significant time when restoring to a host that already has some of the data (e.g., restoring over a corrupted cluster).
- **backup-standby** allows pgbackrest to select a standby instance to execute the backup, rather than strictly requiring the primary. This reduces the performance load on the primary server.

Individual postgres instances are defined after the stanza name. For example

 - **pg2-host** Is the name or ip of the 2nd postgres instance
-  **pg2-port** is the port used by the pg2 host
 - **pg2-path** is the data directory used by pg2

The same would apply to other hosts groups like pg1 and pg3


### Create pgbackrest.conf on database servers

On pgha1 as user postgres

    vi /pgha/config/pgbackrest.conf

Add the following to it's content and save.

    [global]

    repo1-host=pgbackrest1
    repo1-host-user=postgres

    process-max=4
    log-level-console=info
    log-level-file=debug

    [pgha]

    pg1-path=/pgdata/17/data

Save the above and propagate **ONLY TO** the additional database servers.

    scp pgbackrest.conf pgha2:/pgha/config/
    scp pgbackrest.conf pgha3:/pgha/config/


### Create the stanza

On the repo server **pgbackrest1** as user postgres

    pgbackrest --stanza=pgha stanza-create

    2025-11-19 22:02:39.670 P00   INFO: stanza-create command begin 2.57.0: --exec-id=504-dd04aa73 --log-level-console=info --log-level-file=info --pg1-host=pgha1 --pg2-host=pgha2 --pg3-host=pgha3 --pg1-path=/pgdata/17/data --pg2-path=/pgdata/17/data --pg3-path=/pgdata/17/data --pg1-port=5432 --pg2-port=5432 --pg3-port=5432 --repo1-path=/pgha/data/pgbackrest --stanza=pgha
    2025-11-19 22:02:40.004 P00   INFO: stanza-create for stanza 'pgha' on repo1
    2025-11-19 22:02:40.383 P00   INFO: stanza-create command end: completed successfully (715ms)


At this point, we only created the stanza. We still have not configured our database servers.

    pgbackrest --stanza=pgha info

    stanza: pgha
        status: error (no valid backups)
        cipher: none

        db (current)
            wal archive min/max (17): none present



### Update postgres config using patronictl to use pgbackrest

On pgha1 as user postgres

     patronictl -c /pgha/config/patroni.yaml edit-config

**Make the changes to archive _command as shown below**

    loop_wait: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      parameters:
        archive_command: pgbackrest --stanza=pgha archive-push "/pgdata/17/data/pg_wal/%f"
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
      - local all all trust
      - host all all 127.0.0.1/32 trust
      - host replication replicator 127.0.0.1/32 trust
      - host replication replicator 0.0.0.0/0 md5
      - host all postgres 192.168.50.0/24 md5
      use_pg_rewind: true
      use_slots: true
    retry_timeout: 10
    ttl: 30

You will need to restart the cluster again.

    patronictl -c /pgha/config/patroni.yaml restart pgha_patroni_cluster

    + Cluster: pgha_patroni_cluster (7575415324175827441) ----+-----+------------+-----+
    | Member |  Host |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+
    | pgha1  | pgha1 | Leader  | running   |  4 |             |     |            |     |
    | pgha2  | pgha2 | Replica | streaming |  4 |   0/A000000 |   0 |  0/A000000 |   0 |
    | pgha3  | pgha3 | Replica | streaming |  4 |   0/A000000 |   0 |  0/A000000 |   0 |
    +--------+-------+---------+-----------+----+-------------+-----+------------+-----+

    When should the restart take place (e.g. 2025-11-22T07:34)  [now]:
    Are you sure you want to restart members pgha1, pgha2, pgha3? [y/N]: y
    Restart if the PostgreSQL version is less than provided (e.g. 9.5.2)  []:
    Success: restart on member pgha1
    Success: restart on member pgha2
    Success: restart on member pgha3


At this point you should be able to tail the latest postgres log file

    cd $PGDATA
    cd log
    ls -lrt

From the list shown,  it's postgresql-Fri.log

    -rw------- 1 postgres postgres 21801 Nov 22 06:34 postgresql-Sat.log


From one terminal run

    tail -f postgresql-Sat.log

From another terminal run

    psql -h pgha1 -c "SELECT pg_switch_wal()"

Your terminal with the tail command should then display the archiving results.


    2025-11-22 06:39:06.756 UTC [] [1078]: [1-1] user=,db=,host= LOG:  checkpoint starting: time
    2025-11-22 06:39:06.795 UTC [] [1078]: [2-1] user=,db=,host= LOG:  checkpoint complete: wrote 3 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.004 s, sync=0.002 s, total=0.040 s; sync files=2, longest=0.001 s, average=0.001 s; distance=16384 kB, estimate=16384 kB; lsn=0/C0000B8, redo lsn=0/C000060
    2025-11-22 06:41:01.649 P00   INFO: archive-push command begin 2.57.0: [/pgdata/17/data/pg_wal/00000004000000000000000C] --exec-id=1114-4ecccb96 --log-level-console=info --log-level-file=debug --pg1-path=/pgdata/17/data --process-max=4 --repo1-host=pgbackrest1 --repo1-host-user=postgres --stanza=pgha
    2025-11-22 06:41:01.862 P00   INFO: pushed WAL file '00000004000000000000000C' to the archive
    2025-11-22 06:41:01.962 P00   INFO: archive-push command end: completed successfully (315ms)



### Create a backup

Backups need to be started on the repo server ( pgbackrest1 ) as user postgres.  Remember pgbackrest1 is an alias to pgha5 which is where we are hosting our repository.

    ssh pgbackrest1 "pgbackrest  --stanza=pgha --type=full backup"

This should kick off a full backup

    2025-11-22 06:43:36.389 P00   INFO: backup command begin 2.57.0: --backup-standby=y --delta --exec-id=506-36e0cca9 --log-level-console=info --log-level-file=info --pg1-host=pgha1 --pg2-host=pgha2 --pg3-host=pgha3 --pg1-path=/pgdata/17/data --pg2-path=/pgdata/17/data --pg3-path=/pgdata/17/data --pg1-port=5432 --pg2-port=5432 --pg3-port=5432 --process-max=2 --repo1-path=/pgha/data/pgbackrest --repo1-retention-archive-type=full --repo1-retention-full=2 --stanza=pgha --start-fast --type=full
    2025-11-22 06:43:36.688 P00   INFO: execute non-exclusive backup start: backup begins after the requested immediate checkpoint completes
    2025-11-22 06:43:36.804 P00   INFO: backup start archive = 00000004000000000000000E, lsn = 0/E000028
    2025-11-22 06:43:36.804 P00   INFO: wait for replay on the standby to reach 0/E000028
    2025-11-22 06:43:36.918 P00   INFO: replay on the standby reached 0/E000028
    2025-11-22 06:43:36.918 P00   INFO: check archive for prior segment 00000004000000000000000D
    2025-11-22 06:43:39.492 P00   INFO: execute non-exclusive backup stop and wait for all WAL segments to archive
    2025-11-22 06:43:39.501 P00   INFO: backup stop archive = 00000004000000000000000E, lsn = 0/E000158
    2025-11-22 06:43:39.545 P00   INFO: check archive for segment(s) 00000004000000000000000E:00000004000000000000000E
    2025-11-22 06:43:39.954 P00   INFO: new backup label = 20251122-064336F
    2025-11-22 06:43:40.025 P00   INFO: full backup size = 22.2MB, file total = 974
    2025-11-22 06:43:40.025 P00   INFO: backup command end: completed successfully (3637ms)
    2025-11-22 06:43:40.025 P00   INFO: expire command begin 2.57.0: --exec-id=506-36e0cca9 --log-level-console=info --log-level-file=info --repo1-path=/pgha/data/pgbackrest --repo1-retention-archive-type=full --repo1-retention-full=2 --stanza=pgha
    2025-11-22 06:43:40.126 P00   INFO: expire command end: completed successfully (101ms)


We can now check our repo status for backups with the **info** flag

    ssh pgbackrest1 "pgbackrest  --stanza=pgha info"

   Which gives us information about our repo and backups

    stanza: pgha
        status: ok
        cipher: none

        db (current)
            wal archive min/max (17): 00000004000000000000000A/00000004000000000000000E

            full backup: 20251122-064336F
                timestamp start/stop: 2025-11-22 06:43:36+00 / 2025-11-22 06:43:39+00
                wal start/stop: 00000004000000000000000E / 00000004000000000000000E
                database size: 22.2MB, database backup size: 22.2MB
                repo1: backup set size: 2.9MB, backup size: 2.9MB




### pgBackrest Online Documentation

https://pgbackrest.org/user-guide.html


## Apendix

### Manual setup process

The following steps are what have been omitted from the above due to Docker automation.

#### Directory structure for centralized configuration

**All servers in the cluster** should have the following directories created with the noted ownership and privileges.

**As user root** perform the following on each server.

For logging purposes 

    mkdir -p /var/log/etcd
    mkdir -p /var/log/patroni
    chown -R postgres:postgres /var/log/etcd
    chown -R postgres:postgres /var/log/patroni

For centralized configuration and pgbackrest data

    mkdir -p /pgha/{config,certs,data/{etcd,postgres,pgbackrest}}
    chown -R postgres:postgres /pgha

For pgbackrest changes needed to address default location of /etc. We are linking the default /etc/pgbackrest.conf to the one in our centralized location.

    chown -R postgres:postgres /etc/pgbackrest.conf
    touch /pgha/config/pgbackrest.conf
    chown postgres:postgres /pgha/config/pgbackrest.conf
    mv /etc/pgbackrest.conf /etc/pgbackrest.conf.save
    ln -s /pgha/config/pgbackrest.conf /etc/pgbackrest.conf

#### Creating a separate server for the pgBackrest repo server ( pgbackrest1 )

If we do not use one of the existing containers for pgBackrest, we can create a separate stand alone server just for the repo server.

Once again we will use genDeploy for this as it makes creating Docker containers much easier.

     ./genDeploy -c pgbackrest -w pghanet -n 1 -i rocky9-pg17-bundle

            The following docker deploy utility manager file: DockerRunThis.pgbackrest has been created. To manage your new deploy run the file "./DockerRunThis.pgbackrest"

This time our structure is much more simple.

We simply just specify a container name, the number of containers and an existing network. By attaching it to the same network, we have full access to it.

We then simply create the container from the generated DockerRunThis.pgbackrest control file and start it.


    ./DockerRunThis.pgbackrest create
    Using existing network pghanet No need to create the network at this time.
    c3ff6cbda7f7f3ec59c32630781d1014762a3257833b9e829e38c8a71bcce8c7

    ./DockerRunThis.pgbackrest start
    Starting containers  pgbackrest1
    pgbackrest1

That's it. We now have our pgbackrest1 container up and running on the same network as our other containers.

    docker ps | grep pgbackrest
    c3ff6cbda7f7   rocky9-pg17-bundle   "/bin/bash -c /entry…"   5 minutes ago   Up 5 minutes   22/tcp, 80/tcp, 443/tcp, 2379-2380/tcp, 5000-5001/tcp, 6032-6033/tcp, 6132-6133/tcp, 7000/tcp, 8008/tcp, 8432/tcp, 9898/tcp, 0.0.0.0:6438->5432/tcp, [::]:6438->5432/tcp, 0.0.0.0:9998->9999/tcp, [::]:9998->9999/tcp   pgbackrest1

You will need to apply the same new directories and privileges as noted above. However, since I am constantly enhancing the Docker image, this may already be in place.  Again, this is just informational so you have an understanding of how we create the environment.


## More to come

There is more to come. Please check in regularly to check for updates.

