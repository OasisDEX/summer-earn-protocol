terraform {
  backend "s3" {
    bucket       = "summer-earn-protocol-tfstate-17c8a2ef"
    key          = "global/s3/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
