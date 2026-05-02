#!/bin/bash

set -e

kubectl apply -f namespace.yaml

kubectl apply -f apps/worker/

kubectl apply -f apps/api/deployment-v1.yaml

kubectl apply -f apps/api/service.yaml

kubectl apply -f istio/

kubectl apply -f apps/api/rollout.yaml

kubectl apply -f monitoring/

kubectl apply -f rollout/

kubectl apply -f scaling/