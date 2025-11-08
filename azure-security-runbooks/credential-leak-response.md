# Incident Response Runbook: Credential Leak

**Version:** 1.0
**Last Updated:** 2025-11-05
**Severity:** Critical
**MTTR Target:** 15 minutes

---

## Overview

This runbook covers the response to compromised credentials including:
- Azure service principal secrets exposed in code repositories
- Access keys (storage, database, etc.) leaked in logs or public
- SSH keys or certificates exposed
- API keys published publicly

---

## Detection Indicators

### Automated Alerts (Sentinel)
- Secret scanning alerts from GitHub/GitLab
- Unusual authentication from new locations
- Mass resource creation or deletion
- Azure Key Vault accessed from unexpected IPs
- Service principal used outside normal hours

### Manual Discovery
- Accidental commit of `.env` file
- Keys posted in public Slack/Teams channels
- Secret sent via email
- Configuration file exposed in public repo

---

## Initial Response (0-15 minutes)

### 1. Confirm the Incident

```bash
# Check recent sign-ins for the principal
az ad signed-in-user list-owned-objects

# Check Azure Activity Log for suspicious operations
az monitor activity-log list \
  --start-time $(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ') \
  --query "[].{time:eventTimestamp, user:caller, operation:operationName.localizedValue, status:status.localizedValue}" \
  -o table

# Check Sentinel for related alerts
# Portal → Sentinel → Incidents
```

### 2. Activate Incident Response Team

```bash
# Send alert to security team
# Use pre-configured Teams webhook or email
curl -X POST <teams-webhook-url> \
  -H "Content-Type: application/json" \
  -d '{
    "title": "CRITICAL: Credential Leak Detected",
    "text": "Service principal credentials exposed in GitHub repo: repo-name",
    "themeColor": "ff0000"
  }'
```

### 3. Document Everything

```bash
# Create incident ticket
# Record: Time detected, source of leak, scope of access, initial actions
```

---

## Containment (15-30 minutes)

### For Service Principals / App Registrations

```bash
# IMMEDIATELY rotate the secret
az ad app credential reset \
  --id <application-id> \
  --display-name "emergency-rotation-$(date +%Y%m%d%H%M%S)"

# Save new secret securely
# Store in Key Vault, NOT in terminal history

# Revoke ALL existing credentials
az ad app credential delete \
  --id <application-id> \
  --key-id <old-key-id>

# Check what resources the principal has accessed
az role assignment list \
  --assignee <principal-id> \
  --query "[].{scope:scope, role:roleDefinitionName}" \
  -o table

# If highly privileged, consider disabling the principal
az ad sp update \
  --id <service-principal-id> \
  --set accountEnabled=false
```

### For Storage Account Keys

```bash
# Rotate storage account keys
az storage account keys renew \
  --account-name <storage-account> \
  --resource-group <resource-group> \
  --key primary

# Update applications with new key (via Key Vault reference)
az keyvault secret set \
  --vault-name <key-vault> \
  --name storage-account-key \
  --value "<new-key>"

# Review storage access logs
az storage blob list \
  --account-name <storage-account> \
  --container-name '$logs' \
  --num-results 1000
```

### For Database Connection Strings

```bash
# Rotate SQL admin password
az sql server update \
  --name <sql-server> \
  --resource-group <resource-group> \
  --admin-password "<new-strong-password>"

# Update Key Vault reference
az keyvault secret set \
  --vault-name <key-vault> \
  --name sql-connection-string \
  --value "<new-connection-string>"

# Check for suspicious database activity
# Query SQL audit logs for unusual patterns
```

### For SSH Keys / Certificates

```bash
# Remove compromised SSH key from all VMs
az vm user update \
  --name <vm-name> \
  --resource-group <resource-group> \
  --username <username> \
  --ssh-key-value "$(cat new-key.pub)"

# Rotate VM certificates
# Redeploy certificate via Key Vault integration
```

---

## Eradication (30-60 minutes)

### 1. Remove the Exposed Secret from Source

```bash
# For Git repositories: Use BFG Repo-Cleaner or git-filter-repo
git filter-repo --path-glob '*.env' --invert-paths
git push --force --all

# IMPORTANT: Force all developers to re-clone
# Old clones still have the secret in history!

# For GitHub: Notify GitHub Security to invalidate exposed secrets
# GitHub will automatically revoke detected Azure secrets
```

### 2. Invalidate All Active Sessions

```bash
# Revoke all refresh tokens for user accounts (if user creds leaked)
az ad user update \
  --id <user-id> \
  --force-change-password-next-sign-in true

# For service principals: Rotation (done in Containment) invalidates old tokens
```

### 3. Scan for Malicious Activity

```bash
# Check for newly created resources
az resource list \
  --query "[?provisioningState=='Succeeded' && createdTime >= '$(date -u -d '2 hours ago' '+%Y-%m-%dT%H:%M:%SZ')']" \
  -o table

# Check for new role assignments
az role assignment list \
  --query "[?createdOn >= '$(date -u -d '2 hours ago' '+%Y-%m-%dT%H:%M:%SZ')']" \
  -o table

# Review firewall logs for unusual egress
# Portal → Azure Firewall → Logs
```

### 4. Check for Data Exfiltration

```bash
# Review Storage account egress metrics
az monitor metrics list \
  --resource <storage-account-resource-id> \
  --metric Egress \
  --start-time $(date -u -d '24 hours ago' '+%Y-%m-%dT%H:%M:%SZ') \
  --interval PT1H \
  -o table

# Check for large SQL queries or exports
# Review SQL audit logs

# Review Key Vault access logs
az monitor diagnostic-settings show \
  --resource <key-vault-resource-id>
```

---

## Recovery (1-4 hours)

### 1. Rotate ALL Potentially Affected Credentials

```bash
# Even if not directly exposed, rotate related secrets
# Better safe than sorry

# List all secrets in Key Vault
az keyvault secret list \
  --vault-name <key-vault> \
  --query "[].name" \
  -o tsv

# Rotate each one systematically
```

### 2. Update Applications

```bash
# Restart App Services to pick up new Key Vault references
az webapp restart \
  --name <app-name> \
  --resource-group <resource-group>

# For AKS: Rollout restart
kubectl rollout restart deployment/<deployment-name>

# For VMs: Update configuration and restart services
```

### 3. Restore Normal Operations

```bash
# Re-enable service principal if disabled
az ad sp update \
  --id <service-principal-id> \
  --set accountEnabled=true

# Verify applications are functioning
# Run smoke tests
```

---

## Post-Incident Review (24-48 hours)

### Root Cause Analysis

**Questions to Answer:**
1. How was the secret exposed?
   - Committed to Git?
   - Logged in plain text?
   - Sent in email/Slack?
   - Exposed in error message?

2. Why wasn't it caught earlier?
   - Was pre-commit hook bypassed?
   - Was secret scanning disabled?
   - Was the pattern not recognized?

3. What was the scope of access?
   - Which resources were accessible?
   - What actions could be performed?
   - Was any data accessed or exfiltrated?

4. How long was the secret exposed?
   - When was it first committed/published?
   - When was it detected?
   - MTTR = Detection Time - Exposure Time

### Corrective Actions

```bash
# 1. Implement pre-commit hooks
cp .githooks/pre-commit .git/hooks/
chmod +x .git/hooks/pre-commit
git config core.hooksPath .githooks

# 2. Enable GitHub secret scanning
# Repository → Settings → Security → Secret scanning → Enable

# 3. Add Sentinel rule for future detection
# Create custom analytics rule for unusual credential usage

# 4. Update incident response runbook
# Document lessons learned

# 5. Conduct team training
# Schedule security awareness session
```

### Evidence Collection

```bash
# Collect for audit/compliance:
# - Timeline of events
# - Azure Activity Log export
# - Sentinel incident details
# - All credential rotation logs
# - Post-incident review document

az monitor activity-log list \
  --start-time <incident-start> \
  --end-time <incident-end> \
  --query "[].{time:eventTimestamp, user:caller, operation:operationName.localizedValue}" \
  -o json > incident-activity-log.json
```

---

## Prevention Checklist

**Before the next incident:**

- [ ] Pre-commit hooks installed on all developer machines
- [ ] GitHub secret scanning enabled on all repositories
- [ ] No secrets in code (100% Key Vault references)
- [ ] OIDC federation for CI/CD (no static secrets)
- [ ] Azure Policy enforces Key Vault references
- [ ] Sentinel rules active for unusual credential usage
- [ ] Monthly secret rotation automated
- [ ] Developer security training completed
- [ ] Incident response drill completed

---

## Key Contacts

- **Security Team:** security@verdaio.com
- **On-Call Engineer:** Use PagerDuty/On-Call rotation
- **Azure Support:** Use Azure Portal → Support
- **Management:** Escalate for critical incidents

---

## Quick Reference: Critical Commands

```bash
# Rotate service principal secret
az ad app credential reset --id <app-id>

# Disable service principal
az ad sp update --id <sp-id> --set accountEnabled=false

# Rotate storage key
az storage account keys renew --account-name <name> --key primary

# Force password reset
az ad user update --id <user-id> --force-change-password-next-sign-in true

# Check recent activity
az monitor activity-log list --start-time <time> -o table
```

---

**Remember: Speed is critical. ROTATE FIRST, investigate later.**
