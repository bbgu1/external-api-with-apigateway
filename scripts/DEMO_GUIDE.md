# Demo Guide

This guide explains how to run the interactive demo script and manually test the AWS API Gateway multi-tenant solution.

## Prerequisites

Before running the demo, ensure:

1. Core infrastructure is deployed:
   ```bash
   cd terraform
   terraform init
   terraform apply
   ```
2. Tenants are onboarded:
   ```bash
   cd terraform/tenants
   cp terraform.tfvars.example terraform.tfvars
   terraform init
   terraform apply
   ```
3. Sample data is seeded in DynamoDB:
   ```bash
   ./scripts/seed_data.sh
   ```
4. Required tools are installed: `curl`, `jq`, `terraform`

## Running the Demo

```bash
cd scripts
./demo.sh
```

The script retrieves credentials from both Terraform workspaces automatically and walks through an interactive demonstration of all features.

## Demo Flow

The script is interactive and pauses between sections. Press Enter to continue through each step.

### Section 1: Infrastructure Information

Retrieves and displays:
- API Gateway endpoint URL (from core workspace)
- Cognito token endpoint (from core workspace)
- Tenant credentials (from tenants workspace)
- CloudWatch dashboard URL

### Section 2: Authentication

Demonstrates OAuth 2.0 client credentials flow:
- Authenticates as Basic, Standard, and Premium tenants
- Uses `scope=api/read` in token requests
- Lambda authorizer validates JWT and resolves tenant identity via SSM

### Section 3: Catalog API

Shows product catalog operations:
- Lists all products for a tenant
- Retrieves specific product details

### Section 4: Order API

Demonstrates order management:
- Creates a new order
- Retrieves order details

### Section 5: Tenant Isolation

Proves data isolation:
- Attempts cross-tenant data access
- Shows 403/404 error responses
- Confirms security model works

### Section 6: Rate Limiting

Tests usage plan limits:
- Sends rapid requests to trigger throttling
- Shows 429 Too Many Requests responses
- Displays success vs throttled request counts

### Section 7: X-Ray Tracing

Explains distributed tracing:
- Makes a traced request
- Provides trace ID for lookup
- Explains how to view traces in AWS Console

### Section 8: CloudWatch Dashboard

Shows monitoring capabilities:
- Provides dashboard URL
- Lists available metrics

### Section 9: Error Handling

Tests error scenarios:
- Invalid product ID (404)
- Invalid order data (400)

## Manual Testing

If you prefer manual testing, use these example commands.

### Get Core Infrastructure Outputs

```bash
cd terraform
TOKEN_ENDPOINT=$(terraform output -raw cognito_token_endpoint)
API_URL=$(terraform output -raw api_endpoint_url)
```

### Get Tenant Credentials

Credentials come from the tenants workspace (not core):

```bash
cd terraform/tenants
TENANT_IDS=$(terraform output -json cognito_client_ids)
TENANT_SECRETS=$(terraform output -json cognito_client_secrets)

# Extract a specific tenant
CLIENT_ID=$(echo "$TENANT_IDS" | jq -r '.["tenant-basic-001"]')
CLIENT_SECRET=$(echo "$TENANT_SECRETS" | jq -r '.["tenant-basic-001"]')
```

### Authenticate

```bash
TOKEN=$(curl -s -X POST "$TOKEN_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&scope=api/read" \
  | jq -r '.access_token')
```

### Call APIs

```bash
# List products
curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/catalog" | jq

# Get product details
curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/catalog/prod-001" | jq

# Create order
curl -s -X POST "$API_URL/orders" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"customerId":"cust-001","productId":"prod-001","quantity":2}' | jq

# Get order
curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/orders/ORDER_ID" | jq
```

## Provisioning a New Tenant

To onboard a new tenant of any tier, edit `terraform/tenants/terraform.tfvars`:

```hcl
tenants = {
  # Existing tenants
  "tenant-basic-001" = { tier = "basic" }
  "tenant-standard-001" = { tier = "standard" }
  "tenant-premium-001" = { tier = "premium" }

  # Add a new standard-tier tenant
  "tenant-acme-corp" = { tier = "standard" }

  # Add a new premium-tier tenant
  "tenant-bigco" = { tier = "premium" }
}
```

Then apply:

```bash
cd terraform/tenants
terraform apply
```

Retrieve the new tenant's credentials:

```bash
terraform output -json cognito_client_ids | jq -r '.["tenant-acme-corp"]'
terraform output -json cognito_client_secrets | jq -r '.["tenant-acme-corp"]'
```

Test the new tenant:

```bash
NEW_CLIENT_ID=$(terraform output -json cognito_client_ids | jq -r '.["tenant-acme-corp"]')
NEW_CLIENT_SECRET=$(terraform output -json cognito_client_secrets | jq -r '.["tenant-acme-corp"]')

TOKEN_ENDPOINT=$(cd ../../terraform && terraform output -raw cognito_token_endpoint)
API_URL=$(cd ../../terraform && terraform output -raw api_endpoint_url)

NEW_TOKEN=$(curl -s -X POST "$TOKEN_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=${NEW_CLIENT_ID}&client_secret=${NEW_CLIENT_SECRET}&scope=api/read" \
  | jq -r '.access_token')

curl -s -H "Authorization: Bearer $NEW_TOKEN" "$API_URL/catalog" | jq
```

### Available Tiers

| Tier | Rate Limit | Burst | Monthly Quota |
|------|-----------|-------|---------------|
| basic | 10 req/sec | 20 | 100,000 |
| standard | 100 req/sec | 200 | 1,000,000 |
| premium | 1,000 req/sec | 2,000 | 10,000,000 |

Tier definitions can be customized in the `tiers` block of `terraform/tenants/terraform.tfvars`.

## Viewing Traces and Metrics

### X-Ray Traces

1. Open AWS Console → X-Ray → Traces
2. Filter by annotation: `tenant_id = "tenant-basic-001"`
3. Click on a trace to see the full request flow through API Gateway → Lambda authorizer → Lambda function → DynamoDB

### CloudWatch Dashboard

```bash
cd terraform
terraform output -raw cloudwatch_dashboard_url
```

### CloudWatch Logs

```bash
# View Lambda authorizer logs
aws logs tail /aws/lambda/api-gateway-demo-dev-authorizer --follow --region us-east-1

# View catalog function logs
aws logs tail /aws/lambda/api-gateway-demo-dev-catalog --follow --region us-east-1
```

## Troubleshooting

### Authentication Fails

- Verify tenants workspace is deployed: `cd terraform/tenants && terraform output`
- Check client ID and secret are correct (from tenants workspace, not core)
- Ensure `scope=api/read` is included in the token request

### API Returns 401

- Token may be expired (1-hour TTL). Re-authenticate.
- Check Lambda authorizer logs for JWT validation errors:
  ```bash
  aws logs tail /aws/lambda/api-gateway-demo-dev-authorizer --region us-east-1
  ```

### API Returns 403

- The Lambda authorizer could not find a mapping for the `client_id` in SSM
- Ensure `terraform apply` was run in `terraform/tenants/` after adding the tenant
- Verify SSM parameters are populated in AWS Console → Systems Manager → Parameter Store

### Rate Limiting Not Working

- Usage plans are managed in `terraform/tenants/`, not core infrastructure
- Check the tenant's tier assignment in `terraform/tenants/terraform.tfvars`
- Usage plan changes may take a moment to propagate

### No Traces in X-Ray

- Wait 1-2 minutes for traces to appear
- Check IAM permissions for X-Ray

## Cleanup

Destroy in reverse order — tenants first, then core:

```bash
# 1. Destroy tenant resources
cd terraform/tenants
terraform destroy

# 2. Destroy core infrastructure
cd ../
terraform destroy
```
