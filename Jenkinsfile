pipeline {
    agent any

    environment {
        IMAGE_NAME = 'phpxcoder/lanyardv2'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        CONTAINER_NAME = 'lanyard'
        REDIS_CONTAINER = 'lanyard_redis'
        NETWORK_NAME = 'lanyard_net'
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

        stage('Start Redis') {
            steps {
                script {
                    withEnv(["REDIS_NET=${NETWORK_NAME}", "REDIS_CTR=${REDIS_CONTAINER}"]) {
                        sh '''
                            # Ensure network exists
                            docker network inspect $REDIS_NET > /dev/null 2>&1 || \
                                docker network create $REDIS_NET

                            if ! docker ps --format '{{.Names}}' | grep -q "^${REDIS_CTR}$"; then
                                echo "Starting Redis container..."

                                docker rm -f $REDIS_CTR 2>/dev/null || true

                                docker run -d \
                                    --name $REDIS_CTR \
                                    --restart unless-stopped \
                                    --network $REDIS_NET \
                                    -v lanyard-redis-data:/data \
                                    redis:alpine

                                echo "Waiting for Redis to be ready..."
                                for i in $(seq 1 30); do
                                    if docker exec $REDIS_CTR redis-cli ping 2>/dev/null | grep -q PONG; then
                                        echo "Redis is ready"
                                        break
                                    fi
                                    if [ $i -eq 30 ]; then
                                        echo "ERROR: Redis did not become ready in time"
                                        docker logs $REDIS_CTR 2>&1
                                        exit 1
                                    fi
                                    sleep 2
                                done
                            else
                                echo "Redis container already running, skipping start"
                            fi
                        '''
                    }
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

                            echo "Docker image built and tagged successfully: $BUILD_IMAGE_NAME:$BUILD_IMAGE_TAG"
                        '''
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    sh """
                        echo "Checking for existing container..."

                        if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
                            echo "Found existing container ${CONTAINER_NAME}, removing it..."

                            docker stop ${CONTAINER_NAME} || docker kill ${CONTAINER_NAME} || true
                            sleep 2
                            docker rm -f ${CONTAINER_NAME} || true
                            sleep 1

                            if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
                                echo "ERROR: Container ${CONTAINER_NAME} still exists after removal attempt"
                                docker ps -a | grep ${CONTAINER_NAME} || true
                                exit 1
                            fi

                            echo "Container successfully removed"
                        else
                            echo "No existing container found, proceeding with fresh deployment"
                        fi
                    """

                    withEnv(["BOT_CONTAINER=${CONTAINER_NAME}", "BOT_NETWORK=${NETWORK_NAME}", "BOT_IMAGE=${IMAGE_NAME}:${IMAGE_TAG}", "BOT_REDIS=${REDIS_CONTAINER}"]) {
                        withCredentials([
                            string(credentialsId: 'lanyard-bot-token', variable: 'BOT_TOKEN')
                        ]) {
                            sh '''
                                echo "Starting new container..."

                                if docker ps -a --format '{{.Names}}' | grep -q "^$BOT_CONTAINER$"; then
                                    echo "ERROR: Container $BOT_CONTAINER still exists!"
                                    exit 1
                                fi

                                docker run -d \
                                    --name $BOT_CONTAINER \
                                    --restart unless-stopped \
                                    --network $BOT_NETWORK \
                                    -p 4001:4001 \
                                    -e BOT_TOKEN=$BOT_TOKEN \
                                    -e REDIS_HOST=$BOT_REDIS \
                                    $BOT_IMAGE

                                if ! docker ps --format '{{.Names}}' | grep -q "^$BOT_CONTAINER$"; then
                                    echo "ERROR: Container failed to start"
                                    docker logs $BOT_CONTAINER 2>&1 || true
                                    exit 1
                                fi

                                echo "Container started successfully: $BOT_CONTAINER"

                                echo "Waiting for container to initialize..."
                                sleep 5

                                if ! docker ps --format '{{.Names}}' | grep -q "^$BOT_CONTAINER$"; then
                                    echo "ERROR: Container started but immediately crashed"
                                    echo "Container logs:"
                                    docker logs $BOT_CONTAINER 2>&1
                                    exit 1
                                fi
                            '''
                        }
                    }
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    sh """
                        echo "Running health checks..."
                        sleep 10

                        # Check container is still running
                        if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
                            echo "ERROR: Container is not running"
                            docker logs ${CONTAINER_NAME} 2>&1 || true
                            exit 1
                        fi

                        # Check bot connected to Discord gateway by looking for Heartbeat ACK in logs
                        max_attempts=12
                        attempt=0

                        while [ \$attempt -lt \$max_attempts ]; do
                            if docker logs ${CONTAINER_NAME} 2>&1 | grep -q "Heartbeat ACK"; then
                                echo "Bot is online and connected to Discord!"
                                docker ps | grep ${CONTAINER_NAME}
                                exit 0
                            fi
                            attempt=\$((attempt + 1))
                            echo "Attempt \$attempt/\$max_attempts: Bot not ready yet..."
                            sleep 5
                        done

                        echo "Health check failed — bot did not connect to Discord"
                        echo "Container logs:"
                        docker logs ${CONTAINER_NAME} 2>&1
                        exit 1
                    """
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
                Container: ${CONTAINER_NAME}
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
                    if docker ps -a | grep -q ${CONTAINER_NAME}; then
                        echo "Container logs:"
                        docker logs ${CONTAINER_NAME} 2>&1 || echo "Could not retrieve container logs"
                    else
                        echo "Container was not created"
                    fi
                """
            }
        }
    }
}
