#!/bin/bash

################################################################################
# ArgoCD Installation Script
# 
# This script installs and configures ArgoCD on an EKS cluster with:
# - Namespace creation
# - Helm repository setup
# - ArgoCD installation with custom values
# - Project configuration
# - RBAC setup
# - Notifications configuration
#
# Usage:
#   ./install.sh [--dry-run]
#
# Options:
#   --dry-run    Show what would be done without making changes
#
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="argocd"
HELM_REPO_NAME="argo"
HELM_REPO_URL="https://argoproj.github.io/argo-helm"
HELM_CHART="argo/argo-cd"
HELM_RELEASE_NAME="argocd"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

run_command() {
    local cmd="$1"
    local description="$2"
    
    log_info "$description"
    
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] $cmd"
        return 0
    fi
    
    if eval "$cmd"; then
        log_success "$description"
        return 0
    else
        log_error "Failed: $description"
        return 1
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    log_success "kubectl found"
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed"
        exit 1
    fi
    log_success "helm found"
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    log_success "Connected to Kubernetes cluster"
    
    # Check if namespace exists
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "Namespace '$NAMESPACE' already exists"
    fi
}

create_namespace() {
    local namespace_file="$SCRIPT_DIR/namespace.yaml"
    
    if [ ! -f "$namespace_file" ]; then
        log_error "Namespace file not found: $namespace_file"
        exit 1
    fi
    
    run_command "kubectl apply -f '$namespace_file'" "Creating namespace from $namespace_file"
}

add_helm_repo() {
    log_info "Adding Helm repository..."
    
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] helm repo add $HELM_REPO_NAME $HELM_REPO_URL"
        echo "  [DRY-RUN] helm repo update"
        return 0
    fi
    
    if helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL" 2>/dev/null || \
       helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL" --force-update 2>/dev/null; then
        log_success "Helm repository added"
    else
        log_warning "Helm repository may already exist"
    fi
    
    if helm repo update; then
        log_success "Helm repository updated"
    else
        log_error "Failed to update Helm repository"
        exit 1
    fi
}

install_argocd() {
    local values_file="$SCRIPT_DIR/values.yaml"
    
    if [ ! -f "$values_file" ]; then
        log_error "Values file not found: $values_file"
        exit 1
    fi
    
    log_info "Installing/upgrading ArgoCD..."
    
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] helm upgrade --install $HELM_RELEASE_NAME $HELM_CHART -n $NAMESPACE -f $values_file"
        return 0
    fi
    
    if helm upgrade --install "$HELM_RELEASE_NAME" "$HELM_CHART" \
        -n "$NAMESPACE" \
        -f "$values_file" \
        --wait \
        --timeout 5m; then
        log_success "ArgoCD installed/upgraded successfully"
    else
        log_error "Failed to install/upgrade ArgoCD"
        exit 1
    fi
}

apply_projects() {
    local projects_dir="$SCRIPT_DIR/projects"
    
    if [ ! -d "$projects_dir" ]; then
        log_error "Projects directory not found: $projects_dir"
        exit 1
    fi
    
    log_info "Applying ArgoCD projects..."
    
    for project_file in "$projects_dir"/*.yaml; do
        if [ -f "$project_file" ]; then
            local project_name=$(basename "$project_file" .yaml)
            run_command "kubectl apply -f '$project_file'" "Applying project: $project_name"
        fi
    done
}

apply_rbac() {
    local rbac_file="$SCRIPT_DIR/rbac/rbac-configmap.yaml"
    
    if [ ! -f "$rbac_file" ]; then
        log_error "RBAC file not found: $rbac_file"
        exit 1
    fi
    
    run_command "kubectl apply -f '$rbac_file'" "Applying RBAC configuration"
}

apply_notifications() {
    local notifications_cm="$SCRIPT_DIR/notifications/notifications-configmap.yaml"
    local notifications_secret="$SCRIPT_DIR/notifications/notifications-secret.yaml"
    
    if [ ! -f "$notifications_cm" ]; then
        log_error "Notifications ConfigMap not found: $notifications_cm"
        exit 1
    fi
    
    run_command "kubectl apply -f '$notifications_cm'" "Applying notifications ConfigMap"
    
    if [ -f "$notifications_secret" ]; then
        log_warning "Notifications secret file exists but contains placeholders"
        log_info "To configure notifications, update the secret with actual credentials:"
        echo "  kubectl apply -f '$notifications_secret'"
    fi
}

print_next_steps() {
    log_info "Installation complete!"
    echo ""
    echo -e "${BLUE}=== Next Steps ===${NC}"
    echo ""
    echo "1. Retrieve the initial admin password:"
    echo "   ${YELLOW}kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d${NC}"
    echo ""
    echo "2. Port-forward to access ArgoCD UI (for initial setup):"
    echo "   ${YELLOW}kubectl port-forward -n $NAMESPACE svc/$HELM_RELEASE_NAME-server 8080:80${NC}"
    echo "   Then access: http://localhost:8080"
    echo ""
    echo "3. Login with ArgoCD CLI:"
    echo "   ${YELLOW}argocd login argocd.internal.example.com --username admin --password <password>${NC}"
    echo ""
    echo "4. Configure Git repository credentials:"
    echo "   ${YELLOW}argocd repo add https://github.com/ORG/shared-devsecops-gitops.git --username <username> --password <token>${NC}"
    echo ""
    echo "5. Update notification credentials:"
    echo "   Edit the notifications secret with actual Slack/Teams credentials"
    echo "   ${YELLOW}kubectl edit secret argocd-notifications-secret -n $NAMESPACE${NC}"
    echo ""
    echo "6. Verify installation:"
    echo "   ${YELLOW}kubectl get all -n $NAMESPACE${NC}"
    echo "   ${YELLOW}kubectl get appprojects -n $NAMESPACE${NC}"
    echo ""
    echo "Documentation:"
    echo "  - Sync Policies: $SCRIPT_DIR/sync-policies/README.md"
    echo "  - Webhooks: $SCRIPT_DIR/webhooks/README.md"
    echo "  - Notifications: $SCRIPT_DIR/notifications/notifications-configmap.yaml"
    echo ""
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                log_warning "Running in DRY-RUN mode - no changes will be made"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    log_info "Starting ArgoCD installation..."
    echo ""
    
    check_prerequisites
    echo ""
    
    create_namespace
    echo ""
    
    add_helm_repo
    echo ""
    
    install_argocd
    echo ""
    
    apply_projects
    echo ""
    
    apply_rbac
    echo ""
    
    apply_notifications
    echo ""
    
    print_next_steps
}

# Run main function
main "$@"
