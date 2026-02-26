# API Gateway Module

This Terraform module creates an AWS API Gateway REST API with JWT authorization using AWS Cognito, Lambda integrations, X-Ray tracing, and CloudWatch logging.

## Features

- **REST API**: Regional API Gateway with RESTful endpoints
- **JWT Authorization**: Cognito User Pool authorizer for secure authentication
- **Lambda Integration**: AWS_PROXY integration with Catalog and Order Lambda functions
- **CORS Support**: Configurable CORS headers for cross-origin requests
- **X-Ray Tracing**: Distributed tracing for request flow analysis
- **CloudWatch Logging**: Full request/response logging with structured JSON format
- **Multi-Tenant Support**: Tenant ID extraction from JWT tokens for isolation

## API Endpoints

The module creates the following RESTful endpoints:

| Method | Path                    | Description                | Lambda Function |
|--------|-------------------------|----------------------------|-----------------|
| GET    | /catalog                | List all products          | Catalog         |
| GET    | /catalog/{productId}    | Get product details        | Catalog         |
| GET    | /orders                 | List all orders            | Order           |
| POST   | /orders                 | Create a new order         | Order           |
| GET    | /orders/{orderId}       | Get order details          | Order           |
| OPTIONS| /catalog                | CORS preflight             | Mock            |
| OPTIONS| /catalog/{productId}    | CORS preflight             | Mock            |
| OPTIONS| /orders                 | CORS preflight             | Mock            |
| OPTIONS| /orders/{orderId}       | CORS preflight             | Mock            |

## Usage

```hcl
module "api_gateway" {
  source = "./modules/api-gateway"

  environment           = "dev"
  cognito_user_pool_arn = module.cognito.user_pool_arn
  cognito_user_pool_id  = module.cognito.user_pool_id
  catalog_lambda_arn    = module.lambda.catalog_lambda_arn
  catalog_lambda_name   = module.lambda.catalog_lambda_name
  order_lambda_arn      = module.lambda.order_lambda_arn
  order_lambda_name     = module.lambda.order_lambda_name
  enable_xray_tracing   = true
  enable_logging        = true
  log_level             = "INFO"
  log_retention_days    = 7
}
```

## Inputs

| Name                    | Description                                      | Type           | Default                                                                      | Required |
|-------------------------|--------------------------------------------------|----------------|------------------------------------------------------------------------------|----------|
| environment             | Environment name (dev, staging, prod)            | string         | n/a                                                                          | yes      |
| cognito_user_pool_arn   | ARN of the Cognito User Pool                     | string         | n/a                                                                          | yes      |
| cognito_user_pool_id    | ID of the Cognito User Pool                      | string         | n/a                                                                          | yes      |
| catalog_lambda_arn      | ARN of the Catalog Lambda function               | string         | n/a                                                                          | yes      |
| catalog_lambda_name     | Name of the Catalog Lambda function              | string         | n/a                                                                          | yes      |
| order_lambda_arn        | ARN of the Order Lambda function                 | string         | n/a                                                                          | yes      |
| order_lambda_name       | Name of the Order Lambda function                | string         | n/a                                                                          | yes      |
| api_name                | Name of the API Gateway REST API                 | string         | "api-gateway-demo"                                                           | no       |
| api_description         | Description of the API Gateway REST API          | string         | "AWS API Gateway Demo Solution with multi-tenant support"                    | no       |
| stage_name              | Name of the API Gateway deployment stage         | string         | "v1"                                                                         | no       |
| enable_xray_tracing     | Enable AWS X-Ray tracing                         | bool           | true                                                                         | no       |
| enable_logging          | Enable CloudWatch logging                        | bool           | true                                                                         | no       |
| log_level               | CloudWatch log level (INFO or ERROR)             | string         | "INFO"                                                                       | no       |
| log_retention_days      | CloudWatch log retention period in days          | number         | 7                                                                            | no       |
| enable_cors             | Enable CORS for API Gateway endpoints            | bool           | true                                                                         | no       |
| cors_allow_origins      | List of allowed origins for CORS                 | list(string)   | ["*"]                                                                        | no       |
| cors_allow_methods      | List of allowed HTTP methods for CORS            | list(string)   | ["GET", "POST", "OPTIONS"]                                                   | no       |
| cors_allow_headers      | List of allowed headers for CORS                 | list(string)   | ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"] | no       |
| tags                    | Additional tags to apply to resources            | map(string)    | {}                                                                           | no       |

## Outputs

| Name                        | Description                                      |
|-----------------------------|--------------------------------------------------|
| api_id                      | ID of the API Gateway REST API                   |
| api_name                    | Name of the API Gateway REST API                 |
| api_arn                     | ARN of the API Gateway REST API                  |
| api_endpoint_url            | Base URL for the API Gateway endpoint            |
| api_execution_arn           | Execution ARN of the API Gateway REST API        |
| stage_name                  | Name of the API Gateway stage                    |
| stage_arn                   | ARN of the API Gateway stage                     |
| deployment_id               | ID of the API Gateway deployment                 |
| authorizer_id               | ID of the Cognito JWT authorizer                 |
| catalog_resource_id         | ID of the /catalog resource                      |
| catalog_product_resource_id | ID of the /catalog/{productId} resource          |
| orders_resource_id          | ID of the /orders resource                       |
| orders_order_resource_id    | ID of the /orders/{orderId} resource             |
| cloudwatch_log_group_name   | Name of the CloudWatch log group                 |
| cloudwatch_log_group_arn    | ARN of the CloudWatch log group                  |
| xray_tracing_enabled        | Whether X-Ray tracing is enabled                 |
| catalog_endpoint            | Full URL for the /catalog endpoint               |
| orders_endpoint             | Full URL for the /orders endpoint                |

## Authentication

All API endpoints (except OPTIONS for CORS) require JWT authentication using AWS Cognito:

1. **Authorization Header**: Requests must include an `Authorization` header with a valid JWT token
   ```
   Authorization: Bearer <JWT_TOKEN>
   ```

2. **Token Validation**: API Gateway validates the JWT token against the Cognito User Pool
   - Invalid tokens return 401 Unauthorized
   - Expired tokens return 401 Unauthorized
   - Missing Authorization header returns 401 Unauthorized

3. **Tenant Context**: The JWT token contains tenant_id claim which is passed to Lambda functions for multi-tenant isolation

## CloudWatch Logging

When `enable_logging` is true, the module configures:

- **Access Logs**: Structured JSON logs with request/response details
- **Execution Logs**: Detailed logs at INFO or ERROR level
- **Data Trace**: Full request and response body logging (when log_level = INFO)
- **Log Retention**: Configurable retention period (default 7 days)

Log format includes:
- Request ID
- Source IP
- HTTP method and path
- Status code
- Response length
- Error messages (if any)

## X-Ray Tracing

When `enable_xray_tracing` is true, the module enables:

- **API Gateway Tracing**: Traces all API Gateway requests
- **Lambda Integration**: Traces propagate to Lambda functions
- **Service Map**: Visualize request flow through services
- **Performance Analysis**: Identify bottlenecks and latency issues

## CORS Configuration

When `enable_cors` is true, the module creates OPTIONS methods for all endpoints with configurable:

- **Allowed Origins**: Default is `*` (all origins)
- **Allowed Methods**: Default is GET, POST, OPTIONS
- **Allowed Headers**: Default includes Content-Type, Authorization, and AWS headers

## Lambda Permissions

The module automatically creates Lambda permissions for API Gateway to invoke:

- Catalog Lambda: GET /catalog, GET /catalog/{productId}
- Order Lambda: GET /orders, POST /orders, GET /orders/{orderId}

## Dependencies

This module depends on:

- **Cognito Module**: Provides user pool ARN and ID for JWT authorization
- **Lambda Module**: Provides Lambda function ARNs and names for integration

## Requirements

| Name      | Version |
|-----------|---------|
| terraform | >= 1.0  |
| aws       | ~> 5.0  |

## Notes

- The module uses AWS_PROXY integration type for Lambda functions, which passes the entire request to Lambda
- Lambda functions receive JWT claims in `event['requestContext']['authorizer']['claims']`
- The deployment is triggered automatically when any API Gateway resource changes
- CloudWatch logging requires an IAM role with appropriate permissions
- X-Ray tracing adds minimal latency and cost to API requests

## Example API Calls

### Get all products
```bash
curl -H "Authorization: Bearer <JWT_TOKEN>" \
  https://<api-id>.execute-api.<region>.amazonaws.com/v1/catalog
```

### Get specific product
```bash
curl -H "Authorization: Bearer <JWT_TOKEN>" \
  https://<api-id>.execute-api.<region>.amazonaws.com/v1/catalog/prod-001
```

### Create order
```bash
curl -X POST \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"customerId":"cust-123","productId":"prod-001","quantity":2}' \
  https://<api-id>.execute-api.<region>.amazonaws.com/v1/orders
```

### Get order details
```bash
curl -H "Authorization: Bearer <JWT_TOKEN>" \
  https://<api-id>.execute-api.<region>.amazonaws.com/v1/orders/order-001
```

## Troubleshooting

### 401 Unauthorized
- Verify JWT token is valid and not expired
- Check Authorization header format: `Bearer <token>`
- Verify Cognito User Pool ARN is correct

### 403 Forbidden
- Check Lambda execution role has necessary permissions
- Verify API Gateway has permission to invoke Lambda functions

### 500 Internal Server Error
- Check Lambda function logs in CloudWatch
- Verify Lambda function environment variables
- Check X-Ray traces for error details

### CORS Errors
- Verify `enable_cors` is set to true
- Check `cors_allow_origins` includes your origin
- Ensure OPTIONS method is working (returns 200)
