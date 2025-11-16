#!/bin/bash

# As of Patroni 4. you can no longer create users from within the patroni config file for bootstrap
# You have to rune a post bootstrap script to create the roles
# This script runs using the Patroni 'superuser' credentials (postgres/postgres)
# defined in the 'postgresql/authentication/superuser' block of the patroni config file.

echo "Running post_bootstrap script to create users..."

psql -At -c "CREATE USER replicator WITH ENCRYPTED PASSWORD 'replicator';"
psql -At -c "ALTER USER replicator WITH REPLICATION;"

psql -At -c "CREATE USER bubba WITH ENCRYPTED PASSWORD 'bubba';"
psql -At -c "ALTER USER bubba WITH CREATEROLE CREATEDB SUPERUSER;"

echo "Users created/verified."
exit 0
