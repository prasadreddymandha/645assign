pipeline {
    agent any

    // Environment variables
    environment {
        //  Docker Hub username 
        DOCKER_USERNAME = 'prasadreddymanda'
        
        //  Application name
        APP_NAME = 'survey-app'
        
        // Using Jenkins build number for unique image tags
        IMAGE_TAG = "${env.BUILD_ID}"
        
        // Credentials 
        DOCKER_CREDENTIALS = credentials('docker-id')
        KUBECONFIG_CREDENTIALS = credentials('kubernetes-id')
        GIT_CREDENTIALS = credentials('git-id')
    }

    stages {
        // Clean workspace before starting
        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        // Checkout code from GitHub
        stage('Code Checkout') {
            steps {
                script {
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: '*/main']],
                        userRemoteConfigs: [[
                            url: 'https://github.com/prasadreddymandha/645assign.git',
                            credentialsId: 'git-id'
                        ]]
                    ])
                    
                    // Verify required files exist
                    sh '''
                        echo "Verifying required files..."
                        test -f survey.html
                        test -f Dockerfile
                        ls -la
                    '''
                }
            }
        }

        // Build Docker image
        stage('Build Docker Image') {
            steps {
                script {
                    try {
                        // Login to Docker Hub
                        withCredentials([usernamePassword(
                            credentialsId: 'docker-id',
                            usernameVariable: 'DOCKER_USER',
                            passwordVariable: 'DOCKER_PASS'
                        )]) {
                            sh """
                                echo "Logging into Docker Hub..."
                                echo \${DOCKER_PASS} | docker login -u \${DOCKER_USER} --password-stdin
                                
                                echo "Building Docker image..."
                                docker build -t \${DOCKER_USERNAME}/\${APP_NAME}:\${IMAGE_TAG} .
                                docker tag \${DOCKER_USERNAME}/\${APP_NAME}:\${IMAGE_TAG} \${DOCKER_USERNAME}/\${APP_NAME}:latest
                                
                                echo "Verifying image..."
                                docker images | grep \${APP_NAME}
                            """
                        }
                    } catch (Exception e) {
                        error "Docker build failed: ${e.getMessage()}"
                    }
                }
            }
        }

        // Push Docker image to Docker Hub
        stage('Push Docker Image') {
            steps {
                script {
                    try {
                        echo "Pushing Docker image to Docker Hub..."
                        sh """
                            docker push \${DOCKER_USERNAME}/\${APP_NAME}:\${IMAGE_TAG}
                            docker push \${DOCKER_USERNAME}/\${APP_NAME}:latest
                        """
                    } catch (Exception e) {
                        error "Docker push failed: ${e.getMessage()}"
                    }
                }
            }
        }

        // Deploy to Kubernetes
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    try {
                        echo "Creating Kubernetes deployment and service files..."
                        sh """
                        cat <<EOF > deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: \${APP_NAME}
  imagePullPolicy: Always
  labels:
    app: \${APP_NAME}
spec:
  replicas: 3
  selector:
    matchLabels:
      app: \${APP_NAME}
  template:
    metadata:
      labels:
        app: \${APP_NAME}
    spec:
      containers:
      - name: \${APP_NAME}
        image: \${DOCKER_USERNAME}/\${APP_NAME}:\${IMAGE_TAG}
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: "0.2"
            memory: "256Mi"
          requests:
            cpu: "0.1"
            memory: "128Mi"
EOF

                        cat <<EOF > service.yaml
apiVersion: v1
kind: Service
metadata:
  name: \${APP_NAME}-service
  labels:
    app: \${APP_NAME}
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: \${APP_NAME}
EOF
                        """

                        echo "Applying Kubernetes configurations..."
                        withKubeConfig([credentialsId: 'kubernetes-id']) {
                            sh """
                                kubectl apply -f deployment.yaml
                                kubectl apply -f service.yaml
                            """
                        }
                    } catch (Exception e) {
                        error "Kubernetes deployment failed: ${e.getMessage()}"
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
            echo 'Check the console output to find the cause of the failure.'
        }
        always {
            echo 'Cleaning up resources...'
            sh '''
                rm -f deployment.yaml service.yaml || true
                docker rmi ${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG} || true
                docker rmi ${DOCKER_USERNAME}/${APP_NAME}:latest || true
            '''
            cleanWs()
        }
    }
}
