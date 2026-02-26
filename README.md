# AWS API Gateway Demo Solution

A comprehensive serverless API solution demonstrating AWS API Gateway with multi-tenant support, JWT authentication, rate limiting, and full observability using AWS managed services.

## Architecture Overview

This solution showcases:
- **API Gateway**: RESTful API management with Lambda authorizer
- **AWS Cognito**: Machine-to-machine (M2M) authentication with OAuth 2.0
- **AWS Lambda**: Serverless compute for business logic and authorization
- **DynamoDB**: NoSQL database with multi-tenant data isolation
- **AWS X-Ray**: Distributed tracing across all services
- **CloudWatch**: Application monitoring with custom dashboards
- **Multi-tenancy**: Tenant-level rate limiting and data isolation
- **Infrastructure as Code**: Complete Terraform deployment with separate tenant lifecycle

## Project Structure

```
.
├── terraform/                  # Core infrastructure (Terraform)
│   ├── main.tf                # Main configuration
│   ├── variables.tf           # Input variables
│   ├── outputs.tf             # Output values
│   ├── backend.tfvars.example # Backend config template
│   ├── terraform.tfvars       # Variables (environment-specific)
│   └── modules/               # Terraform modules
│       ├── api-gateway/       # API Gateway + Lambda authorizer
│       ├── cognito/           # Cognito user pool
│       ├── dynamodb/          # DynamoDB table
│       ├── lambda/            # Lambda functions + authorizer
│       └── cloudwatch/        # Monitoring dashboard
├── terraform/tenants/          # Tenant lifecycle (separate state)
│   ├── main.tf                # Tenant resources
│   ├── variables.tf           # Tenant variables
│   ├── outputs.tf             # Tenant credentials
│   └── terraform.tfvars.example
├── lambda/                    # Lambda function code
│   ├── shared/                # Shared layer (lambda_base.py)
│   ├── authorizer/            # Lambda authorizer (JWT + SSM)
│   ├── catalog/               # Catalog API
│   └── order/                 # Order API
├── scripts/                   # Utility scripts
└── .kiro/                     # Kiro configuration
```

## Prerequisites

### Required Software

- **AWS Account**: Active AWS account with permissions to create API Gateway, Lambda, DynamoDB, Cognito, CloudWatch, X-Ray, SSM, and IAM resources
- **Terraform**: Version >= 1.0 ([Download](https://www.terraform.io/downloads.html))
  ```bash
  terraform version
  ```
- **AWS CLI**: Version 2.x configured with credentials ([Install Guide](https://aws.amazon.com/cli/))
  ```bash
  aws --version
  aws configure
  ```
- **Python**: Version 3.9 or higher
  ```bash
  python3 --version
  ```
- **jq**: JSON processor ([Install Guide](https://stedolan.github.io/jq/))
  ```bash
  brew install jq   # macOS
  ```

## Quick Start

### Step 1: Clone and Navigate

```bash
cd external-api-with-apigateway
```

### Step 2: Configure Core Infrastructure

```bash
cd terraform
```

Edit `terraform.tfvars` with your configuration:
```hcl
aws_region  = "us-east-1"
environment = "dev"
```

### Step 3: Deploy Core Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

Deployment typically takes 3-5 minutes. This creates the API Gateway, Cognito user pool, DynamoDB table, Lambda functions (including the authorizer), CloudWatch dashboard, and empty SSM parameters for tenant mappings.

### Step 4: Capture Core Outputs

```bash
export API_URL=$(terraform output -raw api_endpoint_url)
export TOKEN_ENDPOINT=$(terraform output -raw cognito_token_endpoint)
echo "API Endpoint: $API_URL"
echo "Token Endpoint: $TOKEN_ENDPOINT"
```

### Step 5: Seed Sample Data (Optional)

```bash
cd ..
./scripts/seed_data.sh
```

### Step 6: Onboard Tenants

Tenants are managed in a separate Terraform workspace with its own state:

```bash
cd terraform/tenants
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars to define your tenants
terraform init
terraform apply
```

This creates per-tenant Cognito app clients, API keys, usage plans, and populates the SSM parameters that the Lambda authorizer reads at runtime.

### Step 7: Get Tenant Credentials

```bash
# From terraform/tenants directory
terraform output -json cognito_client_ids
terraform output -json cognito_client_secrets
```

### Step 8: Test the API

```bash
# Get a token for a tenant
CLIENT_ID=$(terraform output -json cognito_client_ids | jq -r '.["tenant-basic-001"]')
CLIENT_SECRET=$(terraform output -json cognito_client_secrets | jq -r '.["tenant-basic-001"]')

TOKEN_ENDPOINT=$(cd ../.. && cd terraform && terraform output -raw cognito_token_endpoint)
API_URL=$(cd ../.. && cd terraform && terraform output -raw api_endpoint_url)

TOKEN=$(curl -s -X POST "$TOKEN_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&scope=api/read" \
  | jq -r '.access_token')

# Call the API
curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/catalog" | jq
```

## Tenant Management

Tenants are managed in a separate Terraform workspace (`terraform/tenants/`) with its own state file. This allows onboarding and offboarding tenants without touching core infrastructure.

### How It Works

1. The core infrastructure creates empty SSM parameters for tenant mappings
2. The tenants workspace creates per-tenant Cognito app clients, API keys, and usage plans
3. The tenants workspace writes tenant mappings to SSM parameters
4. The Lambda authorizer reads SSM at runtime to resolve `client_id → tenant_id` and `tenant_id → API key value`

### Onboard a New Tenant

Add the tenant to `terraform/tenants/terraform.tfvars`:

```hcl
tenants = {
  # Existing tenants...
  "tenant-basic-001" = {
    tier = "basic"
  }
  # Add a new premium tenant:
  "tenant-acme-corp" = {
    tier = "premium"
  }
}
```

Then apply:

```bash
cd terraform/tenants
terraform apply
```

The new tenant's Cognito credentials will appear in the outputs:

```bash
terraform output -json cognito_client_ids | jq -r '.["tenant-acme-corp"]'
terraform output -json cognito_client_secrets | jq -r '.["tenant-acme-corp"]'
```

### Offboard a Tenant

Remove the tenant from `terraform/tenants/terraform.tfvars` and apply:

```bash
cd terraform/tenants
terraform apply
```

### Tier Configuration

Three tiers are available, configured in `terraform/tenants/terraform.tfvars`:

| Tier | Rate Limit | Burst | Monthly Quota |
|------|-----------|-------|---------------|
| Basic | 10 req/sec | 20 | 100,000 |
| Standard | 100 req/sec | 200 | 1,000,000 |
| Premium | 1,000 req/sec | 2,000 | 10,000,000 |

## API Endpoints

### Authentication

Get a JWT token using OAuth 2.0 client credentials flow:

```bash
TOKEN_ENDPOINT=$(cd terraform && terraform output -raw cognito_token_endpoint)

TOKEN=$(curl -s -X POST "$TOKEN_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&scope=api/read" \
  | jq -r '.access_token')
```

### Catalog API

```bash
API_URL=$(cd terraform && terraform output -raw api_endpoint_url)

# List all products
curl -H "Authorization: Bearer $TOKEN" "$API_URL/catalog"

# Get specific product
curl -H "Authorization: Bearer $TOKEN" "$API_URL/catalog/prod-001"
```

### Order API

```bash
# Create an order
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"customerId":"cust-123","productId":"prod-001","quantity":2}' \
  "$API_URL/orders"

# Get order details
curl -H "Authorization: Bearer $TOKEN" "$API_URL/orders/ORDER_ID"
```

### Testing with Multiple Tenants

```bash
# Get credentials from the tenants workspace
cd terraform/tenants
TENANT_IDS=$(terraform output -json cognito_client_ids)
TENANT_SECRETS=$(terraform output -json cognito_client_secrets)
cd ../../

TOKEN_ENDPOINT=$(cd terraform && terraform output -raw cognito_token_endpoint)
API_URL=$(cd terraform && terraform output -raw api_endpoint_url)

# Tenant 1 (Basic tier)
CLIENT_ID_1=$(echo $TENANT_IDS | jq -r '.["tenant-basic-001"]')
CLIENT_SECRET_1=$(echo $TENANT_SECRETS | jq -r '.["tenant-basic-001"]')
TOKEN_1=$(curl -s -X POST "$TOKEN_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=$CLIENT_ID_1&client_secret=$CLIENT_SECRET_1&scope=api/read" \
  | jq -r '.access_token')

# Tenant 2 (Standard tier)
CLIENT_ID_2=$(echo $TENANT_IDS | jq -r '.["tenant-standard-001"]')
CLIENT_SECRET_2=$(echo $TENANT_SECRETS | jq -r '.["tenant-standard-001"]')
TOKEN_2=$(curl -s -X POST "$TOKEN_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=$CLIENT_ID_2&client_secret=$CLIENT_SECRET_2&scope=api/read" \
  | jq -r '.access_token')

# Test with different tenants
curl -H "Authorization: Bearer $TOKEN_1" "$API_URL/catalog"  # Tenant 1 data
curl -H "Authorization: Bearer $TOKEN_2" "$API_URL/catalog"  # Tenant 2 data
```

## Monitoring and Observability

### CloudWatch Dashboard

```bash
terraform output -raw cloudwatch_dashboard_url
```

Dashboard includes API Gateway metrics, Lambda metrics, DynamoDB metrics, and per-tenant breakdowns.

### X-Ray Tracing

```bash
REGION=$(cd terraform && terraform output -raw aws_region)
echo "https://console.aws.amazon.com/xray/home?region=$REGION#/service-map"
```

Filter traces by `annotation.tenant_id` to see tenant-specific request flows.

### CloudWatch Logs

```bash
# Tail catalog function logs
aws logs tail "/aws/lambda/api-gateway-demo-dev-catalog" --follow --region us-east-1
```

All logs use structured JSON format with `tenant_id` and `request_id` fields.

## Security Considerations

- All API endpoints use HTTPS only
- JWT tokens expire after 1 hour
- Lambda authorizer validates JWT signature against Cognito JWKS
- Tenant ID resolved from `client_id` via SSM mapping (not from JWT claims directly)
- Lambda functions use IAM roles with least privilege
- Sensitive credentials stored in SSM Parameter Store (SecureString)
- Multi-tenant data isolation at DynamoDB partition key level
- Cross-tenant access attempts logged as security violations and return 403/404
- Rate limiting enforced via API Gateway usage plans per tenant tier

## Development

### Running Tests

```bash
cd lambda
source venv/bin/activate  # If using virtual environment

# Run catalog tests
cd catalog
python -m pytest test_catalog.py -v

# Run order tests
cd ../order
python -m pytest test_order.py -v

# Run shared module tests
cd ../shared
python -m pytest test_lambda_base.py -v
```

### Test Individual Components

```bash
# Test Lambda function directly (bypass API Gateway)
aws lambda invoke \
  --function-name api-gateway-demo-dev-catalog \
  --payload '{"requestContext":{"authorizer":{"tenant_id":"tenant-basic-001"}},"httpMethod":"GET","path":"/catalog"}' \
  --region us-east-1 \
  response.json

cat response.json | jq
```

## Cleanup

Destroy the tenants workspace first, then core infrastructure:

```bash
# 1. Destroy tenant resources first
cd terraform/tenants
terraform destroy

# 2. Destroy core infrastructure
cd ../
terraform destroy
```

**Warning**: This permanently deletes all data in DynamoDB, CloudWatch logs, Cognito user pool, and all other resources.

## Troubleshooting

### API Gateway Returns 401 Unauthorized

- Token may be expired (1-hour TTL). Re-authenticate.
- Verify the Lambda authorizer can reach Cognito JWKS endpoint.
- Check authorizer CloudWatch logs: `/aws/lambda/api-gateway-demo-dev-authorizer`

### API Gateway Returns 403 Forbidden

- The Lambda authorizer denied the request. Check if:
  - The `client_id` in the JWT has a mapping in the SSM `client-tenant-map` parameter
  - The resolved `tenant_id` has an API key in the SSM `tenant-api-key-map` parameter
- For cross-tenant data access, 403/404 is expected behavior.

### Rate Limiting Returns 429

- Check the tenant's tier and associated usage plan limits.
- Usage plans are managed in `terraform/tenants/`.

### No Tenant Mapping Found

- Ensure `terraform apply` was run in `terraform/tenants/` after adding the tenant.
- Verify SSM parameters are populated: check in AWS Console under Systems Manager > Parameter Store.

## Support

For issues or questions, refer to the AWS documentation:
- [API Gateway](https://docs.aws.amazon.com/apigateway/)
- [Lambda](https://docs.aws.amazon.com/lambda/)
- [Cognito](https://docs.aws.amazon.com/cognito/)
- [DynamoDB](https://docs.aws.amazon.com/dynamodb/)
- [X-Ray](https://docs.aws.amazon.com/xray/)
