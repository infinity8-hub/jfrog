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
DB_USER="artifactory"
DB_PASS="StrongPasswordHere"
DB_NAME="artifactory"

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

echo "✅ PostgreSQL setup complete for Artifactory (DB: ${DB_NAME}, User: ${DB_USER})"


echo update the /var/lib/pgsql/data/pg_hba.conf