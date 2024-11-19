pipeline {
    agent any

    environment {
        DOCKER_USERNAME = 'prasadreddymanda'
        APP_NAME = 'survey-app'
        IMAGE_TAG = "${BUILD_NUMBER}-${GIT_COMMIT?.substring(0,7)}"
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

        stage('Build Docker Image') {
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: 'docker-id',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh """
                            echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin
                            docker build -t ${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG} .
                            docker images | grep ${APP_NAME}
                        """
                    }
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                sh "docker push ${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG}"
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    try {
                        echo "Creating Kubernetes deployment and service files..."
                        writeFile file: 'deployment.yaml', text: """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  labels:
    app: ${APP_NAME}
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
      annotations:
        rollme: "${BUILD_NUMBER}"
    spec:
      containers:
      - name: ${APP_NAME}
        image: ${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG}
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
"""

                        writeFile file: 'service.yaml', text: """
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}-service
  labels:
    app: ${APP_NAME}
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: ${APP_NAME}
"""

                        echo "Applying Kubernetes configurations..."
                        withKubeConfig([credentialsId: 'kubernetes-id', serverUrl: 'https://your-k8s-api-server:6443']) {
                            sh """
                                kubectl config current-context
                                kubectl config view
                                
                                # Apply configurations
                                kubectl apply -f deployment.yaml
                                kubectl apply -f service.yaml
                                
                                # Wait for deployment
                                kubectl rollout restart deployment ${APP_NAME}
                                kubectl rollout status deployment ${APP_NAME} --timeout=300s
                                
                                # Verify deployment
                                kubectl get pods -l app=${APP_NAME}
                                kubectl get services ${APP_NAME}-service
                            """
                        }
                    } catch (Exception e) {
                        sh """
                            echo "Deployment failed. Checking pod status..."
                            kubectl get pods -l app=${APP_NAME}
                            kubectl describe pods -l app=${APP_NAME}
                            kubectl get events --sort-by='.metadata.creationTimestamp'
                        """
                        throw e
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully!"
            echo "Deployed image: ${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG}"
        }
        failure {
            echo "Pipeline failed!"
            echo "Check the console output to find the cause of the failure."
        }
        always {
            echo "Cleaning up resources..."
            sh """
                rm -f deployment.yaml service.yaml || true
                docker rmi ${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG} || true
            """
            cleanWs()
        }
    }
}
