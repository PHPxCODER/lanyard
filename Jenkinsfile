pipeline {
    agent any

    environment {
        IMAGE_NAME = 'lanyard'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        STACK_NAME = 'lanyard'
        DOCKER_BUILDKIT = '1'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    echo "Building commit: ${env.GIT_COMMIT}"
                }
            }
        }

        stage('Detect Changes') {
            steps {
                script {
                    def changed = true
                    try {
                        def changes = sh(
                            script: 'git diff --name-only HEAD~1 HEAD',
                            returnStdout: true
                        ).trim()
                        changed = changes.length() > 0
                    } catch (Exception e) {
                        echo "Could not detect changes (first run?), proceeding with build"
                        changed = true
                    }

                    if (!changed) {
                        echo "No relevant changes detected, skipping build"
                        currentBuild.result = 'NOT_BUILT'
                        error("No changes detected — skipping build")
                    }

                    echo "Changes detected, proceeding with build"
                }
            }
        }

        stage('Validate Credentials') {
            steps {
                script {
                    def missing = []
                    def requiredCreds = [
                        'lanyard-bot-token'
                    ]

                    for (credId in requiredCreds) {
                        try {
                            withCredentials([string(credentialsId: credId, variable: 'TEST_VAR')]) {
                                // credential exists
                            }
                        } catch (Exception e) {
                            missing.add(credId)
                        }
                    }

                    if (missing.size() > 0) {
                        echo "Missing Jenkins credentials:"
                        missing.each { echo "  - ${it}" }
                        error("${missing.size()} credential(s) missing. Add them in Jenkins > Manage Credentials before deploying.")
                    }

                    echo "All ${requiredCreds.size()} credentials validated"
                }
            }
        }

        stage('Build Image') {
            steps {
                script {
                    withEnv(["BUILD_IMAGE_NAME=${IMAGE_NAME}", "BUILD_IMAGE_TAG=${IMAGE_TAG}", "COMPOSE_PROJECT_NAME=lanyard"]) {
                        sh '''
                            echo "Building Docker image via docker-compose.dev.yml..."

                            DOCKER_BUILDKIT=1 docker compose -f docker-compose.dev.yml build lanyard

                            echo "Tagging image..."
                            docker tag lanyard-lanyard:latest $BUILD_IMAGE_NAME:$BUILD_IMAGE_TAG
                            docker tag lanyard-lanyard:latest $BUILD_IMAGE_NAME:latest

                            echo "Removing intermediate build image..."
                            docker rmi lanyard-lanyard:latest 2>/dev/null || true

                            echo "Docker image built and tagged successfully: $BUILD_IMAGE_NAME:$BUILD_IMAGE_TAG"
                        '''
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    withEnv(["LANYARD_IMAGE=${IMAGE_NAME}:${IMAGE_TAG}", "COMPOSE_PROJECT_NAME=${STACK_NAME}"]) {
                        withCredentials([
                            string(credentialsId: 'lanyard-bot-token', variable: 'BOT_TOKEN')
                        ]) {
                            sh '''
                                echo "Deploying stack: $COMPOSE_PROJECT_NAME..."

                                LANYARD_IMAGE=$LANYARD_IMAGE BOT_TOKEN=$BOT_TOKEN \
                                    docker compose -f docker-compose.yml up -d --remove-orphans

                                echo "Stack deployed successfully"
                            '''
                        }
                    }
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    withEnv(["COMPOSE_PROJECT_NAME=${STACK_NAME}"]) {
                        sh '''
                            echo "Waiting for stack services to start..."
                            sleep 10

                            # Check lanyard container is running
                            if ! docker compose -f docker-compose.yml ps --status running | grep -q lanyard; then
                                echo "ERROR: Lanyard service is not running"
                                docker compose -f docker-compose.yml logs lanyard 2>&1 || true
                                exit 1
                            fi

                            # Check bot connected to Discord by looking for Heartbeat ACK in logs
                            max_attempts=12
                            attempt=0

                            while [ $attempt -lt $max_attempts ]; do
                                if docker compose -f docker-compose.yml logs lanyard 2>&1 | grep -q "Heartbeat ACK"; then
                                    echo "Bot is online and connected to Discord!"
                                    docker compose -f docker-compose.yml ps
                                    exit 0
                                fi
                                attempt=$((attempt + 1))
                                echo "Attempt $attempt/$max_attempts: Bot not ready yet..."
                                sleep 5
                            done

                            echo "Health check failed — bot did not connect to Discord"
                            echo "Service logs:"
                            docker compose -f docker-compose.yml logs lanyard 2>&1
                            exit 1
                        '''
                    }
                }
            }
        }

        stage('Cleanup') {
            steps {
                script {
                    sh """
                        echo "Pruning old images..."

                        docker images ${IMAGE_NAME} --format "{{.ID}} {{.Tag}}" | \
                            grep -v -E "^.* (${IMAGE_TAG}|latest)\$" | \
                            awk '{print \$1}' | xargs -r docker rmi -f 2>/dev/null || true

                        echo "Cleanup completed"
                    """
                }
            }
        }
    }

    post {
        success {
            script {
                echo """
                ====================================
                Deployment Successful!
                ====================================
                Image: ${IMAGE_NAME}:${IMAGE_TAG}
                Stack: ${STACK_NAME}
                Build: #${env.BUILD_NUMBER}
                Commit: ${env.GIT_COMMIT}
                ====================================
                """
            }
        }

        failure {
            script {
                echo """
                ====================================
                Deployment Failed
                ====================================
                Build: #${env.BUILD_NUMBER}
                ====================================
                """

                sh """
                    echo "Stack service logs:"
                    docker service logs ${STACK_NAME}_lanyard 2>&1 || echo "Could not retrieve service logs"
                """
            }
        }
    }
}
