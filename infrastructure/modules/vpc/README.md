# VPC Module

This module provisions a production-grade Networking stack for the Summer Earn Protocol.

## Features
- Dedicated VPC with DNS support.
- Public and Private subnets across multiple Availability Zones.
- Internet Gateway for public routing.
- NAT Gateway (Single) in a public subnet to allow private resources to reach the internet.
- Scoped Route Tables and Associations.

## Usage

```hcl
module "vpc" {
  source   = "./modules/vpc"
  vpc_name = "summer-earn-vpc"
  azs      = ["eu-central-1a", "eu-central-1b"]
  tags     = { Environment = "Production" }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vpc_name | Name of the VPC | `string` | n/a | yes |
| cidr_block | CIDR block for the VPC | `string` | `10.0.0.0/16` | no |
| azs | List of Availability Zones | `list(string)` | n/a | yes |
| public_subnets | List of public subnet CIDRs | `list(string)` | `["10.0.1.0/24", "10.0.2.0/24"]` | no |
| private_subnets | List of private subnet CIDRs | `list(string)` | `["10.0.101.0/24", "10.0.102.0/24"]` | no |
| tags | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC |
| public_subnets | List of public subnet IDs |
| private_subnets | List of private subnet IDs |
