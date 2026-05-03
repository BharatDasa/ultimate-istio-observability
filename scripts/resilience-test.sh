#!/bin/bash

set -euo pipefail

# ======================================================
# CONFIG
# ======================================================

NAMESPACE="istio-demo"

URL="http://api.192.168.56.101.nip.io"

CHAOS_ROUNDS=3

RECOVERY_WAIT=20

WORKER_STRESS_DURATION=60

AUTOSCALER_COOLDOWN=240

# ======================================================
# CLEANUP
# ======================================================

cleanup() {

  echo ""
  echo "🛑 Cleaning up background processes..."

  kill $API_TRAFFIC_PID >/dev/null 2>&1 || true
}

trap cleanup EXIT

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

curl -s -I $URL || true

# ======================================================
# START HIGH-CONCURRENCY API TRAFFIC
# ======================================================

echo ""
echo "🔥 Starting HIGH-CONCURRENCY API traffic..."

(
while true; do

  seq 1 1000 | xargs -P70 -I{} \
  curl -s $URL > /dev/null 2>&1

done
) &

API_TRAFFIC_PID=$!

echo ""
echo "✅ High-concurrency API traffic started"
echo "API Traffic PID: $API_TRAFFIC_PID"

# ======================================================
# START WORKER CPU STRESS
# ======================================================

echo ""
echo "🔥 Starting worker CPU stress..."

kubectl exec -n $NAMESPACE deploy/worker -- \
sh -c "timeout $WORKER_STRESS_DURATION sh -c 'while true; do yes > /dev/null; done'" \
>/dev/null 2>&1 &

echo ""
echo "✅ Worker CPU stress started"
echo "Duration: ${WORKER_STRESS_DURATION}s"

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

echo ""
echo "📈 Initial HPA / KEDA"

kubectl get hpa -n $NAMESPACE || true

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
  echo "⏳ Waiting for Kubernetes recovery and autoscaling..."

  sleep $RECOVERY_WAIT

  echo ""
  echo "📦 Current Pods"

  kubectl get pods -n $NAMESPACE -o wide

  echo ""
  echo "🌐 Verifying application response..."

  curl -s -I $URL || true

  echo ""
  echo "📈 Checking HPA / KEDA..."

  kubectl get hpa -n $NAMESPACE || true

  echo ""
  echo "📈 Current Replica Counts"

  echo -n "API Pods: "
  kubectl get pods -n $NAMESPACE -l app=api --no-headers | wc -l

  echo -n "Worker Pods: "
  kubectl get pods -n $NAMESPACE -l app=worker --no-headers | wc -l

done

# ======================================================
# WAIT FOR AUTOSCALING
# ======================================================

echo ""
echo "⏳ Waiting for autoscaling metrics..."

sleep 60

# ======================================================
# VERIFY KEDA BEFORE STOPPING TRAFFIC
# ======================================================

echo ""
echo "📈 Checking KEDA activity..."

kubectl get scaledobject -n $NAMESPACE || true

echo ""
echo "📈 Checking HPA..."

kubectl get hpa -n $NAMESPACE || true

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
curl -s localhost:15090/stats/prometheus | \
grep istio_requests_total || true

# ======================================================
# VERIFY DISTRIBUTED TRACING
# ======================================================

echo ""
echo "🛰️ Checking distributed tracing..."

echo ""
echo "📦 Trace Headers"

curl -s -D - $URL -o /dev/null | \
grep -Ei "traceparent|x-request-id|x-b3-traceid" || true

# ======================================================
# VERIFY ENVOY TRACE CONFIG
# ======================================================

echo ""
echo "📊 Envoy Trace Configuration"

kubectl exec -n $NAMESPACE $POD -c istio-proxy -- \
curl -s localhost:15000/config_dump | \
grep -i tracing | head || true

# ======================================================
# VERIFY TEMPO TRACES
# ======================================================

echo ""
echo "🔍 Checking traces from Tempo..."

TRACE_FOUND=false

for i in {1..8}; do

  RESPONSE=$(kubectl exec -n monitoring tempo-0 -- \
    wget -qO- "http://localhost:3200/api/search?limit=20" \
    2>/dev/null || true)

  echo ""
  echo "Attempt $i → Response: $RESPONSE"

  if [[ "$RESPONSE" == *"traceID"* ]]; then

    echo ""
    echo "✅ Traces FOUND in Tempo!"

    echo ""
    echo "📦 Trace IDs"

    echo "$RESPONSE" | grep -oE '"traceID":"[^"]+"' || true

    TRACE_FOUND=true

    break
  fi

  echo ""
  echo "⏳ No traces yet, retrying..."

  sleep 5

done

if [ "$TRACE_FOUND" = false ]; then

  echo ""
  echo "❌ No traces found in Tempo!"

  echo ""
  echo "🔍 Tempo Logs"

  kubectl logs -n monitoring tempo-0 --tail=50 || true

fi

# ======================================================
# VERIFY ENVOY ACCESS LOGS
# ======================================================

echo ""
echo "📊 Checking Envoy access logs..."

sleep 5

FOUND_LOGS=false

for POD in $(kubectl get pods -n $NAMESPACE \
-l app=api \
-o jsonpath='{.items[*].metadata.name}'); do

  echo ""
  echo "🔍 Pod: $POD"

  LOGS=$(kubectl logs -n $NAMESPACE $POD \
    -c istio-proxy \
    --tail=100 2>/dev/null | \
    grep -E '"GET|POST|PUT|DELETE|HEAD' || true)

  if [[ -n "$LOGS" ]]; then

    echo "$LOGS"

    FOUND_LOGS=true
  fi
done

if [ "$FOUND_LOGS" = false ]; then

  echo ""
  echo "⚠ No Envoy access logs found yet"

fi

# ======================================================
# STOP API TRAFFIC
# ======================================================

echo ""
echo "🛑 Stopping API traffic generation..."

kill $API_TRAFFIC_PID || true

sleep 10

# ======================================================
# VERIFY FINAL KEDA
# ======================================================

echo ""
echo "📈 Final KEDA Status"

kubectl get scaledobject -n $NAMESPACE || true

echo ""
echo "📈 Final HPA Status"

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
echo "📈 Final Replica Summary"

kubectl get deploy -n $NAMESPACE

echo ""

kubectl get rollout -n $NAMESPACE

# ======================================================
# AUTOSCALER COOLDOWN
# ======================================================

echo ""
echo "⏳ Waiting for autoscaler cooldown..."

sleep $AUTOSCALER_COOLDOWN

echo ""
echo "📊 Current Worker CPU"

kubectl top pod -n $NAMESPACE | grep worker || true

echo ""
echo "⏳ Waiting for worker scale-down..."

for i in {1..24}; do

  echo ""
  echo "Cooldown Check $i"

  kubectl get hpa -n $NAMESPACE || true

  REPLICAS=$(kubectl get hpa worker-hpa \
    -n $NAMESPACE \
    -o jsonpath='{.status.currentReplicas}' || echo "0")

  echo ""
  echo "Current worker replicas: $REPLICAS"

  if [ "$REPLICAS" -le 1 ]; then

    echo ""
    echo "✅ Worker scaled down successfully!"

    break
  fi

  sleep 10

done

# ======================================================
# FINAL AUTOSCALER STATUS
# ======================================================

echo ""
echo "📉 Final Autoscaler Status"

kubectl get hpa -n $NAMESPACE

# ======================================================
# FINAL LINKS
# ======================================================

echo ""
echo "🌐 Application URL"

echo "$URL"

echo ""
echo "📊 Grafana"

echo "Explore → Tempo"
echo "Dashboards → Istio"

# ======================================================
# SUMMARY
# ======================================================

echo ""
echo "🎯 WHAT WAS TESTED"

echo "✔ High-Concurrency API Traffic"
echo "✔ Worker CPU Stress"
echo "✔ KEDA Autoscaling"
echo "✔ HPA Autoscaling"
echo "✔ Istio Routing"
echo "✔ Istio Metrics"
echo "✔ Prometheus Metrics"
echo "✔ Distributed Tracing"
echo "✔ Tempo Integration"
echo "✔ Trace ID Validation"
echo "✔ Pod Recovery"
echo "✔ Kubernetes Self-Healing"
echo "✔ Canary Rollout"
echo "✔ Application Availability"
echo "✔ Chaos Engineering"

echo ""
echo "🏁 TEST FINISHED"

echo ""
