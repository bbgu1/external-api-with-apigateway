# AWS API Gateway Demo - Cost Estimation

## Overview

This document provides detailed cost estimates for the AWS API Gateway Demo solution across different usage levels. All costs are in USD and based on AWS pricing as of February 2026 for the US East (N. Virginia) region.

## Cost Components

### 1. API Gateway (REST API)

**Pricing Model**: Pay per request

- **Cost per million requests**: $3.50
- **Data transfer out**: $0.09/GB (first 10TB)

**Monthly Cost Calculation**:

| Usage Level | Requests/Month | API Gateway Cost | Data Transfer (est. 1KB/response) | Total |
|-------------|----------------|------------------|-----------------------------------|-------|
| Low (100K) | 100,000 | $0.35 | $0.01 | $0.36 |
| Medium (1M) | 1,000,000 | $3.50 | $0.09 | $3.59 |
| High (10M) | 10,000,000 | $35.00 | $0.90 | $35.90 |
| Very High (100M) | 100,000,000 | $350.00 | $9.00 | $359.00 |

**Per Tenant Tier**:
- Basic (100K/month): $0.36
- Standard (1M/month): $3.59
- Premium (10M/month): $35.90

### 2. AWS Lambda

**Pricing Model**: Pay per invocation and compute time

- **Invocation cost**: $0.20 per 1M requests
- **Compute cost**: $0.0000166667 per GB-second
- **Configuration**: 256MB memory, average 200ms duration

**Monthly Cost Calculation**:

| Usage Level | Invocations | Invocation Cost | Compute Time (GB-sec) | Compute Cost | Total |
|-------------|-------------|-----------------|----------------------|--------------|-------|
| Low (100K) | 100,000 | $0.02 | 5,000 | $0.08 | $0.10 |
| Medium (1M) | 1,000,000 | $0.20 | 50,000 | $0.83 | $1.03 |
| High (10M) | 10,000,000 | $2.00 | 500,000 | $8.33 | $10.33 |
| Very High (100M) | 100,000,000 | $20.00 | 5,000,000 | $83.33 | $103.33 |

**Notes**:
- Assumes 2 Lambda invocations per API request (Catalog or Order)
- First 1M requests and 400,000 GB-seconds per month are free tier
- Actual costs may be lower with free tier

### 3. DynamoDB

**Pricing Model**: On-demand (pay per request)

- **Write requests**: $1.25 per million write request units
- **Read requests**: $0.25 per million read request units
- **Storage**: $0.25 per GB-month

**Monthly Cost Calculation**:

| Usage Level | Reads | Writes | Read Cost | Write Cost | Storage (10GB) | Total |
|-------------|-------|--------|-----------|------------|----------------|-------|
| Low (100K) | 80,000 | 20,000 | $0.02 | $0.03 | $2.50 | $2.55 |
| Medium (1M) | 800,000 | 200,000 | $0.20 | $0.25 | $2.50 | $2.95 |
| High (10M) | 8,000,000 | 2,000,000 | $2.00 | $2.50 | $2.50 | $7.00 |
| Very High (100M) | 80,000,000 | 20,000,000 | $20.00 | $25.00 | $2.50 | $47.50 |

**Notes**:
- Assumes 80% reads, 20% writes
- Storage estimate based on 10GB of product and order data
- First 25 GB storage per month is free tier

### 4. AWS Cognito

**Pricing Model**: Monthly Active Users (MAU)

- **First 50,000 MAU**: Free
- **Next 50,000 MAU**: $0.0055 per MAU
- **Next 900,000 MAU**: $0.0046 per MAU
- **Over 1M MAU**: $0.00325 per MAU

**Monthly Cost Calculation**:

| Active Clients | Cost |
|----------------|------|
| 10 | $0.00 (Free tier) |
| 100 | $0.00 (Free tier) |
| 1,000 | $0.00 (Free tier) |
| 10,000 | $0.00 (Free tier) |
| 100,000 | $275.00 |

**Notes**:
- MAU = unique clients that authenticate at least once per month
- Most M2M scenarios have low MAU counts
- Free tier covers up to 50,000 MAU

### 5. AWS X-Ray

**Pricing Model**: Pay per trace

- **Traces recorded**: $5.00 per 1M traces
- **Traces retrieved**: $0.50 per 1M traces
- **Traces scanned**: $0.50 per 1M traces

**Monthly Cost Calculation**:

| Usage Level | Traces Recorded | Recording Cost | Retrieval (10%) | Retrieval Cost | Total |
|-------------|-----------------|----------------|-----------------|----------------|-------|
| Low (100K) | 100,000 | $0.50 | 10,000 | $0.01 | $0.51 |
| Medium (1M) | 1,000,000 | $5.00 | 100,000 | $0.05 | $5.05 |
| High (10M) | 10,000,000 | $50.00 | 1,000,000 | $0.50 | $50.50 |
| Very High (100M) | 100,000,000 | $500.00 | 10,000,000 | $5.00 | $505.00 |

**Notes**:
- First 100,000 traces per month are free tier
- Assumes 10% of traces are retrieved for analysis
- Trace retention: 30 days

### 6. CloudWatch

**Pricing Components**:

- **Logs ingestion**: $0.50 per GB
- **Logs storage**: $0.03 per GB-month
- **Metrics**: $0.30 per custom metric per month
- **Dashboard**: $3.00 per dashboard per month
- **Alarms**: $0.10 per alarm per month

**Monthly Cost Calculation**:

| Component | Low Usage | Medium Usage | High Usage | Very High Usage |
|-----------|-----------|--------------|------------|-----------------|
| Logs ingestion (1KB/request) | $0.05 | $0.50 | $5.00 | $50.00 |
| Logs storage (7-day retention) | $0.01 | $0.10 | $1.00 | $10.00 |
| Custom metrics (20) | $6.00 | $6.00 | $6.00 | $6.00 |
| Dashboard (1) | $3.00 | $3.00 | $3.00 | $3.00 |
| Alarms (5) | $0.50 | $0.50 | $0.50 | $0.50 |
| **Total** | **$9.56** | **$10.10** | **$15.50** | **$69.50** |

**Notes**:
- First 5GB logs ingestion per month is free tier
- First 10 custom metrics and 10 alarms are free tier
- Actual costs may be lower with free tier

## Total Monthly Cost Summary

### By Usage Level

| Usage Level | API Gateway | Lambda | DynamoDB | Cognito | X-Ray | CloudWatch | **Total** |
|-------------|-------------|--------|----------|---------|-------|------------|-----------|
| **Low (100K req/month)** | $0.36 | $0.10 | $2.55 | $0.00 | $0.51 | $9.56 | **$13.08** |
| **Medium (1M req/month)** | $3.59 | $1.03 | $2.95 | $0.00 | $5.05 | $10.10 | **$22.72** |
| **High (10M req/month)** | $35.90 | $10.33 | $7.00 | $0.00 | $50.50 | $15.50 | **$119.23** |
| **Very High (100M req/month)** | $359.00 | $103.33 | $47.50 | $0.00 | $505.00 | $69.50 | **$1,084.33** |

### By Tenant Tier (Monthly)

| Tier | Quota | Estimated Cost per Tenant |
|------|-------|---------------------------|
| **Basic** | 100K requests | $13.08 |
| **Standard** | 1M requests | $22.72 |
| **Premium** | 10M requests | $119.23 |

**Notes**:
- Costs assume single tenant at each tier
- Multiple tenants sharing infrastructure will have economies of scale
- Free tier benefits can significantly reduce costs for low usage

## Cost Breakdown by Service (Medium Usage)

```
Total: $22.72/month

CloudWatch:     $10.10 (44.5%) ████████████████████
X-Ray:          $5.05  (22.2%) ██████████
API Gateway:    $3.59  (15.8%) ███████
DynamoDB:       $2.95  (13.0%) ██████
Lambda:         $1.03  (4.5%)  ██
Cognito:        $0.00  (0.0%)  
```

## Most Expensive Components

### 1. CloudWatch ($10.10 at medium usage)
- **Why**: Fixed costs for dashboards and custom metrics
- **Optimization**: 
  - Reduce custom metric count
  - Decrease log retention period
  - Use metric filters instead of custom metrics
  - Consider CloudWatch Logs Insights for ad-hoc queries

### 2. X-Ray ($5.05 at medium usage)
- **Why**: Traces every API request
- **Optimization**:
  - Sample traces (e.g., 10% sampling) instead of 100%
  - Reduce trace retention period
  - Disable tracing in non-production environments

### 3. API Gateway ($3.59 at medium usage)
- **Why**: Per-request pricing
- **Optimization**:
  - Use caching to reduce backend calls
  - Batch requests where possible
  - Consider HTTP API instead of REST API (cheaper)

### 4. DynamoDB ($2.95 at medium usage)
- **Why**: On-demand pricing for reads/writes
- **Optimization**:
  - Use provisioned capacity for predictable workloads
  - Enable DynamoDB caching (DAX) for read-heavy workloads
  - Optimize data model to reduce request count

### 5. Lambda ($1.03 at medium usage)
- **Why**: Compute time and invocations
- **Optimization**:
  - Reduce memory allocation if possible
  - Optimize code for faster execution
  - Use Lambda reserved concurrency for cost predictability

## Cost Scaling Analysis

### Linear Scaling Components
- API Gateway: Scales linearly with request count
- Lambda: Scales linearly with invocations
- DynamoDB: Scales linearly with read/write operations
- X-Ray: Scales linearly with trace count

### Fixed Cost Components
- CloudWatch Dashboard: $3/month regardless of usage
- CloudWatch Alarms: $0.10/alarm/month
- Custom Metrics: $0.30/metric/month

### Cost per Request

| Usage Level | Total Cost | Requests | Cost per 1K Requests |
|-------------|------------|----------|----------------------|
| Low | $13.08 | 100,000 | $0.131 |
| Medium | $22.72 | 1,000,000 | $0.023 |
| High | $119.23 | 10,000,000 | $0.012 |
| Very High | $1,084.33 | 100,000,000 | $0.011 |

**Observation**: Cost per request decreases with scale due to fixed CloudWatch costs being amortized.

## Multi-Tenant Cost Allocation

### Shared Infrastructure Costs

Some costs are shared across all tenants:
- CloudWatch Dashboard: $3/month
- CloudWatch Alarms: $0.50/month
- Base custom metrics: ~$3/month

**Total shared**: ~$6.50/month

### Per-Tenant Variable Costs

Costs that scale with tenant usage:
- API Gateway: $3.50 per million requests
- Lambda: ~$1.00 per million requests
- DynamoDB: ~$3.00 per million requests
- X-Ray: ~$5.00 per million requests
- CloudWatch Logs: ~$0.50 per million requests

**Total variable**: ~$13.00 per million requests

### Cost Allocation Strategy

For 3 tenants (Basic, Standard, Premium):

| Tenant | Requests | Variable Cost | Shared Cost (33%) | Total Cost |
|--------|----------|---------------|-------------------|------------|
| Basic | 100K | $1.30 | $2.17 | $3.47 |
| Standard | 1M | $13.00 | $2.17 | $15.17 |
| Premium | 10M | $130.00 | $2.17 | $132.17 |
| **Total** | **11.1M** | **$144.30** | **$6.51** | **$150.81** |

## Cost Optimization Recommendations

### Immediate Optimizations (0-30 days)

1. **Enable X-Ray Sampling**: Reduce to 10% sampling → Save ~$4.50/month at medium usage
2. **Reduce Log Retention**: Change from 7 days to 3 days → Save ~$0.05/month
3. **Optimize Lambda Memory**: Test with 128MB instead of 256MB → Save ~$0.50/month

**Potential savings**: ~$5/month (22% reduction at medium usage)

### Medium-term Optimizations (1-3 months)

1. **Implement API Caching**: Cache GET requests for 5 minutes → Reduce backend calls by 30%
2. **DynamoDB Provisioned Capacity**: Switch from on-demand for predictable workloads → Save ~$1/month
3. **Consolidate Custom Metrics**: Reduce from 20 to 10 metrics → Save $3/month

**Potential savings**: ~$7/month (31% reduction at medium usage)

### Long-term Optimizations (3-6 months)

1. **Migrate to HTTP API**: Replace REST API with HTTP API → Save ~$2.50/month at medium usage
2. **Implement DynamoDB DAX**: Cache read-heavy operations → Reduce read costs by 50%
3. **Lambda SnapStart**: Reduce cold start times and duration → Save ~$0.30/month

**Potential savings**: ~$4/month (18% reduction at medium usage)

## Free Tier Benefits

### First 12 Months (New AWS Accounts)

- Lambda: 1M requests + 400,000 GB-seconds per month
- DynamoDB: 25 GB storage + 25 read/write capacity units
- CloudWatch: 10 custom metrics + 10 alarms + 5GB logs
- X-Ray: 100,000 traces per month
- API Gateway: 1M requests per month (first 12 months)

**Estimated savings for medium usage**: ~$15/month for first year

### Always Free

- Lambda: 1M requests + 400,000 GB-seconds per month
- DynamoDB: 25 GB storage
- CloudWatch: 10 custom metrics + 10 alarms + 5GB logs
- X-Ray: 100,000 traces per month
- Cognito: 50,000 MAU

**Estimated ongoing savings**: ~$10/month

## Cost Monitoring and Alerts

### Recommended Cost Alarms

1. **Daily Cost Threshold**: Alert if daily cost exceeds $5
2. **Monthly Projection**: Alert if projected monthly cost exceeds $100
3. **Per-Service Anomaly**: Alert on 50% increase in any service cost
4. **Per-Tenant Budget**: Alert if tenant exceeds allocated budget

### Cost Allocation Tags

All resources should be tagged with:
- `Project`: api-gateway-demo
- `Environment`: dev/staging/prod
- `TenantId`: tenant-xxx (where applicable)
- `CostCenter`: engineering
- `ManagedBy`: terraform

## Conclusion

### Key Findings

1. **Most Expensive**: CloudWatch and X-Ray dominate costs at low-medium usage
2. **Best Value**: Cost per request decreases significantly with scale
3. **Optimization Potential**: 40-50% cost reduction possible with optimizations
4. **Multi-Tenant Economics**: Shared infrastructure costs favor higher tenant counts

### Recommended Pricing Strategy

For SaaS pricing, consider:
- Basic tier: $20/month (53% margin at 100K requests)
- Standard tier: $50/month (69% margin at 1M requests)
- Premium tier: $200/month (40% margin at 10M requests)

### Next Steps

1. Enable cost allocation tags on all resources
2. Set up AWS Cost Explorer with tenant-level filtering
3. Implement cost monitoring dashboards
4. Review and optimize monthly based on actual usage patterns
