#!/bin/bash
set -e

# Set JFROG_HOME Variable system-wide
echo "Setting JFROG_HOME Variable system-wide"
export JFROG_HOME=/opt/jfrog
echo "export JFROG_HOME=${JFROG_HOME}" | sudo tee /etc/profile.d/jfrog.sh

# Firewall entries
echo "Updating firewall entries 8082/tcp and 8081/tcp"
sudo firewall-cmd --permanent --add-port=8082/tcp
sudo firewall-cmd --permanent --add-port=8081/tcp   # 8081 is the router/gateway
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports

# Download RPM
echo "Downloading JFrog Artifactory Pro 7.117.15..."
curl -L -O -J 'https://releases.jfrog.io/artifactory/artifactory-pro-rpms/jfrog-artifactory-pro/jfrog-artifactory-pro-7.117.15.rpm'

# Install Artifactory
echo "Installing JFrog Artifactory..."
sudo yum install -y ./jfrog-artifactory-pro-7.117.15.rpm

SYSTEM_YAML="/opt/jfrog/artifactory/var/etc/system.yaml"
DB_PASS=${DB_PASS:-StrongPasswordHere}

echo "🔧 Backing up existing system.yaml..."
sudo cp -v $SYSTEM_YAML ${SYSTEM_YAML}.bak.$(date +%F-%H%M)

echo "🔧 Cleaning up old commented example and inserting real PostgreSQL config..."

sudo awk -v pass="$DB_PASS" '
/^[[:space:]]*#.*type: postgresql/ { skip=1; next }
skip && /^[[:space:]]*#.*driver: org.postgresql.Driver/ { next }
skip && /^[[:space:]]*#.*url: "jdbc:postgresql/ { next }
skip && /^[[:space:]]*#.*username: artifactory/ { next }
skip && /^[[:space:]]*#.*password: / { skip=0; next }
/## Example for postgresql/ {
    print "       type: postgresql"
    print "       driver: org.postgresql.Driver"
    print "       url: \"jdbc:postgresql://127.0.0.1:5432/artifactory\""
    print "       username: artifactory"
    print "       password: " pass
    next
}
{ print }
' $SYSTEM_YAML > /tmp/system.yaml.updated

sudo mv /tmp/system.yaml.updated $SYSTEM_YAML

echo "✅ system.yaml updated successfully with real PostgreSQL configuration"

# Enable & Start Artifactory via systemd
sudo systemctl daemon-reexec
sudo systemctl enable artifactory.service
sudo systemctl start artifactory.service
chown artifactory:artifactory /var/run/artifactory.pid
sudo -u artifactory /opt/jfrog/artifactory/app/bin/artifactoryManage.sh start

echo "✅ Artifactory installed and started."
echo "UI should be available at: http://<server_ip>:8082/ui/"
