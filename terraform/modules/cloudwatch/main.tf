# CloudWatch Dashboard Module
# Creates comprehensive monitoring dashboard for API Gateway demo solution

locals {
  dashboard_name = var.dashboard_name != "" ? var.dashboard_name : "${var.project_name}-${var.environment}"

  # Cost widgets - always defined, conditionally included in dashboard
  cost_widgets = [
    {
      type = "text"
      properties = {
        markdown = "# Cost Metrics\n\nEstimated costs based on resource usage. Actual costs may vary."
      }
      width  = 24
      height = 2
      x      = 0
      y      = 50
    },
    {
      type = "metric"
      properties = {
        metrics = [
          ["AWS/ApiGateway", "Count", { stat = "Sum", label = "Total Requests" }]
        ]
        view    = "timeSeries"
        stacked = false
        region  = var.aws_region
        title   = "API Gateway - Request Volume"
        period  = 3600
        yAxis = {
          left = {
            label = "Count"
            min   = 0
          }
        }
      }
      width  = 12
      height = 6
      x      = 0
      y      = 52
    },
    {
      type = "metric"
      properties = {
        metrics = [
          ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Total Invocations" }]
        ]
        view    = "timeSeries"
        stacked = false
        region  = var.aws_region
        title   = "Lambda - Invocation Volume"
        period  = 3600
        yAxis = {
          left = {
            label = "Count"
            min   = 0
          }
        }
      }
      width  = 12
      height = 6
      x      = 12
      y      = 52
    },
    {
      type = "metric"
      properties = {
        metrics = [
          ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", var.dynamodb_table_name, { stat = "Sum", label = "Read Units" }],
          [".", "ConsumedWriteCapacityUnits", ".", ".", { stat = "Sum", label = "Write Units" }]
        ]
        view    = "timeSeries"
        stacked = false
        region  = var.aws_region
        title   = "DynamoDB - Capacity Usage"
        period  = 3600
        yAxis = {
          left = {
            label = "Units"
            min   = 0
          }
        }
      }
      width  = 12
      height = 6
      x      = 0
      y      = 58
    },
    {
      type = "text"
      properties = {
        markdown = <<-EOT
          ## Cost Breakdown by Tier
          
          ${join("\n", [for tier, config in var.tiers : "**${upper(tier)} Tier**: ${config.rate_limit} req/s, burst ${config.burst_limit}, quota ${config.quota_limit}/${config.quota_period}"])}
          
          ### Pricing Notes:
          - **API Gateway**: $3.50 per million requests
          - **Lambda**: $0.20 per million requests + $0.00001667 per GB-second
          - **DynamoDB**: $0.25 per million read requests, $1.25 per million write requests (on-demand)
          - **X-Ray**: $5.00 per million traces recorded, $0.50 per million traces retrieved
          - **CloudWatch**: $0.30 per GB ingested, $0.03 per GB archived
          
          Use AWS Cost Explorer with resource tags for accurate per-tenant cost allocation.
        EOT
      }
      width  = 12
      height = 6
      x      = 12
      y      = 58
    }
  ]
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    widgets = concat(
      # API Gateway Metrics Section
      [
        {
          type = "metric"
          properties = {
            metrics = [
              ["AWS/ApiGateway", "Count", { stat = "Sum", label = "Total Requests" }],
              [".", "4XXError", { stat = "Sum", label = "4xx Errors" }],
              [".", "5XXError", { stat = "Sum", label = "5xx Errors" }]
            ]
            view    = "timeSeries"
            stacked = false
            region  = var.aws_region
            title   = "API Gateway - Request Count and Errors"
            period  = 300
            yAxis = {
              left = {
                label = "Count"
              }
            }
            annotations = {
              horizontal = [
                {
                  label = "High Error Threshold"
                  value = 100
                  fill  = "above"
                  color = "#d62728"
                }
              ]
            }
          }
          width  = 12
          height = 6
          x      = 0
          y      = 0
        },
        {
          type = "metric"
          properties = {
            metrics = [
              ["AWS/ApiGateway", "Latency", { stat = "Average", label = "Average Latency" }],
              ["...", { stat = "p90", label = "p90" }],
              ["...", { stat = "p99", label = "p99" }]
            ]
            view    = "timeSeries"
            stacked = false
            region  = var.aws_region
            title   = "API Gateway - Latency (ms)"
            period  = 300
            yAxis = {
              left = {
                label = "Milliseconds"
                min   = 0
              }
            }
            annotations = {
              horizontal = [
                {
                  label = "SLA Threshold (3s)"
                  value = 3000
                  fill  = "above"
                  color = "#ff7f0e"
                }
              ]
            }
          }
          width  = 12
          height = 6
          x      = 12
          y      = 0
        },
        {
          type = "metric"
          properties = {
            metrics = [
              [
                {
                  expression = "m2/m1*100"
                  label      = "4xx Error Rate (%)"
                  id         = "e1"
                }
              ],
              [
                {
                  expression = "m3/m1*100"
                  label      = "5xx Error Rate (%)"
                  id         = "e2"
                }
              ],
              ["AWS/ApiGateway", "Count", { id = "m1", visible = false }],
              [".", "4XXError", { id = "m2", visible = false }],
              [".", "5XXError", { id = "m3", visible = false }]
            ]
            view    = "timeSeries"
            stacked = false
            region  = var.aws_region
            title   = "API Gateway - Error Rate (%)"
            period  = 300
            yAxis = {
              left = {
                label = "Percentage"
                min   = 0
                max   = 100
              }
            }
            annotations = {
              horizontal = [
                {
                  label = "Critical Threshold (5%)"
                  value = 5
                  fill  = "above"
                  color = "#d62728"
                }
              ]
            }
          }
          width  = 12
          height = 6
          x      = 0
          y      = 6
        },
        {
          type = "metric"
          properties = {
            metrics = [
              ["AWS/ApiGateway", "CacheHitCount", { stat = "Sum", label = "Cache Hits" }],
              [".", "CacheMissCount", { stat = "Sum", label = "Cache Misses" }]
            ]
            view    = "timeSeries"
            stacked = true
            region  = var.aws_region
            title   = "API Gateway - Cache Performance"
            period  = 300
            yAxis = {
              left = {
                label = "Count"
              }
            }
          }
          width  = 12
          height = 6
          x      = 12
          y      = 6
        }
      ],

      # Lambda Metrics Section
      [
        {
          type = "metric"
          properties = {
            metrics = [
              ["AWS/Lambda", "Invocations", "FunctionName", var.catalog_lambda_name, { stat = "Sum", label = "Catalog Lambda" }],
              ["...", ".", var.order_lambda_name, { stat = "Sum", label = "Order Lambda" }]
            ]
            view    = "timeSeries"
            stacked = false
            region  = var.aws_region
            title   = "Lambda - Invocations"
            period  = 300
            yAxis = {
              left = {
                label = "Count"
              }
            }
          }
          width  = 12
          height = 6
          x      = 0
          y      = 12
        },
        {
          type = "metric"
          properties = {
            metrics = [
              ["AWS/Lambda", "Duration", "FunctionName", var.catalog_lambda_name, { stat = "Average", label = "Catalog Avg" }],
              ["...", ".", var.order_lambda_name, { stat = "Average", label = "Order Avg" }]
            ]
            view    = "timeSeries"
            stacked = false
            region  = var.aws_region
            title   = "Lambda - Duration (ms)"
            period  = 300
            yAxis = {
              left = {
                label = "Milliseconds"
                min   = 0
              }
            }
            annotations = {
              horizontal = [
                {
                  label = "Timeout Warning (2s)"
                  value = 2000
                  fill  = "above"
                  color = "#ff7f0e"
                }
              ]
            }
          }
          width  = 12
          height = 6
          x      = 12
          y      = 12
        },
        {
          type = "metric"
          properties = {
            metrics = [
              ["AWS/Lambda", "Errors", "FunctionName", var.catalog_lambda_name, { stat = "Sum", label = "Catalog Errors" }],
              ["...", ".", var.order_lambda_name, { stat = "Sum", label = "Order Errors" }]
            ]
            view    = "timeSeries"
            stacked = false
            region  = var.aws_region
            title   = "Lambda - Errors and Throttles"
            period  = 300
            yAxis = {
              left = {
                label = "Count"
              }
            }
          }
          width  = 12
          height = 6
          x      = 0
          y      = 18
        },
        {
          type = "metric"
          properties = {
            metrics = [
              ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", var.catalog_lambda_name, { stat = "Maximum", label = "Catalog Concurrent" }],
              ["...", ".", var.order_lambda_name, { stat = "Maximum", label = "Order Concurrent" }]
            ]
            view    = "timeSeries"
            stacked = false
            region  = var.aws_region
            title   = "Lambda - Concurrent Executions"
            period  = 300
            yAxis = {
              left = {
                label = "Count"
                min   = 0
              }
            }
          }
          width  = 12
          height = 6
          x      = 12
          y      = 18
        }
      ],

      # DynamoDB Metrics Section
      [
        {
          type = "metric"
          properties = {
            metrics = [
              ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", var.dynamodb_table_name, { stat = "Sum", label = "Read Capacity" }],
              [".", "ConsumedWriteCapacityUnits", ".", ".", { stat = "Sum", label = "Write Capacity" }]
            ]
            view    = "timeSeries"
            stacked = false
            region  = var.aws_region
            title   = "DynamoDB - Consumed Capacity Units"
            period  = 300
            yAxis = {
              left = {
                label = "Units"
              }
            }
          }
          width  = 12
          height = 6
          x      = 0
          y      = 24
        },
        {
          type = "metric"
          properties = {
            metrics = [
              ["AWS/DynamoDB", "UserErrors", "TableName", var.dynamodb_table_name, { stat = "Sum", label = "User Errors" }],
              [".", "SystemErrors", ".", ".", { stat = "Sum", label = "System Errors" }]
            ]
            view    = "timeSeries"
            stacked = false
            region  = var.aws_region
            title   = "DynamoDB - Errors and Throttling"
            period  = 300
            yAxis = {
              left = {
                label = "Count"
              }
            }
          }
          width  = 12
          height = 6
          x      = 12
          y      = 24
        },
        {
          type = "metric"
          properties = {
            metrics = [
              ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", var.dynamodb_table_name, "Operation", "GetItem", { stat = "Average", label = "GetItem Avg" }],
              ["...", ".", ".", ".", "Query", { stat = "Average", label = "Query Avg" }]
            ]
            view    = "timeSeries"
            stacked = false
            region  = var.aws_region
            title   = "DynamoDB - Operation Latency (ms)"
            period  = 300
            yAxis = {
              left = {
                label = "Milliseconds"
                min   = 0
              }
            }
            annotations = {
              horizontal = [
                {
                  label = "Target Latency (100ms)"
                  value = 100
                  fill  = "above"
                  color = "#ff7f0e"
                }
              ]
            }
          }
          width  = 12
          height = 6
          x      = 0
          y      = 30
        },
        {
          type = "metric"
          properties = {
            metrics = [
              ["AWS/DynamoDB", "AccountMaxTableLevelReads", "TableName", var.dynamodb_table_name, { stat = "Maximum", label = "Max Read Capacity" }],
              [".", "AccountMaxTableLevelWrites", ".", ".", { stat = "Maximum", label = "Max Write Capacity" }]
            ]
            view    = "timeSeries"
            stacked = false
            region  = var.aws_region
            title   = "DynamoDB - Account Limits"
            period  = 300
            yAxis = {
              left = {
                label = "Units"
              }
            }
          }
          width  = 12
          height = 6
          x      = 12
          y      = 30
        }
      ],

      # Tenant-Specific Metrics Section
      [
        {
          type = "text"
          properties = {
            markdown = "# Tenant-Specific Metrics\n\nMonitor API usage and performance per tenant tier. Use CloudWatch Logs Insights to filter by specific tenant_id."
          }
          width  = 24
          height = 2
          x      = 0
          y      = 36
        },
        {
          type = "log"
          properties = {
            query   = <<-EOQ
              SOURCE `/aws/lambda/${var.catalog_lambda_name}`
              SOURCE `/aws/lambda/${var.order_lambda_name}`
              | fields @timestamp, tenantId, @message
              | filter ispresent(tenantId)
              | stats count() as RequestCount by tenantId
              | sort RequestCount desc
            EOQ
            region  = var.aws_region
            title   = "Requests by Tenant (Last Hour)"
            stacked = false
          }
          width  = 12
          height = 6
          x      = 0
          y      = 38
        },
        {
          type = "log"
          properties = {
            query   = <<-EOQ
              SOURCE `/aws/lambda/${var.catalog_lambda_name}`
              SOURCE `/aws/lambda/${var.order_lambda_name}`
              | fields @timestamp, tenantId, level, @message
              | filter level = "ERROR" and ispresent(tenantId)
              | stats count() as ErrorCount by tenantId
              | sort ErrorCount desc
            EOQ
            region  = var.aws_region
            title   = "Errors by Tenant (Last Hour)"
            stacked = false
          }
          width  = 12
          height = 6
          x      = 12
          y      = 38
        },
        {
          type = "log"
          properties = {
            query   = <<-EOQ
              SOURCE `/aws/lambda/${var.catalog_lambda_name}`
              SOURCE `/aws/lambda/${var.order_lambda_name}`
              | fields @timestamp, tenantId, duration
              | filter ispresent(tenantId) and ispresent(duration)
              | stats avg(duration) as AvgDuration, max(duration) as MaxDuration by tenantId
              | sort AvgDuration desc
            EOQ
            region  = var.aws_region
            title   = "Average Latency by Tenant (Last Hour)"
            stacked = false
          }
          width  = 12
          height = 6
          x      = 0
          y      = 44
        },
        {
          type = "log"
          properties = {
            query   = <<-EOQ
              SOURCE `/aws/lambda/${var.catalog_lambda_name}`
              SOURCE `/aws/lambda/${var.order_lambda_name}`
              | fields @timestamp, tenantId, endpoint
              | filter ispresent(tenantId) and ispresent(endpoint)
              | stats count() as RequestCount by tenantId, endpoint
              | sort RequestCount desc
              | limit 20
            EOQ
            region  = var.aws_region
            title   = "Top Endpoints by Tenant (Last Hour)"
            stacked = false
          }
          width  = 12
          height = 6
          x      = 12
          y      = 44
        }
      ],

      # Cost Metrics Section
      local.cost_widgets,

      # System Health Summary
      [
        {
          type = "text"
          properties = {
            markdown = <<-EOT
              # System Health Summary
              
              ## Tier Configuration
              ${join("\n", [for tier, config in var.tiers : "- **${tier}**: ${config.rate_limit} req/s, burst ${config.burst_limit}, quota ${config.quota_limit}/${config.quota_period}"])}
              
              ## Quick Links
              - [X-Ray Service Map](https://console.aws.amazon.com/xray/home?region=${var.aws_region}#/service-map)
              - [API Gateway Console](https://console.aws.amazon.com/apigateway/home?region=${var.aws_region}#/apis/${var.api_id})
              - [Lambda Functions](https://console.aws.amazon.com/lambda/home?region=${var.aws_region})
              - [DynamoDB Table](https://console.aws.amazon.com/dynamodbv2/home?region=${var.aws_region}#table?name=${var.dynamodb_table_name})
              - [CloudWatch Logs Insights](https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:logs-insights)
            EOT
          }
          width  = 24
          height = 8
          x      = 0
          y      = 64
        }
      ]
    )
  })
}

# CloudWatch Log Group for dashboard queries (if not exists)
resource "aws_cloudwatch_log_group" "dashboard_queries" {
  name              = "/aws/cloudwatch/dashboard/${local.dashboard_name}"
  retention_in_days = 7

  tags = {
    Name        = "${local.dashboard_name}-queries"
    Environment = var.environment
    Application = "monitoring"
  }
}

# SNS Topic for Alarm Notifications
resource "aws_sns_topic" "alarms" {
  name = "${local.dashboard_name}-alarms"

  tags = {
    Name        = "${local.dashboard_name}-alarms"
    Environment = var.environment
    Application = "monitoring"
  }
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# CloudWatch Alarm: High 5xx Error Rate (> 5%)
resource "aws_cloudwatch_metric_alarm" "high_5xx_error_rate" {
  alarm_name          = "${local.dashboard_name}-high-5xx-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 5
  alarm_description   = "Alert when 5xx error rate exceeds 5% for 10 minutes"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "m2/m1*100"
    label       = "5xx Error Rate (%)"
    return_data = true
  }

  metric_query {
    id = "m1"
    metric {
      metric_name = "Count"
      namespace   = "AWS/ApiGateway"
      period      = 300
      stat        = "Sum"
      dimensions = {
        ApiId = var.api_id
      }
    }
  }

  metric_query {
    id = "m2"
    metric {
      metric_name = "5XXError"
      namespace   = "AWS/ApiGateway"
      period      = 300
      stat        = "Sum"
      dimensions = {
        ApiId = var.api_id
      }
    }
  }

  tags = {
    Name        = "${local.dashboard_name}-high-5xx-error-rate"
    Environment = var.environment
    Application = "monitoring"
  }
}

# CloudWatch Alarm: High Latency (p99 > 3s)
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "${local.dashboard_name}-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = 300
  extended_statistic  = "p99"
  threshold           = 3000
  alarm_description   = "Alert when p99 latency exceeds 3 seconds for 10 minutes"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = var.api_id
  }

  tags = {
    Name        = "${local.dashboard_name}-high-latency"
    Environment = var.environment
    Application = "monitoring"
  }
}

# CloudWatch Alarm: API Gateway Throttling
resource "aws_cloudwatch_metric_alarm" "api_throttling" {
  alarm_name          = "${local.dashboard_name}-api-throttling"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Count"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when API Gateway throttles more than 10 requests in 1 minute"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = var.api_id
  }

  tags = {
    Name        = "${local.dashboard_name}-api-throttling"
    Environment = var.environment
    Application = "monitoring"
  }
}

# CloudWatch Alarm: Catalog Lambda Errors
resource "aws_cloudwatch_metric_alarm" "catalog_lambda_errors" {
  alarm_name          = "${local.dashboard_name}-catalog-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when Catalog Lambda has more than 5 errors in 5 minutes"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.catalog_lambda_name
  }

  tags = {
    Name        = "${local.dashboard_name}-catalog-lambda-errors"
    Environment = var.environment
    Application = "monitoring"
  }
}

# CloudWatch Alarm: Order Lambda Errors
resource "aws_cloudwatch_metric_alarm" "order_lambda_errors" {
  alarm_name          = "${local.dashboard_name}-order-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when Order Lambda has more than 5 errors in 5 minutes"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.order_lambda_name
  }

  tags = {
    Name        = "${local.dashboard_name}-order-lambda-errors"
    Environment = var.environment
    Application = "monitoring"
  }
}

# CloudWatch Alarm: DynamoDB Read Throttling
resource "aws_cloudwatch_metric_alarm" "dynamodb_read_throttle" {
  alarm_name          = "${local.dashboard_name}-dynamodb-read-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ReadThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when DynamoDB read throttling exceeds 10 events in 1 minute"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = var.dynamodb_table_name
  }

  tags = {
    Name        = "${local.dashboard_name}-dynamodb-read-throttle"
    Environment = var.environment
    Application = "monitoring"
  }
}

# CloudWatch Alarm: DynamoDB Write Throttling
resource "aws_cloudwatch_metric_alarm" "dynamodb_write_throttle" {
  alarm_name          = "${local.dashboard_name}-dynamodb-write-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "WriteThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when DynamoDB write throttling exceeds 10 events in 1 minute"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = var.dynamodb_table_name
  }

  tags = {
    Name        = "${local.dashboard_name}-dynamodb-write-throttle"
    Environment = var.environment
    Application = "monitoring"
  }
}
