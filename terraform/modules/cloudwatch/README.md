# CloudWatch Dashboard Module

This Terraform module creates a comprehensive CloudWatch dashboard for monitoring the AWS API Gateway demo solution. The dashboard provides real-time visibility into API Gateway, Lambda, DynamoDB, and tenant-specific metrics.

## Features

- **API Gateway Metrics**: Request count, error rates (4xx/5xx), latency (p50, p90, p99), cache performance
- **Lambda Metrics**: Invocations, duration, errors, throttles, concurrent executions
- **DynamoDB Metrics**: Consumed capacity units, errors, throttling, operation latency
- **Tenant-Specific Metrics**: Request count, error rate, latency by tenant using CloudWatch Logs Insights
- **Cost Metrics**: Estimated costs for API Gateway, Lambda, and DynamoDB based on usage
- **System Health Summary**: Tenant configuration and quick links to AWS Console

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name (dev, staging, prod) | `string` | n/a | yes |
| aws_region | AWS region for CloudWatch dashboard | `string` | `"us-east-1"` | no |
| api_id | ID of the API Gateway REST API | `string` | n/a | yes |
| api_name | Name of the API Gateway REST API | `string` | n/a | yes |
| api_stage_name | Name of the API Gateway stage | `string` | n/a | yes |
| catalog_lambda_name | Name of the Catalog Lambda function | `string` | n/a | yes |
| order_lambda_name | Name of the Order Lambda function | `string` | n/a | yes |
| dynamodb_table_name | Name of the DynamoDB table | `string` | n/a | yes |
| tenants | Configuration for multi-tenant setup | `map(object)` | n/a | yes |
| dashboard_name | Name of the CloudWatch dashboard | `string` | `""` | no |
| enable_cost_widgets | Enable cost estimation widgets | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| dashboard_name | Name of the CloudWatch dashboard |
| dashboard_arn | ARN of the CloudWatch dashboard |
| dashboard_url | URL to access the dashboard in AWS Console |
| log_group_name | Name of the CloudWatch log group for dashboard queries |
| log_group_arn | ARN of the CloudWatch log group |
| logs_insights_url | URL to CloudWatch Logs Insights |
| xray_service_map_url | URL to X-Ray service map |
| tenant_ids | List of tenant IDs configured |
| tenants_by_tier | Map of tenant tiers to tenant IDs |

## Dashboard Sections

### 1. API Gateway Metrics
- **Request Count and Errors**: Total requests, 4xx errors, 5xx errors
- **Latency**: Average, p50, p90, p99 latency with 3-second SLA threshold
- **Error Rate**: Percentage of 4xx and 5xx errors with 5% critical threshold
- **Cache Performance**: Cache hits and misses

### 2. Lambda Metrics
- **Invocations**: Total invocations for Catalog and Order Lambda functions
- **Duration**: Average and maximum duration with 2-second warning threshold
- **Errors and Throttles**: Error count and throttle count per function
- **Concurrent Executions**: Maximum concurrent executions

### 3. DynamoDB Metrics
- **Consumed Capacity Units**: Read and write capacity consumption
- **Errors and Throttling**: User errors, system errors, read/write throttles
- **Operation Latency**: Average and p99 latency for GetItem, PutItem, Query operations
- **Account Limits**: Maximum table-level read/write capacity

### 4. Tenant-Specific Metrics
Uses CloudWatch Logs Insights queries to analyze tenant-level data:
- **Requests by Tenant**: Total request count per tenant
- **Errors by Tenant**: Error count per tenant
- **Average Latency by Tenant**: Average and max latency per tenant
- **Top Endpoints by Tenant**: Most frequently accessed endpoints per tenant

### 5. Cost Metrics (Optional)
Estimated costs based on resource usage:
- **API Gateway Cost**: $3.50 per million requests
- **Lambda Cost**: $0.20 per million requests + compute time
- **DynamoDB Cost**: On-demand pricing for read/write requests
- **Cost Breakdown**: Tenant tier summary and pricing notes

### 6. System Health Summary
- Tenant configuration with rate limits and quotas
- Quick links to AWS Console (X-Ray, API Gateway, Lambda, DynamoDB, Logs Insights)

## Usage Example

```hcl
module "cloudwatch" {
  source = "./modules/cloudwatch"

  environment         = "dev"
  aws_region          = "us-east-1"
  api_id              = module.api_gateway.api_id
  api_name            = module.api_gateway.api_name
  api_stage_name      = module.api_gateway.stage_name
  catalog_lambda_name = module.lambda.catalog_lambda_name
  order_lambda_name   = module.lambda.order_lambda_name
  dynamodb_table_name = module.dynamodb.table_name
  
  tenants = {
    "tenant-basic-001" = {
      tier         = "basic"
      rate_limit   = 10
      burst_limit  = 20
      quota_limit  = 100000
      quota_period = "MONTH"
    }
    "tenant-standard-001" = {
      tier         = "standard"
      rate_limit   = 100
      burst_limit  = 200
      quota_limit  = 1000000
      quota_period = "MONTH"
    }
  }
  
  dashboard_name       = "my-api-dashboard"
  enable_cost_widgets  = true
}
```

## Accessing the Dashboard

After deployment, access the dashboard using:

1. **AWS Console**: Use the `dashboard_url` output
2. **Direct Link**: `https://console.aws.amazon.com/cloudwatch/home?region=<region>#dashboards:name=<dashboard_name>`
3. **AWS CLI**: `aws cloudwatch get-dashboard --dashboard-name <dashboard_name>`

## Filtering by Tenant

To filter metrics by specific tenant:

1. Navigate to CloudWatch Logs Insights
2. Select Lambda log groups: `/aws/lambda/<catalog_lambda_name>` and `/aws/lambda/<order_lambda_name>`
3. Use queries like:
   ```
   fields @timestamp, tenantId, @message
   | filter tenantId = "tenant-basic-001"
   | stats count() by bin(5m)
   ```

## Cost Estimation

The dashboard includes estimated costs based on:
- **API Gateway**: $3.50 per million requests
- **Lambda**: $0.20 per million requests + $0.00001667 per GB-second (256MB memory)
- **DynamoDB**: $0.25 per million read requests, $1.25 per million write requests (on-demand)

**Note**: These are estimates. Use AWS Cost Explorer with resource tags for accurate cost allocation.

## Monitoring Best Practices

1. **Set Up Alarms**: Create CloudWatch alarms for critical metrics (error rate, latency, throttling)
2. **Review Regularly**: Check dashboard daily for anomalies
3. **Tenant Analysis**: Use Logs Insights to identify problematic tenants
4. **Cost Optimization**: Monitor cost metrics to identify expensive operations
5. **X-Ray Integration**: Use X-Ray service map for detailed request tracing

## Requirements Validation

This module satisfies the following requirements:
- **10.1**: Display request rate, error rate, and latency metrics per tenant
- **10.2**: Display API Gateway metrics including 4xx and 5xx error rates
- **10.3**: Display Lambda function metrics including invocation count, duration, and errors
- **10.4**: Display DynamoDB metrics including read/write capacity and throttling
- **10.7**: Allow filtering metrics by tenant_id
- **14.5**: Include cost metrics for monitoring actual usage and costs per tenant

## Related Resources

- [CloudWatch Dashboards Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Dashboards.html)
- [CloudWatch Logs Insights Query Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [AWS X-Ray Service Map](https://docs.aws.amazon.com/xray/latest/devguide/xray-console-servicemap.html)
