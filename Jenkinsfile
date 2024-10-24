pipeline {
    agent any
    
    environment {
        // Update these values
        DOCKER_REGISTRY = "your-dockerhub-username"    // Your Docker Hub username
        APP_NAME = "html-app"                          // Your application name
        DOCKER_IMAGE = "${DOCKER_REGISTRY}/${APP_NAME}"
        DOCKER_CREDS = credentials('docker-hub-credentials')  // Jenkins credentials ID for Docker Hub
        GITHUB_CREDS = credentials('github-credentials')      // Jenkins credentials ID for GitHub
        // Get this from Rancher -> Cluster -> Kubeconfig file
        KUBECONFIG_CRED = credentials('rancher-kubeconfig')   // Jenkins credentials ID for Rancher kubeconfig
    }
    
    stages {
        stage('Checkout') {
            steps {
                // Clone your private GitHub repository
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],  // Change if using different branch
                    userRemoteConfigs: [[
                        url: 'YOUR_GITHUB_REPO_URL',  // Your GitHub repo URL
                        credentialsId: "${GITHUB_CREDS}"
                    ]]
                ])
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    // Build Docker image
                    sh "docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} ."
                    // Also tag as latest
                    sh "docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest"
                }
            }
        }
        
        stage('Push Docker Image') {
            steps {
                script {
                    // Login and push to Docker Hub
                    sh """
                        echo ${DOCKER_CREDS_PSW} | docker login -u ${DOCKER_CREDS_USR} --password-stdin
                        docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
                        docker push ${DOCKER_IMAGE}:latest
                    """
                }
            }
        }
        
        stage('Deploy to Rancher Kubernetes') {
            steps {
                script {
                    // Using kubeconfig from Rancher
                    withCredentials([file(credentialsId: 'rancher-kubeconfig', variable: 'KUBECONFIG')]) {
                        sh """
                            # Verify connection to cluster
                            kubectl --kubeconfig ${KUBECONFIG} get nodes
                            
                            # Create namespace if it doesn't exist
                            kubectl --kubeconfig ${KUBECONFIG} create namespace ${APP_NAME} --dry-run=client -o yaml | kubectl apply -f -
                            
                            # Create ConfigMap for HTML content
                            kubectl --kubeconfig ${KUBECONFIG} -n ${APP_NAME} create configmap ${APP_NAME}-content \
                                --from-file=index.html --dry-run=client -o yaml | kubectl apply -f -
                            
                            # Apply Deployment
                            cat <<EOF | kubectl --kubeconfig ${KUBECONFIG} -n ${APP_NAME} apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  namespace: ${APP_NAME}
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
    spec:
      containers:
      - name: ${APP_NAME}
        image: ${DOCKER_IMAGE}:${BUILD_NUMBER}
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html-content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html-content
        configMap:
          name: ${APP_NAME}-content
EOF

                            # Apply Service
                            cat <<EOF | kubectl --kubeconfig ${KUBECONFIG} -n ${APP_NAME} apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}-service
  namespace: ${APP_NAME}
spec:
  type: NodePort
  selector:
    app: ${APP_NAME}
  ports:
  - port: 80
    targetPort: 80
EOF
                        """
                    }
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                script {
                    withCredentials([file(credentialsId: 'rancher-kubeconfig', variable: 'KUBECONFIG')]) {
                        sh """
                            # Wait for deployment to complete
                            kubectl --kubeconfig ${KUBECONFIG} -n ${APP_NAME} rollout status deployment/${APP_NAME}
                            
                            # Get deployment status
                            echo "Deployment Status:"
                            kubectl --kubeconfig ${KUBECONFIG} -n ${APP_NAME} get deployments
                            
                            # Get pods status
                            echo "Pod Status:"
                            kubectl --kubeconfig ${KUBECONFIG} -n ${APP_NAME} get pods
                            
                            # Get service details
                            echo "Service Details:"
                            kubectl --kubeconfig ${KUBECONFIG} -n ${APP_NAME} get service ${APP_NAME}-service
                        """
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo "Deployment successful! Check Rancher UI for application status."
        }
        failure {
            echo "Deployment failed! Check Jenkins and Rancher logs for details."
        }
        always {
            // Cleanup
            sh """
                docker rmi ${DOCKER_IMAGE}:${BUILD_NUMBER} || true
                docker rmi ${DOCKER_IMAGE}:latest || true
            """
        }
    }
}
