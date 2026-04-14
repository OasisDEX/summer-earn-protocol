variable "aws_region" {
  description = "AWS Region to deploy to"
  type        = string
  default     = "eu-central-1" # Defaulted, can be overridden via TF_VAR_aws_region
}

variable "github_repository" {
  description = "The URL to the GitHub repository"
  type        = string
  default     = "https://github.com/OasisDEX/summer-earn-protocol"
}

variable "github_token" {
  description = "Personal Access Token for AWS Amplify to read the repo"
  type        = string
  sensitive   = true
}
