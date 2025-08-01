#!/bin/bash
# For Ubuntu 22.04 EC2 (t2.large)
# Jenkins, OWASP DC, Docker, SonarQube, Trivy setup

set -e

echo "=== Updating System ==="
sudo apt update -y

echo "=== Installing Java 17 ==="
sudo apt install openjdk-17-jdk openjdk-17-jre -y
java -version

echo "=== Installing Required Packages ==="
sudo apt install unzip curl gnupg lsb-release apt-transport-https wget -y

# --- OWASP Dependency-Check ---
echo "=== Installing OWASP Dependency-Check ==="
cd /opt
sudo mkdir -p owasp-dc
cd owasp-dc
wget https://github.com/jeremylong/DependencyCheck/releases/download/v8.4.0/dependency-check-8.4.0-release.zip
unzip dependency-check-8.4.0-release.zip

# --- Install Jenkins ---
echo "=== Installing Jenkins ==="
curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update -y
sudo apt install jenkins -y
sudo systemctl stop jenkins

# --- Place Groovy Script Before Jenkins Starts ---
echo "=== Placing Groovy init script ==="
sudo mkdir -p /var/lib/jenkins/init.groovy.d

sudo bash -c "cat << 'EOF' > /var/lib/jenkins/init.groovy.d/basic-setup.groovy
import jenkins.model.*
import hudson.security.*
import jenkins.install.InstallState
import com.cloudbees.plugins.credentials.impl.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.jenkins.plugins.awscredentials.AWSCredentialsImpl
import org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl
import hudson.util.Secret
import hudson.model.JDK
import hudson.plugins.sonar.SonarRunnerInstallation
import jenkins.plugins.nodejs.tools.NodeJSInstallation
import jenkins.plugins.nodejs.tools.NodeJSInstaller
import org.jenkinsci.plugins.DependencyCheck.tools.DependencyCheckInstallation
import hudson.plugins.sonar.SonarGlobalConfiguration
import hudson.plugins.sonar.SonarInstallation

// ---- CREATE ADMIN USER ----
def instance = Jenkins.getInstance()
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
if (hudsonRealm.getAllUsers().size() == 0) {
    hudsonRealm.createAccount('sree', 'sree123')
    instance.setSecurityRealm(hudsonRealm)
}
instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)
instance.save()

// ---- ADD CREDENTIALS ----
def credentials_store = Jenkins.instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

// 1. Docker Hub (Username/Password)
def dockerCreds = new UsernamePasswordCredentialsImpl(
    CredentialsScope.GLOBAL,
    "docker",
    "docker hub credentials for pipeline",
    "devopslearning25",
    "docker@aws123"
)
credentials_store.addCredentials(Domain.global(), dockerCreds)

// 2. Github Personal Access Token (Secret Text)
def githubToken = new StringCredentialsImpl(
    CredentialsScope.GLOBAL,
    "githubcred",
    "Github Personal Access Token",
    Secret.fromString("REPLACE_WITH_REAL_TOKEN")
)
credentials_store.addCredentials(Domain.global(), githubToken)

// 3. AWS Credentials (Access Key & Secret)
def awsCreds = new AWSCredentialsImpl(
    CredentialsScope.GLOBAL,
    "aws-key",
    "aws credentials for pipeline",
    "REPLACE_WITH_REAL_ACCESS_KEY",
    "REPLACE_WITH_REAL_SECRET_KEY"
)
credentials_store.addCredentials(Domain.global(), awsCreds)

// 4. SonarQube Token (Secret Text)
def sonarToken = new StringCredentialsImpl(
    CredentialsScope.GLOBAL,
    "sonar-token",
    "SonarQube Authentication Token",
    Secret.fromString("REPLACE_WITH_REAL_TOKEN")
)
credentials_store.addCredentials(Domain.global(), sonarToken)

// ------ Global Tool Installations ------

// JDK Installation
def jdkDesc = new JDK.DescriptorImpl()
def jdkInstall = new JDK("jdk", "/usr/lib/jvm/java-17-openjdk-amd64")
jdkDesc.setInstallations(jdkInstall)
jdkDesc.save()

// SonarQube Scanner Installation
def sonarRunnerDesc = Jenkins.instance.getDescriptorByType(SonarRunnerInstallation.DescriptorImpl.class)
def sonarInstall = new SonarRunnerInstallation("sonar-scanner", "", [new hudson.plugins.sonar.SonarRunnerInstaller(null)])
sonarRunnerDesc.setInstallations(sonarInstall)
sonarRunnerDesc.save()

// NodeJS Installation
def nodejsDesc = Jenkins.instance.getDescriptorByType(NodeJSInstallation.DescriptorImpl.class)
def nodejsInstall = new NodeJSInstallation("nodejs", "", [new NodeJSInstaller(null, "", false)])
nodejsDesc.setInstallations(nodejsInstall)
nodejsDesc.save()

// Dependency-Check Installation
def dcDesc = Jenkins.instance.getDescriptorByType(org.jenkinsci.plugins.DependencyCheck.tools.DependencyCheckInstallation.DescriptorImpl.class)
def dcInstall = new DependencyCheckInstallation("DP-Check", "/opt/owasp-dc/dependency-check", [])
dcDesc.setInstallations(dcInstall)
dcDesc.save()

// ------ SonarQube Server Configuration ------
def sonarConfig = Jenkins.instance.getDescriptorByType(hudson.plugins.sonar.SonarGlobalConfiguration.class)
def sonarServer = new SonarInstallation(
    "sonar-server",
    "http://44.213.89.155:9000/",
    "sonar-token", // Credential ID
    "",
    "",
    null,
    false
)
sonarConfig.setInstallations(sonarServer)
sonarConfig.save()
EOF"

sudo chown -R jenkins:jenkins /var/lib/jenkins/init.groovy.d

# --- Install Jenkins Plugins via CLI ---
echo "=== Downloading Jenkins Plugin CLI ==="
wget -O /tmp/jenkins-plugin-cli.jar https://repo.jenkins-ci.org/public/io/jenkins/plugin-manager/cli/2.12.13/cli-2.12.13.jar

cat <<EOF > /tmp/plugins.txt
git
temurin
sonar
nodejs
docker-plugin
docker-commons
docker-workflow
docker-api
docker-build-step
dependency-check-jenkins-plugin
terraform
aws-credentials
pipeline-aws
prometheus
EOF

echo "=== Pre-downloading plugins ==="
java -jar /tmp/jenkins-plugin-cli.jar \
  --war /usr/share/jenkins/jenkins.war \
  --plugin-file /tmp/plugins.txt \
  --plugin-download-directory /var/lib/jenkins/plugins

sudo chown -R jenkins:jenkins /var/lib/jenkins/plugins

echo "=== Starting Jenkins ==="
sudo systemctl start jenkins

echo "=== Waiting for Jenkins to be ready... ==="
until curl -s http://localhost:8080/login > /dev/null; do
  echo "Waiting for Jenkins at port 8080..."
  sleep 10
done

echo "=== Jenkins is up and configured ==="

# --- Docker ---
echo "=== Installing Docker ==="
sudo apt install docker.io -y
sudo usermod -aG docker jenkins
sudo usermod -aG docker ubuntu
sudo chmod 777 /var/run/docker.sock
sudo systemctl restart docker

# --- SonarQube (via Docker) ---
echo "=== Running SonarQube ==="
docker run -d --name sonar -p 9000:9000 sonarqube:lts-community

# --- Trivy ---
echo "=== Installing Trivy ==="
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt update
sudo apt install trivy -y

echo "=== Setup Complete ==="
