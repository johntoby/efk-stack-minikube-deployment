# EFK Stack Deployment to Minikube using Helm Charts

## Prerequisites

### 1. Minikube Setup
```bash
# Start minikube with sufficient resources
minikube start --memory=6144 --cpus=4 --disk-size=20g

# Enable addons
minikube addons enable default-storageclass
minikube addons enable storage-provisioner

# Verify cluster is running
kubectl cluster-info
```

<!-- ### 2. Install Helm
```bash
# Install Helm (if not already installed)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash -->

<!-- # Verify Helm installation
helm version
``` -->

### 3. Create Namespace
```bash
kubectl create namespace logging
```

## Step 1: Add Required Helm Repositories

```bash
# Add Elastic official Helm repository
helm repo add elastic https://helm.elastic.co

# Add Fluent Helm repository
helm repo add fluent https://fluent.github.io/helm-charts

# Update repositories
helm repo update

# Verify repositories
helm repo list
```

## Step 2: Deploy Elasticsearch using Helm

### 2.1 Create Elasticsearch Values File

#### For Elasticsearch 7.x (Recommended for simplicity)
```yaml
# elasticsearch-values.yaml
---
# Minikube optimized settings
replicas: 1
minimumMasterNodes: 1

# Resource configuration for Minikube
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "1000m"
    memory: "2Gi"

# JVM heap settings
esJavaOpts: "-Xmx512m -Xms512m"

# Volume configuration
volumeClaimTemplate:
  accessModes: [ "ReadWriteOnce" ]
  storageClassName: "standard"
  resources:
    requests:
      storage: 5Gi

# Single node cluster configuration
clusterName: "elasticsearch"
nodeGroup: "master"

# Disable security for simplicity
xpack:
  security:
    enabled: false

# Service configuration
service:
  type: ClusterIP
  ports:
    - name: http
      protocol: TCP
      port: 9200
    - name: transport
      protocol: TCP
      port: 9300

# Health checks
readinessProbe:
  failureThreshold: 3
  initialDelaySeconds: 10
  periodSeconds: 10
  successThreshold: 3
  timeoutSeconds: 5

# Disable anti-affinity for single node
antiAffinity: "soft"

# Sysctls for Elasticsearch
sysctlInitContainer:
  enabled: false
```

#### For Elasticsearch 8.x (Advanced)
```yaml
# elasticsearch-8x-values.yaml
---
# Minikube optimized settings
replicas: 1
minimumMasterNodes: 1

# Resource configuration for Minikube
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "1000m"
    memory: "2Gi"

# Volume configuration
volumeClaimTemplate:
  accessModes: [ "ReadWriteOnce" ]
  storageClassName: "standard"
  resources:
    requests:
      storage: 5Gi

# Single node cluster configuration
clusterName: "elasticsearch"
nodeGroup: "master"

# Elasticsearch 8.x configuration with security disabled
esConfig:
  elasticsearch.yml: |
    discovery.type: single-node
    xpack.security.enabled: false
    xpack.security.enrollment.enabled: false
    xpack.security.http.ssl.enabled: false
    xpack.security.transport.ssl.enabled: false

# Environment variables
extraEnvs:
  - name: ES_JAVA_OPTS
    value: "-Xms512m -Xmx512m"
  - name: discovery.type
    value: single-node

# Service configuration
service:
  type: ClusterIP
  ports:
    - name: http
      protocol: TCP
      port: 9200
    - name: transport
      protocol: TCP
      port: 9300

# Health checks
readinessProbe:
  failureThreshold: 3
  initialDelaySeconds: 30
  periodSeconds: 10
  successThreshold: 3
  timeoutSeconds: 5

# Disable anti-affinity for single node
antiAffinity: "soft"

# Sysctls for Elasticsearch
sysctlInitContainer:
  enabled: false
```

### 2.2 Deploy Elasticsearch

#### For Elasticsearch 7.x
```bash
# Deploy Elasticsearch 7.x
helm install elasticsearch elastic/elasticsearch \
  --namespace logging \
  --values elasticsearch-values.yaml \
  --version 7.17.3

# Check deployment status
helm status elasticsearch -n logging

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=elasticsearch-master -n logging --timeout=300s
```

#### For Elasticsearch 8.x
```bash
# Deploy Elasticsearch 8.x
helm install elasticsearch elastic/elasticsearch \
  --namespace logging \
  --values elasticsearch-8x-values.yaml \
  --version 8.5.1

# Check deployment status
helm status elasticsearch -n logging

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=elasticsearch-master -n logging --timeout=300s
```

## Step 3: Deploy Kibana using Helm

### 3.1 Create Kibana Values File
```yaml
# kibana-values.yaml
---
# Resource configuration for Minikube
resources:
  requests:
    cpu: "200m"
    memory: "512Mi"
  limits:
    cpu: "500m"
    memory: "1Gi"

# Elasticsearch connection
elasticsearchHosts: "http://elasticsearch-master:9200"

# Service configuration using ClusterIP
service:
  type: ClusterIP
  port: 5601

# Health checks
healthCheckPath: "/app/kibana"

# Basic configuration
kibanaConfig:
  kibana.yml: |
    server.host: "0.0.0.0"
    server.name: kibana
    elasticsearch.hosts: [ "http://elasticsearch-master:9200" ]
    monitoring.ui.container.elasticsearch.enabled: true

# Security settings
podSecurityContext:
  fsGroup: 1000

securityContext:
  capabilities:
    drop:
    - ALL
  runAsNonRoot: true
  runAsUser: 1000

# Single replica for Minikube
replicas: 1

# Environment variables
env:
  - name: SERVER_HOST
    value: "0.0.0.0"
  - name: ELASTICSEARCH_HOSTS
    value: "http://elasticsearch-master:9200"
```

### 3.2 Deploy Kibana
```bash
# Deploy Kibana
helm install kibana elastic/kibana \
  --namespace logging \
  --values kibana-values.yaml \
  --version 7.17.3

# Check deployment status
helm status kibana -n logging

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=kibana -n logging --timeout=300s
```

## Step 4: Deploy Fluent Bit using Helm

### 4.1 Create Fluent Bit Values File
```yaml
# fluent-bit-values.yaml
---
# Resource configuration for Minikube
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi

# Service account configuration
serviceAccount:
  create: true
  name: fluent-bit

# RBAC configuration
rbac:
  create: true
  nodeAccess: true

# Fluent Bit configuration
config:
  service: |
    [SERVICE]
        Daemon Off
        Flush {{ .Values.flush }}
        Log_Level {{ .Values.logLevel }}
        Parsers_File parsers.conf
        Parsers_File custom_parsers.conf
        HTTP_Server On
        HTTP_Listen 0.0.0.0
        HTTP_Port {{ .Values.metricsPort }}
        Health_Check On

  inputs: |
    [INPUT]
        Name tail
        Path /var/log/containers/*.log
        multiline.parser docker, cri
        Tag kube.*
        Mem_Buf_Limit 50MB
        Skip_Long_Lines On

    [INPUT]
        Name systemd
        Tag host.*
        Systemd_Filter _SYSTEMD_UNIT=kubelet.service
        Read_From_Tail On

  filters: |
    [FILTER]
        Name kubernetes
        Match kube.*
        Kube_URL https://kubernetes.default.svc:443
        Kube_CA_File /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File /var/run/secrets/kubernetes.io/serviceaccount/token
        Kube_Tag_Prefix kube.var.log.containers.
        Merge_Log On
        Merge_Log_Key log_processed
        K8S-Logging.Parser On
        K8S-Logging.Exclude Off

    [FILTER]
        Name modify
        Match *
        Add cluster_name minikube-cluster

  outputs: |
    [OUTPUT]
        Name es
        Match kube.*
        Host elasticsearch-master
        Port 9200
        Logstash_Format On
        Logstash_Prefix logstash
        Retry_Limit False
        Type _doc
        Time_Key @timestamp
        Replace_Dots On
        Suppress_Type_Name On

  customParsers: |
    [PARSER]
        Name docker_no_time
        Format json
        Time_Keep Off
        Time_Key time
        Time_Format %Y-%m-%dT%H:%M:%S.%L

# Volume mounts for log access
volumeMounts:
  - name: varlog
    mountPath: /var/log
    readOnly: true
  - name: varlibdockercontainers
    mountPath: /var/lib/docker/containers
    readOnly: true
  - name: etcmachineid
    mountPath: /etc/machine-id
    readOnly: true

daemonSetVolumes:
  - name: varlog
    hostPath:
      path: /var/log
  - name: varlibdockercontainers
    hostPath:
      path: /var/lib/docker/containers
  - name: etcmachineid
    hostPath:
      path: /etc/machine-id
      type: File

# Tolerations for master node
tolerations:
  - key: node-role.kubernetes.io/master
    operator: Exists
    effect: NoSchedule
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule

# Update strategy
updateStrategy:
  type: RollingUpdate

# Metrics configuration
metricsPort: 2020
```

### 4.2 Deploy Fluent Bit
```bash
# Deploy Fluent Bit
helm install fluent-bit fluent/fluent-bit \
  --namespace logging \
  --values fluent-bit-values.yaml

# Check deployment status
helm status fluent-bit -n logging

# Wait for daemonset to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=fluent-bit -n logging --timeout=300s
```

## Step 5: Verification and Access

### 5.1 Check All Deployments
```bash
# List all Helm releases
helm list -n logging

# Check pod status
kubectl get pods -n logging

# Check services (all should be ClusterIP type)
kubectl get svc -n logging

# Check persistent volumes
kubectl get pv,pvc -n logging
```

### 5.2 Access Services via Port Forwarding

#### Access Kibana
```bash
# Port forward Kibana service
kubectl port-forward service/kibana-kibana 5601:5601 -n logging

# Access Kibana at: http://localhost:5601
```

#### Access Elasticsearch (for debugging)
```bash
# Port forward Elasticsearch service
kubectl port-forward service/elasticsearch-master 9200:9200 -n logging

# Test Elasticsearch connectivity
curl http://localhost:9200/_cluster/health
```

#### Access Fluent Bit Metrics (optional)
```bash
# Port forward Fluent Bit metrics
kubectl port-forward service/fluent-bit 2020:2020 -n logging

# Check Fluent Bit metrics
curl http://localhost:2020/api/v1/metrics
```

### 5.3 Alternative Access Methods

#### Option 1: Using kubectl proxy
```bash
# Start kubectl proxy
kubectl proxy --port=8001

# Access services through proxy:
# Kibana: http://localhost:8001/api/v1/namespaces/logging/services/kibana-kibana:5601/proxy/
# Elasticsearch: http://localhost:8001/api/v1/namespaces/logging/services/elasticsearch-master:9200/proxy/
```

#### Option 2: Create Ingress (if ingress controller is available)
```yaml
# efk-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: efk-ingress
  namespace: logging
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: kibana.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kibana-kibana
            port:
              number: 5601
  - host: elasticsearch.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: elasticsearch-master
            port:
              number: 9200
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Elasticsearch Pod Restart Loop
**Symptoms**: Pod keeps restarting, BackOff errors

**Solutions**:
```bash
# Check pod logs
kubectl logs elasticsearch-master-0 -n logging --previous

# Check resource usage
kubectl top pods -n logging
kubectl describe node minikube

# If memory issues, increase JVM heap or node memory
minikube start --memory=8192 --cpus=4
```

#### 2. Readiness Probe Failures
**Symptoms**: "Readiness probe failed: Waiting for elasticsearch cluster to become ready"

**For ES 8.x, add security configuration**:
```bash
# Update values file with security disabled (see ES 8.x config above)
helm upgrade elasticsearch elastic/elasticsearch -n logging -f elasticsearch-8x-values.yaml
```

#### 3. PVC Binding Issues
**Symptoms**: "pod has unbound immediate PersistentVolumeClaims"

**Solutions**:
```bash
# Check storage class
kubectl get storageclass

# Enable storage provisioner if not enabled
minikube addons enable storage-provisioner
minikube addons enable default-storageclass

# Check PVC status
kubectl get pvc -n logging
kubectl describe pvc <pvc-name> -n logging
```

#### 4. Kibana Connection Issues
**Symptoms**: Kibana can't connect to Elasticsearch

**Solutions**:
```bash
# Verify Elasticsearch is running
kubectl get pods -n logging
kubectl port-forward service/elasticsearch-master 9200:9200 -n logging
curl http://localhost:9200/_cluster/health

# Check Kibana logs
kubectl logs deployment/kibana-kibana -n logging
```

#### 5. No Logs in Kibana
**Symptoms**: Kibana shows no data

**Solutions**:
```bash
# Check Fluent Bit is running
kubectl get pods -n logging -l app.kubernetes.io/name=fluent-bit

# Check Fluent Bit logs
kubectl logs daemonset/fluent-bit -n logging

# Verify Elasticsearch indices
kubectl port-forward service/elasticsearch-master 9200:9200 -n logging
curl http://localhost:9200/_cat/indices
```

### Upgrade Commands
```bash
# Upgrade Elasticsearch
helm upgrade elasticsearch elastic/elasticsearch -n logging -f elasticsearch-values.yaml

# Upgrade Kibana
helm upgrade kibana elastic/kibana -n logging -f kibana-values.yaml

# Upgrade Fluent Bit
helm upgrade fluent-bit fluent/fluent-bit -n logging -f fluent-bit-values.yaml
```

### Cleanup Commands
```bash
# Uninstall all components
helm uninstall elasticsearch -n logging
helm uninstall kibana -n logging
helm uninstall fluent-bit -n logging

# Delete PVCs (if needed)
kubectl delete pvc -n logging --all

# Delete namespace
kubectl delete namespace logging
```
        pathType: Prefix
        backend:
          service:
            name: elasticsearch-master
            port:
              number: 9200
```

```bash
# Enable ingress addon in Minikube
minikube addons enable ingress

# Apply ingress configuration
kubectl apply -f efk-ingress.yaml

# Add entries to /etc/hosts (Linux/Mac) or C:\Windows\System32\drivers\etc\hosts (Windows)
echo "$(minikube ip) kibana.local" | sudo tee -a /etc/hosts
echo "$(minikube ip) elasticsearch.local" | sudo tee -a /etc/hosts

# Access services:
# Kibana: http://kibana.local
# Elasticsearch: http://elasticsearch.local
```

### 5.4 Verify Services are ClusterIP Type
```bash
# Verify all services are using ClusterIP
kubectl get svc -n logging -o wide

# Expected output should show TYPE as ClusterIP for all services:
# NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
# elasticsearch-master    ClusterIP   10.96.xxx.xxx   <none>        9200/TCP,9300/TCP   5m
# kibana-kibana          ClusterIP   10.96.xxx.xxx   <none>        5601/TCP            4m
# fluent-bit             ClusterIP   10.96.xxx.xxx   <none>        2020/TCP            3m
```

### 5.5 Create Service Access Script
```bash
# Create a script for easy service access
cat > access-efk.sh << 'EOF'
#!/bin/bash

SERVICE=$1
PORT=$2

case $SERVICE in
  "kibana")
    echo "Accessing Kibana on http://localhost:5601"
    kubectl port-forward service/kibana-kibana 5601:5601 -n logging
    ;;
  "elasticsearch")
    echo "Accessing Elasticsearch on http://localhost:9200"
    kubectl port-forward service/elasticsearch-master 9200:9200 -n logging
    ;;
  "fluent-bit")
    echo "Accessing Fluent Bit metrics on http://localhost:2020"
    kubectl port-forward service/fluent-bit 2020:2020 -n logging
    ;;
  "all")
    echo "Starting port-forwards for all services..."
    kubectl port-forward service/kibana-kibana 5601:5601 -n logging &
    kubectl port-forward service/elasticsearch-master 9200:9200 -n logging &
    kubectl port-forward service/fluent-bit 2020:2020 -n logging &
    echo "Services accessible at:"
    echo "- Kibana: http://localhost:5601"
    echo "- Elasticsearch: http://localhost:9200"
    echo "- Fluent Bit: http://localhost:2020"
    wait
    ;;
  *)
    echo "Usage: $0 {kibana|elasticsearch|fluent-bit|all}"
    echo "Examples:"
    echo "  $0 kibana"
    echo "  $0 all"
    exit 1
    ;;
esac
EOF

chmod +x access-efk.sh

# Usage examples:
# ./access-efk.sh kibana
# ./access-efk.sh all
```

## Step 6: Configure Kibana Index Patterns

### 1. Security Benefits
- **Internal Access Only**: Services are only accessible within the cluster
- **No External Exposure**: Reduces attack surface by not exposing services externally
- **Network Segmentation**: Better isolation between services and external traffic

### 2. Production Alignment
- **Production Pattern**: ClusterIP is the default and most common service type in production
- **Ingress Integration**: Works seamlessly with ingress controllers for controlled external access
- **Service Mesh Ready**: Compatible with service mesh implementations (Istio, Linkerd)

### 3. Resource Efficiency
- **No NodePort Allocation**: Doesn't consume NodePort range (30000-32767)
- **Cleaner Network**: No additional iptables rules for NodePort handling
- **Predictable IPs**: Cluster-internal IPs are stable and predictable

## Service Access Patterns

### Development Access (Port Forwarding)
```bash
# Access Kibana for development
kubectl port-forward service/kibana-kibana 5601:5601 -n logging

# Access Elasticsearch for debugging
kubectl port-forward service/elasticsearch-master 9200:9200 -n logging

# Multiple port forwards in background
kubectl port-forward service/kibana-kibana 5601:5601 -n logging &
kubectl port-forward service/elasticsearch-master 9200:9200 -n logging &
```

### Production Access (Ingress)
```bash
# Enable ingress for production-like access
minikube addons enable ingress

# Apply ingress configuration (see ingress example above)
kubectl apply -f efk-ingress.yaml
```

### Monitoring Access
```bash
# Access Fluent Bit metrics
kubectl port-forward service/fluent-bit 2020:2020 -n logging

# Check metrics endpoint
curl http://localhost:2020/api/v1/metrics
```

## Benefits of Using ClusterIP Services

### 1. Security Benefits
- **Internal Access Only**: Services are only accessible within the cluster
- **No External Exposure**: Reduces attack surface by not exposing services externally
- **Network Segmentation**: Better isolation between services and external traffic

### 2. Production Alignment
- **Production Pattern**: ClusterIP is the default and most common service type in production
- **Ingress Integration**: Works seamlessly with ingress controllers for controlled external access
- **Service Mesh Ready**: Compatible with service mesh implementations (Istio, Linkerd)

### 3. Resource Efficiency
- **No NodePort Allocation**: Doesn't consume NodePort range (30000-32767)
- **Cleaner Network**: No additional iptables rules for NodePort handling
- **Predictable IPs**: Cluster-internal IPs are stable and predictable

## Service Access Patterns

### Development Access (Port Forwarding)
```bash
# Access Kibana for development
kubectl port-forward service/kibana-kibana 5601:5601 -n logging

# Access Elasticsearch for debugging
kubectl port-forward service/elasticsearch-master 9200:9200 -n logging

# Multiple port forwards in background
kubectl port-forward service/kibana-kibana 5601:5601 -n logging &
kubectl port-forward service/elasticsearch-master 9200:9200 -n logging &
```

### Production Access (Ingress)
```bash
# Enable ingress for production-like access
minikube addons enable ingress

# Apply ingress configuration (see ingress example above)
kubectl apply -f efk-ingress.yaml
```

### Monitoring Access
```bash
# Access Fluent Bit metrics
kubectl port-forward service/fluent-bit 2020:2020 -n logging

# Check metrics endpoint
curl http://localhost:2020/api/v1/metrics
```

## Step 6: Configure Kibana Index Patterns
1. Access Kibana UI at http://localhost:5601
2. Go to **Stack Management** > **Index Patterns**
3. Click **Create index pattern**
4. Enter index pattern: `logstash-*`
5. Select time field: `@timestamp`
6. Click **Create index pattern**

### 6.2 View Logs
1. Go to **Discover** in Kibana
2. Select your `logstash-*` index pattern
3. View logs from all pods in your cluster

## Step 7: Test Log Generation

### 7.1 Deploy Test Application
```bash
# Create a test pod that generates logs
kubectl run log-generator --image=busybox --restart=Never -- /bin/sh -c "
for i in \$(seq 1 1000); do
  echo \"[\$(date)] Test log message \$i - This is a sample log entry\"
  sleep 2
done"

# Check logs are being generated
kubectl logs log-generator --follow
```

### 7.2 Deploy Sample Web Application
```yaml
# sample-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-web-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sample-web-app
  template:
    metadata:
      labels:
        app: sample-web-app
    spec:
      containers:
      - name: web-app
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-logs
          mountPath: /var/log/nginx
      volumes:
      - name: nginx-logs
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: sample-web-app-service
  namespace: default
spec:
  selector:
    app: sample-web-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

```bash
# Deploy sample application
kubectl apply -f sample-app.yaml

# Generate some web traffic
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  /bin/sh -c "while true; do curl -s sample-web-app-service; sleep 5; done"
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Elasticsearch Pod Failing
```bash
# Check logs
kubectl logs elasticsearch-master-0 -n logging

# Common fix: Increase memory limits
helm upgrade elasticsearch elastic/elasticsearch \
  --namespace logging \
  --reuse-values \
  --set resources.limits.memory=3Gi
```

#### 2. Kibana Cannot Connect to Elasticsearch
```bash
# Check Elasticsearch service
kubectl get svc elasticsearch-master -n logging

# Verify connectivity
kubectl exec -it kibana-xxx -n logging -- curl http://elasticsearch-master:9200
```

#### 3. No Logs Appearing in Kibana
```bash
# Check Fluent Bit logs
kubectl logs -l app.kubernetes.io/name=fluent-bit -n logging

# Check Elasticsearch indices
kubectl port-forward service/elasticsearch-master 9200:9200 -n logging &
curl http://localhost:9200/_cat/indices
```

#### 4. Resource Issues in Minikube
```bash
# Check resource usage
kubectl top pods -n logging

# Scale down if needed
helm upgrade fluent-bit fluent/fluent-bit \
  --namespace logging \
  --reuse-values \
  --set resources.limits.memory=128Mi
```

## Cleanup

### Remove EFK Stack
```bash
# Uninstall Helm releases
helm uninstall fluent-bit -n logging
helm uninstall kibana -n logging
helm uninstall elasticsearch -n logging

# Delete namespace
kubectl delete namespace logging

# Delete persistent volumes (if needed)
kubectl delete pv --all
```

## Production Considerations

For production environments, consider:
- **Enable security** (X-Pack, TLS, authentication)
- **Increase resources** based on log volume
- **Configure backup** and disaster recovery
- **Set up monitoring** and alerting
- **Use ingress** instead of NodePort
- **Configure log retention** policies
- **Implement network policies** for security

## Helm Chart Versions Used
- **Elasticsearch**: 7.17.3
- **Kibana**: 7.17.3  
- **Fluent Bit**: Latest from fluent/fluent-bit repository

This deployment provides a fully functional EFK stack optimized for Minikube development environments.