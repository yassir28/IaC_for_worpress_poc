variable "project" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "web_subnet_id" {
  type = string
}

variable "db_subnet_id" {
  type = string
}

variable "vnet_id" {
  type = string
}

variable "vm_size" {
  type = string
}

variable "admin_username" {
  type = string
}

variable "ssh_public_key_path" {
  type = string
}

variable "mysql_admin_user" {
  type      = string
  sensitive = true
}

variable "mysql_admin_password" {
  type      = string
  sensitive = true
}
