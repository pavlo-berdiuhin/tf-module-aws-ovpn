provider "aws" {
  region = var.aws_region
  default_tags {
    tags = merge({
      Name        = local.name
      terraform   = "true"
      owner       = var.owner
      environment = var.environment
      stack       = var.stack
      team        = var.team
    }, var.additional_tags)
  }
}


data "aws_ami" "this" {
  owners      = ["099720109477"]
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }
}


data "aws_route53_zone" "this" {
  zone_id = var.zone_id
}


locals {
  name = "${var.deployment_name}-${var.environment}-${var.stack}"
}

####################################################################################################
# VPN instance
####################################################################################################
resource "aws_instance" "this" {
  ami                         = data.aws_ami.this.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = ["${aws_security_group.this.id}"]
  associate_public_ip_address = true
  subnet_id                   = var.subnet_id
  iam_instance_profile        = module.iam.iam_instance_profile_name
  user_data_replace_on_change = true
  credit_specification {
    cpu_credits = "standard"
  }
  root_block_device {
    volume_type = "gp3"
    volume_size = 20
  }
  user_data = <<EOF
    #!/bin/bash -xe
    curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
    chmod +x openvpn-install.sh
    sudo AUTO_INSTALL=y ENDPOINT=vpn.${data.aws_route53_zone.this.name} ./openvpn-install.sh
  EOF

  lifecycle {
    ignore_changes = [ami]
  }
}

####################################################################################################
# Network
####################################################################################################
resource "aws_security_group" "this" {
  name        = local.name
  description = "Allow VPN access to the ${local.name} instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_eip" "this" {
  domain   = "vpc"
  instance = aws_instance.this.id
}


resource "aws_route53_record" "vpn" {
  zone_id = var.zone_id
  name    = "vpn.${data.aws_route53_zone.this.name}"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.this.public_ip]
}

####################################################################################################
# IAM
####################################################################################################
module "iam" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.55.0"

  create_role             = true
  role_name               = local.name
  role_requires_mfa       = false
  create_instance_profile = true
  trusted_role_arns       = []
  trusted_role_services   = ["ec2.amazonaws.com"]
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]
  inline_policy_statements = {
    "AllowSSM" = {
      Effect = "Allow"
      Action = [
        "ssm:PutParameter",
      ]
      Resource = "/${local.name}/*"
    }
  }
}
