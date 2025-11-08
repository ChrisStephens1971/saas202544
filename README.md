# Azure SaaS Project Template

**Template Type:** Azure-Specific SaaS Project
**Version:** 1.0
**Last Updated:** 2025-11-05

---

## Overview

This template provides a complete Azure-specific SaaS project structure with:

- **Azure Naming Standard v1.1** - Comprehensive naming and tagging conventions
- **Infrastructure as Code** - Both Terraform and Bicep support
- **Automation Scripts** - Name generation, validation, and tag management
- **CI/CD Pipelines** - GitHub Actions and Azure DevOps templates
- **Azure Policy** - Enforcement of naming and tagging standards
- **Multi-Region Support** - DR and HA patterns included

---

## What's Included

### 1. Azure Naming Standard
- **Location:** `technical/azure-naming-standard.md`
- **Features:**
  - Comprehensive naming patterns for 35+ Azure services
  - Service-specific length constraints and rules
  - Global uniqueness handling strategies
  - Multi-region naming patterns
  - Tag standard with required and recommended tags
  - Azure Policy enforcement examples
  - Resource Graph queries for compliance checking

### 2. Automation Scripts
- **Location:** `C:\devop\.template-system\scripts\`
- **Scripts:**
  - `azure-name-generator.py` - Generate resource names
  - `azure-name-validator.py` - Validate names against standard
  - `azure-tag-generator.py` - Generate tags for IaC tools

### 3. Infrastructure as Code

#### Terraform
- **Location:** `infrastructure/terraform/`
- **Includes:**
  - Naming convention module
  - Resource group structure (app, data, net)
  - Virtual networking with subnets and NSGs
  - Log Analytics and Application Insights
  - Key Vault
  - Environment-specific tfvars files

#### Bicep
- **Location:** `infrastructure/bicep/`
- **Includes:**
  - Naming convention module
  - Subscription-level deployment
  - Modular resource templates
  - Environment-specific parameters

### 4. CI/CD Pipelines

#### GitHub Actions
- **Location:** `.github/workflows/`
- **Workflows:**
  - Terraform plan on PR
  - Terraform apply on merge
  - Azure naming validation
  - Bicep deployment

#### Azure DevOps
- **Location:** `infrastructure/pipelines/`
- **Pipelines:**
  - Main Azure pipeline
  - Terraform pipeline
  - Bicep pipeline

### 5. Documentation
- **Location:** `technical/`, `docs/`
- **Includes:**
  - Azure naming standard
  - Architecture documentation templates
  - Security best practices
  - IaC documentation

---

## Getting Started

### Prerequisites

1. **Azure CLI** installed and authenticated
2. **Terraform** >= 1.5 (if using Terraform)
3. **Bicep** CLI (if using Bicep)
4. **Python 3.8+** for automation scripts
5. **Git** initialized repository

### Initial Setup

1. **Review Azure Configuration**
   ```bash
   # Check CLAUDE.md for:
   # - Azure Org code (vrd)
   # - Project code (202544)
   # - Primary/Secondary regions
   ```

2. **Generate Resource Names**
   ```bash
   python C:/devop/.template-system/scripts/azure-name-generator.py \
     --type app \
     --org vrd \
     --proj tmt \
     --env dev \
     --region eus2 \
     --seq 01
   ```

3. **Configure Terraform** (if using)
   ```bash
   cd infrastructure/terraform

   # Copy environment file
   cp environments/dev.tfvars.example environments/dev.tfvars

   # Edit variables
   nano environments/dev.tfvars

   # Initialize
   terraform init

   # Plan
   terraform plan -var-file="environments/dev.tfvars"
   ```

4. **Configure Bicep** (if using)
   ```bash
   cd infrastructure/bicep

   # Copy parameters
   cp environments/dev.parameters.example.json environments/dev.parameters.json

   # Edit parameters
   nano environments/dev.parameters.json

   # Deploy
   az deployment sub create \
     --location eastus2 \
     --template-file main.bicep \
     --parameters @environments/dev.parameters.json
   ```

---

## Azure Naming Quick Reference

### Pattern
```
{type}-{org}-{proj}-{env}-{region}-{slice}-{seq}
```

### Examples
```
rg-vrd-tmt-prd-eus2-app           # Resource Group
app-vrd-tmt-prd-eus2-01           # App Service
func-vrd-tmt-prd-eus2-01          # Function App
stvrdtmtprdeus201                 # Storage (no hyphens)
kv-vrd-tmt-prd-eus2-01            # Key Vault
sqlsvr-vrd-tmt-prd-eus2           # SQL Server
cosmos-vrd-tmt-prd-eus2           # Cosmos DB
vnet-vrd-tmt-prd-eus2             # Virtual Network
snet-vrd-tmt-prd-eus2-app         # Subnet
```

### Required Tags
```
Org, Project, Environment, Region, Owner, CostCenter
```

---

## Project Structure

```
saas-project-azure/
├── CLAUDE.md                    # Claude instructions (Azure-specific)
├── README.md                    # This file
├── .gitignore                   # Git ignore patterns
│
├── technical/                   # Technical documentation
│   ├── azure-naming-standard.md
│   ├── azure-architecture.md
│   └── azure-security.md
│
├── infrastructure/              # Infrastructure as Code
│   ├── terraform/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── modules/
│   │   │   └── naming/
│   │   └── environments/
│   │       ├── dev.tfvars
│   │       ├── stg.tfvars
│   │       └── prd.tfvars
│   │
│   ├── bicep/
│   │   ├── main.bicep
│   │   ├── modules/
│   │   │   ├── naming.bicep
│   │   │   ├── key-vault.bicep
│   │   │   └── vnet.bicep
│   │   └── environments/
│   │       ├── dev.parameters.json
│   │       ├── stg.parameters.json
│   │       └── prd.parameters.json
│   │
│   ├── policies/                # Azure Policy definitions
│   │   ├── rg-naming-policy.json
│   │   ├── required-tags-policy.json
│   │   └── tag-inheritance-policy.json
│   │
│   └── pipelines/               # Azure DevOps pipelines
│       ├── azure-pipelines.yml
│       ├── terraform-pipeline.yml
│       └── bicep-pipeline.yml
│
├── .github/workflows/           # GitHub Actions
│   ├── terraform-plan.yml
│   ├── terraform-apply.yml
│   ├── azure-validation.yml
│   └── bicep-deploy.yml
│
└── docs/                        # Additional documentation
    ├── architecture/
    ├── security/
    └── operations/
```

---

## Common Tasks

### Generate a Resource Name
```bash
python C:/devop/.template-system/scripts/azure-name-generator.py \
  --type <resource-type> \
  --org vrd \
  --proj 202544 \
  --env <environment> \
  --region eus2 \
  --seq 01
```

### Validate a Resource Name
```bash
python C:/devop/.template-system/scripts/azure-name-validator.py \
  --name "app-vrd-tmt-prd-eus2-01"
```

### Generate Tags
```bash
python C:/devop/.template-system/scripts/azure-tag-generator.py \
  --org vrd \
  --proj 202544 \
  --env prd \
  --region eus2 \
  --owner ops@verdaio.com \
  --cost-center 202544-llc \
  --format terraform
```

### Deploy Infrastructure (Terraform)
```bash
cd infrastructure/terraform
terraform init
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

### Deploy Infrastructure (Bicep)
```bash
cd infrastructure/bicep
az deployment sub create \
  --location eastus2 \
  --template-file main.bicep \
  --parameters @environments/dev.parameters.json
```

---

## Best Practices

1. **Always Validate Names** - Use validation scripts before deploying
2. **Use IaC Modules** - Leverage naming modules for consistency
3. **Tag Everything** - Apply tags at resource group level for inheritance
4. **Test in Dev First** - Always deploy to dev environment first
5. **Review Policies** - Understand Azure Policy enforcement before deploying
6. **Document Exceptions** - Use `infrastructure/EXCEPTIONS.md` for deviations
7. **Cost Management** - Review tags for cost allocation accuracy

---

## Multi-Region Deployment

For HA/DR scenarios:

1. **Update Variables** - Set primary and secondary regions
2. **Deploy Primary** - Deploy all resources to primary region
3. **Deploy Secondary** - Deploy to secondary region with `-secondary` suffix
4. **Configure Replication** - Set up geo-replication for data services
5. **Add Traffic Manager** - Configure global load balancing
6. **Tag Resources** - Add `RegionRole` and `PairedRegion` tags

---

## Troubleshooting

### Name Too Long
- Review service-specific length constraints in `azure-naming-standard.md`
- Shorten org or project codes
- Use abbreviated slice names

### Name Already Exists (Globally Unique Services)
- Increment sequence number (01 → 02)
- Check naming module outputs
- Verify naming pattern matches standard

### Policy Violations
- Run validation scripts before deploying
- Check required tags are present
- Review Azure Policy assignments
- Check `EXCEPTIONS.md` for documented deviations

### Tag Inheritance Not Working
- Verify Azure Policy is assigned
- Check resource group has tags
- Review policy compliance in Azure Portal
- Allow time for policy evaluation (5-15 minutes)

---

## Support

**Questions?**
- Review `technical/azure-naming-standard.md`
- Check CLAUDE.md for project-specific instructions
- Contact platform team: ops@verdaio.com

**Found an Issue?**
- Submit PR to improve templates
- Update `EXCEPTIONS.md` for deviations
- Document learnings in `docs/`

---

**Template Version:** 1.0 (Azure)
**Naming Standard Version:** 1.1
**Last Updated:** 2025-11-05
