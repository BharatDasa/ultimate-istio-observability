pipeline {

    agent {
        label 'devops-toolkit'
    }

    environment {

        IMAGE_REPO = "bharatdasa"

        API_V1_IMAGE = "${IMAGE_REPO}/api:v1"
        API_V2_IMAGE = "${IMAGE_REPO}/api:v2"

        WORKER_IMAGE = "${IMAGE_REPO}/worker:v1"

        NAMESPACE = "istio-demo"
    }

    stages {

        // =====================================================
        // CHECKOUT REPOSITORY
        // =====================================================

        stage('Checkout Repository') {

            steps {

                container('toolkit') {

                    git branch: 'master',
                    credentialsId: 'github-ssh',
                    url: 'git@github.com:BharatDasa/ultimate-istio-observability.git'

                    sh 'pwd'

                    sh 'ls -la'

                    sh 'find . -maxdepth 2 -type f | sort'
                }
            }
        }

        // =====================================================
        // VERIFY TOOLS
        // =====================================================

        stage('Verify Tools') {

            steps {

                container('toolkit') {

                    sh 'kubectl version --client'

                    sh 'kubectl-argo-rollouts version'

                    sh 'trivy --version'

                    sh 'python3 --version'

                    sh 'jq --version'

                    sh 'flake8 --version'

                    sh 'pytest --version'

                    sh 'docker --version'
                }
            }
        }

        // =====================================================
        // LINT API V1
        // =====================================================

        stage('Lint API V1') {

            steps {

                container('toolkit') {

                    dir('apps/api-v1') {

                        sh '''
                        pip install \
                        -r requirements.txt \
                        --break-system-packages
                        '''

                        sh 'flake8 . || true'
                    }
                }
            }
        }

        // =====================================================
        // LINT API V2
        // =====================================================

        stage('Lint API V2') {

            steps {

                container('toolkit') {

                    dir('apps/api-v2') {

                        sh '''
                        pip install \
                        -r requirements.txt \
                        --break-system-packages
                        '''

                        sh 'flake8 . || true'
                    }
                }
            }
        }

        // =====================================================
        // LINT WORKER
        // =====================================================

        stage('Lint Worker') {

            steps {

                container('toolkit') {

                    dir('apps/worker') {

                        sh '''
                        pip install \
                        -r requirements.txt \
                        --break-system-packages
                        '''

                        sh 'flake8 . || true'
                    }
                }
            }
        }

        // =====================================================
        // BUILD API V1 IMAGE
        // =====================================================

        stage('Build API V1 Image') {

            steps {

                container('toolkit') {

                    dir('apps/api-v1') {

                        sh """
                        docker build \
                        -t ${API_V1_IMAGE} .
                        """
                    }
                }
            }
        }

        // =====================================================
        // BUILD API V2 IMAGE
        // =====================================================

        stage('Build API V2 Image') {

            steps {

                container('toolkit') {

                    dir('apps/api-v2') {

                        sh """
                        docker build \
                        -t ${API_V2_IMAGE} .
                        """
                    }
                }
            }
        }

        // =====================================================
        // BUILD WORKER IMAGE
        // =====================================================

        stage('Build Worker Image') {

            steps {

                container('toolkit') {

                    dir('apps/worker') {

                        sh """
                        docker build \
                        -t ${WORKER_IMAGE} .
                        """
                    }
                }
            }
        }

        // =====================================================
        // TRIVY SCAN API V1
        // =====================================================

        stage('Trivy Scan API V1') {

            steps {

                container('toolkit') {

                    sh """
                    trivy image \
                    --severity HIGH,CRITICAL \
                    --exit-code 0 \
                    ${API_V1_IMAGE}
                    """
                }
            }
        }

        // =====================================================
        // TRIVY SCAN API V2
        // =====================================================

        stage('Trivy Scan API V2') {

            steps {

                container('toolkit') {

                    sh """
                    trivy image \
                    --severity HIGH,CRITICAL \
                    --exit-code 0 \
                    ${API_V2_IMAGE}
                    """
                }
            }
        }

        // =====================================================
        // TRIVY SCAN WORKER
        // =====================================================

        stage('Trivy Scan Worker') {

            steps {

                container('toolkit') {

                    sh """
                    trivy image \
                    --severity HIGH,CRITICAL \
                    --exit-code 0 \
                    ${WORKER_IMAGE}
                    """
                }
            }
        }

        // =====================================================
        // DOCKER LOGIN
        // =====================================================

        stage('DockerHub Login') {

            steps {

                container('toolkit') {

                    withCredentials([
                        usernamePassword(
                            credentialsId: 'Dockerhub',
                            usernameVariable: 'DOCKER_USER',
                            passwordVariable: 'DOCKER_PASS'
                        )
                    ]) {

                        sh """
                        echo \$DOCKER_PASS | docker login \
                        -u \$DOCKER_USER \
                        --password-stdin
                        """
                    }
                }
            }
        }

        // =====================================================
        // PUSH API V1 IMAGE
        // =====================================================

        stage('Push API V1 Image') {

            steps {

                container('toolkit') {

                    sh "docker push ${API_V1_IMAGE}"
                }
            }
        }

        // =====================================================
        // PUSH API V2 IMAGE
        // =====================================================

        stage('Push API V2 Image') {

            steps {

                container('toolkit') {

                    sh "docker push ${API_V2_IMAGE}"
                }
            }
        }

        // =====================================================
        // PUSH WORKER IMAGE
        // =====================================================

        stage('Push Worker Image') {

            steps {

                container('toolkit') {

                    sh "docker push ${WORKER_IMAGE}"
                }
            }
        }

        // =====================================================
        // DEPLOY PLATFORM
        // =====================================================

        stage('Deploy Platform') {

            steps {

                container('toolkit') {

                    sh 'chmod +x scripts/*.sh'

                    sh './scripts/deploy.sh'
                }
            }
        }

        // =====================================================
        // VERIFY KUBERNETES RESOURCES
        // =====================================================

        stage('Verify Kubernetes Resources') {

            steps {

                container('toolkit') {

                    sh "kubectl get pods -n ${NAMESPACE}"

                    sh "kubectl get svc -n ${NAMESPACE}"

                    sh "kubectl get rollout -n ${NAMESPACE}"

                    sh "kubectl get hpa -n ${NAMESPACE}"

                    sh "kubectl get scaledobject -n ${NAMESPACE}"
                }
            }
        }

        // =====================================================
        // VERIFY ARGO ROLLOUT
        // =====================================================

        stage('Verify Argo Rollout') {

            steps {

                container('toolkit') {

                    sh """
                    kubectl argo rollouts get rollout api \
                    -n ${NAMESPACE}
                    """
                }
            }
        }

        // =====================================================
        // VERIFY APPLICATION
        // =====================================================

        stage('Verify Application') {

            steps {

                container('toolkit') {

                    sh """
                    curl -I \
                    http://api.192.168.56.101.nip.io
                    """
                }
            }
        }

        // =====================================================
        // RUN RESILIENCE TEST
        // =====================================================

        stage('Run Resilience Test') {

            steps {

                container('toolkit') {

                    sh 'chmod +x scripts/resilience-test.sh'

                    sh './scripts/resilience-test.sh'
                }
            }
        }
    }

    // =====================================================
    // POST ACTIONS
    // =====================================================

    post {

        always {

            container('toolkit') {

                sh "kubectl get pods -n ${NAMESPACE} || true"

                sh "kubectl get hpa -n ${NAMESPACE} || true"

                sh "kubectl get rollout -n ${NAMESPACE} || true"
            }
        }

        success {

            echo '🚀 PIPELINE COMPLETED SUCCESSFULLY'
        }

        failure {

            echo '❌ PIPELINE FAILED'
        }
    }
}
