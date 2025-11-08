# Terraform Backend Configuration
# State storage in Azure Storage Account
# Uses OIDC authentication (no access keys)

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-verdaio-eastus2-01"
    storage_account_name = "stvrdtfstateeus201"
    container_name       = "tfstate"
    key                  = "saas202544/${var.env}/terraform.tfstate"

    # Use OIDC authentication (no access keys required)
    use_oidc = true

    # Subscription and tenant for state storage
    subscription_id = "b3fc75c0-c060-4a53-a7cf-5f6ae22fefec"
    tenant_id       = "04c5f804-d3ee-4b0b-b7fa-772496bb7a34"
  }
}

# State locking and consistency features
# Automatically handled by azurerm backend with blob leases
