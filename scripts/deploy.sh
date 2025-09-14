#!/bin/bash

# Strimzi Kafka Helm Chart Deployment Script
# Usage: ./deploy.sh <ENVIRONMENT> <NAMESPACE> <RELEASE_NAME> [ADDITIONAL_HELM_ARGS]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
DEFAULT_TIMEOUT="600s"
DEFAULT_WAIT="true"

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Strimzi Kafka Helm Chart Deployment Script

Usage: $0 <ENVIRONMENT> <NAMESPACE> <RELEASE_NAME> [ADDITIONAL_HELM_ARGS]

Arguments:
  ENVIRONMENT       Target environment (nonprod, staging, prod)
  NAMESPACE         Kubernetes namespace to deploy to
  RELEASE_NAME      Helm release name
  ADDITIONAL_HELM_ARGS  Optional additional Helm arguments

Examples:
  $0 nonprod om-kafka kafka-nonprod
  $0 staging om-kafka-staging kafka-staging --dry-run
  $0 prod om-kafka-prod kafka-prod --set kafkaCluster.replicas=7

Supported environments:
  - nonprod: Non-production environment with basic configuration
  - staging: Staging environment with enhanced features
  - prod: Production environment with full features and high availability

Environment-specific features:
  nonprod: 3 replicas, 4Gi memory, 100Gi storage, HPA disabled
  staging: 3-8 replicas (HPA), 6Gi memory, 200Gi storage, pod anti-affinity
  prod: 5-15 replicas (HPA), 8Gi memory, 500Gi storage, enhanced security

Prerequisites:
  - Helm 3.8+
  - kubectl configured for target cluster
  - Strimzi Kafka Operator installed
  - Appropriate RBAC permissions

EOF
}

# Function to validate environment
validate_environment() {
    local env="$1"
    case "$env" in
        nonprod|staging|prod)
            return 0
            ;;
        *)
            print_error "Invalid environment: $env"
            print_error "Supported environments: nonprod, staging, prod"
            return 1
            ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed or not in PATH"
        return 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        return 1
    fi
    
    # Check if kubectl is configured
    if ! kubectl cluster-info &> /dev/null; then
        print_error "kubectl is not configured or cluster is not accessible"
        return 1
    fi
    
    # Check Helm version
    local helm_version
    helm_version=$(helm version --short --client | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/v//')
    local required_version="3.8.0"
    
    if ! printf '%s\n%s\n' "$required_version" "$helm_version" | sort -V -C; then
        print_error "Helm version $helm_version is too old. Required: $required_version or newer"
        return 1
    fi
    
    print_success "Prerequisites check passed"
    return 0
}

# Function to check if Strimzi operator is installed
check_strimzi_operator() {
    print_info "Checking Strimzi Kafka Operator..."
    
    # Check if Strimzi CRDs exist
    if ! kubectl get crd kafkas.kafka.strimzi.io &> /dev/null; then
        print_warning "Strimzi Kafka Operator CRDs not found"
        print_warning "Please install the Strimzi Kafka Operator first:"
        print_warning "kubectl create -f 'https://strimzi.io/install/latest?namespace=strimzi-operator'"
        return 1
    fi
    
    # Check if operator is running
    if ! kubectl get deployment -n strimzi-operator strimzi-cluster-operator &> /dev/null; then
        print_warning "Strimzi Cluster Operator deployment not found in strimzi-operator namespace"
        print_warning "Please ensure the Strimzi Kafka Operator is installed and running"
        return 1
    fi
    
    print_success "Strimzi Kafka Operator found"
    return 0
}

# Function to validate values file
validate_values_file() {
    local env="$1"
    local values_file="$CHART_DIR/values-$env.yaml"
    
    if [[ ! -f "$values_file" ]]; then
        print_error "Values file not found: $values_file"
        return 1
    fi
    
    # Validate YAML syntax
    if ! helm lint "$CHART_DIR" -f "$values_file" &> /dev/null; then
        print_error "Values file validation failed: $values_file"
        print_error "Run 'helm lint $CHART_DIR -f $values_file' for details"
        return 1
    fi
    
    print_success "Values file validation passed: $values_file"
    return 0
}

# Function to create namespace if it doesn't exist
ensure_namespace() {
    local namespace="$1"
    
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        print_info "Creating namespace: $namespace"
        kubectl create namespace "$namespace"
        print_success "Namespace created: $namespace"
    else
        print_info "Namespace already exists: $namespace"
    fi
}

# Function to deploy the chart
deploy_chart() {
    local env="$1"
    local namespace="$2"
    local release_name="$3"
    shift 3
    local additional_args=("$@")
    
    local values_file="$CHART_DIR/values-$env.yaml"
    
    print_info "Deploying Strimzi Kafka chart..."
    print_info "Environment: $env"
    print_info "Namespace: $namespace"
    print_info "Release: $release_name"
    print_info "Values file: $values_file"
    
    # Prepare Helm command
    local helm_cmd=(
        helm upgrade --install "$release_name" "$CHART_DIR"
        --namespace "$namespace"
        --values "$values_file"
        --timeout "$DEFAULT_TIMEOUT"
    )
    
    if [[ "$DEFAULT_WAIT" == "true" ]]; then
        helm_cmd+=(--wait)
    fi
    
    # Add additional arguments
    if [[ ${#additional_args[@]} -gt 0 ]]; then
        helm_cmd+=("${additional_args[@]}")
        print_info "Additional Helm arguments: ${additional_args[*]}"
    fi
    
    # Execute Helm command
    print_info "Executing: ${helm_cmd[*]}"
    
    if "${helm_cmd[@]}"; then
        print_success "Deployment completed successfully"
        return 0
    else
        print_error "Deployment failed"
        return 1
    fi
}

# Function to show deployment status
show_deployment_status() {
    local namespace="$1"
    local release_name="$2"
    
    print_info "Deployment Status:"
    echo
    
    # Helm release status
    print_info "Helm Release Status:"
    helm status "$release_name" -n "$namespace" || true
    echo
    
    # Kafka cluster status
    print_info "Kafka Cluster Status:"
    kubectl get kafka -n "$namespace" -o wide || true
    echo
    
    # Pod status
    print_info "Pod Status:"
    kubectl get pods -n "$namespace" -l strimzi.io/cluster -o wide || true
    echo
    
    # Service status
    print_info "Service Status:"
    kubectl get svc -n "$namespace" -l strimzi.io/cluster || true
    echo
}

# Function to show post-deployment instructions
show_post_deployment_instructions() {
    local env="$1"
    local namespace="$2"
    local release_name="$3"
    
    cat << EOF

${GREEN}🎉 Deployment Completed Successfully!${NC}

${BLUE}Next Steps:${NC}

1. ${YELLOW}Verify the deployment:${NC}
   kubectl get kafka -n $namespace
   kubectl get pods -n $namespace

2. ${YELLOW}Run Helm tests:${NC}
   helm test $release_name -n $namespace

3. ${YELLOW}Check Kafka cluster status:${NC}
   kubectl describe kafka -n $namespace

4. ${YELLOW}View logs if needed:${NC}
   kubectl logs -n $namespace -l strimzi.io/cluster --tail=100

5. ${YELLOW}Access Kafka (internal):${NC}
   Bootstrap server: <cluster-name>-kafka-bootstrap.$namespace.svc.cluster.local:9092

EOF

    # Environment-specific instructions
    case "$env" in
        nonprod)
            cat << EOF
6. ${YELLOW}External access (nonprod):${NC}
   Bootstrap server: om-kafka.nonprod.om.yo-digital.com:443
   
7. ${YELLOW}Test with console producer/consumer:${NC}
   kubectl run kafka-producer -ti --image=quay.io/strimzi/kafka:0.41.0-kafka-3.9.0 --rm=true --restart=Never -n $namespace -- bin/kafka-console-producer.sh --bootstrap-server om-kafka-cluster-kafka-bootstrap:9092 --topic test-topic

EOF
            ;;
        staging)
            cat << EOF
6. ${YELLOW}External access (staging):${NC}
   Bootstrap server: om-kafka.staging.om.yo-digital.com:443
   
7. ${YELLOW}Monitor HPA (if enabled):${NC}
   kubectl get hpa -n $namespace

EOF
            ;;
        prod)
            cat << EOF
6. ${YELLOW}External access (production):${NC}
   Bootstrap server: om-kafka.prod.om.yo-digital.com:443
   
7. ${YELLOW}Monitor HPA:${NC}
   kubectl get hpa -n $namespace
   
8. ${YELLOW}Monitor Cruise Control:${NC}
   kubectl logs -n $namespace -l strimzi.io/name=<cluster-name>-cruise-control

9. ${YELLOW}Production monitoring:${NC}
   - Check Prometheus metrics
   - Review Grafana dashboards
   - Monitor external DNS records

EOF
            ;;
    esac

    cat << EOF
${BLUE}Troubleshooting:${NC}
- Check the README.md for detailed troubleshooting steps
- Review Strimzi documentation: https://strimzi.io/docs/
- View operator logs: kubectl logs -n strimzi-operator deployment/strimzi-cluster-operator

${BLUE}Useful Commands:${NC}
- Upgrade: helm upgrade $release_name $CHART_DIR -f $CHART_DIR/values-$env.yaml -n $namespace
- Rollback: helm rollback $release_name -n $namespace
- Uninstall: helm uninstall $release_name -n $namespace

EOF
}

# Main function
main() {
    # Check if help is requested
    if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # Check minimum required arguments
    if [[ $# -lt 3 ]]; then
        print_error "Insufficient arguments provided"
        show_usage
        exit 1
    fi
    
    local environment="$1"
    local namespace="$2"
    local release_name="$3"
    shift 3
    local additional_args=("$@")
    
    # Validate inputs
    if ! validate_environment "$environment"; then
        exit 1
    fi
    
    # Run checks
    if ! check_prerequisites; then
        exit 1
    fi
    
    if ! check_strimzi_operator; then
        print_warning "Continuing without Strimzi operator verification..."
    fi
    
    if ! validate_values_file "$environment"; then
        exit 1
    fi
    
    # Create namespace if needed
    ensure_namespace "$namespace"
    
    # Deploy the chart
    if deploy_chart "$environment" "$namespace" "$release_name" "${additional_args[@]}"; then
        echo
        show_deployment_status "$namespace" "$release_name"
        show_post_deployment_instructions "$environment" "$namespace" "$release_name"
        exit 0
    else
        print_error "Deployment failed. Check the logs above for details."
        exit 1
    fi
}

# Run main function with all arguments
main "$@"