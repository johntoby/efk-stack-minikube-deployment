#!/bin/bash

# EFK Stack Deployment Script for AWS EKS
set -e

echo "🚀 Starting EFK Stack deployment to AWS EKS..."

# Verify EKS connection
echo "🔍 Verifying EKS cluster connection..."
kubectl cluster-info

# Create namespace
echo "📁 Creating logging namespace..."
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repositories
echo "📦 Adding Helm repositories..."
helm repo add elastic https://helm.elastic.co
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

# Deploy Elasticsearch
echo "🔍 Deploying Elasticsearch cluster..."
helm install elasticsearch elastic/elasticsearch \
  --namespace logging \
  --values elasticsearch-values.yaml \
  --version 7.17.3

# Wait for Elasticsearch to be ready
echo "⏳ Waiting for Elasticsearch cluster to be ready..."
kubectl wait --for=condition=ready pod -l app=elasticsearch-master -n logging --timeout=600s

# Deploy Kibana
echo "📊 Deploying Kibana..."
helm install kibana elastic/kibana \
  --namespace logging \
  --values kibana-values.yaml \
  --version 7.17.3

# Wait for Kibana to be ready
echo "⏳ Waiting for Kibana to be ready..."
kubectl wait --for=condition=ready pod -l app=kibana -n logging --timeout=300s

# Deploy Fluent Bit
echo "📝 Deploying Fluent Bit..."
helm install fluent-bit fluent/fluent-bit \
  --namespace logging \
  --values fluent-bit-values.yaml

# Wait for Fluent Bit to be ready
echo "⏳ Waiting for Fluent Bit to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=fluent-bit -n logging --timeout=300s

# Show deployment status
echo "✅ EFK Stack deployment completed!"
echo ""
echo "📋 Deployment Status:"
helm list -n logging
echo ""
kubectl get pods -n logging
echo ""
echo "🌐 Access Kibana:"
echo "LoadBalancer URL (wait for provisioning):"
kubectl get service kibana-kibana -n logging
echo ""
echo "Get external URL:"
echo "kubectl get service kibana-kibana -n logging -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"