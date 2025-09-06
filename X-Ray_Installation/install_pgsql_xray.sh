#!/bin/bash
set -e

# Reset and enable PostgreSQL 16 module
sudo dnf module reset -y postgresql || true
sudo dnf module enable -y postgresql:16

# Install PostgreSQL server and contrib
sudo dnf install -y postgresql-server postgresql-contrib

# Initialize PostgreSQL database cluster
sudo postgresql-setup --initdb --unit postgresql

# Enable and start PostgreSQL service
sudo systemctl enable --now postgresql
sudo systemctl status postgresql --no-pager

# Define variables (update the password before running!)
DB_USER="xrayuser"
DB_PASS="StrongPasswordHere"
DB_NAME="xraydb"

# Create user, database, and configure role defaults
sudo -u postgres psql -v ON_ERROR_STOP=1 <<EOF
DO
\$do\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${DB_USER}') THEN
      CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASS}';
   END IF;
END
\$do\$;

CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};

\c ${DB_NAME}
ALTER SCHEMA public OWNER TO ${DB_USER};

ALTER ROLE ${DB_USER} SET client_encoding TO 'utf8';
ALTER ROLE ${DB_USER} SET default_transaction_isolation TO 'read committed';
ALTER ROLE ${DB_USER} SET timezone TO 'UTC';
EOF

echo "✅ PostgreSQL setup complete for xray (DB: ${DB_NAME}, User: ${DB_USER})"

PGDATA="/var/lib/pgsql/data"
PG_HBA="$PGDATA/pg_hba.conf"

echo "🔧 Backing up existing pg_hba.conf..."
sudo cp -v $PG_HBA ${PG_HBA}.bak.$(date +%F-%H%M)

echo "🔧 Writing full pg_hba.conf with xrayuser rules merged..."
sudo tee $PG_HBA > /dev/null <<'EOF'
# PostgreSQL Client Authentication Configuration File
# ===================================================
#
# Refer to the "Client Authentication" section in the PostgreSQL
# documentation for a complete description of this file.  A short
# synopsis follows.
#
# ----------------------
# Authentication Records
# ----------------------
#
# This file controls: which hosts are allowed to connect, how clients
# are authenticated, which PostgreSQL user names they can use, which
# databases they can access.  Records take one of these forms:
#
# local         DATABASE  USER  METHOD  [OPTIONS]
# host          DATABASE  USER  ADDRESS  METHOD  [OPTIONS]
# hostssl       DATABASE  USER  ADDRESS  METHOD  [OPTIONS]
# hostnossl     DATABASE  USER  ADDRESS  METHOD  [OPTIONS]
# hostgssenc    DATABASE  USER  ADDRESS  METHOD  [OPTIONS]
# hostnogssenc  DATABASE  USER  ADDRESS  METHOD  [OPTIONS]
#
# (The uppercase items must be replaced by actual values.)
#
# The first field is the connection type:
# - "local" is a Unix-domain socket
# - "host" is a TCP/IP socket (encrypted or not)
# - "hostssl" is a TCP/IP socket that is SSL-encrypted
# - "hostnossl" is a TCP/IP socket that is not SSL-encrypted
# - "hostgssenc" is a TCP/IP socket that is GSSAPI-encrypted
# - "hostnogssenc" is a TCP/IP socket that is not GSSAPI-encrypted
#
# DATABASE can be "all", "sameuser", "samerole", "replication", a
# database name, a regular expression (if it starts with a slash (/))
# or a comma-separated list thereof.  The "all" keyword does not match
# "replication".  Access to replication must be enabled in a separate
# record (see example below).
#
# USER can be "all", a user name, a group name prefixed with "+", a
# regular expression (if it starts with a slash (/)) or a comma-separated
# list thereof.  In both the DATABASE and USER fields you can also write
# a file name prefixed with "@" to include names from a separate file.
#
# ADDRESS specifies the set of hosts the record matches.  It can be a
# host name, or it is made up of an IP address and a CIDR mask that is
# an integer (between 0 and 32 (IPv4) or 128 (IPv6) inclusive) that
# specifies the number of significant bits in the mask.  A host name
# that starts with a dot (.) matches a suffix of the actual host name.
# Alternatively, you can write an IP address and netmask in separate
# columns to specify the set of hosts.  Instead of a CIDR-address, you
# can write "samehost" to match any of the server's own IP addresses,
# or "samenet" to match any address in any subnet that the server is
# directly connected to.
#
# METHOD can be "trust", "reject", "md5", "password", "scram-sha-256",
# "gss", "sspi", "ident", "peer", "pam", "ldap", "radius" or "cert".
# Note that "password" sends passwords in clear text; "md5" or
# "scram-sha-256" are preferred since they send encrypted passwords.
#
# OPTIONS are a set of options for the authentication in the format
# NAME=VALUE.  The available options depend on the different
# authentication methods -- refer to the "Client Authentication"
# section in the documentation for a list of which options are
# available for which authentication methods.
#
# Database and user names containing spaces, commas, quotes and other
# special characters must be quoted.  Quoting one of the keywords
# "all", "sameuser", "samerole" or "replication" makes the name lose
# its special character, and just match a database or username with
# that name.
#
# ---------------
# Include Records
# ---------------
#
# This file allows the inclusion of external files or directories holding
# more records, using the following keywords:
#
# include           FILE
# include_if_exists FILE
# include_dir       DIRECTORY
#
# FILE is the file name to include, and DIR is the directory name containing
# the file(s) to include.  Any file in a directory will be loaded if suffixed
# with ".conf".  The files of a directory are ordered by name.
# include_if_exists ignores missing files.  FILE and DIRECTORY can be
# specified as a relative or an absolute path, and can be double-quoted if
# they contain spaces.
#
# -------------
# Miscellaneous
# -------------
#
# This file is read on server startup and when the server receives a
# SIGHUP signal.  If you edit the file on a running system, you have to
# SIGHUP the server for the changes to take effect, run "pg_ctl reload",
# or execute "SELECT pg_reload_conf()".
#
# ----------------------------------
# Put your actual configuration here
# ----------------------------------
#
# If you want to allow non-local connections, you need to add more
# "host" records.  In that case you will also need to make PostgreSQL
# listen on a non-local interface via the listen_addresses
# configuration parameter, or via the -i or -h command line switches.


# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                             scram-sha-256

# Allow xrayuser user to connect locally with password
local   xraydb     xrayuser                             scram-sha-256

# IPv4 local connections:
host    xraydb     xrayuser     127.0.0.1/32            scram-sha-256
host    all             all             127.0.0.1/32            ident

# IPv6 local connections:
host    all             all             ::1/128                 ident

# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            ident
host    replication     all             ::1/128                 ident
EOF

echo "🔄 Reloading PostgreSQL service..."
sudo systemctl reload postgresql

echo "✅ pg_hba.conf updated successfully"