terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "wordpresstfstate"
    container_name       = "tfstate"
    key                  = "wordpress-poc.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# --- Resource Group ---

resource "azurerm_resource_group" "main" {
  name     = "${var.project}-rg"
  location = var.location
}

# --- Networking ---

resource "azurerm_virtual_network" "main" {
  name                = "${var.project}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "web" {
  name                 = "web-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "db" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
  delegation {
    name = "mysql-delegation"
    service_delegation {
      name    = "Microsoft.DBforMySQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# resource "azurerm_subnet" "jump" {
#   name                 = "jump-subnet"
#   resource_group_name  = azurerm_resource_group.main.name
#   virtual_network_name = azurerm_virtual_network.main.name
#   address_prefixes     = ["10.0.3.0/24"]
# }

# --- WordPress Module ---

module "wordpress" {
  source = "./modules/wordpress"

  project              = var.project
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  web_subnet_id        = azurerm_subnet.web.id
  db_subnet_id         = azurerm_subnet.db.id
  vnet_id              = azurerm_virtual_network.main.id
  vm_size              = var.vm_size
  admin_username       = var.admin_username
  ssh_public_key_path  = var.ssh_public_key_path
  mysql_admin_user     = var.mysql_admin_user
  mysql_admin_password = var.mysql_admin_password
}

# --- JumpHost Module (disabled for POC, uncomment to enable) ---

# module "jumphost" {
#   source = "./modules/jumphost"
#
#   project             = var.project
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name
#   subnet_id           = azurerm_subnet.jump.id
#   vm_size             = var.vm_size
#   admin_username      = var.admin_username
#   ssh_public_key_path = var.ssh_public_key_path
#   admin_cidr          = var.admin_cidr
# }
