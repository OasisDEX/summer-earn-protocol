data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# NOTE: this module is instantiated ONCE PER CHAIN (see infrastructure/main.tf's
# `module "dca_keeper"` for_each over var.keeper_chains). The image registry
# (ECR) and the secrets CMK are shared singletons created in the root module and
# passed in via `ecr_repository_url` / `kms_key_arn`, so every chain keeper runs
# the same image and decrypts against one key. Per-chain isolation lives here:
# its own Lambda (reserved_concurrency = 1 → nonce safety per chain), schedule,
# SSM prefix, IAM role, and log group.

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# ---------------------------------------------------------------- secrets (SSM)

# One SecureString per secret under the keeper's per-chain prefix. Mirrors the
# amplify_app pattern: an empty value writes a REPLACE_ME placeholder so the
# parameter exists and can be filled in the SSM console without leaking through
# tfstate. Encrypted with the shared keeper CMK (var.kms_key_arn).
resource "aws_ssm_parameter" "secrets" {
  for_each = var.secrets

  name   = "${var.ssm_prefix}/${each.key}"
  type   = "SecureString"
  key_id = var.kms_key_arn
  value  = nonsensitive(each.value) == "" ? "REPLACE_ME_IN_SSM_CONSOLE" : each.value

  # Manage only the parameter's existence, not its value: operators fill the real
  # secret in the SSM console after first apply, and Terraform must not drift-
  # correct it back to the placeholder. With the var left empty, the real secret
  # never enters tfstate.
  lifecycle {
    ignore_changes = [value]
  }

  tags = var.tags
}

# ---------------------------------------------------------------- IAM

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = var.tags
}

# CloudWatch Logs.
resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Read + decrypt the keeper's SecureString secrets at runtime.
data "aws_iam_policy_document" "ssm_read" {
  statement {
    sid     = "ReadKeeperSecrets"
    actions = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_prefix}/*",
    ]
  }

  # Scoped to the shared keeper CMK only (the SSM SecureStrings use it).
  statement {
    sid       = "DecryptKeeperSecrets"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "ssm_read" {
  name   = "${var.function_name}-ssm-read"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.ssm_read.json
}

# ---------------------------------------------------------------- Lambda

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = aws_iam_role.this.arn
  package_type  = "Image"
  image_uri     = "${var.ecr_repository_url}:${var.image_tag}"
  architectures = var.architectures
  timeout       = var.timeout
  memory_size   = var.memory_size

  # One pass at a time — a still-running invocation must not overlap the next
  # scheduled fire (the keeper's nonce is reserved in-process per invocation).
  reserved_concurrent_executions = var.reserved_concurrency

  environment {
    variables = merge(var.environment, { KEEPER_SSM_PREFIX = var.ssm_prefix })
  }

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy_attachment.basic,
    aws_iam_role_policy.ssm_read,
  ]

  tags = var.tags

  # CI owns the image after bootstrap (update-function-code with :<sha>).
  lifecycle {
    ignore_changes = [image_uri]
  }
}

# ---------------------------------------------------------------- schedule

resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${var.function_name}-schedule"
  description         = "Invoke ${var.function_name} on a fixed schedule"
  schedule_expression = var.schedule_expression
  state               = var.schedule_enabled ? "ENABLED" : "DISABLED"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = var.function_name
  arn       = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "events" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}
