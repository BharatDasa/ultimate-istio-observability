#!/bin/bash

set -e

echo ""
echo "======================================"
echo "🚀 DEPLOYING ISTIO OBSERVABILITY APP"
echo "======================================"

# ======================================================
# NAMESPACE
# ======================================================

echo ""
echo "📦 Creating namespace..."

kubectl apply -f namespace.yaml

# ======================================================
# WORKER
# ======================================================

echo ""
echo "⚙️ Deploying worker..."

kubectl apply -f apps/worker/

# ======================================================
# API SERVICES
# ======================================================

echo ""
echo "🌐 Creating API stable/canary services..."

kubectl apply -f apps/api/api-stable-service.yaml

kubectl apply -f apps/api/api-canary-service.yaml

# ======================================================
# ISTIO
# ======================================================

echo ""
echo "🛣️ Applying Istio routing..."

kubectl apply -f istio/

# ======================================================
# ROLLOUT
# ======================================================

echo ""
echo "🚀 Deploying Argo Rollout..."

kubectl apply -f apps/api/rollout.yaml

# ======================================================
# MONITORING
# ======================================================

echo ""
echo "📊 Applying monitoring resources..."

kubectl apply -f monitoring/

kubectl apply -f rollout/

# ======================================================
# SCALING
# ======================================================

echo ""
echo "📈 Applying scaling..."

kubectl apply -f scaling/

# ======================================================
# FINAL STATUS
# ======================================================

echo ""
echo "======================================"
echo "✅ DEPLOYMENT COMPLETED"
echo "======================================"

kubectl get all -n istio-demo
