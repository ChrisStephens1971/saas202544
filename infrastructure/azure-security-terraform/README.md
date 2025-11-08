# Azure Security Baseline - Terraform Modules

**Version:** 1.0
**Last Updated:** 2025-11-05
**Part of:** Azure Security Playbook (Zero-to-Production) v2.0

---

## Overview

This directory contains Terraform modules for deploying the Azure security baseline. These modules are reference implementations - **we recommend using the Bicep modules** (`azure-security-bicep/`) for production deployments as they are more feature-complete and better maintained by Microsoft.

**Why Terraform modules are included:**
- Compatibility with existing Terraform infrastructure
- Multi-cloud orchestration scenarios
- Organizations with Terraform-first policies

**For production use, we recommend:**
- **Bicep** for Azure-native deployments (see `../azure-security-bicep/`)
- **Terraform** only if you have strong organizational requirements

---

## Available Modules

| Module | Purpose | Status |
|--------|---------|--------|
| **management-groups** | Creates MG hierarchy | ✅ Complete |
| **hub-network** | Hub VNet with Firewall + Bastion | ✅ Complete |

**Note:** Additional modules (spoke network, policies, defender, logging) are best deployed using Bicep. See the Bicep directory for complete implementations.

---

## Quick Start

### Prerequisites

```bash
# Install Terraform
brew install terraform  # macOS
# or download from https://www.terraform.io/downloads

# Verify installation
terraform version

# Azure CLI authentication
az login
az account set --subscription <subscription-id>
```

### Deployment Example

#### 1. Management Groups

```hcl
# main.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "management_groups" {
  source   = "./modules/security-baseline/management-groups"
  org_code = "vrd"
  products = ["tmt", "hoa"]
}

output "platform_mg_id" {
  value = module.management_groups.platform_mg_id
}
```

```bash
terraform init
terraform plan
terraform apply
```

#### 2. Hub Network

```hcl
# hub.tf
resource "azurerm_resource_group" "network" {
  name     = "rg-vrd-platform-prd-eus2-net"
  location = "eastus2"
}

module "hub_network" {
  source              = "./modules/security-baseline/hub-network"
  org                 = "vrd"
  env                 = "prd"
  region              = "eus2"
  location            = "eastus2"
  resource_group_name = azurerm_resource_group.network.name
  firewall_sku        = "Premium"
  enable_ddos         = true

  tags = {
    Org         = "vrd"
    Environment = "prd"
    DeployedBy  = "Terraform"
  }
}

output "firewall_ip" {
  value = module.hub_network.firewall_private_ip
}
```

```bash
terraform init
terraform plan
terraform apply
```

---

## Module Details

### Management Groups Module

**Path:** `modules/security-baseline/management-groups/main.tf`

**Variables:**
- `org_code` (required) - Organization code (2-4 chars)
- `products` (optional) - List of product names

**Outputs:**
- `platform_mg_id` - Platform MG ID
- `corp_mg_id` - Corporate MG ID
- `sandbox_mg_id` - Sandbox MG ID
- `products_mg_id` - Products MG ID
- `prod_mg_ids` - Map of production MG IDs
- `nonprod_mg_ids` - Map of non-production MG IDs

**Example:**
```hcl
module "mgs" {
  source   = "./modules/security-baseline/management-groups"
  org_code = "vrd"
  products = ["tmt", "hoa", "myapp"]
}
```

---

### Hub Network Module

**Path:** `modules/security-baseline/hub-network/main.tf`

**Variables:**
- `org` (required) - Organization code
- `env` (required) - Environment (dev, tst, prd)
- `region` (required) - Region short code (eus2, wus2)
- `location` (required) - Azure location (eastus2, westus2)
- `resource_group_name` (required) - RG name
- `hub_vnet_address_space` (optional) - Default: ["10.0.0.0/16"]
- `firewall_subnet_prefix` (optional) - Default: "10.0.1.0/24"
- `bastion_subnet_prefix` (optional) - Default: "10.0.2.0/24"
- `firewall_sku` (optional) - Standard or Premium (default: Premium)
- `enable_ddos` (optional) - Default: true
- `tags` (optional) - Resource tags

**Outputs:**
- `hub_vnet_id` - Hub VNet ID
- `hub_vnet_name` - Hub VNet name
- `firewall_private_ip` - Firewall private IP
- `firewall_id` - Firewall resource ID
- `bastion_id` - Bastion resource ID
- `private_dns_zone_ids` - Map of Private DNS zone IDs

**Cost Estimate:**
- Dev: ~$600/month (Standard firewall, no DDoS)
- Production: ~$4,200/month (Premium firewall + DDoS)

---

## Why We Recommend Bicep for Azure

### Advantages of Bicep over Terraform for Azure

1. **Native Azure support** - First-class citizen, same-day API coverage
2. **No state file** - Azure Resource Manager tracks state
3. **Better type safety** - Compile-time validation
4. **Simpler syntax** - Less boilerplate than Terraform
5. **What-if deployments** - Preview changes before apply
6. **Microsoft support** - Official support from Azure team

### When to Use Terraform

1. **Multi-cloud** - Managing AWS, GCP, and Azure together
2. **Existing codebase** - Already using Terraform extensively
3. **Team expertise** - Team strongly prefers Terraform
4. **Third-party integrations** - Need Terraform providers for other services

---

## Migration from Terraform to Bicep

If you want to migrate existing Terraform to Bicep:

```bash
# 1. Export current state
terraform state pull > terraform.tfstate

# 2. Use Azure Resource Manager to import
az deployment group create \
  --resource-group <rg> \
  --template-file <bicep-file> \
  --mode Incremental  # Don't delete existing resources

# 3. Validate Bicep matches Terraform state
az deployment group what-if \
  --resource-group <rg> \
  --template-file <bicep-file>

# 4. Once validated, destroy Terraform state
terraform destroy  # Only after Bicep is managing resources
```

---

## Limitations of These Terraform Modules

**Not included (use Bicep instead):**
- Spoke network module
- Azure Policy assignments
- Microsoft Defender for Cloud
- Log Analytics + Sentinel
- Monitoring dashboards

**Reason:** These are better handled by Bicep due to:
- Complex policy identity management
- Defender for Cloud API nuances
- Sentinel connectors and analytics rules
- Azure-specific features not well-supported in Terraform

---

## Recommended Hybrid Approach

**Use Terraform for:**
- Management group hierarchy (one-time setup)
- Multi-cloud orchestration
- External integrations (GitHub, Datadog, etc.)

**Use Bicep for:**
- Network infrastructure (hub-spoke)
- Security policies
- Defender for Cloud
- Logging and monitoring
- All day-to-day Azure resources

**Example workflow:**
```bash
# 1. Create MGs with Terraform (once)
terraform apply -target=module.management_groups

# 2. Deploy security baseline with Bicep
az deployment sub create --template-file azure-security-bicep/main.bicep

# 3. Manage workloads with Bicep
az deployment group create --template-file app.bicep
```

---

## State Management

### Terraform Backend Configuration

**Recommended:** Azure Storage for remote state

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstatevrd01"
    container_name       = "tfstate"
    key                  = "security-baseline.tfstate"
  }
}
```

**Setup:**
```bash
# Create state storage
az group create --name rg-terraform-state --location eastus2

az storage account create \
  --name sttfstatevrd01 \
  --resource-group rg-terraform-state \
  --sku Standard_LRS \
  --encryption-services blob

az storage container create \
  --name tfstate \
  --account-name sttfstatevrd01
```

---

## CI/CD Integration

### GitHub Actions

```yaml
name: Deploy Security Baseline
on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Azure Login (OIDC)
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.6.0

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve tfplan
```

---

## Troubleshooting

### Common Issues

**1. Provider version conflicts**
```bash
# Solution: Lock provider version
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 3.80.0"  # Lock to specific version
    }
  }
}
```

**2. Authentication failures**
```bash
# Solution: Clear cached credentials
az logout
az login
az account set --subscription <subscription-id>
```

**3. State lock errors**
```bash
# Solution: Force unlock (use with caution)
terraform force-unlock <lock-id>
```

**4. Management group conflicts**
```bash
# Solution: Import existing MGs
terraform import azurerm_management_group.platform /providers/Microsoft.Management/managementGroups/mg-vrd-platform
```

---

## Additional Resources

- **Bicep Modules (Recommended):** `../azure-security-bicep/`
- **Azure Security Playbook v2.0:** `../azure-security-zero-to-prod-v2.md`
- **Incident Response Runbooks:** `../azure-security-runbooks/`
- **Terraform Azure Provider:** https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- **Bicep Documentation:** https://learn.microsoft.com/azure/azure-resource-manager/bicep/

---

## Next Steps

1. **Evaluate** whether Terraform or Bicep is right for your organization
2. **Deploy** management groups with Terraform (if chosen)
3. **Switch to Bicep** for network and security baseline
4. **Follow** Azure Security Playbook v2.0 for complete implementation
5. **Test** with incident response runbooks

---

**Version:** 1.0 (Reference Implementation)
**Status:** Production-Ready (Limited Scope)
**Recommendation:** Use Bicep modules for full feature set
**Last Updated:** 2025-11-05
