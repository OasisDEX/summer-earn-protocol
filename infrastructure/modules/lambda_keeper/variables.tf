variable "function_name" {
  description = "Name of the Lambda function (per-chain, e.g. summer-earn-dca-keeper-base)"
  type        = string
  nullable    = false
}

variable "ecr_repository_url" {
  description = "URL of the shared keeper ECR repository (created once in the root module). The Lambda image is this URL joined with image_tag."
  type        = string
  nullable    = false
}

variable "kms_key_arn" {
  description = "ARN of the shared CMK that encrypts the keeper's SSM SecureString secrets (created once in the root module)."
  type        = string
  nullable    = false
}

variable "schedule_expression" {
  description = "EventBridge schedule for the keeper run, e.g. 'rate(10 minutes)' or a cron() expression. This is the knob to change the cadence."
  type        = string
  default     = "rate(10 minutes)"
}

variable "schedule_enabled" {
  description = "Whether the schedule is enabled. Set false to pause the keeper without destroying it."
  type        = bool
  default     = true
}

variable "image_tag" {
  description = "ECR image tag used at create time to bootstrap the function. CI updates the running image via update-function-code; image_uri is ignored after create."
  type        = string
  default     = "latest"
}

variable "architectures" {
  description = "Lambda CPU architecture(s). Must match the image built in the Dockerfile."
  type        = list(string)
  default     = ["x86_64"]
}

variable "timeout" {
  description = "Lambda timeout in seconds. Keep below the schedule interval to avoid overlap."
  type        = number
  default     = 300
}

variable "memory_size" {
  description = "Lambda memory in MB"
  type        = number
  default     = 512
}

variable "reserved_concurrency" {
  description = "Reserved concurrent executions. 1 prevents overlapping keeper passes (nonce safety)."
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch log retention for the function"
  type        = number
  default     = 7
}

variable "ssm_prefix" {
  description = "SSM Parameter Store path prefix for the keeper's SecureString secrets, e.g. '/dca-keeper/summer-earn-dca-keeper'"
  type        = string
  nullable    = false
}

variable "secrets" {
  description = "Secret keeper config written as SSM SecureStrings under ssm_prefix and read at runtime by the handler (e.g. RPC_URL, KEEPER_PRIVATE_KEY, ENSO_API_KEY)."
  type        = map(string)
  default     = {}
  # NOT marked sensitive: the map drives for_each, which forbids sensitive keys.
  # Values stay sensitive via their source root vars (keeper_private_key, the
  # per-chain rpc_url, …) and are written to SecureString params. Mirrors the
  # amplify_app secrets pattern.
}

variable "environment" {
  description = "Non-secret keeper config passed as plain Lambda env vars (e.g. CHAIN_ID, DCA_STRATEGY_MANAGER, SUBGRAPH_URL, ENSO_API_URL, MAX_CONCURRENT_EXECUTIONS, TX_CONFIRMATION_TIMEOUT_SECONDS, LOG_LEVEL, KEEPER_RUN_ONCE)."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
}
