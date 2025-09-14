# Contributing to Strimzi Kafka Helm Chart

Thank you for your interest in contributing to this Strimzi Kafka Helm chart! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Guidelines](#contributing-guidelines)
- [Testing](#testing)
- [Security Considerations](#security-considerations)
- [Documentation](#documentation)
- [Pull Request Process](#pull-request-process)
- [Release Process](#release-process)

## Code of Conduct

This project adheres to a code of conduct that we expect all contributors to follow:

- **Be respectful** and inclusive in all interactions
- **Be collaborative** and help others learn and grow
- **Be constructive** when providing feedback
- **Focus on the issue**, not the person
- **Respect different viewpoints** and experiences

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- **Kubernetes cluster** (1.21+) for testing
- **Helm** (3.8+) installed locally
- **kubectl** configured to access your cluster
- **Git** for version control
- **Text editor** or IDE of your choice

### Repository Structure

```
strimzi-kafka-helm/
├── Chart.yaml                 # Helm chart metadata
├── values.yaml               # Default configuration values
├── values-*.yaml             # Environment-specific values
├── templates/                # Kubernetes resource templates
│   ├── _helpers.tpl         # Template helper functions
│   ├── kafka-cluster.yaml   # Main Kafka cluster resource
│   ├── kafka-users.yaml     # KafkaUser resources
│   ├── kafka-topics.yaml    # KafkaTopic resources
│   ├── kafka-connect.yaml   # KafkaConnect resources
│   ├── kafka-rebalance.yaml # KafkaRebalance resources
│   ├── configmaps.yaml      # ConfigMap resources
│   ├── hpa.yaml             # HorizontalPodAutoscaler resources
│   ├── tests/               # Helm test resources
│   └── NOTES.txt           # Post-install notes
├── README.md                # Main documentation
├── SECURITY.md             # Security guide
├── upgrades.md             # Upgrade procedures
└── CONTRIBUTING.md         # This file
```

## Development Setup

### 1. Fork and Clone

```bash
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/strimzi-kafka-helm.git
cd strimzi-kafka-helm

# Add upstream remote
git remote add upstream https://github.com/ORIGINAL_OWNER/strimzi-kafka-helm.git
```

### 2. Install Dependencies

```bash
# Add Strimzi Helm repository
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# Install Strimzi Kafka Operator (if not already installed)
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --namespace strimzi-system \
  --create-namespace \
  --wait
```

### 3. Development Environment

```bash
# Create a development namespace
kubectl create namespace kafka-dev

# Install the chart for development
helm install kafka-dev . \
  --namespace kafka-dev \
  --values values-nonprod.yaml \
  --wait
```

## Contributing Guidelines

### Types of Contributions

We welcome various types of contributions:

#### 🐛 **Bug Fixes**
- Fix template rendering issues
- Correct configuration problems
- Resolve security vulnerabilities
- Address compatibility issues

#### ✨ **Features**
- Add new Strimzi resource support
- Enhance configuration options
- Improve security features
- Add monitoring capabilities

#### 📚 **Documentation**
- Update README.md
- Enhance security documentation
- Add configuration examples
- Improve troubleshooting guides

#### 🧪 **Testing**
- Add Helm tests
- Improve validation logic
- Add integration tests
- Enhance CI/CD pipeline

### Contribution Workflow

1. **Create an Issue** (for significant changes)
   - Describe the problem or enhancement
   - Discuss the approach with maintainers
   - Get feedback before implementation

2. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```

3. **Make Changes**
   - Follow coding standards (see below)
   - Update documentation as needed
   - Add tests for new functionality

4. **Test Thoroughly**
   - Validate Helm template rendering
   - Test with different value configurations
   - Verify security settings
   - Run integration tests

5. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat: add support for custom listeners"
   # or
   git commit -m "fix: resolve TLS configuration issue"
   ```

6. **Push and Create PR**
   ```bash
   git push origin feature/your-feature-name
   ```

### Coding Standards

#### Helm Template Guidelines

1. **Template Structure**
   ```yaml
   {{- if .Values.component.enabled }}
   apiVersion: kafka.strimzi.io/v1beta2
   kind: ResourceType
   metadata:
     name: {{ include "helper.name" . }}
     namespace: {{ include "strimzi-kafka.namespace" . }}
     labels:
       {{- include "strimzi-kafka.labels" . | nindent 4 }}
   spec:
     # Resource specification
   {{- end }}
   ```

2. **Helper Functions**
   - Use helper functions for repeated logic
   - Follow naming convention: `strimzi-kafka.functionName`
   - Document complex helper functions

3. **Conditional Logic**
   ```yaml
   {{- if .Values.feature.enabled }}
   # Feature configuration
   {{- end }}
   
   {{- with .Values.optional.config }}
   # Optional configuration
   {{- toYaml . | nindent 2 }}
   {{- end }}
   ```

4. **Security Defaults**
   - Always default to secure configurations
   - Require explicit opt-in for insecure settings
   - Validate security-critical parameters

## Testing

### Local Testing

#### 1. Template Validation
```bash
# Validate template rendering
helm template test-kafka . --values values-nonprod.yaml

# Check for specific resources
helm template test-kafka . --values values-prod.yaml | grep -A 10 "kind: Kafka"

# Validate with different configurations
helm template test-kafka . --set kafkaCluster.version=3.8.0
```

#### 2. Lint Testing
```bash
# Run Helm linting
helm lint .

# Check for YAML syntax
helm template test-kafka . --values values-prod.yaml | kubectl apply --dry-run=client -f -
```

#### 3. Security Validation
```bash
# Test security configurations
helm template test-kafka . --values values-prod.yaml | grep -E "(tls|authentication|authorization)"

# Validate ACL configurations
helm template test-kafka . --values values-prod.yaml | grep -A 20 "kind: KafkaUser"
```

### Integration Testing

#### 1. Deployment Testing
```bash
# Install in test namespace
helm install test-kafka . \
  --namespace kafka-test \
  --create-namespace \
  --values values-nonprod.yaml \
  --wait

# Run Helm tests
helm test test-kafka --namespace kafka-test

# Cleanup
helm uninstall test-kafka --namespace kafka-test
kubectl delete namespace kafka-test
```

#### 2. Multi-Environment Testing
```bash
# Test different environment configurations
for env in nonprod staging prod; do
  echo "Testing $env environment..."
  helm template test-kafka-$env . --values values-$env.yaml > /tmp/test-$env.yaml
  kubectl apply --dry-run=client -f /tmp/test-$env.yaml
done
```

### Test Checklist

Before submitting a PR, ensure:

- [ ] **Template Rendering** - All templates render without errors
- [ ] **Value Validation** - All value combinations work correctly
- [ ] **Security Testing** - Security configurations are properly applied
- [ ] **Multi-Environment** - Changes work across all environment files
- [ ] **Backward Compatibility** - Existing deployments continue to work
- [ ] **Documentation** - All changes are documented
- [ ] **Helm Tests** - Built-in tests pass successfully

## Security Considerations

### Security Review Process

All security-related changes require additional review:

1. **Security Impact Assessment**
   - Identify potential security implications
   - Document security configuration changes
   - Validate secure defaults

2. **Security Testing**
   - Test authentication mechanisms
   - Validate authorization controls
   - Verify TLS configurations
   - Check for privilege escalation

### Security Guidelines

1. **Secure by Default**
   ```yaml
   # Good: Secure default
   kafkaCluster:
     config:
       auto.create.topics.enable: false
       allow.everyone.if.no.acl.found: false
   
   # Bad: Insecure default
   kafkaCluster:
     config:
       auto.create.topics.enable: true
   ```

2. **Security Validation**
   ```yaml
   # Validate TLS configuration
   {{- range .Values.kafkaCluster.listeners }}
   {{- if and (eq .type "external") (not .tls) }}
   {{- fail "External listeners must have TLS enabled" }}
   {{- end }}
   {{- end }}
   ```

## Pull Request Process

### PR Requirements

1. **Description**
   - Clear description of changes
   - Link to related issues
   - Explain motivation and context
   - List breaking changes (if any)

2. **Testing Evidence**
   - Include test results
   - Show template rendering output
   - Demonstrate functionality
   - Provide security validation

3. **Documentation Updates**
   - Update relevant documentation
   - Add configuration examples
   - Include troubleshooting information
   - Update security guidance

### Review Process

1. **Automated Checks**
   - Helm linting passes
   - Template rendering successful
   - Documentation builds correctly

2. **Manual Review**
   - Code quality assessment
   - Security review (for security changes)
   - Documentation review
   - Testing validation

3. **Approval Requirements**
   - At least one maintainer approval
   - Security team approval (for security changes)
   - All checks passing
   - Conflicts resolved

---

Thank you for contributing to the Strimzi Kafka Helm Chart! Your contributions help make Kafka deployment on Kubernetes more accessible and secure for everyone. 🚀
