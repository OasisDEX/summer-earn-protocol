variable "app_name" {
  description = "Name of the ECS application worker"
  type        = string
  nullable    = false
}

variable "cluster_id" {
  description = "The ID of the ECS cluster to deploy into"
  type        = string
  nullable    = false
}

variable "vpc_id" {
  description = "The VPC ID for the worker security group"
  type        = string
  nullable    = false
}

variable "subnet_ids" {
  description = "List of subnets to deploy the Fargate tasks in"
  type        = list(string)
}

variable "force_delete" {
  description = "Whether to force-delete the ECR repository (including all images) on destroy"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
}
