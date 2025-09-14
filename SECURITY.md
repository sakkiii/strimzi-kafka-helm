# Strimzi Kafka Security Guide

This document provides comprehensive security guidance for deploying and configuring Kafka clusters using this Helm chart with production-grade security hardening.

## Table of Contents

- [Security Overview](#security-overview)
- [Authentication Strategies](#authentication-strategies)
- [Authorization & ACLs](#authorization--acls)
- [TLS Configuration](#tls-configuration)
- [Production Security Hardening](#production-security-hardening)
- [Security Configuration Examples](#security-configuration-examples)
- [KafkaUser Management](#kafkauser-management)
- [Security Monitoring](#security-monitoring)
- [Troubleshooting Security Issues](#troubleshooting-security-issues)
- [Security Checklist](#security-checklist)

## Security Overview

This Helm chart implements a **defense-in-depth security model** with multiple layers of protection:

1. **Transport Security**: TLS encryption for all communications
2. **Authentication**: Multiple authentication methods (TLS, SCRAM-SHA-512)
3. **Authorization**: Fine-grained ACL-based access control
4. **Network Security**: Listener isolation and ingress controls
5. **Configuration Security**: Hardened Kafka broker settings

### Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Security Layers                          │
├─────────────────────────────────────────────────────────────┤
│ 🔒 TLS Encryption (All Listeners)                          │
│ 🔐 Authentication (TLS Certs + SCRAM-SHA-512)              │
│ 🛡️  Authorization (ACL-based with Deny-by-Default)         │
│ 🌐 Network Security (Listener Isolation)                   │
│ ⚙️  Configuration Hardening (Secure Defaults)              │
└─────────────────────────────────────────────────────────────┘
```

## Authentication Strategies

### Supported Authentication Methods

#### 1. TLS Certificate Authentication
- **Use Case**: Internal services, admin users, high-security applications
- **Security Level**: Highest (mutual TLS)
- **Management**: Certificate lifecycle management required

```yaml
listeners:
  - name: "tls"
    port: 9093
    type: internal
    tls: true
    authentication:
      type: tls
```

#### 2. SCRAM-SHA-512 Authentication
- **Use Case**: Applications, external clients, user-based access
- **Security Level**: High (strong password hashing)
- **Management**: Username/password with secure storage

```yaml
listeners:
  - name: "scram"
    port: 9094
    type: internal
    tls: true
    authentication:
      type: scram-sha-512
```

### Authentication Best Practices

1. **Use TLS for Admin Access**: Always use certificate-based authentication for administrative users
2. **SCRAM for Applications**: Use SCRAM-SHA-512 for application-level access
3. **Strong Passwords**: Enforce strong password policies for SCRAM users
4. **Certificate Rotation**: Implement regular certificate rotation schedules
5. **Credential Management**: Use Kubernetes secrets for credential storage

## Authorization & ACLs

### ACL Model

This chart implements **deny-by-default authorization** with explicit ACL grants:

```yaml
config:
  allow.everyone.if.no.acl.found: false  # Deny by default
  authorizer.class.name: kafka.security.authorizer.AclAuthorizer
```

### ACL Pattern Types

#### 1. Literal Patterns
- **Use Case**: Specific topic/group access
- **Example**: `name: "user-events"`, `patternType: literal`

#### 2. Prefix Patterns
- **Use Case**: Scalable access to related resources
- **Example**: `name: "analytics-*"`, `patternType: prefix`

### Common ACL Patterns

#### Read-Only Consumer
```yaml
acls:
  # Topic read access
  - resource:
      type: topic
      name: "analytics-data"
      patternType: literal
    operations: [Describe, Read]
    host: "*"
  
  # Consumer group access
  - resource:
      type: group
      name: "analytics-consumers"
      patternType: literal
    operations: [Read]
    host: "*"
```

#### Producer with Topic Creation
```yaml
acls:
  # Topic write access
  - resource:
      type: topic
      name: "app-events"
      patternType: literal
    operations: [Create, Describe, Write]
    host: "*"
```

#### Service Account Pattern
```yaml
acls:
  # Prefix-based access for service
  - resource:
      type: topic
      name: "service-name-*"
      patternType: prefix
    operations: [Create, Describe, Read, Write]
    host: "*"
  
  - resource:
      type: group
      name: "service-name-*"
      patternType: prefix
    operations: [Read]
    host: "*"
```

## TLS Configuration

### TLS Security Levels

#### 1. TLS Encryption Only
```yaml
listeners:
  - name: "plain-tls"
    tls: true
    authentication: {}  # No authentication, just encryption
```

#### 2. TLS with Client Authentication
```yaml
listeners:
  - name: "mutual-tls"
    tls: true
    authentication:
      type: tls  # Requires client certificates
```

### Certificate Management Options

#### Option 1: Strimzi CA (Default)
- **Pros**: Automatic certificate generation and rotation
- **Cons**: Strimzi-specific, limited external integration
- **Use Case**: Internal clusters, development environments

#### Option 2: External CA (cert-manager)
- **Pros**: Integration with existing PKI, external trust chains
- **Cons**: Manual certificate management
- **Use Case**: Production environments, enterprise PKI integration

```yaml
# Example: Using cert-manager certificates
listeners:
  - name: "external"
    type: ingress
    tls: true
    configuration:
      tls:
        secretName: "kafka-tls-cert"  # cert-manager generated
```

### TLS Best Practices

1. **Always Enable TLS**: Never use plaintext listeners in production
2. **Strong Cipher Suites**: Configure secure TLS protocols
3. **Certificate Validation**: Ensure proper certificate chain validation
4. **Regular Rotation**: Implement certificate rotation policies

```yaml
config:
  ssl.enabled.protocols: TLSv1.3,TLSv1.2  # Only secure versions
  ssl.protocol: TLSv1.3                   # Prefer TLS 1.3
  ssl.client.auth: required               # Require client authentication
```

## Production Security Hardening

### Critical Security Settings

```yaml
config:
  # MANDATORY: Prevent unauthorized topic creation
  auto.create.topics.enable: false
  
  # MANDATORY: Require explicit ACLs
  allow.everyone.if.no.acl.found: false
  
  # MANDATORY: Require client authentication
  ssl.client.auth: required
  
  # MANDATORY: Prevent data loss
  unclean.leader.election.enable: false
  
  # Security: Define superusers explicitly
  super.users: User:CN=kafka-admin-prod;User:kafka-superuser-prod
```

### Replication & Durability

```yaml
config:
  # High availability and durability
  default.replication.factor: 5
  min.insync.replicas: 3
  offsets.topic.replication.factor: 5
  transaction.state.log.replication.factor: 5
  transaction.state.log.min.isr: 3
```

### Network Security

```yaml
listeners:
  # Internal secure communication
  - name: "tls"
    port: 9093
    type: internal
    tls: true
    authentication:
      type: tls
  
  # Application access with SCRAM
  - name: "scram"
    port: 9094
    type: internal
    tls: true
    authentication:
      type: scram-sha-512
  
  # External access (production ingress)
  - name: "external"
    port: 9095
    type: ingress
    tls: true
    authentication:
      type: scram-sha-512
    configuration:
      class: "nginx"
      annotations:
        nginx.ingress.kubernetes.io/ssl-redirect: "true"
        nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
```

## Security Configuration Examples

### Development Environment
```yaml
# values-dev.yaml
kafkaCluster:
  listeners:
    - name: "internal"
      port: 9092
      type: internal
      tls: false  # OK for development
      authentication: {}
  
  authorization:
    type: simple
    superUsers: []  # No restrictions in dev
  
  config:
    auto.create.topics.enable: true  # OK for development
    allow.everyone.if.no.acl.found: true
```

### Staging Environment
```yaml
# values-staging.yaml
kafkaCluster:
  listeners:
    - name: "tls"
      port: 9093
      type: internal
      tls: true
      authentication:
        type: tls
    
    - name: "scram"
      port: 9094
      type: internal
      tls: true
      authentication:
        type: scram-sha-512
  
  authorization:
    type: simple
    superUsers:
      - CN=kafka-admin-staging
  
  config:
    auto.create.topics.enable: false
    allow.everyone.if.no.acl.found: false
    ssl.client.auth: required
```

### Production Environment
```yaml
# values-prod.yaml - Full security hardening
kafkaCluster:
  listeners:
    - name: "tls"
      port: 9093
      type: internal
      tls: true
      authentication:
        type: tls
    
    - name: "scram"
      port: 9094
      type: internal
      tls: true
      authentication:
        type: scram-sha-512
    
    - name: "external"
      port: 9095
      type: ingress
      tls: true
      authentication:
        type: scram-sha-512
      configuration:
        class: "nginx"
        annotations:
          nginx.ingress.kubernetes.io/ssl-redirect: "true"
          cert-manager.io/cluster-issuer: "letsencrypt-prod"
  
  authorization:
    type: simple
    superUsers:
      - CN=kafka-admin-prod
      - kafka-superuser-prod
  
  config:
    auto.create.topics.enable: false
    allow.everyone.if.no.acl.found: false
    ssl.client.auth: required
    ssl.enabled.protocols: TLSv1.3,TLSv1.2
    ssl.protocol: TLSv1.3
    unclean.leader.election.enable: false
    default.replication.factor: 5
    min.insync.replicas: 3
```

## KafkaUser Management

### User Creation Patterns

#### 1. Application Service User
```yaml
kafkaUsers:
  - name: app-service-user
    authentication:
      type: scram-sha-512
    authorization:
      type: simple
      acls:
        # Read specific input topics
        - resource:
            type: topic
            name: "input-events"
            patternType: literal
          operations: [Describe, Read]
          host: "*"
        
        # Write to output topics
        - resource:
            type: topic
            name: "processed-events"
            patternType: literal
          operations: [Describe, Write]
          host: "*"
        
        # Consumer group access
        - resource:
            type: group
            name: "app-service-group"
            patternType: literal
          operations: [Read]
          host: "*"
```

#### 2. Analytics User (Read-Only)
```yaml
kafkaUsers:
  - name: analytics-user
    authentication:
      type: scram-sha-512
    authorization:
      type: simple
      acls:
        # Read-only access to analytics topics
        - resource:
            type: topic
            name: "analytics-*"
            patternType: prefix
          operations: [Describe, Read]
          host: "*"
        
        # Consumer groups for analytics
        - resource:
            type: group
            name: "analytics-*"
            patternType: prefix
          operations: [Read]
          host: "*"
```

#### 3. Admin User (TLS)
```yaml
kafkaUsers:
  - name: kafka-admin
    authentication:
      type: tls
    # No authorization block = inherits superuser privileges
```

#### 4. Monitoring User (Limited Access)
```yaml
kafkaUsers:
  - name: monitoring-user
    authentication:
      type: scram-sha-512
    authorization:
      type: simple
      acls:
        # Describe-only access (no data reading)
        - resource:
            type: topic
            name: "*"
            patternType: literal
          operations: [Describe]
          host: "*"
        
        # Consumer group for monitoring tools
        - resource:
            type: group
            name: "monitoring-*"
            patternType: prefix
          operations: [Read]
          host: "*"
```

### User Management Best Practices

1. **Principle of Least Privilege**: Grant minimum required permissions
2. **Use Prefix Patterns**: Scale access with consistent naming
3. **Separate Admin Users**: Use TLS authentication for administrators
4. **Regular Audits**: Review and update user permissions regularly
5. **Credential Rotation**: Implement regular password/certificate rotation

## Security Monitoring

### Key Security Metrics

#### 1. Authentication Failures
- Monitor failed authentication attempts
- Set up alerts for authentication anomalies
- Track authentication method usage

#### 2. Authorization Denials
- Monitor ACL denials and access violations
- Alert on unauthorized access attempts
- Track permission escalation attempts

#### 3. TLS Certificate Status
- Monitor certificate expiration dates
- Track certificate validation failures
- Alert on certificate rotation needs

### Security Logging

```yaml
kafkaCluster:
  config:
    # Enable security logging
    log4j.logger.kafka.authorizer.logger: INFO, authorizerAppender
    log4j.logger.kafka.network.RequestChannel: WARN
    log4j.logger.kafka.security.auth: INFO
```

### Monitoring Tools Integration

#### Prometheus Metrics
```yaml
kafkaCluster:
  metricsConfig:
    enabled: true
    type: jmxPrometheusExporter
    configMapName: kafka-metrics
    configMapKey: kafka-metrics-config.yml
```

#### Log Aggregation
- Configure log forwarding to centralized logging
- Set up security event correlation
- Implement automated threat detection

## Troubleshooting Security Issues

### Common Authentication Issues

#### Issue: TLS Certificate Validation Failures
```bash
# Check certificate validity
openssl x509 -in kafka-cert.pem -text -noout

# Verify certificate chain
openssl verify -CAfile ca-cert.pem kafka-cert.pem
```

**Solution**: Ensure certificate chain is complete and CA is trusted.

#### Issue: SCRAM Authentication Failures
```bash
# Check KafkaUser status
kubectl get kafkauser -n kafka-namespace
kubectl describe kafkauser username -n kafka-namespace
```

**Solution**: Verify user exists and password secret is correctly configured.

### Common Authorization Issues

#### Issue: ACL Denials
```bash
# Check Kafka logs for authorization failures
kubectl logs kafka-pod -n kafka-namespace | grep "DENY"
```

**Solution**: Review and update ACL permissions for the user.

#### Issue: Topic Access Denied
```yaml
# Add topic access ACL
acls:
  - resource:
      type: topic
      name: "topic-name"
      patternType: literal
    operations: [Describe, Read, Write]
    host: "*"
```

### Security Configuration Validation

#### Validate TLS Configuration
```bash
# Test TLS connection
openssl s_client -connect kafka-broker:9093 -servername kafka-broker
```

#### Validate ACL Configuration
```bash
# List ACLs for a user
kubectl exec kafka-pod -- kafka-acls.sh --bootstrap-server localhost:9092 --list --principal User:username
```

#### Validate Authentication
```bash
# Test SCRAM authentication
kafka-console-producer.sh --bootstrap-server kafka:9094 \
  --producer.config client-scram.properties \
  --topic test-topic
```

## Security Checklist

### Pre-Deployment Security Checklist

- [ ] **TLS Configuration**
  - [ ] TLS enabled on all listeners
  - [ ] Strong cipher suites configured
  - [ ] Certificate chain validation enabled
  - [ ] Client authentication required

- [ ] **Authentication Setup**
  - [ ] Authentication method chosen (TLS/SCRAM)
  - [ ] User credentials securely stored
  - [ ] Admin users use TLS certificates
  - [ ] Application users use SCRAM-SHA-512

- [ ] **Authorization Configuration**
  - [ ] ACL authorizer enabled
  - [ ] Deny-by-default configured
  - [ ] Superusers explicitly defined
  - [ ] User ACLs follow least privilege

- [ ] **Broker Security Hardening**
  - [ ] Auto-topic creation disabled
  - [ ] Unclean leader election disabled
  - [ ] High replication factors set
  - [ ] Security logging enabled

### Post-Deployment Security Checklist

- [ ] **Security Validation**
  - [ ] TLS connections working
  - [ ] Authentication functioning
  - [ ] ACLs properly enforced
  - [ ] Unauthorized access blocked

- [ ] **Monitoring Setup**
  - [ ] Security metrics collected
  - [ ] Authentication failure alerts
  - [ ] Authorization denial alerts
  - [ ] Certificate expiration monitoring

- [ ] **Operational Security**
  - [ ] Regular security audits scheduled
  - [ ] Credential rotation procedures
  - [ ] Incident response plan
  - [ ] Security documentation updated

### Ongoing Security Maintenance

- [ ] **Regular Tasks**
  - [ ] Certificate rotation (quarterly)
  - [ ] User access review (monthly)
  - [ ] Security configuration audit (quarterly)
  - [ ] Vulnerability assessments (annually)

- [ ] **Monitoring & Alerting**
  - [ ] Security dashboard configured
  - [ ] Alert thresholds tuned
  - [ ] Incident response tested
  - [ ] Security training updated

## Security References

### Strimzi Security Documentation
- [Strimzi Security Guide](https://strimzi.io/docs/operators/latest/security.html)
- [Authentication Methods](https://strimzi.io/docs/operators/latest/security#assembly-authentication-str)
- [Authorization with ACLs](https://strimzi.io/docs/operators/latest/security#assembly-authorization-str)

### Kafka Security Best Practices
- [Apache Kafka Security](https://kafka.apache.org/documentation/#security)
- [Kafka ACL Management](https://kafka.apache.org/documentation/#security_authz)
- [TLS Configuration](https://kafka.apache.org/documentation/#security_ssl)

### Certificate Management
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Kubernetes TLS Management](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls)

---

**⚠️ Security Notice**: This guide provides comprehensive security configurations. Always review and adapt these settings to your specific security requirements and compliance needs. Regular security audits and updates are essential for maintaining a secure Kafka deployment.
