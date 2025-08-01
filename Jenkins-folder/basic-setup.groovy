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