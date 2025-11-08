# Incident Response Runbook: Suspicious OAuth Consent Grant

**Version:** 1.0
**Last Updated:** 2025-11-05
**Severity:** High to Critical
**MTTR Target:** 20 minutes

---

## Overview

This runbook covers response to suspicious OAuth application consent including:
- User granted consent to malicious OAuth app
- Overly permissive app permissions (Mail.Read, Files.ReadWrite.All, etc.)
- App with suspicious publisher or no verified publisher
- Consent phishing attack
- Illicit consent grant from compromised account

---

## Detection Indicators

### Automated Alerts (Sentinel)
- "Suspicious OAuth app file download activities"
- "OAuth app with suspicious Graph API permissions"
- "Mass consent grants to same application"
- "Consent granted to app with no verified publisher"
- "Application with suspicious redirect URI"

### Manual Discovery
- User reports unexpected OAuth consent request
- App appears in user's "My Apps" that they don't recognize
- Unexpected emails being sent from user accounts
- Files being accessed or shared without user knowledge

---

## Initial Response (0-10 minutes)

### 1. Identify the Malicious Application

```bash
# Get details about the app
az ad app show --id <application-id>

# Check app permissions
az ad app permission list \
  --id <application-id> \
  --query "[]" \
  -o json > app-permissions.json

# List all users who granted consent
az ad sp show --id <service-principal-id> \
  --query "oauth2PermissionGrants" \
  -o json
```

### 2. Check App Activity

```bash
# Review sign-in logs for the app
# Portal → Entra ID → Sign-in logs → Filter by Application ID

# Export via CLI
az monitor activity-log list \
  --start-time $(date -u -d '7 days ago' '+%Y-%m-%dT%H:%M:%SZ') \
  --query "[?contains(resourceId, '<application-id>')]" \
  -o json > app-activity.json
```

### 3. Assess Permissions Granted

**High-Risk Permissions to Watch For:**
- `Mail.Read` / `Mail.ReadWrite` - Can read/modify all emails
- `Mail.Send` - Can send emails as user
- `Files.Read.All` / `Files.ReadWrite.All` - Can access all OneDrive/SharePoint files
- `User.Read.All` - Can read all user profiles
- `Directory.Read.All` - Can read directory data
- `offline_access` - Can get refresh tokens (persistent access)

---

## Containment (10-20 minutes)

### 1. Revoke All Consent for the Application

```bash
# Get service principal ID
SP_ID=$(az ad sp list --display-name "<app-name>" --query "[0].id" -o tsv)

# Revoke all OAuth permissions
az ad app permission delete \
  --id <application-id>

# Revoke all user consent grants
# This requires PowerShell or Graph API
```

**PowerShell:**
```powershell
Connect-MgGraph -Scopes "DelegatedPermissionGrant.ReadWrite.All"

# Get all consent grants for this app
$grants = Get-MgOauth2PermissionGrant -Filter "clientId eq '$SP_ID'"

# Revoke each grant
foreach ($grant in $grants) {
  Remove-MgOauth2PermissionGrant -OAuth2PermissionGrantId $grant.Id
}
```

### 2. Disable the Application

```bash
# Disable the service principal (prevents new sign-ins)
az ad sp update \
  --id <service-principal-id> \
  --set accountEnabled=false

# Or delete it entirely if confirmed malicious
az ad sp delete --id <service-principal-id>
```

### 3. Revoke Refresh Tokens for Affected Users

```bash
# For each affected user, revoke all refresh tokens
az ad user update \
  --id <user-id> \
  --force-change-password-next-sign-in false

# Revoke all refresh tokens
az rest --method POST \
  --url "https://graph.microsoft.com/v1.0/users/<user-id>/revokeSignInSessions"
```

### 4. Reset Passwords for Compromised Accounts

```bash
# If the consent grant was made by a compromised account
az ad user update \
  --id <user-id> \
  --force-change-password-next-sign-in true
```

---

## Eradication (20-60 minutes)

### 1. Identify Data Access

```bash
# Check what the app accessed via Graph API
# Query Azure AD audit logs for Graph API calls by this app

# Export audit logs
az monitor activity-log list \
  --start-time $(date -u -d '30 days ago' '+%Y-%m-%dT%H:%M:%SZ') \
  --resource-type "Microsoft.Graph" \
  --query "[?contains(caller, '<application-id>')]" \
  -o json > graph-api-activity.json

# Check mailbox access (if Mail.Read granted)
# Use Microsoft 365 Defender / Purview audit logs
# Search-UnifiedAuditLog -Operations MailItemsAccessed
```

### 2. Check for Data Exfiltration

```kusto
// Sentinel KQL query
let appId = "<application-id>";
AuditLogs
| where TimeGenerated > ago(30d)
| where InitiatedBy.app.appId == appId
| where ActivityDisplayName in ("Download file", "Send mail", "Create share link")
| project TimeGenerated, ActivityDisplayName, TargetResources, InitiatedBy
| order by TimeGenerated desc
```

### 3. Review Application Registration

```bash
# Check if app was registered in our tenant (insider threat)
az ad app list \
  --query "[?appId=='<application-id>']"

# If so, check who created it
az ad app owner list --id <application-id>

# Check redirect URIs (should be HTTPS, not localhost or suspicious domains)
az ad app show --id <application-id> \
  --query "web.redirectUris"
```

### 4. Block the Application Tenant-Wide

```bash
# If external app, block it tenant-wide
# Portal → Entra ID → Enterprise applications → <app> → Properties → "Enabled for users to sign in?" → No

# Via CLI (if app is Enterprise App)
az ad sp update \
  --id <service-principal-id> \
  --set accountEnabled=false
```

---

## Recovery (1-4 hours)

### 1. Implement Admin Consent Workflow

```bash
# Disable user consent for apps
# Portal → Entra ID → Enterprise applications → Consent and permissions
# → User consent settings → "Do not allow user consent"

# Enable Admin Consent Workflow
# Portal → Entra ID → Enterprise applications → Consent and permissions
# → Admin consent requests → Enable

# Set reviewers: Security team members
```

### 2. Create Conditional Access Policy

```bash
# Create CA policy to block risky apps
# Policy conditions:
# - Target: All users
# - Cloud apps: All apps
# - Conditions: App risk = High
# - Grant: Block access

# Unfortunately, no CLI for CA policies yet
# Use Portal or Graph API
```

### 3. Enable App Governance (Microsoft Defender for Cloud Apps)

```bash
# Enable Defender for Cloud Apps app governance
# Portal → Microsoft 365 Defender → Cloud Apps → App Governance

# Create policies:
# - Alert on new app with high-risk permissions
# - Alert on app with no verified publisher
# - Alert on app accessing sensitive data
```

### 4. Educate Users

**Send organization-wide alert:**
```
Subject: SECURITY ALERT: OAuth Consent Phishing Attempt Detected

Dear Team,

We detected a malicious OAuth application that gained access to user accounts.

❌ DO NOT grant consent to apps unless:
  1. You recognize the publisher
  2. The app is verified (blue checkmark)
  3. IT/Security has approved it

✅ If you see a suspicious consent request:
  1. DO NOT CLICK "Accept"
  2. Take a screenshot
  3. Report to security@verdaio.com immediately

Stay vigilant!
- Security Team
```

---

## Post-Incident Review

### Impact Assessment

**Determine what data was compromised:**
- Emails read/sent?
- Files accessed/downloaded?
- User data exfiltrated?
- Calendar events viewed?
- Teams messages accessed?

### Compliance Notifications

**May require notification if:**
- **GDPR:** Personal data of EU residents accessed
- **HIPAA:** PHI accessed
- **State laws:** PII accessed (varies by state)

### Evidence Collection

```bash
# Export for audit:
# 1. Application details
az ad app show --id <application-id> -o json > malicious-app-details.json

# 2. All affected users
az ad sp show --id <service-principal-id> --query "oauth2PermissionGrants" -o json > affected-users.json

# 3. Audit logs
# Already exported in Eradication phase

# 4. Timeline of events
# Document in incident report
```

### Root Cause Analysis

**Common Causes:**
1. User consent enabled (should be admin-only)
2. No app governance in place
3. Phishing email with OAuth link
4. User unfamiliar with OAuth consent flows
5. No security awareness training

---

## Prevention Checklist

**Immediate (Week 1):**
- [ ] Disable user consent for apps
- [ ] Enable Admin Consent Workflow
- [ ] Review all existing app registrations
- [ ] Revoke consent for unrecognized apps
- [ ] Enable Sentinel analytics rules for suspicious consent

**Short-term (Month 1):**
- [ ] Enable Microsoft Defender for Cloud Apps app governance
- [ ] Create Conditional Access policies for risky apps
- [ ] Conduct user security awareness training
- [ ] Document approved applications list
- [ ] Implement app approval process

**Long-term (Quarter 1):**
- [ ] Quarterly review of all app permissions
- [ ] Automated app risk scoring
- [ ] Integration with threat intelligence feeds
- [ ] Incident response drills for OAuth attacks
- [ ] Zero Trust app access policies

---

## Common OAuth Phishing Techniques

**1. Typosquatting:**
- Legitimate: "Microsoft Teams"
- Malicious: "Microsoft Tеams" (Cyrillic 'е')

**2. Similar Icons:**
- Uses Microsoft/Google logo to appear legitimate

**3. Redirect URI Tricks:**
- Legitimate: `https://app.example.com/callback`
- Malicious: `https://app.evil.com/callback`

**4. Over-permissioned Apps:**
- Requests more permissions than needed
- "Flashlight app" requesting `Mail.ReadWrite.All`

---

## Quick Reference: Critical Commands

```bash
# Disable service principal
az ad sp update --id <sp-id> --set accountEnabled=false

# Revoke user refresh tokens
az rest --method POST --url "https://graph.microsoft.com/v1.0/users/<user-id>/revokeSignInSessions"

# Force password reset
az ad user update --id <user-id> --force-change-password-next-sign-in true

# List app permissions
az ad app permission list --id <app-id>
```

**PowerShell:**
```powershell
# Revoke OAuth grant
Remove-MgOauth2PermissionGrant -OAuth2PermissionGrantId <grant-id>

# Get all enterprise apps
Get-MgServicePrincipal -All
```

---

**Remember: When in doubt, revoke consent first, investigate later.**
