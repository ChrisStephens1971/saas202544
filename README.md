# saas202544

Generated from .template-system on 2025-11-08 10:00:14Z.

## Overview

This repository implements a cloud-native SaaS infrastructure using Azure and Terraform, with automated CI/CD pipelines via GitHub Actions. Infrastructure is managed as code with state stored securely in Azure Storage, and authentication uses OIDC federation (no secrets).

## Infrastructure Architecture

### Azure Resources

| Resource | Name | Purpose | Location |
|----------|------|---------|----------|
| Subscription | Azure subscription 1 | Primary Azure subscription | - |
| Resource Group | `rg-tfstate-verdaio-eastus2-01` | Terraform state management | East US 2 |
| Storage Account | `stvrdtfstateeus201` | Terraform remote state backend | East US 2 |
| Storage Container | `tfstate` | Terraform state files | - |
| Service Principal | App ID: `750452fa-c519-455f-b77d-18f9707e2f39` | CI/CD authentication | - |

### Azure Configuration

**Subscription ID**: `b3fc75c0-c060-4a53-a7cf-5f6ae22fefec`
**Tenant ID**: `04c5f804-d3ee-4b0b-b7fa-772496bb7a34`

**Storage Account Details**:

- Kind: StorageV2
- Access Tier: Hot
- TLS Version: 1.2 (minimum)
- Public Blob Access: Disabled
- Cross-Tenant Replication: Disabled

## RBAC Permissions

The service principal has the following role assignments:

| Scope | Role | Purpose |
|-------|------|---------|
| Subscription | Reader | Read subscription metadata and resources |
| Storage Account: `stvrdtfstateeus201` | Storage Blob Data Contributor | Read/write Terraform state files via RBAC (no storage keys) |

## GitHub Actions OIDC Federation

### Configuration

Authentication uses OpenID Connect (OIDC) workload identity federation - no secrets or keys stored in GitHub.

**Federated Identity Credentials**:

| Name | Subject | Purpose |
|------|---------|---------|
| `gh-main` | `repo:ChrisStephens1971/saas202544:ref:refs/heads/main` | Main branch deployments |
| `gh-pr` | `repo:ChrisStephens1971/saas202544:pull_request` | Pull request validation |
| `gh-ci-fix` | `repo:ChrisStephens1971/saas202544:ref:refs/heads/ci/fix-oidc-plan` | CI fix branch |

**OIDC Parameters**:
- Issuer: `https://token.actions.githubusercontent.com`
- Audience: `api://AzureADTokenExchange`

### Repository Variables

The following variables must be configured in GitHub repository settings (Settings → Secrets and variables → Actions → Variables):

| Variable | Value | Usage |
|----------|-------|-------|
| `AZURE_CLIENT_ID` | `750452fa-c519-455f-b77d-18f9707e2f39` | Service principal application ID |
| `AZURE_TENANT_ID` | `04c5f804-d3ee-4b0b-b7fa-772496bb7a34` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | `b3fc75c0-c060-4a53-a7cf-5f6ae22fefec` | Target Azure subscription |

## CI/CD Workflows

### 1. boot-check

**File**: `.github/workflows/boot-check.yml`
**Triggers**: Pull requests, pushes to main
**Purpose**: Basic repository sanity checks

Validates repository structure and basic configuration before other workflows run.

### 2. infra-terraform

**File**: `.github/workflows/infra-terraform.yml`
**Triggers**: Pull requests to main, manual dispatch
**Purpose**: Terraform infrastructure planning and deployment

**Jobs**:
- `plan`: Generates Terraform execution plan (runs on PRs and main)
- `apply`: Applies infrastructure changes (runs only on main branch)

**Branch Protection**: This workflow provides the required check `infra-terraform / plan`.

### 3. review-pack

**File**: `.github/workflows/review-pack.yml`
**Triggers**: Pull requests, pushes to main
**Purpose**: Static analysis and security scanning

**Jobs**:
- `actionlint`: Validates GitHub Actions workflow syntax
- `markdownlint`: Validates markdown formatting
- `trufflehog`: Scans for secrets and credentials

### 4. oidc-smoke

**File**: `.github/workflows/oidc-smoke.yml`
**Triggers**: Pull requests (when workflow changes), manual dispatch, nightly schedule
**Purpose**: Validates Azure OIDC authentication and RBAC permissions

**Validation Steps**:
1. Authenticate to Azure using OIDC (no secrets)
2. Verify subscription access
3. Check Terraform state resource group accessibility
4. Validate storage account control plane access
5. Test blob data plane access (container listing via RBAC)

**Permissions Required**:
- `id-token: write` - Request OIDC token from GitHub
- `contents: read` - Checkout repository

**Schedule**: Runs nightly at 02:00 UTC to detect credential expiry or RBAC changes.

## Branch Protection Rules

**Branch**: `main`

| Setting | Value |
|---------|-------|
| Required Status Checks | `boot-check`, `infra-terraform / plan` |
| Require Branches to be Up to Date | Yes |
| Require Approvals | 1 |
| Dismiss Stale Reviews | Yes |
| Enforce for Administrators | Yes |
| Allow Force Pushes | No |
| Allow Deletions | No |
| Require Linear History | Yes |

## Terraform State Management

### Backend Configuration

State is stored remotely in Azure Storage using RBAC authentication:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-verdaio-eastus2-01"
    storage_account_name = "stvrdtfstateeus201"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
    use_azuread_auth     = true  # RBAC instead of storage keys
  }
}
```

### State Container Details

- **Container Name**: `tfstate`
- **Created**: 2025-11-08T13:20:58+00:00
- **Access Method**: Azure AD authentication (Storage Blob Data Contributor role)
- **Versioning**: Recommended (configure via storage account)
- **Soft Delete**: Recommended (configure via storage account)

## Development Workflow

### Making Infrastructure Changes

1. Create a feature branch from `main`
2. Make Terraform changes
3. Push branch and create pull request
4. CI workflows automatically run:
   - Boot checks validate repository
   - Terraform plan validates infrastructure changes
   - Review pack performs security scanning
5. Review Terraform plan output in workflow logs
6. Request approval from team member
7. Merge to `main` once approved and checks pass
8. Terraform apply runs automatically on `main` after merge

### Running Workflows Manually

```bash
# Trigger OIDC smoke test
gh workflow run oidc-smoke --ref main

# Trigger infrastructure plan
gh workflow run infra-terraform --ref main

# Trigger on specific branch
gh workflow run oidc-smoke --ref feature/my-branch
```

Note: Manual workflow runs on non-main branches will fail OIDC authentication unless a federated credential exists for that specific ref pattern.

### Validating OIDC Configuration

```bash
# List federated credentials
az ad app federated-credential list --id 750452fa-c519-455f-b77d-18f9707e2f39 -o table

# Show specific credential details
az ad app federated-credential show \
  --id 750452fa-c519-455f-b77d-18f9707e2f39 \
  --federated-credential-id gh-pr \
  -o json
```

### Accessing Azure Resources

```bash
# Login with service principal (for local testing)
az login --service-principal \
  -u 750452fa-c519-455f-b77d-18f9707e2f39 \
  -t 04c5f804-d3ee-4b0b-b7fa-772496bb7a34 \
  --allow-no-subscriptions

# Select subscription
az account set --subscription b3fc75c0-c060-4a53-a7cf-5f6ae22fefec

# List Terraform state containers
az storage container list \
  --account-name stvrdtfstateeus201 \
  --auth-mode login \
  -o table
```

## Security Considerations

### No Secrets in GitHub

This repository uses OIDC workload identity federation exclusively. No Azure credentials, storage keys, or secrets are stored in GitHub.

### RBAC-Only Storage Access

Storage account access uses Azure AD authentication with the Storage Blob Data Contributor role. Storage account keys are not used or required for CI/CD operations.

### Principle of Least Privilege

The service principal has:
- Reader role at subscription level (cannot modify resources)
- Storage Blob Data Contributor only on the state storage account (cannot access other storage accounts)
- No ability to manage IAM roles or create/modify Azure resources directly

### Credential Scanning

The `trufflehog` workflow job scans all commits for accidentally committed secrets and fails the build if verified credentials are detected.

### Nightly Validation

The OIDC smoke test runs nightly to detect:
- Expired or revoked federated credentials
- RBAC permission changes
- Storage account access issues
- Service principal configuration drift

## Troubleshooting

### OIDC Authentication Failures

**Error**: "No matching federated identity record found"

**Cause**: The workflow is running on a branch/ref without a federated credential.

**Solution**:
- PRs automatically work (subject: `repo:ChrisStephens1971/saas202544:pull_request`)
- Main branch works (subject: `repo:ChrisStephens1971/saas202544:ref:refs/heads/main`)
- For other branches, add a federated credential with appropriate subject pattern

### Container Access Denied

**Error**: "This request is not authorized to perform this operation"

**Cause**: Service principal lacks Storage Blob Data Contributor role.

**Solution**:
```bash
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee 750452fa-c519-455f-b77d-18f9707e2f39 \
  --scope "/subscriptions/b3fc75c0-c060-4a53-a7cf-5f6ae22fefec/resourceGroups/rg-tfstate-verdaio-eastus2-01/providers/Microsoft.Storage/storageAccounts/stvrdtfstateeus201"
```

### Branch Protection Blocking Merge

**Issue**: PR cannot merge due to failing required checks.

**Solution**: Ensure these checks are passing:
- `boot-check` (from boot-check workflow)
- `infra-terraform / plan` (from infra-terraform workflow, job named "plan")

Check workflow logs for specific errors.

### Terraform Apply Failures

**Error**: Terraform apply fails on main branch

**Common Causes**:
1. State file locked by another process
2. Insufficient permissions to create/modify resources
3. Resource naming conflicts
4. Azure quota limits reached

**Solution**: Check workflow logs for specific error messages and resolve accordingly.

## References

- [Azure OIDC Federation Docs](https://learn.microsoft.com/entra/workload-id/workload-identity-federation)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Terraform Azure Backend](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm)
- [Azure RBAC Storage](https://learn.microsoft.com/azure/storage/blobs/authorize-access-azure-active-directory)
