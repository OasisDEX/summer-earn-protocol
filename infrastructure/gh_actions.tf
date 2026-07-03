locals {
  github_repo = "OasisDEX/summer-earn-protocol"

  # Amplify apps the CI role may manage PR-preview branches for
  # (.github/workflows/amplify-previews.yaml / amplify-prod-deploys.yaml).
  amplify_app_arns = [
    module.gov_validator.arn,
    module.auctions_frontend.arn,
    module.interface.arn,
    module.dca_app.arn,
    module.rwa_app.arn,
    module.institution_inspector.arn,
  ]
}

data "aws_caller_identity" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-deploy-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "github_actions_permissions" {
  # ECR: GetAuthorizationToken requires * — scoped per AWS docs
  statement {
    sid       = "ECRAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ECR: Push/pull scoped to the gov-alert-bot repository
  statement {
    sid = "ECRPushPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
    resources = [
      "arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/summer-earn-*"
    ]
  }

  # ECS: Scoped to the summer-earn cluster and services
  statement {
    sid = "ECSDeployment"
    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeServices",
      "ecs:UpdateService"
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ecs:cluster"
      values = [
        "arn:aws:ecs:*:${data.aws_caller_identity.current.account_id}:cluster/summer-earn-*"
      ]
    }
  }

  # ECS: RegisterTaskDefinition requires * (no resource-level restriction)
  statement {
    sid       = "ECSTaskDefinition"
    actions   = ["ecs:RegisterTaskDefinition", "ecs:DescribeTaskDefinition"]
    resources = ["*"]
  }

  # PassRole: Scoped to ECS task roles only
  statement {
    sid       = "PassRole"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/summer-earn-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  # Lambda: update the scheduled keeper's image (deploy-dca-keeper workflow)
  statement {
    sid = "LambdaDeploy"
    actions = [
      "lambda:GetFunction",
      "lambda:UpdateFunctionCode",
    ]
    resources = [
      # Scoped to the keeper functions only: update-function-code runs
      # attacker-controlled image code under the function's role + secrets
      # (the keeper holds a signer key), so this is not a `summer-earn-*` wildcard.
      # The `-*` suffix covers the per-chain functions (summer-earn-dca-keeper-base,
      # summer-earn-dca-keeper-mainnet, …) created by the dca_keeper for_each.
      "arn:aws:lambda:*:${data.aws_caller_identity.current.account_id}:function:summer-earn-dca-keeper-*"
    ]
  }

  # Amplify: name -> appId discovery for the preview workflows.
  # ListApps supports no resource-level scoping.
  statement {
    sid       = "AmplifyDiscover"
    actions   = ["amplify:ListApps"]
    resources = ["*"]
  }

  # Amplify: PR-preview branch/job management + prod deploy observation, scoped
  # to the frontend apps and their branches/jobs. Actions are allowed on all
  # three ARN shapes because Amplify binds different actions to different
  # resource types (CreateBranch -> app, Get/DeleteBranch -> branch, job
  # actions -> job); the union stays scoped to these apps.
  statement {
    sid = "AmplifyPreviewManage"
    actions = [
      "amplify:GetApp",
      "amplify:GetBranch",
      "amplify:ListBranches",
      "amplify:CreateBranch",
      "amplify:DeleteBranch",
      "amplify:StartJob",
      "amplify:StopJob",
      "amplify:GetJob",
      "amplify:ListJobs",
    ]
    resources = concat(
      local.amplify_app_arns,
      [for a in local.amplify_app_arns : "${a}/branches/*"],
      [for a in local.amplify_app_arns : "${a}/branches/*/jobs/*"],
    )
  }

  # Hard guardrail: CI must never mutate the production branch or the apps
  # themselves — main deploys happen via Amplify auto-build; CI only observes
  # them (GetJob/ListJobs/GetBranch stay allowed).
  statement {
    sid    = "AmplifyProtectProd"
    effect = "Deny"
    actions = [
      "amplify:DeleteBranch",
      "amplify:UpdateBranch",
      "amplify:StartJob",
      "amplify:StopJob",
      "amplify:DeleteApp",
      "amplify:UpdateApp",
    ]
    resources = concat(
      local.amplify_app_arns,
      [for a in local.amplify_app_arns : "${a}/branches/main"],
      [for a in local.amplify_app_arns : "${a}/branches/main/jobs/*"],
    )
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "github-actions-deploy-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
