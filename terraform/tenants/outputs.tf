# Tenant Workspace Outputs

output "cognito_client_ids" {
  description = "Map of tenant ID to Cognito app client ID"
  value       = { for k, v in aws_cognito_user_pool_client.tenant : k => v.id }
}

output "cognito_client_secrets" {
  description = "Map of tenant ID to Cognito app client secret"
  value       = { for k, v in aws_cognito_user_pool_client.tenant : k => v.client_secret }
  sensitive   = true
}

output "tenant_credentials" {
  description = "Quick reference: tenant credentials for testing"
  value = {
    for tenant_id, _ in var.tenants :
    tenant_id => {
      client_id = aws_cognito_user_pool_client.tenant[tenant_id].id
      tier      = var.tenants[tenant_id].tier
    }
  }
}
