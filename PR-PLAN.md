# Bootstrap PR Plan - saas202544

## Overview

This document outlines the files to add/modify for bootstrapping the Azure deployment pipeline with GitHub Actions OIDC authentication.

---

## Files to Add

### 1. GitHub Workflows

**`.github/workflows/boot-check.yml`**
- Validates naming conventions (Azure naming standard v1.2)
- Validates required tags are present
- Scans for secrets and credentials
- Checks for unreplaced placeholders
- Runs on: PRs and pushes to master

**`.github/workflows/infra-terraform-plan.yml`**
- Authenticates to Azure via OIDC (no secrets)
- Initializes Terraform backend
- Runs `terraform plan` for all environments
- Posts plan output as PR comment
- Runs on: PRs to master

**`.github/workflows/infra-terraform-apply.yml`**
- Authenticates to Azure via OIDC
- Applies Terraform changes for specified environment
- Runs on: Manual workflow_dispatch or merge to master
- Requires environment approval for stg/prd

**`.github/workflows/infra-bicep-validate.yml`**
- Validates Bicep templates
- Runs `az bicep build` on all templates
- Checks parameter files are valid
- Runs on: PRs and pushes to master

### 2. Environment Configuration Files

**`environments/dev.tfvars`** ✅ Created
**`environments/stg.tfvars`** ✅ Created
**`environments/prd.tfvars`** ✅ Created
**`environments/dev.parameters.jsonc`** ✅ Created
**`environments/stg.parameters.jsonc`** ✅ Created
**`environments/prd.parameters.jsonc`** ✅ Created

### 3. Infrastructure Configuration

**`infrastructure/terraform/backend.tf`**
- Configure azurerm backend with state storage
- Use variables from template.vars.json

**`infrastructure/terraform/variables.tf`**
- Define all input variables (org, proj, env, region, seq, tags)
- Add validation rules for region codes and naming patterns

**`infrastructure/bicep/main.parameters.template.jsonc`**
- Template for parameter files
- Include all standard parameters

### 4. Repository Configuration

**`CODEOWNERS`**
```
# Infrastructure and technical documentation
/infrastructure/**               @ChrisStephens1971
/technical/**                    @ChrisStephens1971
/environments/**                 @ChrisStephens1971
/.github/workflows/**            @ChrisStephens1971

# Configuration files
/template.vars.json              @ChrisStephens1971
/CI-INSTRUCTIONS.md              @ChrisStephens1971
/PR-PLAN.md                      @ChrisStephens1971
```

**`.github/labeler.yml`**
```yml
infrastructure:
  - infrastructure/**/*
  - environments/**/*

github-actions:
  - .github/workflows/**/*

documentation:
  - '**/*.md'
  - technical/**/*

security:
  - infrastructure/azure-security-bicep/**/*
  - infrastructure/azure-security-terraform/**/*
```

### 5. Documentation

**`CI-INSTRUCTIONS.md`** ✅ Created
**`PR-PLAN.md`** ✅ Created (this file)
**`template.vars.json`** ✅ Created

---

## Files to Modify

### 1. Infrastructure Code

**`infrastructure/terraform/**/*.tf`**
- Ensure all resources use naming module outputs
- Apply tags uniformly from variables
- Remove hardcoded values
- Use consistent naming: `{prefix}-{org}-{proj}-{env}-{region}-{seq}`

**`infrastructure/bicep/**/*.bicep`**
- Parameterize all resource names
- Apply tags from parameters
- Use naming module for consistency
- Remove hardcoded values

### 2. Documentation

**`README.md`**
- Add "Quick Start" section with exact deploy commands
- Add "CI/CD Setup" section linking to CI-INSTRUCTIONS.md
- Add "Architecture" section describing Azure resources
- Include Cloud Shell and Codespaces deployment instructions

**Example additions:**
```markdown
## Quick Start

### Deploy with Azure Cloud Shell

1. Open [Azure Cloud Shell](https://shell.azure.com)
2. Clone the repository:
   ```bash
   git clone https://github.com/ChrisStephens1971/saas202544.git
   cd saas202544
   ```
3. Initialize Terraform:
   ```bash
   cd infrastructure/terraform
   terraform init
   terraform plan -var-file=../../environments/dev.tfvars
   ```

### Deploy with GitHub Codespaces

1. Open in Codespaces (click "Code" → "Open with Codespaces")
2. Authenticate to Azure:
   ```bash
   az login --use-device-code
   ```
3. Deploy infrastructure:
   ```bash
   cd infrastructure/terraform
   terraform init
   terraform apply -var-file=../../environments/dev.tfvars
   ```

## CI/CD Setup

See [CI-INSTRUCTIONS.md](./CI-INSTRUCTIONS.md) for complete GitHub Actions OIDC setup.
```

### 3. Git Configuration

**`.gitignore`**
Add if not present:
```
# Terraform
*.tfstate
*.tfstate.*
*.tfstate.backup
.terraform/
.terraform.lock.hcl
terraform.tfvars
override.tf
override.tf.json

# Bicep
*.parameters.dev.json
*.parameters.stg.json
*.parameters.prd.json

# Azure
.azure/

# Secrets
*.secret.*
.env.local
.env.*.local
```

---

## Validation Checklist

Before creating the PR, verify:

- [ ] All `{{placeholders}}` replaced in infrastructure code
- [ ] Naming module outputs match Azure naming standard v1.2 pattern
- [ ] No hardcoded secrets anywhere (use Key Vault references only)
- [ ] GitHub OIDC federated credential created
- [ ] GitHub Actions variables configured (AZURE_SUBSCRIPTION_ID, AZURE_TENANT_ID, AZURE_CLIENT_ID)
- [ ] Terraform backend storage account created
- [ ] All environments (dev/stg/prd) have tfvars and parameters.jsonc files
- [ ] CODEOWNERS file includes all infrastructure paths
- [ ] Branch protection rules configured for master branch
- [ ] Workflows include OIDC authentication steps
- [ ] No .tfstate files committed to git

---

## Workflow Execution Order

1. **On PR Creation:**
   - `boot-check.yml` runs (validates naming, tags, no secrets)
   - `infra-terraform-plan.yml` runs (shows what will change)
   - `infra-bicep-validate.yml` runs (validates Bicep syntax)

2. **On PR Merge to Master:**
   - `infra-terraform-apply.yml` runs for dev environment (auto-deploy)

3. **Manual Deployment to Staging:**
   - Manually trigger `infra-terraform-apply.yml` workflow
   - Select environment: `stg`
   - Requires approval from @ChrisStephens1971

4. **Manual Deployment to Production:**
   - Manually trigger `infra-terraform-apply.yml` workflow
   - Select environment: `prd`
   - Requires approval from @ChrisStephens1971
   - 5-minute wait timer before deployment

---

## Implementation Steps

### Step 1: Create Workflows (Priority)
```bash
cd /c/devop/saas202544/.github/workflows
# Create boot-check.yml
# Create infra-terraform-plan.yml
# Create infra-terraform-apply.yml
# Create infra-bicep-validate.yml
```

### Step 2: Update Infrastructure Code
```bash
cd /c/devop/saas202544/infrastructure
# Update terraform/*.tf files with backend config
# Update bicep/*.bicep files to use parameters
# Verify naming module is consistent
```

### Step 3: Add Repository Configuration
```bash
cd /c/devop/saas202544
# Create CODEOWNERS
# Create .github/labeler.yml
# Update .gitignore
```

### Step 4: Update Documentation
```bash
cd /c/devop/saas202544
# Update README.md with deployment instructions
# Verify CI-INSTRUCTIONS.md is accurate
```

### Step 5: Test Locally
```bash
# Test Terraform init
cd infrastructure/terraform
terraform init

# Test Terraform plan
terraform plan -var-file=../../environments/dev.tfvars

# Test Bicep validation
cd ../bicep
az bicep build --file main.bicep
```

### Step 6: Create Bootstrap PR
```bash
git checkout -b bootstrap/azure-ci-pipeline
git add .
git commit -m "feat: add Azure CI/CD pipeline with OIDC authentication

- Add GitHub Actions workflows for Terraform plan/apply
- Add boot-check validation workflow
- Add Bicep validation workflow
- Configure environment-specific tfvars and parameters
- Add CODEOWNERS and labeler configuration
- Update README with deployment instructions
- Configure Terraform backend for state storage

Closes #1 (if bootstrap issue exists)
"
git push origin bootstrap/azure-ci-pipeline

# Create PR via GitHub CLI
gh pr create \
  --title "Bootstrap: Azure CI/CD Pipeline with OIDC" \
  --body "$(cat PR-PLAN.md)" \
  --label "infrastructure,github-actions" \
  --assignee "@me"
```

---

## Expected Outcomes

✅ **After PR Merge:**
- Automated Terraform plan on every PR
- Automated validation of naming and tags
- No secrets in repository (OIDC only)
- Consistent deployment process for all environments
- Environment-specific approvals for stg/prd
- Audit trail of all infrastructure changes

✅ **Security Improvements:**
- Zero secrets stored in GitHub
- Federated authentication with Azure AD
- Least privilege RBAC assignments
- State file encryption and versioning
- Audit logging for all deployments

✅ **Developer Experience:**
- Single command deployment from Cloud Shell or Codespaces
- Automated PR comments with plan output
- Clear documentation for all workflows
- Consistent naming across all resources

---

**Last Updated:** 2025-11-08
**Project:** saas202544
**Estimated Time:** 2-3 hours for complete implementation
