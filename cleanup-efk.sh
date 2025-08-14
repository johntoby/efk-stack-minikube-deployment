#!/bin/bash

# EFK Stack Cleanup Script
set -e

echo "🧹 Starting EFK Stack cleanup..."

# Uninstall Helm releases
echo "📦 Uninstalling Helm releases..."
helm uninstall fluent-bit -n logging || echo "Fluent Bit not found"
helm uninstall kibana -n logging || echo "Kibana not found"
helm uninstall elasticsearch -n logging || echo "Elasticsearch not found"

# Delete PVCs
echo "💾 Deleting PVCs..."
kubectl delete pvc -n logging --all || echo "No PVCs found"

# Delete namespace
echo "📁 Deleting logging namespace..."
kubectl delete namespace logging || echo "Namespace not found"

echo "✅ EFK Stack cleanup completed!"