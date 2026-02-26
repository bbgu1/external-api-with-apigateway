# Lambda Module Variables

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "api-gateway-demo"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  type        = string
}

variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "python3.11"
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda functions in MB"
  type        = number
  default     = 256
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions in seconds"
  type        = number
  default     = 30
}

variable "log_level" {
  description = "Log level for Lambda functions (INFO, DEBUG, ERROR)"
  type        = string
  default     = "INFO"
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}

variable "enable_xray_tracing" {
  description = "Enable AWS X-Ray tracing for Lambda functions"
  type        = bool
  default     = true
}

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID for the Lambda authorizer to validate JWTs"
  type        = string
  default     = ""
}

variable "tenant_map_ssm_parameter_arn" {
  description = "ARN of the SSM parameter storing the tenant-to-API-key-value map"
  type        = string
}

variable "tenant_map_ssm_path" {
  description = "SSM parameter name for the tenant-to-API-key-value map"
  type        = string
}

variable "client_tenant_map_ssm_parameter_arn" {
  description = "ARN of the SSM parameter storing the client-id-to-tenant-id map"
  type        = string
}

variable "client_tenant_map_ssm_path" {
  description = "SSM parameter name for the client-id-to-tenant-id map"
  type        = string
}
