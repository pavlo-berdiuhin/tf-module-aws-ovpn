################################################################################
# VPN Clients Passwords
################################################################################
resource "random_password" "this" {
  for_each = toset(var.vpn_clients)

  length  = 16
  special = false
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
resource "time_sleep" "wait_5min" {
  create_duration = "5m"
  triggers = {
    instance_id = aws_instance.this.id
  }
}

resource "aws_ssm_document" "this" {
  for_each = toset(var.vpn_clients)

  name          = "${local.name}_${each.key}"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Add vpn client ${each.key}"
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "vpn_client"
      inputs = {
        runCommand = [
          "MENU_OPTION=1 CLIENT=${each.key} PASS=2 EASYRSA_PASSOUT='pass:${random_password.this[each.key].result}' /openvpn-install.sh",
          "aws ssm put-parameter --name '/${local.name}/${each.key}/ovpn_config' --type 'String' --value 'file:///root/${each.key}.ovpn' --overwrite",
        ]
      }
    }]
  })
  depends_on = [aws_instance.this, time_sleep.wait_5min]
}


resource "aws_ssm_association" "this" {
  for_each = toset(var.vpn_clients)

  name                             = aws_ssm_document.this[each.key].name
  wait_for_success_timeout_seconds = 60
  targets {
    key    = "InstanceIds"
    values = [aws_instance.this.id]
  }
  depends_on = [aws_instance.this, aws_ssm_document.this]
}