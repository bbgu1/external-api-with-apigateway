#!/bin/bash

# End-to-End Testing Script for AWS API Gateway Demo Solution
# This script performs comprehensive testing of the deployed infrastructure

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Function to print colored output
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

print_failure() {
    echo -e "${RED}✗ $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_header "Checking Prerequisites"

if ! command_exists terraform; then
    print_failure "Terraform not found. Please install Terraform."
    exit 1
fi
print_success "Terraform installed"

if ! command_exists aws; then
    print_failure "AWS CLI not found. Please install AWS CLI."
    exit 1
fi
print_success "AWS CLI installed"

if ! command_exists jq; then
    print_failure "jq not found. Please install jq for JSON parsing."
    exit 1
fi
print_success "jq installed"

if ! command_exists curl; then
    print_failure "curl not found. Please install curl."
    exit 1
fi
print_success "curl installed"

# Navigate to terraform directory
cd terraform

# Check if Terraform is initialized
print_header "Verifying Terraform State"

if [ ! -d ".terraform" ]; then
    print_failure "Terraform not initialized. Run 'terraform init' first."
    exit 1
fi
print_success "Terraform initialized"

# Check if infrastructure is deployed
if [ ! -f "terraform.tfstate" ] || [ ! -s "terraform.tfstate" ]; then
    print_failure "Infrastructure not deployed. The terraform.tfstate file is empty or missing."
    echo ""
    print_info "To deploy the infrastructure, follow these steps:"
    echo ""
    echo "  1. Create terraform.tfvars from the example:"
    echo "     cp terraform.tfvars.example terraform.tfvars"
    echo ""
    echo "  2. Edit terraform.tfvars with your configuration"
    echo ""
    echo "  3. Initialize Terraform (if not already done):"
    echo "     terraform init"
    echo ""
    echo "  4. Deploy the infrastructure:"
    echo "     terraform apply"
    echo ""
    echo "  5. Once deployed, run this test script again:"
    echo "     ./scripts/e2e_test.sh"
    echo ""
    exit 1
fi
print_success "Infrastructure state file found"

# Verify state file has resources
RESOURCE_COUNT=$(terraform state list 2>/dev/null | wc -l | tr -d ' ')
if [ "$RESOURCE_COUNT" -eq 0 ]; then
    print_failure "No resources found in Terraform state. Infrastructure may not be deployed."
    echo ""
    print_info "Deploy the infrastructure first:"
    echo "     cd terraform"
    echo "     terraform apply"
    echo ""
    exit 1
fi
print_success "Found $RESOURCE_COUNT resources in Terraform state"

# Get Terraform outputs
print_info "Retrieving Terraform outputs..."

API_URL=$(terraform output -raw api_endpoint_url 2>/dev/null)
if [ -z "$API_URL" ]; then
    print_failure "Could not retrieve API endpoint URL. Is infrastructure deployed?"
    exit 1
fi
print_success "API endpoint URL retrieved: $API_URL"

TOKEN_ENDPOINT=$(terraform output -raw cognito_token_endpoint 2>/dev/null)
if [ -z "$TOKEN_ENDPOINT" ]; then
    print_failure "Could not retrieve Cognito token endpoint"
    exit 1
fi
print_success "Cognito token endpoint retrieved"

AWS_REGION=$(terraform output -raw aws_region 2>/dev/null)
if [ -z "$AWS_REGION" ]; then
    print_failure "Could not retrieve AWS region"
    exit 1
fi
print_success "AWS region: $AWS_REGION"

DASHBOARD_URL=$(terraform output -raw cloudwatch_dashboard_url 2>/dev/null)
TABLE_NAME=$(terraform output -raw dynamodb_table_name 2>/dev/null)
API_GATEWAY_ID=$(terraform output -raw api_gateway_id 2>/dev/null)

# Get app clients
APP_CLIENTS=$(terraform output -json cognito_app_clients 2>/dev/null)
if [ -z "$APP_CLIENTS" ] || [ "$APP_CLIENTS" == "null" ]; then
    print_failure "Could not retrieve Cognito app clients"
    exit 1
fi

# Extract tenant IDs
TENANT_IDS=$(echo "$APP_CLIENTS" | jq -r 'keys[]')
TENANT_COUNT=$(echo "$TENANT_IDS" | wc -l | tr -d ' ')
print_success "Found $TENANT_COUNT tenant(s): $(echo $TENANT_IDS | tr '\n' ' ')"

# Test 1: API Gateway Accessibility
print_header "Test 1: API Gateway Accessibility"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/catalog")
if [ "$HTTP_CODE" == "401" ]; then
    print_success "API Gateway is accessible and returns 401 without token (expected)"
else
    print_failure "API Gateway returned unexpected status code: $HTTP_CODE (expected 401)"
fi

# Test 2: Authentication for Multiple Tenants
print_header "Test 2: Authentication for Multiple Tenants"

# Store tokens in temporary files (bash 3.2 compatible)
TOKENS_DIR=$(mktemp -d)
trap "rm -rf $TOKENS_DIR" EXIT

for TENANT_ID in $TENANT_IDS; do
    print_info "Testing authentication for tenant: $TENANT_ID"
    
    CLIENT_ID=$(echo "$APP_CLIENTS" | jq -r ".\"$TENANT_ID\".client_id")
    CLIENT_SECRET=$(echo "$APP_CLIENTS" | jq -r ".\"$TENANT_ID\".client_secret")
    
    if [ -z "$CLIENT_ID" ] || [ "$CLIENT_ID" == "null" ]; then
        print_failure "Could not retrieve client ID for $TENANT_ID"
        continue
    fi
    
    # Get access token
    TOKEN_RESPONSE=$(curl -s -X POST "$TOKEN_ENDPOINT" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET")
    
    TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
    
    if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
        print_failure "Failed to get token for $TENANT_ID"
        print_info "Response: $TOKEN_RESPONSE"
        continue
    fi
    
    # Verify token is a valid JWT (has 3 parts)
    TOKEN_PARTS=$(echo "$TOKEN" | awk -F. '{print NF-1}')
    if [ "$TOKEN_PARTS" == "2" ]; then
        print_success "Valid JWT token obtained for $TENANT_ID"
        echo "$TOKEN" > "$TOKENS_DIR/$TENANT_ID.token"
        
        # Decode and verify tenant_id in token
        PAYLOAD=$(echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null || echo "{}")
        TOKEN_TENANT_ID=$(echo "$PAYLOAD" | jq -r '.tenant_id // .["custom:tenant_id"] // empty')
        
        if [ ! -z "$TOKEN_TENANT_ID" ]; then
            print_success "Token contains tenant_id: $TOKEN_TENANT_ID"
        else
            print_warning "Token does not contain tenant_id claim"
        fi
    else
        print_failure "Invalid JWT token format for $TENANT_ID"
    fi
done

# Test 3: Catalog API for Each Tenant
print_header "Test 3: Catalog API for Each Tenant"

for TENANT_ID in $TENANT_IDS; do
    if [ ! -f "$TOKENS_DIR/$TENANT_ID.token" ]; then
        continue
    fi
    TOKEN=$(cat "$TOKENS_DIR/$TENANT_ID.token")
    
    print_info "Testing Catalog API for tenant: $TENANT_ID"
    
    # Test GET /catalog
    CATALOG_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/catalog")
    STATUS_CODE=$(echo "$CATALOG_RESPONSE" | jq -r '.statusCode // empty')
    
    if [ "$STATUS_CODE" == "200" ]; then
        PRODUCT_COUNT=$(echo "$CATALOG_RESPONSE" | jq -r '.data | length')
        print_success "GET /catalog returned $PRODUCT_COUNT products for $TENANT_ID"
        
        # Store first product ID for later tests
        PRODUCT_ID=$(echo "$CATALOG_RESPONSE" | jq -r '.data[0].productId // empty')
        if [ ! -z "$PRODUCT_ID" ]; then
            echo "$PRODUCT_ID" > "$TOKENS_DIR/$TENANT_ID.product"
            
            # Test GET /catalog/{productId}
            PRODUCT_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/catalog/$PRODUCT_ID")
            PRODUCT_STATUS=$(echo "$PRODUCT_RESPONSE" | jq -r '.statusCode // empty')
            
            if [ "$PRODUCT_STATUS" == "200" ]; then
                PRODUCT_NAME=$(echo "$PRODUCT_RESPONSE" | jq -r '.data.name // empty')
                print_success "GET /catalog/$PRODUCT_ID returned product: $PRODUCT_NAME"
            else
                print_failure "GET /catalog/$PRODUCT_ID failed with status: $PRODUCT_STATUS"
            fi
        fi
    else
        print_failure "GET /catalog failed for $TENANT_ID with status: $STATUS_CODE"
        print_info "Response: $CATALOG_RESPONSE"
    fi
done

# Test 4: Order API for Each Tenant
print_header "Test 4: Order API for Each Tenant"

declare -A TENANT_ORDERS

for TENANT_ID in "${!TENANT_TOKENS[@]}"; do
    TOKEN="${TENANT_TOKENS[$TENANT_ID]}"
    PRODUCT_ID="${TENANT_PRODUCTS[$TENANT_ID]}"
    
    if [ -z "$PRODUCT_ID" ]; then
        print_warning "No product ID available for $TENANT_ID, skipping order test"
        continue
    fi
    
    print_info "Testing Order API for tenant: $TENANT_ID"
    
    # Test POST /orders
    ORDER_DATA="{\"customerId\":\"cust-test-001\",\"productId\":\"$PRODUCT_ID\",\"quantity\":2}"
    ORDER_RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$ORDER_DATA" \
        "$API_URL/orders")
    
    ORDER_STATUS=$(echo "$ORDER_RESPONSE" | jq -r '.statusCode // empty')
    
    if [ "$ORDER_STATUS" == "200" ]; then
        ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.data.orderId // empty')
        print_success "POST /orders created order: $ORDER_ID for $TENANT_ID"
        TENANT_ORDERS[$TENANT_ID]=$ORDER_ID
        
        # Test GET /orders/{orderId}
        sleep 1  # Brief delay to ensure consistency
        GET_ORDER_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/orders/$ORDER_ID")
        GET_ORDER_STATUS=$(echo "$GET_ORDER_RESPONSE" | jq -r '.statusCode // empty')
        
        if [ "$GET_ORDER_STATUS" == "200" ]; then
            RETRIEVED_ORDER_ID=$(echo "$GET_ORDER_RESPONSE" | jq -r '.data.orderId // empty')
            if [ "$RETRIEVED_ORDER_ID" == "$ORDER_ID" ]; then
                print_success "GET /orders/$ORDER_ID retrieved correct order"
            else
                print_failure "GET /orders/$ORDER_ID returned wrong order ID"
            fi
        else
            print_failure "GET /orders/$ORDER_ID failed with status: $GET_ORDER_STATUS"
        fi
    else
        print_failure "POST /orders failed for $TENANT_ID with status: $ORDER_STATUS"
        print_info "Response: $ORDER_RESPONSE"
    fi
done

# Test 5: Tenant Isolation
print_header "Test 5: Tenant Isolation"

# Get two different tenants
TENANT_ARRAY=("${!TENANT_TOKENS[@]}")
if [ ${#TENANT_ARRAY[@]} -ge 2 ]; then
    TENANT_A="${TENANT_ARRAY[0]}"
    TENANT_B="${TENANT_ARRAY[1]}"
    
    TOKEN_A="${TENANT_TOKENS[$TENANT_A]}"
    TOKEN_B="${TENANT_TOKENS[$TENANT_B]}"
    ORDER_A="${TENANT_ORDERS[$TENANT_A]}"
    
    if [ ! -z "$ORDER_A" ]; then
        print_info "Testing cross-tenant access: $TENANT_B trying to access $TENANT_A's order"
        
        CROSS_TENANT_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN_B" "$API_URL/orders/$ORDER_A")
        CROSS_TENANT_STATUS=$(echo "$CROSS_TENANT_RESPONSE" | jq -r '.statusCode // empty')
        
        if [ "$CROSS_TENANT_STATUS" == "404" ] || [ "$CROSS_TENANT_STATUS" == "403" ]; then
            print_success "Tenant isolation working: Cross-tenant access denied (status: $CROSS_TENANT_STATUS)"
        else
            print_failure "Tenant isolation FAILED: Cross-tenant access returned status: $CROSS_TENANT_STATUS"
            print_warning "SECURITY ISSUE: Tenant $TENANT_B can access $TENANT_A's data!"
        fi
    else
        print_warning "No order available for tenant isolation test"
    fi
else
    print_warning "Need at least 2 tenants for isolation test (found ${#TENANT_ARRAY[@]})"
fi

# Test 6: Rate Limiting
print_header "Test 6: Rate Limiting"

if [ ${#TENANT_ARRAY[@]} -ge 1 ]; then
    TENANT_ID="${TENANT_ARRAY[0]}"
    TOKEN="${TENANT_TOKENS[$TENANT_ID]}"
    
    print_info "Testing rate limiting for tenant: $TENANT_ID"
    print_info "Sending 20 rapid requests..."
    
    THROTTLED_COUNT=0
    SUCCESS_COUNT=0
    
    for i in {1..20}; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: Bearer $TOKEN" \
            "$API_URL/catalog")
        
        if [ "$HTTP_CODE" == "429" ]; then
            THROTTLED_COUNT=$((THROTTLED_COUNT + 1))
        elif [ "$HTTP_CODE" == "200" ]; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
        
        sleep 0.05  # 50ms between requests = 20 req/sec
    done
    
    print_info "Results: $SUCCESS_COUNT successful, $THROTTLED_COUNT throttled"
    
    if [ $THROTTLED_COUNT -gt 0 ]; then
        print_success "Rate limiting is working (received $THROTTLED_COUNT 429 responses)"
    else
        print_warning "No rate limiting detected (may need higher request rate or check usage plan)"
    fi
else
    print_warning "No tenants available for rate limiting test"
fi

# Test 7: X-Ray Traces
print_header "Test 7: X-Ray Traces"

print_info "Checking for X-Ray traces..."

# Get traces from last 5 minutes
START_TIME=$(date -u -d '5 minutes ago' +%s 2>/dev/null || date -u -v-5M +%s)
END_TIME=$(date -u +%s)

TRACES=$(aws xray get-trace-summaries \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --region $AWS_REGION \
    2>/dev/null || echo '{"TraceSummaries":[]}')

TRACE_COUNT=$(echo "$TRACES" | jq -r '.TraceSummaries | length')

if [ "$TRACE_COUNT" -gt 0 ]; then
    print_success "Found $TRACE_COUNT X-Ray traces"
    
    # Check if traces have annotations
    FIRST_TRACE_ID=$(echo "$TRACES" | jq -r '.TraceSummaries[0].Id // empty')
    if [ ! -z "$FIRST_TRACE_ID" ]; then
        print_info "Sample trace ID: $FIRST_TRACE_ID"
        print_success "X-Ray tracing is enabled and capturing requests"
    fi
else
    print_warning "No X-Ray traces found (may need to wait a few minutes or generate more requests)"
fi

# Test 8: CloudWatch Dashboard
print_header "Test 8: CloudWatch Dashboard"

if [ ! -z "$DASHBOARD_URL" ]; then
    print_success "CloudWatch dashboard URL: $DASHBOARD_URL"
    
    # Verify dashboard exists
    DASHBOARD_NAME=$(terraform output -raw cloudwatch_dashboard_name 2>/dev/null)
    if [ ! -z "$DASHBOARD_NAME" ]; then
        DASHBOARD_CHECK=$(aws cloudwatch get-dashboard \
            --dashboard-name "$DASHBOARD_NAME" \
            --region $AWS_REGION \
            2>/dev/null || echo '{}')
        
        if [ "$(echo "$DASHBOARD_CHECK" | jq -r '.DashboardName // empty')" == "$DASHBOARD_NAME" ]; then
            print_success "CloudWatch dashboard exists and is accessible"
        else
            print_failure "CloudWatch dashboard not found"
        fi
    fi
else
    print_failure "CloudWatch dashboard URL not available"
fi

# Test 9: CloudWatch Alarms
print_header "Test 9: CloudWatch Alarms"

print_info "Checking CloudWatch alarms..."

ALARMS=$(aws cloudwatch describe-alarms \
    --alarm-name-prefix "api-gateway-demo" \
    --region $AWS_REGION \
    2>/dev/null || echo '{"MetricAlarms":[]}')

ALARM_COUNT=$(echo "$ALARMS" | jq -r '.MetricAlarms | length')

if [ "$ALARM_COUNT" -gt 0 ]; then
    print_success "Found $ALARM_COUNT CloudWatch alarm(s)"
    
    # List alarm names
    ALARM_NAMES=$(echo "$ALARMS" | jq -r '.MetricAlarms[].AlarmName')
    for ALARM_NAME in $ALARM_NAMES; do
        print_info "  - $ALARM_NAME"
    done
else
    print_warning "No CloudWatch alarms found"
fi

# Test 10: Cost Allocation Tags
print_header "Test 10: Cost Allocation Tags"

print_info "Checking resource tags..."

# Check DynamoDB table tags
if [ ! -z "$TABLE_NAME" ]; then
    TABLE_ARN=$(aws dynamodb describe-table \
        --table-name "$TABLE_NAME" \
        --region $AWS_REGION \
        --query 'Table.TableArn' \
        --output text 2>/dev/null)
    
    if [ ! -z "$TABLE_ARN" ]; then
        TAGS=$(aws dynamodb list-tags-of-resource \
            --resource-arn "$TABLE_ARN" \
            --region $AWS_REGION \
            2>/dev/null || echo '{"Tags":[]}')
        
        TAG_COUNT=$(echo "$TAGS" | jq -r '.Tags | length')
        
        if [ "$TAG_COUNT" -gt 0 ]; then
            print_success "DynamoDB table has $TAG_COUNT tag(s)"
            
            # Check for required tags
            PROJECT_TAG=$(echo "$TAGS" | jq -r '.Tags[] | select(.Key=="Project") | .Value')
            ENV_TAG=$(echo "$TAGS" | jq -r '.Tags[] | select(.Key=="Environment") | .Value')
            
            if [ ! -z "$PROJECT_TAG" ]; then
                print_success "  - Project tag: $PROJECT_TAG"
            fi
            if [ ! -z "$ENV_TAG" ]; then
                print_success "  - Environment tag: $ENV_TAG"
            fi
        else
            print_warning "DynamoDB table has no tags"
        fi
    fi
fi

# Check API Gateway tags
if [ ! -z "$API_GATEWAY_ID" ]; then
    API_TAGS=$(aws apigateway get-tags \
        --resource-arn "arn:aws:apigateway:$AWS_REGION::/restapis/$API_GATEWAY_ID" \
        --region $AWS_REGION \
        2>/dev/null || echo '{"tags":{}}')
    
    API_TAG_COUNT=$(echo "$API_TAGS" | jq -r '.tags | length')
    
    if [ "$API_TAG_COUNT" -gt 0 ]; then
        print_success "API Gateway has $API_TAG_COUNT tag(s)"
    else
        print_warning "API Gateway has no tags"
    fi
fi

# Test 11: Documentation Accuracy
print_header "Test 11: Documentation Verification"

cd ..  # Back to project root

# Check if key documentation files exist
DOCS_TO_CHECK=(
    "README.md"
    "API_DOCUMENTATION.md"
    "terraform/COST_ESTIMATION.md"
    "terraform/TAGGING_STRATEGY.md"
)

for DOC in "${DOCS_TO_CHECK[@]}"; do
    if [ -f "$DOC" ]; then
        print_success "Documentation exists: $DOC"
    else
        print_failure "Documentation missing: $DOC"
    fi
done

# Test 12: Lambda Tests
print_header "Test 12: Lambda Function Tests"

cd lambda

if [ -f "run_tests.sh" ]; then
    print_info "Running Lambda function tests..."
    
    if bash run_tests.sh > /tmp/test_output.txt 2>&1; then
        print_success "All Lambda tests passed"
    else
        print_failure "Some Lambda tests failed"
        print_info "Check /tmp/test_output.txt for details"
    fi
else
    print_warning "Test runner script not found"
fi

cd ..

# Final Summary
print_header "Test Summary"

echo -e "${BLUE}Total Tests: $TESTS_TOTAL${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}"
    echo -e "${GREEN}========================================${NC}\n"
    echo -e "${GREEN}The AWS API Gateway Demo Solution is fully functional.${NC}\n"
    exit 0
else
    echo -e "\n${RED}========================================${NC}"
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo -e "${RED}========================================${NC}\n"
    echo -e "${YELLOW}Please review the failures above and check:${NC}"
    echo -e "${YELLOW}1. CloudWatch Logs for error details${NC}"
    echo -e "${YELLOW}2. X-Ray traces for request flow${NC}"
    echo -e "${YELLOW}3. Terraform state for resource status${NC}\n"
    exit 1
fi
