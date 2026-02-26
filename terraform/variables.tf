# Variables for AWS API Gateway Demo Solution

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for storing products and orders"
  type        = string
  default     = "api-gateway-demo"
}

variable "tiers" {
  description = "Rate limiting configuration per tier (basic, standard, premium)"
  type = map(object({
    rate_limit   = number
    burst_limit  = number
    quota_limit  = number
    quota_period = string
  }))

  default = {
    "basic" = {
      rate_limit   = 10
      burst_limit  = 20
      quota_limit  = 100000
      quota_period = "MONTH"
    }
    "standard" = {
      rate_limit   = 100
      burst_limit  = 200
      quota_limit  = 1000000
      quota_period = "MONTH"
    }
    "premium" = {
      rate_limit   = 1000
      burst_limit  = 2000
      quota_limit  = 10000000
      quota_period = "MONTH"
    }
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

variable "enable_xray_tracing" {
  description = "Enable AWS X-Ray distributed tracing"
  type        = bool
  default     = true
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda functions in MB"
  type        = number
  default     = 256

  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "enable_api_gateway_logging" {
  description = "Enable CloudWatch logging for API Gateway"
  type        = bool
  default     = true
}

variable "api_gateway_log_level" {
  description = "API Gateway CloudWatch log level"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["INFO", "ERROR"], var.api_gateway_log_level)
    error_message = "API Gateway log level must be INFO or ERROR."
  }
}

variable "project_name" {
  description = "Project name used for resource naming and tagging (allows multiple deployments)"
  type        = string
  default     = "api-gateway-demo"
}

variable "cost_center" {
  description = "Cost center tag for resource billing"
  type        = string
  default     = "api-gateway-demo"
}

variable "owner" {
  description = "Owner tag for resource identification"
  type        = string
  default     = "demo-team"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
