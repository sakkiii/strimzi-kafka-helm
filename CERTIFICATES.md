# 🔐 Certificate Management Guide

This document provides comprehensive guidance for managing TLS certificates in Kafka clusters deployed with this Helm chart, covering different certificate strategies, rotation procedures, and security best practices.

## 📋 Table of Contents

- [Certificate Strategies Overview](#certificate-strategies-overview)
- [Strimzi CA (Default)](#strimzi-ca-default)
- [External Certificate Manager](#external-certificate-manager)
- [Custom CA Certificates](#custom-ca-certificates)
- [Certificate Rotation](#certificate-rotation)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)

## 🔍 Certificate Strategies Overview

Kafka clusters require TLS certificates for secure communication between brokers and clients. This chart supports multiple certificate management strategies:

| Strategy | Use Case | Complexity | Automation | External Dependencies |
|----------|----------|------------|------------|---------------------|
| **Strimzi CA** | Development, Testing | Low | High | None |
| **cert-manager** | Production, Kubernetes-native | Medium | High | cert-manager operator |
| **External CA** | Enterprise, Compliance | High | Low | External PKI |
| **Custom Certificates** | Legacy, Specific Requirements | High | Low | Manual management |

## 🏠 Strimzi CA (Default)

### Overview
Strimzi automatically generates and manages a Certificate Authority (CA) and all required certificates for the Kafka cluster.

### Configuration
```yaml
# values.yaml - Default configuration (no changes needed)
kafkaCluster:
  listeners:
    - name: tls
      port: 9093
      type: internal
      tls: true
      authentication:
        type: tls
```

### Advantages
- ✅ **Zero configuration** required
- ✅ **Automatic certificate generation** and renewal
- ✅ **Built-in rotation** capabilities
- ✅ **No external dependencies**

### Disadvantages
- ❌ **Self-signed certificates** (not trusted by external systems)
- ❌ **Limited customization** options
- ❌ **Cluster-scoped CA** (not organization-wide)

### Certificate Locations
```bash
# Cluster CA certificate (for client trust)
kubectl get secret my-kafka-cluster-cluster-ca-cert -o yaml

# Client CA certificate (for client authentication)
kubectl get secret my-kafka-cluster-clients-ca-cert -o yaml

# Broker certificates (automatically managed)
kubectl get secret my-kafka-cluster-kafka-brokers -o yaml
```

### Client Configuration Example
```bash
# Extract cluster CA certificate for client use
kubectl get secret my-kafka-cluster-cluster-ca-cert -o jsonpath='{.data.ca\.crt}' | base64 -d > cluster-ca.crt

# Use in client applications
kafka-console-producer.sh \
  --bootstrap-server my-kafka-cluster-kafka-bootstrap:9093 \
  --topic test-topic \
  --producer-property security.protocol=SSL \
  --producer-property ssl.truststore.location=cluster-ca.crt \
  --producer-property ssl.truststore.type=PEM
```

## 🎯 External Certificate Manager

### Overview
Integration with cert-manager for Kubernetes-native certificate management with support for various issuers (Let's Encrypt, private CA, etc.).

### Prerequisites
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Verify installation
kubectl get pods -n cert-manager
```

### Configuration

#### 1. Create ClusterIssuer
```yaml
# cluster-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: kafka-ca-issuer
spec:
  ca:
    secretName: kafka-ca-key-pair  # Your CA certificate and key
---
# For Let's Encrypt (production)
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@yourdomain.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

#### 2. Configure Kafka with cert-manager
```yaml
# values.yaml
kafkaCluster:
  listeners:
    - name: tls
      port: 9093
      type: internal
      tls: true
      authentication:
        type: tls
      configuration:
        brokerCertChainAndKey:
          secretName: kafka-broker-certs
          certificate: tls.crt
          key: tls.key
    
    - name: external
      port: 9095
      type: ingress
      tls: true
      authentication:
        type: tls
      configuration:
        class: nginx
        bootstrap:
          host: kafka.yourdomain.com
        brokers:
          hostTemplate: kafka-{id}.yourdomain.com
        # cert-manager integration
        tls:
          secretName: kafka-external-tls
        annotations:
          cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

#### 3. Create Certificate Resources
```yaml
# kafka-certificates.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: kafka-broker-certs
  namespace: kafka
spec:
  secretName: kafka-broker-certs
  issuerRef:
    name: kafka-ca-issuer
    kind: ClusterIssuer
  commonName: kafka-broker
  dnsNames:
  - "*.kafka.svc.cluster.local"
  - "kafka-bootstrap.kafka.svc.cluster.local"
  - "kafka-0.kafka.svc.cluster.local"
  - "kafka-1.kafka.svc.cluster.local"
  - "kafka-2.kafka.svc.cluster.local"
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: kafka-external-tls
  namespace: kafka
spec:
  secretName: kafka-external-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: kafka.yourdomain.com
  dnsNames:
  - kafka.yourdomain.com
  - kafka-0.yourdomain.com
  - kafka-1.yourdomain.com
  - kafka-2.yourdomain.com
```

### Advantages
- ✅ **Trusted certificates** (with proper issuers)
- ✅ **Automatic renewal** and rotation
- ✅ **Kubernetes-native** management
- ✅ **Multiple issuer support** (Let's Encrypt, private CA, etc.)

### Disadvantages
- ❌ **Additional complexity** and dependencies
- ❌ **cert-manager operator** required
- ❌ **DNS validation** may be required for some issuers

## 🏢 Custom CA Certificates

### Overview
Use your organization's existing Certificate Authority for enterprise compliance and integration.

### Configuration Steps

#### 1. Prepare CA Certificate and Key
```bash
# Your organization's CA certificate and key
# ca.crt - CA certificate (public)
# ca.key - CA private key (keep secure)

# Create Kubernetes secret with CA
kubectl create secret tls kafka-custom-ca \
  --cert=ca.crt \
  --key=ca.key \
  -n kafka
```

#### 2. Generate Broker Certificates
```bash
# Generate broker private key
openssl genrsa -out broker.key 2048

# Create certificate signing request
openssl req -new -key broker.key -out broker.csr -subj "/CN=kafka-broker" \
  -config <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[req_distinguished_name]
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = *.kafka.svc.cluster.local
DNS.2 = kafka-bootstrap.kafka.svc.cluster.local
DNS.3 = kafka-0.kafka.svc.cluster.local
DNS.4 = kafka-1.kafka.svc.cluster.local
DNS.5 = kafka-2.kafka.svc.cluster.local
EOF
)

# Sign certificate with your CA
openssl x509 -req -in broker.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out broker.crt -days 365 \
  -extensions v3_req -extfile <(cat <<EOF
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = *.kafka.svc.cluster.local
DNS.2 = kafka-bootstrap.kafka.svc.cluster.local
DNS.3 = kafka-0.kafka.svc.cluster.local
DNS.4 = kafka-1.kafka.svc.cluster.local
DNS.5 = kafka-2.kafka.svc.cluster.local
EOF
)

# Create Kubernetes secret with broker certificates
kubectl create secret tls kafka-broker-certs \
  --cert=broker.crt \
  --key=broker.key \
  -n kafka
```

#### 3. Configure Kafka Cluster
```yaml
# values.yaml
kafkaCluster:
  listeners:
    - name: tls
      port: 9093
      type: internal
      tls: true
      authentication:
        type: tls
      configuration:
        brokerCertChainAndKey:
          secretName: kafka-broker-certs
          certificate: tls.crt
          key: tls.key
        # Disable Strimzi CA
        generateCertificateAuthority: false
        # Use custom CA for client verification
        trustedCertificates:
          - secretName: kafka-custom-ca
            certificate: tls.crt
```

### Client Certificate Generation
```bash
# Generate client private key
openssl genrsa -out client.key 2048

# Create client certificate signing request
openssl req -new -key client.key -out client.csr \
  -subj "/CN=kafka-client"

# Sign client certificate with your CA
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out client.crt -days 365

# Create client keystore (for Java clients)
openssl pkcs12 -export -in client.crt -inkey client.key \
  -out client.p12 -name kafka-client -password pass:clientpass

# Create truststore with CA certificate
keytool -import -trustcacerts -alias kafka-ca -file ca.crt \
  -keystore truststore.jks -storepass trustpass -noprompt
```

## 🔄 Certificate Rotation

### Automatic Rotation (Strimzi CA)

Strimzi automatically rotates certificates based on configured intervals:

```yaml
# values.yaml - Configure rotation intervals
kafkaCluster:
  clusterCa:
    renewalDays: 30      # Renew 30 days before expiry
    validityDays: 365    # Certificate valid for 1 year
    generateCertificateAuthority: true
  clientsCa:
    renewalDays: 30
    validityDays: 365
    generateCertificateAuthority: true
```

### Manual Certificate Rotation

#### 1. Trigger CA Rotation
```bash
# Annotate Kafka resource to trigger CA rotation
kubectl annotate kafka my-kafka-cluster \
  strimzi.io/force-renew=ca-cert

# Monitor rotation progress
kubectl get kafka my-kafka-cluster -o yaml | grep -A 10 status
```

#### 2. Trigger Client Certificate Rotation
```bash
# Rotate client certificates
kubectl annotate kafka my-kafka-cluster \
  strimzi.io/force-renew=clients-ca-cert
```

#### 3. Monitor Rotation Status
```bash
# Check certificate expiration dates
kubectl get secret my-kafka-cluster-cluster-ca-cert -o yaml | \
  grep -A 1 'ca.crt:' | tail -1 | base64 -d | \
  openssl x509 -noout -dates

# Verify broker restart during rotation
kubectl get pods -l strimzi.io/cluster=my-kafka-cluster -w
```

### cert-manager Automatic Renewal

cert-manager automatically renews certificates before expiry:

```yaml
# Certificate with automatic renewal
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: kafka-broker-certs
spec:
  secretName: kafka-broker-certs
  duration: 2160h    # 90 days
  renewBefore: 360h  # Renew 15 days before expiry
  issuerRef:
    name: kafka-ca-issuer
    kind: ClusterIssuer
```

## 🛡️ Security Best Practices

### Certificate Security
- 🔐 **Use strong key sizes** (minimum 2048-bit RSA or 256-bit ECDSA)
- 🔄 **Regular rotation** (90 days or less for production)
- 🔒 **Secure key storage** (use Kubernetes secrets with proper RBAC)
- 📋 **Certificate monitoring** (track expiration dates)
- 🚫 **Revocation procedures** (maintain CRL or OCSP)

### Network Security
```yaml
# Enforce TLS on all listeners
kafkaCluster:
  listeners:
    - name: tls
      port: 9093
      type: internal
      tls: true                    # Always enable TLS
      authentication:
        type: tls                  # Require client certificates
    - name: external
      port: 9095
      type: ingress
      tls: true                    # Mandatory for external access
      authentication:
        type: tls
```

### Client Authentication
```yaml
# Configure client certificate authentication
kafkaUsers:
  - name: secure-client
    authentication:
      type: tls                    # Certificate-based auth
    authorization:
      type: simple
      acls:
        - resource:
            type: topic
            name: secure-topic
          operations: [Read, Write]
```

### Monitoring Certificate Health
```yaml
# Add certificate monitoring to ServiceMonitor
monitoring:
  serviceMonitor:
    enabled: true
    metricRelabelings:
      - sourceLabels: [__name__]
        regex: 'kafka_server_socket_server_metrics_connection_count'
        targetLabel: __name__
        replacement: 'kafka_tls_connections'
```

## 🔧 Troubleshooting

### Common Certificate Issues

#### 1. Certificate Validation Errors
```bash
# Check certificate details
kubectl get secret kafka-broker-certs -o yaml | \
  grep 'tls.crt:' | cut -d: -f2 | base64 -d | \
  openssl x509 -noout -text

# Verify certificate chain
openssl verify -CAfile ca.crt broker.crt
```

#### 2. Client Connection Failures
```bash
# Test TLS connection
openssl s_client -connect kafka-bootstrap:9093 -servername kafka-bootstrap

# Check client certificate
openssl x509 -in client.crt -noout -subject -issuer -dates
```

#### 3. Certificate Rotation Issues
```bash
# Check rotation status
kubectl describe kafka my-kafka-cluster | grep -A 20 "Certificate"

# Verify new certificates are generated
kubectl get secrets | grep kafka | grep -E "(ca-cert|certs)"
```

#### 4. Ingress TLS Problems
```bash
# Check ingress certificate
kubectl describe ingress my-kafka-cluster-kafka-external-bootstrap

# Verify cert-manager certificate status
kubectl describe certificate kafka-external-tls
```

### Debugging Commands

```bash
# List all certificate-related secrets
kubectl get secrets | grep -E "(ca|cert|tls)"

# Check certificate expiration dates
for secret in $(kubectl get secrets -o name | grep kafka); do
  echo "=== $secret ==="
  kubectl get $secret -o yaml | grep 'tls.crt:' | cut -d: -f2 | base64 -d | openssl x509 -noout -dates 2>/dev/null || echo "No certificate found"
done

# Monitor certificate rotation
kubectl get events --field-selector reason=CertificateRotation -w

# Check Strimzi operator logs for certificate issues
kubectl logs -n strimzi-operator deployment/strimzi-cluster-operator | grep -i cert
```

### Recovery Procedures

#### Emergency Certificate Replacement
```bash
# Backup current certificates
kubectl get secret kafka-broker-certs -o yaml > kafka-certs-backup.yaml

# Replace with new certificates
kubectl delete secret kafka-broker-certs
kubectl create secret tls kafka-broker-certs --cert=new-broker.crt --key=new-broker.key

# Restart Kafka pods to pick up new certificates
kubectl rollout restart statefulset/my-kafka-cluster-kafka
```

#### Reset to Strimzi CA
```yaml
# Remove custom certificate configuration
kafkaCluster:
  listeners:
    - name: tls
      port: 9093
      type: internal
      tls: true
      authentication:
        type: tls
      # Remove custom certificate configuration
      # configuration:
      #   brokerCertChainAndKey: ...
```

## 📚 Additional Resources

- **Strimzi TLS Documentation**: https://strimzi.io/docs/operators/latest/configuring.html#assembly-configuring-kafka-listeners-str
- **cert-manager Documentation**: https://cert-manager.io/docs/
- **OpenSSL Certificate Guide**: https://www.openssl.org/docs/man1.1.1/man1/openssl-x509.html
- **Kafka SSL Configuration**: https://kafka.apache.org/documentation/#security_ssl

---

> 💡 **Best Practice**: Always test certificate changes in a non-production environment first, and maintain proper certificate lifecycle management procedures.

> 🔐 **Security Note**: Never commit private keys to version control. Use Kubernetes secrets and proper RBAC for certificate management.
