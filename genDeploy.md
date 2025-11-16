

# genDeploy

### Jorge Torralba
#### Postgressolutions.com

  
This is a home brewed option to docker-compose for use with the docker image you create from this repo.  It is a first go at the project and can use feedback and improvement.  I will eventually be customized to be more flexible and universal.

## What it does

It creates a way for you to manage your docker deploy from this Pgpool repo and it's assets in a way similar to docker-compose by generating a file called **DockerRunThis** you can use to manage the deploy.

You can also use it in generic mode which allows you to generate the DockerRunThis file for other Postgres docker images besides the one in this repo.


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
    


The above will generate a DockerRunThis.xxx file for managing your deployment.

### Important:

When you generate deploy management  file by running genDeploy, make sure you either run the deploy you just created before  creating another deploy management file. This is because when you run genDeploy, it gathers information from existing docker deploys and networks to determine subnets, ip addreses and so on. Otherwise, you could generate duplicate ip addresses for the deploy DockerRunThis file. 

For example, if you were seting up a Pgpool environment. First generate your postgres dbnodes with genDeply then create them with DockerRunThis. Afterwards, run the genDeploy again for the pgpool nodes, then run the DockerRunThis file for the pgpool nodes.  

Doing the above, ensures that all current networks and ip are taken into consideration when generating the DockerRunThis files.



## Moving on .....


### For example

If you wish to create a deploy of a single Postgres node with the name  **pgdemo** running on a custom docker network called  **pgdemonet** with a subnet of **192.168.10**  you would run the following .

    ./genDeploy -s 192.168.10 -w pgdemonet -c pgdemo

Which would output the following:


    The following file: DockerRunThis.pgdemo,  contains the needed docker run commands
    
    
            ALERT -- Before starting the containers you must manually create the network pgdemonet as shown below. Or run the command again with the -y option
    
            docker network create --driver bridge --subnet 192.168.10.0/24 --gateway 192.168.10.1 pgdemonet 


Lets say you want 3 Postgres nodes. Use the **-n** option.

    ./genDeploy -s 192.168.10 -w pgdemonet -c pgdemo -n 3

Again, you get the following message

    The following file: DockerRunThis.pgdemo,  contains the needed docker run commands

In our example above **DockerRunThis.pgdemo** is our version of a docker-compose file. And from here you can control what to do.

    Usage: DockerRunThis.pgdemo [-f] {start|stop|create|rm|rmvolumes|down}
          
    Description:
          
    Manage your docker deploy generated when you ran build-docker-env
    
    Actions:
      start         Start the docker containers  pgdemo1 pgdemo2 pgdemo3
      restart       Restart the docker containers  pgdemo1 pgdemo2 pgdemo3
      stop          Stop the docker containers  pgdemo1 pgdemo2 pgdemo3
      create        Run the docker conatiners " pgdemo1 pgdemo2 pgdemo3" for the first time
      rm            Remove the docker containers  pgdemo1 pgdemo2 pgdemo3
      rmvolumes     Remove the volumes   pgdemo1-pgdata  pgdemo2-pgdata  pgdemo3-pgdata
      down          Delete everything created with this run file
       
    Options:
      -f            Force delete of volumes. Otherwise preserved




### Running the containers

    ./DockerRunThis.pgdemo create
    
    b6dc4763c2181130435ab8d3daf41722026a3ccbe9f528ce1f1fac522ced8acc
    95cf392c8ee2a665258ea8b1f219c945f9a6f4d8404573d991f9152ff9859982
    c76efefc2033a9f9a083680470e608b27622000113cf6ccc418f1ac9260e5a5e
    7900571f91bee6a108e9df3ef682bcdac0df16321c2ab6e28160d8686dd44fc3



The above created the Network and the containers

    CONTAINER ID   IMAGE                COMMAND                  CREATED          STATUS          PORTS                                                                                                                                                                                                                   NAMES
    7900571f91be   rocky9-pg17-bundle   "/bin/bash -c /entry…"   34 seconds ago   Up 34 seconds   22/tcp, 80/tcp, 443/tcp, 2379-2380/tcp, 5000-5001/tcp, 6032-6033/tcp, 6132-6133/tcp, 7000/tcp, 8008/tcp, 8432/tcp, 9898/tcp, 0.0.0.0:6437->5432/tcp, [::]:6437->5432/tcp, 0.0.0.0:9997->9999/tcp, [::]:9997->9999/tcp   pgdemo3
    c76efefc2033   rocky9-pg17-bundle   "/bin/bash -c /entry…"   35 seconds ago   Up 34 seconds   22/tcp, 80/tcp, 443/tcp, 2379-2380/tcp, 5000-5001/tcp, 6032-6033/tcp, 6132-6133/tcp, 7000/tcp, 8008/tcp, 8432/tcp, 9898/tcp, 0.0.0.0:6436->5432/tcp, [::]:6436->5432/tcp, 0.0.0.0:9996->9999/tcp, [::]:9996->9999/tcp   pgdemo2
    95cf392c8ee2   rocky9-pg17-bundle   "/bin/bash -c /entry…"   35 seconds ago   Up 35 seconds   22/tcp, 80/tcp, 443/tcp, 2379-2380/tcp, 5000-5001/tcp, 6032-6033/tcp, 6132-6133/tcp, 7000/tcp, 8008/tcp, 8432/tcp, 9898/tcp, 0.0.0.0:6435->5432/tcp, [::]:6435->5432/tcp, 0.0.0.0:9995->9999/tcp, [::]:9995->9999/tcp   pgdemo1

And the **pgdemonet** network

    docker network ls
    NETWORK ID     NAME        DRIVER    SCOPE
    7ca26fc20206   bridge      bridge    local
    d79e759c7a31   host        host      local
    8a80a92ec19f   pgdemonet   bridge    local
    5b44e038202c   poolnet     bridge    local

Our data is persistent with volumes. So you can delete the containers and retain the data. Doing so allows you to recreate the containers and access the data previoulsy stored.

    docker volume ls
    DRIVER    VOLUME NAME
    local     pg1-pgdata
    local     pg2-pgdata
    local     pg3-pgdata
    local     pgdemo1-pgdata
    local     pgdemo2-pgdata
    local     pgdemo3-pgdata
    local     pool1-pgdata
    local     pool2-pgdata

You can see the volumes above for pgdemo1, 2 and 3 

### Stopping the containers

    ./DockerRunThis.pgdemo stop

You can see they are stopped now

    ./DockerRunThis.pgdemo stop
    Stoping containers  pgdemo1 pgdemo2 pgdemo3
    pgdemo1
    pgdemo2
    pgdemo3


### Starting the containers

    ./DockerRunThis.pgdemo start
    Starting containers  pgdemo1 pgdemo2 pgdemo3
    pgdemo1
    pgdemo2
    pgdemo3

### Deleting the entire deploy

Similar to docker-compose down 

    ./DockerRunThis.pgdemo down -f

We used the -f option to force delete the volumes

     ./DockerRunThis.pgdemo down -f
     
    Attempting to delete entire depoloy 
    Stoping containers  pgdemo1 pgdemo2 pgdemo3
    pgdemo1
    pgdemo2
    pgdemo3
    Removing containers  pgdemo1 pgdemo2 pgdemo3
    pgdemo1
    pgdemo2
    pgdemo3
    Removing network demonet
    demonet
    Removing volumes   pgdemo1-pgdata  pgdemo2-pgdata  pgdemo3-pgdata
    pgdemo1-pgdata
    pgdemo2-pgdata
    pgdemo3-pgdata

Without the **-f**, we would still retain the volumes but can still delete them.  

For example, lets recreate everything again.

    ./DockerRunThis.pgdemo -a run
    d7967c913f9783881a21628b9e3cccf4c90128d0aab22a680c7e08f488164e5a
    56bdc54687294ddbfcadc5918e8439864208e039dc1ce04723e0fab9cba7477e
    e13ea756623a09dc49759139804c74ceb38cbd90d74016214a2a31fe39f8a324
    fb193de88c53afd6195159070302f670d0fab8080f69768ec5ff8f35c257179b

Now lets delete the environment **without the -f** option

    ./DockerRunThis.pgdemo down 
    
    Attempting to delete entire depoloy 
    Stoping containers  pgdemo1 pgdemo2 pgdemo3
    pgdemo1
    pgdemo2
    pgdemo3
    Removing containers  pgdemo1 pgdemo2 pgdemo3
    pgdemo1
    pgdemo2
    pgdemo3
    Removing network demonet
    demonet
    Preserving volumes. Use -f to for removal or run  rmvolumes


Notice the volumes were not deleted

    docker volume ls
    DRIVER    VOLUME NAME
    local     pg1-pgdata
    local     pg2-pgdata
    local     pg3-pgdata
    local     pgdemo1-pgdata
    local     pgdemo2-pgdata
    local     pgdemo3-pgdata
    local     pool1-pgdata
    local     pool2-pgdata

### Deleting the volumes

To actually delete the volumes after destroying the environment, simply run the following.

    ./DockerRunThis.pgdemo rmvolumes

Which removes the volumes only

    ./DockerRunThis.pgdemo rmvolumes
    
    Running docker volume rm pgdemo1-data pgdemo2-data pgdemo3-data
    pgdemo1-pgdata
    pgdemo2-pgdata
    pgdemo3-pgdata



## What if ....

### You want to build the environment and use an existing Network


If you wish to create a deploy of a single Postgres node with the name  **pgdemo** running on a custom docker network called  **poolnet**  you would run the following .

In the above example, the network poolnet already exists. 


**./genDeploy -w poolnet -c pgdemo -n 3**

When building the containers, you would see the following. Notice the first line

    ./DockerRunThis.pgdemo create
    
    Using existing network poolnet No need to create the network at this time.
    9d510265e8ba6bb6227d0cc748a910f5a586377e9c65be4f2c5ff2593485567c
    5ef7fb317ddc50dc445353db0d01f777c1699481589e8fb9f459330e9b81be22
    3faf8e971e97f9e322c38e8f5e30e9abce0dd3bc168ffe71ddc6e6b59139d0dd



If you were to looks at the DockerRunThis file, you would see the following in it

    docker run -p 6435:5432 -p 9995:9999 --env=PGPASSWORD=postgres -v pgdemo1-pgdata:/pgdata --hostname=pgdemo1 --network=poolnet --name=pgdemo1 --privileged --ip 172.28.0.14   -dt rocky9-pg17-bundle 
    docker run -p 6436:5432 -p 9996:9999 --env=PGPASSWORD=postgres -v pgdemo2-pgdata:/pgdata --hostname=pgdemo2 --network=poolnet --name=pgdemo2 --privileged --ip 172.28.0.15   -dt rocky9-pg17-bundle 
    docker run -p 6437:5432 -p 9997:9999 --env=PGPASSWORD=postgres -v pgdemo3-pgdata:/pgdata --hostname=pgdemo3 --network=poolnet --name=pgdemo3 --privileged --ip 172.28.0.16   -dt rocky9-pg17-bundle 

Notice the ip's assigned to your new containers.  Since the network already existed, the genDeploy extracts the next available IP from the network.


    d7e53402587c   2d2845e69ba1   "/bin/bash -c /entry…"   9 days ago   Up 34 hours   22/tcp, 80/tcp, 443/tcp, 9898/tcp, 0.0.0.0:6432->5432/tcp, [::]:6432->5432/tcp, 0.0.0.0:9992->9999/tcp, [::]:9992->9999/tcp   pg2
    caa606de2612   2d2845e69ba1   "/bin/bash -c /entry…"   9 days ago   Up 34 hours   22/tcp, 80/tcp, 443/tcp, 9898/tcp, 0.0.0.0:6431->5432/tcp, [::]:6431->5432/tcp, 0.0.0.0:9991->9999/tcp, [::]:9991->9999/tcp   pg1

A docker network inspect of of the pool net


    docker network inspect poolnet --format '{{range .Containers}}{{.Name}} - {{.IPv4Address}}{{"\n"}}{{end}}'

Lists the ip's already in use

    pg1 - 172.28.0.11/16
    pg2 - 172.28.0.12/16
    pg3 - 172.28.0.13/16



And as you can see a few lines up, our pgdemo containers start with ip of **172.28.0.14**  We could modify the script to start at 13, but I wanted a buffer in there


## Use as generic generator

When used with the -g option as mentioned above, you just generate multiple container docker run commands to manage. For example.


    /genDeploy -w poolnet -c generic -n 10 -g -i myimage


Would generate a DockerRunThis file with the following run commands:

    docker run -p 6439:5432 --hostname=generic1 --network=poolnet --name=generic1 --ip 172.28.0.17 -dt myimage
    docker run -p 6440:5432 --hostname=generic2 --network=poolnet --name=generic2 --ip 172.28.0.18 -dt myimage
    docker run -p 6441:5432 --hostname=generic3 --network=poolnet --name=generic3 --ip 172.28.0.19 -dt myimage
    docker run -p 6442:5432 --hostname=generic4 --network=poolnet --name=generic4 --ip 172.28.0.20 -dt myimage
    docker run -p 6443:5432 --hostname=generic5 --network=poolnet --name=generic5 --ip 172.28.0.21 -dt myimage
    docker run -p 6444:5432 --hostname=generic6 --network=poolnet --name=generic6 --ip 172.28.0.22 -dt myimage
    docker run -p 6445:5432 --hostname=generic7 --network=poolnet --name=generic7 --ip 172.28.0.23 -dt myimage
    docker run -p 6446:5432 --hostname=generic8 --network=poolnet --name=generic8 --ip 172.28.0.24 -dt myimage
    docker run -p 6447:5432 --hostname=generic9 --network=poolnet --name=generic9 --ip 172.28.0.25 -dt myimage
    docker run -p 6448:5432 --hostname=generic10 --network=poolnet --name=generic10 --ip 172.28.0.26 -dt myimage

This just makes things a little easier to manage.

## The DockerRunThis file. Whats in it?

The following is the file we generated to manage our docker deploy. It is pretty simple and straight forward. Remember, you get a custom file for every container name.


    #!/bin/bash
    
    function runNetwork() {
            echo -e "Using existing network "poolnet" No need to create the network at this time." 
    }
    
    function runContainers() {
            runNetwork
            docker run -p 6435:5432 -p 9995:9999 --env=PGPASSWORD=postgres -v pgdemo1-pgdata:/pgdata --hostname=pgdemo1 --network=poolnet --name=pgdemo1 --privileged --ip 172.28.0.14   -dt rocky9-pg17-bundle 
            docker run -p 6436:5432 -p 9996:9999 --env=PGPASSWORD=postgres -v pgdemo2-pgdata:/pgdata --hostname=pgdemo2 --network=poolnet --name=pgdemo2 --privileged --ip 172.28.0.15   -dt rocky9-pg17-bundle 
            docker run -p 6437:5432 -p 9997:9999 --env=PGPASSWORD=postgres -v pgdemo3-pgdata:/pgdata --hostname=pgdemo3 --network=poolnet --name=pgdemo3 --privileged --ip 172.28.0.16   -dt rocky9-pg17-bundle 
    }
    
    function restartContainers() {
            echo -e "Restarting containers  pgdemo1 pgdemo2 pgdemo3"
            docker restart  pgdemo1 pgdemo2 pgdemo3
    }
    
    function startContainers() {
            echo -e "Starting containers  pgdemo1 pgdemo2 pgdemo3"
            docker start  pgdemo1 pgdemo2 pgdemo3
    }
    
    function stopContainers() {
            echo -e "Stoping containers  pgdemo1 pgdemo2 pgdemo3"
            docker stop  pgdemo1 pgdemo2 pgdemo3
    }
    
    function removeContainers() {
            echo -e "Removing containers  pgdemo1 pgdemo2 pgdemo3"
            docker rm  pgdemo1 pgdemo2 pgdemo3
    }
    
    function removeNetwork() {
            if [ 1 -eq 0 ]; then
                    echo -e "Removing network poolnet"
                    docker network rm poolnet
            else
                    echo -e
                    echo -e "This DockerRunFile: DockerRunThis.pgdemo was generated using an existing network. Therefore, the network cannot be removed."
                    echo -e "If you are certain no other containers are using this network, you can manually remove it by running the following command:"
                    echo -e "\tdocker network rm poolnet"
                    echo -e "If you do remove the network, regenerate this DockerRunFile again using the following command:"
                    echo -e "\t"./genDeploy -w poolnet -c pgdemo -i rocky9-pg17-bundle -n 3""
                    echo -e
                    echo -e "Also, feel free to modify this file: DockerRunThis.pgdemo and adjust as needed"
                    echo -e
            fi
    }
    
    function removeVolumes() {
            echo -e "Removing volumes   pgdemo1-pgdata  pgdemo2-pgdata  pgdemo3-pgdata"
            docker volume rm   pgdemo1-pgdata  pgdemo2-pgdata  pgdemo3-pgdata
    }
    
    function usage() {
    
    cat << EOF
    
    Usage: DockerRunThis.pgdemo [-f] {start|stop|create|rm|rmvolumes|down}
          
    Description:
          
    Manage your docker deploy generated when you ran build-docker-env
    
    Actions:
      start         Start the docker containers  pgdemo1 pgdemo2 pgdemo3
      restart       Restart the docker containers  pgdemo1 pgdemo2 pgdemo3
      stop          Stop the docker containers  pgdemo1 pgdemo2 pgdemo3
      create        Run the docker conatiners " pgdemo1 pgdemo2 pgdemo3" for the first time
      rm            Remove the docker containers  pgdemo1 pgdemo2 pgdemo3
      rmvolumes     Remove the volumes   pgdemo1-pgdata  pgdemo2-pgdata  pgdemo3-pgdata
      down          Delete everything created with this run file
       
    Options:
      -f            Force delete of volumes. Otherwise preserved
       
    EOF
    exit
    }
    
    function deleteEnv() {
            echo -e "Attempting to delete entire depoloy "
            stopContainers
            removeContainers
            removeNetwork
            if [ $force -eq 1 ]; then
                    removeVolumes
            fi
            if [ $force -eq 0 ]; then
                    echo -e "Preserving volumes. Use -f to for removal or run  rmvolumes"
            fi
    }
    
    
    force=0
    doThis=""
    
    for arg in "$@"; do
        case "$arg" in
            -f)
                force=1
                ;;
            -*)
                echo "Error: Unknown option $arg" >&2
                usage
                ;;
            start|restart|stop|create|rm|rmvolumes|down)
                # This block explicitly catches valid actions
                if [ -z "$doThis" ]; then 
                    doThis="$arg"
                else
                    echo "Error: Only one action is allowed." >&2
                    usage
                fi
                ;; 
            *)
                # This catches any other non-option argument (e.g., 'hello')
                echo "Error: Invalid action or argument: $arg" >&2
                usage
                ;; 
        esac
    done
    
    if [ -z "$doThis" ]; then
        echo "Error: Must specify an action." >&2
        usage
    fi
    
    
    case $doThis in
       "start") startContainers;;  
       "restart") restartContainers;;  
       "stop") stopContainers;;
       "create") runContainers;;
       "rm") removeContainers;;
       "rmvolumes") removeVolumes;;
       "down") deleteEnv;;
       *) usage;;
       ?) usage;;   
    esac



