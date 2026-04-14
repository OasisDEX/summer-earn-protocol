resource "aws_amplify_app" "this" {
  name       = var.app_name
  repository = var.repository

  access_token                = var.github_token

  enable_branch_auto_build    = true
  enable_branch_auto_deletion = true

  auto_branch_creation_config {
    enable_auto_build             = true
    enable_pull_request_preview   = true
    pull_request_environment_name = "pr-preview"
  }

  platform = "WEB_COMPUTE"

  build_spec = <<-EOT
    version: 1
    applications:
      - appRoot: ${var.package_root}
        frontend:
          phases:
            preBuild:
              commands:
                - npm install -g pnpm
                - pnpm install
            build:
              commands:
                - pnpm run build --filter=${var.build_filter}
          artifacts:
            baseDirectory: .next
            files:
              - '**/*'
          cache:
            paths:
              - node_modules/**/*
              - .next/cache/**/*
  EOT
}

resource "aws_amplify_branch" "this" {
  app_id      = aws_amplify_app.this.id
  branch_name = var.branch_name

  framework         = "Next.js - SSR"
  enable_auto_build = true
}
