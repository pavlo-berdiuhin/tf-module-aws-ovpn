output "vpn_clients" {
  value = {
    for client in var.vpn_clients : client => {
      ovpn_config_ssm_path   = "/${local.name}/${client}/ovpn_config",
      ovpn_password_ssm_path = "/${local.name}/${client}/ovpn_password",
    }
  }
}

output "security_group_id" {
  value = aws_security_group.this.id
}