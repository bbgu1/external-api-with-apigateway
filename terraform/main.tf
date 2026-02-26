# AWS API Gateway Demo Solution
# Main Terraform configuration

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  # Local backend for state management
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "Terraform"
        CostCenter  = var.cost_center
        Owner       = var.owner
      },
      var.tags
    )
  }
}

# DynamoDB Table
module "dynamodb" {
  source = "./modules/dynamodb"

  environment  = var.environment
  project_name = var.project_name
  table_name   = var.dynamodb_table_name
}

# Cognito User Pool (shared — per-tenant clients managed in terraform/tenants)
module "cognito" {
  source = "./modules/cognito"

  environment  = var.environment
  project_name = var.project_name
}

# SSM Parameter for tenant-to-API-key mapping
# Initially empty — populated by the terraform/tenants workspace
resource "aws_ssm_parameter" "tenant_api_key_map" {
  name        = "/${var.environment}/${var.project_name}/tenant-api-key-map"
  description = "JSON map of tenant_id to API Gateway API key value"
  type        = "SecureString"
  value       = "{}"

  tags = {
    Name        = "${var.environment}-tenant-api-key-map"
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [value]
  }
}

# SSM Parameter for client-to-tenant mapping
# Initially empty — populated by the terraform/tenants workspace
resource "aws_ssm_parameter" "client_tenant_map" {
  name        = "/${var.environment}/${var.project_name}/client-tenant-map"
  description = "JSON map of Cognito client_id to tenant_id"
  type        = "SecureString"
  value       = "{}"

  tags = {
    Name        = "${var.environment}-client-tenant-map"
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [value]
  }
}

# Lambda Functions
module "lambda" {
  source = "./modules/lambda"

  environment                 = var.environment
  project_name                = var.project_name
  dynamodb_table_name         = module.dynamodb.table_name
  dynamodb_table_arn          = module.dynamodb.table_arn
  lambda_memory_size          = var.lambda_memory_size
  lambda_timeout              = var.lambda_timeout
  log_retention_days          = var.log_retention_days
  enable_xray_tracing         = var.enable_xray_tracing

  # Authorizer configuration
  cognito_user_pool_id             = module.cognito.user_pool_id
  tenant_map_ssm_parameter_arn     = aws_ssm_parameter.tenant_api_key_map.arn
  tenant_map_ssm_path              = aws_ssm_parameter.tenant_api_key_map.name
  client_tenant_map_ssm_parameter_arn = aws_ssm_parameter.client_tenant_map.arn
  client_tenant_map_ssm_path          = aws_ssm_parameter.client_tenant_map.name
}

# API Gateway
module "api_gateway" {
  source = "./modules/api-gateway"

  environment                  = var.environment
  cognito_user_pool_arn        = module.cognito.user_pool_arn
  cognito_user_pool_id         = module.cognito.user_pool_id
  catalog_lambda_arn           = module.lambda.catalog_lambda_arn
  catalog_lambda_name          = module.lambda.catalog_lambda_name
  order_lambda_arn             = module.lambda.order_lambda_arn
  order_lambda_name            = module.lambda.order_lambda_name
  authorizer_lambda_invoke_arn = module.lambda.authorizer_lambda_invoke_arn
  authorizer_lambda_name       = module.lambda.authorizer_lambda_name
  enable_xray_tracing          = var.enable_xray_tracing
  enable_logging               = var.enable_api_gateway_logging
  log_level                    = var.api_gateway_log_level
  log_retention_days           = var.log_retention_days
}

# CloudWatch Dashboard
module "cloudwatch" {
  source = "./modules/cloudwatch"

  environment         = var.environment
  project_name        = var.project_name
  aws_region          = var.aws_region
  api_id              = module.api_gateway.api_id
  api_name            = module.api_gateway.api_name
  api_stage_name      = module.api_gateway.stage_name
  catalog_lambda_name = module.lambda.catalog_lambda_name
  order_lambda_name   = module.lambda.order_lambda_name
  dynamodb_table_name = module.dynamodb.table_name
  tiers               = var.tiers
  enable_cost_widgets = true
}


