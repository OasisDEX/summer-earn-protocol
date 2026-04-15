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
  name               = "${var.app_name}-amplify-service-role"
  assume_role_policy = data.aws_iam_policy_document.amplify_trust.json

  tags = var.tags
}

# Scoped Amplify permissions instead of AdministratorAccess-Amplify
data "aws_iam_policy_document" "amplify_permissions" {
  # Amplify service permissions
  statement {
    sid = "AmplifyManagement"
    actions = [
      "amplify:GetApp",
      "amplify:GetBranch",
      "amplify:CreateBranch",
      "amplify:DeleteBranch",
      "amplify:CreateDeployment",
      "amplify:StartDeployment",
      "amplify:StopDeployment",
      "amplify:GetJob",
      "amplify:ListJobs",
      "amplify:StartJob",
      "amplify:StopJob",
    ]
    resources = ["*"]
  }

  # CloudFront for hosting
  statement {
    sid = "CloudFrontHosting"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetDistribution",
      "cloudfront:GetInvalidation",
      "cloudfront:ListDistributions",
      "cloudfront:ListInvalidations",
      "cloudfront:UpdateDistribution",
    ]
    resources = ["*"]
  }

  # S3 for build artifacts and hosting
  statement {
    sid = "S3BuildArtifacts"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = ["*"]
  }

  # CloudWatch Logs for build logs
  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }

  # SSM for environment variable management
  statement {
    sid = "SSMParameters"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.app_name}-amplify-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.amplify_permissions.json
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
