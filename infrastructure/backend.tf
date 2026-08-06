terraform {
  backend "s3" {
    bucket       = "summer-earn-protocol-tfstate-026090545685"
    key          = "global/s3/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
