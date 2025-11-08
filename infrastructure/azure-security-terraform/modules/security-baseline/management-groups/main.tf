# Azure Management Group Hierarchy
# Part of: Azure Security Playbook v2.0
# Purpose: Create management group hierarchy for organization

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

variable "org_code" {
  description = "Organization code (2-4 chars)"
  type        = string
  validation {
    condition     = length(var.org_code) >= 2 && length(var.org_code) <= 4
    error_message = "Organization code must be 2-4 characters."
  }
}

variable "products" {
  description = "Product names to create management groups for"
  type        = list(string)
  default     = []
}

# Platform management group
resource "azurerm_management_group" "platform" {
  display_name = "Platform"
  name         = "mg-${var.org_code}-platform"
}

# Corporate management group
resource "azurerm_management_group" "corp" {
  display_name = "Corporate"
  name         = "mg-${var.org_code}-corp"
}

# Sandbox management group
resource "azurerm_management_group" "sandbox" {
  display_name = "Sandbox"
  name         = "mg-${var.org_code}-sandbox"
}

# Products management group
resource "azurerm_management_group" "products" {
  display_name = "Products"
  name         = "mg-${var.org_code}-products"
}

# Per-product production management groups
resource "azurerm_management_group" "prod" {
  for_each     = toset(var.products)
  display_name = "Production - ${each.value}"
  name         = "mg-${var.org_code}-prod-${each.value}"
  parent_management_group_id = azurerm_management_group.products.id
}

# Per-product non-production management groups
resource "azurerm_management_group" "nonprod" {
  for_each     = toset(var.products)
  display_name = "Non-Production - ${each.value}"
  name         = "mg-${var.org_code}-nonprod-${each.value}"
  parent_management_group_id = azurerm_management_group.products.id
}

# Outputs
output "platform_mg_id" {
  value = azurerm_management_group.platform.id
}

output "corp_mg_id" {
  value = azurerm_management_group.corp.id
}

output "sandbox_mg_id" {
  value = azurerm_management_group.sandbox.id
}

output "products_mg_id" {
  value = azurerm_management_group.products.id
}

output "prod_mg_ids" {
  value = { for k, v in azurerm_management_group.prod : k => v.id }
}

output "nonprod_mg_ids" {
  value = { for k, v in azurerm_management_group.nonprod : k => v.id }
}
