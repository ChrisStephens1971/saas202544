# Azure Naming Module
# Generates Azure resource names following Verdaio naming standard v1.1

variable "org" {
  description = "Organization code (2-4 chars)"
  type        = string
  validation {
    condition     = length(var.org) >= 2 && length(var.org) <= 4
    error_message = "Org code must be 2-4 characters."
  }
}

variable "project" {
  description = "Project code (2-5 chars)"
  type        = string
  validation {
    condition     = length(var.project) >= 2 && length(var.project) <= 5
    error_message = "Project code must be 2-5 characters."
  }
}

variable "env" {
  description = "Environment"
  type        = string
  validation {
    condition     = contains(["prd", "stg", "dev", "tst", "sbx"], var.env)
    error_message = "Environment must be prd, stg, dev, tst, or sbx."
  }
}

variable "region" {
  description = "Azure region short code"
  type        = string
}

variable "location" {
  description = "Azure region full name"
  type        = string
}

variable "owner" {
  description = "Owner email"
  type        = string
}

variable "cost_center" {
  description = "Cost center"
  type        = string
}

variable "data_sensitivity" {
  description = "Data sensitivity level"
  type        = string
  default     = "internal"
  validation {
    condition     = contains(["public", "internal", "confidential", "regulated"], var.data_sensitivity)
    error_message = "Data sensitivity must be public, internal, confidential, or regulated."
  }
}

variable "compliance" {
  description = "Compliance requirements"
  type        = string
  default     = "none"
  validation {
    condition     = contains(["none", "pci", "hipaa", "sox", "gdpr"], var.compliance)
    error_message = "Compliance must be none, pci, hipaa, sox, or gdpr."
  }
}

variable "business_unit" {
  description = "Business unit (optional)"
  type        = string
  default     = null
}

variable "application" {
  description = "Application name (optional)"
  type        = string
  default     = null
}

locals {
  name_prefix = "${var.org}-${var.project}-${var.env}-${var.region}"

  common_tags = merge(
    {
      Org             = var.org
      Project         = var.project
      Environment     = var.env
      Region          = var.region
      Owner           = var.owner
      CostCenter      = var.cost_center
      DataSensitivity = var.data_sensitivity
      Compliance      = var.compliance
      CreatedDate     = formatdate("YYYY-MM-DD", timestamp())
      ManagedBy       = "terraform"
    },
    var.business_unit != null ? { BusinessUnit = var.business_unit } : {},
    var.application != null ? { Application = var.application } : {}
  )
}

# Outputs for resource naming
output "name_prefix" {
  description = "Common name prefix"
  value       = local.name_prefix
}

output "resource_group_name" {
  description = "Resource group name pattern"
  value       = "rg-${local.name_prefix}"
}

output "app_service_plan_name" {
  description = "App Service Plan name"
  value       = "asp-${local.name_prefix}"
}

output "app_service_name" {
  description = "App Service name pattern (add sequence)"
  value       = "app-${local.name_prefix}"
}

output "function_app_name" {
  description = "Function App name pattern (add sequence)"
  value       = "func-${local.name_prefix}"
}

output "storage_account_name" {
  description = "Storage account name pattern (add sequence, no hyphens)"
  value       = "st${var.org}${var.project}${var.env}${var.region}"
}

output "key_vault_name" {
  description = "Key Vault name pattern (add sequence)"
  value       = "kv-${local.name_prefix}"
}

output "container_registry_name" {
  description = "Container Registry name (no hyphens)"
  value       = "acr${var.org}${var.project}${var.env}${var.region}"
}

output "sql_server_name" {
  description = "SQL Server name"
  value       = "sqlsvr-${local.name_prefix}"
}

output "sql_database_name" {
  description = "SQL Database name pattern (add database name)"
  value       = "sqldb-${local.name_prefix}"
}

output "cosmos_db_name" {
  description = "Cosmos DB account name"
  value       = "cosmos-${local.name_prefix}"
}

output "redis_cache_name" {
  description = "Redis Cache name pattern (add sequence)"
  value       = "redis-${local.name_prefix}"
}

output "service_bus_name" {
  description = "Service Bus namespace name"
  value       = "sb-${local.name_prefix}"
}

output "event_hub_name" {
  description = "Event Hub namespace name"
  value       = "eh-${local.name_prefix}"
}

output "log_analytics_name" {
  description = "Log Analytics workspace name"
  value       = "la-${local.name_prefix}"
}

output "app_insights_name" {
  description = "Application Insights name"
  value       = "appi-${local.name_prefix}"
}

output "vnet_name" {
  description = "Virtual Network name"
  value       = "vnet-${local.name_prefix}"
}

output "subnet_name" {
  description = "Subnet name pattern (add purpose)"
  value       = "snet-${local.name_prefix}"
}

output "nsg_name" {
  description = "Network Security Group name pattern (add purpose)"
  value       = "nsg-${local.name_prefix}"
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = "aks-${local.name_prefix}"
}

output "common_tags" {
  description = "Common tags to apply to all resources"
  value       = local.common_tags
}

output "location" {
  description = "Azure location"
  value       = var.location
}
