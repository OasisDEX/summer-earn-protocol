output "function_name" {
  description = "The Lambda function name"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "The Lambda function ARN"
  value       = aws_lambda_function.this.arn
}

output "role_arn" {
  description = "The Lambda execution role ARN"
  value       = aws_iam_role.this.arn
}

output "schedule_rule_name" {
  description = "The EventBridge rule that triggers the function"
  value       = aws_cloudwatch_event_rule.schedule.name
}
