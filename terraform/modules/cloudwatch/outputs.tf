# CloudWatch Dashboard Module Outputs

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_arn" {
  description = "ARN of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_arn
}

output "dashboard_url" {
  description = "URL to access the CloudWatch dashboard in AWS Console"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "log_group_name" {
  description = "Name of the CloudWatch log group for dashboard queries"
  value       = aws_cloudwatch_log_group.dashboard_queries.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group for dashboard queries"
  value       = aws_cloudwatch_log_group.dashboard_queries.arn
}

output "logs_insights_url" {
  description = "URL to CloudWatch Logs Insights for custom queries"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:logs-insights"
}

output "xray_service_map_url" {
  description = "URL to X-Ray service map"
  value       = "https://console.aws.amazon.com/xray/home?region=${var.aws_region}#/service-map"
}

output "tier_names" {
  description = "List of tier names configured in the dashboard"
  value       = keys(var.tiers)
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarm notifications"
  value       = aws_sns_topic.alarms.arn
}

output "alarm_arns" {
  description = "ARNs of all CloudWatch alarms"
  value = {
    high_5xx_error_rate     = aws_cloudwatch_metric_alarm.high_5xx_error_rate.arn
    high_latency            = aws_cloudwatch_metric_alarm.high_latency.arn
    api_throttling          = aws_cloudwatch_metric_alarm.api_throttling.arn
    catalog_lambda_errors   = aws_cloudwatch_metric_alarm.catalog_lambda_errors.arn
    order_lambda_errors     = aws_cloudwatch_metric_alarm.order_lambda_errors.arn
    dynamodb_read_throttle  = aws_cloudwatch_metric_alarm.dynamodb_read_throttle.arn
    dynamodb_write_throttle = aws_cloudwatch_metric_alarm.dynamodb_write_throttle.arn
  }
}
