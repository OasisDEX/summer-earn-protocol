output "app_id" {
  description = "The unique ID of the Amplify app"
  value       = aws_amplify_app.this.id
}

output "arn" {
  description = "The ARN of the Amplify app"
  value       = aws_amplify_app.this.arn
}

output "default_domain" {
  description = "The default domain for the Amplify app"
  value       = aws_amplify_app.this.default_domain
}
