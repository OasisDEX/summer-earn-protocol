variable "app_name" {
  description = "Name of the ECS application worker"
  type        = string
}

variable "cluster_id" {
  description = "The ID of the ECS cluster to deploy into"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnets to deploy the Fargate tasks in"
  type        = list(string)
}
