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
  default     = "vpn"
}

variable "additional_tags" {
  type        = map(string)
  description = "Additional tags for all resources"
  default     = {}
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID"
}

variable "zone_id" {
  type        = string
  description = "Route53 zone ID"
}

variable "instance_type" {
  type        = string
  description = "Instance type"
  default     = "t4g.small"
}

variable "vpn_clients" {
  description = "VPN clients"
  type        = list(string)
  default = [
    "devops",
  ]
}
