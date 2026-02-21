variable "project" {
  type    = string
  default = "wordpress-poc"
}

variable "location" {
  type    = string
  default = "West Europe"
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH into jumphost"
  type        = string
  default     = "0.0.0.0/0"
}

variable "mysql_admin_user" {
  type      = string
  sensitive = true
}

variable "mysql_admin_password" {
  type      = string
  sensitive = true
}
