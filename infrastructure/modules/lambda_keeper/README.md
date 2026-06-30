# lambda_keeper

A container-image AWS Lambda invoked on an EventBridge schedule. Built for the
DCA keeper (`packages/core-contracts/scripts/dca-keeper`) running in one-shot
mode, but generic enough for any scheduled, image-packaged keeper.

## What it creates

- `aws_ecr_repository` (MUTABLE tags) for the function image.
- `aws_lambda_function` (`package_type = "Image"`) with `reserved_concurrent_executions = 1`
  so passes never overlap.
- `aws_cloudwatch_event_rule` + target + `aws_lambda_permission` — fires the
  function on `var.schedule_expression` (default `rate(10 minutes)`).
- `aws_ssm_parameter` SecureStrings (one per `var.secrets` key) under
  `var.ssm_prefix`, plus an IAM role allowed to read + `kms:Decrypt` them.
- `aws_cloudwatch_log_group` `/aws/lambda/<function_name>`.

Secrets are read at runtime by the handler (it injects them into the env), not
baked into the function config.

## Changing the cadence

Set `schedule_expression` (`rate(10 minutes)`, `rate(5 minutes)`, `cron(...)`).
Set `schedule_enabled = false` to pause without destroying.

## First deploy (bootstrap)

The image must exist before the Lambda can be created:

1. Create just the repo: `terraform apply -target='module.<name>.aws_ecr_repository.this'`
2. Build + push the first image (the CI workflow's `workflow_dispatch`, or
   manually `docker build`/`push` the repo's `:latest` tag).
3. `terraform apply` — creates the Lambda (from `:latest`) + schedule.

Thereafter CI pushes `:<sha>` and calls `update-function-code`; Terraform
ignores `image_uri`.
