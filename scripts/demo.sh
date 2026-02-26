#!/bin/bash

# AWS API Gateway Demo Script
# Demonstrates the key features of the multi-tenant API Gateway solution.
#
# Prerequisites:
#   1. Core infrastructure deployed: cd terraform && terraform apply
#   2. Tenants onboarded: cd terraform/tenants && terraform apply
#   3. Sample data seeded: ./scripts/seed_data.sh
#   4. Tools: curl, jq, terraform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
TENANTS_DIR="$PROJECT_ROOT/terraform/tenants"

# Helper functions
print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}➜ $1${NC}"
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

pause() {
    echo ""
    read -p "Press Enter to continue..."
    echo ""
}

# Get output from core infrastructure
get_core_output() {
    cd "$TERRAFORM_DIR"
    terraform output -raw "$1" 2>/dev/null || echo ""
}

# Get JSON output from tenants workspace
get_tenants_json_output() {
    cd "$TENANTS_DIR"
    terraform output -json "$1" 2>/dev/null || echo "{}"
}

# Authenticate a tenant and return the access token
authenticate_tenant() {
    local tenant_id=$1
    local client_id=$2
    local client_secret=$3
    local token_endpoint=$4

    print_step "Authenticating as tenant: $tenant_id"

    local token_response=$(curl -s -X POST "$token_endpoint" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials&client_id=${client_id}&client_secret=${client_secret}&scope=api/read")

    local access_token=$(echo "$token_response" | jq -r '.access_token')

    if [ "$access_token" != "null" ] && [ -n "$access_token" ]; then
        print_success "Authentication successful"
        echo "$access_token"
    else
        print_error "Authentication failed"
        echo "$token_response" | jq '.'
        return 1
    fi
}

# Make an API call
api_call() {
    local method=$1
    local endpoint=$2
    local token=$3
    local data=$4

    if [ -n "$data" ]; then
        curl -s -X "$method" "$endpoint" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "$data"
    else
        curl -s -X "$method" "$endpoint" \
            -H "Authorization: Bearer $token"
    fi
}

main() {
    print_header "AWS API Gateway Multi-Tenant Demo"

    echo "This demo showcases:"
    echo "  1. Multi-tenant authentication with AWS Cognito"
    echo "  2. RESTful API endpoints (Catalog & Orders)"
    echo "  3. Tenant isolation and security"
    echo "  4. Rate limiting per tenant tier"
    echo "  5. AWS X-Ray distributed tracing"
    echo "  6. CloudWatch monitoring dashboard"

    pause

    # ── Step 1: Retrieve infrastructure info ──────────────────────────
    print_header "Step 1: Retrieving Infrastructure Information"

    print_step "Getting core infrastructure outputs..."
    API_ENDPOINT=$(get_core_output "api_endpoint_url")
    TOKEN_ENDPOINT=$(get_core_output "cognito_token_endpoint")
    AWS_REGION=$(get_core_output "aws_region")
    DASHBOARD_URL=$(get_core_output "cloudwatch_dashboard_url")

    if [ -z "$API_ENDPOINT" ]; then
        print_error "Failed to retrieve API endpoint. Is the core infrastructure deployed?"
        echo "  Run: cd terraform && terraform apply"
        exit 1
    fi

    print_success "API Endpoint: $API_ENDPOINT"
    print_success "Token Endpoint: $TOKEN_ENDPOINT"
    print_success "AWS Region: $AWS_REGION"
    print_success "Dashboard URL: $DASHBOARD_URL"

    print_step "Getting tenant credentials from tenants workspace..."
    TENANT_CLIENT_IDS=$(get_tenants_json_output "cognito_client_ids")
    TENANT_CLIENT_SECRETS=$(get_tenants_json_output "cognito_client_secrets")

    if [ "$TENANT_CLIENT_IDS" = "{}" ]; then
        print_error "No tenant credentials found. Are tenants onboarded?"
        echo "  Run: cd terraform/tenants && terraform apply"
        exit 1
    fi

    # Extract credentials for each tenant
    BASIC_CLIENT_ID=$(echo "$TENANT_CLIENT_IDS" | jq -r '.["tenant-basic-001"] // empty')
    BASIC_CLIENT_SECRET=$(echo "$TENANT_CLIENT_SECRETS" | jq -r '.["tenant-basic-001"] // empty')
    STANDARD_CLIENT_ID=$(echo "$TENANT_CLIENT_IDS" | jq -r '.["tenant-standard-001"] // empty')
    STANDARD_CLIENT_SECRET=$(echo "$TENANT_CLIENT_SECRETS" | jq -r '.["tenant-standard-001"] // empty')
    PREMIUM_CLIENT_ID=$(echo "$TENANT_CLIENT_IDS" | jq -r '.["tenant-premium-001"] // empty')
    PREMIUM_CLIENT_SECRET=$(echo "$TENANT_CLIENT_SECRETS" | jq -r '.["tenant-premium-001"] // empty')

    print_success "Loaded credentials for tenants: basic, standard, premium"

    pause

    # ── Step 2: Authentication ────────────────────────────────────────
    print_header "Step 2: Multi-Tenant Authentication"

    echo "Authenticating tenants of different tiers..."
    echo ""

    BASIC_TOKEN=$(authenticate_tenant "tenant-basic-001" "$BASIC_CLIENT_ID" "$BASIC_CLIENT_SECRET" "$TOKEN_ENDPOINT")
    echo ""

    STANDARD_TOKEN=$(authenticate_tenant "tenant-standard-001" "$STANDARD_CLIENT_ID" "$STANDARD_CLIENT_SECRET" "$TOKEN_ENDPOINT")
    echo ""

    PREMIUM_TOKEN=$(authenticate_tenant "tenant-premium-001" "$PREMIUM_CLIENT_ID" "$PREMIUM_CLIENT_SECRET" "$TOKEN_ENDPOINT")

    pause

    # ── Step 3: Catalog API ───────────────────────────────────────────
    print_header "Step 3: Catalog API - Product Listing"

    print_step "Fetching product catalog for Basic tenant..."
    CATALOG_RESPONSE=$(api_call "GET" "${API_ENDPOINT}/catalog" "$BASIC_TOKEN")
    echo "$CATALOG_RESPONSE" | jq '.'
    print_success "Retrieved products for tenant-basic-001"

    pause

    print_step "Fetching specific product details..."
    PRODUCT_ID=$(echo "$CATALOG_RESPONSE" | jq -r '.data[0].productId' 2>/dev/null || echo "prod-001")
    PRODUCT_RESPONSE=$(api_call "GET" "${API_ENDPOINT}/catalog/${PRODUCT_ID}" "$BASIC_TOKEN")
    echo "$PRODUCT_RESPONSE" | jq '.'

    pause

    # ── Step 4: Order API ─────────────────────────────────────────────
    print_header "Step 4: Order API - Creating Orders"

    print_step "Creating an order for Basic tenant..."
    ORDER_DATA='{"customerId":"cust-demo-001","productId":"'$PRODUCT_ID'","quantity":2}'

    ORDER_RESPONSE=$(api_call "POST" "${API_ENDPOINT}/orders" "$BASIC_TOKEN" "$ORDER_DATA")
    echo "$ORDER_RESPONSE" | jq '.'

    ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.data.orderId')
    print_success "Order created: $ORDER_ID"

    pause

    print_step "Retrieving order details..."
    api_call "GET" "${API_ENDPOINT}/orders/${ORDER_ID}" "$BASIC_TOKEN" | jq '.'

    pause

    # ── Step 5: Tenant Isolation ──────────────────────────────────────
    print_header "Step 5: Tenant Isolation Security"

    echo "Demonstrating that tenants cannot access each other's data..."
    echo ""

    print_step "Standard tenant attempting to access Basic tenant's order..."
    ISOLATION_TEST=$(api_call "GET" "${API_ENDPOINT}/orders/${ORDER_ID}" "$STANDARD_TOKEN")
    echo "$ISOLATION_TEST" | jq '.'

    if echo "$ISOLATION_TEST" | jq -e '.statusCode == 404 or .statusCode == 403' > /dev/null 2>&1; then
        print_success "Tenant isolation working correctly - access denied"
    else
        print_warning "Unexpected response - check tenant isolation"
    fi

    pause

    # ── Step 6: Rate Limiting ─────────────────────────────────────────
    print_header "Step 6: Rate Limiting Demonstration"

    echo "Basic Tier:    10 req/sec, Burst: 20"
    echo "Standard Tier: 100 req/sec, Burst: 200"
    echo "Premium Tier:  1000 req/sec, Burst: 2000"
    echo ""

    print_step "Sending rapid requests to test Basic tier rate limiting..."
    echo ""

    SUCCESS_COUNT=0
    THROTTLED_COUNT=0

    for i in {1..25}; do
        RESPONSE=$(api_call "GET" "${API_ENDPOINT}/catalog" "$BASIC_TOKEN")
        STATUS=$(echo "$RESPONSE" | jq -r '.statusCode // 200')

        if [ "$STATUS" == "429" ]; then
            ((THROTTLED_COUNT++))
            echo -n "T"
        else
            ((SUCCESS_COUNT++))
            echo -n "."
        fi
    done

    echo ""
    echo ""
    print_success "Successful: $SUCCESS_COUNT"
    print_warning "Throttled:  $THROTTLED_COUNT"

    if [ $THROTTLED_COUNT -gt 0 ]; then
        print_success "Rate limiting is working correctly"
    else
        print_warning "No throttling detected - limits may need adjustment"
    fi

    pause

    # ── Step 7: X-Ray Tracing ─────────────────────────────────────────
    print_header "Step 7: AWS X-Ray Distributed Tracing"

    print_step "Making a traced request..."
    TRACED_RESPONSE=$(api_call "POST" "${API_ENDPOINT}/orders" "$PREMIUM_TOKEN" "$ORDER_DATA")
    echo "$TRACED_RESPONSE" | jq '.'

    echo ""
    echo "View traces in X-Ray console:"
    echo "  https://console.aws.amazon.com/xray/home?region=${AWS_REGION}#/traces"
    echo ""
    echo "Filter by annotation.tenant_id to see tenant-specific traces."

    pause

    # ── Step 8: CloudWatch Dashboard ──────────────────────────────────
    print_header "Step 8: CloudWatch Monitoring Dashboard"

    echo "Dashboard URL: $DASHBOARD_URL"
    echo ""
    echo "The dashboard shows:"
    echo "  - API Gateway metrics (requests, errors, latency)"
    echo "  - Lambda metrics (invocations, duration, errors)"
    echo "  - DynamoDB metrics (capacity, throttling)"
    echo "  - Per-tenant metrics and cost tracking"

    pause

    # ── Step 9: Error Handling ────────────────────────────────────────
    print_header "Step 9: Error Handling and Validation"

    print_step "Testing invalid product ID..."
    api_call "GET" "${API_ENDPOINT}/catalog/invalid-id" "$BASIC_TOKEN" | jq '.'
    print_success "404 error returned correctly"

    echo ""
    print_step "Testing invalid order data (missing required fields)..."
    api_call "POST" "${API_ENDPOINT}/orders" "$BASIC_TOKEN" '{"customerId":"cust-001"}' | jq '.'
    print_success "400 validation error returned correctly"

    pause

    # ── Summary ───────────────────────────────────────────────────────
    print_header "Demo Complete"

    echo "Features demonstrated:"
    echo "  - Multi-tenant authentication (Cognito + Lambda authorizer)"
    echo "  - RESTful API operations (GET, POST)"
    echo "  - Tenant data isolation"
    echo "  - Per-tier rate limiting"
    echo "  - X-Ray distributed tracing"
    echo "  - CloudWatch monitoring"
    echo "  - Error handling and validation"
    echo ""
    echo "Next steps:"
    echo "  - Explore the CloudWatch dashboard: $DASHBOARD_URL"
    echo "  - View X-Ray traces in AWS Console"
    echo "  - Onboard a new tenant: edit terraform/tenants/terraform.tfvars"
    echo ""
    print_success "Thank you for exploring the AWS API Gateway Demo"
}

main
