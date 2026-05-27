data "aws_caller_identity" "this" {}

data "aws_vpc" "this" {
  id = var.vpc_id
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
  count = var.zone_id != null ? 1 : 0

  zone_id = var.zone_id
}


locals {
  create_dns_record = var.zone_id != null
  dns_name          = local.create_dns_record ? "vpn.${data.aws_route53_zone.this[0].name}" : null
  vpn_endpoint      = local.create_dns_record ? local.dns_name : aws_eip.this.public_ip
  vpc_cidr_host     = cidrhost(data.aws_vpc.this.cidr_block, 0)
  vpc_cidr_mask     = cidrnetmask(data.aws_vpc.this.cidr_block)
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
  user_data = <<-EOF
    #!/usr/bin/env bash
    set -x
    curl -fsSL -o /openvpn-install.sh https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
    chmod +x /openvpn-install.sh
    sudo /openvpn-install.sh install --endpoint ${local.vpn_endpoint} --no-client
    sed  -i 's/"redirect-gateway def1 bypass-dhcp"/"route ${local.vpc_cidr_host} ${local.vpc_cidr_mask}"/' /etc/openvpn/server/server.conf
    systemctl daemon-reload
    systemctl restart openvpn-server@server
    sudo snap install aws-cli --classic
    EOF

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = var.name
  }
}

####################################################################################################
# Network
####################################################################################################
resource "aws_security_group" "this" {
  name        = var.name
  description = "Allow VPN access to the ${var.name} instance"
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
  domain = "vpc"
}


resource "aws_eip_association" "this" {
  allocation_id = aws_eip.this.id
  instance_id   = aws_instance.this.id
}


resource "aws_route53_record" "vpn" {
  count = local.create_dns_record ? 1 : 0

  zone_id = var.zone_id
  name    = local.dns_name
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
  role_name               = var.name
  role_requires_mfa       = false
  create_instance_profile = true
  trusted_role_arns       = []
  trusted_role_services   = ["ec2.amazonaws.com"]
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]
  inline_policy_statements = {
    "AllowSSM" = {
      effect = "Allow"
      actions = [
        "ssm:PutParameter",
      ]
      resources = [
        "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.this.account_id}:parameter/${var.name}/*",
      ]
    }
  }
}
