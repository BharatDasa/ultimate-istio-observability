#!/bin/bash

set -e

echo ""
echo "======================================"
echo "🚀 INSTALLING ARGO ROLLOUTS"
echo "======================================"

# ======================================================
# CREATE NAMESPACE
# ======================================================

kubectl create namespace argo-rollouts \
--dry-run=client -o yaml | kubectl apply -f -

# ======================================================
# INSTALL ARGO ROLLOUTS
# ======================================================

kubectl apply -n argo-rollouts \
-f https://raw.githubusercontent.com/argoproj/argo-rollouts/stable/manifests/install.yaml

# ======================================================
# WAIT FOR CONTROLLER
# ======================================================

echo ""
echo "⏳ Waiting for Argo Rollouts controller..."

kubectl rollout status deployment/argo-rollouts \
-n argo-rollouts \
--timeout=120s

# ======================================================
# INSTALL KUBECTL PLUGIN
# ======================================================

echo ""
echo "🔌 Installing kubectl argo rollouts plugin..."

curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64

chmod +x kubectl-argo-rollouts-linux-amd64

sudo mv kubectl-argo-rollouts-linux-amd64 \
/usr/local/bin/kubectl-argo-rollouts

# ======================================================
# VERIFY INSTALLATION
# ======================================================

echo ""
echo "✅ Verifying installation..."

kubectl get pods -n argo-rollouts

kubectl argo rollouts version

# ======================================================
# COMPLETED
# ======================================================

echo ""
echo "======================================"
echo "✅ ARGO ROLLOUTS INSTALLED"
echo "======================================"
