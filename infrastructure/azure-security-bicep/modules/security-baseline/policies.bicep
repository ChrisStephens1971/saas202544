// Azure Policy Assignments for Security Baseline
// Part of: Azure Security Playbook v2.0
// Purpose: Enforce security guardrails via Azure Policy

targetScope = 'managementGroup'

@description('Management group ID to apply policies to')
param managementGroupId string

@description('Log Analytics workspace resource ID for diagnostic settings')
param logAnalyticsWorkspaceId string

@description('Azure region for policy assignment identity')
param location string

// Built-in policy definitions (by ID)
var policyDefinitions = {
  denyPublicNetworkAccessStorage: '/providers/Microsoft.Authorization/policyDefinitions/34c877ad-507e-4c82-993e-3452a6e0ad3c'
  enforceHttpsStorage: '/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9'
  enforceTls12: '/providers/Microsoft.Authorization/policyDefinitions/fe83a0eb-a853-422d-aac2-1bffd182c5d0'
  requireDiskEncryption: '/providers/Microsoft.Authorization/policyDefinitions/0961003e-5a0a-4549-abde-af6a37f2724d'
  requirePrivateEndpoints: '/providers/Microsoft.Authorization/policySetDefinitions/a33a8e05-4fc2-47e6-8a1d-cf4f1c7e6eda'
  autoDiagnosticSettings: '/providers/Microsoft.Authorization/policyDefinitions/7f89b1eb-583c-429a-8828-af049802c1d9'
  requireTags: '/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025'
  inheritTags: '/providers/Microsoft.Authorization/policyDefinitions/cd3aa116-8754-49c3-b9be-2e4c0f58f2d6'
  allowedRegions: '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'
  allowedVMSkus: '/providers/Microsoft.Authorization/policyDefinitions/cccc23c7-8427-4f53-ad12-b6a63eb452b3'
}

// 1. Deny public network access for Storage Accounts
resource denyPublicStorage 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'deny-public-storage'
  properties: {
    displayName: 'Deny public network access for Storage Accounts'
    description: 'Denies public network access for storage accounts to enforce private-only connectivity'
    policyDefinitionId: policyDefinitions.denyPublicNetworkAccessStorage
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
    enforcementMode: 'Default'
  }
  location: location
  identity: {
    type: 'SystemAssigned'
  }
}

// 2. Enforce HTTPS-only for Storage Accounts
resource enforceHttpsStorage 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'enforce-https-storage'
  properties: {
    displayName: 'Enforce HTTPS-only for Storage Accounts'
    description: 'Requires HTTPS for all storage account access'
    policyDefinitionId: policyDefinitions.enforceHttpsStorage
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
    enforcementMode: 'Default'
  }
}

// 3. Enforce TLS 1.2+ for all services
resource enforceTls12 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'enforce-tls-1-2'
  properties: {
    displayName: 'Enforce minimum TLS 1.2'
    description: 'Requires TLS 1.2 or higher for all services'
    policyDefinitionId: policyDefinitions.enforceTls12
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
    enforcementMode: 'Default'
  }
}

// 4. Require disk encryption
resource requireDiskEncryption 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'require-disk-encryption'
  properties: {
    displayName: 'Require disk encryption for VMs'
    description: 'Requires Azure Disk Encryption for all virtual machines'
    policyDefinitionId: policyDefinitions.requireDiskEncryption
    parameters: {
      effect: {
        value: 'Audit'  // Start with Audit, change to Deny after validation
      }
    }
    enforcementMode: 'Default'
  }
}

// 5. Auto-enable diagnostic settings
resource autoDiagnostics 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'auto-diagnostic-settings'
  properties: {
    displayName: 'Auto-enable diagnostic settings to Log Analytics'
    description: 'Automatically enables diagnostic settings for all resources'
    policyDefinitionId: policyDefinitions.autoDiagnosticSettings
    parameters: {
      logAnalytics: {
        value: logAnalyticsWorkspaceId
      }
    }
    enforcementMode: 'Default'
  }
  location: location
  identity: {
    type: 'SystemAssigned'
  }
}

// 6. Require 'Org' tag on resource groups
resource requireOrgTag 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'require-org-tag'
  properties: {
    displayName: 'Require Org tag on resource groups'
    description: 'Requires the Org tag on all resource groups'
    policyDefinitionId: policyDefinitions.requireTags
    parameters: {
      tagName: {
        value: 'Org'
      }
    }
    enforcementMode: 'Default'
  }
}

// 7. Require 'Environment' tag on resource groups
resource requireEnvTag 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'require-env-tag'
  properties: {
    displayName: 'Require Environment tag on resource groups'
    description: 'Requires the Environment tag on all resource groups'
    policyDefinitionId: policyDefinitions.requireTags
    parameters: {
      tagName: {
        value: 'Environment'
      }
    }
    enforcementMode: 'Default'
  }
}

// 8. Require 'Owner' tag on resource groups
resource requireOwnerTag 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'require-owner-tag'
  properties: {
    displayName: 'Require Owner tag on resource groups'
    description: 'Requires the Owner tag on all resource groups'
    policyDefinitionId: policyDefinitions.requireTags
    parameters: {
      tagName: {
        value: 'Owner'
      }
    }
    enforcementMode: 'Default'
  }
}

// 9. Inherit 'Org' tag from resource group
resource inheritOrgTag 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'inherit-org-tag'
  properties: {
    displayName: 'Inherit Org tag from resource group'
    description: 'Automatically inherits the Org tag from the parent resource group'
    policyDefinitionId: policyDefinitions.inheritTags
    parameters: {
      tagName: {
        value: 'Org'
      }
    }
    enforcementMode: 'Default'
  }
  location: location
  identity: {
    type: 'SystemAssigned'
  }
}

// 10. Inherit 'Environment' tag from resource group
resource inheritEnvTag 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'inherit-env-tag'
  properties: {
    displayName: 'Inherit Environment tag from resource group'
    description: 'Automatically inherits the Environment tag from the parent resource group'
    policyDefinitionId: policyDefinitions.inheritTags
    parameters: {
      tagName: {
        value: 'Environment'
      }
    }
    enforcementMode: 'Default'
  }
  location: location
  identity: {
    type: 'SystemAssigned'
  }
}

// 11. Restrict to allowed regions
resource allowedRegions 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'allowed-regions'
  properties: {
    displayName: 'Restrict resource creation to allowed regions'
    description: 'Restricts resources to approved Azure regions only'
    policyDefinitionId: policyDefinitions.allowedRegions
    parameters: {
      listOfAllowedLocations: {
        value: [
          'eastus2'
          'westus2'
          'centralus'
        ]
      }
    }
    enforcementMode: 'Default'
  }
}

// 12. Restrict VM SKUs (cost control)
resource allowedVMSkus 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'allowed-vm-skus'
  properties: {
    displayName: 'Restrict VM SKUs to approved list'
    description: 'Restricts VM creation to approved SKUs only for cost control'
    policyDefinitionId: policyDefinitions.allowedVMSkus
    parameters: {
      listOfAllowedSKUs: {
        value: [
          'Standard_B2s'
          'Standard_B2ms'
          'Standard_D2s_v3'
          'Standard_D4s_v3'
          'Standard_D8s_v3'
          'Standard_E2s_v3'
          'Standard_E4s_v3'
        ]
      }
    }
    enforcementMode: 'Default'
  }
}

// Grant RBAC to policy-assigned identities
// Note: These require additional role assignments at deployment

// Outputs
output policyAssignmentIds array = [
  denyPublicStorage.id
  enforceHttpsStorage.id
  enforceTls12.id
  requireDiskEncryption.id
  autoDiagnostics.id
  requireOrgTag.id
  requireEnvTag.id
  requireOwnerTag.id
  inheritOrgTag.id
  inheritEnvTag.id
  allowedRegions.id
  allowedVMSkus.id
]

output policyIdentities array = [
  {
    name: 'denyPublicStorage'
    principalId: denyPublicStorage.identity.principalId
    role: 'Contributor'
  }
  {
    name: 'autoDiagnostics'
    principalId: autoDiagnostics.identity.principalId
    role: 'Log Analytics Contributor'
  }
  {
    name: 'inheritOrgTag'
    principalId: inheritOrgTag.identity.principalId
    role: 'Tag Contributor'
  }
  {
    name: 'inheritEnvTag'
    principalId: inheritEnvTag.identity.principalId
    role: 'Tag Contributor'
  }
]
