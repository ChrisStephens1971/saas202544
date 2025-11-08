# CI/CD Setup Instructions - Azure OIDC + GitHub Actions

## Azure AD Federated Credential (No Client Secret)

### 1. Create Service Principal with Federated Credential

```bash
# Create Azure AD application
az ad app create --display-name "gh-verdaio-saas202544"
# Note the appId from output

# Create service principal
az ad sp create --id <appId>

# Create federated credential for main branch
az ad app federated-credential create \
  --id <appId> \
  --parameters '{
    "name": "gh-verdaio-saas202544-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:ChrisStephens1971/saas202544:ref:refs/heads/master",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Optional: Create federated credentials for pull requests
az ad app federated-credential create \
  --id <appId> \
  --parameters '{
    "name": "gh-verdaio-saas202544-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:ChrisStephens1971/saas202544:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### 2. Assign Azure RBAC Permissions

```bash
# Assign Contributor role at subscription level
az role assignment create \
  --assignee <appId> \
  --role Contributor \
  --subscription b3fc75c0-c060-4a53-a7cf-5f6ae22fefec

# Optional: Assign User Access Administrator for RBAC operations
az role assignment create \
  --assignee <appId> \
  --role "User Access Administrator" \
  --subscription b3fc75c0-c060-4a53-a7cf-5f6ae22fefec
```

---

## GitHub Actions Configuration

### Repository Variables

Navigate to: `Settings → Secrets and variables → Actions → Variables`

Add these **Variables** (not secrets):

| Name | Value |
|------|-------|
| `AZURE_SUBSCRIPTION_ID` | `b3fc75c0-c060-4a53-a7cf-5f6ae22fefec` |
| `AZURE_TENANT_ID` | `04c5f804-d3ee-4b0b-b7fa-772496bb7a34` |
| `AZURE_CLIENT_ID` | `<appId from service principal>` |

### Branch Protection Rules

Navigate to: `Settings → Branches → Add rule`

**Protection for `master` branch:**
- ✅ Require status checks to pass before merging
  - Required checks: `boot-check`, `infra-terraform-plan`
- ✅ Require pull request reviews before merging (1 approval)
- ✅ Dismiss stale pull request approvals when new commits are pushed

### Environment Protection Rules (Optional)

**For `stg` environment:**
1. Navigate to: `Settings → Environments → New environment`
2. Name: `stg`
3. Protection rules:
   - ✅ Required reviewers: `@ChrisStephens1971`
   - ✅ Wait timer: 0 minutes

**For `prd` environment:**
1. Navigate to: `Settings → Environments → New environment`
2. Name: `prd`
3. Protection rules:
   - ✅ Required reviewers: `@ChrisStephens1971`
   - ✅ Wait timer: 5 minutes
   - ✅ Prevent administrators from bypassing configured protection rules

---

## Terraform State Storage (One-time setup)

```bash
# Create resource group for Terraform state
az group create \
  --name rg-tfstate-verdaio-eastus2-01 \
  --location eastus2 \
  --tags org=verdaio proj=platform env=prd

# Create storage account for Terraform state
az storage account create \
  --name stvrdtfstateeus201 \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --location eastus2 \
  --sku Standard_LRS \
  --encryption-services blob \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

# Create blob container for state files
az storage container create \
  --name tfstate \
  --account-name stvrdtfstateeus201 \
  --auth-mode login

# Enable versioning for state files (recommended)
az storage account blob-service-properties update \
  --account-name stvrdtfstateeus201 \
  --enable-versioning true

# Optional: Enable soft delete for state files (30 days retention)
az storage account blob-service-properties update \
  --account-name stvrdtfstateeus201 \
  --enable-delete-retention true \
  --delete-retention-days 30
```

---

## Verify OIDC Configuration

Test the federated credential authentication:

```bash
# From your local machine with Azure CLI
az login

# Test OIDC token exchange (requires GitHub CLI)
gh auth status

# Run a test workflow to verify OIDC authentication
# Create a test workflow in .github/workflows/test-oidc.yml
```

---

## Security Best Practices

✅ **Completed:**
- No client secrets stored in GitHub
- OIDC authentication only
- Least privilege RBAC assignments
- State file encryption enabled
- TLS 1.2 minimum required
- Public blob access disabled

⚠️ **Additional Recommendations:**
- Enable Azure Defender for Storage on state storage account
- Configure Azure Monitor alerts for unauthorized access attempts
- Enable audit logging for service principal activities
- Rotate federated credentials periodically (every 90 days)
- Use separate service principals for dev/stg/prd if needed

---

## Troubleshooting

**Issue: OIDC authentication fails**
```bash
# Verify federated credential configuration
az ad app federated-credential list --id <appId>

# Check subject matches GitHub repository
# Format: repo:<owner>/<repo>:ref:refs/heads/<branch>
```

**Issue: Terraform state access denied**
```bash
# Verify service principal has Storage Blob Data Contributor role
az role assignment list --assignee <appId> --subscription b3fc75c0-c060-4a53-a7cf-5f6ae22fefec
```

**Issue: Branch protection cannot be set**
- Ensure repository is not empty (has at least one commit)
- Verify GitHub Actions workflows exist in `.github/workflows/`
- Check that workflow names match the required checks

---

## Next Steps

1. ✅ Create service principal with federated credential
2. ✅ Assign RBAC permissions
3. ✅ Configure GitHub Actions variables
4. ✅ Set up Terraform state storage
5. ⏭️ Create GitHub workflows (see `PR-PLAN.md`)
6. ⏭️ Test OIDC authentication with a test deployment
7. ⏭️ Configure environment-specific secrets (if needed)

---

**Last Updated:** 2025-11-08
**Project:** saas202544
**Owner:** chris.stephens@verdaio.com
