
pipeline{
    agent any
    tools{
        jdk 'jdk'
        nodejs 'node'
    }
    environment {
        SCANNER_HOME=tool 'sonar-scanner'
    }
    stages {
        stage('clean workspace'){
            steps{
                cleanWs()
            }
        }
        stage('Checkout from Git'){
            steps{
                git branch: 'main', url: 'https://github.com/devopslearning2024/DevSecOps-Project.git'
            }
        }
        stage("Sonarqube Analysis "){
            steps{
                withSonarQubeEnv('sonar-server') {
                    sh ''' $SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=Netflix \
                    -Dsonar.projectKey=Netflixnow'''
                }
            }
        }
        stage("quality gate"){
           steps {
                script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'sonar-token' 
                }
            } 
        }
        stage('Install Dependencies') {
            steps {
                sh "npm install"
            }
        }
        stage('OWASP FS SCAN') {
            steps {
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'DP-Check'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }
        stage('TRIVY FS SCAN') {
            steps {
                sh "trivy fs . > trivyfs.txt"
            }
        }
        stage("Docker Build & Push"){
            steps{
                script{
                   withDockerRegistry(credentialsId: 'docker', toolName: 'docker'){   
                       sh "docker build --build-arg TMDB_V3_API_KEY=3c664ea9644934f3fe1a7118a2d8d323 -t netflix ."
                       sh "docker tag netflix devopslearning25/netflix:latest "
                       sh "docker push devopslearning25/netflix:latest "
                    }
                }
            }
        }
        stage("TRIVY"){
            steps{
                sh "trivy image sree56/netflix:latest > trivyimage.txt" 
            }
        }
        stage('Deploy to container'){
            steps{
                sh 'docker run -d -p 8081:80 sree56/netflix:latest'
            }
        }
        stage('Update Deployment file') {
            environment {
                GIT_REPO_NAME = "working-project"
                GIT_USER_NAME = "devopslearning2024"
            }
            steps {
                dir('K8s'){
                    withCredentials([string(credentialsId: 'githubcred', variable: 'GITHUB_TOKEN')]) {
                        sh '''
                            git config user.email "devops.learning.aws.123@gmail.com"
                            git config user.name "devopslearning2024"
                            BUILD_NUMBER=${BUILD_NUMBER}
                            echo $BUILD_NUMBER
                            imageTag=$(grep -oP '(?<=netflix:)[^ ]+' deployment.yml)
                            echo $imageTag
                            sed -i "s/netflix:${imageTag}/netflix:${BUILD_NUMBER}/" deployment.yml
                            git add deployment.yml
                            git commit -m "Update deployment Image to version \${BUILD_NUMBER}"
                            git push https://${GITHUB_TOKEN}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME}.git HEAD:main
                        '''
                    }
                }
            }
        }
    }
    post{
        always{
            emailext attachLog: true,
               subject: "'${currentBuild.result}'",
               body: "Project: ${env.JOB_NAME}<br/>" +
                     "Build Number: ${env.BUILD_NUMBER}<br/>" +
                     "URL: ${env.BUILD_URL}<br/>",
               to: 'sreelakshmi.ram.a.1099@gmail.com' ,
               attachmentsPattern: 'trivyfs.txt,trivyimage.txt'
        }
    }
  }
