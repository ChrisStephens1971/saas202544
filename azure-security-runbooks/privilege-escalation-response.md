# Incident Response Runbook: Privilege Escalation

**Version:** 1.0
**Last Updated:** 2025-11-05
**Severity:** High to Critical
**MTTR Target:** 30 minutes

---

## Overview

This runbook covers response to unauthorized privilege escalation in Azure:
- User granted Global Admin role unexpectedly
- Service principal elevated to Owner role
- PIM activation without proper approval
- Azure subscription transferred to unauthorized user
- Role assignment created outside normal workflow
- Managed identity granted excessive permissions

---

## Detection Indicators

### Automated Alerts (Sentinel)
- "Privileged role assigned outside PIM"
- "User added to Global Administrator role"
- "Service principal granted Owner permissions"
- "Mass role assignments in short timeframe"
- "PIM activation from unusual location"
- "Role assignment by non-privileged user"

### Manual Discovery
- User reports access to resources they shouldn't have
- Unexpected role visible in "My roles"
- Audit log shows role assignment not requested
- Cost spike from resources created by unauthorized user

---

## Initial Response (0-10 minutes)

### 1. Identify the Escalation

```bash
# List recent role assignments
az role assignment list \
  --query "[?createdOn >= '$(date -u -d '24 hours ago' '+%Y-%m-%dT%H:%M:%SZ')']" \
  -o json > recent-role-assignments.json

# Focus on high-privilege roles
az role assignment list \
  --role "Owner" \
  --query "[].{principal:principalName, scope:scope, createdOn:createdOn}" \
  -o table

az role assignment list \
  --role "User Access Administrator" \
  --query "[].{principal:principalName, scope:scope, createdOn:createdOn}" \
  -o table

# Check Global Admin assignments (via Entra ID)
az ad directory-role member list \
  --role "Global Administrator" \
  --query "[].{displayName:displayName, userPrincipalName:userPrincipalName}" \
  -o table
```

### 2. Check the Legitimacy

```bash
# Get details of the role assignment
az role assignment show \
  --id <role-assignment-id> \
  -o json > suspicious-assignment.json

# Who granted the role?
cat suspicious-assignment.json | jq '.createdBy'

# When was it granted?
cat suspicious-assignment.json | jq '.createdOn'

# Check if it was through PIM
# Portal → Entra ID → Privileged Identity Management → Audit history
```

### 3. Verify the Identity

```bash
# Check sign-in logs for the principal
# Portal → Entra ID → Sign-in logs → Filter by user

# CLI: Get sign-in risk
az ad signed-in-user show

# Check recent activity by this principal
az monitor activity-log list \
  --caller <principal-id> \
  --start-time $(date -u -d '24 hours ago' '+%Y-%m-%dT%H:%M:%SZ') \
  -o table
```

---

## Containment (10-30 minutes)

### 1. Revoke the Elevated Role IMMEDIATELY

```bash
# Delete the role assignment
az role assignment delete \
  --id <role-assignment-id>

# Or by principal and role
az role assignment delete \
  --assignee <principal-id> \
  --role "Owner" \
  --scope "/subscriptions/<subscription-id>"

# For Entra ID roles (Global Admin, etc.)
az ad directory-role member remove \
  --role "Global Administrator" \
  --member <user-object-id>
```

### 2. Disable the Account (If Compromised)

```bash
# Disable user account
az ad user update \
  --id <user-id> \
  --account-enabled false

# Or for service principal
az ad sp update \
  --id <service-principal-id> \
  --set accountEnabled=false

# Revoke all active sessions
az rest --method POST \
  --url "https://graph.microsoft.com/v1.0/users/<user-id>/revokeSignInSessions"
```

### 3. Reset Credentials

```bash
# Force password reset for user
az ad user update \
  --id <user-id> \
  --force-change-password-next-sign-in true

# Rotate service principal credentials
az ad app credential reset \
  --id <application-id>

# Update Key Vault with new secret
az keyvault secret set \
  --vault-name <key-vault> \
  --name sp-secret \
  --value "<new-secret>"
```

### 4. Lock Down Subscription

```bash
# If entire subscription compromised, lock it
az lock create \
  --name EmergencyLock \
  --lock-type CanNotDelete \
  --resource-group <resource-group>

# Or at subscription level
az lock create \
  --name EmergencyLock \
  --lock-type CanNotDelete \
  --subscription <subscription-id>
```

---

## Eradication (30-60 minutes)

### 1. Identify Attack Path

```bash
# How did attacker gain initial access?
# Check sign-in logs for unusual patterns

# Export sign-in logs
az monitor activity-log list \
  --resource-type "Microsoft.AAD/SignInLogs" \
  --start-time $(date -u -d '7 days ago' '+%Y-%m-%dT%H:%M:%SZ') \
  -o json > signin-logs.json

# Look for:
# - Impossible travel
# - Anonymous IP
# - Unfamiliar location
# - Multiple failed attempts before success
```

### 2. Check for Backdoors

```bash
# List all Owner/UAA role assignments
az role assignment list \
  --role "Owner" \
  -o json > all-owners.json

az role assignment list \
  --role "User Access Administrator" \
  -o json > all-uaa.json

# Check for:
# - Service principals with Owner
# - Users not in approved list
# - Assignments at broad scopes (subscription, management group)

# List all service principals
az ad sp list --all --query "[].{displayName:displayName, appId:appId}" -o table

# Check for newly created service principals
az ad sp list --all \
  --query "[?createdDateTime >= '$(date -u -d '30 days ago' '+%Y-%m-%dT%H:%M:%SZ')']" \
  -o table
```

### 3. Audit All Role Assignments

```bash
# Export all role assignments for review
az role assignment list -o json > all-role-assignments-$(date +%Y%m%d).json

# Group by principal
cat all-role-assignments-$(date +%Y%m%d).json | jq 'group_by(.principalName)'

# Identify assignments that violate least privilege
# Remove any that are not justified
```

### 4. Check for Malicious Activity

```kusto
// Sentinel KQL query
let suspiciousUser = "<compromised-user-id>";
AzureActivity
| where TimeGenerated > ago(30d)
| where Caller == suspiciousUser or CallerIpAddress == "<suspicious-ip>"
| where ActivityStatusValue == "Success"
| summarize count() by OperationNameValue, ResourceGroup
| order by count_ desc
```

**Look for:**
- VM creation (cryptomining)
- Storage account creation (data exfiltration)
- Role assignments (persistence)
- Key Vault access (credential theft)
- Resource deletion (sabotage)

---

## Recovery (1-4 hours)

### 1. Implement Proper RBAC

```bash
# Use least privilege
# Grant specific roles, not Owner

# Example: Grant only VM contributor, not full Contributor
az role assignment create \
  --assignee <principal-id> \
  --role "Virtual Machine Contributor" \
  --resource-group <resource-group>

# Use custom roles for fine-grained control
az role definition create --role-definition @custom-role.json
```

**Custom Role Example:**
```json
{
  "Name": "VM Operator - Read Only",
  "Description": "Can view VMs and start/stop, but not create/delete",
  "Actions": [
    "Microsoft.Compute/virtualMachines/read",
    "Microsoft.Compute/virtualMachines/start/action",
    "Microsoft.Compute/virtualMachines/restart/action",
    "Microsoft.Compute/virtualMachines/deallocate/action"
  ],
  "NotActions": [],
  "AssignableScopes": ["/subscriptions/<subscription-id>"]
}
```

### 2. Enable PIM for All Privileged Roles

```bash
# Ensure PIM is enabled (Azure AD Premium P2 required)
# Portal → Entra ID → Privileged Identity Management

# Configure PIM settings:
# - Require justification
# - Require approval
# - Require MFA on activation
# - Max activation duration: 8 hours
# - Require re-approval every 30 days
```

### 3. Implement Conditional Access for Privileged Roles

**Create CA policy:**
```json
{
  "displayName": "CA-PIM: Require MFA and compliant device for PIM activation",
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

### 4. Enable Alerts for Role Changes

```bash
# Create Sentinel analytics rule
# Alert on any role assignment at subscription scope

# KQL query:
```
```kusto
AzureActivity
| where OperationNameValue == "Microsoft.Authorization/roleAssignments/write"
| where Properties contains "Owner" or Properties contains "User Access Administrator"
| where Scope endswith "/subscriptions/<subscription-id>"
| project TimeGenerated, Caller, OperationNameValue, Properties, Scope
```

---

## Post-Incident Review

### Impact Assessment

**Questions:**
1. What resources did the attacker access?
2. Was data exfiltrated?
3. Were resources created/modified/deleted?
4. How long did attacker have elevated access?
5. What is the financial impact?

### Evidence Collection

```bash
# Export for audit:
# 1. Role assignment history
az role assignment list -o json > role-assignments-evidence.json

# 2. PIM audit history
# Portal → Entra ID → PIM → Audit history → Export

# 3. Activity logs
az monitor activity-log list \
  --start-time <incident-start> \
  --end-time <incident-end> \
  -o json > activity-logs-evidence.json

# 4. Sign-in logs
# Portal → Entra ID → Sign-in logs → Download

# 5. Sentinel incident report
# Portal → Sentinel → Incidents → Export
```

### Root Cause Analysis

**Common Attack Paths:**

1. **Compromised Global Admin Account**
   - Phished credentials
   - Weak password
   - No MFA
   - Shared account

2. **Service Principal with Owner**
   - Secret leaked in Git
   - Over-privileged CI/CD pipeline
   - No secret rotation

3. **PIM Misconfiguration**
   - No approval required
   - Auto-approval enabled
   - No justification required

4. **Azure RBAC Vulnerability**
   - Contributor + User Access Administrator = Owner
   - Misconfigured custom role
   - Inherited permissions from management group

5. **Insider Threat**
   - Malicious admin
   - Negligent user
   - Compromised employee account

---

## Prevention Checklist

**Immediate (Week 1):**
- [ ] Enable PIM for all privileged roles
- [ ] Remove all standing Owner/Global Admin assignments
- [ ] Implement approval workflow for PIM
- [ ] Enable MFA for all admin accounts
- [ ] Review all service principal permissions
- [ ] Enable Sentinel analytics rules for role changes

**Short-term (Month 1):**
- [ ] Implement least privilege RBAC
- [ ] Create custom roles (no Owner grants)
- [ ] Enable Conditional Access for admin roles
- [ ] Implement privileged access workstations (PAWs)
- [ ] Quarterly access reviews
- [ ] Service principal secret rotation (monthly)

**Long-term (Quarter 1):**
- [ ] Zero standing privileges (all PIM)
- [ ] Just-in-time access for all admin tasks
- [ ] SIEM integration (real-time monitoring)
- [ ] Automated remediation (revoke on alert)
- [ ] Regular access recertification
- [ ] Incident response drills

---

## Azure RBAC Best Practices

**Deny List:**
- ❌ Never grant Owner at subscription scope (except break-glass)
- ❌ Never grant User Access Administrator alone (always with specific resource role)
- ❌ Never use service principals with Owner
- ❌ Never share admin accounts
- ❌ Never bypass PIM approval

**Allow List:**
- ✅ Use Contributor + specific resource roles
- ✅ Use custom roles for fine-grained control
- ✅ Use managed identities (not service principals)
- ✅ Use PIM for all privileged access
- ✅ Assign roles to groups, not users

---

## Quick Reference: Critical Commands

```bash
# Revoke role assignment
az role assignment delete --id <assignment-id>

# Disable user account
az ad user update --id <user-id> --account-enabled false

# Revoke sessions
az rest --method POST --url "https://graph.microsoft.com/v1.0/users/<user-id>/revokeSignInSessions"

# List all Owner assignments
az role assignment list --role "Owner" -o table

# Force password reset
az ad user update --id <user-id> --force-change-password-next-sign-in true
```

**Sentinel KQL:**
```kusto
// Role assignment changes
AzureActivity
| where OperationNameValue == "Microsoft.Authorization/roleAssignments/write"
| where Properties contains "Owner"
| project TimeGenerated, Caller, Properties, Scope
```

---

**Remember: Revoke first, investigate later. Every second counts.**
