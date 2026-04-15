variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "eu-central-1"
  nullable    = false

  validation {
    condition     = can(regex("^(us|eu|ap|sa|ca|me|af)-(north|south|east|west|central|northeast|southeast)-[0-9]+$", var.aws_region))
    error_message = "Must be a valid AWS region identifier (e.g., eu-central-1)."
  }
}

variable "github_repository" {
  description = "The URL to the GitHub repository for Amplify apps"
  type        = string
  default     = "https://github.com/OasisDEX/summer-earn-protocol"
  nullable    = false
}

variable "github_token" {
  description = "Personal Access Token for AWS Amplify to read the repo"
  type        = string
  sensitive   = true
}
