variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
  default     = "my-eks-cluster"
}

variable "bucket_name" {
  type        = string
}

variable "secret_name" {
  type        = string
  description = "Name for the AWS Secrets Manager secret"
}

variable "secret_value" {
  type        = any
  description = "Value to store in the AWS Secrets Manager secret"
  sensitive   = true
}


