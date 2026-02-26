# CloudWatch Dashboard Module Variables

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "api-gateway-demo"
}

variable "aws_region" {
  description = "AWS region for CloudWatch dashboard"
  type        = string
  default     = "us-east-1"
}

variable "api_id" {
  description = "ID of the API Gateway REST API"
  type        = string
}

variable "api_name" {
  description = "Name of the API Gateway REST API"
  type        = string
}

variable "api_stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
}

variable "catalog_lambda_name" {
  description = "Name of the Catalog Lambda function"
  type        = string
}

variable "order_lambda_name" {
  description = "Name of the Order Lambda function"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "tiers" {
  description = "Tier definitions for dashboard display"
  type = map(object({
    rate_limit   = number
    burst_limit  = number
    quota_limit  = number
    quota_period = string
  }))
  default = {}
}

variable "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  type        = string
  default     = ""
}

variable "enable_cost_widgets" {
  description = "Enable cost estimation widgets in the dashboard"
  type        = bool
  default     = true
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarm notifications (optional)"
  type        = string
  default     = ""
}
