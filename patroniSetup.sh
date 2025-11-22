#!/bin/bash

patroniVarFile="/pgha/config/patroniVars"
patroniConf="/pgha/config/patroni.yaml"

if [ -f "$patroniVarFile" ]; then
    source "$patroniVarFile"
    echo "Configuration loaded successfully from $patroniVarFile."
else
    echo "Error: Configuration file $patroniVarFile not found. Did you run etcdSetup.sh?"
    exit 1
fi


cat << EOF > $patroniConf

namespace: ${NAMESPACE}
scope: ${SCOPE}
name: ${NODE_NAME}

log:
  dir: /var/log/patroni
  filename: patroni.log
  level: INFO
  file_size: 26214400
  file_num: 4

restapi:
    listen: 0.0.0.0:8008
    connect_address: ${NODE_NAME}:8008

etcd3:
    hosts: ${ETCD_NODES}

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
                #restore_command: pgbackrest --config=${CFG_DIR}/pgbackrest.conf --stanza=${STANZA_NAME} archive-get %f "%p"

    # some desired options for 'initdb'
    initdb:
        - encoding: UTF8
        - data-checksums

    post_bootstrap: ${CFG_DIR}/createRoles.sh

    pg_hba: # Add the following lines to pg_hba.conf after running 'initdb'
        - local all all trust
        - host all postgres 127.0.0.1/32 trust
        - host all postgres 0.0.0.0/0 md5
        - host replication replicator 127.0.0.1/32 trust
        - host replication replicator 0.0.0.0/0 md5

    # Users are now created in post bootstrap section

postgresql:
    cluster_name: ${SCOPE}
    listen: 0.0.0.0:5432
    connect_address: ${NODE_NAME}:5432
    data_dir: ${DATADIR}
    bin_dir: ${PG_BIN_DIR}
    pgpass: ${CFG_DIR}/pgpass

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
        #command: pgbackrest --config=${CFG_DIR}/pgbackrest.conf --stanza=stanza=${STANZA_NAME} --delta restore
        #keep_data: True
        #no_params: True

    #recovery_conf:
        #recovery_target_timeline: latest
        #restore_command: pgbackrest --config=${CFG_DIR}/pgbackrest.conf --stanza=${STANZA_NAME} archive-get %f \"%p\"

    basebackup:
        checkpoint: 'fast'
        wal-method: 'stream'

tags:
    nofailover: false
    noloadbalance: false
    clonefrom: false
    nosync: false

EOF
