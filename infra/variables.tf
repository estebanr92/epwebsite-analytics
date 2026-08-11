variable "aws_region" {
  description = "AWS region where the analytics pipeline is deployed."
  type        = string
  default     = "us-east-2"
}

variable "aws_profile" {
  description = "AWS CLI profile used for authentication."
  type        = string
  default     = "eramon-nr-admin"
}

variable "project_name" {
  description = "Short project name used as a prefix/tag on all resources."
  type        = string
  default     = "epwebsite-analytics"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"
}
