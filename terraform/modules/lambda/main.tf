# Lambda Module
# Creates Lambda functions for Catalog and Order APIs with X-Ray tracing
# Requirements: 7.1, 7.3, 9.1, 13.5

terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# Data source for Lambda execution role policy
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# IAM Role for Lambda functions
resource "aws_iam_role" "lambda_execution_role" {
  name               = "${var.environment}-${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name        = "${var.environment}-${var.project_name}-lambda-role"
    Environment = var.environment
  }
}

# CloudWatch Log Groups (defined early so IAM policies can reference them)
resource "aws_cloudwatch_log_group" "catalog_lambda" {
  name              = "/aws/lambda/${var.environment}-catalog-api"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.environment}-catalog-api-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "order_lambda" {
  name              = "/aws/lambda/${var.environment}-order-api"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.environment}-order-api-logs"
    Environment = var.environment
  }
}

# CloudWatch Logs policy for Lambda
# Hardened with specific log group ARNs for least privilege access (Requirement 13.5)
data "aws_iam_policy_document" "lambda_logging" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      aws_cloudwatch_log_group.catalog_lambda.arn,
      "${aws_cloudwatch_log_group.catalog_lambda.arn}:*",
      aws_cloudwatch_log_group.order_lambda.arn,
      "${aws_cloudwatch_log_group.order_lambda.arn}:*"
    ]
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "${var.environment}-${var.project_name}-lambda-logging"
  description = "IAM policy for Lambda logging with least privilege"
  policy      = data.aws_iam_policy_document.lambda_logging.json
}

resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

# X-Ray tracing policy for Lambda
# Note: X-Ray requires wildcard resources as traces are written to the X-Ray service
# without specific resource identifiers. This is an AWS service limitation.
data "aws_iam_policy_document" "lambda_xray" {
  statement {
    effect = "Allow"

    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords"
    ]

    # X-Ray API does not support resource-level permissions
    # See: https://docs.aws.amazon.com/xray/latest/devguide/security_iam_service-with-iam.html
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_xray" {
  name        = "${var.environment}-${var.project_name}-lambda-xray"
  description = "IAM policy for Lambda X-Ray tracing"
  policy      = data.aws_iam_policy_document.lambda_xray.json
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_xray.arn
}

# DynamoDB access policy for Lambda
# Scoped to specific table ARN for least privilege (Requirement 13.5)
data "aws_iam_policy_document" "lambda_dynamodb" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem"
    ]

    resources = [
      var.dynamodb_table_arn,
      "${var.dynamodb_table_arn}/*"
    ]
  }
}

resource "aws_iam_policy" "lambda_dynamodb" {
  name        = "${var.environment}-${var.project_name}-lambda-dynamodb"
  description = "IAM policy for Lambda DynamoDB access with least privilege"
  policy      = data.aws_iam_policy_document.lambda_dynamodb.json
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb.arn
}

# Lambda Layer for shared dependencies
resource "aws_lambda_layer_version" "shared_layer" {
  filename            = "${path.module}/../../../lambda/shared/lambda-layer.zip"
  layer_name          = "${var.environment}-${var.project_name}-shared-layer"
  compatible_runtimes = ["python3.11", "python3.12"]
  description         = "Shared dependencies for API Gateway demo Lambda functions"

  source_code_hash = fileexists("${path.module}/../../../lambda/shared/lambda-layer.zip") ? filebase64sha256("${path.module}/../../../lambda/shared/lambda-layer.zip") : null
}

# Archive file for Catalog Lambda
data "archive_file" "catalog_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/catalog"
  output_path = "${path.module}/catalog-lambda.zip"
  excludes    = ["README.md", "requirements.txt", "__pycache__", "*.pyc"]
}

# Catalog Lambda Function
resource "aws_lambda_function" "catalog" {
  filename         = data.archive_file.catalog_lambda.output_path
  function_name    = "${var.environment}-catalog-api"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.catalog_lambda.output_base64sha256
  runtime          = var.lambda_runtime
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout

  layers = [aws_lambda_layer_version.shared_layer.arn]

  environment {
    variables = {
      TABLE_NAME = var.dynamodb_table_name
      LOG_LEVEL  = var.log_level
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.catalog_lambda,
    aws_iam_role_policy_attachment.lambda_logging,
    aws_iam_role_policy_attachment.lambda_xray,
    aws_iam_role_policy_attachment.lambda_dynamodb
  ]

  tags = {
    Name        = "${var.environment}-catalog-api"
    Environment = var.environment
    API         = "Catalog"
    Application = "catalog-api"
  }
}

# Archive file for Order Lambda
data "archive_file" "order_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/order"
  output_path = "${path.module}/order-lambda.zip"
  excludes    = ["README.md", "requirements.txt", "__pycache__", "*.pyc"]
}

# Order Lambda Function
resource "aws_lambda_function" "order" {
  filename         = data.archive_file.order_lambda.output_path
  function_name    = "${var.environment}-order-api"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.order_lambda.output_base64sha256
  runtime          = var.lambda_runtime
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout

  layers = [aws_lambda_layer_version.shared_layer.arn]

  environment {
    variables = {
      TABLE_NAME = var.dynamodb_table_name
      LOG_LEVEL  = var.log_level
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.order_lambda,
    aws_iam_role_policy_attachment.lambda_logging,
    aws_iam_role_policy_attachment.lambda_xray,
    aws_iam_role_policy_attachment.lambda_dynamodb
  ]

  tags = {
    Name        = "${var.environment}-order-api"
    Environment = var.environment
    API         = "Order"
    Application = "order-api"
  }
}

# ============================================================================
# Lambda Authorizer Function
# Validates Cognito JWTs and returns usageIdentifierKey for rate limiting
# ============================================================================

resource "aws_cloudwatch_log_group" "authorizer_lambda" {
  name              = "/aws/lambda/${var.environment}-api-authorizer"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.environment}-api-authorizer-logs"
    Environment = var.environment
  }
}

# Build step: install authorizer dependencies into a build directory
resource "null_resource" "authorizer_build" {
  triggers = {
    requirements = filemd5("${path.module}/../../../lambda/authorizer/requirements.txt")
    source       = filemd5("${path.module}/../../../lambda/authorizer/index.py")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      BUILD_DIR="${path.module}/authorizer-build"
      rm -rf "$BUILD_DIR"
      mkdir -p "$BUILD_DIR"
      cp ${path.module}/../../../lambda/authorizer/index.py "$BUILD_DIR/"
      # Install with Linux-compatible binaries for Lambda (Amazon Linux x86_64)
      python3 -m pip install \
        -r ${path.module}/../../../lambda/authorizer/requirements.txt \
        -t "$BUILD_DIR" \
        --upgrade -q \
        --platform manylinux2014_x86_64 \
        --implementation cp \
        --only-binary=:all: \
        --python-version 3.11
      find "$BUILD_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
      find "$BUILD_DIR" -name "*.pyc" -delete 2>/dev/null || true
      find "$BUILD_DIR" -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
    EOT
  }
}

data "archive_file" "authorizer_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/authorizer-build"
  output_path = "${path.module}/authorizer-lambda.zip"
  excludes    = ["README.md", "requirements.txt", "__pycache__", "*.pyc"]

  depends_on = [null_resource.authorizer_build]
}

# IAM role for the authorizer (separate role - no DynamoDB access needed)
resource "aws_iam_role" "authorizer_execution_role" {
  name               = "${var.environment}-api-authorizer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name        = "${var.environment}-api-authorizer-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "authorizer_logging" {
  role       = aws_iam_role.authorizer_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# SSM Parameter Store read policy for the authorizer
data "aws_iam_policy_document" "authorizer_ssm" {
  statement {
    effect  = "Allow"
    actions = ["ssm:GetParameter"]
    resources = [
      var.tenant_map_ssm_parameter_arn,
      var.client_tenant_map_ssm_parameter_arn,
    ]
  }
}

resource "aws_iam_policy" "authorizer_ssm" {
  name        = "${var.environment}-api-authorizer-ssm"
  description = "Allow authorizer Lambda to read tenant map from SSM"
  policy      = data.aws_iam_policy_document.authorizer_ssm.json
}

resource "aws_iam_role_policy_attachment" "authorizer_ssm" {
  role       = aws_iam_role.authorizer_execution_role.name
  policy_arn = aws_iam_policy.authorizer_ssm.arn
}

resource "aws_lambda_function" "authorizer" {
  filename         = data.archive_file.authorizer_lambda.output_path
  function_name    = "${var.environment}-api-authorizer"
  role             = aws_iam_role.authorizer_execution_role.arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.authorizer_lambda.output_base64sha256
  runtime          = var.lambda_runtime
  memory_size      = 128
  timeout          = 10

  environment {
    variables = {
      COGNITO_USER_POOL_ID       = var.cognito_user_pool_id
      TENANT_MAP_SSM_PATH        = var.tenant_map_ssm_path
      CLIENT_TENANT_MAP_SSM_PATH = var.client_tenant_map_ssm_path
      LOG_LEVEL                  = var.log_level
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.authorizer_lambda,
    aws_iam_role_policy_attachment.authorizer_logging,
    aws_iam_role_policy_attachment.authorizer_ssm,
  ]

  tags = {
    Name        = "${var.environment}-api-authorizer"
    Environment = var.environment
    Application = "api-authorizer"
  }
}
