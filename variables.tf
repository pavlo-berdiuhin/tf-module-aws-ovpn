variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "name" {
  type        = string
  description = "Name used for resource naming"
}

variable "tags" {
  type        = map(string)
  description = "Tags for all resources"
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
  default     = null
}

variable "instance_type" {
  type        = string
  description = "Instance type"
  default     = "t4g.small"
}

variable "vpn_clients" {
  description = "VPN clients"
  type        = list(string)
  default     = []
}
