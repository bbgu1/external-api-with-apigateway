# Cognito Module Variables

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "api-gateway-demo"
}

variable "jwt_token_expiration" {
  description = "JWT token expiration time in seconds"
  type        = number
  default     = 3600 # 1 hour
}

variable "refresh_token_expiration" {
  description = "Refresh token expiration time in days"
  type        = number
  default     = 30
}

variable "user_pool_name" {
  description = "Name of the Cognito User Pool"
  type        = string
  default     = ""
}
