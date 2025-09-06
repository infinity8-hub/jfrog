#!/bin/bash
set -e

# Enable & Start Artifactory via systemd
sudo systemctl daemon-reexec
sudo systemctl enable artifactory.service
sudo systemctl start artifactory.service
chown artifactory:artifactory /var/run/artifactory.pid
sudo -u artifactory /opt/jfrog/artifactory/app/bin/artifactoryManage.sh start

echo "✅ Artifactory installed and started."
echo "UI should be available at: http://<server_ip>:8082/ui/"