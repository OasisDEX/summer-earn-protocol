data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "amplify_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type = "Service"
      identifiers = ["amplify.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  # Renaming role to force a new ARN and refresh Amplify's internal association
  name               = "${var.app_name}-amplify-role-v2"
  assume_role_policy = data.aws_iam_policy_document.amplify_trust.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-Amplify"
}

resource "aws_iam_role_policy_attachment" "amplify_backend_deploy" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmplifyBackendDeployFullAccess"
}

resource "aws_iam_policy" "ssm_access" {
  name        = "${var.app_name}-ssm-access"
  description = "Allow Amplify to read its own secrets from SSM"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/amplify/${aws_amplify_app.this.id}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.ssm_access.arn
}

resource "aws_amplify_app" "this" {
  name       = var.app_name
  repository = var.repository

  access_token = var.github_token
  iam_service_role_arn = aws_iam_role.this.arn

  environment_variables = merge(var.environment_variables, {
    AMPLIFY_MONOREPO_APP_ROOT = var.package_root
  })

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
                - pnpm run build
          artifacts:
            baseDirectory: .next/standalone
            files:
              - '**/*'
          cache:
            paths:
              - .next/cache/**/*
  EOT

  job_config {
    build_compute_type = "XLARGE_72GB"
  }

  tags = var.tags
}

resource "aws_amplify_branch" "this" {
  app_id      = aws_amplify_app.this.id
  branch_name = var.branch_name

  framework         = "Next.js - SSR"
  enable_auto_build = true
}

resource "aws_ssm_parameter" "secrets" {
  for_each = var.secrets

  name  = "/amplify/${aws_amplify_app.this.id}/${var.branch_name}/${each.key}"
  type  = "SecureString"
  value = each.value

  tags = var.tags
}

moved {
  from = aws_iam_role.amplify_role
  to   = aws_iam_role.this
}

moved {
  from = aws_iam_role_policy_attachment.amplify_role_policy
  to   = aws_iam_role_policy_attachment.this
}
