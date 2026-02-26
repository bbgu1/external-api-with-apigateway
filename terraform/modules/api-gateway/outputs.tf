# API Gateway Module Outputs

output "api_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_name" {
  description = "Name of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.name
}

output "api_arn" {
  description = "ARN of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.arn
}

output "api_endpoint_url" {
  description = "Base URL for the API Gateway endpoint"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_execution_arn" {
  description = "Execution ARN of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.main.stage_name
}

output "stage_arn" {
  description = "ARN of the API Gateway stage"
  value       = aws_api_gateway_stage.main.arn
}

output "deployment_id" {
  description = "ID of the API Gateway deployment"
  value       = aws_api_gateway_deployment.main.id
}

output "authorizer_id" {
  description = "ID of the Lambda authorizer"
  value       = aws_api_gateway_authorizer.lambda_authorizer.id
}

output "catalog_resource_id" {
  description = "ID of the /catalog resource"
  value       = aws_api_gateway_resource.catalog.id
}

output "catalog_product_resource_id" {
  description = "ID of the /catalog/{productId} resource"
  value       = aws_api_gateway_resource.catalog_product.id
}

output "orders_resource_id" {
  description = "ID of the /orders resource"
  value       = aws_api_gateway_resource.orders.id
}

output "orders_order_resource_id" {
  description = "ID of the /orders/{orderId} resource"
  value       = aws_api_gateway_resource.orders_order.id
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for API Gateway"
  value       = var.enable_logging ? aws_cloudwatch_log_group.api_gateway[0].name : null
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for API Gateway"
  value       = var.enable_logging ? aws_cloudwatch_log_group.api_gateway[0].arn : null
}

output "xray_tracing_enabled" {
  description = "Whether X-Ray tracing is enabled"
  value       = aws_api_gateway_stage.main.xray_tracing_enabled
}

# Endpoint URLs for convenience
output "catalog_endpoint" {
  description = "Full URL for the /catalog endpoint"
  value       = "${aws_api_gateway_stage.main.invoke_url}/catalog"
}

output "orders_endpoint" {
  description = "Full URL for the /orders endpoint"
  value       = "${aws_api_gateway_stage.main.invoke_url}/orders"
}
