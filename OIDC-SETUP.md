# OIDC Setup Documentation
## Azure AD Federated Credential Configuration for GitHub Actions

**Project:** saas202544
**Organization:** verdaio
**Repository:** ChrisStephens1971/saas202544
**Date:** 2025-11-08

---

## ✅ Completed Steps

### 1. Azure AD Application Created

**App Name:** `gh-verdaio-saas202544`
**App ID (Client ID):** `750452fa-c519-455f-b77d-18f9707e2f39`

```bash
az ad app create --display-name "gh-verdaio-saas202544"
```

**Output:**
```json
{
  "appId": "750452fa-c519-455f-b77d-18f9707e2f39",
  "displayName": "gh-verdaio-saas202544"
}
```

---

### 2. Service Principal Created

**Service Principal ID:** `20707ebd-5b35-4596-83d8-b668cfae9688`

```bash
az ad sp create --id 750452fa-c519-455f-b77d-18f9707e2f39
```

**Output:**
```json
{
  "appId": "750452fa-c519-455f-b77d-18f9707e2f39",
  "displayName": "gh-verdaio-saas202544",
  "id": "20707ebd-5b35-4596-83d8-b668cfae9688"
}
```

---

### 3. Federated Credentials Created

#### a) Main Branch Credential

**Name:** `gh-main`
**Subject:** `repo:ChrisStephens1971/saas202544:ref:refs/heads/main`

```bash
az ad app federated-credential create \
  --id 750452fa-c519-455f-b77d-18f9707e2f39 \
  --parameters '{
    "name": "gh-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:ChrisStephens1971/saas202544:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

**Output:**
```json
{
  "name": "gh-main",
  "subject": "repo:ChrisStephens1971/saas202544:ref:refs/heads/main"
}
```

?? **Note:** Repository currently uses `master` as the default branch. Plan to rename it to `main` so the federated credential subject is already aligned. After renaming, remove any legacy credential named `gh-master` to avoid unused trust relationships:
```bash
# Rename branch locally and push
git branch -m master main
git push -u origin main
gh repo edit --default-branch main

# Remove legacy federated credential if it still exists
az ad app federated-credential delete \
  --id 750452fa-c519-455f-b77d-18f9707e2f39 \
  --federated-credential-id gh-master
```

#### b) Pull Request Credential

**Name:** `gh-pr`
**Subject:** `repo:ChrisStephens1971/saas202544:pull_request`

```bash
az ad app federated-credential create \
  --id 750452fa-c519-455f-b77d-18f9707e2f39 \
  --parameters '{
    "name": "gh-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:ChrisStephens1971/saas202544:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

**Output:**
```json
{
  "name": "gh-pr",
  "subject": "repo:ChrisStephens1971/saas202544:pull_request"
}
```

---

## 🔒 RBAC Role Assignments (Narrow Scopes)

### Security Principle: Least Privilege

Following the principle of least privilege, we assign:
1. **Reader** at subscription scope - for Terraform planning only
2. **Storage Blob Data Contributor** on tfstate storage account - for state file access

⚠️ **NOT granting Contributor at subscription.** After infrastructure creates the project resource group, scope Contributor to that RG only.

---

### 4. Create Terraform State Storage (If Not Exists)

```bash
# Check if resource group exists
az group show --name rg-tfstate-verdaio-eastus2-01 2>/dev/null || \
az group create \
  --name rg-tfstate-verdaio-eastus2-01 \
  --location eastus2 \
  --tags org=verdaio proj=platform env=prd

# Check if storage account exists
az storage account show --name stvrdtfstateeus201 --resource-group rg-tfstate-verdaio-eastus2-01 2>/dev/null || \
az storage account create \
  --name stvrdtfstateeus201 \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --location eastus2 \
  --sku Standard_LRS \
  --encryption-services blob \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

# Create blob container
az storage container create \
  --name tfstate \
  --account-name stvrdtfstateeus201 \
  --auth-mode login

# Enable versioning
az storage account blob-service-properties update \
  --account-name stvrdtfstateeus201 \
  --enable-versioning true

# Enable soft delete (30 days)
az storage account blob-service-properties update \
  --account-name stvrdtfstateeus201 \
  --enable-delete-retention true \
  --delete-retention-days 30
```

---

### 5. Assign Reader Role at Subscription Scope

**Scope:** `/subscriptions/b3fc75c0-c060-4a53-a7cf-5f6ae22fefec`
**Role:** Reader
**Purpose:** Allow Terraform to read existing resources for planning

```bash
az role assignment create \
  --assignee 750452fa-c519-455f-b77d-18f9707e2f39 \
  --role Reader \
  --scope "/subscriptions/b3fc75c0-c060-4a53-a7cf-5f6ae22fefec"
```

---

### 6. Assign Storage Blob Data Contributor on State Storage

**Storage Account:** stvrdtfstateeus201
**Role:** Storage Blob Data Contributor
**Purpose:** Allow Terraform to read/write state files

```bash
# Get storage account resource ID
STORAGE_ID=$(az storage account show \
  --name stvrdtfstateeus201 \
  --resource-group rg-tfstate-verdaio-eastus2-01 \
  --query id -o tsv)

# Assign Storage Blob Data Contributor
az role assignment create \
  --assignee 750452fa-c519-455f-b77d-18f9707e2f39 \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_ID"
```

---

## 🔐 GitHub Repository Configuration

### GitHub Actions Variables (NOT Secrets)

Navigate to: **Settings → Secrets and variables → Actions → Variables**

Add these three **Variables**:

| Variable Name | Value |
|---------------|-------|
| `AZURE_TENANT_ID` | `04c5f804-d3ee-4b0b-b7fa-772496bb7a34` |
| `AZURE_SUBSCRIPTION_ID` | `b3fc75c0-c060-4a53-a7cf-5f6ae22fefec` |
| `AZURE_CLIENT_ID` | `750452fa-c519-455f-b77d-18f9707e2f39` |

**Using GitHub CLI:**
```bash
cd /c/devop/saas202544

gh variable set AZURE_TENANT_ID --body "04c5f804-d3ee-4b0b-b7fa-772496bb7a34"
gh variable set AZURE_SUBSCRIPTION_ID --body "b3fc75c0-c060-4a53-a7cf-5f6ae22fefec"
gh variable set AZURE_CLIENT_ID --body "750452fa-c519-455f-b77d-18f9707e2f39"
```

---

## 🧪 Verification Steps

### 1. Verify Federated Credentials

```bash
az ad app federated-credential list --id 750452fa-c519-455f-b77d-18f9707e2f39 -o table
```

Expected output:
```
Name       Subject                                                    Issuer
---------  ---------------------------------------------------------  ----------------------------------------
gh-main  repo:ChrisStephens1971/saas202544:ref:refs/heads/main   https://token.actions.githubusercontent.com
gh-pr      repo:ChrisStephens1971/saas202544:pull_request            https://token.actions.githubusercontent.com
```

### 2. Verify Role Assignments

```bash
# Check subscription Reader role
az role assignment list \
  --assignee 750452fa-c519-455f-b77d-18f9707e2f39 \
  --scope "/subscriptions/b3fc75c0-c060-4a53-a7cf-5f6ae22fefec" \
  --query "[].{role:roleDefinitionName, scope:scope}" -o table

# Check storage account role
az role assignment list \
  --assignee 750452fa-c519-455f-b77d-18f9707e2f39 \
  --scope "/subscriptions/b3fc75c0-c060-4a53-a7cf-5f6ae22fefec/resourceGroups/rg-tfstate-verdaio-eastus2-01/providers/Microsoft.Storage/storageAccounts/stvrdtfstateeus201" \
  --query "[].{role:roleDefinitionName, scope:scope}" -o table
```

### 3. Test OIDC Authentication in Workflow

The workflows will test OIDC authentication automatically when they run.

---

## 📋 Summary

| Component | Value |
|-----------|-------|
| **Azure AD App** | gh-verdaio-saas202544 |
| **App ID (Client ID)** | `750452fa-c519-455f-b77d-18f9707e2f39` |
| **Service Principal ID** | `20707ebd-5b35-4596-83d8-b668cfae9688` |
| **Tenant ID** | `04c5f804-d3ee-4b0b-b7fa-772496bb7a34` |
| **Subscription ID** | `b3fc75c0-c060-4a53-a7cf-5f6ae22fefec` |
| **Default Branch** | `master` (rename to `main` planned; gh-main credential already documented) |
| **Federated Credentials** | 2 (`gh-main` for branch refs/heads/main, `gh-pr` for pull_request) |
| **RBAC Roles** | Reader (subscription), Storage Blob Data Contributor (state storage) |

---

## 🚀 Next Steps

1. ✅ Run the RBAC assignment commands above (if not already completed)
2. ✅ Set GitHub Actions variables
3. ✅ Push workflows to repository
4. ✅ Test with a PR to verify OIDC authentication
5. ⏭️ After first `terraform apply` creates project RG, narrow Contributor scope:
   ```bash
   # Get project RG ID after it's created
   PROJECT_RG_ID=$(az group show --name rg-verdaio-saas202544-dev-eastus2-01 --query id -o tsv)

   # Assign Contributor to project RG only
   az role assignment create \
     --assignee 750452fa-c519-455f-b77d-18f9707e2f39 \
     --role Contributor \
     --scope "$PROJECT_RG_ID"
   ```

---

**Security Status:** ✅ No secrets stored in GitHub
**Authentication Method:** OIDC federated credentials only
**RBAC Scope:** Narrow (Reader at subscription, Storage Blob Data Contributor on state storage)

**Last Updated:** 2025-11-08






