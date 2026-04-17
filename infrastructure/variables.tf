variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "eu-central-1"

  validation {
    condition     = can(regex("^(us|eu|ap|sa|ca|me|af)-(north|south|east|west|central|northeast|southeast)-[0-9]+$", var.aws_region))
    error_message = "Must be a valid AWS region identifier (e.g., eu-central-1)."
  }

  nullable = false
}

variable "cluster_name" {
  description = "The name of the ECS cluster"
  type        = string
  default     = "summer-earn-cluster"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.cluster_name))
    error_message = "Cluster name must be alphanumeric with underscores or hyphens."
  }

  nullable = false
}

variable "governance_cache_table_name" {
  description = "The name of the DynamoDB table for governance caching"
  type        = string
  default     = "SummerGovernanceCache"
  nullable    = false
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

variable "coingecko_api_key" {
  description = "API Key for CoinGecko"
  type        = string
  sensitive   = true
  default     = ""
}

variable "blockscout_api_key" {
  description = "API Key for Blockscout"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tenderly_access_key" {
  description = "Access Key for Tenderly"
  type        = string
  sensitive   = true
  default     = ""
}

variable "walletconnect_id" {
  description = "WalletConnect Project ID"
  type        = string
  default     = "demo"
}
