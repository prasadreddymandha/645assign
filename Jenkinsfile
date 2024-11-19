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
      maxUnavailable: 1
  selector:
    matchLabels:
      app: \${APP_NAME}
  template:
    metadata:
      labels:
        app: \${APP_NAME}
      annotations:
        rollme: "\${env.BUILD_ID}"
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
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 2
          successThreshold: 1
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 20
          periodSeconds: 10
          timeoutSeconds: 2
          failureThreshold: 3
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
                        # Delete any failed pods first
                        kubectl delete pods --field-selector status.phase=Failed -n default
                        
                        # Apply new configurations
                        kubectl apply -f deployment.yaml
                        kubectl apply -f service.yaml
                        
                        # Wait for service to be available
                        echo "Waiting for service..."
                        kubectl wait --for=condition=available --timeout=60s service/\${APP_NAME}-service
                        
                        # Perform rolling update with increased timeout
                        echo "Starting rollout..."
                        kubectl rollout restart deployment \${APP_NAME}
                        kubectl rollout status deployment \${APP_NAME} --timeout=600s
                        
                        # Verify deployment
                        echo "Verifying deployment..."
                        kubectl get pods -l app=\${APP_NAME}
                    """
                }
            } catch (Exception e) {
                // Print more detailed error information
                sh """
                    echo "Deployment failed. Checking pod status..."
                    kubectl get pods -l app=\${APP_NAME}
                    echo "Pod details:"
                    kubectl describe pods -l app=\${APP_NAME}
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
