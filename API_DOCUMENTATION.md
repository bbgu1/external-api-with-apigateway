# AWS API Gateway Demo - API Documentation

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Authentication](#authentication)
- [API Endpoints](#api-endpoints)
- [Error Handling](#error-handling)
- [Rate Limiting](#rate-limiting)
- [Multi-Tenant Architecture](#multi-tenant-architecture)
- [Monitoring and Observability](#monitoring-and-observability)
- [Code Examples](#code-examples)

## Overview

The AWS API Gateway Demo Solution is a comprehensive serverless API that demonstrates enterprise-grade multi-tenant architecture using AWS managed services. The solution provides RESTful APIs for product catalog management and order processing with built-in authentication, rate limiting, and full observability.

### Key Features

- **Multi-tenant SaaS Architecture**: Complete tenant isolation at data and rate-limiting levels
- **OAuth 2.0 Authentication**: Machine-to-machine (M2M) authentication via AWS Cognito with JWT tokens
- **RESTful API Design**: Product catalog and order management endpoints
- **Tiered Rate Limiting**: Usage plans for Basic, Standard, and Premium tiers
- **Full Observability**: AWS X-Ray distributed tracing, CloudWatch dashboards, structured JSON logging
- **Infrastructure as Code**: Complete Terraform deployment with modular architecture

### Technology Stack

- **API Gateway**: AWS API Gateway REST API
- **Compute**: AWS Lambda (Python 3.9+)
- **Database**: AWS DynamoDB (single table design)
- **Authentication**: AWS Cognito User Pools
- **Tracing**: AWS X-Ray
- **Monitoring**: Amazon CloudWatch
- **Infrastructure**: Terraform

## Architecture

### High-Level Architecture

```
┌─────────────┐
│   Client    │
│  (Tenant A) │
└──────┬──────┘
       │ HTTPS + JWT
       ▼
┌─────────────────────┐
│   API Gateway       │
│  - JWT Validation   │
│  - Rate Limiting    │
│  - Request Routing  │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│  Lambda Functions   │
│  - Catalog API      │
│  - Order API        │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│     DynamoDB        │
│  - Multi-tenant     │
│  - Partition by Tenant │
└─────────────────────┘

         │
         ▼
┌─────────────────────┐
│   Observability     │
│  - X-Ray Traces     │
│  - CloudWatch Logs  │
│  - CloudWatch Metrics│
└─────────────────────┘
```

### Request Flow

1. **Authentication**: Client requests JWT token from Cognito with tenant-specific credentials
2. **API Request**: Client sends API request with JWT token in Authorization header
3. **Gateway Validation**: API Gateway validates JWT token and extracts tenant ID
4. **Rate Limiting**: API Gateway checks tenant-specific usage plan limits
5. **Lambda Invocation**: API Gateway invokes appropriate Lambda function with tenant context
6. **Data Access**: Lambda function queries/writes DynamoDB with tenant isolation
7. **Tracing**: X-Ray captures distributed trace across all components
8. **Response**: Lambda returns response through API Gateway to client

## Authentication

### OAuth 2.0 Client Credentials Flow

The API uses OAuth 2.0 client credentials flow for machine-to-machine authentication via AWS Cognito.

### Obtaining an Access Token

**Endpoint**: `https://your-cognito-domain.auth.region.amazoncognito.com/oauth2/token`

**Method**: POST

**Headers**:
```
Content-Type: application/x-www-form-urlencoded
Authorization: Basic <base64(client_id:client_secret)>
```

**Body**:
```
grant_type=client_credentials&scope=api/read api/write
```

**Example Request (curl)**:
```bash
curl -X POST \
  https://your-cognito-domain.auth.region.amazoncognito.com/oauth2/token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H 'Authorization: Basic <base64_encoded_credentials>' \
  -d 'grant_type=client_credentials&scope=api/read api/write'
```

**Example Response**:
```json
{
  "access_token": "eyJraWQiOiJ...",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

### JWT Token Structure

The JWT token contains the following claims:

```json
{
  "sub": "client-uuid",
  "tenant_id": "tenant-123",
  "client_id": "app-client-id",
  "scope": "api/read api/write",
  "iss": "https://cognito-idp.region.amazonaws.com/pool-id",
  "exp": 1234567890,
  "iat": 1234567890
}
```

### Using the Access Token

Include the access token in the Authorization header for all API requests:

```
Authorization: Bearer <access_token>
```

## API Endpoints

### Base URL

```
https://<api-id>.execute-api.<region>.amazonaws.com/<stage>
```

### Catalog API

#### List All Products

Retrieve all products for the authenticated tenant.

**Endpoint**: `GET /catalog`

**Headers**:
```
Authorization: Bearer <access_token>
```

**Response** (200 OK):
```json
{
  "statusCode": 200,
  "data": [
    {
      "productId": "prod-001",
      "name": "Widget Pro",
      "description": "Professional grade widget",
      "price": 99.99,
      "currency": "USD",
      "category": "Electronics",
      "inStock": true
    },
    {
      "productId": "prod-002",
      "name": "Gadget Plus",
      "description": "Advanced gadget",
      "price": 149.99,
      "currency": "USD",
      "category": "Electronics",
      "inStock": true
    }
  ],
  "tenantId": "tenant-123",
  "requestId": "abc-123-def-456"
}
```

**Example (curl)**:
```bash
curl -X GET \
  https://api-id.execute-api.us-east-1.amazonaws.com/prod/catalog \
  -H 'Authorization: Bearer eyJraWQiOiJ...'
```

**Example (Python)**:
```python
import requests

url = "https://api-id.execute-api.us-east-1.amazonaws.com/prod/catalog"
headers = {
    "Authorization": f"Bearer {access_token}"
}

response = requests.get(url, headers=headers)
products = response.json()
print(products)
```

**Example (JavaScript)**:
```javascript
const url = 'https://api-id.execute-api.us-east-1.amazonaws.com/prod/catalog';
const headers = {
  'Authorization': `Bearer ${accessToken}`
};

fetch(url, { headers })
  .then(response => response.json())
  .then(data => console.log(data));
```

#### Get Product Details

Retrieve details for a specific product.

**Endpoint**: `GET /catalog/{productId}`

**Path Parameters**:
- `productId` (string, required): The unique identifier of the product

**Headers**:
```
Authorization: Bearer <access_token>
```

**Response** (200 OK):
```json
{
  "statusCode": 200,
  "data": {
    "productId": "prod-001",
    "name": "Widget Pro",
    "description": "Professional grade widget",
    "price": 99.99,
    "currency": "USD",
    "category": "Electronics",
    "inStock": true,
    "createdAt": "2024-01-15T10:30:00Z",
    "updatedAt": "2024-01-15T10:30:00Z"
  },
  "tenantId": "tenant-123",
  "requestId": "abc-123-def-456"
}
```

**Example (curl)**:
```bash
curl -X GET \
  https://api-id.execute-api.us-east-1.amazonaws.com/prod/catalog/prod-001 \
  -H 'Authorization: Bearer eyJraWQiOiJ...'
```

### Order API

#### Create Order

Create a new order for the authenticated tenant.

**Endpoint**: `POST /orders`

**Headers**:
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body**:
```json
{
  "customerId": "cust-456",
  "productId": "prod-001",
  "quantity": 2
}
```

**Response** (200 OK):
```json
{
  "statusCode": 200,
  "data": {
    "orderId": "order-789",
    "customerId": "cust-456",
    "productId": "prod-001",
    "quantity": 2,
    "totalPrice": 199.98,
    "currency": "USD",
    "status": "PENDING",
    "createdAt": "2024-01-15T14:20:00Z"
  },
  "tenantId": "tenant-123",
  "requestId": "abc-123-def-456"
}
```

**Example (curl)**:
```bash
curl -X POST \
  https://api-id.execute-api.us-east-1.amazonaws.com/prod/orders \
  -H 'Authorization: Bearer eyJraWQiOiJ...' \
  -H 'Content-Type: application/json' \
  -d '{
    "customerId": "cust-456",
    "productId": "prod-001",
    "quantity": 2
  }'
```

**Example (Python)**:
```python
import requests

url = "https://api-id.execute-api.us-east-1.amazonaws.com/prod/orders"
headers = {
    "Authorization": f"Bearer {access_token}",
    "Content-Type": "application/json"
}
data = {
    "customerId": "cust-456",
    "productId": "prod-001",
    "quantity": 2
}

response = requests.post(url, headers=headers, json=data)
order = response.json()
print(order)
```

**Example (JavaScript)**:
```javascript
const url = 'https://api-id.execute-api.us-east-1.amazonaws.com/prod/orders';
const headers = {
  'Authorization': `Bearer ${accessToken}`,
  'Content-Type': 'application/json'
};
const body = JSON.stringify({
  customerId: 'cust-456',
  productId: 'prod-001',
  quantity: 2
});

fetch(url, { method: 'POST', headers, body })
  .then(response => response.json())
  .then(data => console.log(data));
```

#### Get Order Details

Retrieve details for a specific order.

**Endpoint**: `GET /orders/{orderId}`

**Path Parameters**:
- `orderId` (string, required): The unique identifier of the order

**Headers**:
```
Authorization: Bearer <access_token>
```

**Response** (200 OK):
```json
{
  "statusCode": 200,
  "data": {
    "orderId": "order-789",
    "customerId": "cust-456",
    "productId": "prod-001",
    "quantity": 2,
    "totalPrice": 199.98,
    "currency": "USD",
    "status": "PENDING",
    "createdAt": "2024-01-15T14:20:00Z",
    "updatedAt": "2024-01-15T14:20:00Z"
  },
  "tenantId": "tenant-123",
  "requestId": "abc-123-def-456"
}
```

**Example (curl)**:
```bash
curl -X GET \
  https://api-id.execute-api.us-east-1.amazonaws.com/prod/orders/order-789 \
  -H 'Authorization: Bearer eyJraWQiOiJ...'
```

## Error Handling

### Error Response Format

All error responses follow a consistent format:

```json
{
  "statusCode": 400,
  "error": "BadRequest",
  "message": "Validation failed: quantity must be a positive integer",
  "tenantId": "tenant-123",
  "requestId": "abc-123-def-456",
  "timestamp": "2024-01-15T14:30:00Z"
}
```

### HTTP Status Codes

| Status Code | Error Type | Description |
|-------------|------------|-------------|
| 400 | Bad Request | Invalid request data or missing required fields |
| 401 | Unauthorized | Invalid, expired, or missing JWT token |
| 403 | Forbidden | Insufficient permissions or cross-tenant access attempt |
| 404 | Not Found | Resource (product/order) not found |
| 429 | Too Many Requests | Rate limit or quota exceeded |
| 500 | Internal Server Error | Unexpected server error |

### Common Error Scenarios

#### 401 Unauthorized - Invalid Token

**Request**:
```bash
curl -X GET \
  https://api-id.execute-api.us-east-1.amazonaws.com/prod/catalog \
  -H 'Authorization: Bearer invalid_token'
```

**Response**:
```json
{
  "message": "Unauthorized"
}
```

#### 400 Bad Request - Missing Required Field

**Request**:
```bash
curl -X POST \
  https://api-id.execute-api.us-east-1.amazonaws.com/prod/orders \
  -H 'Authorization: Bearer eyJraWQiOiJ...' \
  -H 'Content-Type: application/json' \
  -d '{
    "customerId": "cust-456",
    "quantity": 2
  }'
```

**Response**:
```json
{
  "statusCode": 400,
  "error": "BadRequest",
  "message": "Missing required field: productId",
  "tenantId": "tenant-123",
  "requestId": "abc-123-def-456"
}
```

#### 404 Not Found - Product Not Found

**Request**:
```bash
curl -X GET \
  https://api-id.execute-api.us-east-1.amazonaws.com/prod/catalog/invalid-id \
  -H 'Authorization: Bearer eyJraWQiOiJ...'
```

**Response**:
```json
{
  "statusCode": 404,
  "error": "NotFound",
  "message": "Product invalid-id not found",
  "tenantId": "tenant-123",
  "requestId": "abc-123-def-456"
}
```

#### 429 Too Many Requests - Rate Limit Exceeded

**Response**:
```json
{
  "message": "Too Many Requests"
}
```

## Rate Limiting

### Usage Tiers

The API implements tenant-level rate limiting with three tiers:

| Tier | Rate Limit | Burst Limit | Monthly Quota |
|------|------------|-------------|---------------|
| Basic | 10 req/sec | 20 | 100,000 |
| Standard | 100 req/sec | 200 | 1,000,000 |
| Premium | 1000 req/sec | 2000 | 10,000,000 |

### How Rate Limiting Works

1. **Tenant Identification**: The tenant ID is extracted from the JWT token
2. **Usage Plan Mapping**: The tenant ID is mapped to the appropriate usage plan
3. **Limit Enforcement**: API Gateway enforces rate limits, burst limits, and quotas
4. **Throttling Response**: When limits are exceeded, a 429 status code is returned

### Rate Limit Headers

API Gateway does not return rate limit headers by default, but you can monitor your usage through CloudWatch metrics.

### Best Practices

- **Implement Exponential Backoff**: When receiving 429 responses, wait before retrying
- **Cache Responses**: Cache product catalog data to reduce API calls
- **Batch Operations**: Group multiple operations when possible
- **Monitor Usage**: Use CloudWatch dashboards to track your API usage

## Multi-Tenant Architecture

### Tenant Isolation

The solution implements comprehensive tenant isolation at multiple layers:

#### 1. Authentication Layer

- Each tenant has separate Cognito app clients
- JWT tokens include tenant_id claim
- Tokens are scoped to specific tenant

#### 2. API Gateway Layer

- Usage plans are assigned per tenant
- Rate limits enforced per tenant
- No cross-tenant token sharing

#### 3. Application Layer

- Lambda functions extract tenant_id from JWT
- All data operations include tenant_id
- Cross-tenant access attempts are logged and rejected

#### 4. Data Layer

- DynamoDB uses composite keys with tenant_id
- Partition key format: `TENANT#{tenant_id}#{entity_type}`
- Sort key format: `{ENTITY_TYPE}#{entity_id}`
- Queries always filter by tenant_id

### Data Model

**Product**:
```
PK: TENANT#tenant-123#PRODUCT
SK: PRODUCT#prod-001
```

**Order**:
```
PK: TENANT#tenant-123#ORDER
SK: ORDER#order-789
```

### Security Violations

Cross-tenant access attempts are:
- Logged as security violations
- Captured in CloudWatch Logs
- Traced in X-Ray
- Return 403 Forbidden or 404 Not Found

**Example Log Entry**:
```json
{
  "level": "WARNING",
  "message": "SECURITY VIOLATION: Cross-tenant access attempt",
  "security_event": "cross_tenant_access",
  "requested_tenant": "tenant-456",
  "authenticated_tenant": "tenant-123",
  "resource_type": "order",
  "resource_id": "order-789",
  "timestamp": "2024-01-15T14:30:00Z"
}
```

## Monitoring and Observability

### CloudWatch Dashboard

Access the CloudWatch Application Signals dashboard to monitor API performance:

1. Navigate to AWS Console → CloudWatch → Dashboards
2. Select the dashboard: `api-gateway-demo-<environment>-dashboard`

**Dashboard Widgets**:
- API Gateway request count, error rates, latency
- Lambda invocation count, duration, errors
- DynamoDB read/write capacity, throttling
- Tenant-specific metrics
- Cost metrics

### X-Ray Traces

View distributed traces to understand request flow:

1. Navigate to AWS Console → X-Ray → Traces
2. Filter by tenant_id annotation: `annotation.tenant_id = "tenant-123"`
3. Filter by request_id: `annotation.request_id = "abc-123-def-456"`

**Trace Information**:
- Complete request path (API Gateway → Lambda → DynamoDB)
- Timing for each service component
- Error details and stack traces
- Custom annotations (tenant_id, request_id, endpoint)

### CloudWatch Logs

View structured logs for debugging:

1. Navigate to AWS Console → CloudWatch → Log Groups
2. Select log group: `/aws/lambda/<function-name>`
3. Use CloudWatch Logs Insights for queries

**Example Query - Errors by Tenant**:
```
fields @timestamp, tenantId, @message
| filter level = "ERROR"
| stats count() by tenantId
| sort count desc
```

**Example Query - Slow Requests**:
```
fields @timestamp, tenantId, requestId, duration
| filter duration > 1000
| sort duration desc
```

### CloudWatch Alarms

The solution includes pre-configured alarms:

- **High Error Rate**: 5xx errors > 5% of requests
- **High Latency**: p99 latency > 3 seconds
- **Throttling**: Throttled requests > 10
- **Lambda Errors**: Lambda errors > 5

Alarms send notifications to SNS topics for alerting.

## Code Examples

### Complete Python Example

```python
import requests
import base64
import json

class APIGatewayClient:
    def __init__(self, api_url, cognito_domain, client_id, client_secret):
        self.api_url = api_url
        self.cognito_domain = cognito_domain
        self.client_id = client_id
        self.client_secret = client_secret
        self.access_token = None
    
    def authenticate(self):
        """Obtain access token from Cognito"""
        token_url = f"https://{self.cognito_domain}/oauth2/token"
        
        # Encode credentials
        credentials = f"{self.client_id}:{self.client_secret}"
        encoded_credentials = base64.b64encode(credentials.encode()).decode()
        
        headers = {
            "Content-Type": "application/x-www-form-urlencoded",
            "Authorization": f"Basic {encoded_credentials}"
        }
        
        data = {
            "grant_type": "client_credentials",
            "scope": "api/read api/write"
        }
        
        response = requests.post(token_url, headers=headers, data=data)
        response.raise_for_status()
        
        self.access_token = response.json()["access_token"]
        return self.access_token
    
    def _get_headers(self):
        """Get headers with access token"""
        if not self.access_token:
            self.authenticate()
        
        return {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json"
        }
    
    def list_products(self):
        """List all products"""
        url = f"{self.api_url}/catalog"
        response = requests.get(url, headers=self._get_headers())
        response.raise_for_status()
        return response.json()
    
    def get_product(self, product_id):
        """Get product details"""
        url = f"{self.api_url}/catalog/{product_id}"
        response = requests.get(url, headers=self._get_headers())
        response.raise_for_status()
        return response.json()
    
    def create_order(self, customer_id, product_id, quantity):
        """Create a new order"""
        url = f"{self.api_url}/orders"
        data = {
            "customerId": customer_id,
            "productId": product_id,
            "quantity": quantity
        }
        response = requests.post(url, headers=self._get_headers(), json=data)
        response.raise_for_status()
        return response.json()
    
    def get_order(self, order_id):
        """Get order details"""
        url = f"{self.api_url}/orders/{order_id}"
        response = requests.get(url, headers=self._get_headers())
        response.raise_for_status()
        return response.json()

# Usage
if __name__ == "__main__":
    client = APIGatewayClient(
        api_url="https://api-id.execute-api.us-east-1.amazonaws.com/prod",
        cognito_domain="your-domain.auth.us-east-1.amazoncognito.com",
        client_id="your-client-id",
        client_secret="your-client-secret"
    )
    
    # List products
    products = client.list_products()
    print("Products:", json.dumps(products, indent=2))
    
    # Get specific product
    product = client.get_product("prod-001")
    print("Product:", json.dumps(product, indent=2))
    
    # Create order
    order = client.create_order("cust-456", "prod-001", 2)
    print("Order:", json.dumps(order, indent=2))
    
    # Get order
    order_details = client.get_order(order["data"]["orderId"])
    print("Order Details:", json.dumps(order_details, indent=2))
```

### Complete JavaScript Example

```javascript
const axios = require('axios');

class APIGatewayClient {
  constructor(apiUrl, cognitoDomain, clientId, clientSecret) {
    this.apiUrl = apiUrl;
    this.cognitoDomain = cognitoDomain;
    this.clientId = clientId;
    this.clientSecret = clientSecret;
    this.accessToken = null;
  }

  async authenticate() {
    const tokenUrl = `https://${this.cognitoDomain}/oauth2/token`;
    
    // Encode credentials
    const credentials = Buffer.from(`${this.clientId}:${this.clientSecret}`).toString('base64');
    
    const headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Authorization': `Basic ${credentials}`
    };
    
    const data = 'grant_type=client_credentials&scope=api/read api/write';
    
    const response = await axios.post(tokenUrl, data, { headers });
    this.accessToken = response.data.access_token;
    return this.accessToken;
  }

  async getHeaders() {
    if (!this.accessToken) {
      await this.authenticate();
    }
    
    return {
      'Authorization': `Bearer ${this.accessToken}`,
      'Content-Type': 'application/json'
    };
  }

  async listProducts() {
    const url = `${this.apiUrl}/catalog`;
    const headers = await this.getHeaders();
    const response = await axios.get(url, { headers });
    return response.data;
  }

  async getProduct(productId) {
    const url = `${this.apiUrl}/catalog/${productId}`;
    const headers = await this.getHeaders();
    const response = await axios.get(url, { headers });
    return response.data;
  }

  async createOrder(customerId, productId, quantity) {
    const url = `${this.apiUrl}/orders`;
    const headers = await this.getHeaders();
    const data = {
      customerId,
      productId,
      quantity
    };
    const response = await axios.post(url, data, { headers });
    return response.data;
  }

  async getOrder(orderId) {
    const url = `${this.apiUrl}/orders/${orderId}`;
    const headers = await this.getHeaders();
    const response = await axios.get(url, { headers });
    return response.data;
  }
}

// Usage
(async () => {
  const client = new APIGatewayClient(
    'https://api-id.execute-api.us-east-1.amazonaws.com/prod',
    'your-domain.auth.us-east-1.amazoncognito.com',
    'your-client-id',
    'your-client-secret'
  );

  try {
    // List products
    const products = await client.listProducts();
    console.log('Products:', JSON.stringify(products, null, 2));

    // Get specific product
    const product = await client.getProduct('prod-001');
    console.log('Product:', JSON.stringify(product, null, 2));

    // Create order
    const order = await client.createOrder('cust-456', 'prod-001', 2);
    console.log('Order:', JSON.stringify(order, null, 2));

    // Get order
    const orderDetails = await client.getOrder(order.data.orderId);
    console.log('Order Details:', JSON.stringify(orderDetails, null, 2));
  } catch (error) {
    console.error('Error:', error.response?.data || error.message);
  }
})();
```

### Bash Script Example

```bash
#!/bin/bash

# Configuration
API_URL="https://api-id.execute-api.us-east-1.amazonaws.com/prod"
COGNITO_DOMAIN="your-domain.auth.us-east-1.amazoncognito.com"
CLIENT_ID="your-client-id"
CLIENT_SECRET="your-client-secret"

# Authenticate and get access token
echo "Authenticating..."
CREDENTIALS=$(echo -n "${CLIENT_ID}:${CLIENT_SECRET}" | base64)
TOKEN_RESPONSE=$(curl -s -X POST \
  "https://${COGNITO_DOMAIN}/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Basic ${CREDENTIALS}" \
  -d "grant_type=client_credentials&scope=api/read api/write")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')
echo "Access token obtained"

# List products
echo -e "\nListing products..."
curl -s -X GET \
  "${API_URL}/catalog" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq '.'

# Get specific product
echo -e "\nGetting product prod-001..."
curl -s -X GET \
  "${API_URL}/catalog/prod-001" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq '.'

# Create order
echo -e "\nCreating order..."
ORDER_RESPONSE=$(curl -s -X POST \
  "${API_URL}/orders" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "cust-456",
    "productId": "prod-001",
    "quantity": 2
  }')

echo $ORDER_RESPONSE | jq '.'
ORDER_ID=$(echo $ORDER_RESPONSE | jq -r '.data.orderId')

# Get order
echo -e "\nGetting order ${ORDER_ID}..."
curl -s -X GET \
  "${API_URL}/orders/${ORDER_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq '.'
```

## Appendix

### Getting Started

1. **Deploy Infrastructure**: Use Terraform to deploy the solution
2. **Obtain Credentials**: Get Cognito client ID and secret from Terraform outputs
3. **Authenticate**: Request access token from Cognito
4. **Make API Calls**: Use access token to call API endpoints
5. **Monitor**: View traces in X-Ray and metrics in CloudWatch

### Support and Resources

- **Terraform Outputs**: Run `terraform output` to get API endpoint and Cognito details
- **CloudWatch Dashboard**: Monitor API performance and errors
- **X-Ray Service Map**: Visualize request flow and dependencies
- **CloudWatch Logs**: Debug issues with structured logs

### Troubleshooting

**Issue**: 401 Unauthorized
- **Solution**: Verify access token is valid and not expired. Re-authenticate if needed.

**Issue**: 429 Too Many Requests
- **Solution**: Implement exponential backoff and reduce request rate.

**Issue**: 404 Not Found
- **Solution**: Verify resource ID exists for your tenant. Check tenant isolation.

**Issue**: 500 Internal Server Error
- **Solution**: Check CloudWatch Logs and X-Ray traces for error details.

### API Versioning

The current API version is v1. Future versions will be indicated in the URL path:
- v1: `/prod/catalog`
- v2: `/prod/v2/catalog` (future)

### Changelog

- **v1.0.0** (2024-01-15): Initial release with Catalog and Order APIs
