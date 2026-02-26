resource "aws_dynamodb_table" "main" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(
    {
      Name        = var.table_name
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Application = "data-store"
    },
    var.tags
  )
}
