data "aws_iam_policy_document" "amplify_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "amplify.amazonaws.com",
        "amplify.eu-central-1.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role" "this" {
  # Renaming role to force a new ARN and refresh Amplify's internal association
  name               = "${var.app_name}-amplify-role-v1"
  assume_role_policy = data.aws_iam_policy_document.amplify_trust.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-Amplify"
}

resource "aws_amplify_app" "this" {
  name       = var.app_name
  repository = var.repository

  access_token = var.github_token

  iam_service_role_arn = aws_iam_role.this.arn

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

  tags = var.tags
}

resource "aws_amplify_branch" "this" {
  app_id      = aws_amplify_app.this.id
  branch_name = var.branch_name

  framework         = "Next.js - SSR"
  enable_auto_build = true
}

moved {
  from = aws_iam_role.amplify_role
  to   = aws_iam_role.this
}

moved {
  from = aws_iam_role_policy_attachment.amplify_role_policy
  to   = aws_iam_role_policy_attachment.this
}
