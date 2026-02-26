# API Gateway Module - REST API with JWT Authorization

# REST API
resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.api_name}-${var.environment}"
  description = var.api_description

  # Use JWT authorizer as API key source for usage plans
  # This allows rate limiting based on tenant_id from JWT without requiring x-api-key header
  api_key_source = "AUTHORIZER"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(
    {
      Name        = "${var.api_name}-${var.environment}"
      Environment = var.environment
      Application = "api-gateway"
    },
    var.tags
  )
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  count             = var.enable_logging ? 1 : 0
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.main.name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    {
      Name        = "${var.api_name}-${var.environment}-logs"
      Environment = var.environment
      Application = "api-gateway"
    },
    var.tags
  )
}

# IAM Role for API Gateway CloudWatch Logging
resource "aws_iam_role" "api_gateway_cloudwatch" {
  count = var.enable_logging ? 1 : 0
  name  = "${var.api_name}-${var.environment}-api-gateway-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.api_name}-${var.environment}-api-gateway-cloudwatch"
      Environment = var.environment
      Application = "api-gateway"
    },
    var.tags
  )
}

# Attach CloudWatch Logs policy to API Gateway role
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  count      = var.enable_logging ? 1 : 0
  role       = aws_iam_role.api_gateway_cloudwatch[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# API Gateway Account settings for CloudWatch logging
resource "aws_api_gateway_account" "main" {
  count               = var.enable_logging ? 1 : 0
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch[0].arn
}

# Lambda TOKEN Authorizer
# Replaces COGNITO_USER_POOLS authorizer because only Lambda authorizers can return
# usageIdentifierKey in their response, which is required for api_key_source = "AUTHORIZER".
# The authorizer validates the Cognito JWT and maps tenant_id → API key value so that
# API Gateway can enforce the correct per-tenant usage plan.
resource "aws_api_gateway_authorizer" "lambda_authorizer" {
  name                             = "${var.api_name}-${var.environment}-lambda-authorizer"
  rest_api_id                      = aws_api_gateway_rest_api.main.id
  type                             = "TOKEN"
  identity_source                  = "method.request.header.Authorization"
  authorizer_uri                   = var.authorizer_lambda_invoke_arn
  authorizer_result_ttl_in_seconds = 300 # Cache policy for 5 min to reduce Lambda invocations
}

# Allow API Gateway to invoke the Lambda authorizer
resource "aws_lambda_permission" "authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = var.authorizer_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/authorizers/${aws_api_gateway_authorizer.lambda_authorizer.id}"
}

# ============================================================================
# /catalog Resource and Methods
# ============================================================================

# /catalog resource
resource "aws_api_gateway_resource" "catalog" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "catalog"
}

# GET /catalog method
resource "aws_api_gateway_method" "catalog_get" {
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = aws_api_gateway_resource.catalog.id
  http_method      = "GET"
  authorization    = "CUSTOM"
  authorizer_id    = aws_api_gateway_authorizer.lambda_authorizer.id
  api_key_required = true # Enable usage plan enforcement

  request_parameters = {
    "method.request.header.Authorization" = true
  }
}

# GET /catalog integration with Lambda
resource "aws_api_gateway_integration" "catalog_get" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.catalog.id
  http_method             = aws_api_gateway_method.catalog_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.catalog_lambda_arn}/invocations"
}

# Lambda permission for GET /catalog
resource "aws_lambda_permission" "catalog_get" {
  statement_id  = "AllowAPIGatewayInvoke-GET-catalog"
  action        = "lambda:InvokeFunction"
  function_name = var.catalog_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/${aws_api_gateway_method.catalog_get.http_method}${aws_api_gateway_resource.catalog.path}"
}

# OPTIONS /catalog method for CORS
resource "aws_api_gateway_method" "catalog_options" {
  count         = var.enable_cors ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.catalog.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# OPTIONS /catalog integration for CORS
resource "aws_api_gateway_integration" "catalog_options" {
  count       = var.enable_cors ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.catalog.id
  http_method = aws_api_gateway_method.catalog_options[0].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# OPTIONS /catalog method response for CORS
resource "aws_api_gateway_method_response" "catalog_options" {
  count       = var.enable_cors ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.catalog.id
  http_method = aws_api_gateway_method.catalog_options[0].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

# OPTIONS /catalog integration response for CORS
resource "aws_api_gateway_integration_response" "catalog_options" {
  count       = var.enable_cors ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.catalog.id
  http_method = aws_api_gateway_method.catalog_options[0].http_method
  status_code = aws_api_gateway_method_response.catalog_options[0].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'${join(",", var.cors_allow_headers)}'"
    "method.response.header.Access-Control-Allow-Methods" = "'${join(",", var.cors_allow_methods)}'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${join(",", var.cors_allow_origins)}'"
  }
}

# ============================================================================
# /catalog/{productId} Resource and Methods
# ============================================================================

# /catalog/{productId} resource
resource "aws_api_gateway_resource" "catalog_product" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.catalog.id
  path_part   = "{productId}"
}

# GET /catalog/{productId} method
resource "aws_api_gateway_method" "catalog_product_get" {
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = aws_api_gateway_resource.catalog_product.id
  http_method      = "GET"
  authorization    = "CUSTOM"
  authorizer_id    = aws_api_gateway_authorizer.lambda_authorizer.id
  api_key_required = true # Enable usage plan enforcement

  request_parameters = {
    "method.request.header.Authorization" = true
    "method.request.path.productId"       = true
  }
}

# GET /catalog/{productId} integration with Lambda
resource "aws_api_gateway_integration" "catalog_product_get" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.catalog_product.id
  http_method             = aws_api_gateway_method.catalog_product_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.catalog_lambda_arn}/invocations"
}

# Lambda permission for GET /catalog/{productId}
resource "aws_lambda_permission" "catalog_product_get" {
  statement_id  = "AllowAPIGatewayInvoke-GET-catalog-productId"
  action        = "lambda:InvokeFunction"
  function_name = var.catalog_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/${aws_api_gateway_method.catalog_product_get.http_method}/catalog/*"
}

# OPTIONS /catalog/{productId} method for CORS
resource "aws_api_gateway_method" "catalog_product_options" {
  count         = var.enable_cors ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.catalog_product.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# OPTIONS /catalog/{productId} integration for CORS
resource "aws_api_gateway_integration" "catalog_product_options" {
  count       = var.enable_cors ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.catalog_product.id
  http_method = aws_api_gateway_method.catalog_product_options[0].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# OPTIONS /catalog/{productId} method response for CORS
resource "aws_api_gateway_method_response" "catalog_product_options" {
  count       = var.enable_cors ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.catalog_product.id
  http_method = aws_api_gateway_method.catalog_product_options[0].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

# OPTIONS /catalog/{productId} integration response for CORS
resource "aws_api_gateway_integration_response" "catalog_product_options" {
  count       = var.enable_cors ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.catalog_product.id
  http_method = aws_api_gateway_method.catalog_product_options[0].http_method
  status_code = aws_api_gateway_method_response.catalog_product_options[0].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'${join(",", var.cors_allow_headers)}'"
    "method.response.header.Access-Control-Allow-Methods" = "'${join(",", var.cors_allow_methods)}'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${join(",", var.cors_allow_origins)}'"
  }
}

# ============================================================================
# /orders Resource and Methods
# ============================================================================

# /orders resource
resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "orders"
}

# GET /orders method
resource "aws_api_gateway_method" "orders_get" {
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = aws_api_gateway_resource.orders.id
  http_method      = "GET"
  authorization    = "CUSTOM"
  authorizer_id    = aws_api_gateway_authorizer.lambda_authorizer.id
  api_key_required = true # Enable usage plan enforcement

  request_parameters = {
    "method.request.header.Authorization" = true
  }
}

# GET /orders integration with Lambda
resource "aws_api_gateway_integration" "orders_get" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.orders.id
  http_method             = aws_api_gateway_method.orders_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.order_lambda_arn}/invocations"
}

# Lambda permission for GET /orders
resource "aws_lambda_permission" "orders_get" {
  statement_id  = "AllowAPIGatewayInvoke-GET-orders"
  action        = "lambda:InvokeFunction"
  function_name = var.order_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/${aws_api_gateway_method.orders_get.http_method}${aws_api_gateway_resource.orders.path}"
}

# POST /orders method
resource "aws_api_gateway_method" "orders_post" {
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = aws_api_gateway_resource.orders.id
  http_method      = "POST"
  authorization    = "CUSTOM"
  authorizer_id    = aws_api_gateway_authorizer.lambda_authorizer.id
  api_key_required = true # Enable usage plan enforcement

  request_parameters = {
    "method.request.header.Authorization" = true
  }
}

# POST /orders integration with Lambda
resource "aws_api_gateway_integration" "orders_post" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.orders.id
  http_method             = aws_api_gateway_method.orders_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.order_lambda_arn}/invocations"
}

# Lambda permission for POST /orders
resource "aws_lambda_permission" "orders_post" {
  statement_id  = "AllowAPIGatewayInvoke-POST-orders"
  action        = "lambda:InvokeFunction"
  function_name = var.order_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/${aws_api_gateway_method.orders_post.http_method}${aws_api_gateway_resource.orders.path}"
}

# OPTIONS /orders method for CORS
resource "aws_api_gateway_method" "orders_options" {
  count         = var.enable_cors ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# OPTIONS /orders integration for CORS
resource "aws_api_gateway_integration" "orders_options" {
  count       = var.enable_cors ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.orders_options[0].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# OPTIONS /orders method response for CORS
resource "aws_api_gateway_method_response" "orders_options" {
  count       = var.enable_cors ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.orders_options[0].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

# OPTIONS /orders integration response for CORS
resource "aws_api_gateway_integration_response" "orders_options" {
  count       = var.enable_cors ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.orders_options[0].http_method
  status_code = aws_api_gateway_method_response.orders_options[0].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'${join(",", var.cors_allow_headers)}'"
    "method.response.header.Access-Control-Allow-Methods" = "'${join(",", var.cors_allow_methods)}'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${join(",", var.cors_allow_origins)}'"
  }
}

# ============================================================================
# /orders/{orderId} Resource and Methods
# ============================================================================

# /orders/{orderId} resource
resource "aws_api_gateway_resource" "orders_order" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.orders.id
  path_part   = "{orderId}"
}

# GET /orders/{orderId} method
resource "aws_api_gateway_method" "orders_order_get" {
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = aws_api_gateway_resource.orders_order.id
  http_method      = "GET"
  authorization    = "CUSTOM"
  authorizer_id    = aws_api_gateway_authorizer.lambda_authorizer.id
  api_key_required = true # Enable usage plan enforcement

  request_parameters = {
    "method.request.header.Authorization" = true
    "method.request.path.orderId"         = true
  }
}

# GET /orders/{orderId} integration with Lambda
resource "aws_api_gateway_integration" "orders_order_get" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.orders_order.id
  http_method             = aws_api_gateway_method.orders_order_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.order_lambda_arn}/invocations"
}

# Lambda permission for GET /orders/{orderId}
resource "aws_lambda_permission" "orders_order_get" {
  statement_id  = "AllowAPIGatewayInvoke-GET-orders-orderId"
  action        = "lambda:InvokeFunction"
  function_name = var.order_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/${aws_api_gateway_method.orders_order_get.http_method}/orders/*"
}

# OPTIONS /orders/{orderId} method for CORS
resource "aws_api_gateway_method" "orders_order_options" {
  count         = var.enable_cors ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.orders_order.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# OPTIONS /orders/{orderId} integration for CORS
resource "aws_api_gateway_integration" "orders_order_options" {
  count       = var.enable_cors ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.orders_order.id
  http_method = aws_api_gateway_method.orders_order_options[0].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# OPTIONS /orders/{orderId} method response for CORS
resource "aws_api_gateway_method_response" "orders_order_options" {
  count       = var.enable_cors ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.orders_order.id
  http_method = aws_api_gateway_method.orders_order_options[0].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

# OPTIONS /orders/{orderId} integration response for CORS
resource "aws_api_gateway_integration_response" "orders_order_options" {
  count       = var.enable_cors ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.orders_order.id
  http_method = aws_api_gateway_method.orders_order_options[0].http_method
  status_code = aws_api_gateway_method_response.orders_order_options[0].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'${join(",", var.cors_allow_headers)}'"
    "method.response.header.Access-Control-Allow-Methods" = "'${join(",", var.cors_allow_methods)}'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${join(",", var.cors_allow_origins)}'"
  }
}

# ============================================================================
# API Gateway Deployment and Stage
# ============================================================================

# API Gateway Deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  # Force new deployment on any change
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.main.api_key_source,
      aws_api_gateway_authorizer.lambda_authorizer.id,
      aws_api_gateway_resource.catalog.id,
      aws_api_gateway_resource.catalog_product.id,
      aws_api_gateway_resource.orders.id,
      aws_api_gateway_resource.orders_order.id,
      aws_api_gateway_method.catalog_get.id,
      aws_api_gateway_method.catalog_get.authorization_scopes,
      aws_api_gateway_method.catalog_get.api_key_required,
      aws_api_gateway_method.catalog_product_get.id,
      aws_api_gateway_method.catalog_product_get.authorization_scopes,
      aws_api_gateway_method.catalog_product_get.api_key_required,
      aws_api_gateway_method.orders_get.id,
      aws_api_gateway_method.orders_get.authorization_scopes,
      aws_api_gateway_method.orders_get.api_key_required,
      aws_api_gateway_method.orders_post.id,
      aws_api_gateway_method.orders_post.authorization_scopes,
      aws_api_gateway_method.orders_post.api_key_required,
      aws_api_gateway_method.orders_order_get.id,
      aws_api_gateway_method.orders_order_get.authorization_scopes,
      aws_api_gateway_method.orders_order_get.api_key_required,
      aws_api_gateway_integration.catalog_get.id,
      aws_api_gateway_integration.catalog_product_get.id,
      aws_api_gateway_integration.orders_get.id,
      aws_api_gateway_integration.orders_post.id,
      aws_api_gateway_integration.orders_order_get.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.stage_name

  # X-Ray tracing configuration
  xray_tracing_enabled = var.enable_xray_tracing

  # CloudWatch logging configuration
  access_log_settings {
    destination_arn = var.enable_logging ? aws_cloudwatch_log_group.api_gateway[0].arn : null
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
      errorType      = "$context.error.messageString"
    })
  }

  tags = merge(
    {
      Name        = "${var.api_name}-${var.environment}-${var.stage_name}"
      Environment = var.environment
      Application = "api-gateway"
    },
    var.tags
  )

  depends_on = [
    aws_api_gateway_account.main
  ]
}

# API Gateway Method Settings for detailed CloudWatch logging
resource "aws_api_gateway_method_settings" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    # CloudWatch metrics
    metrics_enabled = true

    # CloudWatch logging
    logging_level = var.enable_logging ? var.log_level : "OFF"

    # Log full request and response data
    data_trace_enabled = var.enable_logging

    # Throttling settings (can be overridden by usage plans)
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
  }
}

# Data source for current AWS region
data "aws_region" "current" {}
