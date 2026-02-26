variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "api-gateway-demo"
}

variable "tags" {
  description = "Additional tags to apply to the table"
  type        = map(string)
  default     = {}
}
