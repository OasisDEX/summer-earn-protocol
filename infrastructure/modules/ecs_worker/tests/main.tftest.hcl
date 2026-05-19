# ECS Worker Module Invariants Test Suite

variables {
  app_name   = "test-worker"
  cluster_id = "arn:aws:ecs:eu-central-1:123456789012:cluster/test-cluster"
  vpc_id     = "vpc-12345678"
  subnet_ids = ["subnet-123", "subnet-456"]
}

run "verify_networking_configuration" {
  command = plan

  assert {
    condition     = aws_ecs_service.this.network_configuration[0].assign_public_ip == false
    error_message = "ECS service should not assign a public IP address by default for private subnet workers"
  }
}

run "verify_logging_configuration" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.this.name == "/ecs/test-worker"
    error_message = "CloudWatch log group naming convention mismatch"
  }
}

run "verify_resource_isolation" {
  command = plan

  assert {
    condition     = aws_security_group.this.vpc_id == "vpc-12345678"
    error_message = "Security group must be created in the provided VPC"
  }
}
