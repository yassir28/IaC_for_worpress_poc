output "lb_public_ip" {
  value = azurerm_public_ip.lb.ip_address
}

output "jumphost_public_ip" {
  value = module.jumphost.public_ip
}

output "mysql_fqdn" {
  value     = azurerm_mysql_flexible_server.main.fqdn
  sensitive = true
}

output "ssh_jump_command" {
  value = module.jumphost.ssh_command
}

output "wordpress_url" {
  value = "http://${azurerm_public_ip.lb.ip_address}"
}
