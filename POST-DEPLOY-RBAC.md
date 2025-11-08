# Post-Deploy RBAC Scope Narrowing

**Project:** saas202544
**Service Principal:** 750452fa-c519-455f-b77d-18f9707e2f39
**Subscription:** b3fc75c0-c060-4a53-a7cf-5f6ae22fefec
**Execute After:** First successful `terraform apply` creates project resource group

---

## Overview

This document describes the **RBAC narrowing** that should occur after the first successful infrastructure deployment. The goal is to reduce the service principal's permissions from subscription-wide **Reader** to resource-group-scoped **Contributor**, following the principle of least privilege.

**Why Narrow After First Deploy?**
- **Initial RBAC (now):** Reader at subscription + Storage Blob Data Contributor on tfstate storage
  - Allows Terraform to **plan** (read Azure resources)
  - Allows Terraform to **read/write** state files
  - **Cannot create/modify** resources (plan-only mode)

- **After first deploy:** Contributor on project resource group only
  - Allows Terraform to **create/modify/delete** resources in project RG
  - Removes subscription-wide Reader (optional, for maximum security)
  - Still retains Storage Blob Data Contributor on tfstate storage

---

## Prerequisites

Before running these commands, verify:

1. **✅ First Terraform apply completed successfully**
   ```bash
   # Check that project resource group exists
   az group show --name rg-verdaio-saas202544-dev-eastus2-01
   ```

2. **✅ Resources deployed correctly**
   ```bash
   # List resources in project RG
   az resource list --resource-group rg-verdaio-saas202544-dev-eastus2-01 -o table
   ```

3. **✅ No ongoing deployments**
   ```bash
   # Check GitHub Actions workflow status
   gh run list --workflow=infra-terraform.yml --limit 5
   ```

---

## RBAC Narrowing Commands

### 1. Get Service Principal Object ID

```bash
APP_ID="750452fa-c519-455f-b77d-18f9707e2f39"
SUB="b3fc75c0-c060-4a53-a7cf-5f6ae22fefec"

# Get service principal object ID
SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)

echo "Service Principal Object ID: $SP_OBJECT_ID"
```

---

### 2. Assign Contributor Role to Project Resource Group

**Purpose:** Allow Terraform to manage resources in project RG only

```bash
PROJECT_RG="/subscriptions/$SUB/resourceGroups/rg-verdaio-saas202544-dev-eastus2-01"

az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --role Contributor \
  --scope "$PROJECT_RG"
```

**What this does:**
- Grants full management permissions within project resource group
- Scoped to single RG (not entire subscription)
- Allows create/update/delete of resources
- Does NOT grant permissions outside this resource group

---

### 3. Verify New Role Assignment

```bash
az role assignment list \
  --assignee-object-id "$SP_OBJECT_ID" \
  --scope "$PROJECT_RG" \
  -o table
```

**Expected output:**
```
Principal                              Role         Scope
------------------------------------  -----------  --------------------------------------
750452fa-c519-455f-b77d-18f9707e2f39  Contributor  /subscriptions/.../rg-verdaio-saas202544-dev-eastus2-01
```

---

### 4. (Optional) Remove Subscription-Wide Reader Role

**⚠️ WARNING:** Only remove if you no longer need to read resources outside project RG

**Why you might keep it:**
- Allows Terraform to reference existing subscription-level resources
- Enables data sources like `azurerm_resource_group` for other RGs
- Needed if sharing resources (e.g., shared Key Vault, Log Analytics)

**Why you might remove it:**
- Maximum security posture (zero access outside project RG)
- Compliance requirements (strict least privilege)
- Project is fully self-contained

**To remove:**
```bash
# List current Reader assignments to verify
az role assignment list \
  --assignee-object-id "$SP_OBJECT_ID" \
  --role Reader \
  --scope "/subscriptions/$SUB" \
  -o table

# Delete Reader role at subscription level
az role assignment delete \
  --assignee-object-id "$SP_OBJECT_ID" \
  --role Reader \
  --scope "/subscriptions/$SUB"
```

---

### 5. Final RBAC Verification

**List all role assignments for service principal:**

```bash
az role assignment list \
  --assignee-object-id "$SP_OBJECT_ID" \
  --all \
  -o table
```

**Expected output (maximum security):**
```
Principal                              Role                             Scope
------------------------------------  -------------------------------  --------------------------------------
750452fa-c519-455f-b77d-18f9707e2f39  Contributor                      /subscriptions/.../rg-verdaio-saas202544-dev-eastus2-01
750452fa-c519-455f-b77d-18f9707e2f39  Storage Blob Data Contributor    /subscriptions/.../stvrdtfstateeus201
```

**Expected output (if keeping subscription Reader):**
```
Principal                              Role                             Scope
------------------------------------  -------------------------------  --------------------------------------
750452fa-c519-455f-b77d-18f9707e2f39  Reader                           /subscriptions/b3fc75c0-...
750452fa-c519-455f-b77d-18f9707e2f39  Contributor                      /subscriptions/.../rg-verdaio-saas202544-dev-eastus2-01
750452fa-c519-455f-b77d-18f9707e2f39  Storage Blob Data Contributor    /subscriptions/.../stvrdtfstateeus201
```

---

## Multi-Environment RBAC

When deploying to staging and production, apply the same pattern:

### Staging Environment

```bash
PROJECT_RG_STG="/subscriptions/$SUB/resourceGroups/rg-verdaio-saas202544-stg-eastus2-01"

az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --role Contributor \
  --scope "$PROJECT_RG_STG"
```

---

### Production Environment

**⚠️ RECOMMENDATION:** Use a **separate service principal** for production

**Why separate SP for production?**
- Limits blast radius of credential compromise
- Allows different approval workflows
- Enables stricter audit logging
- Satisfies compliance requirements (SOC 2, ISO 27001)

**If using same SP (not recommended for prod):**
```bash
PROJECT_RG_PRD="/subscriptions/$SUB/resourceGroups/rg-verdaio-saas202544-prd-eastus2-01"

az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --role Contributor \
  --scope "$PROJECT_RG_PRD"
```

**Recommended approach (separate SP):**
```bash
# Create production-specific service principal
az ad sp create-for-rbac \
  --name "gh-saas202544-prd" \
  --role Contributor \
  --scopes "$PROJECT_RG_PRD" \
  --sdk-auth false

# Create federated credentials for production SP
# (follow same pattern as OIDC-SETUP.md)
```

---

## Testing After RBAC Narrowing

### Test 1: Terraform Plan (Should Still Work)

```bash
cd /c/devop/saas202544/infrastructure/terraform

terraform init -reconfigure
terraform plan -var-file=../../environments/dev.tfvars
```

**Expected result:** Plan succeeds, shows existing resources

---

### Test 2: Terraform Apply (Should Now Work)

```bash
cd /c/devop/saas202544/infrastructure/terraform

# Make a small change (e.g., add a tag to resource)
terraform plan -var-file=../../environments/dev.tfvars -out=tfplan
terraform apply tfplan
```

**Expected result:** Apply succeeds, resources updated

---

### Test 3: CI/CD Pipeline (Should Work)

```bash
# Trigger Terraform apply via GitHub Actions
gh workflow run infra-terraform.yml \
  --ref main \
  -f environment=dev \
  -f action=apply

# Monitor workflow
gh run watch
```

**Expected result:**
- Workflow authenticates via OIDC
- Terraform plan succeeds
- Terraform apply succeeds (if approved)
- No permission errors

---

### Test 4: Verify Scope Restrictions (Should Fail)

**Try to create resource outside project RG:**

```bash
# Attempt to create resource group in different region (should fail)
az group create \
  --name rg-test-unauthorized \
  --location westus2 \
  --subscription "$SUB"
```

**Expected result:** Unauthorized error (if subscription Reader was removed)

---

## Rollback Procedure

If RBAC narrowing causes issues:

### 1. Re-add Subscription Reader

```bash
az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --role Reader \
  --scope "/subscriptions/$SUB"
```

---

### 2. Remove Project RG Contributor (if needed)

```bash
az role assignment delete \
  --assignee-object-id "$SP_OBJECT_ID" \
  --role Contributor \
  --scope "$PROJECT_RG"
```

---

### 3. Verify Rollback

```bash
az role assignment list \
  --assignee-object-id "$SP_OBJECT_ID" \
  --all \
  -o table
```

---

## Audit Trail

**Record RBAC changes:**

```bash
# Export current role assignments to JSON
az role assignment list \
  --assignee-object-id "$SP_OBJECT_ID" \
  --all \
  -o json > rbac-assignments-$(date +%Y%m%d-%H%M%S).json

# View role assignment change history (last 90 days)
az monitor activity-log list \
  --resource-group rg-verdaio-saas202544-dev-eastus2-01 \
  --caller chris.stephens@verdaio.com \
  --start-time $(date -u -d '90 days ago' '+%Y-%m-%dT%H:%M:%SZ') \
  --query "[?contains(authorization.action, 'roleAssignments')]" \
  -o table
```

---

## Compliance Mapping

**SOC 2 Controls:**
- ✅ CC6.1 - Logical access controls (least privilege enforcement)
- ✅ CC6.2 - Role-based access control (scoped by resource group)
- ✅ CC6.3 - Authorization (Contributor only where needed)

**CIS Azure Benchmark:**
- ✅ 1.23 - Ensure that no custom subscription owner roles are created
- ✅ 1.25 - Ensure that only authorized users have access to resources

**ISO 27001:**
- ✅ A.9.2.3 - Management of privileged access rights
- ✅ A.9.4.1 - Information access restriction

---

## Execution Checklist

Run these commands **after first successful terraform apply**:

- [ ] **Prerequisite 1:** Verify project RG exists
  ```bash
  az group show --name rg-verdaio-saas202544-dev-eastus2-01
  ```

- [ ] **Prerequisite 2:** Verify resources deployed
  ```bash
  az resource list --resource-group rg-verdaio-saas202544-dev-eastus2-01 -o table
  ```

- [ ] **Step 1:** Get service principal object ID
  ```bash
  SP_OBJECT_ID=$(az ad sp show --id "750452fa-c519-455f-b77d-18f9707e2f39" --query id -o tsv)
  ```

- [ ] **Step 2:** Assign Contributor to project RG
  ```bash
  # Command from section 2
  ```

- [ ] **Step 3:** Verify new role assignment
  ```bash
  # Command from section 3
  ```

- [ ] **Step 4 (Optional):** Remove subscription Reader
  ```bash
  # Command from section 4 (only if maximum security required)
  ```

- [ ] **Step 5:** Final verification
  ```bash
  # Command from section 5
  ```

- [ ] **Test 1:** Terraform plan
- [ ] **Test 2:** Terraform apply
- [ ] **Test 3:** CI/CD pipeline
- [ ] **Test 4:** Scope restrictions

- [ ] **Audit:** Export role assignments to JSON
  ```bash
  # Command from audit section
  ```

---

## Summary

| RBAC Scope | Before (Initial) | After (Narrowed) |
|------------|------------------|------------------|
| Subscription Reader | ✅ Required | ⚠️ Optional (can remove) |
| Project RG Contributor | ❌ Not assigned | ✅ Required |
| Tfstate Storage Blob Contributor | ✅ Required | ✅ Keep (still required) |

**Security Posture:**
- **Before:** Read-only at subscription + state storage access (plan-only)
- **After:** Full control in project RG only + state storage access (deploy-ready)

**Least Privilege Progression:**
1. **Bootstrap:** Reader (subscription) + Storage Blob Contributor (tfstate)
2. **After First Deploy:** Contributor (project RG) + Storage Blob Contributor (tfstate)
3. **Maximum Security:** Contributor (project RG) only + Storage Blob Contributor (tfstate)

**Next Steps:**
1. Complete first terraform apply successfully
2. Run commands from execution checklist
3. Test with all 4 test scenarios
4. Document in audit trail
5. Update HARDENING-REPORT.md with final RBAC configuration

**Last Updated:** 2025-11-08
**Owner:** chris.stephens@verdaio.com
