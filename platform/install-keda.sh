#!/bin/bash

set -e

echo ""
echo "======================================"
echo "⚡ INSTALLING KEDA"
echo "======================================"

# ======================================================
# ADD HELM REPO
# ======================================================

helm repo add kedacore https://kedacore.github.io/charts || true

# ======================================================
# UPDATE REPOS
# ======================================================

helm repo update

# ======================================================
# INSTALL / UPGRADE KEDA
# ======================================================

helm upgrade --install keda kedacore/keda \
  --namespace keda \
  --create-namespace

# ======================================================
# WAIT FOR KEDA
# ======================================================

echo ""
echo "⏳ Waiting for KEDA pods..."

kubectl rollout status deployment/keda-operator \
-n keda \
--timeout=120s

# ======================================================
# VERIFY
# ======================================================

echo ""
echo "✅ Verifying KEDA..."

kubectl get pods -n keda

kubectl get crd | grep keda

# ======================================================
# COMPLETED
# ======================================================

echo ""
echo "======================================"
echo "✅ KEDA INSTALLED"
echo "======================================"
