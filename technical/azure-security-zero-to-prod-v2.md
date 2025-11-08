# Azure Security Playbook (Zero-to-Production) — New Tenant Setup

**Version:** 2.0 (Best-in-Class Edition)
**Last Updated:** 2025-11-05
**Status:** Production-Ready

**Goal:** Stand up a brand-new Azure/Entra environment with sane defaults, strong guardrails, and clear ops rituals. This is a pragmatic, opinionated checklist that you can execute without already being an Azure expert.

**Who this is for:** You're starting from scratch. You'll run multiple products/LLCs, and you want each isolated with a repeatable security baseline.

**Integration:** This playbook integrates with the Verdaio Azure Naming Standard v1.1 and Azure template system.

---

## Table of Contents

1. [Principles](#principles)
2. [What You Need Before You Begin](#what-you-need-before-you-begin)
3. [Naming & Organization Standards](#naming--organization-standards)
4. [Cost Planning & Optimization](#cost-planning--optimization)
5. [Day 0: Create Tenant, Lock Identity](#day-0-create-tenant-lock-identity)
6. [Day 1: Management Groups, Subscriptions, Landing Zone](#day-1-management-groups-subscriptions-landing-zone)
7. [Day 2: Network Baseline (Hub/Spoke, Private Link)](#day-2-network-baseline-hubspoke-private-link)
8. [Day 3: Policy Guardrails](#day-3-policy-guardrails)
9. [Day 4: Logging, Monitoring, Sentinel](#day-4-logging-monitoring-sentinel)
10. [Day 5: Data, Keys, Secrets](#day-5-data-keys-secrets)
11. [Day 6: Workload Baselines (App Service, AKS, VMs)](#day-6-workload-baselines-app-service-aks-vms)
12. [Day 7: DevSecOps & Supply Chain](#day-7-devsecops--supply-chain)
13. [Day 8: Security Testing & Validation](#day-8-security-testing--validation)
14. [Day 9: Compliance Framework Mappings](#day-9-compliance-framework-mappings)
15. [Ongoing: Backup/DR, Incident Response, Audits](#ongoing-backupdr-incident-response-audits)
16. [Verification Checks (KQL)](#verification-checks-kql)
17. [Monitoring Dashboards & Workbooks](#monitoring-dashboards--workbooks)
18. [Appendix A: CLI/Bicep/Terraform Snippets](#appendix-a-clibicepterraform-snippets)
19. [Appendix B: Conditional Access Baseline](#appendix-b-conditional-access-baseline)
20. [Appendix C: Tagging & Metadata](#appendix-c-tagging--metadata)
21. [Appendix D: Incident Response Runbooks](#appendix-d-incident-response-runbooks)
22. [Appendix E: Infrastructure Modules Reference](#appendix-e-infrastructure-modules-reference)

---

## Principles

- **Least privilege by default.** No standing Global Admins. Elevate with PIM when needed.
- **Identity is the new perimeter.** Strong MFA for humans; managed identities for apps.
- **Private-first networking.** No public endpoints unless explicitly justified and tagged.
- **Everything is logged.** Diagnostic settings on every resource type.
- **Automate the guardrails.** Policy enforces your rules. Exceptions are documented and time-bound.
- **Prove it routinely.** Monthly drills for break-glass, restores, and failover.
- **Security is code.** All security configuration managed via IaC (Bicep/Terraform).
- **Compliance by design.** Built-in controls for SOC 2, ISO 27001, HIPAA, PCI-DSS.

---

## What You Need Before You Begin

- A primary domain you control (e.g., `verdaio.com`).
- Two FIDO2 hardware security keys for admins (YubiKey, Titan, etc.).
- A password manager and an offline vault (paper or hardware) for break-glass credentials.
- Billing method for Azure ($5,000-6,000/month budget per environment).
- Workstation with: Azure CLI, PowerShell 7+, and rights to install tools.
- Optional: Bicep CLI or Terraform for IaC deployment.

---

## Naming & Organization Standards

**IMPORTANT:** This playbook follows the **Verdaio Azure Naming Standard v1.1**.
See `azure-naming-standard.md` for complete naming conventions.

### Quick Reference

**Pattern:** `{type}-{org}-{proj}-{env}-{region}-{slice}-{seq}`

**Examples:**
```
# Resource Groups
rg-vrd-tmt-prd-eus2-app
rg-vrd-tmt-prd-eus2-data
rg-vrd-tmt-prd-eus2-net

# Compute & Runtime
app-vrd-tmt-prd-eus2-01
func-vrd-tmt-prd-eus2-01
aks-vrd-tmt-prd-eus2

# Data & Secrets
sqlsvr-vrd-tmt-prd-eus2
cosmos-vrd-tmt-prd-eus2
kv-vrd-tmt-prd-eus2-01
stvrdtmtprdeus201  # Storage (no hyphens)

# Networking
vnet-vrd-tmt-prd-eus2
snet-vrd-tmt-prd-eus2-app
nsg-vrd-tmt-prd-eus2-app
```

### Automation Scripts

Use the Verdaio automation scripts for name generation and validation:

```bash
# Generate resource name
python C:/devop/.template-system/scripts/azure-name-generator.py \
  --type app --org vrd --proj tmt --env prd --region eus2 --seq 01

# Validate resource name
python C:/devop/.template-system/scripts/azure-name-validator.py \
  --name "app-vrd-tmt-prd-eus2-01"

# Generate tags for Terraform/Bicep
python C:/devop/.template-system/scripts/azure-tag-generator.py \
  --org vrd --proj tmt --env prd --region eus2 \
  --owner ops@verdaio.com --cost-center tmt-llc \
  --format terraform
```

### Management Groups

```
Root (tenant)
├─ platform           # Shared infrastructure
├─ corp               # Corporate services (AD, email, etc.)
├─ sandbox            # Developer experimentation
└─ products           # Production workloads
   ├─ prod-<productA>
   ├─ prod-<productB>
   ├─ nonprod-<productA>
   └─ nonprod-<productB>
```

### Subscriptions (per product, per env)

Format: `{product}-{env}`
- `tmt-dev`, `tmt-test`, `tmt-prod`
- `hoa-dev`, `hoa-test`, `hoa-prod`

### Required Tags

See [Appendix C](#appendix-c-tagging--metadata) for complete tagging standard.

**Core tags:**
- `Org`, `Project`, `Environment`, `Region`, `Owner`, `CostCenter`

**Security tags:**
- `DataSensitivity`, `Compliance`, `DRTier`, `BackupRetention`

---

## Cost Planning & Optimization

### Estimated Monthly Costs (per environment)

| Component | SKU | Dev/Test | Production | Notes |
|-----------|-----|----------|------------|-------|
| **Hub VNet - Firewall** | Premium | $595 (Standard) | $1,250 | TLS inspection, IDPS |
| **Hub VNet - DDoS** | Standard | $0 (not needed) | $2,944 | Only for prod |
| **Spoke VNets** | Standard (x3) | $0 | $0 | Data charges only |
| **Application Gateway** | WAF_v2 | $125 | $250 | Autoscale based on traffic |
| **Bastion** | Standard | $0 (not deployed) | $146 | Only when needed |
| **Defender for Cloud** | Per resource | $100 | $500 | Varies by resource count |
| **Log Analytics** | Per GB ingested | $50 | $300 | ~10-30 GB/day |
| **Azure Sentinel** | Per GB ingested | $100 | $500 | ~10-30 GB/day |
| **Key Vaults** | Standard (x3) | $9 | $9 | $3/vault |
| **Private Endpoints** | ~10-20 endpoints | $80 | $160 | $8/endpoint/month |
| **Azure Backup** | GRS, 100GB | $10 | $20 | Varies by data volume |
| **ExpressRoute** | Optional | - | $55-1,650 | If hybrid connectivity |
| | | | | |
| **Total Baseline** | | **~$1,000-1,500** | **~$5,000-6,000** | Without workload costs |

### Cost Optimization Strategies

**Non-Production Environments:**
- Use Azure Firewall Standard instead of Premium ($595 vs $1,250)
- Skip DDoS Protection Standard ($2,944 savings)
- Use Application Gateway Standard_v2 instead of WAF_v2
- Deploy Bastion only when needed (on-demand)
- Use Defender for Cloud free tier
- Shorter log retention (30 days vs 90-365 days)

**Log Cost Optimization:**
```bash
# Table-level retention (not workspace-level)
az monitor log-analytics workspace table update \
  --workspace-name la-vrd-tmt-prd-eus2 \
  --name AzureActivity \
  --retention-time 90

# Archive old logs (cheaper tier for >90 days)
az monitor log-analytics workspace table update \
  --workspace-name la-vrd-tmt-prd-eus2 \
  --name AzureDiagnostics \
  --total-retention-time 365 \
  --plan Basic  # Archived storage
```

**Sentinel Cost Reduction:**
- Use data ingestion limits and sampling
- Filter verbose/low-value logs before ingestion
- Use basic logs for high-volume sources
- Commitment tiers for predictable usage (10% discount at 100GB/day)

**Network Cost Optimization:**
- Use Private Link instead of VNet peering where possible
- Consolidate egress through single Firewall (avoid per-resource public IPs)
- Use Azure Front Door Standard tier for global apps (vs Premium)
- Right-size Application Gateway instances based on actual traffic

---

## Day 0: Create Tenant, Lock Identity

### 1. Create Azure AD/Entra Tenant

```bash
# Login to Azure
az login

# Create new tenant (via portal: portal.azure.com → Entra ID → Create tenant)
# Verify custom domain: Add TXT record to DNS
```

### 2. Create Two Break-Glass Accounts

```powershell
# Create cloud-only accounts with long random passwords
$breakGlassPassword = [System.Web.Security.Membership]::GeneratePassword(64,10)
Write-Host "STORE THIS PASSWORD OFFLINE: $breakGlassPassword"

az ad user create \
  --display-name "Break Glass Admin 1" \
  --user-principal-name breakglass1@yourdomain.com \
  --password $breakGlassPassword \
  --force-change-password-next-sign-in false

# Assign Global Admin role
az role assignment create \
  --assignee breakglass1@yourdomain.com \
  --role "Global Administrator" \
  --scope "/"

# Repeat for breakglass2@yourdomain.com
```

**Critical:**
- Store passwords in physical safe + password manager
- Exclude from all Conditional Access policies
- Test sign-in immediately
- Monitor for usage (alert if used)

### 3. Enable Security Defaults (Temporary)

Only if you can't configure Conditional Access on Day 0:

```bash
az rest --method patch \
  --url "https://graph.microsoft.com/v1.0/policies/identitySecurityDefaultsEnforcementPolicy" \
  --body '{"isEnabled":true}'
```

Disable once CA is configured.

### 4. Disable Legacy Authentication

```bash
# Block legacy auth protocols tenant-wide
az rest --method patch \
  --url "https://graph.microsoft.com/beta/organization/<tenant-id>" \
  --body '{
    "securityDefaults": {
      "enabledForReportingButNotEnforced": false
    },
    "authenticationMethodsPolicy": {
      "registrationEnforcement": {
        "authenticationMethodsRegistrationCampaign": {
          "state": "enabled"
        }
      }
    }
  }'
```

### 5. Conditional Access Policies

See [Appendix B](#appendix-b-conditional-access-baseline) for complete policy definitions.

**Policy 1: Require MFA for all users**
**Policy 2: Admins require compliant device + MFA**
**Policy 3: Block risky sign-ins**
**Policy 4: Block from restricted geo-locations**

### 6. Privileged Identity Management (PIM)

```bash
# Enable PIM (Azure AD Premium P2 required)
# Portal: Entra ID → Privileged Identity Management

# Configure roles to require:
# - Just-in-time activation (max 8 hours)
# - Approval from another admin
# - Justification for activation
# - MFA on activation

# Remove all standing Global Admin assignments
```

### 7. Admin Consent Controls

```bash
# Require admin consent for all apps
az rest --method patch \
  --url "https://graph.microsoft.com/v1.0/policies/authorizationPolicy" \
  --body '{
    "permissionGrantPolicyIdsAssignedToDefaultUserRole": []
  }'

# Enable Admin Consent Workflow
# Portal: Entra ID → Enterprise applications → User settings
# → Admin consent requests → Enable
```

### 8. Identity Hardening (NEW)

**Password Policies:**
```bash
# Banned password list
# Portal: Entra ID → Security → Authentication methods → Password protection
# - Enable custom banned password list
# - Add: company name, product names, common patterns

# Password expiration: DISABLED (per NIST SP 800-63B)
# Self-service password reset: ENABLED with MFA
```

**Identity Protection:**
```bash
# User risk policy: Block at High, require password change at Medium
# Sign-in risk policy: Block at High, require MFA at Medium

# Portal: Entra ID → Security → Identity Protection
```

**Guest User Controls:**
```bash
# Limit guest invitations to specific roles
az rest --method patch \
  --url "https://graph.microsoft.com/v1.0/policies/authorizationPolicy" \
  --body '{
    "guestUserRoleId": "10dae51f-b6af-4016-8d66-8c2a99b929b3",
    "allowInvitesFrom": "adminsAndGuestInviters"
  }'

# Enable guest access reviews (every 90 days)
# Portal: Entra ID → Identity Governance → Access reviews
```

### 9. Workload Identity Standard

```bash
# For all Azure compute:
# - Enable system-assigned managed identity
# - Grant RBAC to specific resources only

# For CI/CD (GitHub Actions, Azure DevOps):
# - Use OIDC federation (no secrets)
# - See Appendix A for setup examples
```

**Exit criteria:**
✅ Break-glass tested
✅ CA baseline working (all users have MFA)
✅ PIM enforced (zero standing Global Admins)
✅ Legacy auth disabled
✅ Identity Protection enabled
✅ Guest controls configured

---

## Day 1: Management Groups, Subscriptions, Landing Zone

### 1. Create Management Groups

```bash
# Create MG hierarchy
az account management-group create --name platform
az account management-group create --name corp
az account management-group create --name sandbox
az account management-group create --name products

# Create per-product MGs
az account management-group create --name prod-tmt --parent products
az account management-group create --name nonprod-tmt --parent products
```

### 2. Create Subscriptions

```bash
# Via portal or CLI (requires EA/MCA)
az account subscription create \
  --offer-type MS-AZR-0017P \
  --display-name "tmt-dev" \
  --billing-account-name <billing-account> \
  --enrollment-account-name <enrollment-account>

# Move to correct MG
az account management-group subscription add \
  --name nonprod-tmt \
  --subscription tmt-dev
```

Repeat for: `tmt-test`, `tmt-prod`

### 3. Adopt Azure Landing Zone (ALZ)

```bash
# Deploy ALZ using Bicep or Terraform
# See: https://github.com/Azure/terraform-azurerm-caf-enterprise-scale

# Or use Azure Portal accelerator:
# Portal → Search "Azure landing zone accelerator"
```

### 4. Baseline RBAC

```bash
# Create Entra groups for role assignments
az ad group create --display-name "grp-tmt-owners-prd" --mail-nickname grp-tmt-owners-prd
az ad group create --display-name "grp-tmt-contributors-prd" --mail-nickname grp-tmt-contributors-prd
az ad group create --display-name "grp-tmt-readers-prd" --mail-nickname grp-tmt-readers-prd

# Assign roles to groups (NOT users)
az role assignment create \
  --assignee-object-id <group-id> \
  --role "Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/rg-vrd-tmt-prd-eus2-app"

# DENY Owner role except for break-glass
az role assignment create \
  --assignee <breakglass-id> \
  --role "Owner" \
  --scope "/subscriptions/<sub-id>" \
  --description "Break-glass only"
```

### 5. Enable Defender for Cloud

```bash
# At management group level (applies to all subs)
az security pricing create \
  --name VirtualMachines --tier Standard \
  --scope "/providers/Microsoft.Management/managementGroups/products"

az security pricing create \
  --name AppServices --tier Standard \
  --scope "/providers/Microsoft.Management/managementGroups/products"

az security pricing create \
  --name SqlServers --tier Standard \
  --scope "/providers/Microsoft.Management/managementGroups/products"

az security pricing create \
  --name KubernetesService --tier Standard \
  --scope "/providers/Microsoft.Management/managementGroups/products"

az security pricing create \
  --name ContainerRegistry --tier Standard \
  --scope "/providers/Microsoft.Management/managementGroups/products"

az security pricing create \
  --name KeyVaults --tier Standard \
  --scope "/providers/Microsoft.Management/managementGroups/products"

az security pricing create \
  --name StorageAccounts --tier Standard \
  --scope "/providers/Microsoft.Management/managementGroups/products"
```

**Exit criteria:**
✅ MG hierarchy in place
✅ Subscriptions created and organized
✅ Roles assigned via groups
✅ Defender for Cloud enabled on all resource types

---

## Day 2: Network Baseline (Hub/Spoke, Private Link)

### 1. Hub VNet Infrastructure

See `infrastructure/bicep/modules/security-baseline/hub-network.bicep` for complete Bicep module.

```bash
# Create hub resource group
az group create --name rg-vrd-platform-prd-eus2-net --location eastus2

# Deploy hub VNet with Firewall + DDoS
az deployment group create \
  --resource-group rg-vrd-platform-prd-eus2-net \
  --template-file hub-network.bicep \
  --parameters org=vrd env=prd region=eus2
```

**Hub components:**
- Azure Firewall Premium (TLS inspection, IDPS)
- DDoS Protection Standard
- Azure Bastion (for admin access)
- Private DNS zones for Private Link

**Network Performance Planning:**
| Component | Throughput | Connections/sec | Cost |
|-----------|-----------|-----------------|------|
| Firewall Premium | 30 Gbps | 100K | $1,250/mo |
| Firewall Standard | 30 Gbps | 100K | $595/mo |
| Application Gateway v2 | 125 Mbps - 10 Gbps | Autoscale | $125-250/mo |
| ExpressRoute | 50 Mbps - 10 Gbps | Varies | $55-1,650/mo |

### 2. Spoke VNets (per environment/product)

```bash
# Create spoke VNet
az network vnet create \
  --name vnet-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-net \
  --address-prefixes 10.1.0.0/16

# Create subnets with NSGs
az network vnet subnet create \
  --name snet-vrd-tmt-prd-eus2-app \
  --vnet-name vnet-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-net \
  --address-prefixes 10.1.1.0/24 \
  --network-security-group nsg-vrd-tmt-prd-eus2-app

# Peer to hub
az network vnet peering create \
  --name spoke-to-hub \
  --resource-group rg-vrd-tmt-prd-eus2-net \
  --vnet-name vnet-vrd-tmt-prd-eus2 \
  --remote-vnet /subscriptions/<hub-sub>/resourceGroups/rg-vrd-platform-prd-eus2-net/providers/Microsoft.Network/virtualNetworks/vnet-vrd-hub-prd-eus2 \
  --allow-forwarded-traffic
```

### 3. Ingress: WAF Protection

```bash
# Application Gateway with WAF v2
az network application-gateway create \
  --name agw-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-net \
  --vnet-name vnet-vrd-tmt-prd-eus2 \
  --subnet snet-vrd-tmt-prd-eus2-agw \
  --sku WAF_v2 \
  --waf-policy /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies/waf-policy

# Block direct origin access (use NSG)
az network nsg rule create \
  --name DenyDirectAccess \
  --nsg-name nsg-vrd-tmt-prd-eus2-app \
  --resource-group rg-vrd-tmt-prd-eus2-net \
  --priority 100 \
  --access Deny \
  --source-address-prefixes Internet \
  --destination-address-prefixes * \
  --destination-port-ranges 80 443
```

### 4. Egress: Firewall Control

```bash
# Route table to force through Firewall
az network route-table create \
  --name rt-vrd-tmt-prd-eus2-app \
  --resource-group rg-vrd-tmt-prd-eus2-net

az network route-table route create \
  --name default-via-firewall \
  --route-table-name rt-vrd-tmt-prd-eus2-app \
  --resource-group rg-vrd-tmt-prd-eus2-net \
  --address-prefix 0.0.0.0/0 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 10.0.1.4  # Firewall private IP

# Associate with subnet
az network vnet subnet update \
  --name snet-vrd-tmt-prd-eus2-app \
  --vnet-name vnet-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-net \
  --route-table rt-vrd-tmt-prd-eus2-app
```

**Firewall application rules (allow-list):**
```bash
# Allow package managers, APIs, etc.
az network firewall application-rule create \
  --collection-name allowed-outbound \
  --firewall-name azfw-vrd-hub-prd-eus2 \
  --name allow-package-repos \
  --protocols Https=443 \
  --source-addresses 10.0.0.0/8 \
  --target-fqdns \
    "*.npmjs.com" \
    "*.pypi.org" \
    "*.nuget.org" \
    "github.com" \
    "*.githubusercontent.com" \
  --priority 100 \
  --action Allow
```

### 5. Private Link for Azure Services

```bash
# Private DNS zones (in hub)
az network private-dns zone create \
  --resource-group rg-vrd-platform-prd-eus2-net \
  --name privatelink.vaultcore.azure.net

az network private-dns zone create \
  --resource-group rg-vrd-platform-prd-eus2-net \
  --name privatelink.database.windows.net

# Link to spoke VNets
az network private-dns link vnet create \
  --resource-group rg-vrd-platform-prd-eus2-net \
  --zone-name privatelink.vaultcore.azure.net \
  --name link-to-tmt-spoke \
  --virtual-network /subscriptions/<sub>/resourceGroups/rg-vrd-tmt-prd-eus2-net/providers/Microsoft.Network/virtualNetworks/vnet-vrd-tmt-prd-eus2 \
  --registration-enabled false

# Create private endpoint for Key Vault
az network private-endpoint create \
  --name pe-vrd-tmt-prd-eus2-kv \
  --resource-group rg-vrd-tmt-prd-eus2-net \
  --vnet-name vnet-vrd-tmt-prd-eus2 \
  --subnet snet-vrd-tmt-prd-eus2-data \
  --private-connection-resource-id /subscriptions/<sub>/resourceGroups/rg-vrd-tmt-prd-eus2-app/providers/Microsoft.KeyVault/vaults/kv-vrd-tmt-prd-eus2-01 \
  --connection-name kv-connection \
  --group-id vault
```

### 6. No Inbound RDP/SSH

```bash
# Use Azure Bastion for admin access
az network bastion create \
  --name bastion-vrd-platform-prd-eus2 \
  --resource-group rg-vrd-platform-prd-eus2-net \
  --vnet-name vnet-vrd-hub-prd-eus2 \
  --location eastus2 \
  --public-ip-address pip-bastion-vrd-platform-prd-eus2

# Enable JIT access via Defender for Cloud
az security jit-policy create \
  --location eastus2 \
  --name jit-policy-vm \
  --resource-group rg-vrd-tmt-prd-eus2-app \
  --virtual-machines "/subscriptions/<sub>/resourceGroups/rg-vrd-tmt-prd-eus2-app/providers/Microsoft.Compute/virtualMachines/vm-vrd-tmt-prd-eus2-web-01" \
  --port 22 3389 \
  --protocol TCP \
  --max-request-access-duration PT3H
```

**Exit criteria:**
✅ Hub-spoke topology deployed
✅ Egress controlled via Firewall
✅ Private DNS working
✅ No public IPs on workloads
✅ Bastion + JIT configured

---

## Day 3: Policy Guardrails

Apply policies at the `products` management group to enforce standards.

See `infrastructure/bicep/modules/security-baseline/policies.bicep` for complete policy set.

### 1. Deny Public Network Access

```bash
# Deny public access for sensitive services
az policy assignment create \
  --name "Deny-Public-Access-Storage" \
  --policy "/providers/Microsoft.Authorization/policyDefinitions/34c877ad-507e-4c82-993e-3452a6e0ad3c" \
  --scope "/providers/Microsoft.Management/managementGroups/products" \
  --params '{
    "effect": {"value": "Deny"}
  }'

# Repeat for:
# - SQL Database (deny public access)
# - Key Vault (deny public network access)
# - Cosmos DB (deny public network access)
# - ACR (deny public network access)
```

### 2. Enforce Encryption & TLS

```bash
# Require HTTPS-only for Storage
az policy assignment create \
  --name "Enforce-HTTPS-Storage" \
  --policy "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9" \
  --scope "/providers/Microsoft.Management/managementGroups/products"

# Require TLS 1.2+ for all services
az policy assignment create \
  --name "Enforce-TLS-1.2" \
  --policy "/providers/Microsoft.Authorization/policyDefinitions/fe83a0eb-a853-422d-aac2-1bffd182c5d0" \
  --scope "/providers/Microsoft.Management/managementGroups/products"

# Require disk encryption
az policy assignment create \
  --name "Enforce-Disk-Encryption" \
  --policy "/providers/Microsoft.Authorization/policyDefinitions/0961003e-5a0a-4549-abde-af6a37f2724d" \
  --scope "/providers/Microsoft.Management/managementGroups/products"
```

### 3. Require Private Endpoints

```bash
# Policy: Require private endpoint for Key Vault, Storage, SQL, etc.
az policy assignment create \
  --name "Require-Private-Endpoints" \
  --policy-set-definition "/providers/Microsoft.Authorization/policySetDefinitions/a33a8e05-4fc2-47e6-8a1d-cf4f1c7e6eda" \
  --scope "/providers/Microsoft.Management/managementGroups/products"
```

### 4. Auto-Enable Diagnostic Settings

```bash
# Automatically send logs to Log Analytics
az policy assignment create \
  --name "Auto-Enable-Diagnostics" \
  --policy "/providers/Microsoft.Authorization/policyDefinitions/7f89b1eb-583c-429a-8828-af049802c1d9" \
  --scope "/providers/Microsoft.Management/managementGroups/products" \
  --params '{
    "logAnalytics": {"value": "/subscriptions/<sub>/resourceGroups/rg-vrd-platform-prd-eus2-ops/providers/Microsoft.OperationalInsights/workspaces/la-vrd-platform-prd-eus2"}
  }' \
  --assign-identity \
  --location eastus2
```

### 5. Tag Compliance

```bash
# Require tags on resource groups
az policy assignment create \
  --name "Require-Tags-RG" \
  --policy "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025" \
  --scope "/providers/Microsoft.Management/managementGroups/products" \
  --params '{
    "tagName": {"value": "Org"}
  }'

# Repeat for: Project, Environment, Region, Owner, CostCenter

# Inherit tags from RG
az policy assignment create \
  --name "Inherit-Tags-From-RG" \
  --policy "/providers/Microsoft.Authorization/policyDefinitions/cd3aa116-8754-49c3-b9be-2e4c0f58f2d6" \
  --scope "/providers/Microsoft.Management/managementGroups/products" \
  --params '{
    "tagName": {"value": "Org"}
  }' \
  --assign-identity \
  --location eastus2
```

### 6. Region & SKU Allow-List

```bash
# Restrict to specific regions
az policy assignment create \
  --name "Allowed-Regions" \
  --policy "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c" \
  --scope "/providers/Microsoft.Management/managementGroups/products" \
  --params '{
    "listOfAllowedLocations": {"value": ["eastus2", "westus2", "centralus"]}
  }'

# Restrict to approved SKUs (cost control)
az policy assignment create \
  --name "Allowed-VM-SKUs" \
  --policy "/providers/Microsoft.Authorization/policyDefinitions/cccc23c7-8427-4f53-ad12-b6a63eb452b3" \
  --scope "/providers/Microsoft.Management/managementGroups/products" \
  --params '{
    "listOfAllowedSKUs": {"value": ["Standard_D2s_v3", "Standard_D4s_v3", "Standard_E2s_v3"]}
  }'
```

### 7. Policy Testing

**IMPORTANT:** Test policies in audit mode first!

```bash
# Set to audit mode for 7 days
az policy assignment create \
  --name "Test-Policy-Audit" \
  --policy <policy-id> \
  --scope <scope> \
  --params '{"effect": {"value": "Audit"}}'

# Check compliance
az policy state summarize \
  --management-group products \
  --query "results.policyAssignments[?complianceState=='NonCompliant']"

# After validation, switch to Deny/DeployIfNotExists
az policy assignment update \
  --name "Test-Policy-Audit" \
  --params '{"effect": {"value": "Deny"}}'
```

### 8. Policy Exemptions

```bash
# Document permanent exemptions in Git repo
# Create time-bound exemption
az policy exemption create \
  --name "legacy-storage-exception" \
  --policy-assignment "/subscriptions/<sub>/providers/Microsoft.Authorization/policyAssignments/Deny-Public-Access-Storage" \
  --exemption-category "Waiver" \
  --expires-on "2025-12-31T23:59:59Z" \
  --description "Legacy storage account - migration planned Q4 2025"

# List all exemptions
az policy exemption list --query "[].{name:name, expiresOn:expiresOn, category:exemptionCategory}"
```

**Exit criteria:**
✅ >95% policy compliance
✅ All exceptions documented and time-bound
✅ Policies tested in audit mode first

---

## Day 4: Logging, Monitoring, Sentinel

### 1. Log Analytics Workspaces

```bash
# Create per-region workspace
az monitor log-analytics workspace create \
  --resource-group rg-vrd-platform-prd-eus2-ops \
  --workspace-name la-vrd-platform-prd-eus2 \
  --location eastus2 \
  --retention-time 90 \
  --sku PerGB2018

# Configure table-level retention
az monitor log-analytics workspace table update \
  --workspace-name la-vrd-platform-prd-eus2 \
  --resource-group rg-vrd-platform-prd-eus2-ops \
  --name AzureActivity \
  --retention-time 90

# Archive old logs (>90 days to cheaper tier)
az monitor log-analytics workspace table update \
  --workspace-name la-vrd-platform-prd-eus2 \
  --resource-group rg-vrd-platform-prd-eus2-ops \
  --name AzureDiagnostics \
  --total-retention-time 365 \
  --plan Basic  # Archived storage
```

### 2. Diagnostic Settings Everywhere

```bash
# Key Vault
az monitor diagnostic-settings create \
  --name send-to-la \
  --resource /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/kv-vrd-tmt-prd-eus2-01 \
  --logs '[{"category":"AuditEvent","enabled":true}]' \
  --metrics '[{"category":"AllMetrics","enabled":true}]' \
  --workspace /subscriptions/<sub>/resourceGroups/rg-vrd-platform-prd-eus2-ops/providers/Microsoft.OperationalInsights/workspaces/la-vrd-platform-prd-eus2

# Storage
az monitor diagnostic-settings create \
  --name send-to-la \
  --resource /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/stvrdtmtprdeus201 \
  --logs '[{"category":"StorageRead","enabled":true},{"category":"StorageWrite","enabled":true}]' \
  --metrics '[{"category":"Transaction","enabled":true}]' \
  --workspace <workspace-id>

# Repeat for all resource types
```

**Automate with Policy (see Day 3):**
- Policy automatically enables diagnostic settings on creation

### 3. Azure Sentinel (Microsoft Sentinel)

```bash
# Enable Sentinel on workspace
az sentinel onboard \
  --resource-group rg-vrd-platform-prd-eus2-ops \
  --workspace-name la-vrd-platform-prd-eus2

# Connect data sources
# Portal: Sentinel → Data connectors → Install:
# - Azure Active Directory (Sign-ins, Audit logs, Risky users)
# - Azure Activity
# - Azure Key Vault
# - Azure Storage
# - Azure SQL Database
# - Azure Firewall
# - Azure WAF
# - Azure Container Registry
# - Azure Kubernetes Service
# - Azure App Service
```

### 4. High-Signal Analytics Rules

Enable these built-in rules:

**Identity & Access:**
- Impossible travel activity
- Mass password reset by single user
- Suspicious consent grant to OAuth app
- Multiple failed sign-in attempts
- Sign-in from anonymous IP
- Privileged role assigned outside PIM

**Data & Secrets:**
- Mass Key Vault secret access
- Unusual Key Vault operations
- Storage account public access enabled
- Mass file download from Storage

**Compute & Network:**
- Crypto-mining activity
- Suspicious egress traffic spikes
- Unusual VM extension deployment
- Port scanning activity

**Compliance:**
- Audit log retention changed
- Security policy modified
- Diagnostic settings disabled

### 5. Alert Routing

```bash
# Create action group
az monitor action-group create \
  --name ag-security-ops \
  --resource-group rg-vrd-platform-prd-eus2-ops \
  --short-name SecOps \
  --email-receiver name=SecurityTeam email=security@verdaio.com \
  --sms-receiver name=OnCall country-code=1 phone-number=5551234567

# Create alert rule
az monitor metrics alert create \
  --name alert-firewall-threat-intel-hits \
  --resource-group rg-vrd-platform-prd-eus2-net \
  --scopes /subscriptions/<sub>/resourceGroups/rg-vrd-platform-prd-eus2-net/providers/Microsoft.Network/azureFirewalls/azfw-vrd-hub-prd-eus2 \
  --condition "total ApplicationRuleHit > 100" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action ag-security-ops \
  --severity 2
```

**Exit criteria:**
✅ Centralized logs flowing to LA workspace
✅ Sentinel enabled and connectors configured
✅ High-signal analytics rules enabled
✅ Alert routing tested (send test alert)
✅ Security dashboard visible to SOC

---

## Day 5: Data, Keys, Secrets

### 1. Key Vault Hardening

```bash
# Create Key Vault with security baseline
az keyvault create \
  --name kv-vrd-tmt-prd-eus2-01 \
  --resource-group rg-vrd-tmt-prd-eus2-app \
  --location eastus2 \
  --enable-rbac-authorization true \
  --enable-purge-protection true \
  --enable-soft-delete true \
  --retention-days 90 \
  --public-network-access Disabled

# Create private endpoint (see Day 2)
# Enable diagnostic settings (see Day 4)

# RBAC roles (no access policies)
az role assignment create \
  --assignee <app-managed-identity> \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/kv-vrd-tmt-prd-eus2-01
```

**Managed HSM for regulated workloads:**
```bash
# For payment data, healthcare, financial services
az keyvault create-hsm \
  --name hsm-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-app \
  --location eastus2 \
  --administrators <admin-object-id>

# Cost: ~$1.45/hour ($1,050/month per pool)
```

### 2. Storage Account Lockdown

```bash
# Hardened storage account
az storage account update \
  --name stvrdtmtprdeus201 \
  --resource-group rg-vrd-tmt-prd-eus2-data \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-shared-key-access false \
  --public-network-access Disabled \
  --default-action Deny

# Enable versioning + soft delete
az storage account blob-service-properties update \
  --account-name stvrdtmtprdeus201 \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 90

# Immutability for logs/archives (ransomware protection)
az storage container immutability-policy create \
  --account-name stvrdtmtprdeus201 \
  --container-name logs \
  --period 365 \
  --policy-mode Locked
```

### 3. Database Security

**Azure SQL:**
```bash
# Create SQL Server with Entra-only auth
az sql server create \
  --name sqlsvr-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-data \
  --location eastus2 \
  --enable-ad-only-auth \
  --external-admin-principal-type User \
  --external-admin-name <admin-upn> \
  --external-admin-sid <admin-object-id>

# Disable public access
az sql server update \
  --name sqlsvr-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-data \
  --public-network-access Disabled

# Enable Defender for SQL
az security pricing create \
  --name SqlServers --tier Standard

# Transparent Data Encryption with CMK
az sql server tde-key set \
  --server sqlsvr-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-data \
  --key-type AzureKeyVault \
  --kid https://kv-vrd-tmt-prd-eus2-01.vault.azure.net/keys/tde-key/version

# Auditing to Log Analytics
az sql server audit-policy update \
  --name sqlsvr-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-data \
  --state Enabled \
  --log-analytics-workspace-resource-id <workspace-id>
```

**Cosmos DB:**
```bash
# Create with private access only
az cosmosdb create \
  --name cosmos-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-data \
  --public-network-access Disabled \
  --enable-automatic-failover true \
  --locations regionName=eastus2 failoverPriority=0 \
  --locations regionName=westus2 failoverPriority=1

# CMK encryption
az cosmosdb update \
  --name cosmos-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-data \
  --key-uri https://kv-vrd-tmt-prd-eus2-01.vault.azure.net/keys/cosmos-key/version
```

**Exit criteria:**
✅ No secrets in app settings (Key Vault references only)
✅ All datastores private-only access
✅ Auditing enabled to immutable storage
✅ CMK encryption for sensitive data

---

## Day 6: Workload Baselines (App Service, AKS, VMs)

### App Service / Functions

```bash
# Create App Service with security baseline
az appservice plan create \
  --name plan-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-app \
  --sku P1v3 \
  --is-linux

az webapp create \
  --name app-vrd-tmt-prd-eus2-01 \
  --resource-group rg-vrd-tmt-prd-eus2-app \
  --plan plan-vrd-tmt-prd-eus2 \
  --runtime "NODE|18-lts"

# Security configuration
az webapp config set \
  --name app-vrd-tmt-prd-eus2-01 \
  --resource-group rg-vrd-tmt-prd-eus2-app \
  --https-only true \
  --min-tls-version 1.2 \
  --ftps-state Disabled \
  --always-on true

# VNet integration (outbound)
az webapp vnet-integration add \
  --name app-vrd-tmt-prd-eus2-01 \
  --resource-group rg-vrd-tmt-prd-eus2-app \
  --vnet vnet-vrd-tmt-prd-eus2 \
  --subnet snet-vrd-tmt-prd-eus2-app

# Lock down SCM site
az webapp config access-restriction add \
  --name app-vrd-tmt-prd-eus2-01 \
  --resource-group rg-vrd-tmt-prd-eus2-app \
  --rule-name "Allow-From-VNet" \
  --action Allow \
  --vnet-name vnet-vrd-tmt-prd-eus2 \
  --subnet snet-vrd-tmt-prd-eus2-app \
  --priority 100 \
  --scm-site true

# Use Key Vault references for secrets
az webapp config appsettings set \
  --name app-vrd-tmt-prd-eus2-01 \
  --resource-group rg-vrd-tmt-prd-eus2-app \
  --settings \
    "DatabasePassword=@Microsoft.KeyVault(SecretUri=https://kv-vrd-tmt-prd-eus2-01.vault.azure.net/secrets/db-password/)"

# Enable managed identity
az webapp identity assign \
  --name app-vrd-tmt-prd-eus2-01 \
  --resource-group rg-vrd-tmt-prd-eus2-app
```

### AKS (Azure Kubernetes Service)

See `infrastructure/bicep/modules/security-baseline/aks-secure-cluster.bicep` for complete module.

```bash
# Create private AKS cluster
az aks create \
  --name aks-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-app \
  --location eastus2 \
  --enable-private-cluster \
  --network-plugin azure \
  --vnet-subnet-id /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/vnet-vrd-tmt-prd-eus2/subnets/snet-vrd-tmt-prd-eus2-aks \
  --enable-managed-identity \
  --disable-local-accounts \
  --enable-defender

# Azure Policy for AKS (admission controller)
az aks enable-addons \
  --name aks-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-app \
  --addons azure-policy

# Network policies (Calico)
az aks update \
  --name aks-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-app \
  --network-policy calico
```

**Pod Security Standards (via Azure Policy):**
- No privileged containers
- readOnlyRootFilesystem required
- runAsNonRoot required
- No hostPath volumes
- Drop all capabilities

**Egress control:**
- All egress through Azure Firewall (see Day 2)
- Allow-list: container registries, package repos, APIs

### Virtual Machines

```bash
# Create VM with security baseline
az vm create \
  --name vm-vrd-tmt-prd-eus2-web-01 \
  --resource-group rg-vrd-tmt-prd-eus2-app \
  --image UbuntuLTS \
  --size Standard_D2s_v3 \
  --vnet-name vnet-vrd-tmt-prd-eus2 \
  --subnet snet-vrd-tmt-prd-eus2-app \
  --nsg nsg-vrd-tmt-prd-eus2-app \
  --public-ip-address "" \
  --authentication-type ssh \
  --ssh-key-value @~/.ssh/id_rsa.pub \
  --assign-identity

# Disable password auth
az vm user update \
  --name vm-vrd-tmt-prd-eus2-web-01 \
  --resource-group rg-vrd-tmt-prd-eus2-app \
  --username adminuser \
  --disable-password-authentication true

# Enable Defender for Servers
az security pricing create \
  --name VirtualMachines --tier Standard

# Disk encryption with CMK
az vm encryption enable \
  --name vm-vrd-tmt-prd-eus2-web-01 \
  --resource-group rg-vrd-tmt-prd-eus2-app \
  --disk-encryption-keyvault kv-vrd-tmt-prd-eus2-01 \
  --key-encryption-key <key-url>
```

**Exit criteria:**
✅ App Services VNet-integrated, HTTPS-only, Key Vault refs
✅ AKS private cluster, admission policies enforced
✅ VMs password-disabled, Defender enabled, encrypted

---

## Day 7: DevSecOps & Supply Chain

### Source Control Security

**Branch Protection:**
```yaml
# .github/branch-protection.yml
protection:
  required_pull_request_reviews:
    required_approving_review_count: 2
    dismiss_stale_reviews: true
    require_code_owner_reviews: true
  required_status_checks:
    strict: true
    contexts:
      - security-scan
      - dependency-audit
      - iac-scan
  enforce_admins: true
  required_signatures: true
```

**CODEOWNERS:**
```
# CODEOWNERS
*                    @team-developers
*.bicep              @team-infrastructure
*.tf                 @team-infrastructure
/infrastructure/     @team-infrastructure @team-security
/.github/workflows/  @team-devops @team-security
```

### CI/CD with OIDC (No Secrets)

**GitHub Actions:**
```yaml
# .github/workflows/deploy.yml
name: Deploy to Azure
on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Azure Login (OIDC)
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy Bicep
        run: |
          az deployment group create \
            --resource-group rg-vrd-tmt-prd-eus2-app \
            --template-file infrastructure/bicep/main.bicep
```

**Azure OIDC Federation Setup:**
```bash
# Create service principal
az ad sp create-for-rbac \
  --name sp-github-oidc \
  --role Contributor \
  --scopes /subscriptions/<sub>/resourceGroups/rg-vrd-tmt-prd-eus2-app

# Add federated credential
az ad app federated-credential create \
  --id <app-id> \
  --parameters '{
    "name":"github-oidc",
    "issuer":"https://token.actions.githubusercontent.com",
    "subject":"repo:ChrisStephens1971/saas202511:ref:refs/heads/main",
    "audiences":["api://AzureADTokenExchange"]
  }'
```

### Security Scanning

**SAST (Static Analysis):**
```yaml
# .github/workflows/security-scan.yml
- name: Run Semgrep
  uses: returntocorp/semgrep-action@v1
  with:
    config: >-
      p/security-audit
      p/owasp-top-ten
```

**Dependency Scanning:**
```yaml
- name: Dependency Audit
  run: npm audit --audit-level=moderate

- name: Snyk Security Scan
  uses: snyk/actions/node@master
  env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
```

**IaC Scanning:**
```yaml
- name: Checkov IaC Scan
  uses: bridgecrewio/checkov-action@master
  with:
    directory: infrastructure/
    framework: bicep,terraform
    soft_fail: false
```

**Container Scanning:**
```yaml
- name: Build Container
  run: docker build -t myapp:${{ github.sha }} .

- name: Scan with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: myapp:${{ github.sha }}
    severity: CRITICAL,HIGH
    exit-code: 1

- name: Push to ACR
  run: |
    az acr login --name acrvrdtmtprdeus2
    docker tag myapp:${{ github.sha }} acrvrdtmtprdeus2.azurecr.io/myapp:${{ github.sha }}
    docker push acrvrdtmtprdeus2.azurecr.io/myapp:${{ github.sha }}
```

### Container Registry Security

```bash
# Create ACR with security baseline
az acr create \
  --name acrvrdtmtprdeus2 \
  --resource-group rg-vrd-tmt-prd-eus2-app \
  --sku Premium \
  --public-network-enabled false

# Content trust (signed images)
az acr config content-trust update \
  --name acrvrdtmtprdeus2 \
  --status enabled

# Retention policy
az acr config retention update \
  --name acrvrdtmtprdeus2 \
  --status enabled \
  --days 90 \
  --type UntaggedManifests
```

**Exit criteria:**
✅ CI/CD uses OIDC (no static secrets)
✅ All builds scanned (SAST, dependencies, IaC, containers)
✅ Branch protection enforced
✅ Container images signed and scanned
✅ Provenance documented

---

## Day 8: Security Testing & Validation

### Automated Security Testing

**Infrastructure Validation:**
```bash
# Test policy compliance
az policy state summarize --management-group products

# Verify no public IPs
az network public-ip list --query "[?contains(resourceGroup, 'prd')]"

# Check Key Vault access
az keyvault list --query "[].{name:name, publicNetworkAccess:properties.publicNetworkAccess}"
```

**Penetration Testing:**
- Use Azure-approved penetration testing
- Test from external attacker perspective
- Validate WAF effectiveness
- Test MFA bypass attempts
- Check privilege escalation paths

**Chaos Engineering:**
```bash
# Simulate zone failure
# Test failover to secondary region
# Verify backup restore procedures
# Test break-glass account access
```

### Compliance Validation

See [Day 9](#day-9-compliance-framework-mappings) for framework-specific checks.

**Exit criteria:**
✅ Automated security tests pass
✅ Penetration test findings remediated
✅ Chaos tests documented
✅ Compliance gaps identified

---

## Day 9: Compliance Framework Mappings

### SOC 2 Type II

**Control Mappings:**
- CC6.1 (Logical Access) → Conditional Access + PIM
- CC6.6 (Encryption) → TLS 1.2+, CMK, Private Link
- CC6.7 (System Operations) → Azure Monitor, Sentinel
- CC7.2 (Change Management) → IaC in Git, policy enforcement
- CC7.3 (Data Backup) → Azure Backup, immutability

**Evidence Collection:**
```bash
# Export audit logs for audit period
az monitor activity-log list \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-12-31T23:59:59Z \
  --query "[].{time:eventTimestamp, user:caller, operation:operationName.localizedValue}" \
  -o json > audit-logs-2025.json
```

### ISO 27001

**Control Mappings:**
- A.9 (Access Control) → Entra ID + PIM + CA
- A.10 (Cryptography) → Key Vault, TDE, CMK
- A.12 (Operations Security) → Defender, Sentinel, Policies
- A.14 (System Acquisition) → DevSecOps pipeline
- A.17 (Business Continuity) → Backup, geo-replication, DR

### HIPAA (Healthcare)

**Technical Safeguards:**
- Access Control (164.312(a)) → MFA, PIM, JIT
- Audit Controls (164.312(b)) → Sentinel, Log Analytics
- Integrity (164.312(c)) → Immutability, versioning
- Transmission Security (164.312(e)) → Private Link, TLS 1.2+

**Encryption Requirements:**
- At-rest: Azure Storage encryption + CMK
- In-transit: TLS 1.2+, Private Link
- Key management: Key Vault with Managed HSM for PHI

### PCI-DSS (Payment Cards)

**Requirements:**
- Req 1 (Firewall) → Azure Firewall, NSGs
- Req 2 (No defaults) → Policy enforcement, configuration baselines
- Req 3 (Protect data) → Encryption, tokenization, CMK
- Req 4 (Encrypt transmission) → TLS 1.2+, Private Link
- Req 8 (Unique IDs) → Entra ID, MFA, PIM
- Req 10 (Logging) → Sentinel, Log Analytics (1 year retention)

**Exit criteria:**
✅ Controls mapped to requirements
✅ Evidence collection automated
✅ Gaps documented with remediation plan

---

## Ongoing: Backup/DR, Incident Response, Audits

### Backup & Disaster Recovery

**Azure Backup:**
```bash
# Create Recovery Services Vault
az backup vault create \
  --name rsv-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-ops \
  --location eastus2

# Enable GRS with immutability
az backup vault backup-properties set \
  --name rsv-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-ops \
  --backup-storage-redundancy GeoRedundant \
  --soft-delete-state Enable \
  --soft-delete-retention-duration 90

# Configure VM backup
az backup protection enable-for-vm \
  --vm vm-vrd-tmt-prd-eus2-web-01 \
  --vault-name rsv-vrd-tmt-prd-eus2 \
  --resource-group rg-vrd-tmt-prd-eus2-ops \
  --policy-name DefaultPolicy
```

**SQL Geo-Replication:**
```bash
# Create failover group
az sql failover-group create \
  --name fg-vrd-tmt-prd \
  --partner-server sqlsvr-vrd-tmt-prd-wus2 \
  --resource-group rg-vrd-tmt-prd-eus2-data \
  --server sqlsvr-vrd-tmt-prd-eus2 \
  --failover-policy Automatic \
  --grace-period 1
```

**DR Drills (Quarterly):**
- Failover to secondary region
- Restore from backup
- Test break-glass access
- Validate RTO/RPO

### Incident Response

See [Appendix D](#appendix-d-incident-response-runbooks) for detailed runbooks.

**Playbooks:**
1. Credential leak response
2. Exposed storage response
3. Suspicious consent grant response
4. Ransomware response
5. Privilege escalation response

**Sentinel Automation:**
```bash
# Create playbook (Logic App) to auto-revoke tokens
# Portal: Sentinel → Automation → Create → Playbook
# Trigger: Sentinel alert for "Suspicious consent"
# Action: Revoke OAuth app permissions via Graph API
```

### Monthly Audits

**Checklist:**
- [ ] Review Owner/UAA role assignments
- [ ] Test break-glass accounts
- [ ] Run backup restore test
- [ ] Review policy compliance (target: ≥95%)
- [ ] Check for expired exemptions
- [ ] Rotate service principal credentials

**Quarterly Audits:**
- [ ] CA policy review
- [ ] PIM role audit
- [ ] Failover drill
- [ ] Secret rotation report
- [ ] Policy compliance ≥95%
- [ ] Update threat model

---

## Verification Checks (KQL)

```kusto
// Public IPs in production resource groups
AzureResourceGraph
| where type =~ 'microsoft.network/publicipaddresses'
| where resourceGroup contains 'prd'
| project name, resourceGroup, location

// Key Vault access from outside Private Link
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT" and Category == "AuditEvent"
| where isnotempty(CallerIPAddress)
| where CallerIPAddress !startswith "10."
| where CallerIPAddress !startswith "172."
| where CallerIPAddress !startswith "192.168."
| summarize count() by CallerIPAddress, Resource

// Failed Sentinel rules in last 24h
SecurityAlert
| where TimeGenerated > ago(24h)
| summarize count() by AlertSeverity, ProductName, AlertName

// Resources without required tags
AzureResourceGraph
| where type =~ 'microsoft.resources/subscriptions/resourcegroups'
| where tags !has 'Org' or tags !has 'Environment' or tags !has 'Owner'
| project name, tags, subscriptionId

// Storage accounts with public access enabled
AzureResourceGraph
| where type =~ 'microsoft.storage/storageaccounts'
| where properties.publicNetworkAccess == 'Enabled'
| project name, resourceGroup, properties.publicNetworkAccess

// Non-compliant policy assignments
PolicyResources
| where type =~ 'microsoft.policyinsights/policystates'
| where complianceState == 'NonCompliant'
| summarize count() by policyAssignmentName, policyDefinitionName
```

---

## Monitoring Dashboards & Workbooks

See `infrastructure/monitoring/` for Azure Workbook templates.

**Security Posture Dashboard:**
- Policy compliance percentage
- Defender for Cloud secure score
- Public endpoint count
- Certificate expiration warnings

**Identity Risk Dashboard:**
- Failed sign-in attempts
- MFA bypass attempts
- Risky sign-ins
- Privileged role activations

**Network Exposure Dashboard:**
- Firewall threat intelligence hits
- WAF blocked requests
- NSG flow logs (suspicious traffic)
- Private Link connection status

---

## Appendix A: CLI/Bicep/Terraform Snippets

Complete IaC modules available at: `C:\devop\.template-system\templates\saas-project-azure\infrastructure\`

**Bicep Modules:**
- `modules/security-baseline/management-groups.bicep`
- `modules/security-baseline/hub-network.bicep`
- `modules/security-baseline/policies.bicep`
- `modules/security-baseline/defender.bicep`
- `modules/security-baseline/logging.bicep`

**Terraform Modules:**
- `modules/security-baseline/management-groups/`
- `modules/security-baseline/hub-network/`
- `modules/security-baseline/policies/`

---

## Appendix B: Conditional Access Baseline

**Policy 1: Require MFA for all users**
```json
{
  "displayName": "CA001: Require MFA for all users",
  "state": "enabled",
  "conditions": {
    "users": {
      "includeUsers": ["All"],
      "excludeUsers": ["breakglass1@domain.com", "breakglass2@domain.com"]
    },
    "applications": {
      "includeApplications": ["All"]
    }
  },
  "grantControls": {
    "operator": "OR",
    "builtInControls": ["mfa"]
  },
  "sessionControls": {
    "signInFrequency": {
      "value": 8,
      "type": "hours"
    }
  }
}
```

**Policy 2: Admins require compliant device + MFA**
```json
{
  "displayName": "CA002: Admins require compliant device + MFA",
  "state": "enabled",
  "conditions": {
    "users": {
      "includeRoles": [
        "62e90394-69f5-4237-9190-012177145e10",  // Global Admin
        "e8611ab8-c189-46e8-94e1-60213ab1f814",  // Privileged Role Admin
        "194ae4cb-b126-40b2-bd5b-6091b380977d"   // Security Admin
      ]
    },
    "applications": {
      "includeApplications": ["All"]
    }
  },
  "grantControls": {
    "operator": "AND",
    "builtInControls": ["mfa", "compliantDevice"]
  }
}
```

**Policy 3: Block risky sign-ins**
```json
{
  "displayName": "CA003: Block risky sign-ins",
  "state": "enabled",
  "conditions": {
    "users": {
      "includeUsers": ["All"]
    },
    "signInRiskLevels": ["high", "medium"]
  },
  "grantControls": {
    "operator": "OR",
    "builtInControls": ["block"]
  }
}
```

**Policy 4: Block from restricted geo-locations**
```json
{
  "displayName": "CA004: Block from restricted countries",
  "state": "enabled",
  "conditions": {
    "users": {
      "includeUsers": ["All"]
    },
    "locations": {
      "includeLocations": ["AllTrusted"],
      "excludeLocations": ["<named-location-id-for-restricted-countries>"]
    }
  },
  "grantControls": {
    "operator": "OR",
    "builtInControls": ["block"]
  }
}
```

---

## Appendix C: Tagging & Metadata

**IMPORTANT:** Follows the Verdaio Azure Naming Standard v1.1.
See `azure-naming-standard.md` for complete tagging specifications.

**Required Tags (deny on create if missing):**
```json
{
  "Org": "vrd",
  "Project": "tmt",
  "Environment": "prd",
  "Region": "eus2",
  "Owner": "ops@verdaio.com",
  "CostCenter": "tmt-llc",
  "DataSensitivity": "Confidential",
  "RPO": "4h",
  "RTO": "4h",
  "BackupTier": "immutable"
}
```

**Generate tags automatically:**
```bash
python C:/devop/.template-system/scripts/azure-tag-generator.py \
  --org vrd --proj tmt --env prd --region eus2 \
  --owner ops@verdaio.com --cost-center tmt-llc \
  --format terraform
```

---

## Appendix D: Incident Response Runbooks

Detailed runbooks available in separate files:

1. **Credential Leak Response** → `runbooks/credential-leak-response.md`
2. **Exposed Storage Response** → `runbooks/exposed-storage-response.md`
3. **Suspicious Consent Response** → `runbooks/suspicious-consent-response.md`
4. **Ransomware Response** → `runbooks/ransomware-response.md`
5. **Privilege Escalation Response** → `runbooks/privilege-escalation-response.md`

Each runbook includes:
- Detection indicators
- Initial response steps
- Containment actions
- Eradication procedures
- Recovery steps
- Post-incident review

---

## Appendix E: Infrastructure Modules Reference

Complete IaC modules available at:
`C:\devop\.template-system\templates\saas-project-azure\infrastructure\`

**Bicep Modules:**
- Management Groups (`modules/security-baseline/management-groups.bicep`)
- Hub Network (`modules/security-baseline/hub-network.bicep`)
- Spoke Network (`modules/security-baseline/spoke-network.bicep`)
- Policy Set (`modules/security-baseline/policies.bicep`)
- Defender Configuration (`modules/security-baseline/defender.bicep`)
- Logging & Monitoring (`modules/security-baseline/logging.bicep`)
- AKS Secure Cluster (`modules/security-baseline/aks-secure-cluster.bicep`)

**Terraform Modules:**
- Management Groups (`modules/security-baseline/management-groups/`)
- Network Baseline (`modules/security-baseline/network-baseline/`)
- Policy Baseline (`modules/security-baseline/policy-baseline/`)

**Usage:**
```bash
# Deploy complete security baseline
cd infrastructure/bicep
az deployment tenant create \
  --location eastus2 \
  --template-file main.bicep \
  --parameters @parameters.json
```

---

### Success Criteria Recap

✅ **No public workload endpoints** by default; Private Link everywhere feasible
✅ **Managed identities only**; no app secrets in code or pipelines
✅ **CA + PIM active**; zero standing Global Admins
✅ **Logs centralized**; Sentinel rules firing; drill results documented
✅ **Backups immutable**; failover tested; RPO/RTO tags enforced
✅ **>95% policy compliance**; all exceptions time-bound
✅ **DevSecOps integrated**; all builds scanned; OIDC federation working
✅ **Compliance mapped**; SOC 2, ISO 27001, HIPAA, PCI-DSS controls documented

**You now have a secure, repeatable baseline to onboard any product/LLC without reinventing security each time.**

---

**Version:** 2.0 (Best-in-Class Edition)
**Status:** Production-Ready
**Integration:** Works with Verdaio Azure Naming Standard v1.1 and Template System
**Total Lines:** ~1,200
**Last Updated:** 2025-11-05
