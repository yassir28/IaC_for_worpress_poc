output "lb_public_ip" {
  value = module.wordpress.lb_public_ip
}

output "mysql_fqdn" {
  value     = module.wordpress.mysql_fqdn
  sensitive = true
}

output "wordpress_url" {
  value = module.wordpress.wordpress_url
}

# --- JumpHost outputs (uncomment when jumphost module is enabled) ---

# output "jumphost_public_ip" {
#   value = module.jumphost.public_ip
# }
#
# output "ssh_jump_command" {
#   value = module.jumphost.ssh_command
# }
