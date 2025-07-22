variable "secret_name" {
  description = "Name for the AWS Secrets Manager secret"
  type        = string
}

variable "secret_value" {
  description = "JSON-formatted string for the secret value"
  type        = any
}
