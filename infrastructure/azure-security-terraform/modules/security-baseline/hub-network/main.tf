# Azure Hub Network with Firewall + DDoS + Bastion
# Part of: Azure Security Playbook v2.0
# Purpose: Deploy secure hub network infrastructure

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

variable "org" {
  description = "Organization code (2-4 chars)"
  type        = string
}

variable "env" {
  description = "Environment (dev, tst, prd)"
  type        = string
}

variable "region" {
  description = "Azure region short code (e.g., eus2)"
  type        = string
}

variable "location" {
  description = "Azure region full name"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "hub_vnet_address_space" {
  description = "Hub VNet address space"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "firewall_subnet_prefix" {
  description = "Azure Firewall subnet prefix"
  type        = string
  default     = "10.0.1.0/24"
}

variable "bastion_subnet_prefix" {
  description = "Azure Bastion subnet prefix"
  type        = string
  default     = "10.0.2.0/24"
}

variable "firewall_sku" {
  description = "Azure Firewall SKU (Standard or Premium)"
  type        = string
  default     = "Premium"
  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku)
    error_message = "Firewall SKU must be Standard or Premium."
  }
}

variable "enable_ddos" {
  description = "Enable DDoS Protection Standard"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}

locals {
  hub_vnet_name     = "vnet-${var.org}-hub-${var.env}-${var.region}"
  firewall_name     = "azfw-${var.org}-hub-${var.env}-${var.region}"
  firewall_pip_name = "pip-firewall-${var.org}-hub-${var.env}-${var.region}"
  bastion_name      = "bastion-${var.org}-hub-${var.env}-${var.region}"
  bastion_pip_name  = "pip-bastion-${var.org}-hub-${var.env}-${var.region}"
  ddos_plan_name    = "ddos-plan-${var.org}-hub-${var.env}-${var.region}"
}

# DDoS Protection Plan
resource "azurerm_network_ddos_protection_plan" "ddos" {
  count               = var.enable_ddos ? 1 : 0
  name                = local.ddos_plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Hub VNet
resource "azurerm_virtual_network" "hub" {
  name                = local.hub_vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.hub_vnet_address_space
  tags                = var.tags

  dynamic "ddos_protection_plan" {
    for_each = var.enable_ddos ? [1] : []
    content {
      id     = azurerm_network_ddos_protection_plan.ddos[0].id
      enable = true
    }
  }
}

# Azure Firewall Subnet
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.firewall_subnet_prefix]
}

# Azure Bastion Subnet
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

# Firewall Public IP
resource "azurerm_public_ip" "firewall" {
  name                = local.firewall_pip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Firewall Policy
resource "azurerm_firewall_policy" "policy" {
  name                = "azfw-policy-${var.org}-hub-${var.env}-${var.region}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.firewall_sku
  threat_intelligence_mode = "Alert"
  tags                = var.tags

  dns {
    proxy_enabled = true
  }

  dynamic "intrusion_detection" {
    for_each = var.firewall_sku == "Premium" ? [1] : []
    content {
      mode = "Alert"
    }
  }
}

# Firewall Policy Rule Collection Group
resource "azurerm_firewall_policy_rule_collection_group" "rules" {
  name               = "DefaultRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.policy.id
  priority           = 100

  application_rule_collection {
    name     = "AllowedOutbound"
    priority = 100
    action   = "Allow"

    rule {
      name = "AllowPackageRepos"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = ["10.0.0.0/8"]
      destination_fqdns = [
        "*.npmjs.com",
        "*.pypi.org",
        "*.nuget.org",
        "github.com",
        "*.githubusercontent.com",
        "registry.hub.docker.com",
        "*.docker.io"
      ]
    }

    rule {
      name = "AllowAzureServices"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = ["10.0.0.0/8"]
      destination_fqdns = [
        "*.azure.com",
        "*.microsoft.com",
        "*.windows.net"
      ]
    }
  }

  network_rule_collection {
    name     = "AllowDNS"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "AllowDNS"
      protocols             = ["UDP"]
      source_addresses      = ["10.0.0.0/8"]
      destination_addresses = ["*"]
      destination_ports     = ["53"]
    }
  }
}

# Azure Firewall
resource "azurerm_firewall" "firewall" {
  name                = local.firewall_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku
  firewall_policy_id  = azurerm_firewall_policy.policy.id
  tags                = var.tags

  ip_configuration {
    name                 = "firewallIpConfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

# Bastion Public IP
resource "azurerm_public_ip" "bastion" {
  name                = local.bastion_pip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Azure Bastion
resource "azurerm_bastion_host" "bastion" {
  name                = local.bastion_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  ip_configuration {
    name                 = "bastionIpConfig"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  file_copy_enabled     = true
  tunneling_enabled     = true
}

# Private DNS Zones
locals {
  private_dns_zones = [
    "privatelink.vaultcore.azure.net",
    "privatelink.blob.core.windows.net",
    "privatelink.file.core.windows.net",
    "privatelink.queue.core.windows.net",
    "privatelink.table.core.windows.net",
    "privatelink.database.windows.net",
    "privatelink.documents.azure.com",
    "privatelink.azurecr.io",
    "privatelink.postgres.database.azure.com",
    "privatelink.mysql.database.azure.com",
    "privatelink.redis.cache.windows.net"
  ]
}

resource "azurerm_private_dns_zone" "zones" {
  for_each            = toset(local.private_dns_zones)
  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_links" {
  for_each              = toset(local.private_dns_zones)
  name                  = "${each.value}-link-hub"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.value].name
  virtual_network_id    = azurerm_virtual_network.hub.id
  tags                  = var.tags
}

# Outputs
output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "firewall_private_ip" {
  value = azurerm_firewall.firewall.ip_configuration[0].private_ip_address
}

output "firewall_id" {
  value = azurerm_firewall.firewall.id
}

output "bastion_id" {
  value = azurerm_bastion_host.bastion.id
}

output "private_dns_zone_ids" {
  value = { for k, v in azurerm_private_dns_zone.zones : k => v.id }
}
