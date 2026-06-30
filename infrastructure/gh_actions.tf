locals {
  github_repo = "OasisDEX/summer-earn-protocol"
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
      # Scoped to the keeper function only: update-function-code runs
      # attacker-controlled image code under the function's role + secrets
      # (the keeper holds a signer key), so this is not a `summer-earn-*` wildcard.
      "arn:aws:lambda:*:${data.aws_caller_identity.current.account_id}:function:summer-earn-dca-keeper"
    ]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "github-actions-deploy-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
