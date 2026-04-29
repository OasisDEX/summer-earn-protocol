# Amplify App Module

This module deploys an AWS Amplify Gen 2 application with support for Turborepo and Next.js SSR.

## Features
- AWS Amplify App with `WEB_COMPUTE` platform (Next.js SSR support).
- IAM Service Role with standard Amplify management permissions.
- Automatic branch deployment.
- Monorepo support via custom build specs.

## Usage

```hcl
module "my_app" {
  source       = "./modules/amplify_app"
  app_name     = "my-awesome-app"
  repository   = "https://github.com/org/repo"
  github_token = var.github_token
  package_root = "packages/my-app"
  build_filter = "@org/my-app"
  tags         = local.common_tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| app_name | The name of the Amplify app | `string` | n/a | yes |
| repository | GitHub repository URL | `string` | n/a | yes |
| github_token | GitHub personal access token | `string` | n/a | yes |
| branch_name | The branch to deploy | `string` | `"main"` | no |
| package_root | The monorepo path | `string` | n/a | yes |
| build_filter | The turborepo filter | `string` | n/a | yes |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| app_id | The ID of the Amplify app |
| app_arn | The ARN of the Amplify app |
| default_domain | The default domain of the Amplify app |
