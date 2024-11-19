pipeline {
    agent any

    environment {
        DOCKER_USERNAME = 'prasadreddymanda'
        APP_NAME = 'survey-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
        DOCKER_CREDENTIALS = credentials('docker-id')
        KUBECONFIG_CREDENTIALS = credentials('kubernetes-id')
        GIT_CREDENTIALS = credentials('git-id')
    }

    stages {
        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

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
                    
                    sh '''
                        echo "Verifying required files..."
                        test -f survey.html
                        test -f Dockerfile
                        ls -la
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    try {
                        withCredentials([usernamePassword(
                            credentialsId: 'docker-id',
                            usernameVariable: 'DOCKER_USER',
                            passwordVariable: 'DOCKER_PASS'
                        )]) {
                            sh """
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
  labels:
    app: \${APP_NAME}
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  selector:
    matchLabels:
      app: \${APP_NAME}
  template:
    metadata:
      labels:
        app: \${APP_NAME}
      annotations:
        rollme: "\${BUILD_NUMBER}"
    spec:
      containers:
      - name: \${APP_NAME}
        image: \${DOCKER_USERNAME}/\${APP_NAME}:\${IMAGE_TAG}
        imagePullPolicy: Always
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: "0.5"
            memory: "512Mi"
          requests:
            cpu: "0.2"
            memory: "256Mi"
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
                                # Verify Kubernetes connection
                                kubectl get nodes
                                
                                # Apply new configurations
                                kubectl apply -f deployment.yaml
                                kubectl apply -f service.yaml
                                
                                # Force rolling update
                                kubectl rollout restart deployment \${APP_NAME}
                                
                                # Wait for rollout to finish
                                kubectl rollout status deployment \${APP_NAME} --timeout=300s
                            """
                        }
                    } catch (Exception e) {
                        sh """
                            echo "Deployment failed. Checking status..."
                            kubectl get pods -l app=\${APP_NAME}
                            kubectl describe deployment \${APP_NAME}
                        """
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
