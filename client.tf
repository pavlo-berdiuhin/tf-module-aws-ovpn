################################################################################
# VPN Clients Passwords
################################################################################
resource "random_password" "this" {
  for_each = toset(var.vpn_clients)

  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}


resource "aws_ssm_parameter" "this" {
  for_each = toset(var.vpn_clients)

  name       = "/${local.name}/${each.key}/ovpn_password"
  type       = "SecureString"
  value      = random_password.this[each.key].result
  depends_on = [random_password.this]
}

################################################################################
# VPN Clients Provisioning
################################################################################
resource "aws_ssm_document" "this" {
  for_each = toset(var.vpn_clients)

  name          = "AddVpnClient_${each.key}"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Add vpn client ${each.key}"
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "install"
      inputs = {
        runCommand = [
          "MENU_OPTION=1 CLIENT=${each.key} PASS=${random_password.this[each.key].result} ./openvpn-install.sh",
        ]
      }
    }]
  })
}


resource "aws_ssm_association" "this" {
  for_each = toset(var.vpn_clients)

  name = aws_ssm_document.this[each.key].name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.this.id]
  }
}