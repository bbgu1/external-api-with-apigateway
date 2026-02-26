# Lambda Module Outputs

# Catalog Lambda outputs
output "catalog_lambda_arn" {
  description = "ARN of the Catalog Lambda function"
  value       = aws_lambda_function.catalog.arn
}

output "catalog_lambda_name" {
  description = "Name of the Catalog Lambda function"
  value       = aws_lambda_function.catalog.function_name
}

output "catalog_lambda_invoke_arn" {
  description = "Invoke ARN of the Catalog Lambda function"
  value       = aws_lambda_function.catalog.invoke_arn
}

output "catalog_lambda_qualified_arn" {
  description = "Qualified ARN of the Catalog Lambda function"
  value       = aws_lambda_function.catalog.qualified_arn
}

# Order Lambda outputs
output "order_lambda_arn" {
  description = "ARN of the Order Lambda function"
  value       = aws_lambda_function.order.arn
}

output "order_lambda_name" {
  description = "Name of the Order Lambda function"
  value       = aws_lambda_function.order.function_name
}

output "order_lambda_invoke_arn" {
  description = "Invoke ARN of the Order Lambda function"
  value       = aws_lambda_function.order.invoke_arn
}

output "order_lambda_qualified_arn" {
  description = "Qualified ARN of the Order Lambda function"
  value       = aws_lambda_function.order.qualified_arn
}

# Shared layer outputs
output "shared_layer_arn" {
  description = "ARN of the shared Lambda layer"
  value       = aws_lambda_layer_version.shared_layer.arn
}

output "shared_layer_version" {
  description = "Version of the shared Lambda layer"
  value       = aws_lambda_layer_version.shared_layer.version
}

# IAM role outputs
output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution IAM role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "lambda_execution_role_name" {
  description = "Name of the Lambda execution IAM role"
  value       = aws_iam_role.lambda_execution_role.name
}

# Authorizer Lambda outputs
output "authorizer_lambda_arn" {
  description = "ARN of the Lambda authorizer function"
  value       = aws_lambda_function.authorizer.arn
}

output "authorizer_lambda_name" {
  description = "Name of the Lambda authorizer function"
  value       = aws_lambda_function.authorizer.function_name
}

output "authorizer_lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda authorizer function"
  value       = aws_lambda_function.authorizer.invoke_arn
}
