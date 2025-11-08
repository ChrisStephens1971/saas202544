# Azure Security Baseline - Bicep Modules

**Version:** 1.0
**Last Updated:** 2025-11-05
**Part of:** Azure Security Playbook (Zero-to-Production) v2.0

---

## Overview

This directory contains production-ready Bicep modules for deploying the Azure security baseline described in the Azure Security Playbook v2.0. These modules implement best practices for networking, identity, logging, policy enforcement, and threat protection.

---

## Available Modules

### Core Modules

| Module | Purpose | Scope |
|--------|---------|-------|
| **main.bicep** | Orchestrates complete security baseline deployment | Subscription |
| **management-groups.bicep** | Creates management group hierarchy | Tenant |
| **hub-network.bicep** | Deploys hub network with Firewall + DDoS + Bastion | Resource Group |
| **spoke-network.bicep** | Deploys spoke network with NSGs and routing | Resource Group |
| **policies.bicep** | Applies Azure Policy guardrails | Management Group |
| **defender.bicep** | Enables Microsoft Defender for Cloud (all plans) | Subscription |
| **logging.bicep** | Deploys Log Analytics + Sentinel + App Insights | Resource Group |

---

## Quick Start

### Prerequisites

1. **Azure CLI** installed and authenticated
   ```bash
   az login
   az account set --subscription <subscription-id>
   ```

2. **Bicep CLI** installed
   ```bash
   az bicep install
   az bicep version
   ```

3. **Required Azure permissions:**
   - Owner role on subscription (for RBAC assignments)
   - User Access Administrator (for policy identities)
   - Global Administrator (for management groups)

### Deployment Steps

#### 1. Deploy Complete Security Baseline

```bash
# Set parameters
ORG="vrd"
PROJ="tmt"
ENV="prd"
REGION="eus2"
SUBSCRIPTION_ID="<your-subscription-id>"

# Deploy
az deployment sub create \
  --location eastus2 \
  --template-file main.bicep \
  --parameters \
    org=$ORG \
    proj=$PROJ \
    env=$ENV \
    primaryRegion=$REGION \
    deployHub=true \
    deploySpoke=true \
    enableDDoS=true \
    firewallSku=Premium
```

**What this deploys:**
- ✅ 4 resource groups (platform, ops, network, project)
- ✅ Log Analytics workspace + Azure Sentinel
- ✅ Application Insights
- ✅ Hub VNet with Azure Firewall Premium + DDoS + Bastion
- ✅ Spoke VNet with NSGs and private subnets
- ✅ VNet peering (hub-spoke)
- ✅ Private DNS zones for Private Link
- ✅ Microsoft Defender for Cloud (all plans)
- ✅ Data collection rules

**Deployment time:** ~30-45 minutes

#### 2. Deploy Management Groups (Optional)

```bash
# Requires tenant-level permissions
az deployment tenant create \
  --location eastus2 \
  --template-file modules/security-baseline/management-groups.bicep \
  --parameters \
    orgCode=vrd \
    products='["tmt","hoa"]'
```

#### 3. Deploy Azure Policies (Optional)

```bash
# At management group scope
MANAGEMENT_GROUP_ID="mg-vrd-products"
LOG_ANALYTICS_ID="/subscriptions/<sub>/resourceGroups/rg-vrd-platform-prd-eus2-ops/providers/Microsoft.OperationalInsights/workspaces/la-vrd-platform-prd-eus2"

az deployment mg create \
  --location eastus2 \
  --management-group-id $MANAGEMENT_GROUP_ID \
  --template-file modules/security-baseline/policies.bicep \
  --parameters \
    managementGroupId=$MANAGEMENT_GROUP_ID \
    logAnalyticsWorkspaceId=$LOG_ANALYTICS_ID \
    location=eastus2
```

---

## Module Details

### 1. Management Groups (`management-groups.bicep`)

**Scope:** Tenant

**Creates:**
```
Root (tenant)
├─ mg-{org}-platform     # Shared infrastructure
├─ mg-{org}-corp         # Corporate services
├─ mg-{org}-sandbox      # Developer experimentation
└─ mg-{org}-products     # Production workloads
   ├─ mg-{org}-prod-{product}
   ├─ mg-{org}-nonprod-{product}
   └─ ...
```

**Parameters:**
- `orgCode` - Organization code (2-4 chars)
- `products` - Array of product names

**Example:**
```bash
az deployment tenant create \
  --location eastus2 \
  --template-file modules/security-baseline/management-groups.bicep \
  --parameters orgCode=vrd products='["tmt","hoa"]'
```

---

### 2. Hub Network (`hub-network.bicep`)

**Scope:** Resource Group

**Creates:**
- Hub VNet (10.0.0.0/16)
- Azure Firewall (Standard or Premium)
- Azure Firewall Policy with application/network rules
- Azure Bastion
- DDoS Protection Plan (optional)
- Private DNS zones for Private Link
- Public IPs for Firewall and Bastion

**Parameters:**
- `org`, `env`, `region` - Naming components
- `firewallSku` - `Standard` or `Premium`
- `enableDDoS` - `true` for production

**Cost Estimate:**
- Dev/Test: ~$600/month (Firewall Standard, no DDoS)
- Production: ~$4,200/month (Firewall Premium + DDoS)

**Example:**
```bash
az group create --name rg-vrd-platform-prd-eus2-net --location eastus2

az deployment group create \
  --resource-group rg-vrd-platform-prd-eus2-net \
  --template-file modules/security-baseline/hub-network.bicep \
  --parameters \
    org=vrd \
    env=prd \
    region=eus2 \
    firewallSku=Premium \
    enableDDoS=true
```

---

### 3. Spoke Network (`spoke-network.bicep`)

**Scope:** Resource Group

**Creates:**
- Spoke VNet (10.1.0.0/16)
- 3 subnets: app, data, private-endpoints
- NSGs for each subnet
- Route table (force traffic through hub firewall)
- VNet peering to hub

**Parameters:**
- `org`, `proj`, `env`, `region` - Naming components
- `hubVNetId` - Hub VNet resource ID
- `hubFirewallPrivateIp` - Firewall private IP

**Example:**
```bash
az group create --name rg-vrd-tmt-prd-eus2 --location eastus2

az deployment group create \
  --resource-group rg-vrd-tmt-prd-eus2 \
  --template-file modules/security-baseline/spoke-network.bicep \
  --parameters \
    org=vrd \
    proj=tmt \
    env=prd \
    region=eus2 \
    hubVNetId="/subscriptions/<sub>/resourceGroups/rg-vrd-platform-prd-eus2-net/providers/Microsoft.Network/virtualNetworks/vnet-vrd-hub-prd-eus2" \
    hubFirewallPrivateIp="10.0.1.4"
```

---

### 4. Policies (`policies.bicep`)

**Scope:** Management Group

**Creates 12 policy assignments:**
1. Deny public network access for Storage
2. Enforce HTTPS-only for Storage
3. Enforce TLS 1.2+
4. Require disk encryption
5. Auto-enable diagnostic settings
6. Require 'Org' tag
7. Require 'Environment' tag
8. Require 'Owner' tag
9. Inherit 'Org' tag from RG
10. Inherit 'Environment' tag from RG
11. Restrict to allowed regions
12. Restrict VM SKUs

**Parameters:**
- `managementGroupId` - Target management group
- `logAnalyticsWorkspaceId` - For diagnostic settings policy
- `location` - For policy-assigned identities

**Example:**
```bash
az deployment mg create \
  --location eastus2 \
  --management-group-id mg-vrd-products \
  --template-file modules/security-baseline/policies.bicep \
  --parameters \
    managementGroupId=mg-vrd-products \
    logAnalyticsWorkspaceId="/subscriptions/<sub>/resourceGroups/rg-vrd-platform-prd-eus2-ops/providers/Microsoft.OperationalInsights/workspaces/la-vrd-platform-prd-eus2" \
    location=eastus2
```

---

### 5. Defender for Cloud (`defender.bicep`)

**Scope:** Subscription

**Enables:**
- Defender for Virtual Machines (Plan 2)
- Defender for App Services
- Defender for SQL Servers
- Defender for Storage (with malware scanning)
- Defender for Kubernetes
- Defender for Container Registry
- Defender for Key Vaults
- Defender for DNS
- Defender for Azure Resource Manager
- Defender for Cosmos DB
- Defender for Open Source Databases

**Cost Estimate:** ~$500-1,000/month depending on resource count

**Example:**
```bash
az deployment sub create \
  --location eastus2 \
  --template-file modules/security-baseline/defender.bicep \
  --parameters \
    enableVirtualMachines=true \
    enableAppServices=true \
    enableStorageAccounts=true \
    enableKubernetes=true
```

---

### 6. Logging (`logging.bicep`)

**Scope:** Resource Group

**Creates:**
- Log Analytics workspace
- Azure Sentinel (SecurityInsights solution)
- Application Insights
- Data collection rules
- Table-level retention settings

**Parameters:**
- `org`, `env`, `region` - Naming components
- `retentionInDays` - Log retention (30-730 days)
- `dailyQuotaGb` - Daily ingestion cap (-1 for unlimited)
- `enableSentinel` - Deploy Sentinel
- `enableAppInsights` - Deploy App Insights

**Cost Estimate:**
- Dev/Test: ~$50-150/month (low ingestion)
- Production: ~$300-800/month (10-30 GB/day)

**Example:**
```bash
az group create --name rg-vrd-platform-prd-eus2-ops --location eastus2

az deployment group create \
  --resource-group rg-vrd-platform-prd-eus2-ops \
  --template-file modules/security-baseline/logging.bicep \
  --parameters \
    org=vrd \
    env=prd \
    region=eus2 \
    retentionInDays=90 \
    enableSentinel=true \
    enableAppInsights=true
```

---

## Customization

### Firewall Rules

Edit `hub-network.bicep` to add custom application rules:

```bicep
targetFqdns: [
  '*.npmjs.com'
  '*.pypi.org'
  'custom.domain.com'  // ADD YOUR DOMAINS HERE
]
```

### NSG Rules

Edit `spoke-network.bicep` to add custom security rules:

```bicep
{
  name: 'AllowCustom'
  properties: {
    priority: 120
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceAddressPrefix: '10.1.1.0/24'
    destinationAddressPrefix: '*'
    destinationPortRanges: ['8080', '8443']
  }
}
```

### Policy Assignments

Edit `policies.bicep` to add custom policies or adjust parameters:

```bicep
// Add your custom policy
resource customPolicy 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'custom-policy-name'
  properties: {
    displayName: 'My Custom Policy'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/<policy-id>'
    enforcementMode: 'Default'
  }
}
```

---

## Validation

### Check Deployment Status

```bash
# List deployments
az deployment sub list --query "[].{name:name, state:properties.provisioningState}" -o table

# Check specific deployment
az deployment sub show --name deploy-defender --query "properties.provisioningState"
```

### Verify Resources

```bash
# List resource groups
az group list --query "[?tags.DeployedBy=='Bicep'].name" -o table

# Check Defender status
az security pricing list -o table

# Check policy compliance
az policy state summarize --management-group mg-vrd-products
```

### Test Connectivity

```bash
# Test firewall routing
az network nic show-effective-route-table \
  --name <nic-name> \
  --resource-group <rg-name> \
  -o table

# Check DNS resolution
nslookup kv-vrd-tmt-prd-eus2-01.vault.azure.net
```

---

## Troubleshooting

### Common Issues

**1. Deployment fails with "Insufficient permissions"**
```
Solution: Ensure you have Owner or User Access Administrator role
```

**2. VNet peering fails**
```
Solution: Ensure hub VNet exists before deploying spoke
az network vnet show --name vnet-vrd-hub-prd-eus2 --resource-group rg-vrd-platform-prd-eus2-net
```

**3. Policy assignment identity creation fails**
```
Solution: Ensure location parameter is provided and valid
--parameters location=eastus2
```

**4. Firewall deployment times out**
```
Solution: Increase timeout (--no-wait flag, then check status)
az deployment group create --no-wait ...
az deployment group show --name <deployment-name> --resource-group <rg>
```

---

## Cost Optimization

### Dev/Test Environment

```bash
az deployment sub create \
  --template-file main.bicep \
  --parameters \
    env=dev \
    enableDDoS=false \
    firewallSku=Standard \
    deployHub=false  # Use shared hub if available
```

**Estimated savings:** ~$3,600/month

### Production Optimizations

1. **Log retention:** 30 days hot, 365 days archived
2. **Firewall:** Premium only if TLS inspection needed
3. **Defender:** Disable plans for unused services
4. **DDoS:** Only for internet-facing workloads

---

## Next Steps

After deploying security baseline:

1. **Deploy workloads** using spoke networks
2. **Configure Private Endpoints** for Azure services
3. **Enable Sentinel analytics rules** for threat detection
4. **Configure alerts** for security events
5. **Test backup and restore** procedures
6. **Conduct security drills** (see incident response runbooks)

---

## Integration with Azure Security Playbook

These modules implement security controls from:
- **Day 0:** Identity hardening (manual Entra ID configuration)
- **Day 1:** Management groups, subscriptions, Defender
- **Day 2:** Hub-spoke network, Firewall, Bastion, Private DNS
- **Day 3:** Azure Policy guardrails
- **Day 4:** Log Analytics, Sentinel, monitoring
- **Days 5-7:** Deploy with workload-specific templates

---

## Additional Resources

- [Azure Security Playbook v2.0](../azure-security-zero-to-prod-v2.md)
- [Incident Response Runbooks](../azure-security-runbooks/)
- [Azure Naming Standard v1.1](../azure-naming-standard.md)
- [Microsoft Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Architecture Center](https://learn.microsoft.com/azure/architecture/)

---

**Version:** 1.0
**Status:** Production-Ready
**Last Updated:** 2025-11-05
