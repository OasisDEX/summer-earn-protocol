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

variable "tags" {
  description = "Tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
}
