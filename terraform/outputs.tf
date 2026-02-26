# Outputs for AWS API Gateway Demo Solution

# API Gateway Outputs
output "api_endpoint_url" {
  description = "Base URL for the API Gateway endpoint"
  value       = module.api_gateway.api_endpoint_url
}

output "api_id" {
  description = "ID of the API Gateway REST API"
  value       = module.api_gateway.api_id
}

output "api_stage_name" {
  description = "Name of the API Gateway stage"
  value       = module.api_gateway.stage_name
}

# Cognito Outputs
output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = module.cognito.user_pool_arn
}

output "cognito_user_pool_endpoint" {
  description = "Endpoint URL for the Cognito User Pool"
  value       = module.cognito.user_pool_endpoint
}

output "cognito_token_endpoint" {
  description = "OAuth 2.0 token endpoint for authentication"
  value       = module.cognito.token_endpoint
}

# DynamoDB Outputs
output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = module.dynamodb.table_arn
}

# Lambda Outputs
output "catalog_lambda_function_name" {
  description = "Name of the Catalog Lambda function"
  value       = module.lambda.catalog_lambda_name
}

output "catalog_lambda_function_arn" {
  description = "ARN of the Catalog Lambda function"
  value       = module.lambda.catalog_lambda_arn
}

output "order_lambda_function_name" {
  description = "Name of the Order Lambda function"
  value       = module.lambda.order_lambda_name
}

output "order_lambda_function_arn" {
  description = "ARN of the Order Lambda function"
  value       = module.lambda.order_lambda_arn
}

# CloudWatch Dashboard Outputs
output "cloudwatch_dashboard_url" {
  description = "URL to access the CloudWatch Application Signals dashboard"
  value       = module.cloudwatch.dashboard_url
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = module.cloudwatch.dashboard_name
}

output "cloudwatch_logs_insights_url" {
  description = "URL to CloudWatch Logs Insights for custom queries"
  value       = module.cloudwatch.logs_insights_url
}

output "cloudwatch_xray_service_map_url" {
  description = "URL to X-Ray service map"
  value       = module.cloudwatch.xray_service_map_url
}

# X-Ray Outputs
output "xray_enabled" {
  description = "Whether X-Ray tracing is enabled"
  value       = var.enable_xray_tracing
}

# Deployment Information
output "deployment_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "aws_region" {
  description = "AWS region where resources are deployed (alias for deployment_region)"
  value       = var.aws_region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

# SSM Parameters (needed by tenants workspace)
output "tenant_map_ssm_parameter_name" {
  description = "SSM parameter name for tenant-to-API-key map"
  value       = aws_ssm_parameter.tenant_api_key_map.name
}

output "client_tenant_map_ssm_parameter_name" {
  description = "SSM parameter name for client-id-to-tenant-id map"
  value       = aws_ssm_parameter.client_tenant_map.name
}

# Quick Start Guide
output "quick_start_guide" {
  description = "Quick start instructions for using the API"
  value       = <<-EOT
    
    ========================================
    AWS API Gateway Demo - Quick Start
    ========================================
    
    1. API Endpoint:
       ${module.api_gateway.api_endpoint_url}
    
    2. Authentication:
       Token Endpoint: ${module.cognito.token_endpoint}
       
       Get a token (replace with your tenant credentials from tenants workspace):
       curl -X POST ${module.cognito.token_endpoint} \
         -H "Content-Type: application/x-www-form-urlencoded" \
         -d "grant_type=client_credentials&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET&scope=api/read"
    
    3. API Endpoints:
       GET  ${module.api_gateway.api_endpoint_url}/catalog
       GET  ${module.api_gateway.api_endpoint_url}/catalog/{productId}
       POST ${module.api_gateway.api_endpoint_url}/orders
       GET  ${module.api_gateway.api_endpoint_url}/orders/{orderId}
    
    4. Example API Call:
       curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
         ${module.api_gateway.api_endpoint_url}/catalog
    
    5. Monitoring:
       CloudWatch Dashboard: ${module.cloudwatch.dashboard_url}
       X-Ray Service Map: ${module.cloudwatch.xray_service_map_url}
       Logs Insights: ${module.cloudwatch.logs_insights_url}
    
    6. Manage tenants in terraform/tenants/ workspace.
    
    ========================================
  EOT
}

# Alias for backward compatibility with test scripts
output "api_gateway_id" {
  description = "ID of the API Gateway REST API (alias for api_id)"
  value       = module.api_gateway.api_id
}
