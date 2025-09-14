# Strimzi Kafka Helm Chart

A comprehensive, production-ready Helm chart for deploying Apache Kafka clusters using the [Strimzi Kafka Operator](https://strimzi.io/) on Kubernetes. This chart provides extensive parameterization and supports multiple environments with flexible configuration options.

## 🚀 Features

### Core Capabilities
- **Multi-Environment Support**: Dedicated configurations for `nonprod`, `staging`, and `prod` environments
- **Flexible Kafka Versions**: Support for Kafka 3.8.0, 3.9.0, and newer versions
- **KRaft Mode Only**: Modern ZooKeeper-less Kafka deployment (ZooKeeper is deprecated)
- **Flexible Node Roles**: Support for Controller, Broker, or Dual-role nodes per [Strimzi KRaft docs](https://strimzi.io/docs/operators/latest/deploying#assembly-kraft-mode-str)
- **Dynamic Scaling**: Optional Horizontal Pod Autoscaler (HPA) support
- **Flexible Listener Configuration**: List-based approach supporting unlimited listeners with different types, ports, and authentication

### Advanced Features
- **Storage Flexibility**: Configurable persistent storage with optional storage classes
- **Node Scheduling**: Comprehensive affinity and toleration support for EKS nodegroups
- **Security**: TLS encryption, SCRAM-SHA-512 authentication, and ACL-based authorization
- **Monitoring**: Built-in JMX Prometheus Exporter metrics for Kafka, Cruise Control, and Connect
- **Large Message Support**: Pre-configured for handling messages up to 10MB
- **Auto-Rebalancing**: Cruise Control integration with customizable rebalancing goals

### Operational Excellence
- **External DNS Integration**: Automatic DNS record management for external listeners
- **Rack Awareness**: Multi-AZ deployment support
- **Resource Management**: Configurable CPU and memory limits/requests
- **Pod Disruption Budgets**: Built-in availability protection
- **Comprehensive Testing**: Helm tests for connectivity validation

## 📋 Prerequisites

- Kubernetes 1.21+
- Helm 3.8+
- [Strimzi Kafka Operator](https://strimzi.io/docs/operators/latest/deploying) installed in your cluster
- For external listeners: Ingress controller (e.g., NGINX) and ExternalDNS (optional)
- For EKS: Appropriate nodegroups with taints/labels configured

## 🛠️ Installation

### Quick Start

1. **Add the Helm repository** (if using a repository):
   ```bash
   helm repo add strimzi-kafka /path/to/chart
   helm repo update
   ```

2. **Install with default values**:
   ```bash
   helm install my-kafka strimzi-kafka/strimzi-kafka -n kafka-system --create-namespace
   ```

3. **Install for specific environment**:
   ```bash
   # Non-production (release name: kafka-nonprod, namespace: om-kafka)
   helm install kafka-nonprod . -f values-nonprod.yaml -n om-kafka --create-namespace
   
   # Staging (release name: kafka-staging, namespace: om-kafka-staging)
   helm install kafka-staging . -f values-staging.yaml -n om-kafka-staging --create-namespace
   
   # Production (release name: kafka-prod, namespace: om-kafka-prod)
   helm install kafka-prod . -f values-prod.yaml -n om-kafka-prod --create-namespace
   ```

### Using the Deployment Script

For easier multi-environment deployment, use the provided script:

```bash
# Make the script executable
chmod +x scripts/deploy.sh

# Deploy to different environments
./scripts/deploy.sh nonprod om-kafka kafka-nonprod
./scripts/deploy.sh staging om-kafka-staging kafka-staging
./scripts/deploy.sh prod om-kafka-prod kafka-prod
```

## 🎯 Flexible Naming Configuration

This Helm chart provides **flexible naming** with sensible defaults that follow Helm best practices:

### 🏷️ **Default Behavior (Recommended)**
- **Cluster Name**: Defaults to `{{ .Release.Name }}` (your Helm release name)
- **Namespace**: Defaults to `{{ .Release.Namespace }}` (your deployment namespace)
- **Node Pools**: Prefixed with cluster name (e.g., `my-kafka-dual-role`)
- **Secrets**: Prefixed with cluster name (e.g., `my-kafka-kafka-tls-secret`)

### 🔧 **Override Options**
```yaml
kafkaCluster:
  name: "my-custom-kafka"        # Override cluster name
  namespace: "custom-namespace"  # Override namespace
  nodePools:
    - name: "custom-dual-role"   # Will become: my-custom-kafka-custom-dual-role
```

### ✅ **Benefits**
- **🎯 Flexible**: Override names when needed for specific requirements
- **📏 Consistent**: Follows Helm conventions by default
- **🔍 Predictable**: Resource names are clearly prefixed and organized
- **🚀 Simple**: Works out-of-the-box with sensible defaults  

### Example:
```bash
# This creates a Kafka cluster named "my-kafka" in namespace "kafka-system"
helm install my-kafka . -n kafka-system --create-namespace
```

## ⚙️ Configuration

### Core Parameters

| Parameter | Description | Default | Environment Specific |
|-----------|-------------|---------|---------------------|
| `kafkaCluster.version` | Kafka version | `3.9.0` | ✅ |
| `kafkaCluster.replicas` | Number of Kafka brokers | `3` | ✅ |

**Note**: 
- The chart uses **Helm built-in variables** for naming: `{{ .Release.Name }}` for cluster name and `{{ .Release.Namespace }}` for namespace
- Deploy to the desired namespace using `helm install --namespace <namespace> <release-name>`
- The release name becomes your Kafka cluster name automatically

## 🐳 Docker Image Configuration

The chart provides comprehensive image configuration options for all Strimzi components, supporting both public and private registries with flexible override capabilities.

### Global Image Defaults

Set default image settings that apply to all components unless overridden:

```yaml
global:
  # Default Image Configuration
  defaultImageRegistry: "quay.io"              # Default: quay.io
  defaultImageRepository: "strimzi"            # Default: strimzi  
  defaultImageTag: "0.47.0-kafka-3.9.0"      # Strimzi version with Kafka version
  
  # Global Image Pull Configuration
  imagePullPolicy: "IfNotPresent"             # Always, Never, IfNotPresent
  imagePullSecrets:                           # Global pull secrets
    - name: "private-registry-secret"
    - name: "ecr-registry-secret"
```

### Component-Specific Image Overrides

Override image settings for specific components:

```yaml
# Strimzi Operator Image Configuration
strimzi:
  operator:
    image:
      registry: "my-registry.com"             # Override global registry
      repository: "custom-strimzi"           # Override global repository
      name: "operator"                       # Operator image name
      tag: "0.47.0-custom"                  # Override global tag
      pullPolicy: "Always"                   # Override global pull policy
      pullSecrets:                          # Additional component secrets
        - name: "operator-registry-secret"

# Kafka Cluster Image Configuration  
kafkaCluster:
  image:
    registry: ""                            # Empty = use global default
    repository: ""                          # Empty = use global default
    tag: ""                                # Empty = use global default
    pullPolicy: ""                         # Empty = use global default
    pullSecrets: []                        # Additional Kafka secrets

# Kafka Connect Image Configuration
kafkaConnects:
  - name: my-connect-cluster
    image:
      registry: "my-registry.com"
      repository: "custom-kafka"
      name: "kafka-connect"                 # Connect image name
      tag: "3.9.0-custom"
      pullPolicy: "Always"
      pullSecrets:
        - name: "connect-registry-secret"
```

### Environment-Specific Examples

#### Non-Production (Public Registry)
```yaml
global:
  defaultImageRegistry: "quay.io"
  defaultImageRepository: "strimzi"
  defaultImageTag: "0.47.0-kafka-3.9.0"
  imagePullPolicy: "IfNotPresent"
  imagePullSecrets: []  # No secrets for public registry
```

#### Production (Private ECR Registry)
```yaml
global:
  defaultImageRegistry: "123456789012.dkr.ecr.us-east-1.amazonaws.com"
  defaultImageRepository: "strimzi"
  defaultImageTag: "0.47.0-kafka-3.9.0"
  imagePullPolicy: "Always"  # Always pull latest for production
  imagePullSecrets:
    - name: "ecr-registry-secret"
```

### Image Pull Secrets Setup

For private registries, create image pull secrets:

```bash
# For ECR (AWS)
kubectl create secret docker-registry ecr-registry-secret \
  --docker-server=123456789012.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1) \
  --namespace=kafka-system

# For Docker Hub
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=docker.io \
  --docker-username=myusername \
  --docker-password=mypassword \
  --namespace=kafka-system

# For Harbor/Custom Registry  
kubectl create secret docker-registry harbor-secret \
  --docker-server=harbor.company.com \
  --docker-username=myusername \
  --docker-password=mypassword \
  --namespace=kafka-system
```

## Kubernetes-style Ingress Configuration

The chart supports modern Kubernetes-style ingress configuration with optional annotations and flexible TLS settings. This provides better control over ingress resources and follows Kubernetes best practices.

### Ingress Configuration Options

```yaml
kafkaCluster:
  listeners:
    external:
      ingress:
        # Ingress class name (required)
        className: "nginx"  # or "alb", "traefik", etc.
        
        # Ingress host (required)
        host: "kafka.example.com"
        
        # Optional annotations - if {} then disabled/not required
        annotations:
          external-dns.alpha.kubernetes.io/hostname: "kafka.example.com"
          external-dns.alpha.kubernetes.io/ttl: "60"
          nginx.ingress.kubernetes.io/ssl-redirect: "true"
          cert-manager.io/cluster-issuer: "letsencrypt-prod"
        
        # TLS Configuration
        tls:
          enabled: true  # true or false
          secretName: "kafka-tls-secret"  # optional - auto-generated if not specified
      
      # Broker configuration - inherits className, annotations, and TLS from parent
      brokers:
        # Host pattern: broker-{broker}-{parent.host} (e.g., broker-0-kafka.example.com)
        # Brokers automatically inherit all parent ingress settings
        hostPattern: "broker-{broker}-kafka.example.com"  # Optional override
```

### Environment-Specific Examples

**Non-Production**: Simplified setup with TLS disabled
```yaml
kafkaCluster:
  listeners:
    external:
      ingress:
        className: "nginx"
        host: "kafka.dev.example.com"
        annotations:
          external-dns.alpha.kubernetes.io/hostname: "kafka.dev.example.com"
        tls:
          enabled: false  # Simplified for development
      brokers:
        # Brokers inherit all settings from parent
        # Host pattern: broker-0-kafka.dev.example.com, broker-1-kafka.dev.example.com, etc.
```

**Production**: Full security with TLS and cert-manager
```yaml
kafkaCluster:
  listeners:
    external:
      ingress:
        className: "nginx"
        host: "kafka.prod.example.com"
        annotations:
          external-dns.alpha.kubernetes.io/hostname: "kafka.prod.example.com"
          cert-manager.io/cluster-issuer: "letsencrypt-prod"
          nginx.ingress.kubernetes.io/ssl-redirect: "true"
          nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
        tls:
          enabled: true
          secretName: "kafka-prod-tls"
      brokers:
        # Brokers inherit all settings from parent including TLS and cert-manager
        # Host pattern: broker-0-kafka.prod.example.com, broker-1-kafka.prod.example.com, etc.
```

### Optional Annotations

Annotations are completely optional. If you set `annotations: {}` or omit the annotations section entirely, no annotations will be applied to the ingress resources. This provides maximum flexibility for different deployment scenarios.

### KRaft Node Roles Configuration

This chart supports **KRaft mode only** (ZooKeeper is deprecated). You can configure flexible node roles as per the [Strimzi KRaft documentation](https://strimzi.io/docs/operators/latest/deploying#assembly-kraft-mode-str):

#### Supported Node Roles

1. **Controller**: Manages cluster metadata and leader elections
2. **Broker**: Handles client requests and data storage  
3. **Dual-role**: Both controller and broker functions (suitable for dev/test)

#### Configuration Examples

**Development/Testing - Dual-role nodes:**
```yaml
kafkaCluster:
  nodePools:
    - name: "kafka-dual-role"
      replicas: 3  # Minimum for KRaft quorum
      roles:
        - broker
        - controller
```

**Production - Dedicated roles (recommended):**
```yaml
kafkaCluster:
  nodePools:
    # Dedicated controllers for metadata management
    - name: "kafka-controllers"
      replicas: 3  # Odd number for quorum (3 or 5)
      roles:
        - controller
      resources:
        requests:
          memory: "2Gi"
          cpu: "500m"
    
    # Dedicated brokers for client traffic
    - name: "kafka-brokers"
      replicas: 6  # Scale based on throughput needs
      roles:
        - broker
      resources:
        requests:
          memory: "8Gi"
          cpu: "2000m"
```

#### Environment-Specific Patterns

- **Non-Production**: Dual-role nodes for cost efficiency
- **Staging**: Mixed setup to test production patterns
- **Production**: Dedicated roles for optimal performance and isolation

### Global Node Selection, Affinity and Tolerations

The chart supports flexible node selection through both simple `nodeSelector` and advanced `affinity` configurations, plus tolerations that apply to all Kafka components (brokers, entity operator, Kafka exporter, Cruise Control) unless explicitly overridden at the component level.

#### 🎯 **Global Override System**

**Key Benefits:**
- ✅ **DRY Principle**: Configure once, apply everywhere
- ✅ **Consistent Scheduling**: All components use same node selection by default  
- ✅ **Easy Management**: Change global settings to affect all components
- ✅ **Selective Override**: Override only specific components when needed

**How it Works:**
1. **Global Configuration**: Set `global.nodeSelector`, `global.affinity`, `global.tolerations`
2. **Automatic Inheritance**: All Kafka components inherit these settings
3. **Component Override**: Override at component level only when different behavior is needed

#### ✨ **Before vs After Example**

**❌ Before (Repetitive):**
```yaml
# Repeated in every component - hard to maintain!
kafkaCluster:
  nodePools:
    - template:
        pod:
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                  - matchExpressions:
                      - key: eks.amazonaws.com/nodegroup
                        operator: In
                        values: ["kafka-nodes"]
entityOperator:
  template:
    pod:
      affinity: # Same config repeated again!
        nodeAffinity: # ... 15 lines of duplicate config
cruiseControl:
  template:
    pod:
      affinity: # Same config repeated again!
        nodeAffinity: # ... 15 lines of duplicate config
```

**✅ After (Clean & DRY):**
```yaml
# Configure once globally
global:
  nodeSelector:
    eks.amazonaws.com/nodegroup: "kafka-nodes"

# All components automatically inherit - no repetition!
kafkaCluster:
  nodePools:
    - template:
        pod:
          affinity: {} # Inherits from global
entityOperator:
  template:
    pod:
      affinity: {} # Inherits from global
cruiseControl:
  template:
    pod:
      affinity: {} # Inherits from global

# Override only when needed
kafkaExporter:
  template:
    pod:
      nodeSelector:
        special-node: "monitoring" # Override for this component only
```

### Node Selection Options

**Simple Node Selection (Recommended)**:
Use `nodeSelector` for straightforward node targeting:

```yaml
global:
  nodeSelector:
    eks.amazonaws.com/nodegroup: "kafka-nodegroup"
    node-type: "kafka-dedicated"
    kubernetes.io/arch: "amd64"
```

**Advanced Node Selection**:
Use `affinity.nodeAffinity` for complex node selection logic:

```yaml
global:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: eks.amazonaws.com/nodegroup
                operator: In
                values:
                  - "kafka-nodegroup-1"
                  - "kafka-nodegroup-2"
```

#### Global Configuration

```yaml
global:
  # Global Affinity Configuration (applied to all components unless overridden)
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: eks.amazonaws.com/nodegroup
                operator: In
                values:
                  - "kafka-nodegroup"
              - key: node-type
                operator: In
                values:
                  - "kafka-dedicated"
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: strimzi.io/cluster
                operator: In
                values:
                  - "{{ .Values.global.clusterName }}"
          topologyKey: kubernetes.io/hostname
  
  # Global Tolerations Configuration (applied to all components unless overridden)
  tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "kafka"
      effect: "NoSchedule"
    - key: "identifier"
      operator: "Equal"
      value: "kafka-nodegroup-taint"
      effect: "NoSchedule"
```

#### Component-Level Overrides

Individual components can override global affinity and tolerations:

```yaml
kafkaCluster:
  nodePools:
    - template:
        pod:
          # Override global affinity for this node pool
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                  - matchExpressions:
                      - key: node-type
                        operator: In
                        values:
                          - "kafka-broker-only"
          # Override global tolerations for this node pool
          tolerations:
            - key: "broker-dedicated"
              operator: "Equal"
              value: "true"
              effect: "NoSchedule"
  
  entityOperator:
    template:
      pod:
        # Entity operator can have different affinity/tolerations
        affinity:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
                - matchExpressions:
                    - key: node-type
                      operator: In
                      values:
                        - "kafka-management"
```

#### Environment-Specific Examples

**Non-Production**: Basic node affinity, no pod anti-affinity
```yaml
global:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: eks.amazonaws.com/nodegroup
                operator: In
                values:
                  - "dev-nodegroup"
  tolerations:
    - key: "dev-taint"
      operator: "Equal"
      value: "kafka"
      effect: "NoSchedule"
```

**Production**: Strict node affinity and pod anti-affinity
```yaml
global:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: eks.amazonaws.com/nodegroup
                operator: In
                values:
                  - "kafka-dedicated-nodegroup"
              - key: node-type
                operator: In
                values:
                  - "kafka-dedicated"
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:  # Hard anti-affinity for production
        - labelSelector:
            matchExpressions:
              - key: strimzi.io/cluster
                operator: In
                values:
                  - "kafka-cluster-prod"
          topologyKey: kubernetes.io/hostname
  tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "kafka"
      effect: "NoSchedule"
```

### Storage Configuration

```yaml
kafkaCluster:
  nodePools:
    - storage:
        enabled: true
        type: jbod  # or persistent-claim
        volumes:
          - id: 1
            type: persistent-claim
            size: 100Gi  # Configurable per environment
            deleteClaim: false
            kraftMetadata: shared
            storageClass: gp3  # Optional: specify storage class
```

### 🎧 Flexible Listener Configuration

The chart now supports **flexible list-based listeners** - add as many listeners as needed with different configurations:

#### **Basic Example**
```yaml
kafkaCluster:
  listeners:
    # Internal TLS listener (always recommended)
    - name: "tls"
      port: 9093
      type: internal
      tls: true
      authentication:
        type: tls
    
    # External ingress listener
    - name: "external"
      port: 9095
      type: ingress
      tls: true
      authentication:
        type: scram-sha-512
      configuration:
        class: "nginx"
        bootstrap:
          host: "kafka.example.com"
          annotations:
            external-dns.alpha.kubernetes.io/hostname: "kafka.example.com"
        brokers:
          hostTemplate: "kafka-{id}.example.com"
          annotations:
            external-dns.alpha.kubernetes.io/hostname: "kafka-{id}.example.com"
        tls:
          secretName: "kafka-tls-secret"
          brokerSecretName: "kafka-broker-tls"
```

#### **Advanced Multi-Listener Example**
```yaml
kafkaCluster:
  listeners:
    # Internal TLS for inter-broker communication
    - name: "tls"
      port: 9093
      type: internal
      tls: true
      authentication:
        type: tls
    
    # Internal SCRAM for applications
    - name: "scram"
      port: 9094
      type: internal
      tls: true
      authentication:
        type: scram-sha-512
    
    # External ingress for web clients
    - name: "web-clients"
      port: 9095
      type: ingress
      tls: true
      authentication:
        type: scram-sha-512
      configuration:
        class: "nginx"
        bootstrap:
          host: "kafka-web.example.com"
        brokers:
          hostTemplate: "kafka-web-{id}.example.com"
    
    # External LoadBalancer for internal services
    - name: "internal-services"
      port: 9096
      type: loadbalancer
      tls: true
      authentication:
        type: tls
      configuration:
        loadBalancerSourceRanges:
          - "10.0.0.0/8"
          - "172.16.0.0/12"
    
    # NodePort for development access
    - name: "dev-access"
      port: 9097
      type: nodeport
      tls: false
      authentication:
        type: scram-sha-512
      configuration:
        nodePort: 32000
```

#### **✅ Benefits of List-Based Listeners**
- **🔧 Unlimited Flexibility**: Add any number of listeners with different configurations
- **🎯 Purpose-Specific**: Create listeners for different client types (web, mobile, internal services)
- **🔒 Security Granular**: Different authentication methods per listener
- **🌐 Multi-Environment**: Different ingress hosts and TLS configurations per listener
- **📈 Scalable**: Easy to add new listeners without restructuring existing ones

### Node Affinity and Tolerations

Configure pod scheduling for EKS nodegroups:

```yaml
kafkaCluster:
  nodePools:
    - template:
        pod:
          affinity:
            enabled: true
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                  - matchExpressions:
                      - key: eks.amazonaws.com/nodegroup
                        operator: In
                        values:
                          - "kafka-nodegroup"
            podAntiAffinity:
              enabled: true  # Recommended for production
          tolerations:
            enabled: true
            tolerations:
              - key: "kafka-dedicated"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
```

### Horizontal Pod Autoscaler (HPA)

Enable automatic scaling based on CPU/memory metrics:

```yaml
hpa:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
  scaleUpPeriodSeconds: 300
  scaleDownPeriodSeconds: 300
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

When HPA is enabled, external listener brokers are automatically generated up to `maxReplicas`.

### Metrics Configuration

Enable comprehensive monitoring with JMX Prometheus Exporter:

```yaml
kafkaCluster:
  metricsConfig:
    enabled: true
    type: jmxPrometheusExporter
    configMapName: kafka-metrics
    configMapKey: kafka-metrics-config.yml
  
  kafkaExporter:
    enabled: true  # Additional Kafka-specific metrics
  
  cruiseControl:
    enabled: true
    metricsConfig:
      enabled: true
      type: jmxPrometheusExporter
      configMapName: cruise-control-metrics
      configMapKey: metrics-config.yml
```

### Kafka Users and Topics

Define users and topics declaratively:

```yaml
kafkaUsers:
  - name: app-user
    authentication:
      type: scram-sha-512
    authorization:
      type: simple
      acls:
        - resource:
            type: topic
            name: "app-*"
            patternType: prefix
          operations: [Describe, Read, Write]
          host: "*"

kafkaTopics:
  - name: user-events
    partitions: 12
    replicas: 3
    config:
      retention.ms: 604800000  # 7 days
      segment.bytes: 1073741824
      compression.type: lz4
```

### Kafka Connect

Deploy Kafka Connect clusters with custom connectors:

```yaml
kafkaConnects:
  - name: analytics-connect
    replicas: 3
    version: "3.9.0"
    resources:
      requests:
        memory: 4Gi
        cpu: 2
      limits:
        memory: 4Gi
        cpu: 4
    bootstrapServers: "kafka.example.com:443"
    build:
      output:
        type: docker
        image: "registry.example.com/kafka-connect:latest"
      plugins:
        - name: opensearch-sink
          artifacts:
            - type: zip
              url: "https://github.com/Aiven-Open/opensearch-connector-for-apache-kafka/releases/download/v3.1.1/opensearch-connector-for-apache-kafka-3.1.1.zip"
```

### Rebalancing Configuration

Configure automatic rebalancing with Cruise Control:

```yaml
kafkaCluster:
  cruiseControl:
    enabled: true
    autoRebalance:
      enabled: true
      modes:
        - mode: add-brokers
          templateName: "my-rebalance-template"
        - mode: remove-brokers
          templateName: "my-rebalance-template"

kafkaRebalances:
  - name: my-rebalance-template
    goals:
      - ReplicaCapacityGoal
      - DiskCapacityGoal
      - ReplicaDistributionGoal
      - DiskUsageDistributionGoal
      - TopicReplicaDistributionGoal
      - LeaderReplicaDistributionGoal
      - LeaderBytesInDistributionGoal
```

## 🌍 Multi-Environment Deployment

### Environment-Specific Configurations

The chart includes pre-configured values for different environments:

#### Non-Production (`values-nonprod.yaml`)
- 3 replicas
- 4Gi memory per broker
- 100Gi storage per broker
- 1-hour log retention
- HPA disabled
- Basic monitoring

#### Staging (`values-staging.yaml`)
- 3 replicas (HPA: 3-8)
- 6Gi memory per broker
- 200Gi storage per broker
- 24-hour log retention
- HPA enabled
- Pod anti-affinity enabled
- Enhanced monitoring

#### Production (`values-prod.yaml`)
- 5 replicas (HPA: 5-15)
- 8Gi memory per broker
- 500Gi storage per broker
- 7-day log retention
- HPA enabled with conservative scaling
- Pod anti-affinity enforced
- Comprehensive monitoring
- Multiple Connect clusters
- Enhanced security settings

### Deployment Examples

```bash
# Deploy to non-production (cluster name: kafka-nonprod)
helm install kafka-nonprod . \
  -f values-nonprod.yaml \
  -n om-kafka \
  --create-namespace

# Deploy to staging with custom overrides (cluster name: kafka-staging)
helm install kafka-staging . \
  -f values-staging.yaml \
  --set kafkaCluster.replicas=4 \
  --set hpa.maxReplicas=10 \
  -n om-kafka-staging \
  --create-namespace

# Deploy to production with additional security (cluster name: kafka-prod)
helm install kafka-prod . \
  -f values-prod.yaml \
  --set kafkaCluster.config.auto.create.topics.enable=false \
  --set kafkaCluster.authorization.type=simple \
  -n om-kafka-prod \
  --create-namespace
```

## 🧪 Testing

### Helm Tests

Run built-in connectivity tests:

```bash
# Test the deployment
helm test kafka-nonprod -n om-kafka

# View test logs
kubectl logs -n om-kafka kafka-nonprod-test-kafka-connection
```

### Manual Testing

1. **Create a test producer**:
   ```bash
   kubectl run kafka-producer -ti --image=quay.io/strimzi/kafka:0.41.0-kafka-3.9.0 --rm=true --restart=Never -- bin/kafka-console-producer.sh --bootstrap-server om-kafka-cluster-kafka-bootstrap:9092 --topic test-topic
   ```

2. **Create a test consumer**:
   ```bash
   kubectl run kafka-consumer -ti --image=quay.io/strimzi/kafka:0.41.0-kafka-3.9.0 --rm=true --restart=Never -- bin/kafka-console-consumer.sh --bootstrap-server om-kafka-cluster-kafka-bootstrap:9092 --topic test-topic --from-beginning
   ```

## 📊 Monitoring

### Metrics Collection

The chart automatically configures JMX Prometheus Exporter for:

- **Kafka Brokers**: Core Kafka metrics, JVM metrics, and custom business metrics
- **Cruise Control**: Rebalancing and optimization metrics
- **Kafka Connect**: Connector performance and health metrics
- **Kafka Exporter**: Additional Kafka-specific metrics

### Grafana Dashboards

Import the provided Grafana dashboards:

```bash
# Import Kafka cluster health dashboard
kubectl apply -f grafana/kafka-cluster-health.json

# Import Zookeeper dashboard (if using ZooKeeper mode)
kubectl apply -f grafana/zookeeper.json
```

### Prometheus Configuration

Add the following to your Prometheus configuration:

```yaml
scrape_configs:
  - job_name: 'kafka'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
```

## 🔧 Troubleshooting

### Common Issues

1. **Pods stuck in Pending state**:
   - Check node affinity and tolerations
   - Verify nodegroup labels and taints
   - Ensure sufficient resources in the cluster

2. **External listeners not accessible**:
   - Verify ingress controller is running
   - Check DNS resolution for broker hosts
   - Validate TLS certificates

3. **Storage issues**:
   - Verify storage class exists
   - Check PVC creation and binding
   - Ensure sufficient storage quota

4. **Authentication failures**:
   - Verify user secrets are created
   - Check ACL configurations
   - Validate certificate trust chains

### Debug Commands

```bash
# Check Kafka cluster status
kubectl get kafka -n om-kafka

# View Kafka cluster details
kubectl describe kafka om-kafka-cluster -n om-kafka

# Check pod logs
kubectl logs -n om-kafka om-kafka-cluster-kafka-0

# View Strimzi operator logs
kubectl logs -n strimzi-operator deployment/strimzi-cluster-operator

# Check external DNS records
kubectl logs -n external-dns deployment/external-dns
```

### Performance Tuning

For production workloads, consider these optimizations:

1. **JVM Tuning**:
   ```yaml
   jvmOptions:
     xms: "4g"
     xmx: "4g"
     additionalOptions:
       - "-XX:+UseG1GC"
       - "-XX:MaxGCPauseMillis=20"
       - "-XX:InitiatingHeapOccupancyPercent=35"
   ```

2. **Kafka Configuration**:
   ```yaml
   config:
     num.io.threads: 16
     num.network.threads: 8
     socket.send.buffer.bytes: 102400
     socket.receive.buffer.bytes: 102400
     socket.request.max.bytes: 104857600
     num.replica.fetchers: 4
   ```

3. **Storage Optimization**:
   ```yaml
   storage:
     type: jbod
     volumes:
       - type: persistent-claim
         size: 1000Gi
         class: io1  # High IOPS storage class
   ```

## 🔄 Upgrading

### Kafka Version Upgrade

1. **Update the chart values**:
   ```yaml
   kafkaCluster:
     version: "3.9.0"  # New version
   ```

2. **Apply the upgrade**:
   ```bash
   helm upgrade kafka-nonprod . -f values-nonprod.yaml -n om-kafka
   ```

3. **Monitor the rolling update**:
   ```bash
   kubectl get pods -n om-kafka -w
   ```

### Chart Upgrade

```bash
# Upgrade to a new chart version
helm upgrade kafka-nonprod . -f values-nonprod.yaml -n om-kafka

# Rollback if needed
helm rollback kafka-nonprod 1 -n om-kafka
```

## 🗑️ Uninstallation

```bash
# Uninstall the Helm release
helm uninstall kafka-nonprod -n om-kafka

# Clean up persistent volumes (if needed)
kubectl delete pvc -l strimzi.io/cluster=om-kafka-cluster -n om-kafka

# Remove the namespace
kubectl delete namespace om-kafka
```

## 📚 Additional Resources

- [Strimzi Documentation](https://strimzi.io/docs/operators/latest/deploying)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📊 Metrics Configuration

The chart provides flexible metrics configuration through conditional ConfigMaps that are created only when needed, eliminating unnecessary overhead and keeping your `values.yaml` clean.

### 🎯 **Dynamic ConfigMap Creation**

Instead of hardcoding 160+ lines of metrics configuration in `values.yaml`, ConfigMaps are now created dynamically based on your metrics requirements:

```yaml
# Optional standalone metrics configurations
kafkaMetrics:
  enabled: true                    # Create Kafka JMX metrics ConfigMap
  configMapName: kafka-metrics
  configMapKey: kafka-metrics-config.yml

cruiseControlMetrics:
  enabled: true                    # Create Cruise Control metrics ConfigMap
  configMapName: cruise-control-metrics
  configMapKey: cruise-control-metrics-config.yml

```

### ✅ **Benefits**

- **🎯 Conditional Creation**: ConfigMaps are created only when `enabled: true`
- **📦 Reduced Overhead**: No hardcoded metrics configuration in values.yaml
- **🔧 Flexible Configuration**: Enable only the metrics you need
- **📊 Default Configurations**: Production-ready JMX Prometheus Exporter patterns included
- **🚀 Easy Management**: Simple enable/disable per metrics type

### 📈 **Available Metrics Types**

| Metrics Type | Purpose | Default Enabled |
|--------------|---------|-----------------|
| `kafkaMetrics` | Kafka broker JMX metrics with comprehensive patterns | ✅ |
| `cruiseControlMetrics` | Cruise Control rebalancing metrics | ✅ |

**Note**: Kafka Exporter has built-in metrics collection and doesn't require a separate ConfigMap.

### 🔗 **Integration with Components**

The metrics ConfigMaps automatically integrate with their respective components:

```yaml
kafkaCluster:
  metricsConfig:
    enabled: true
    configMapName: kafka-metrics        # References kafkaMetrics ConfigMap
    configMapKey: kafka-metrics-config.yml

  cruiseControl:
    metricsConfig:
      enabled: true
      configMapName: cruise-control-metrics  # References cruiseControlMetrics ConfigMap
      configMapKey: cruise-control-metrics-config.yml
```

## 📄 License

This Helm chart is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

## 🆘 Support

For issues and questions:

1. Check the [troubleshooting section](#-troubleshooting)
2. Review [Strimzi documentation](https://strimzi.io/docs/)
3. Open an issue in the repository
4. Contact the maintainers

---

**Note**: This chart is designed for production use with comprehensive configuration options. Always test in a non-production environment before deploying to production.