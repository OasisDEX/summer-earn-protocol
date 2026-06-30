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

variable "keeper_chains" {
  description = <<-EOT
    Per-chain DCA keeper config, keyed by chain slug (base, mainnet). Each enabled
    chain gets its own Lambda + EventBridge schedule + SSM secret prefix, all
    running the one shared image. Add a chain by adding a map entry. `rpc_url` is
    written to an SSM SecureString — leave it "" to get a REPLACE_ME placeholder
    you fill in the console (so the real endpoint never lands in tfstate).
    `dca_strategy_manager` defaults to the interim v4 address per chain and is
    swapped to v5 post-deploy (bd aphelion-app-4z5). Set `enabled = false` to
    pause/skip a chain without removing it.
  EOT
  type = map(object({
    chain_id             = number
    dca_strategy_manager = string
    subgraph_url         = string
    rpc_url              = optional(string, "")
    schedule_expression  = optional(string, "rate(10 minutes)")
    enabled              = optional(bool, true)
  }))
  default = {
    base = {
      chain_id             = 8453
      dca_strategy_manager = "0x82334fd233430C086ED7B9ED4723a7728d1eF292" # interim v4 -> v5 post-deploy
      subgraph_url         = "https://subgraph.staging.oasisapp.dev/summer-dca-base"
    }
    mainnet = {
      chain_id             = 1
      dca_strategy_manager = "0x8044e2df8bF45f32E6021Bd342b4C734ffA64E0B" # interim v4 -> v5 post-deploy
      subgraph_url         = "https://subgraph.staging.oasisapp.dev/summer-dca"
    }
  }
  nullable = false
}

variable "keeper_image_tag" {
  description = "ECR image tag the keeper Lambdas bootstrap from (CI re-pushes :latest each deploy; image_uri is ignored after create)."
  type        = string
  default     = "latest"
  nullable    = false
}

variable "keeper_ecr_force_delete" {
  description = "Force-delete the shared keeper ECR repository (including all images) on destroy."
  type        = bool
  default     = false
  nullable    = false
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

variable "keeper_private_key" {
  description = "Keeper EOA private key, shared across all chains (stored as a per-chain SSM SecureString). One EOA works on every EVM chain; nonces are independent per chain."
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
