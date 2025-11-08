# CLAUDE.md - Azure SaaS Project

**Project:** saas202544
**Created:** 2025-11-08
**Template:** Azure (azure)
**Platform:** Microsoft Azure
**Path:** C:\devop\saas202544

---

## ⚙️ Available Tools: Built-in vs. Installable

**IMPORTANT:** Understand what's available without installation!

### ✅ Built-in Tools (Always Available - No Installation)

These are **ALWAYS** available in every Claude Code session:

**Core Operations:**
- Read, Write, Edit - File operations
- Glob, Grep - Search and find files
- Bash - Execute commands
- WebSearch, WebFetch - Research capabilities

**Specialized Task Agents (Built-in!):**
- **Task tool with subagent_type** - Launches specialized agents
  - `Explore` - Fast codebase exploration
  - `Plan` - Fast planning and analysis
  - `general-purpose` - Multi-step complex tasks

**⚠️ CRITICAL:** Task tool's Explore/Plan agents are **BUILT-IN**. They do NOT require installation!

### 📦 Optional Extensions (Require Installation)

Install these **ONLY when needed**:

**Claude Skills** - Document processing
- xlsx, docx, pdf, skill-creator
- Install: `/plugin add xlsx`

**WSHobson Agents** - Framework specialists
- python-development, react-typescript, full-stack-orchestration
- Install: `/plugin install full-stack-orchestration`

**Claude Code Templates** - Role-based workflows
- frontend-developer, backend-architect, test-engineer
- Install: `npx claude-code-templates@latest --agent [name]`

**See:** `BUILT-IN-VS-INSTALLABLE.md` for complete breakdown

**When to install extensions?** Only during development phase, NOT for planning!

---

## 🎯 Project Overview

This is an **Azure-specific SaaS project** using the Verdaio Azure naming standard v1.2.

**Azure Configuration:**
- **Organization:** vrd
- **Project Code:** 202544
- **Primary Region:** eus2
- **Secondary Region:** wus2
- **Multi-Tenant:** false
- **Tenant Model:** single

---

## 📋 Azure Naming Standard

This project follows the **Verdaio Azure Naming & Tagging Standard v1.2** with projectID-based codes.

**Pattern:** `{type}-{org}-{proj}-{env}-{region}-{slice}-{seq}`

**Example Resources:**
```
# Resource Groups
rg-vrd-202544-prd-eus2-app
rg-vrd-202544-prd-eus2-data

# App Services
app-vrd-202544-prd-eus2-01
func-vrd-202544-prd-eus2-01

# Data Services
sqlsvr-vrd-202544-prd-eus2
cosmos-vrd-202544-prd-eus2
redis-vrd-202544-prd-eus2-01

# Storage & Secrets
stvrd202544prdeus201
kv-vrd-202544-prd-eus2-01
```

**Full Documentation:** See `technical/azure-naming-standard.md`

---

## 🔧 Azure Automation Scripts

Located in `C:\devop\.template-system\scripts\`:

### Generate Resource Names
```bash
python C:/devop/.template-system/scripts/azure-name-generator.py \
  --type app \
  --org vrd \
  --proj 202544 \
  --env prd \
  --region eus2 \
  --seq 01
```

### Validate Resource Names
```bash
python C:/devop/.template-system/scripts/azure-name-validator.py \
  --name "app-vrd-202544-prd-eus2-01"
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

---

## 🔒 Azure Security Baseline

This project includes the **Azure Security Playbook v2.0** - a comprehensive zero-to-production security implementation.

### Security Resources

**📘 Core Documentation:**
- `technical/azure-security-zero-to-prod-v2.md` - Complete security playbook (Days 0-9)
- `azure-security-baseline-checklist.csv` - 151-task tracking checklist

**🚨 Incident Response Runbooks:**
- `azure-security-runbooks/` - 5 detailed incident response procedures
  - credential-leak-response.md (MTTR: 15 min)
  - exposed-storage-response.md (MTTR: 30 min)
  - suspicious-consent-response.md (MTTR: 20 min)
  - ransomware-response.md (MTTR: Immediate)
  - privilege-escalation-response.md (MTTR: 30 min)

**🏗️ Security Baseline IaC:**
- `infrastructure/azure-security-bicep/` - Production-ready Bicep modules (Recommended)
  - Management groups, hub network, spoke network, policies, Defender, logging
  - Deploy complete baseline: `az deployment sub create --template-file azure-security-bicep/main.bicep`
- `infrastructure/azure-security-terraform/` - Terraform reference modules

### Quick Start: Deploy Security Baseline

```bash
# Deploy complete security infrastructure (30-45 min)
cd infrastructure/azure-security-bicep

az deployment sub create \
  --location eastus2 \
  --template-file main.bicep \
  --parameters \
    org=vrd \
    proj=202544 \
    env=prd \
    primaryRegion=eus2 \
    enableDDoS=true \
    firewallSku=Premium
```

**What gets deployed:**
- ✅ Hub network (Firewall Premium + DDoS + Bastion)
- ✅ Spoke network with NSGs and private subnets
- ✅ Log Analytics + Azure Sentinel
- ✅ Microsoft Defender for Cloud (all plans)
- ✅ Azure Policies for governance
- ✅ Private DNS zones for Private Link

**Cost:** ~$5,000-6,000/month (production) | ~$1,000-1,500/month (dev/test)

---

## 🏗️ Infrastructure as Code

This project includes both **Terraform** and **Bicep** scaffolding.

### Terraform

Located in `infrastructure/terraform/`:

```bash
cd infrastructure/terraform

# Initialize
terraform init

# Plan
terraform plan -var-file="environments/dev.tfvars"

# Apply
terraform apply -var-file="environments/dev.tfvars"
```

**Key Files:**
- `main.tf` - Main infrastructure
- `variables.tf` - Variable definitions
- `outputs.tf` - Output values
- `modules/naming/` - Naming convention module
- `environments/*.tfvars` - Environment-specific variables

### Bicep

Located in `infrastructure/bicep/`:

```bash
cd infrastructure/bicep

# Deploy
az deployment group create \
  --resource-group rg-vrd-202544-dev-eus2-app \
  --template-file main.bicep \
  --parameters @environments/dev.parameters.json
```

**Key Files:**
- `main.bicep` - Main infrastructure
- `modules/naming.bicep` - Naming convention module
- `environments/*.parameters.json` - Environment-specific parameters

---

## 🚀 CI/CD Pipelines

### GitHub Actions

Workflows in `.github/workflows/`:

- `terraform-plan.yml` - Run Terraform plan on PR
- `terraform-apply.yml` - Apply Terraform on merge to main
- `azure-validation.yml` - Validate naming and tagging compliance
- `bicep-deploy.yml` - Deploy Bicep templates

### Azure DevOps

Pipeline templates in `infrastructure/pipelines/`:

- `azure-pipelines.yml` - Main pipeline
- `terraform-pipeline.yml` - Terraform-specific pipeline
- `bicep-pipeline.yml` - Bicep-specific pipeline

---

## 🏷️ Required Tags

All Azure resources must have these tags:

**Core Tags (Required):**
- `Org`: vrd
- `Project`: 202544
- `Environment`: prd|stg|dev|tst|sbx
- `Region`: eus2
- `Owner`: ops@verdaio.com
- `CostCenter`: 202544-llc

**Recommended Tags:**
- `DataSensitivity`: public|internal|confidential|regulated
- `Compliance`: none|pci|hipaa|sox|gdpr
- `DRTier`: rpo15m-rto4h
- `BackupRetention`: 7d|30d|90d|1y
- `ManagedBy`: terraform|bicep|arm

**Tags are automatically applied via IaC modules.**

---

## 🔐 Azure Secrets Management

### Key Vault Naming

```
kv-vrd-202544-{env}-eus2-01
```

### Secret Naming Convention

Format: `{service}-{purpose}-{env}`

Examples:
```
sqlsvr-connection-string-prd
storage-access-key-prd
api-client-secret-prd
cosmos-primary-key-prd
```

### Accessing Secrets in IaC

**Terraform:**
```hcl
data "azurerm_key_vault_secret" "db_connection" {
  name         = "sqlsvr-connection-string-prd"
  key_vault_id = azurerm_key_vault.main.id
}
```

**Bicep:**
```bicep
resource kv 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: 'kv-vrd-202544-prd-eus2-01'
}

output connectionString string = kv.getSecret('sqlsvr-connection-string-prd')
```

---

## 🌍 Multi-Region Architecture

**Primary Region:** eus2
**Secondary Region:** wus2

### DR Strategy

**Active-Passive (Recommended):**
```
# Primary
app-vrd-202544-prd-eus2-primary-01
sqlsvr-vrd-202544-prd-eus2-primary

# Secondary (DR)
app-vrd-202544-prd-wus2-secondary-01
sqlsvr-vrd-202544-prd-wus2-secondary
```

**Active-Active (Advanced):**
```
# Region 1
app-vrd-202544-prd-eus2-01

# Region 2
app-vrd-202544-prd-wus2-01
```

### Multi-Region Tags

Add these tags to multi-region resources:
- `RegionRole`: primary|secondary|dr|active
- `PairedRegion`: wus2

---

## 🔍 Azure Policy Enforcement

Azure Policies are deployed via IaC to enforce naming and tagging standards.

**Policies Included:**
1. **Resource Group Naming** - Denies RGs that don't match pattern
2. **Required Tags** - Denies resources without core tags
3. **Tag Inheritance** - Auto-inherits tags from RG to resources
4. **Naming Validation** - Audits resources with non-standard names

**Policy Location:** `infrastructure/policies/`

**Deploy Policies:**
```bash
# Terraform
cd infrastructure/terraform/policies
terraform apply

# Azure CLI
cd infrastructure/policies
az policy definition create --name "rg-naming" --rules rg-naming-policy.json
az policy assignment create --policy "rg-naming" --scope /subscriptions/{sub-id}
```

---

## 📊 Cost Management

### Cost Allocation

Resources are tagged with:
- `CostCenter`: 202544-llc
- `BusinessUnit`: (optional, set per resource)
- `Application`: saas202544

### Azure Cost Analysis Queries

**Cost by Environment:**
```kusto
Resources
| where tags['Project'] == '202544'
| extend env = tostring(tags['Environment'])
| summarize cost = sum(toint(tags['monthlyCost'])) by env
```

**Cost by Resource Type:**
```kusto
Resources
| where tags['Project'] == '202544'
| summarize cost = sum(toint(tags['monthlyCost'])) by type
| order by cost desc
```

### 💰 Automatic Cost Optimization (Dev/Staging)

**Save 60-70% on dev/staging costs with automatic resource deallocation!**

The template system includes automatic Azure cost optimization scripts that deallocate VMs and scale down resources after business hours.

**Quick Setup (15 minutes):**

```bash
# 1. Install Azure SDK
pip install azure-mgmt-compute azure-mgmt-web azure-mgmt-resource azure-identity

# 2. Authenticate
az login

# 3. Create configuration
cd C:\devop\.template-system\scripts
python create-deallocation-config.py --interactive

# 4. Test (dry run)
python azure-auto-deallocate.py --dry-run --force

# 5. View cost dashboard
python azure-cost-dashboard.py

# 6. Setup automation (PowerShell as Admin)
.\Setup-AzureDeallocationSchedule.ps1
```

**Features:**
- ✅ Automatic VM deallocation after 8pm weekdays, restart at 6am
- ✅ Full weekend shutdown (Friday 8pm → Monday 6am)
- ✅ Production protection (never touches production resources)
- ✅ Safety features (exclusion tags, snapshots, resource group exclusions)
- ✅ Real-time cost dashboard with multiple views
- ✅ Email reports and logging
- ✅ Windows Task Scheduler integration

**Expected Savings:**
- ~$47/month per project (60-70% reduction on dev/staging)
- ~$235/month for 5 dev projects
- ~$2,820/year savings

**Cost Dashboard:**
```bash
# Summary view
python azure-cost-dashboard.py

# Detailed view with all resources
python azure-cost-dashboard.py --detailed

# Export to CSV
python azure-cost-dashboard.py --export costs.csv
```

**Configuration:**
The auto-deallocation system uses `azure-auto-deallocate-config.json` which specifies:
- Subscription ID
- Resource groups to manage
- Deallocation schedule
- Safety settings
- Email notifications

**See:** `C:\devop\.template-system\AZURE-AUTO-COST-OPTIMIZATION.md` for complete setup guide and troubleshooting

---

## 🧪 Testing & Validation

### Pre-Deployment Validation

Run these checks before deploying:

```bash
# 1. Validate naming
python C:/devop/.template-system/scripts/azure-name-validator.py \
  --file infrastructure/resource-inventory.json

# 2. Validate Terraform
cd infrastructure/terraform
terraform validate
terraform fmt -check

# 3. Run Checkov (security/compliance)
checkov -d infrastructure/terraform

# 4. Validate Bicep
cd infrastructure/bicep
az bicep build --file main.bicep
```

### Post-Deployment Validation

```bash
# 1. Check deployed resources match naming standard
python C:/devop/.template-system/scripts/azure-name-validator.py \
  --subscription <subscription-id>

# 2. Verify tags
az resource list \
  --tag Project=202544 \
  --query "[].{name:name, tags:tags}" \
  -o table

# 3. Check policy compliance
az policy state list \
  --filter "complianceState eq 'NonCompliant'" \
  -o table
```

---

## 📚 Documentation

### Azure-Specific Docs

- `technical/azure-naming-standard.md` - Full naming standard
- `technical/azure-architecture.md` - Architecture diagrams
- `technical/azure-security.md` - Security best practices
- `infrastructure/README.md` - IaC documentation

### General Project Docs

- `product/` - Product planning
- `sprints/` - Sprint planning
- `technical/` - Technical documentation
- `business/` - Business planning

---

## 🤖 Virtual Agent: Azure Helper

**Trigger:** User mentions "azure", "deploy", "infrastructure", "terraform", "bicep"

### Common Azure Tasks

1. **"Generate Azure resource names"**
   - Use `azure-name-generator.py` script
   - Follow naming standard exactly
   - Validate with `azure-name-validator.py`

2. **"Create Terraform module"**
   - Use naming module template
   - Include common_tags locals
   - Validate names before creating resources

3. **"Deploy to Azure"**
   - Check environment (dev/stg/prd)
   - Validate naming and tagging
   - Run Terraform plan first
   - Get approval before apply

4. **"Check compliance"**
   - Run Azure Policy checks
   - Validate naming standard
   - Verify required tags present
   - Check cost allocation tags

5. **"Multi-region setup"**
   - Deploy to primary region first
   - Configure geo-replication
   - Set up Traffic Manager/Front Door
   - Add multi-region tags

---

## 🔗 Related Resources

**Azure Naming Tool:** `C:\devop\.template-system\scripts\azure-name-*.py`

**Terraform Registry:**
- [azurerm provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Naming module](https://registry.terraform.io/modules/Azure/naming/azurerm/latest)

**Microsoft Docs:**
- [Azure naming conventions](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging)
- [Azure Policy](https://learn.microsoft.com/en-us/azure/governance/policy/)
- [Bicep documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

---

## 🚨 Important Notes

1. **Never bypass naming standard** - All resources must follow the pattern
2. **Always tag resources** - Required tags must be present
3. **Validate before deploying** - Run validation scripts
4. **Document exceptions** - Use `infrastructure/EXCEPTIONS.md`
5. **Test in dev first** - Never deploy directly to production
6. **Use IaC modules** - Don't manually create resources
7. **Check costs regularly** - Review Azure Cost Management

---

**Template Version:** 1.0 (Azure)
**Last Updated:** 2025-11-08
