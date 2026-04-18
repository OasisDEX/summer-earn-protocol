data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "amplify_deployment_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["amplify.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

data "aws_iam_policy_document" "amplify_compute_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["amplify.amazonaws.com", "lambda.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    # Optional: Hardening with SourceArn if App ID is known, but wildcarded here to avoid circularity
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:amplify:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:apps/*"]
    }
  }
}

resource "aws_iam_role" "deployment" {
  name               = "${var.app_name}-amplify-deploy-role"
  assume_role_policy = data.aws_iam_policy_document.amplify_deployment_trust.json

  tags = var.tags
}

resource "aws_iam_role" "compute" {
  name               = "${var.app_name}-amplify-compute-role"
  assume_role_policy = data.aws_iam_policy_document.amplify_compute_trust.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "deployment_admin" {
  role       = aws_iam_role.deployment.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-Amplify"
}

resource "aws_iam_role_policy_attachment" "deployment_backend" {
  role       = aws_iam_role.deployment.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmplifyBackendDeployFullAccess"
}

resource "aws_iam_policy" "deployment_pass_role" {
  name        = "${var.app_name}-pass-role"
  description = "Allow Amplify deployment role to pass the compute role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "iam:PassRole"
        Effect   = "Allow"
        Resource = aws_iam_role.compute.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "deployment_pass_role" {
  role       = aws_iam_role.deployment.name
  policy_arn = aws_iam_policy.deployment_pass_role.arn
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
  role       = aws_iam_role.compute.name
  policy_arn = aws_iam_policy.ssm_access.arn
}

resource "aws_iam_role_policy_attachment" "compute_logging" {
  role       = aws_iam_role.compute.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_amplify_app" "this" {
  name       = var.app_name
  repository = var.repository

  access_token         = var.github_token
  iam_service_role_arn = aws_iam_role.deployment.arn
  compute_role_arn     = aws_iam_role.compute.arn

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
                - echo "AWS_APP_ID=$AWS_APP_ID" >> .env.production
                - echo "AWS_BRANCH=$AWS_BRANCH" >> .env.production
                - echo "REGION=$AWS_DEFAULT_REGION" >> .env.production
            build:
              commands:
                - pnpm run build
          artifacts:
            baseDirectory: .next
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

  environment_variables = {
    _HARDENED_SECRETS_ACTIVE = "true"
  }
}

resource "aws_ssm_parameter" "secrets" {
  for_each = var.secrets

  name  = "/amplify/${aws_amplify_app.this.id}/${var.branch_name}/${each.key}"
  type  = "SecureString"
  value = nonsensitive(each.value) == "" ? "REPLACE_ME_IN_SSM_CONSOLE" : each.value

  tags = var.tags
}

moved {
  from = aws_iam_role.this
  to   = aws_iam_role.deployment
}

moved {
  from = aws_iam_role_policy_attachment.this
  to   = aws_iam_role_policy_attachment.deployment_admin
}

moved {
  from = aws_iam_role_policy_attachment.amplify_backend_deploy
  to   = aws_iam_role_policy_attachment.deployment_backend
}
