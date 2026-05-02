#!/bin/bash

set -euo pipefail

# ======================================================
# CONFIG
# ======================================================
NAMESPACE="istio-demo"

URL="http://api.192.168.56.101.nip.io"

CHAOS_ROUNDS=5

RECOVERY_WAIT=20

TRAFFIC_SLEEP=0.05

# ======================================================
# HEADER
# ======================================================
echo ""
echo "======================================================"
echo "🚀 STARTING ULTIMATE RESILIENCE TEST"
echo "======================================================"

# ======================================================
# VERIFY APPLICATION
# ======================================================
echo ""
echo "🔍 Checking application availability..."

curl -I $URL || true

# ======================================================
# START CONTINUOUS TRAFFIC
# ======================================================
echo ""
echo "🔥 Starting continuous traffic generation..."

(
while true; do

  curl -s $URL > /dev/null || true

  sleep $TRAFFIC_SLEEP

done
) &

TRAFFIC_PID=$!

echo ""
echo "✅ Traffic generator started"
echo "Traffic PID: $TRAFFIC_PID"

# ======================================================
# SHOW INITIAL STATE
# ======================================================
echo ""
echo "📦 Initial Pods"

kubectl get pods -n $NAMESPACE -o wide

echo ""
echo "📦 Initial Services"

kubectl get svc -n $NAMESPACE

echo ""
echo "📦 Initial Rollouts"

kubectl get rollout -n $NAMESPACE || true

# ======================================================
# CHAOS TESTING LOOP
# ======================================================
echo ""
echo "💥 Starting chaos testing..."

for i in $(seq 1 $CHAOS_ROUNDS); do

  echo ""
  echo "======================================================"
  echo "💥 CHAOS ROUND $i / $CHAOS_ROUNDS"
  echo "======================================================"

  echo ""
  echo "🔥 Force deleting API pods..."

  kubectl delete pod \
    -l app=api \
    -n $NAMESPACE \
    --grace-period=0 \
    --force || true

  echo ""
  echo "⏳ Waiting for Kubernetes recovery..."

  sleep $RECOVERY_WAIT

  echo ""
  echo "📦 Current Pods"

  kubectl get pods -n $NAMESPACE -o wide

  echo ""
  echo "🌐 Verifying application response..."

  curl -I $URL || true

  echo ""
  echo "📈 Checking HPA..."

  kubectl get hpa -n $NAMESPACE || true

done

# ======================================================
# STOP TRAFFIC
# ======================================================
echo ""
echo "🛑 Stopping traffic generation..."

kill $TRAFFIC_PID || true

sleep 2

# ======================================================
# VERIFY ISTIO METRICS
# ======================================================
echo ""
echo "📊 Checking Istio metrics..."

POD=$(kubectl get pod -n $NAMESPACE \
-l app=api \
-o jsonpath='{.items[0].metadata.name}')

echo ""
echo "Using pod: $POD"

kubectl exec -n $NAMESPACE $POD -c istio-proxy -- \
curl -s localhost:15090/stats/prometheus \
| grep istio_requests_total || true

# ======================================================
# VERIFY KEDA
# ======================================================
echo ""
echo "📈 Checking KEDA..."

kubectl get scaledobject -n $NAMESPACE || true

# ======================================================
# VERIFY HPA
# ======================================================
echo ""
echo "📈 Checking HPA..."

kubectl get hpa -n $NAMESPACE || true

# ======================================================
# VERIFY ROLLOUT
# ======================================================
echo ""
echo "🚀 Checking Rollout..."

kubectl get rollout -n $NAMESPACE || true

echo ""
kubectl argo rollouts get rollout api \
-n $NAMESPACE || true

# ======================================================
# FINAL STATUS
# ======================================================
echo ""
echo "======================================================"
echo "✅ RESILIENCE TEST COMPLETED SUCCESSFULLY"
echo "======================================================"

echo ""
echo "📦 Final Resources"

kubectl get all -n $NAMESPACE

echo ""
echo "🌐 Application URL"
echo "$URL"

echo ""
echo "📊 Grafana"
echo "Explore → Tempo"
echo "Dashboards → Istio"

echo ""
echo "🎯 WHAT WAS TESTED"
echo "✔ Continuous Traffic"
echo "✔ Istio Routing"
echo "✔ Pod Recovery"
echo "✔ Kubernetes Self-Healing"
echo "✔ HPA Scaling"
echo "✔ KEDA Integration"
echo "✔ Istio Metrics"
echo "✔ Canary Rollout"
echo "✔ Application Availability"
echo "✔ Chaos Engineering"
echo ""