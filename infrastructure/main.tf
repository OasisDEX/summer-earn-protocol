provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Project   = "summer-earn-protocol"
    ManagedBy = "Terraform"
  }

  common_app_env_vars = {
    REGION                       = var.aws_region
    DYNAMODB_TABLE_NAME          = var.governance_cache_table_name
    NEXT_PUBLIC_WALLETCONNECT_ID = var.walletconnect_id
    NODE_OPTIONS                 = "--max-old-space-size=32000"
  }

  common_app_secrets = {
    COINGECKO_API_KEY   = var.coingecko_api_key
    BLOCKSCOUT_API_KEY  = var.blockscout_api_key
    ETHERSCAN_API_KEY   = var.etherscan_api_key
    TENDERLY_ACCESS_KEY = var.tenderly_access_key
    CRON_SECRET         = var.cron_secret
  }

  # Only enabled chains get a keeper Lambda. Keyed by chain slug (base, mainnet).
  keeper_chains_enabled = { for slug, cfg in var.keeper_chains : slug => cfg if cfg.enabled }
}

module "vpc" {
  source   = "./modules/vpc"
  vpc_name = "${var.cluster_name}-vpc"
  azs      = ["${var.aws_region}a", "${var.aws_region}b"]
  tags     = local.common_tags
}

resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

module "gov_validator" {
  source                = "./modules/amplify_app"
  app_name              = "summer-earn-gov-validator"
  repository            = var.github_repository
  github_token          = var.github_token
  package_root          = "packages/summer-earn-gov-validator"
  build_filter          = "@summerfi/summer-earn-gov-validator"
  environment_variables = local.common_app_env_vars
  secrets               = local.common_app_secrets
  dynamodb_arn          = aws_dynamodb_table.governance_cache.arn
  tags                  = local.common_tags
}

module "auctions_frontend" {
  source                = "./modules/amplify_app"
  app_name              = "summer-earn-auctions-frontend"
  repository            = var.github_repository
  github_token          = var.github_token
  package_root          = "packages/summer-earn-auctions-frontend"
  build_filter          = "@summerfi/summer-earn-auctions-frontend"
  environment_variables = local.common_app_env_vars
  secrets               = local.common_app_secrets
  tags                  = local.common_tags
}

module "interface" {
  source                = "./modules/amplify_app"
  app_name              = "summer-earn-interface"
  repository            = var.github_repository
  github_token          = var.github_token
  package_root          = "packages/summer-earn-interface"
  build_filter          = "@summerfi/summer-earn-interface"
  environment_variables = local.common_app_env_vars
  secrets               = local.common_app_secrets
  tags                  = local.common_tags
}

module "dca_app" {
  source                = "./modules/amplify_app"
  app_name              = "summer-earn-dca-app"
  repository            = var.github_repository
  github_token          = var.github_token
  package_root          = "packages/summer-earn-dca-app"
  build_filter          = "@summerfi/summer-earn-dca-app"
  environment_variables = local.common_app_env_vars
  secrets               = local.common_app_secrets
  tags                  = local.common_tags
}

module "rwa_app" {
  source                = "./modules/amplify_app"
  app_name              = "summer-earn-rwa-app"
  repository            = var.github_repository
  github_token          = var.github_token
  package_root          = "packages/summer-earn-rwa-app"
  build_filter          = "@summerfi/summer-earn-rwa-app"
  environment_variables = local.common_app_env_vars
  secrets               = local.common_app_secrets
  tags                  = local.common_tags
}

module "gov_alert_bot" {
  source     = "./modules/ecs_worker"
  app_name   = "summer-earn-gov-alert-bot"
  cluster_id = aws_ecs_cluster.this.id
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  tags       = local.common_tags
}

# Scheduled one-shot DCA keeper — MULTICHAIN. One Lambda per chain (see the
# for_each below), each running the keeper checks (subgraph -> checkUpkeep ->
# Enso -> executeStrategy) once per invocation on its own schedule. No VPC
# needed — RPC/subgraph/Enso are public HTTPS endpoints.
#
# The image registry and the secrets CMK are SHARED singletons: CI builds one
# image and every chain keeper runs it (the chain is selected at runtime by the
# CHAIN_ID/RPC_URL/DCA_STRATEGY_MANAGER env, not baked into the image).

# Shared image registry. MUTABLE so the CI workflow can re-push the stable
# `:latest` tag each deploy; per-deploy traceability uses the immutable `:<sha>`
# tag CI passes to update-function-code.
resource "aws_ecr_repository" "dca_keeper" {
  name                 = "summer-earn-dca-keeper"
  image_tag_mutability = "MUTABLE"
  force_delete         = var.keeper_ecr_force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# Shared CMK for every chain keeper's SSM SecureString secrets (signer keys).
# A dedicated CMK isolates them from the shared aws/ssm default key, satisfies
# CKV_AWS_337, and lets each Lambda role's kms:Decrypt be scoped to this ARN.
resource "aws_kms_key" "dca_keeper_secrets" {
  description             = "summer-earn-dca-keeper SSM SecureString secrets"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  tags = local.common_tags
}

resource "aws_kms_alias" "dca_keeper_secrets" {
  name          = "alias/summer-earn-dca-keeper-secrets"
  target_key_id = aws_kms_key.dca_keeper_secrets.key_id
}

# One keeper Lambda per enabled chain.
module "dca_keeper" {
  for_each = local.keeper_chains_enabled
  source   = "./modules/lambda_keeper"

  function_name       = "summer-earn-dca-keeper-${each.key}"
  ecr_repository_url  = aws_ecr_repository.dca_keeper.repository_url
  kms_key_arn         = aws_kms_key.dca_keeper_secrets.arn
  image_tag           = var.keeper_image_tag
  schedule_expression = each.value.schedule_expression
  ssm_prefix          = "/dca-keeper/summer-earn-dca-keeper-${each.key}"

  # Non-secret per-chain config (plain Lambda env vars).
  environment = {
    CHAIN_ID                        = tostring(each.value.chain_id)
    DCA_STRATEGY_MANAGER            = each.value.dca_strategy_manager
    SUBGRAPH_URL                    = each.value.subgraph_url
    ENSO_API_URL                    = var.keeper_enso_api_url
    MAX_CONCURRENT_EXECUTIONS       = tostring(var.keeper_max_concurrent_executions)
    TX_CONFIRMATION_TIMEOUT_SECONDS = tostring(var.keeper_tx_confirmation_timeout)
    LOG_LEVEL                       = var.keeper_log_level
    KEEPER_RUN_ONCE                 = "1"
  }

  # Secret config -> SSM SecureStrings (filled in the console post-apply). The
  # private key and Enso key are shared across chains (one keeper EOA; nonces are
  # independent per chain); only the RPC endpoint is per-chain.
  secrets = {
    RPC_URL            = each.value.rpc_url
    KEEPER_PRIVATE_KEY = var.keeper_private_key
    ENSO_API_KEY       = var.keeper_enso_api_key
  }

  tags = local.common_tags
}

moved {
  from = aws_ecs_cluster.main
  to   = aws_ecs_cluster.this
}
