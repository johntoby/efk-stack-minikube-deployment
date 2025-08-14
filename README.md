# EFK Stack Deployment Files

This directory contains all necessary files to deploy the EFK (Elasticsearch, Fluent Bit, Kibana) stack to Minikube.

## Files Overview

### Configuration Files
- `elasticsearch-values.yaml` - Elasticsearch 7.x configuration
- `elasticsearch-8x-values.yaml` - Elasticsearch 8.x configuration  
- `kibana-values.yaml` - Kibana configuration
- `fluent-bit-values.yaml` - Fluent Bit configuration
- `efk-ingress.yaml` - Ingress configuration (optional)

### Deployment Scripts
- `deploy-efk.sh` - Deploy EFK stack with Elasticsearch 7.x
- `deploy-efk-8x.sh` - Deploy EFK stack with Elasticsearch 8.x
- `cleanup-efk.sh` - Clean up EFK stack deployment

## Quick Start

### Prerequisites
```bash
# Start Minikube with sufficient resources
minikube start --memory=6144 --cpus=4 --disk-size=20g

# Enable storage addons
minikube addons enable default-storageclass
minikube addons enable storage-provisioner
```

### Deploy EFK Stack (Elasticsearch 7.x - Recommended)
```bash
chmod +x deploy-efk.sh
./deploy-efk.sh
```

### Deploy EFK Stack (Elasticsearch 8.x)
```bash
chmod +x deploy-efk-8x.sh
./deploy-efk-8x.sh
```

### Access Kibana
```bash
kubectl port-forward service/kibana-kibana 5601:5601 -n logging
# Open http://localhost:5601
```

### Cleanup
```bash
chmod +x cleanup-efk.sh
./cleanup-efk.sh
```

## Manual Deployment

If you prefer manual deployment, follow the commands in `efk-minikube-deployment.md`.

## Troubleshooting

Check pod status:
```bash
kubectl get pods -n logging
kubectl logs <pod-name> -n logging
```

Check Elasticsearch health:
```bash
kubectl port-forward service/elasticsearch-master 9200:9200 -n logging
curl http://localhost:9200/_cluster/health
```