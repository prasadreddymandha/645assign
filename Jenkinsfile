pipeline {
    agent any

    environment {
        DOCKER_USERNAME = 'prasadreddymanda'
        APP_NAME = 'survey-app'
        // Using both BUILD_ID and GIT_COMMIT for better traceability
        IMAGE_TAG = "${env.BUILD_ID}-${env.GIT_COMMIT?.take(7)}"
        DOCKER_CREDENTIALS = credentials('docker-id')
        KUBECONFIG_CREDENTIALS = credentials('kubernetes-id')
        GIT_CREDENTIALS = credentials('git-id')
    }

    stages {
        // Previous stages remain the same until Deploy to Kubernetes stage
        
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
      maxUnavailable: 0
  selector:
    matchLabels:
      app: \${APP_NAME}
  template:
    metadata:
      labels:
        app: \${APP_NAME}
      annotations:
        kubernetes.io/change-cause: "Build: \${IMAGE_TAG}"
    spec:
      containers:
      - name: \${APP_NAME}
        image: \${DOCKER_USERNAME}/\${APP_NAME}:\${IMAGE_TAG}
        imagePullPolicy: Always
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: "0.2"
            memory: "256Mi"
          requests:
            cpu: "0.1"
            memory: "128Mi"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
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
                                # Force rolling update
                                kubectl rollout restart deployment \${APP_NAME}
                                # Wait for rollout to complete
                                kubectl rollout status deployment \${APP_NAME} --timeout=300s
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
            echo "Deployed image: ${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG}"
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
            '''
            cleanWs()
        }
    }
}
