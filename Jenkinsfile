pipeline {
    agent any
    environment {
        DOCKER_CREDENTIALS = credentials('docker-id')  
        KUBECONFIG_CREDENTIALS = credentials('kubernetes-id')  
        GIT_CREDENTIALS = credentials('git-id')
        IMAGE_TAG = "${env.BUILD_ID}"
        DOCKER_USERNAME = 'prasadreddymanda'
        APP_NAME = 'html-app'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[
                        url: 'https://github.com/prasadreddymandha/645assign/tree/main',
                        credentialsId: 'git-id'
                    ]]
                ])
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'docker-id', passwordVariable: 'DOCKER_PSW', usernameVariable: 'DOCKER_USR')]) {
                        sh 'echo $DOCKER_PSW | docker login -u $DOCKER_USR --password-stdin'
                    }
                    image = docker.build("${DOCKER_USERNAME}/${APP_NAME}:${env.IMAGE_TAG}")
                }
            }
        }
        
        stage('Push Docker Image') {
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', 'docker-id') {
                        image.push()
                    }
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    // Create deployment YAML
                    sh """
                    cat <<EOF > deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: html-app
  labels:
    app: html-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: html-app
  template:
    metadata:
      labels:
        app: html-app
    spec:
      containers:
      - name: html-app
        image: ${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG}
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

                    # Create service YAML
                    cat <<EOF > service.yaml
apiVersion: v1
kind: Service
metadata:
  name: html-app-service
  labels:
    app: html-app
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: html-app
EOF

                    # Create ConfigMap for HTML content
                    kubectl --kubeconfig=$KUBECONFIG_CREDENTIALS create configmap html-content --from-file=index.html -o yaml --dry-run=client | kubectl --kubeconfig=$KUBECONFIG_CREDENTIALS apply -f -

                    # Apply Kubernetes configurations
                    kubectl --kubeconfig=$KUBECONFIG_CREDENTIALS apply -f deployment.yaml
                    kubectl --kubeconfig=$KUBECONFIG_CREDENTIALS apply -f service.yaml
                    """
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                script {
                    sh '''
                    kubectl --kubeconfig=$KUBECONFIG_CREDENTIALS rollout status deployment/html-app
                    kubectl --kubeconfig=$KUBECONFIG_CREDENTIALS get pods
                    kubectl --kubeconfig=$KUBECONFIG_CREDENTIALS get svc html-app-service
                    '''
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully!'
            echo 'To access the application:'
            sh '''
            export NODE_PORT=$(kubectl --kubeconfig=$KUBECONFIG_CREDENTIALS get svc html-app-service -o jsonpath='{.spec.ports[0].nodePort}')
            echo "Application is accessible at: http://<node-ip>:$NODE_PORT"
            '''
        }
        failure {
            echo 'Pipeline failed.'
        }
        always {
            // Cleanup temporary files
            sh '''
            rm -f deployment.yaml service.yaml || true
            docker rmi ${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG} || true
            '''
        }
    }
}
