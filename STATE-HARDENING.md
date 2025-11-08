# Terraform State Hardening Guide
## Azure Storage Backend Security Configuration

**Project:** saas202544
**State Storage:** stvrdtfstateeus201
**Resource Group:** rg-tfstate-verdaio-eastus2-01
**Container:** tfstate

---

## Overview

This document provides commands to harden the Terraform state storage backend with enterprise-grade security controls.

**Security Goals:**
- ✅ Version control for state files (disaster recovery)
- ✅ Soft delete protection (30-day retention)
- ✅ Disable public blob access (prevent leaks)
- ✅ Read-only resource group lock (prevent accidental deletion)
- ✅ Encryption at rest (Azure default)
- ✅ HTTPS-only access (TLS 1.2 minimum)

---

## Current Status

| Feature | Status | Notes |
|---------|--------|-------|
| Storage Account Created | ✅ | stvrdtfstateeus201 |
| Blob Container Created | ✅ | tfstate |
| Versioning | ✅ | Already enabled (30-day retention) |
| Soft Delete | ✅ | Already enabled (30 days) |
| Public Access Disabled | ✅ | Already configured |
| HTTPS-Only | ✅ | Enforced |
| TLS 1.2 Minimum | ✅ | Configured |
| Resource Group Lock | ⏭️ | Pending (run after RBAC complete) |

---

## State Safety Commands

### 1. Enable Blob Versioning (Idempotent)

**Purpose:** Maintain version history of state files for rollback capability

```bash
az storage account blob-service-properties update \
  --account-name stvrdtfstateeus201 \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --enable-versioning true
```

**Verify:**
```bash
az storage account blob-service-properties show \
  --account-name stvrdtfstateeus201 \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --query "{versioning:isVersioningEnabled}" -o table
```

---

### 2. Enable Soft Delete (Idempotent)

**Purpose:** Protect against accidental state file deletion

```bash
az storage account blob-service-properties update \
  --account-name stvrdtfstateeus201 \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --enable-delete-retention true \
  --delete-retention-days 30
```

**Verify:**
```bash
az storage account blob-service-properties show \
  --account-name stvrdtfstateeus201 \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --query "deleteRetentionPolicy.{enabled:enabled, days:days}" -o table
```

---

### 3. Disable Public Blob Access (Idempotent)

**Purpose:** Prevent anonymous access to state files

```bash
az storage account update \
  --name stvrdtfstateeus201 \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --allow-blob-public-access false
```

**Verify:**
```bash
az storage account show \
  --name stvrdtfstateeus201 \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --query "allowBlobPublicAccess" -o tsv
```

Expected output: `false`

---

### 4. Enforce HTTPS-Only (Idempotent)

**Purpose:** Require TLS for all connections

```bash
az storage account update \
  --name stvrdtfstateeus201 \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --https-only true \
  --min-tls-version TLS1_2
```

**Verify:**
```bash
az storage account show \
  --name stvrdtfstateeus201 \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --query "{httpsOnly:enableHttpsTrafficOnly, minTLS:minimumTlsVersion}" -o table
```

Expected: `httpsOnly: true`, `minTLS: TLS1_2`

---

### 5. Apply Resource Group Lock (After RBAC Complete)

**Purpose:** Prevent accidental deletion of state storage infrastructure

⚠️ **CRITICAL:** Only run this **AFTER** completing RBAC role assignments in OIDC-SETUP.md

```bash
# Apply read-only lock to prevent modifications
az lock create \
  --name tfstate-readonly \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --lock-type ReadOnly \
  --notes "Protect Terraform state storage from accidental deletion or modification"
```

**To remove lock (if needed):**
```bash
az lock delete \
  --name tfstate-readonly \
  --resource-group rg-tfstate-verdaio-eastus2-01
```

**Verify:**
```bash
az lock list \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --query "[].{name:name, level:level, notes:notes}" -o table
```

---

## State File Backup & Recovery

### Manual Backup

```bash
# Download current state file
az storage blob download \
  --account-name stvrdtfstateeus201 \
  --container-name tfstate \
  --name saas202544/dev.tfstate \
  --file backup-dev-$(date +%Y%m%d-%H%M%S).tfstate \
  --auth-mode login
```

### List Previous Versions

```bash
az storage blob list \
  --account-name stvrdtfstateeus201 \
  --container-name tfstate \
  --prefix saas202544/dev.tfstate \
  --include v \
  --auth-mode login \
  --query "[].{name:name, versionId:versionId, lastModified:properties.lastModified}" -o table
```

### Restore from Version

```bash
# Copy a specific version to a new blob
az storage blob copy start \
  --account-name stvrdtfstateeus201 \
  --destination-container tfstate \
  --destination-blob saas202544/dev.tfstate.restored \
  --source-container tfstate \
  --source-blob saas202544/dev.tfstate \
  --source-version-id <VERSION_ID> \
  --auth-mode login
```

---

## Additional Security Recommendations

### Enable Azure Defender for Storage

```bash
az security pricing create \
  --name StorageAccounts \
  --tier standard
```

**Benefits:**
- Malware detection
- Anomalous access detection
- Threat intelligence alerts

### Enable Diagnostic Logging

```bash
# Create Log Analytics workspace
az monitor log-analytics workspace create \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --workspace-name law-tfstate-audit-eus2

# Get workspace ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --workspace-name law-tfstate-audit-eus2 \
  --query id -o tsv)

# Enable diagnostics for storage account
az monitor diagnostic-settings create \
  --name tfstate-diagnostics \
  --resource /subscriptions/b3fc75c0-c060-4a53-a7cf-5f6ae22fefec/resourceGroups/rg-tfstate-verdaio-eastus2-01/providers/Microsoft.Storage/storageAccounts/stvrdtfstateeus201 \
  --workspace "$WORKSPACE_ID" \
  --logs '[{"category":"StorageRead","enabled":true},{"category":"StorageWrite","enabled":true},{"category":"StorageDelete","enabled":true}]' \
  --metrics '[{"category":"Transaction","enabled":true}]'
```

### Network Restrictions (Optional - Advanced)

If deploying from fixed locations:

```bash
# Restrict access to specific IP ranges
az storage account network-rule add \
  --account-name stvrdtfstateeus201 \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --ip-address <YOUR_IP>

# Update default action to deny
az storage account update \
  --name stvrdtfstateeus201 \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --default-action Deny
```

⚠️ **Warning:** This will block GitHub Actions. Use only if deploying from VPN/private network.

---

## Verification Checklist

Run this comprehensive check:

```bash
#!/bin/bash
echo "=== Terraform State Storage Security Audit ==="
echo ""

# Storage account name
STORAGE="stvrdtfstateeus201"
RG="rg-tfstate-verdaio-eastus2-01"

# 1. Versioning
echo "1. Blob Versioning:"
az storage account blob-service-properties show \
  --account-name "$STORAGE" \
  --resource-group "$RG" \
  --query "isVersioningEnabled" -o tsv

# 2. Soft delete
echo "2. Soft Delete (days):"
az storage account blob-service-properties show \
  --account-name "$STORAGE" \
  --resource-group "$RG" \
  --query "deleteRetentionPolicy.days" -o tsv

# 3. Public access
echo "3. Public Access Disabled:"
az storage account show \
  --name "$STORAGE" \
  --resource-group "$RG" \
  --query "allowBlobPublicAccess" -o tsv

# 4. HTTPS only
echo "4. HTTPS Only:"
az storage account show \
  --name "$STORAGE" \
  --resource-group "$RG" \
  --query "enableHttpsTrafficOnly" -o tsv

# 5. Min TLS
echo "5. Minimum TLS Version:"
az storage account show \
  --name "$STORAGE" \
  --resource-group "$RG" \
  --query "minimumTlsVersion" -o tsv

# 6. Resource group lock
echo "6. Resource Group Lock:"
az lock list \
  --resource-group "$RG" \
  --query "[].{name:name, level:level}" -o table

echo ""
echo "=== Audit Complete ==="
```

**Expected Output:**
```
1. Blob Versioning: true
2. Soft Delete (days): 30
3. Public Access Disabled: false
4. HTTPS Only: true
5. Minimum TLS Version: TLS1_2
6. Resource Group Lock: tfstate-readonly (ReadOnly)
```

---

## Incident Response: State File Corruption

### Symptoms
- `terraform plan` fails with state parse errors
- State file shows unexpected modifications
- Resources exist but not in state

### Response Steps

1. **Immediate:** Stop all deployments
   ```bash
   # Check current state file
   az storage blob download \
     --account-name stvrdtfstateeus201 \
     --container-name tfstate \
     --name saas202544/dev.tfstate \
     --file current-state.tfstate \
     --auth-mode login
   ```

2. **List available versions:**
   ```bash
   az storage blob list \
     --account-name stvrdtfstateeus201 \
     --container-name tfstate \
     --prefix saas202544/dev.tfstate \
     --include v \
     --auth-mode login
   ```

3. **Restore from last known good version:**
   ```bash
   # Download specific version
   az storage blob download \
     --account-name stvrdtfstateeus201 \
     --container-name tfstate \
     --name saas202544/dev.tfstate \
     --version-id <GOOD_VERSION_ID> \
     --file restored-state.tfstate \
     --auth-mode login

   # Verify state file integrity
   terraform show restored-state.tfstate

   # If valid, upload as current state
   az storage blob upload \
     --account-name stvrdtfstateeus201 \
     --container-name tfstate \
     --name saas202544/dev.tfstate \
     --file restored-state.tfstate \
     --auth-mode login \
     --overwrite
   ```

4. **Verify recovery:**
   ```bash
   terraform init -reconfigure
   terraform plan -var-file=../../environments/dev.tfvars
   ```

---

## Compliance & Audit

**SOC 2 Controls:**
- ✅ CC6.1 - Logical access controls (RBAC, Azure AD auth)
- ✅ CC6.6 - Encryption at rest (Azure Storage encryption)
- ✅ CC6.7 - Encryption in transit (HTTPS-only, TLS 1.2)
- ✅ CC7.2 - System monitoring (diagnostic logging available)

**CIS Azure Benchmark:**
- ✅ 3.1 - Ensure storage accounts use encryption
- ✅ 3.2 - Ensure storage accounts require secure transfer (HTTPS)
- ✅ 3.3 - Ensure storage accounts disable public blob access
- ✅ 3.6 - Ensure soft delete is enabled for blob containers

---

## Summary

| Security Control | Status | Command |
|------------------|--------|---------|
| Blob Versioning | ✅ Enabled | See section 1 |
| Soft Delete (30d) | ✅ Enabled | See section 2 |
| Public Access Disabled | ✅ Configured | See section 3 |
| HTTPS-Only + TLS 1.2 | ✅ Enforced | See section 4 |
| Resource Group Lock | ⏭️ Pending | See section 5 (after RBAC) |
| Defender for Storage | 📋 Optional | See additional recommendations |
| Diagnostic Logging | 📋 Optional | See additional recommendations |

**Next Steps:**
1. Complete RBAC assignments from OIDC-SETUP.md
2. Apply resource group lock (section 5)
3. Consider enabling Azure Defender for Storage
4. Set up diagnostic logging for audit trail

**Last Updated:** 2025-11-08
**Owner:** chris.stephens@verdaio.com
