# Architecture Documentation

## System Architecture

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           External Clients                               │
│                    (Multiple Tenants: Basic, Standard, Premium)          │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ HTTPS + JWT Token
                                 │
                    ┌────────────▼────────────┐
                    │   AWS Cognito           │
                    │   User Pool             │
                    │                         │
                    │  • OAuth 2.0 M2M        │
                    │  • JWT Tokens           │
                    │  • Tenant ID Claims     │
                    └────────────┬────────────┘
                                 │
                                 │ JWT Validation
                                 │
                    ┌────────────▼────────────┐
                    │   API Gateway           │
                    │   REST API              │
                    │                         │
                    │  • JWT Authorizer       │
                    │  • Usage Plans          │
                    │  • Rate Limiting        │
                    │  • X-Ray Tracing        │
                    └────────────┬────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
         ┌──────────▼──────────┐   ┌─────────▼──────────┐
         │  Catalog Lambda     │   │  Order Lambda      │
         │                     │   │                    │
         │  • Get Products     │   │  • Create Order    │
         │  • Get Product      │   │  • Get Order       │
         │  • Tenant Isolation │   │  • Validation      │
         │  • X-Ray Tracing    │   │  • X-Ray Tracing   │
         └──────────┬──────────┘   └─────────┬──────────┘
                    │                        │
                    └────────────┬───────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   DynamoDB Table        │
                    │                         │
                    │  • Single Table Design  │
                    │  • Tenant Partitioning  │
                    │  • On-Demand Billing    │
                    └─────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                        Observability Layer                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐     │
│  │   AWS X-Ray      │  │  CloudWatch      │  │  CloudWatch      │     │
│  │                  │  │  Logs            │  │  Dashboard       │     │
│  │  • Service Map   │  │                  │  │                  │     │
│  │  • Trace Details │  │  • Structured    │  │  • API Metrics   │     │
│  │  • Annotations   │  │  • JSON Format   │  │  • Lambda Stats  │     │
│  │  • Tenant Filter │  │  • Error Logs    │  │  • DDB Metrics   │     │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Request Flow Diagram

```
┌─────────┐
│ Client  │
└────┬────┘
     │
     │ 1. POST /oauth2/token
     │    (client_id, client_secret)
     ▼
┌─────────────┐
│   Cognito   │
└─────┬───────┘
      │
      │ 2. JWT Token
      │    (tenant_id claim)
      ▼
┌─────────┐
│ Client  │
└────┬────┘
     │
     │ 3. GET /catalog
     │    Authorization: Bearer <JWT>
     ▼
┌──────────────┐
│ API Gateway  │
└──────┬───────┘
       │
       │ 4. Validate JWT
       │    Extract tenant_id
       │    Check rate limits
       ▼
┌──────────────┐
│    Lambda    │
└──────┬───────┘
       │
       │ 5. Query DynamoDB
       │    PK = TENANT#{tenant_id}#PRODUCT
       ▼
┌──────────────┐
│   DynamoDB   │
└──────┬───────┘
       │
       │ 6. Return products
       ▼
┌──────────────┐
│    Lambda    │
└──────┬───────┘
       │
       │ 7. Format response
       │    Add tenant_id, request_id
       ▼
┌──────────────┐
│ API Gateway  │
└──────┬───────┘
       │
       │ 8. Return JSON response
       ▼
┌─────────┐
│ Client  │
└─────────┘

Throughout: X-Ray traces entire flow
            CloudWatch logs all operations
```

## Multi-Tenant Data Model

```
DynamoDB Table: api-gateway-demo
┌─────────────────────────────────────────────────────────────────┐
│ PK (Partition Key)              │ SK (Sort Key)                 │
├─────────────────────────────────┼───────────────────────────────┤
│ TENANT#tenant-basic#PRODUCT     │ PRODUCT#prod-001              │
│ TENANT#tenant-basic#PRODUCT     │ PRODUCT#prod-002              │
│ TENANT#tenant-basic#ORDER       │ ORDER#order-001               │
│ TENANT#tenant-basic#ORDER       │ ORDER#order-002               │
├─────────────────────────────────┼───────────────────────────────┤
│ TENANT#tenant-standard#PRODUCT  │ PRODUCT#prod-001              │
│ TENANT#tenant-standard#PRODUCT  │ PRODUCT#prod-002              │
│ TENANT#tenant-standard#ORDER    │ ORDER#order-001               │
├─────────────────────────────────┼───────────────────────────────┤
│ TENANT#tenant-premium#PRODUCT   │ PRODUCT#prod-001              │
│ TENANT#tenant-premium#ORDER     │ ORDER#order-001               │
└─────────────────────────────────┴───────────────────────────────┘

Benefits:
• Tenant isolation at partition key level
• Efficient queries within tenant
• Prevents cross-tenant access
• Scales automatically per tenant
```

## Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Security Layers                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Layer 1: Network Security                                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  • HTTPS only (TLS 1.2+)                               │    │
│  │  • API Gateway regional endpoint                       │    │
│  │  • No public Lambda endpoints                          │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Layer 2: Authentication                                        │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  • OAuth 2.0 client credentials flow                   │    │
│  │  • JWT tokens with 1-hour expiration                   │    │
│  │  • Cognito validates all tokens                        │    │
│  │  • No API keys required                                │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Layer 3: Authorization                                         │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  • JWT authorizer on API Gateway                       │    │
│  │  • Tenant ID extracted from token                      │    │
│  │  • Lambda validates tenant access                      │    │
│  │  • Cross-tenant access blocked (403/404)              │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Layer 4: Data Isolation                                        │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  • Tenant ID in DynamoDB partition key                 │    │
│  │  • Queries scoped to tenant partition                  │    │
│  │  • No cross-tenant queries possible                    │    │
│  │  • Security violations logged                          │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Layer 5: IAM Permissions                                       │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  • Least privilege Lambda roles                        │    │
│  │  • Resource-level DynamoDB permissions                 │    │
│  │  • No wildcard permissions                             │    │
│  │  • Secrets in AWS Secrets Manager                      │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Rate Limiting Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   Usage Plans & Rate Limiting                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  JWT Token → API Gateway → Usage Plan Mapping                   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Basic Tier (tenant-basic)                               │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  Rate Limit:    10 requests/second                 │  │  │
│  │  │  Burst Limit:   20 requests                        │  │  │
│  │  │  Quota:         100,000 requests/month             │  │  │
│  │  │  Cost:          ~$3.50/month                       │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Standard Tier (tenant-standard)                         │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  Rate Limit:    100 requests/second                │  │  │
│  │  │  Burst Limit:   200 requests                       │  │  │
│  │  │  Quota:         1,000,000 requests/month           │  │  │
│  │  │  Cost:          ~$35/month                         │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Premium Tier (tenant-premium)                           │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  Rate Limit:    1000 requests/second               │  │  │
│  │  │  Burst Limit:   2000 requests                      │  │  │
│  │  │  Quota:         10,000,000 requests/month          │  │  │
│  │  │  Cost:          ~$350/month                        │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  When limit exceeded: HTTP 429 Too Many Requests                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Observability Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Observability Stack                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  AWS X-Ray (Distributed Tracing)                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • End-to-end request tracing                            │  │
│  │  • Service map visualization                             │  │
│  │  • Annotations: tenant_id, request_id, endpoint          │  │
│  │  • Metadata: request/response bodies                     │  │
│  │  • Error capture with stack traces                       │  │
│  │  • 30-day retention                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  CloudWatch Logs (Structured Logging)                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • JSON structured logs                                  │  │
│  │  • Log groups per Lambda function                        │  │
│  │  • API Gateway execution logs                            │  │
│  │  • Log Insights queries                                  │  │
│  │  • 7-day retention                                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  CloudWatch Metrics & Dashboard                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  API Gateway Metrics:                                    │  │
│  │    • Request count, 4xx/5xx errors, latency (p50/p99)   │  │
│  │                                                           │  │
│  │  Lambda Metrics:                                         │  │
│  │    • Invocations, duration, errors, throttles           │  │
│  │                                                           │  │
│  │  DynamoDB Metrics:                                       │  │
│  │    • Consumed capacity, throttles, latency              │  │
│  │                                                           │  │
│  │  Tenant Metrics:                                         │  │
│  │    • Per-tenant request volume, errors, latency         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  CloudWatch Alarms                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • High error rate (5xx > 5%)                            │  │
│  │  • High latency (p99 > 3s)                               │  │
│  │  • Throttling detected                                   │  │
│  │  • Lambda errors                                         │  │
│  │  • SNS notifications                                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  Infrastructure as Code (Terraform)              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  terraform/                                                      │
│  ├── main.tf              (Root module)                         │
│  ├── variables.tf         (Input variables)                     │
│  ├── outputs.tf           (Output values)                       │
│  └── modules/                                                    │
│      ├── api-gateway/     (REST API, authorizer, integrations)  │
│      ├── cognito/         (User pool, app clients)              │
│      ├── dynamodb/        (Table with tenant partitioning)      │
│      ├── lambda/          (Functions, layers, IAM roles)        │
│      ├── usage-plans/     (Rate limiting per tier)              │
│      └── cloudwatch/      (Dashboard, alarms, log groups)       │
│                                                                  │
│  Deployment Process:                                             │
│  1. terraform init        (Initialize providers)                │
│  2. terraform plan        (Preview changes)                     │
│  3. terraform apply       (Deploy infrastructure)               │
│  4. Seed data             (Populate DynamoDB)                   │
│  5. Test endpoints        (Verify deployment)                   │
│                                                                  │
│  State Management:                                               │
│  • Local backend (terraform.tfstate)                            │
│  • Can be migrated to S3 + DynamoDB for team use               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Cost Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Cost Breakdown (Monthly)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Basic Tier (100K requests/month):                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  API Gateway:    $0.35  (100K requests)                  │  │
│  │  Lambda:         $0.20  (100K invocations, 256MB, 500ms) │  │
│  │  DynamoDB:       $1.25  (Storage + requests)             │  │
│  │  Cognito:        $0.00  (< 50 MAU free tier)             │  │
│  │  X-Ray:          $0.50  (100K traces)                    │  │
│  │  CloudWatch:     $1.20  (Logs + metrics)                 │  │
│  │  ─────────────────────────────────────────────────────   │  │
│  │  Total:          ~$3.50/month                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Standard Tier (1M requests/month):                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  API Gateway:    $3.50  (1M requests)                    │  │
│  │  Lambda:         $2.00  (1M invocations)                 │  │
│  │  DynamoDB:       $12.50 (Storage + requests)             │  │
│  │  Cognito:        $0.00  (< 50 MAU free tier)             │  │
│  │  X-Ray:          $5.00  (1M traces)                      │  │
│  │  CloudWatch:     $12.00 (Logs + metrics)                 │  │
│  │  ─────────────────────────────────────────────────────   │  │
│  │  Total:          ~$35/month                              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Premium Tier (10M requests/month):                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  API Gateway:    $35.00  (10M requests)                  │  │
│  │  Lambda:         $20.00  (10M invocations)               │  │
│  │  DynamoDB:       $125.00 (Storage + requests)            │  │
│  │  Cognito:        $0.00   (< 50 MAU free tier)            │  │
│  │  X-Ray:          $50.00  (10M traces)                    │  │
│  │  CloudWatch:     $120.00 (Logs + metrics)                │  │
│  │  ─────────────────────────────────────────────────────   │  │
│  │  Total:          ~$350/month                             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Cost Optimization:                                              │
│  • DynamoDB on-demand (pay per request)                         │
│  • Lambda right-sized (256MB memory)                            │
│  • CloudWatch log retention (7 days)                            │
│  • X-Ray sampling (reduce trace volume)                         │
│  • Resource tagging for cost allocation                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Technology Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                      Technology Stack                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Infrastructure:                                                 │
│  • Terraform >= 1.0                                             │
│  • AWS Provider ~> 5.0                                          │
│                                                                  │
│  AWS Services:                                                   │
│  • API Gateway (REST API)                                       │
│  • Lambda (Python 3.9+)                                         │
│  • DynamoDB (On-Demand)                                         │
│  • Cognito (User Pools)                                         │
│  • X-Ray (Tracing)                                              │
│  • CloudWatch (Logs, Metrics, Dashboards)                       │
│  • Secrets Manager (Credentials)                                │
│                                                                  │
│  Lambda Runtime:                                                 │
│  • Python 3.9+                                                  │
│  • boto3 >= 1.26.0                                              │
│  • aws-xray-sdk >= 2.12.0                                       │
│                                                                  │
│  Testing:                                                        │
│  • pytest (Unit tests)                                          │
│  • Hypothesis (Property-based tests)                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```
