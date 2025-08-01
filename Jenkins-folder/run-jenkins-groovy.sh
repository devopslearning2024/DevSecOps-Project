#!/bin/bash
set -e

echo "=== Applying Jenkins Groovy Config ==="
sudo mkdir -p /var/lib/jenkins/init.groovy.d
sudo cp /opt/jenkins-bootstrap/basic-setup.groovy /var/lib/jenkins/init.groovy.d/
sudo chown -R jenkins:jenkins /var/lib/jenkins/init.groovy.d

echo "=== Restarting Jenkins ==="
sudo systemctl restart jenkins

echo "=== Waiting for Jenkins to be ready... ==="
until curl -s http://localhost:8080/login > /dev/null; do
  echo "Waiting..."
  sleep 5
done

echo "✅ Jenkins Groovy setup applied."