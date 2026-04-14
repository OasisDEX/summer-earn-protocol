terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_ecs_cluster" "main" {
  name = "summer-earn-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}


module "gov_validator" {
  source       = "./modules/amplify_app"
  app_name     = "summer-earn-gov-validator"
  repository   = var.github_repository
  github_token = var.github_token
  package_root = "packages/summer-earn-gov-validator"
  build_filter = "@summerfi/summer-earn-gov-validator"
}

module "auctions_frontend" {
  source       = "./modules/amplify_app"
  app_name     = "summer-earn-auctions-frontend"
  repository   = var.github_repository
  github_token = var.github_token
  package_root = "packages/summer-earn-auctions-frontend"
  build_filter = "@summerfi/summer-earn-auctions-frontend"
}

module "interface" {
  source       = "./modules/amplify_app"
  app_name     = "summer-earn-interface"
  repository   = var.github_repository
  github_token = var.github_token
  package_root = "packages/summer-earn-interface"
  build_filter = "@summerfi/summer-earn-interface"
}


module "gov_alert_bot" {
  source     = "./modules/ecs_worker"
  app_name   = "summer-earn-gov-alert-bot"
  cluster_id = aws_ecs_cluster.main.id
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids
}
