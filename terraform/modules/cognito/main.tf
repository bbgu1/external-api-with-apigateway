# Cognito User Pool for Multi-Tenant Authentication

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

locals {
  user_pool_name = var.user_pool_name != "" ? var.user_pool_name : "${var.project_name}-${var.environment}"
}

# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = local.user_pool_name

  # Disable user sign-up since this is for M2M authentication
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  # Custom attribute for tenant_id
  schema {
    name                = "tenant_id"
    attribute_data_type = "String"
    mutable             = false
    required            = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # Password policy (not used for M2M but required)
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  # Account recovery settings
  account_recovery_setting {
    recovery_mechanism {
      name     = "admin_only"
      priority = 1
    }
  }

  tags = {
    Name        = local.user_pool_name
    Environment = var.environment
    Application = "authentication"
  }
}

# Cognito User Pool Domain for OAuth endpoints
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${local.user_pool_name}-${random_string.domain_suffix.result}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# Random string for unique domain name
resource "random_string" "domain_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Resource Server for custom scopes
resource "aws_cognito_resource_server" "api" {
  identifier   = "api"
  name         = "API Resource Server"
  user_pool_id = aws_cognito_user_pool.main.id

  scope {
    scope_name        = "read"
    scope_description = "Read access to API"
  }

  scope {
    scope_name        = "write"
    scope_description = "Write access to API"
  }
}

# NOTE: Per-tenant Cognito app clients are now managed in terraform/tenants workspace.
# This module only creates the shared user pool, domain, and resource server.

# Data source to get current AWS region (used in token_endpoint output)
data "aws_region" "current" {}
