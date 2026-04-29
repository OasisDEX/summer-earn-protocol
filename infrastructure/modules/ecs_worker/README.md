# ECS Worker Module

This module deploys an AWS ECS service running on Fargate as a worker process (no load balancer).

## Features
- ECR Repository with Immutable tags.
- CloudWatch Log Group with 7-day retention.
- IAM Task and Execution Roles correctly configured.
- Security Group allowing all outbound traffic.
- Fargate Service with public IP enabled (for simple worker networking).

## Usage

```hcl
module "my_worker" {
  source     = "./modules/ecs_worker"
  app_name   = "my-worker"
  cluster_id = aws_ecs_cluster.this.id
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids
  tags       = local.common_tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| app_name | Name of the ECS application worker | `string` | n/a | yes |
| cluster_id | The ID of the ECS cluster | `string` | n/a | yes |
| vpc_id | The VPC ID | `string` | n/a | yes |
| subnet_ids | List of subnets for Fargate | `list(string)` | n/a | yes |
| force_delete | Force-delete ECR repository | `bool` | `false` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| service_name | The name of the ECS service |
| ecr_repository_url | The URL of the ECR repository |
