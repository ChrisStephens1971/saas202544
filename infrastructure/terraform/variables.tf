# Terraform Variables
# Azure SaaS Project: saas202544

variable "org" {
  description = "Organization code (2-4 chars)"
  type        = string
  default     = "vrd"
}

variable "project" {
  description = "Project code (2-5 chars)"
  type        = string
  default     = "202544"
}

variable "env" {
  description = "Environment (prd, stg, dev, tst, sbx)"
  type        = string
}

variable "region" {
  description = "Azure region short code"
  type        = string
  default     = "eus2"
}

variable "location" {
  description = "Azure region full name"
  type        = string
}

variable "owner" {
  description = "Owner email"
  type        = string
  default     = "ops@verdaio.com"
}

variable "cost_center" {
  description = "Cost center"
  type        = string
  default     = "202544-llc"
}

variable "data_sensitivity" {
  description = "Data sensitivity level"
  type        = string
  default     = "internal"
}

variable "compliance" {
  description = "Compliance requirements"
  type        = string
  default     = "none"
}

variable "business_unit" {
  description = "Business unit (optional)"
  type        = string
  default     = null
}

variable "application" {
  description = "Application name (optional)"
  type        = string
  default     = "saas202544"
}

variable "proj" {
  description = "Project identifier (saasYYYYMM format)"
  type        = string
  default     = "saas202544"
}

variable "seq" {
  description = "Resource sequence number"
  type        = string
  default     = "01"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    org    = "verdaio"
    proj   = "saas202544"
    env    = "dev"
    region = "eastus2"
    owner  = "chris.stephens@verdaio.com"
  }
}
