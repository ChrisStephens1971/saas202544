# Incident Response Runbook: Exposed Storage Account

**Version:** 1.0
**Last Updated:** 2025-11-05
**Severity:** High to Critical
**MTTR Target:** 30 minutes

---

## Overview

This runbook covers response to publicly exposed Azure Storage accounts including:
- Storage account with public network access enabled
- Blob containers with anonymous public access
- Storage account keys leaked
- Misconfigured SAS tokens with excessive permissions
- Data exfiltration detected

---

## Detection Indicators

### Automated Alerts
- Azure Policy: Public network access enabled
- Defender for Storage: Mass download detected
- Defender for Storage: Unusual access pattern
- Sentinel: Suspicious storage access from Tor exit node
- Cost anomaly: Unexpected egress charges

### Manual Discovery
- Container shows "Public access level: Blob" or "Container"
- Storage account firewall shows "Allow from all networks"
- Anonymous access successful without authentication

---

## Initial Response (0-15 minutes)

### 1. Assess the Exposure

```bash
# Check storage account public access setting
az storage account show \
  --name <storage-account> \
  --resource-group <resource-group> \
  --query "{publicNetworkAccess:publicNetworkAccess, allowBlobPublicAccess:allowBlobPublicAccess}"

# List all containers and their public access level
az storage container list \
  --account-name <storage-account> \
  --query "[].{name:name, publicAccess:properties.publicAccess}" \
  -o table

# Check if account keys are used (should be false)
az storage account show \
  --name <storage-account> \
  --query "allowSharedKeyAccess"
```

### 2. Determine Data Sensitivity

```bash
# Check tags for data classification
az storage account show \
  --name <storage-account> \
  --query "tags.DataSensitivity"

# List sensitive containers (PII, PHI, PCI, etc.)
# Review container naming convention
# e.g., containers starting with "pii-", "hipaa-", "pci-"
```

### 3. Check Access Logs

```bash
# Query Storage Analytics logs (if enabled)
az storage blob list \
  --account-name <storage-account> \
  --container-name '$logs' \
  --query "[].name" \
  -o tsv

# Download recent logs
az storage blob download-batch \
  --account-name <storage-account> \
  --source '$logs' \
  --destination ./logs \
  --pattern "blob/*/y=$(date +%Y)/m=$(date +%m)/d=$(date +%d)/*"

# Parse logs for anonymous access
grep "AnonymousSuccess" ./logs/*.log
```

---

## Containment (15-30 minutes)

### 1. Immediately Block Public Access

```bash
# CRITICAL: Disable public network access
az storage account update \
  --name <storage-account> \
  --resource-group <resource-group> \
  --public-network-access Disabled \
  --default-action Deny

# Disable blob public access at account level
az storage account update \
  --name <storage-account> \
  --resource-group <resource-group> \
  --allow-blob-public-access false

# Remove public access from all containers
for container in $(az storage container list --account-name <storage-account> --query "[].name" -o tsv); do
  az storage container set-permission \
    --name $container \
    --account-name <storage-account> \
    --public-access off
done
```

### 2. Rotate Storage Keys

```bash
# Rotate both keys (one at a time if apps are using keys)
az storage account keys renew \
  --account-name <storage-account> \
  --resource-group <resource-group> \
  --key primary

# After apps updated, rotate secondary
az storage account keys renew \
  --account-name <storage-account> \
  --resource-group <resource-group> \
  --key secondary

# Disable shared key access (force Entra ID only)
az storage account update \
  --name <storage-account> \
  --resource-group <resource-group> \
  --allow-shared-key-access false
```

### 3. Revoke Active SAS Tokens

```bash
# Unfortunately, Azure doesn't support direct SAS token revocation
# Two options:

# Option A: Create new User Delegation SAS (Entra ID-based)
# Then revoke the Entra identity's access

# Option B: Rotate storage account key (invalidates all SAS tokens)
# Already done above

# Option C: Set stored access policy expiry to past (if SAS uses policy)
az storage container policy update \
  --name <policy-name> \
  --container-name <container-name> \
  --account-name <storage-account> \
  --expiry "2020-01-01T00:00:00Z"
```

### 4. Enable Defender for Storage (if not already)

```bash
az security pricing create \
  --name StorageAccounts \
  --tier Standard
```

---

## Eradication (30-60 minutes)

### 1. Identify What Was Accessed

```bash
# Parse storage logs for unique IPs
cat ./logs/*.log | grep "AnonymousSuccess" | cut -d';' -f10 | sort -u > accessed-ips.txt

# Check IP reputation
# Use threat intelligence feeds or VirusTotal

# Identify which blobs were accessed
cat ./logs/*.log | grep "AnonymousSuccess" | cut -d';' -f8 | sort -u > accessed-blobs.txt
```

### 2. Check for Data Modification

```bash
# Look for write operations
cat ./logs/*.log | grep -E "PutBlob|PutBlock|DeleteBlob|DeleteContainer"

# Check blob versioning (if enabled)
az storage blob list \
  --account-name <storage-account> \
  --container-name <container-name> \
  --include v \
  --query "[?versionId!=null]"

# Restore deleted blobs (if soft delete enabled)
az storage blob undelete \
  --account-name <storage-account> \
  --container-name <container-name> \
  --name <blob-name>
```

### 3. Quarantine Affected Data

```bash
# Move suspicious or accessed data to quarantine container
az storage container create \
  --name quarantine-$(date +%Y%m%d) \
  --account-name <storage-account> \
  --public-access off

# Copy affected blobs
for blob in $(cat accessed-blobs.txt); do
  az storage blob copy start \
    --source-account-name <storage-account> \
    --source-container <container> \
    --source-blob $blob \
    --destination-account-name <storage-account> \
    --destination-container quarantine-$(date +%Y%m%d) \
    --destination-blob $blob
done
```

---

## Recovery (1-4 hours)

### 1. Implement Proper Access Controls

```bash
# Create private endpoint
az network private-endpoint create \
  --name pe-storage-<name> \
  --resource-group <resource-group> \
  --vnet-name <vnet-name> \
  --subnet <subnet-name> \
  --private-connection-resource-id <storage-resource-id> \
  --connection-name storage-connection \
  --group-id blob

# Update DNS
az network private-dns zone create \
  --resource-group <resource-group> \
  --name privatelink.blob.core.windows.net

az network private-dns link vnet create \
  --resource-group <resource-group> \
  --zone-name privatelink.blob.core.windows.net \
  --name <link-name> \
  --virtual-network <vnet-id> \
  --registration-enabled false
```

### 2. Enable Advanced Threat Protection Features

```bash
# Enable versioning
az storage account blob-service-properties update \
  --account-name <storage-account> \
  --enable-versioning true

# Enable soft delete
az storage account blob-service-properties update \
  --account-name <storage-account> \
  --enable-delete-retention true \
  --delete-retention-days 90

# Enable change feed
az storage account blob-service-properties update \
  --account-name <storage-account> \
  --enable-change-feed true

# Enable point-in-time restore (if supported)
az storage account blob-service-properties update \
  --account-name <storage-account> \
  --enable-restore-policy true \
  --restore-days 7
```

### 3. Update Applications to Use Managed Identities

```bash
# App Service: Enable managed identity
az webapp identity assign \
  --name <app-name> \
  --resource-group <resource-group>

# Grant RBAC to storage
az role assignment create \
  --assignee <app-identity-principal-id> \
  --role "Storage Blob Data Contributor" \
  --scope <storage-resource-id>

# Update app code to use DefaultAzureCredential (no keys!)
```

### 4. Enable Comprehensive Logging

```bash
# Enable diagnostic settings
az monitor diagnostic-settings create \
  --name send-to-sentinel \
  --resource <storage-resource-id> \
  --logs '[
    {"category":"StorageRead","enabled":true},
    {"category":"StorageWrite","enabled":true},
    {"category":"StorageDelete","enabled":true}
  ]' \
  --metrics '[{"category":"Transaction","enabled":true}]' \
  --workspace <log-analytics-workspace-id>
```

---

## Post-Incident Review

### Compliance Impact Assessment

**Determine if breach notification is required:**
- **GDPR:** If PII of EU residents exposed → 72 hours to notify
- **HIPAA:** If PHI exposed → Notify HHS within 60 days
- **State Laws:** Varies by state (e.g., California CCPA)
- **PCI-DSS:** If cardholder data exposed → Notify card brands immediately

```bash
# Export evidence
az storage blob list \
  --account-name <storage-account> \
  --container-name <container-name> \
  --query "[].{name:name, lastModified:properties.lastModified}" \
  -o json > exposed-blobs-inventory.json

# Export access logs
# Already downloaded in Eradication phase
```

### Root Cause Analysis

**Common Causes:**
1. Developer testing with public access (forgot to remove)
2. Policy not enforced (audit mode vs. deny mode)
3. Overly permissive SAS token shared publicly
4. Storage account key committed to Git
5. Misconfigured ARM/Bicep template

### Corrective Actions

```bash
# 1. Enable Azure Policy to deny public access
az policy assignment create \
  --name "Deny-Storage-Public-Access" \
  --policy "/providers/Microsoft.Authorization/policyDefinitions/34c877ad-507e-4c82-993e-3452a6e0ad3c" \
  --scope "/subscriptions/<subscription-id>"

# 2. Create Sentinel rule for public access changes
# Analytics rule: "Storage account public access enabled"

# 3. Implement least privilege access
# Use RBAC, not storage keys

# 4. Enable immutability for critical data
az storage container immutability-policy create \
  --account-name <storage-account> \
  --container-name <container-name> \
  --period 365 \
  --policy-mode Locked
```

---

## Prevention Checklist

- [ ] Azure Policy: Deny public network access (enforced, not audit)
- [ ] Azure Policy: Deny blob public access (enforced)
- [ ] Private endpoints configured for all storage accounts
- [ ] Shared key access disabled (Entra ID only)
- [ ] No storage keys in code or CI/CD pipelines
- [ ] Managed identities for all applications
- [ ] Defender for Storage enabled
- [ ] Versioning + soft delete enabled
- [ ] Diagnostic settings enabled (send to Sentinel)
- [ ] Monthly access review
- [ ] Data classification tags enforced

---

## Quick Reference: Critical Commands

```bash
# Disable public access IMMEDIATELY
az storage account update --name <name> --public-network-access Disabled --default-action Deny

# Disable blob public access
az storage account update --name <name> --allow-blob-public-access false

# Rotate storage keys
az storage account keys renew --name <name> --key primary

# Enable Defender for Storage
az security pricing create --name StorageAccounts --tier Standard

# Check what was accessed
az storage blob list --account-name <name> --container-name '$logs'
```

---

**Remember: Assume the worst. If publicly accessible, assume it was accessed.**
