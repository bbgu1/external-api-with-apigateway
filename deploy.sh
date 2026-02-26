#!/bin/bash

################################################################################
# AWS API Gateway Demo - Automated Deployment Script
#
# This script automates the deployment of the AWS API Gateway demo solution
# with validation checks and rollback capability.
#
# Usage:
#   ./deploy.sh [options]
#
# Options:
#   --auto-approve    Skip confirmation prompts
#   --destroy         Destroy infrastructure instead of deploying
#   --rollback        Rollback to previous Terraform state
#   --validate-only   Only validate configuration without deploying
#   --help            Show this help message
#
################################################################################

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="terraform"
REQUIRED_TERRAFORM_VERSION="1.0"
REQUIRED_AWS_CLI_VERSION="2.0"
REQUIRED_PYTHON_VERSION="3.9"

# Flags
AUTO_APPROVE=false
DESTROY_MODE=false
ROLLBACK_MODE=false
VALIDATE_ONLY=false

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

confirm() {
    if [ "$AUTO_APPROVE" = true ]; then
        return 0
    fi
    
    read -p "$1 (yes/no): " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed"
        return 1
    fi
    print_success "$1 is installed"
    return 0
}

version_compare() {
    # Compare version strings (e.g., "1.5.2" >= "1.0")
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

################################################################################
# Validation Functions
################################################################################

validate_prerequisites() {
    print_header "Validating Prerequisites"
    
    local all_valid=true
    
    # Check Terraform
    if check_command terraform; then
        local tf_version=$(terraform version -json | jq -r '.terraform_version')
        if version_compare "$tf_version" "$REQUIRED_TERRAFORM_VERSION"; then
            print_success "Terraform version $tf_version (>= $REQUIRED_TERRAFORM_VERSION required)"
        else
            print_error "Terraform version $tf_version is too old (>= $REQUIRED_TERRAFORM_VERSION required)"
            all_valid=false
        fi
    else
        all_valid=false
    fi
    
    # Check AWS CLI
    if check_command aws; then
        local aws_version=$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2)
        if version_compare "$aws_version" "$REQUIRED_AWS_CLI_VERSION"; then
            print_success "AWS CLI version $aws_version (>= $REQUIRED_AWS_CLI_VERSION required)"
        else
            print_error "AWS CLI version $aws_version is too old (>= $REQUIRED_AWS_CLI_VERSION required)"
            all_valid=false
        fi
    else
        all_valid=false
    fi
    
    # Check Python
    if check_command python3; then
        local py_version=$(python3 --version | cut -d' ' -f2)
        if version_compare "$py_version" "$REQUIRED_PYTHON_VERSION"; then
            print_success "Python version $py_version (>= $REQUIRED_PYTHON_VERSION required)"
        else
            print_error "Python version $py_version is too old (>= $REQUIRED_PYTHON_VERSION required)"
            all_valid=false
        fi
    else
        all_valid=false
    fi
    
    # Check jq (optional but recommended)
    if check_command jq; then
        print_success "jq is installed (optional)"
    else
        print_warning "jq is not installed (optional, but recommended for JSON parsing)"
    fi
    
    if [ "$all_valid" = false ]; then
        print_error "Prerequisites validation failed"
        exit 1
    fi
    
    print_success "All prerequisites validated"
    echo
}

validate_aws_credentials() {
    print_header "Validating AWS Credentials"
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured or invalid"
        print_info "Run 'aws configure' to set up your credentials"
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local user_arn=$(aws sts get-caller-identity --query Arn --output text)
    
    print_success "AWS credentials are valid"
    print_info "Account ID: $account_id"
    print_info "User/Role: $user_arn"
    echo
}

validate_terraform_config() {
    print_header "Validating Terraform Configuration"
    
    cd "$TERRAFORM_DIR"
    
    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        print_error "terraform.tfvars not found"
        print_info "Copy terraform.tfvars.example and customize it:"
        print_info "  cp terraform.tfvars.example terraform.tfvars"
        exit 1
    fi
    print_success "terraform.tfvars found"
    
    # Validate Terraform configuration
    if ! terraform validate &> /dev/null; then
        print_error "Terraform configuration is invalid"
        terraform validate
        exit 1
    fi
    print_success "Terraform configuration is valid"
    
    cd - > /dev/null
    echo
}

################################################################################
# Backup Functions
################################################################################

backup_terraform_state() {
    print_header "Backing Up Terraform State"
    
    cd "$TERRAFORM_DIR"
    
    if [ -f "terraform.tfstate" ]; then
        local backup_file="terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)"
        cp terraform.tfstate "$backup_file"
        print_success "State backed up to $backup_file"
    else
        print_info "No state file to backup (first deployment)"
    fi
    
    cd - > /dev/null
    echo
}

################################################################################
# Deployment Functions
################################################################################

initialize_terraform() {
    print_header "Initializing Terraform"
    
    cd "$TERRAFORM_DIR"
    
    # Check if backend.tfvars exists
    if [ -f "backend.tfvars" ]; then
        print_info "Using remote backend configuration"
        terraform init -backend-config=backend.tfvars
    else
        print_info "Using local backend (no backend.tfvars found)"
        terraform init
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Terraform initialized successfully"
    else
        print_error "Terraform initialization failed"
        exit 1
    fi
    
    cd - > /dev/null
    echo
}

plan_deployment() {
    print_header "Planning Deployment"
    
    cd "$TERRAFORM_DIR"
    
    if [ "$DESTROY_MODE" = true ]; then
        terraform plan -destroy -out=tfplan
    else
        terraform plan -out=tfplan
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Terraform plan created successfully"
    else
        print_error "Terraform plan failed"
        exit 1
    fi
    
    cd - > /dev/null
    echo
}

apply_deployment() {
    print_header "Applying Deployment"
    
    cd "$TERRAFORM_DIR"
    
    if [ "$AUTO_APPROVE" = true ]; then
        terraform apply tfplan
    else
        if confirm "Do you want to apply this plan?"; then
            terraform apply tfplan
        else
            print_info "Deployment cancelled"
            rm -f tfplan
            exit 0
        fi
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Deployment applied successfully"
    else
        print_error "Deployment failed"
        print_warning "You may need to rollback using: ./deploy.sh --rollback"
        exit 1
    fi
    
    rm -f tfplan
    cd - > /dev/null
    echo
}

show_outputs() {
    print_header "Deployment Outputs"
    
    cd "$TERRAFORM_DIR"
    
    if terraform output &> /dev/null; then
        echo
        terraform output
        echo
        
        # Save outputs to file
        terraform output > ../deployment-outputs.txt
        print_success "Outputs saved to deployment-outputs.txt"
        
        # Show quick access commands
        print_info "Quick access commands:"
        echo "  export API_URL=\$(cd terraform && terraform output -raw api_endpoint_url)"
        echo "  export TOKEN_ENDPOINT=\$(cd terraform && terraform output -raw cognito_token_endpoint)"
        echo "  export DASHBOARD_URL=\$(cd terraform && terraform output -raw cloudwatch_dashboard_url)"
    else
        print_warning "No outputs available (deployment may have failed)"
    fi
    
    cd - > /dev/null
    echo
}

################################################################################
# Rollback Functions
################################################################################

rollback_deployment() {
    print_header "Rolling Back Deployment"
    
    cd "$TERRAFORM_DIR"
    
    # Find most recent backup
    local latest_backup=$(ls -t terraform.tfstate.backup.* 2>/dev/null | head -1)
    
    if [ -z "$latest_backup" ]; then
        print_error "No backup state file found"
        print_info "Cannot rollback without a backup"
        exit 1
    fi
    
    print_info "Found backup: $latest_backup"
    
    if confirm "Do you want to rollback to this state?"; then
        # Backup current state before rollback
        if [ -f "terraform.tfstate" ]; then
            cp terraform.tfstate "terraform.tfstate.before_rollback.$(date +%Y%m%d_%H%M%S)"
        fi
        
        # Restore backup
        cp "$latest_backup" terraform.tfstate
        print_success "State restored from backup"
        
        # Apply the restored state
        print_info "Applying restored state..."
        terraform apply -auto-approve
        
        if [ $? -eq 0 ]; then
            print_success "Rollback completed successfully"
        else
            print_error "Rollback failed"
            exit 1
        fi
    else
        print_info "Rollback cancelled"
        exit 0
    fi
    
    cd - > /dev/null
    echo
}

################################################################################
# Destroy Functions
################################################################################

destroy_infrastructure() {
    print_header "Destroying Infrastructure"
    
    print_warning "This will permanently delete all resources including data!"
    
    if ! confirm "Are you sure you want to destroy all infrastructure?"; then
        print_info "Destroy cancelled"
        exit 0
    fi
    
    # Double confirmation for safety
    if ! confirm "Type 'yes' again to confirm destruction"; then
        print_info "Destroy cancelled"
        exit 0
    fi
    
    cd "$TERRAFORM_DIR"
    
    if [ "$AUTO_APPROVE" = true ]; then
        terraform destroy -auto-approve
    else
        terraform destroy
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Infrastructure destroyed successfully"
    else
        print_error "Destroy failed"
        exit 1
    fi
    
    cd - > /dev/null
    echo
}

################################################################################
# Main Script
################################################################################

show_help() {
    cat << EOF
AWS API Gateway Demo - Automated Deployment Script

Usage: ./deploy.sh [options]

Options:
  --auto-approve    Skip confirmation prompts
  --destroy         Destroy infrastructure instead of deploying
  --rollback        Rollback to previous Terraform state
  --validate-only   Only validate configuration without deploying
  --help            Show this help message

Examples:
  # Deploy with prompts
  ./deploy.sh

  # Deploy without prompts
  ./deploy.sh --auto-approve

  # Validate configuration only
  ./deploy.sh --validate-only

  # Destroy infrastructure
  ./deploy.sh --destroy

  # Rollback to previous state
  ./deploy.sh --rollback

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto-approve)
                AUTO_APPROVE=true
                shift
                ;;
            --destroy)
                DESTROY_MODE=true
                shift
                ;;
            --rollback)
                ROLLBACK_MODE=true
                shift
                ;;
            --validate-only)
                VALIDATE_ONLY=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    
    print_header "AWS API Gateway Demo - Deployment Script"
    echo
    
    # Always validate prerequisites
    validate_prerequisites
    validate_aws_credentials
    
    # Handle rollback mode
    if [ "$ROLLBACK_MODE" = true ]; then
        rollback_deployment
        exit 0
    fi
    
    # Handle destroy mode
    if [ "$DESTROY_MODE" = true ]; then
        destroy_infrastructure
        exit 0
    fi
    
    # Validate Terraform configuration
    validate_terraform_config
    
    # Exit if validate-only mode
    if [ "$VALIDATE_ONLY" = true ]; then
        print_success "Validation completed successfully"
        exit 0
    fi
    
    # Backup state before deployment
    backup_terraform_state
    
    # Initialize Terraform
    initialize_terraform
    
    # Plan deployment
    plan_deployment
    
    # Apply deployment
    apply_deployment
    
    # Show outputs
    show_outputs
    
    print_header "Deployment Complete"
    print_success "Infrastructure deployed successfully!"
    echo
    print_info "Next steps:"
    echo "  1. Review outputs above or in deployment-outputs.txt"
    echo "  2. Test authentication: see README.md 'Verification Steps'"
    echo "  3. Access CloudWatch dashboard: \$(cd terraform && terraform output -raw cloudwatch_dashboard_url)"
    echo "  4. View X-Ray traces in AWS Console"
    echo
}

# Run main function
main "$@"
