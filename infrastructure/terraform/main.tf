# Main Terraform Configuration
# Azure SaaS Project: saas202544

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Uncomment for remote state
  # backend "azurerm" {
  #   resource_group_name  = "rg-vrd-terraform-prd-eus2-ops"
  #   storage_account_name = "stvrdtfstateprdeus201"
  #   container_name       = "tfstate"
  #   key                  = "saas202544.terraform.tfstate"
  # }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

# Naming module
module "naming" {
  source = "./modules/naming"

  org               = var.org
  project           = var.project
  env               = var.env
  region            = var.region
  location          = var.location
  owner             = var.owner
  cost_center       = var.cost_center
  data_sensitivity  = var.data_sensitivity
  compliance        = var.compliance
  business_unit     = var.business_unit
  application       = var.application
}

# Resource Groups
resource "azurerm_resource_group" "app" {
  name     = "${module.naming.resource_group_name}-app"
  location = module.naming.location
  tags     = module.naming.common_tags
}

resource "azurerm_resource_group" "data" {
  name     = "${module.naming.resource_group_name}-data"
  location = module.naming.location
  tags     = module.naming.common_tags
}

resource "azurerm_resource_group" "net" {
  name     = "${module.naming.resource_group_name}-net"
  location = module.naming.location
  tags     = module.naming.common_tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = module.naming.log_analytics_name
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = module.naming.common_tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = module.naming.app_insights_name
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = module.naming.common_tags
}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                       = "${module.naming.key_vault_name}-01"
  location                   = azurerm_resource_group.app.location
  resource_group_name        = azurerm_resource_group.app.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = module.naming.common_tags
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = module.naming.vnet_name
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  address_space       = ["10.0.0.0/16"]
  tags                = module.naming.common_tags
}

# Subnets
resource "azurerm_subnet" "app" {
  name                 = "${module.naming.subnet_name}-app"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "data" {
  name                 = "${module.naming.subnet_name}-data"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Network Security Groups
resource "azurerm_network_security_group" "app" {
  name                = "${module.naming.nsg_name}-app"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  tags                = module.naming.common_tags
}

resource "azurerm_network_security_group" "data" {
  name                = "${module.naming.nsg_name}-data"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  tags                = module.naming.common_tags
}

# Data sources
data "azurerm_client_config" "current" {}

# Outputs
output "resource_group_app_name" {
  value = azurerm_resource_group.app.name
}

output "resource_group_data_name" {
  value = azurerm_resource_group.data.name
}

output "resource_group_net_name" {
  value = azurerm_resource_group.net.name
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "app_insights_instrumentation_key" {
  value     = azurerm_application_insights.main.instrumentation_key
  sensitive = true
}
