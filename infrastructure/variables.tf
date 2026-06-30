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

variable "etherscan_api_key" {
  description = "API Key for Etherscan"
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

variable "cron_secret" {
  description = "Secret for authorizing cron job requests"
  type        = string
  sensitive   = true
  default     = ""
}

# ---------------------------------------------------------------- DCA keeper Lambda

variable "keeper_schedule_expression" {
  description = "EventBridge schedule for the DCA keeper Lambda. Change this to adjust the cadence (e.g. 'rate(10 minutes)', 'rate(5 minutes)', 'cron(...)')."
  type        = string
  default     = "rate(10 minutes)"
  nullable    = false
}

variable "keeper_chain_id" {
  description = "Chain ID the keeper operates on (Base mainnet = 8453)"
  type        = number
  default     = 8453
  nullable    = false
}

variable "keeper_dca_strategy_manager" {
  description = "DCAStrategyManager contract address the keeper executes against"
  type        = string
  default     = ""
}

variable "keeper_subgraph_url" {
  description = "DCA subgraph GraphQL endpoint the keeper polls"
  type        = string
  default     = ""
}

variable "keeper_enso_api_url" {
  description = "Enso router API base URL"
  type        = string
  default     = "https://api.enso.finance/api/v1"
  nullable    = false
}

variable "keeper_max_concurrent_executions" {
  description = "Max strategies the keeper processes concurrently within a single pass"
  type        = number
  default     = 3
  nullable    = false
}

variable "keeper_tx_confirmation_timeout" {
  description = "Seconds the keeper waits for a tx receipt before moving on (kept short for one-shot Lambda runs)"
  type        = number
  default     = 60
  nullable    = false
}

variable "keeper_log_level" {
  description = "Keeper log level (DEBUG/INFO/WARNING/ERROR)"
  type        = string
  default     = "INFO"
  nullable    = false
}

variable "keeper_rpc_url" {
  description = "RPC endpoint for the keeper's chain (stored as an SSM SecureString)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "keeper_private_key" {
  description = "Keeper EOA private key (stored as an SSM SecureString)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "keeper_enso_api_key" {
  description = "Enso API key, optional (stored as an SSM SecureString)"
  type        = string
  sensitive   = true
  default     = ""
}
