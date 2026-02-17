output "lb_public_ip" {
  value = azurerm_public_ip.lb.ip_address
}

output "mysql_fqdn" {
  value     = azurerm_mysql_flexible_server.main.fqdn
  sensitive = true
}

output "wordpress_url" {
  value = "http://${azurerm_public_ip.lb.ip_address}"
}
