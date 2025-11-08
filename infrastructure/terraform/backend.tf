# Terraform Backend Configuration
# State storage in Azure Storage Account
# Uses Azure AD authentication (no access keys)
#
# NOTE: Backend config does not support variable interpolation.
# The key is set to dev by default. For stg/prd, use -backend-config:
#   terraform init -backend-config="key=saas202544/stg.tfstate"
#   terraform init -backend-config="key=saas202544/prd.tfstate"

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-verdaio-eastus2-01"
    storage_account_name = "stvrdtfstateeus201"
    container_name       = "tfstate"
    key                  = "saas202544/dev.tfstate"

    # Use Azure AD authentication (OIDC in GitHub Actions, az cli locally)
    use_azuread_auth = true
  }
}

# State locking and consistency features
# Automatically handled by azurerm backend with blob leases
