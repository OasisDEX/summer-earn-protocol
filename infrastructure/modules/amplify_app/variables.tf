variable "app_name" {
  description = "The name of the Amplify app"
  type        = string
  nullable    = false
}

variable "repository" {
  description = "GitHub repository URL"
  type        = string
  nullable    = false
}

variable "github_token" {
  description = "GitHub personal access token for Amplify repo access"
  type        = string
  sensitive   = true
}

variable "branch_name" {
  description = "The branch to deploy"
  type        = string
  default     = "main"
}

variable "package_root" {
  description = "The monorepo path (e.g., packages/summer-earn-gov-validator)"
  type        = string
  nullable    = false
}

variable "build_filter" {
  description = "The turborepo filter, e.g. @summerfi/summer-earn-gov-validator"
  type        = string
  nullable    = false
}

variable "platform" {
  description = "Amplify hosting platform: WEB_COMPUTE (Next.js SSR) or WEB (static export)"
  type        = string
  default     = "WEB_COMPUTE"

  validation {
    condition     = contains(["WEB_COMPUTE", "WEB"], var.platform)
    error_message = "platform must be WEB_COMPUTE or WEB."
  }
}

variable "framework" {
  description = "Framework label for the Amplify branch (e.g. 'Next.js - SSR', 'Next.js - SSG')"
  type        = string
  default     = "Next.js - SSR"
}

variable "build_command" {
  description = "Build command run in the package root"
  type        = string
  default     = "pnpm run build"
}

variable "artifacts_base_directory" {
  description = "Build output directory relative to the package root"
  type        = string
  default     = ".next"
}

variable "build_compute_type" {
  description = "Amplify build compute size (STANDARD_8GB, LARGE_16GB or XLARGE_72GB)"
  type        = string
  default     = "XLARGE_72GB"

  validation {
    condition     = contains(["STANDARD_8GB", "LARGE_16GB", "XLARGE_72GB"], var.build_compute_type)
    error_message = "build_compute_type must be one of STANDARD_8GB, LARGE_16GB, XLARGE_72GB."
  }
}

variable "tags" {
  description = "Tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
}

variable "environment_variables" {
  description = "Environment variables for the Amplify app"
  type        = map(string)
  default     = {}
}

variable "dynamodb_arn" {
  type        = string
  description = "Optional ARN of a DynamoDB table the compute role can access"
  default     = null
}

variable "enable_dynamodb_access" {
  type        = bool
  description = "Set to true to create the DynamoDB access policy"
  default     = false
}

variable "secrets" {
  description = "Sensitive secrets to store in SSM for the Amplify app"
  type        = map(string)
  default     = {}
}

variable "custom_domain" {
  description = "Optional custom domain name to associate with the Amplify app"
  type        = string
  default     = ""
}

variable "additional_domains" {
  description = "Optional list of additional custom domain names to associate with the Amplify app"
  type        = list(string)
  default     = []
}
