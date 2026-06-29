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

  # Non-secret DCA keeper config (plain Lambda env vars).
  keeper_env = {
    CHAIN_ID                        = tostring(var.keeper_chain_id)
    DCA_STRATEGY_MANAGER            = var.keeper_dca_strategy_manager
    SUBGRAPH_URL                    = var.keeper_subgraph_url
    ENSO_API_URL                    = var.keeper_enso_api_url
    MAX_CONCURRENT_EXECUTIONS       = tostring(var.keeper_max_concurrent_executions)
    TX_CONFIRMATION_TIMEOUT_SECONDS = tostring(var.keeper_tx_confirmation_timeout)
    LOG_LEVEL                       = var.keeper_log_level
    KEEPER_RUN_ONCE                 = "1"
  }

  # Secret DCA keeper config (written to SSM SecureStrings, read at runtime).
  keeper_secrets = {
    RPC_URL            = var.keeper_rpc_url
    KEEPER_PRIVATE_KEY = var.keeper_private_key
    ENSO_API_KEY       = var.keeper_enso_api_key
  }
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

# Scheduled one-shot DCA keeper. Runs the keeper checks (subgraph -> checkUpkeep
# -> Enso -> executeStrategy) once per invocation; EventBridge fires it on
# var.keeper_schedule_expression (default every 10 minutes). No VPC needed —
# RPC/subgraph/Enso are public HTTPS endpoints.
module "dca_keeper" {
  source              = "./modules/lambda_keeper"
  function_name       = "summer-earn-dca-keeper"
  schedule_expression = var.keeper_schedule_expression
  ssm_prefix          = "/dca-keeper/summer-earn-dca-keeper"
  environment         = local.keeper_env
  secrets             = local.keeper_secrets
  tags                = local.common_tags
}

moved {
  from = aws_ecs_cluster.main
  to   = aws_ecs_cluster.this
}
