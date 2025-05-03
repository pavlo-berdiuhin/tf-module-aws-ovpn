variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "environment" {
  type        = string
  description = "Environment"
}

variable "stack" {
  type        = string
  description = "Installation stack"
}

variable "owner" {
  type        = string
  description = "Owner"
}

variable "team" {
  type        = string
  description = "Team name"
  default     = "devops"
}

variable "deployment_name" {
  type        = string
  description = "Deployment name"
}

variable "additional_tags" {
  type        = map(string)
  description = "Additional tags for all resources"
  default     = {}
}
