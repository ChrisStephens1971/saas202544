# Incident Response Runbook: Ransomware Attack

**Version:** 1.0
**Last Updated:** 2025-11-05
**Severity:** Critical
**MTTR Target:** Immediate containment (15 minutes), Full recovery (24-72 hours)

---

## Overview

This runbook covers response to ransomware attacks affecting Azure resources:
- VM disk encryption by ransomware
- Storage account blob/file encryption
- Database corruption or encryption
- Backup deletion or corruption
- Lateral movement across subscriptions

**CRITICAL: DO NOT pay the ransom. Recovery is possible with proper backups.**

---

## Detection Indicators

### Automated Alerts
- Defender for Servers: Ransomware behavior detected
- Defender for Storage: Mass file deletion/modification
- Azure Backup: Backup job failures
- Sentinel: Suspicious PowerShell execution
- Cost anomaly: Unexpected compute spike (cryptomining)
- File extension changes (.locked, .encrypted, .crypt, etc.)

### Manual Discovery
- Files inaccessible or encrypted
- Ransom note in directories (README.txt, HOW_TO_DECRYPT.html)
- Desktop background changed to ransom demand
- Email from attackers with ransom demand
- Backups deleted or corrupted

---

## Initial Response (0-15 minutes)

### 1. DO NOT SHUT DOWN AFFECTED VMs

**Critical: Keep VMs running!**
- Encryption keys may be in memory
- Forensics requires live system
- Shutting down can make recovery harder

### 2. Isolate Affected Resources IMMEDIATELY

```bash
# Disconnect VM from network (remove NICs)
az vm nic remove \
  --vm-name <vm-name> \
  --resource-group <resource-group> \
  --nics <nic-id>

# Or update NSG to deny all traffic
az network nsg rule create \
  --resource-group <resource-group> \
  --nsg-name <nsg-name> \
  --name DenyAllInbound \
  --priority 100 \
  --direction Inbound \
  --access Deny \
  --protocol '*' \
  --source-address-prefixes '*' \
  --destination-address-prefixes '*' \
  --source-port-ranges '*' \
  --destination-port-ranges '*'

az network nsg rule create \
  --resource-group <resource-group> \
  --nsg-name <nsg-name> \
  --name DenyAllOutbound \
  --priority 100 \
  --direction Outbound \
  --access Deny \
  --protocol '*' \
  --source-address-prefixes '*' \
  --destination-address-prefixes '*' \
  --source-port-ranges '*' \
  --destination-port-ranges '*'
```

### 3. Activate Crisis Response Team

```bash
# CRITICAL incident - activate ALL teams
# - Security team
# - Infrastructure team
# - Legal/Compliance
# - Executive management
# - PR/Communications (if customer data affected)
# - Insurance company (cyber insurance)
```

### 4. Snapshot Everything

```bash
# Take snapshots of VM disks (for forensics)
az snapshot create \
  --resource-group <resource-group> \
  --name snapshot-<vm-name>-$(date +%Y%m%d%H%M%S) \
  --source <disk-resource-id>

# Export snapshot to immutable storage
az snapshot grant-access \
  --resource-group <resource-group> \
  --name <snapshot-name> \
  --duration-in-seconds 3600

# Download VHD
# Store in air-gapped storage for forensics
```

---

## Containment (15-60 minutes)

### 1. Identify Scope of Infection

```bash
# List all resources in subscription
az resource list --subscription <subscription-id> -o table

# Check for unusual resources (cryptomining VMs, etc.)
az vm list --query "[].{name:name, size:hardwareProfile.vmSize, location:location}" -o table

# Check for newly created storage accounts (data exfiltration)
az storage account list \
  --query "[?createdTime >= '$(date -u -d '7 days ago' '+%Y-%m-%dT%H:%M:%SZ')']" \
  -o table
```

### 2. Protect Backups Immediately

```bash
# Enable soft delete on all backups (if not already)
az backup vault backup-properties set \
  --name <vault-name> \
  --resource-group <resource-group> \
  --soft-delete-state Enable \
  --soft-delete-retention-duration 90

# Lock backup vault to prevent deletion
az lock create \
  --name CannotDelete \
  --lock-type CannotDelete \
  --resource-group <resource-group> \
  --resource-name <vault-name> \
  --resource-type Microsoft.RecoveryServices/vaults

# Verify backups are intact
az backup item list \
  --resource-group <resource-group> \
  --vault-name <vault-name> \
  -o table

# Check last successful backup
az backup job list \
  --resource-group <resource-group> \
  --vault-name <vault-name> \
  --status Completed \
  --operation Backup \
  -o table
```

### 3. Revoke Compromised Credentials

```bash
# Rotate ALL credentials in the affected subscription
# Service principals, storage keys, managed identities, etc.

# Disable all service principals
for sp_id in $(az ad sp list --query "[].id" -o tsv); do
  az ad sp update --id $sp_id --set accountEnabled=false
done

# Rotate storage account keys
for sa in $(az storage account list --query "[].name" -o tsv); do
  az storage account keys renew \
    --name $sa \
    --resource-group <resource-group> \
    --key primary
done

# Force password reset for all users
az ad user list --query "[].id" -o tsv | while read user_id; do
  az ad user update --id $user_id --force-change-password-next-sign-in true
done
```

### 4. Block Known Ransomware C2 Servers

```bash
# Update Azure Firewall rules to block known C2 IPs
# Get threat intelligence feeds

# Block at NSG level
az network nsg rule create \
  --resource-group <resource-group> \
  --nsg-name <nsg-name> \
  --name BlockC2Servers \
  --priority 90 \
  --direction Outbound \
  --access Deny \
  --protocol '*' \
  --source-address-prefixes '*' \
  --destination-address-prefixes <c2-ip-list> \
  --destination-port-ranges '*'
```

---

## Eradication (1-24 hours)

### 1. Identify Ransomware Variant

```bash
# Collect sample encrypted files
# Upload to ID Ransomware or Kaspersky's No Ransom

# Check ransom note for indicators:
# - Email addresses used
# - Bitcoin wallets
# - Tor URLs
# - Ransomware family name

# Search for decryptors
# Visit: https://www.nomoreransom.org/
```

### 2. Forensics Analysis

```bash
# Analyze VM snapshots (offline)
# Look for:
# - Initial access vector (RDP brute force, phished creds, exploit)
# - Persistence mechanisms (scheduled tasks, registry keys)
# - Lateral movement (PsExec, WMI, RDP)
# - Data staging areas
# - Exfiltration channels

# Use Azure Monitor logs to trace attacker activity
az monitor activity-log list \
  --start-time <incident-start-time> \
  --query "[?level=='Critical' || level=='Error']" \
  -o json > incident-activity.json

# Check Sentinel for attack timeline
```

### 3. Nuke and Rebuild Infected VMs

**DO NOT try to clean infected VMs. Rebuild from scratch.**

```bash
# Delete infected VMs
az vm delete \
  --name <vm-name> \
  --resource-group <resource-group> \
  --yes

# Delete infected disks
az disk delete \
  --name <disk-name> \
  --resource-group <resource-group> \
  --yes

# Deploy new VMs from clean images
az vm create \
  --name <vm-name>-new \
  --resource-group <resource-group> \
  --image <clean-image> \
  --size <vm-size> \
  --vnet-name <vnet> \
  --subnet <subnet> \
  --authentication-type ssh \
  --ssh-key-value @~/.ssh/new-key.pub
```

---

## Recovery (24-72 hours)

### 1. Restore from Backups

```bash
# Restore VM from backup
az backup restore restore-disks \
  --resource-group <resource-group> \
  --vault-name <vault-name> \
  --container-name <container-name> \
  --item-name <item-name> \
  --storage-account <storage-account> \
  --restore-to-staging-storage-account

# Restore SQL database
az sql db restore \
  --dest-name <database-name>-restored \
  --resource-group <resource-group> \
  --server <sql-server> \
  --time "2025-11-05T10:00:00Z" \
  --source-database <database-resource-id>

# Restore Storage blobs from versioning
az storage blob list \
  --account-name <storage-account> \
  --container-name <container-name> \
  --include v \
  --query "[?versionId!=null]" \
  -o table

# Restore specific version
az storage blob download \
  --account-name <storage-account> \
  --container-name <container-name> \
  --name <blob-name> \
  --version-id <version-id>
```

### 2. Verify Integrity of Restored Data

```bash
# Compare checksums of restored files
# Check database consistency
# Run application smoke tests

# SQL database integrity check
az sql db show-connection-string \
  --client sqlcmd \
  --name <database-name>

# Then run: DBCC CHECKDB ('<database-name>')
```

### 3. Harden Infrastructure

```bash
# Disable RDP from internet
az vm update \
  --name <vm-name> \
  --resource-group <resource-group> \
  --remove networkProfile.networkInterfaces[0].ipConfigurations[0].publicIpAddress

# Enable JIT access
az security jit-policy create \
  --location <location> \
  --name jit-policy \
  --resource-group <resource-group> \
  --virtual-machines <vm-resource-id> \
  --port 22 3389 \
  --protocol TCP \
  --max-request-access-duration PT3H

# Enable disk encryption with CMK
az vm encryption enable \
  --resource-group <resource-group> \
  --name <vm-name> \
  --disk-encryption-keyvault <key-vault-name> \
  --key-encryption-key <key-url>

# Enable immutable backups
az backup vault backup-properties set \
  --name <vault-name> \
  --resource-group <resource-group> \
  --soft-delete-state Enable \
  --soft-delete-retention-duration 90
```

### 4. Restore Services

```bash
# Bring services back online gradually
# Monitor for signs of reinfection

# Enable NSG rules (controlled access)
# Restore application connectivity
# Notify users of restored access
```

---

## Post-Incident Review

### Business Impact Assessment

**Calculate costs:**
- Downtime cost = (Revenue/hour) × Hours down
- Recovery costs (labor, consulting)
- Data loss impact
- Reputation damage
- Regulatory fines (if applicable)
- Insurance claim value

### Root Cause Analysis

**Common Attack Vectors:**
1. **Phishing email** → User downloads malicious attachment
2. **RDP brute force** → Weak passwords, RDP exposed to internet
3. **Software vulnerability** → Unpatched systems
4. **Supply chain attack** → Compromised software update
5. **Insider threat** → Malicious or negligent employee

### Regulatory Notifications

**May require notification:**
- **GDPR:** Data breach → 72 hours
- **HIPAA:** PHI compromised → 60 days
- **State laws:** PII compromised (varies)
- **Cyber insurance:** File claim immediately

### Evidence Preservation

```bash
# Preserve for law enforcement / insurance:
# - VM snapshots
# - Network flow logs
# - Azure Activity logs
# - Sentinel incident reports
# - Ransom note
# - Attacker communications
# - Timeline of events

# Export all logs
az monitor activity-log list \
  --start-time <incident-start> \
  --end-time <incident-end> \
  -o json > ransomware-incident-logs.json
```

---

## Prevention Checklist

**Immediate (Week 1):**
- [ ] Disable RDP/SSH from internet
- [ ] Enable JIT access via Defender
- [ ] Enable immutable backups
- [ ] Enable Defender for Servers/Storage
- [ ] Patch all VMs (critical updates)
- [ ] Enable MFA for all accounts
- [ ] Review and revoke excessive permissions

**Short-term (Month 1):**
- [ ] Implement zero trust network access
- [ ] Enable Defender for Cloud (all plans)
- [ ] Segment networks (VLANs, subnets, NSGs)
- [ ] Enable Azure Firewall with TLS inspection
- [ ] Implement application whitelisting
- [ ] Test backup restores monthly
- [ ] Conduct ransomware simulation drill

**Long-term (Quarter 1):**
- [ ] Air-gapped backup strategy
- [ ] Incident response team training
- [ ] Cyber insurance coverage
- [ ] 24/7 SOC monitoring
- [ ] EDR on all endpoints
- [ ] Network segmentation (zero trust)
- [ ] Quarterly penetration tests

---

## DO NOT Pay Ransom

**Why?**
1. No guarantee of decryption
2. Funds terrorist organizations
3. Makes you a target for repeat attacks
4. Violates sanctions (OFAC) in some cases
5. Recovery from backup is faster and cheaper

**If Recovery Fails:**
- Contact professional incident response firm
- Contact law enforcement (FBI, Secret Service)
- Check https://www.nomoreransom.org/ for decryptors
- Restore from older backups (sacrifice some data)

---

## Quick Reference: Critical Commands

```bash
# Isolate VM
az vm nic remove --vm-name <name> --nics <nic-id>

# Snapshot disk
az snapshot create --name <name> --source <disk-id>

# Protect backups
az lock create --name CannotDelete --lock-type CannotDelete --resource-group <rg> --resource-name <vault>

# Restore VM
az backup restore restore-disks --vault-name <vault> --item-name <item>

# Enable Defender
az security pricing create --name VirtualMachines --tier Standard
```

---

**Remember: Time is critical. Isolate first, investigate later. Backups are your lifeline.**
