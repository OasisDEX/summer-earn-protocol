# Amplify App Module

This module deploys an AWS Amplify Gen 2 application from a Turborepo monorepo package. It supports
two hosting modes:

- **`WEB_COMPUTE`** (default) — Next.js SSR with an Amplify compute role.
- **`WEB`** — fully static export (e.g. Next.js `output: 'export'`); no compute role is attached.

## Features

- AWS Amplify App with configurable platform (`WEB_COMPUTE` or `WEB`).
- IAM service role with standard Amplify management permissions; compute role only for SSR apps.
- Auto-build of the `main` branch. PR-preview branches are managed by
  `.github/workflows/amplify-previews.yaml` via the Amplify API — native Amplify web previews are
  disabled because this is a public repo (AWS forbids previews on `WEB_COMPUTE` apps in public
  repos).
- Monorepo support via an inline build spec (`AMPLIFY_MONOREPO_APP_ROOT`, `AMPLIFY_DIFF_DEPLOY`).
- Secrets stored as SSM SecureStrings under `/amplify/<app_id>/<branch>/<key>`.

## Usage

SSR app (defaults):

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

Static-export app:

```hcl
module "my_static_app" {
  source       = "./modules/amplify_app"
  app_name     = "my-static-app"
  repository   = "https://github.com/org/repo"
  github_token = var.github_token
  package_root = "packages/my-static-app"
  build_filter = "my-static-app"

  platform                 = "WEB"
  framework                = "Next.js - SSG"
  build_command            = "pnpm run build:static"
  artifacts_base_directory = "out"
  build_compute_type       = "STANDARD_8GB"

  tags = local.common_tags
}
```

## Inputs

| Name                     | Description                                              | Type          | Default            | Required |
| ------------------------ | -------------------------------------------------------- | ------------- | ------------------ | :------: |
| app_name                 | The name of the Amplify app                              | `string`      | n/a                |   yes    |
| repository               | GitHub repository URL                                    | `string`      | n/a                |   yes    |
| github_token             | GitHub personal access token                             | `string`      | n/a                |   yes    |
| branch_name              | The branch to deploy                                     | `string`      | `"main"`           |    no    |
| package_root             | The monorepo path                                        | `string`      | n/a                |   yes    |
| build_filter             | The turborepo filter (currently unused by the buildspec) | `string`      | n/a                |   yes    |
| platform                 | `WEB_COMPUTE` (SSR) or `WEB` (static)                    | `string`      | `"WEB_COMPUTE"`    |    no    |
| framework                | Framework label for the Amplify branch                   | `string`      | `"Next.js - SSR"`  |    no    |
| build_command            | Build command run in the package root                    | `string`      | `"pnpm run build"` |    no    |
| artifacts_base_directory | Build output dir relative to the package root            | `string`      | `".next"`          |    no    |
| build_compute_type       | Build compute size                                       | `string`      | `"XLARGE_72GB"`    |    no    |
| environment_variables    | Environment variables for the app                        | `map(string)` | `{}`               |    no    |
| secrets                  | Secrets stored in SSM for the app                        | `map(string)` | `{}`               |    no    |
| dynamodb_arn             | Optional DynamoDB table ARN for the compute role         | `string`      | `null`             |    no    |
| tags                     | Tags to apply to all resources                           | `map(string)` | `{}`               |    no    |

## Outputs

| Name           | Description                           |
| -------------- | ------------------------------------- |
| app_id         | The ID of the Amplify app             |
| arn            | The ARN of the Amplify app            |
| default_domain | The default domain of the Amplify app |
