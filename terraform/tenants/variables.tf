# Variables for Tenant Lifecycle Management

variable "aws_region" {
  description = "AWS region matching the core infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (must match core infrastructure)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name (must match core infrastructure)"
  type        = string
  default     = "api-gateway-demo"
}

variable "tenants" {
  description = "Map of tenant IDs to their configuration"
  type = map(object({
    tier = string
  }))

  validation {
    condition     = alltrue([for t in values(var.tenants) : contains(["basic", "standard", "premium"], t.tier)])
    error_message = "Each tenant tier must be one of: basic, standard, premium."
  }
}

# Core infrastructure references
variable "cognito_resource_server_identifier" {
  description = "Cognito resource server identifier (e.g. 'api')"
  type        = string
  default     = "api"
}

variable "stage_name" {
  description = "API Gateway stage name (must match core infrastructure)"
  type        = string
  default     = "v1"
}

variable "tiers" {
  description = "Rate limiting configuration per tier"
  type = map(object({
    rate_limit   = number
    burst_limit  = number
    quota_limit  = number
    quota_period = string
  }))
}
