#!/bin/bash

# EFK Stack Deployment Script for Minikube
set -e

echo "🚀 Starting EFK Stack deployment to Minikube..."

# Create namespace
echo "📁 Creating logging namespace..."
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repositories
echo "📦 Adding Helm repositories..."
helm repo add elastic https://helm.elastic.co
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

# Deploy Elasticsearch (7.x by default)
echo "🔍 Deploying Elasticsearch..."
helm install elasticsearch elastic/elasticsearch \
  --namespace logging \
  --values elasticsearch-values.yaml \
  --version 7.17.3

# Wait for Elasticsearch to be ready
echo "⏳ Waiting for Elasticsearch to be ready..."
kubectl wait --for=condition=ready pod -l app=elasticsearch-master -n logging --timeout=300s

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
echo "kubectl port-forward service/kibana-kibana 5601:5601 -n logging"
echo "Then open: http://localhost:5601"