# lambda_keeper

A container-image AWS Lambda invoked on an EventBridge schedule. Built for the
DCA keeper (`packages/core-contracts/scripts/dca-keeper`) running in one-shot
mode, but generic enough for any scheduled, image-packaged keeper.

**Instantiated once per chain.** The root module (`infrastructure/main.tf`)
creates the shared image registry (`aws_ecr_repository.dca_keeper`) and the
secrets CMK (`aws_kms_key.dca_keeper_secrets`) once, then `for_each`es this
module over `var.keeper_chains`, passing `ecr_repository_url` + `kms_key_arn`
in. So every chain keeper runs the same image (the chain is selected at runtime
by `CHAIN_ID`/`RPC_URL`/`DCA_STRATEGY_MANAGER` env) and decrypts against one key.

## What it creates (per chain)

- `aws_lambda_function` (`package_type = "Image"`) with
  `reserved_concurrent_executions = 1` so passes never overlap — **nonce safety
  is per chain** (one in-process nonce per invocation per chain).
- `aws_cloudwatch_event_rule` + target + `aws_lambda_permission` — fires the
  function on `var.schedule_expression` (default `rate(10 minutes)`).
- `aws_ssm_parameter` SecureStrings (one per `var.secrets` key) under
  `var.ssm_prefix`, encrypted with the shared `var.kms_key_arn`, plus an IAM
  role allowed to read them + `kms:Decrypt` scoped to that key.
- `aws_cloudwatch_log_group` `/aws/lambda/<function_name>`.

The ECR repository and the CMK are NOT created here — they are shared inputs.

Secrets are read at runtime by the handler (it injects them into the env), not
baked into the function config. The keeper EOA private key is the same across
chains (passed by the root as `var.keeper_private_key`); only `RPC_URL` is
per-chain. Nonces are independent per chain, so the shared key is safe.

## Changing the cadence / chains

Per chain, set `schedule_expression` (`rate(10 minutes)`, `cron(...)`) and
`schedule_enabled = false` to pause without destroying. Add or remove a chain by
editing the root `var.keeper_chains` map.

## First deploy (bootstrap)

The shared image must exist before any Lambda can be created:

1. Create just the shared repo:
   `terraform apply -target=aws_ecr_repository.dca_keeper`
2. Build + push the first image (the CI workflow's `workflow_dispatch`, or
   manually `docker build`/`push` the repo's `:latest` tag).
3. `terraform apply` — creates every enabled chain's Lambda (from `:latest`) +
   schedule + SSM placeholders + IAM.
4. Fill the real secret values in the SSM console under each chain's
   `/dca-keeper/summer-earn-dca-keeper-<chain>/` prefix.

Thereafter CI pushes `:<sha>` and calls `update-function-code` for each chain
function; Terraform ignores `image_uri`.
