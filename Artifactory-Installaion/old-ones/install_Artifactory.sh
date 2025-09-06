#!/bin/bash
set -e

# Set JFROG_HOME Variable system-wide
echo setting JFROG_HOME Variable system-wide
export JFROG_HOME=/opt/jfrog
echo "export JFROG_HOME=${JFROG_HOME}" | sudo tee -a /etc/profile.d/jfrog.sh

# Firewall entries
echo updating firewall entries 8082/tcp and 8081/tcp
sudo firewall-cmd --permanent --add-port=8082/tcp
sudo firewall-cmd --permanent --add-port=8081/tcp   # 8081 is the router/gateway, often required
sudo firewall-cmd --reload

# Download RPM
echo "Downloading JFrog Artifactory Pro 7.117.15..."
curl -L -O -J 'https://releases.jfrog.io/artifactory/artifactory-pro-rpms/jfrog-artifactory-pro/jfrog-artifactory-pro-7.117.15.rpm'

# Install Artifactory
echo "Installing JFrog Artifactory..."
sudo yum install -y ./jfrog-artifactory-pro-7.117.15.rpm