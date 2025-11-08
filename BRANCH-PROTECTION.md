# Branch Protection & Environment Security

**Project:** saas202544
**Repository:** ChrisStephens1971/saas202544
**Protected Branch:** main
**Created:** 2025-11-08

---

## Overview

This document provides `gh api` commands to configure branch protection rules and environment protection for the repository. These commands enforce CI checks, require pull requests, and add deployment gates for staging and production.

**Security Goals:**
- ✅ Require CI checks to pass before merging
- ✅ Enforce pull request workflow (no direct commits to main)
- ✅ Block force-pushes and deletions
- ✅ Dismiss stale approvals when new commits are pushed
- ✅ Add environment protection for staging/production deploys

---

## Branch Protection Rules

### 1. Protect `main` Branch

**Purpose:** Enforce CI checks and PR workflow on the main branch

```bash
REPO="ChrisStephens1971/saas202544"

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "/repos/$REPO/branches/main/protection" \
  -f "required_status_checks[strict]=true" \
  -f "required_status_checks[contexts][]=boot-check" \
  -f "required_status_checks[contexts][]=terraform-plan (dev)" \
  -f "enforce_admins=true" \
  -f "required_pull_request_reviews[dismiss_stale_reviews]=true" \
  -f "required_pull_request_reviews[require_code_owner_reviews]=false" \
  -f "required_pull_request_reviews[required_approving_review_count]=1" \
  -f "restrictions=null" \
  -f "allow_force_pushes=false" \
  -f "allow_deletions=false" \
  -f "block_creations=false" \
  -f "required_conversation_resolution=true" \
  -f "lock_branch=false" \
  -f "allow_fork_syncing=true"
```

**What this does:**
- Requires `boot-check` and `terraform-plan (dev)` to pass
- Enforces rules even for repository admins
- Requires at least 1 approval review
- Dismisses stale reviews when new commits are pushed
- Blocks force-pushes and deletions
- Requires all conversations to be resolved before merging

---

### 2. Verify Branch Protection

**Check current protection status:**

```bash
gh api \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "/repos/ChrisStephens1971/saas202544/branches/main/protection" \
  --jq '{
    required_status_checks: .required_status_checks.contexts,
    enforce_admins: .enforce_admins.enabled,
    required_reviews: .required_pull_request_reviews.required_approving_review_count,
    dismiss_stale: .required_pull_request_reviews.dismiss_stale_reviews,
    allow_force_pushes: .allow_force_pushes.enabled,
    allow_deletions: .allow_deletions.enabled
  }'
```

**Expected output:**
```json
{
  "required_status_checks": [
    "boot-check",
    "terraform-plan (dev)"
  ],
  "enforce_admins": true,
  "required_reviews": 1,
  "dismiss_stale": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
```

---

## Environment Protection

### 3. Create `stg` Environment with Protection

**Purpose:** Add approval gate for staging deployments

```bash
REPO="ChrisStephens1971/saas202544"

# Create staging environment
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "/repos/$REPO/environments/stg" \
  -f "wait_timer=0" \
  -f "prevent_self_review=false" \
  -f "reviewers[][type]=User" \
  -f "reviewers[][id]=<YOUR_GITHUB_USER_ID>" \
  -f "deployment_branch_policy[protected_branches]=true" \
  -f "deployment_branch_policy[custom_branch_policies]=false"
```

**Note:** Replace `<YOUR_GITHUB_USER_ID>` with your actual GitHub user ID. Get it with:

```bash
gh api user --jq '.id'
```

---

### 4. Create `prd` Environment with Protection

**Purpose:** Add approval gate for production deployments with wait timer

```bash
REPO="ChrisStephens1971/saas202544"

# Create production environment with 15-minute wait timer
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "/repos/$REPO/environments/prd" \
  -f "wait_timer=15" \
  -f "prevent_self_review=true" \
  -f "reviewers[][type]=User" \
  -f "reviewers[][id]=<YOUR_GITHUB_USER_ID>" \
  -f "deployment_branch_policy[protected_branches]=true" \
  -f "deployment_branch_policy[custom_branch_policies]=false"
```

**What this does:**
- Requires manual approval before deploying to production
- Adds 15-minute wait timer (cooling-off period)
- Prevents self-review (approval must come from someone else)
- Only allows deployments from protected branches (main)

---

### 5. Verify Environment Protection

**List all environments:**

```bash
gh api \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "/repos/ChrisStephens1971/saas202544/environments" \
  --jq '.environments[] | {
    name: .name,
    wait_timer: .protection_rules[0].wait_timer,
    reviewers: .protection_rules[0].reviewers | length,
    prevent_self_review: .protection_rules[0].prevent_self_review
  }'
```

**Expected output:**
```json
{
  "name": "stg",
  "wait_timer": 0,
  "reviewers": 1,
  "prevent_self_review": false
}
{
  "name": "prd",
  "wait_timer": 15,
  "reviewers": 1,
  "prevent_self_review": true
}
```

---

## Additional Security: Required Workflows

### 6. Require Workflows for All Branches (Optional)

**Purpose:** Ensure security checks run on all branches, not just PRs

```bash
REPO="ChrisStephens1971/saas202544"

# Get workflow ID for boot-check
WORKFLOW_ID=$(gh api \
  "/repos/$REPO/actions/workflows" \
  --jq '.workflows[] | select(.name=="boot-check") | .id')

# Require boot-check workflow
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "/repos/$REPO/actions/required_workflows" \
  -f "workflow_file_path=.github/workflows/boot-check.yml" \
  -f "scope=selected" \
  -F "selected_repository_ids[]=$(gh api /repos/$REPO --jq '.id')"
```

---

## Branch Protection Rulesets (Alternative Approach)

### 7. Create Ruleset for Enhanced Protection (GitHub Enterprise)

**Note:** Rulesets are available in GitHub Free for public repos and GitHub Enterprise

```bash
REPO="ChrisStephens1971/saas202544"

gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "/repos/$REPO/rulesets" \
  -f "name=main-protection" \
  -f "target=branch" \
  -f "enforcement=active" \
  -f "bypass_actors[0][actor_type]=RepositoryRole" \
  -f "bypass_actors[0][actor_id]=5" \
  -f "bypass_actors[0][bypass_mode]=always" \
  -f "conditions[ref_name][include][0]=refs/heads/main" \
  -f "rules[0][type]=pull_request" \
  -f "rules[0][parameters][required_approving_review_count]=1" \
  -f "rules[0][parameters][dismiss_stale_reviews_on_push]=true" \
  -f "rules[1][type]=required_status_checks" \
  -f "rules[1][parameters][required_status_checks][0][context]=boot-check" \
  -f "rules[1][parameters][required_status_checks][1][context]=terraform-plan (dev)" \
  -f "rules[1][parameters][strict_required_status_checks_policy]=true" \
  -f "rules[2][type]=non_fast_forward" \
  -f "rules[3][type]=deletion"
```

---

## Execution Checklist

Run these commands in order:

- [ ] **Step 1:** Get your GitHub user ID
  ```bash
  gh api user --jq '.id'
  ```

- [ ] **Step 2:** Apply branch protection to `main`
  ```bash
  # Run command from section 1
  ```

- [ ] **Step 3:** Verify branch protection
  ```bash
  # Run command from section 2
  ```

- [ ] **Step 4:** Create `stg` environment (replace user ID)
  ```bash
  # Run command from section 3
  ```

- [ ] **Step 5:** Create `prd` environment (replace user ID)
  ```bash
  # Run command from section 4
  ```

- [ ] **Step 6:** Verify environment protection
  ```bash
  # Run command from section 5
  ```

- [ ] **Optional:** Configure required workflows
  ```bash
  # Run command from section 6
  ```

---

## Testing Branch Protection

### Test 1: Direct Push to Main (Should Fail)

```bash
cd /c/devop/saas202544
echo "test" >> README.md
git add README.md
git commit -m "test: direct push"
git push origin main
```

**Expected result:** Push rejected (branch protection active)

---

### Test 2: PR Workflow (Should Succeed)

```bash
cd /c/devop/saas202544
git checkout -b test/branch-protection
echo "test" >> README.md
git add README.md
git commit -m "test: via PR"
git push origin test/branch-protection

# Create PR
gh pr create --title "Test: Branch Protection" --body "Testing branch protection rules"

# Wait for CI checks to pass, then merge
gh pr merge --auto --squash
```

**Expected result:**
- PR created successfully
- CI checks (boot-check, terraform-plan) run automatically
- Merge blocked until checks pass
- After checks pass, can merge with approval

---

### Test 3: Staging Deployment (Should Require Approval)

```bash
# Trigger staging deployment
gh workflow run infra-terraform.yml \
  --ref main \
  -f environment=stg \
  -f action=plan

# Check deployment status
gh run list --workflow=infra-terraform.yml --limit 1
```

**Expected result:**
- Workflow starts
- Waits for manual approval before proceeding
- Email/notification sent to approver

---

### Test 4: Production Deployment (Should Require Approval + Wait)

```bash
# Trigger production deployment
gh workflow run infra-terraform.yml \
  --ref main \
  -f environment=prd \
  -f action=plan

# Check deployment status
gh run list --workflow=infra-terraform.yml --limit 1
```

**Expected result:**
- Workflow starts
- Waits for manual approval
- After approval, waits 15 minutes (cooling-off period)
- Requires approval from someone other than requester
- Then proceeds with deployment

---

## Troubleshooting

### Issue: 404 Not Found

**Cause:** Missing permissions or incorrect repository name

**Fix:**
```bash
# Verify gh CLI authentication
gh auth status

# Re-authenticate with admin:repo_hook scope
gh auth refresh -h github.com -s admin:repo_hook
```

---

### Issue: Protection Already Exists

**Cause:** Branch protection rules already configured

**Fix:** Update existing protection:
```bash
# Use same command as section 1, but it will update instead of create
```

---

### Issue: Environment Protection Not Working

**Cause:** Workflow not referencing environment

**Fix:** Ensure workflow has `environment:` key:
```yaml
jobs:
  terraform-apply:
    environment: ${{ inputs.environment }}
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        run: terraform apply
```

---

## Compliance Mapping

**SOC 2 Controls:**
- ✅ CC6.8 - Change management (PR reviews required)
- ✅ CC7.2 - System monitoring (CI checks enforced)
- ✅ CC8.1 - Change authorization (environment approvals)

**CIS GitHub Benchmark:**
- ✅ 2.3.1 - Require status checks to pass before merging
- ✅ 2.3.2 - Require pull request reviews before merging
- ✅ 2.3.3 - Require signed commits (optional, not configured)
- ✅ 2.3.4 - Dismiss stale reviews on new commits
- ✅ 2.3.5 - Prevent force pushes to protected branches

---

## Summary

| Protection | Status | Notes |
|------------|--------|-------|
| Branch Protection (main) | 📋 Pending | Commands in section 1 |
| Required CI Checks | 📋 Pending | boot-check, terraform-plan (dev) |
| PR Reviews Required | 📋 Pending | 1 approval, dismiss stale |
| Force Push Blocked | 📋 Pending | Configured in section 1 |
| Environment: stg | 📋 Pending | Approval gate (section 3) |
| Environment: prd | 📋 Pending | Approval + 15min wait (section 4) |

**Next Steps:**
1. Get your GitHub user ID
2. Run commands in sections 1, 3, and 4
3. Verify with sections 2 and 5
4. Test with branch protection tests

**Last Updated:** 2025-11-08
**Owner:** chris.stephens@verdaio.com
