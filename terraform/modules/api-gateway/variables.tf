# API Gateway Module Variables

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool for JWT authorization"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool for JWT authorization"
  type        = string
}

variable "catalog_lambda_arn" {
  description = "ARN of the Catalog Lambda function"
  type        = string
}

variable "catalog_lambda_name" {
  description = "Name of the Catalog Lambda function"
  type        = string
}

variable "order_lambda_arn" {
  description = "ARN of the Order Lambda function"
  type        = string
}

variable "order_lambda_name" {
  description = "Name of the Order Lambda function"
  type        = string
}

variable "api_name" {
  description = "Name of the API Gateway REST API"
  type        = string
  default     = "api-gateway-demo"
}

variable "api_description" {
  description = "Description of the API Gateway REST API"
  type        = string
  default     = "AWS API Gateway Demo Solution with multi-tenant support"
}

variable "stage_name" {
  description = "Name of the API Gateway deployment stage"
  type        = string
  default     = "v1"
}

variable "enable_xray_tracing" {
  description = "Enable AWS X-Ray tracing for API Gateway"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable CloudWatch logging for API Gateway"
  type        = bool
  default     = true
}

variable "log_level" {
  description = "CloudWatch log level (INFO or ERROR)"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["INFO", "ERROR"], var.log_level)
    error_message = "Log level must be INFO or ERROR."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}

variable "enable_cors" {
  description = "Enable CORS for API Gateway endpoints"
  type        = bool
  default     = true
}

variable "cors_allow_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allow_methods" {
  description = "List of allowed HTTP methods for CORS"
  type        = list(string)
  default     = ["GET", "POST", "OPTIONS"]
}

variable "cors_allow_headers" {
  description = "List of allowed headers for CORS"
  type        = list(string)
  default     = ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"]
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "authorizer_lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda authorizer function"
  type        = string
}

variable "authorizer_lambda_name" {
  description = "Name of the Lambda authorizer function (for Lambda permission)"
  type        = string
}
