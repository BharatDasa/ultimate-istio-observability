#!/bin/bash

set -euo pipefail

# Variables
DOCKER_USER="bharatdasa"
API_V1_IMAGE="$DOCKER_USER/api:v1"
API_V2_IMAGE="$DOCKER_USER/api:v2"
WORKER_IMAGE="$DOCKER_USER/worker:v1"

echo "🚀 Starting Docker build process..."

# Build images
echo "📦 Building API v1..."
docker build -t $API_V1_IMAGE ./apps/api-v1

echo "📦 Building API v2..."
docker build -t $API_V2_IMAGE ./apps/api-v2

echo "📦 Building Worker..."
docker build -t $WORKER_IMAGE ./apps/worker

echo "✅ Build completed successfully!"

# Push images
echo "📤 Pushing images to Docker Hub..."

docker push $API_V1_IMAGE
docker push $API_V2_IMAGE
docker push $WORKER_IMAGE

echo "🎉 All images pushed successfully!"
