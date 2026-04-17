output "ecr_repository_url" {
  description = "The URL of the ECR repository for container image pushes"
  value       = aws_ecr_repository.this.repository_url
}

output "service_name" {
  description = "The name of the ECS service"
  value       = aws_ecs_service.this.name
}

output "task_execution_role_arn" {
  description = "The ARN of the ECS task execution role"
  value       = aws_iam_role.task_execution.arn
}

output "security_group_id" {
  description = "The ID of the worker security group"
  value       = aws_security_group.this.id
}
