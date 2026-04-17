# VPC Module Invariants Test Suite

variables {
  vpc_name = "test-vpc"
  azs      = ["eu-central-1a", "eu-central-1b"]
}

run "verify_vpc_configuration" {
  command = plan

  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR block does not match expected default '10.0.0.0/16'"
  }

  assert {
    condition     = aws_vpc.this.enable_dns_hostnames == true
    error_message = "DNS hostnames should be enabled for production compatibility"
  }
}

run "verify_subnet_layout" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "Expected 2 public subnets based on default variables"
  }

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "Expected 2 private subnets based on default variables"
  }
}

run "verify_networking_isolation" {
  command = plan

  assert {
    condition     = alltrue([for s in aws_subnet.public : s.map_public_ip_on_launch == true])
    error_message = "Public subnets must have map_public_ip_on_launch enabled"
  }

  assert {
    condition     = alltrue([for s in aws_subnet.private : s.map_public_ip_on_launch == false])
    error_message = "Private subnets must NOT have map_public_ip_on_launch enabled for security"
  }
}
