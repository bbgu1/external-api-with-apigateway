# Cognito Module Outputs

output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_endpoint" {
  description = "Endpoint URL for the Cognito User Pool"
  value       = aws_cognito_user_pool.main.endpoint
}

output "user_pool_domain" {
  description = "Domain prefix for the Cognito User Pool"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "token_endpoint" {
  description = "OAuth 2.0 token endpoint for authentication"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/token"
}

output "resource_server_identifier" {
  description = "Identifier of the resource server"
  value       = aws_cognito_resource_server.api.identifier
}
