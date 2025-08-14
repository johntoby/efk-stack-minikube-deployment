#!/bin/bash

# EKS Cluster Deployment Script
set -e

echo "🚀 Deploying EKS cluster..."

# Initialize Terraform
echo "📦 Initializing Terraform..."
terraform init

# Plan deployment
echo "📋 Planning deployment..."
terraform plan

# Apply configuration
echo "🔧 Creating EKS cluster..."
terraform apply -auto-approve

# Configure kubectl
echo "⚙️ Configuring kubectl..."
aws eks --region us-east-2 update-kubeconfig --name efk-cluster

# Verify cluster
echo "✅ Verifying cluster..."
kubectl get nodes

echo "🎉 EKS cluster ready for EFK deployment!"