# Azure Security Incident Response Runbooks

**Version:** 1.0
**Last Updated:** 2025-11-05
**Part of:** Azure Security Playbook (Zero-to-Production) v2.0

---

## Overview

This directory contains detailed incident response runbooks for common Azure security incidents. Each runbook provides step-by-step procedures for detection, containment, eradication, and recovery.

---

## Available Runbooks

### 1. [Credential Leak Response](credential-leak-response.md)

**Severity:** Critical | **MTTR:** 15 minutes

Covers response to compromised credentials including:
- Service principal secrets exposed in code
- Storage account keys leaked
- SSH keys or certificates compromised
- API keys published publicly

**Key Actions:**
- Rotate credentials immediately
- Revoke active sessions
- Scan for malicious activity
- Remove secrets from source control

---

### 2. [Exposed Storage Response](exposed-storage-response.md)

**Severity:** High to Critical | **MTTR:** 30 minutes

Covers response to publicly exposed Azure Storage accounts including:
- Public network access enabled
- Anonymous container access
- SAS tokens with excessive permissions
- Data exfiltration detected

**Key Actions:**
- Disable public access immediately
- Rotate storage keys
- Revoke SAS tokens
- Implement private endpoints

---

### 3. [Suspicious OAuth Consent Response](suspicious-consent-response.md)

**Severity:** High to Critical | **MTTR:** 20 minutes

Covers response to malicious OAuth application consent including:
- Consent phishing attacks
- Overly permissive app permissions
- Unverified publishers
- Illicit consent grants

**Key Actions:**
- Revoke app consent
- Disable service principal
- Revoke user refresh tokens
- Implement admin consent workflow

---

### 4. [Ransomware Response](ransomware-response.md)

**Severity:** Critical | **MTTR:** Immediate containment (15 min), Full recovery (24-72 hours)

Covers response to ransomware attacks affecting Azure resources:
- VM disk encryption
- Storage blob encryption
- Database corruption
- Backup deletion
- Lateral movement

**Key Actions:**
- Isolate affected resources (DO NOT shut down VMs)
- Snapshot everything
- Protect backups
- Nuke and rebuild infected VMs
- Restore from backups

---

### 5. [Privilege Escalation Response](privilege-escalation-response.md)

**Severity:** High to Critical | **MTTR:** 30 minutes

Covers response to unauthorized privilege escalation:
- Unauthorized Global Admin grants
- Service principal elevated to Owner
- PIM bypass
- Role assignment outside normal workflow

**Key Actions:**
- Revoke elevated role immediately
- Disable compromised account
- Reset credentials
- Audit all role assignments

---

## How to Use These Runbooks

### Before an Incident

1. **Familiarize yourself** with all runbooks
2. **Conduct tabletop exercises** quarterly
3. **Test procedures** in non-production environment
4. **Update contact information** in runbooks
5. **Ensure tools are installed** (Azure CLI, PowerShell, etc.)

### During an Incident

1. **Stay calm** - Follow the runbook step-by-step
2. **Document everything** - Screenshots, commands, timestamps
3. **Activate the team** - Don't work alone
4. **Contain first, investigate later** - Speed is critical
5. **Communicate** - Keep stakeholders informed

### After an Incident

1. **Complete post-incident review** within 48 hours
2. **Update runbook** with lessons learned
3. **Implement corrective actions** from RCA
4. **Conduct training** for the team
5. **Test improvements** in next drill

---

## Runbook Structure

Each runbook follows this standard format:

### 1. Overview
- Incident types covered
- Severity and MTTR targets

### 2. Detection Indicators
- Automated alerts (Sentinel, Defender)
- Manual discovery methods

### 3. Initial Response (0-15 minutes)
- Confirm the incident
- Activate response team
- Begin documentation

### 4. Containment (15-60 minutes)
- Stop the bleeding
- Isolate affected resources
- Prevent spread

### 5. Eradication (30-60 minutes)
- Remove the threat
- Identify attack path
- Check for backdoors

### 6. Recovery (1-24 hours)
- Restore normal operations
- Implement hardening
- Verify integrity

### 7. Post-Incident Review
- Root cause analysis
- Evidence collection
- Corrective actions
- Prevention checklist

---

## Required Tools

### Azure CLI
```bash
# Install
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login
az login

# Set subscription
az account set --subscription <subscription-id>
```

### Azure PowerShell
```powershell
# Install
Install-Module -Name Az -AllowClobber -Scope CurrentUser

# Connect
Connect-AzAccount
```

### Microsoft Graph PowerShell
```powershell
# Install
Install-Module Microsoft.Graph -Scope CurrentUser

# Connect
Connect-MgGraph -Scopes "Directory.ReadWrite.All,User.ReadWrite.All"
```

### Kusto Query Language (KQL)
- Used for Sentinel queries
- Portal → Sentinel → Logs
- Learn: https://learn.microsoft.com/azure/data-explorer/kusto/query/

---

## Key Contacts

**During an incident, contact:**

### Internal
- **Security Team:** security@verdaio.com
- **On-Call Engineer:** Use PagerDuty/On-Call rotation
- **Infrastructure Team:** infra@verdaio.com
- **Management:** executives@verdaio.com (for critical incidents)
- **Legal/Compliance:** legal@verdaio.com (for breach notifications)

### External
- **Azure Support:** Portal → Support → New support request
- **Microsoft Security Response Center:** secure@microsoft.com
- **Cyber Insurance:** [Your insurance provider contact]
- **Law Enforcement:** FBI Cyber Division (for ransomware, APT)

---

## Escalation Matrix

| Severity | Initial Response | Escalation (15 min) | Executive Escalation (30 min) |
|----------|-----------------|---------------------|------------------------------|
| **Critical** | Security Team + On-Call | + Infrastructure Team | + CEO, COO, Legal |
| **High** | Security Team + On-Call | + Infrastructure Team | + CTO, Legal |
| **Medium** | Security Team | + On-Call Engineer | + CISO |
| **Low** | On-Call Engineer | + Security Team | (If pattern emerges) |

---

## Common Commands Reference

### Role Management
```bash
# List all Owner assignments
az role assignment list --role "Owner" -o table

# Revoke role
az role assignment delete --id <assignment-id>

# List recent role changes
az role assignment list --query "[?createdOn >= '$(date -u -d '24 hours ago')']"
```

### Account Management
```bash
# Disable user
az ad user update --id <user-id> --account-enabled false

# Force password reset
az ad user update --id <user-id> --force-change-password-next-sign-in true

# Revoke sessions
az rest --method POST --url "https://graph.microsoft.com/v1.0/users/<user-id>/revokeSignInSessions"
```

### Storage Security
```bash
# Disable public access
az storage account update --name <name> --public-network-access Disabled

# Rotate keys
az storage account keys renew --name <name> --key primary

# Check blob access level
az storage container list --account-name <name> --query "[].{name:name, publicAccess:properties.publicAccess}"
```

### VM Operations
```bash
# Disconnect VM from network
az vm nic remove --vm-name <name> --nics <nic-id>

# Snapshot disk
az snapshot create --name <name> --source <disk-id>

# Enable JIT access
az security jit-policy create --name <name> --resource-group <rg> --virtual-machines <vm-id>
```

### Logging & Monitoring
```bash
# Export activity logs
az monitor activity-log list --start-time <time> -o json > logs.json

# Query Sentinel
# Use Portal → Sentinel → Logs

# Enable diagnostic settings
az monitor diagnostic-settings create --name <name> --resource <resource-id> --workspace <workspace-id>
```

---

## Testing & Validation

### Quarterly Drills

**Schedule:**
- Q1: Credential leak simulation
- Q2: Ransomware tabletop exercise
- Q3: Privilege escalation drill
- Q4: Multi-incident chaos drill

**Metrics to Track:**
- Mean Time to Detect (MTTD)
- Mean Time to Respond (MTTR)
- Mean Time to Recover (MTTrec)
- False positive rate
- Runbook accuracy

---

## Continuous Improvement

### After Each Incident or Drill

1. **Review runbook effectiveness**
   - What worked well?
   - What was unclear?
   - What was missing?

2. **Update runbooks**
   - Add new commands discovered
   - Clarify ambiguous steps
   - Add screenshots if helpful

3. **Share learnings**
   - Distribute post-incident report
   - Conduct team training
   - Update documentation

---

## Compliance & Audit

These runbooks support compliance with:
- **SOC 2 Type II:** Incident response procedures (CC7.4, CC7.5)
- **ISO 27001:** Incident management (A.16)
- **HIPAA:** Security incident procedures (164.308(a)(6))
- **PCI-DSS:** Incident response plan (Requirement 12.10)
- **NIST CSF:** Respond function (RS)

**Evidence to Maintain:**
- Incident tickets with timestamps
- Runbook execution logs
- Post-incident review reports
- Training completion records
- Drill results and metrics

---

## Additional Resources

### Microsoft Documentation
- [Azure Security Best Practices](https://learn.microsoft.com/azure/security/fundamentals/best-practices-and-patterns)
- [Incident Response Overview](https://learn.microsoft.com/security/operations/incident-response-overview)
- [Azure Sentinel Playbooks](https://learn.microsoft.com/azure/sentinel/tutorial-respond-threats-playbook)

### External Resources
- [NIST Incident Response Guide](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-61r2.pdf)
- [SANS Incident Handler's Handbook](https://www.sans.org/white-papers/33901/)
- [No More Ransom Project](https://www.nomoreransom.org/)

### Threat Intelligence
- [Microsoft Threat Intelligence](https://www.microsoft.com/en-us/security/business/threat-intelligence)
- [Azure Security Blog](https://azure.microsoft.com/blog/topics/security/)
- [CISA Alerts](https://www.cisa.gov/uscert/ncas/alerts)

---

## Feedback & Updates

**Report issues or suggest improvements:**
- Security Team: security@verdaio.com
- GitHub Issues: [Repository URL if applicable]
- Slack: #security-team

**Review Schedule:**
- Monthly: Update contact information
- Quarterly: Review after each drill
- Annually: Comprehensive runbook update

---

**Version:** 1.0
**Status:** Production-Ready
**Part of:** Azure Security Playbook v2.0
**Last Updated:** 2025-11-05
