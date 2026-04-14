resource "aws_iam_role" "amplify_role" {
  name = "${var.app_name}-amplify-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = ["amplify.amazonaws.com",
            "amplify.eu-central-1.amazonaws.com",
        ] }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "amplify_role_policy" {
  role       = aws_iam_role.amplify_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-Amplify"
}

resource "aws_amplify_app" "this" {
  name       = var.app_name
  repository = var.repository

  access_token = var.github_token

  iam_service_role_arn = aws_iam_role.amplify_role.arn

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
