#!/bin/bash

set -e

docker build \
-t bharatdasa/api:v1 \
apps/api-v1

docker build \
-t bharatdasa/api:v2 \
apps/api-v2

docker build \
-t bharatdasa/worker:v1 \
apps/worker

docker push bharatdasa/api:v1

docker push bharatdasa/api:v2

docker push bharatdasa/worker:v1