# Tenant Lifecycle Management
# Separate Terraform workspace for onboarding/offboarding tenants
# without touching core infrastructure.

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Component   = "tenants"
    }
  }
}

# Cognito User Pool data source (read-only reference)
data "aws_cognito_user_pools" "main" {
  name = "${var.project_name}-${var.environment}"
}

# API Gateway REST API data source
data "aws_api_gateway_rest_api" "main" {
  name = "${var.project_name}-${var.environment}"
}

locals {
  ssm_parameter_name             = "/${var.environment}/${var.project_name}/tenant-api-key-map"
  client_tenant_map_ssm_name     = "/${var.environment}/${var.project_name}/client-tenant-map"
}

# ============================================================================
# Usage Plans — One per Tier
# ============================================================================

resource "aws_api_gateway_usage_plan" "tier_plans" {
  for_each = var.tiers

  name        = "${var.project_name}-${var.environment}-${each.key}-tier"
  description = "Usage plan for ${each.key} tier tenants"

  api_stages {
    api_id = data.aws_api_gateway_rest_api.main.id
    stage  = var.stage_name
  }

  throttle_settings {
    rate_limit  = each.value.rate_limit
    burst_limit = each.value.burst_limit
  }

  quota_settings {
    limit  = each.value.quota_limit
    period = upper(each.value.quota_period)
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-tier"
    Environment = var.environment
    Tier        = each.key
  }
}

# ============================================================================
# Per-Tenant Resources
# ============================================================================

# Cognito App Client per tenant (M2M client credentials flow)
resource "aws_cognito_user_pool_client" "tenant" {
  for_each = var.tenants

  name         = "${var.environment}-${each.key}"
  user_pool_id = tolist(data.aws_cognito_user_pools.main.ids)[0]

  generate_secret              = true
  allowed_oauth_flows          = ["client_credentials"]
  allowed_oauth_scopes         = ["${var.cognito_resource_server_identifier}/read", "${var.cognito_resource_server_identifier}/write"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers = ["COGNITO"]

  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  token_validity_units {
    access_token = "hours"
  }

  access_token_validity = 1
}

# API Gateway API Key per tenant
resource "aws_api_gateway_api_key" "tenant" {
  for_each = var.tenants

  name    = "${var.environment}-${each.key}"
  enabled = true

  tags = {
    TenantId = each.key
    Tier     = each.value.tier
  }
}

# Associate each tenant's API key with the correct tier usage plan
resource "aws_api_gateway_usage_plan_key" "tenant" {
  for_each = var.tenants

  key_id        = aws_api_gateway_api_key.tenant[each.key].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.tier_plans[each.value.tier].id
}

# ============================================================================
# SSM Parameters — Aggregate maps for the Lambda authorizer
# ============================================================================

# Build the JSON map and write it to the SSM parameter created by core infra.
# The Lambda authorizer reads this at runtime to resolve tenant_id → API key value.
resource "aws_ssm_parameter" "tenant_api_key_map" {
  name      = local.ssm_parameter_name
  type      = "SecureString"
  overwrite = true

  value = jsonencode({
    for tenant_id, _ in var.tenants :
    tenant_id => aws_api_gateway_api_key.tenant[tenant_id].value
  })

  tags = {
    Name        = "${var.environment}-tenant-api-key-map"
    Environment = var.environment
  }
}

# Build the JSON map of Cognito client_id → tenant_id.
# The Lambda authorizer reads this at runtime to resolve who the caller is.
resource "aws_ssm_parameter" "client_tenant_map" {
  name      = local.client_tenant_map_ssm_name
  type      = "SecureString"
  overwrite = true

  value = jsonencode({
    for tenant_id, _ in var.tenants :
    aws_cognito_user_pool_client.tenant[tenant_id].id => tenant_id
  })

  tags = {
    Name        = "${var.environment}-client-tenant-map"
    Environment = var.environment
  }
}
