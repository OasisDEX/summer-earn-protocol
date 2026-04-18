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
    TENDERLY_ACCESS_KEY = var.tenderly_access_key
    CRON_SECRET         = var.cron_secret
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

module "gov_alert_bot" {
  source     = "./modules/ecs_worker"
  app_name   = "summer-earn-gov-alert-bot"
  cluster_id = aws_ecs_cluster.this.id
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  tags       = local.common_tags
}

moved {
  from = aws_ecs_cluster.main
  to   = aws_ecs_cluster.this
}
