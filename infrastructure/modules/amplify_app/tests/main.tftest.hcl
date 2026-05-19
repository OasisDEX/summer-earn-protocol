# Amplify App Module Invariants Test Suite

variables {
  app_name     = "test-app"
  repository   = "https://github.com/test/repo"
  github_token = "dummy-token"
  package_root = "packages/test"
  build_filter = "@test/app"
  secrets = {
    API_KEY = "test-value"
  }
}

run "verify_iam_naming_convention" {
  command = plan

  assert {
    condition     = endswith(aws_iam_role.this.name, "-v2")
    error_message = "Amplify IAM role must use the -v2 suffix to force ARN refresh"
  }
}

run "verify_amplify_platform" {
  command = plan

  assert {
    condition     = aws_amplify_app.this.platform == "WEB_COMPUTE"
    error_message = "Amplify platform must be WEB_COMPUTE for Next.js SSR support"
  }
}

run "verify_ssm_parameters_exist" {
  command = plan

  assert {
    condition     = length(aws_ssm_parameter.secrets) == 1
    error_message = "Expected 1 SSM parameter for the provided test secrets"
  }
}
