// Azure Management Group Hierarchy
// Part of: Azure Security Playbook v2.0
// Purpose: Create management group hierarchy for organization

targetScope = 'tenant'

@description('Organization code (2-4 chars)')
param orgCode string

@description('Product names to create management groups for')
param products array = []

// Root management group (automatically exists)
// We create child management groups under it

// Platform management group - shared infrastructure
resource platformMG 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: 'mg-${orgCode}-platform'
  properties: {
    displayName: 'Platform'
    details: {
      parent: {
        id: tenantResourceId('Microsoft.Management/managementGroups', 'mg-${orgCode}-root')
      }
    }
  }
}

// Corporate management group - corporate services
resource corpMG 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: 'mg-${orgCode}-corp'
  properties: {
    displayName: 'Corporate'
    details: {
      parent: {
        id: tenantResourceId('Microsoft.Management/managementGroups', 'mg-${orgCode}-root')
      }
    }
  }
}

// Sandbox management group - developer experimentation
resource sandboxMG 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: 'mg-${orgCode}-sandbox'
  properties: {
    displayName: 'Sandbox'
    details: {
      parent: {
        id: tenantResourceId('Microsoft.Management/managementGroups', 'mg-${orgCode}-root')
      }
    }
  }
}

// Products management group - production workloads
resource productsMG 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: 'mg-${orgCode}-products'
  properties: {
    displayName: 'Products'
    details: {
      parent: {
        id: tenantResourceId('Microsoft.Management/managementGroups', 'mg-${orgCode}-root')
      }
    }
  }
}

// Create per-product management groups
resource prodMGs 'Microsoft.Management/managementGroups@2023-04-01' = [for product in products: {
  name: 'mg-${orgCode}-prod-${product}'
  properties: {
    displayName: 'Production - ${product}'
    details: {
      parent: {
        id: productsMG.id
      }
    }
  }
}]

resource nonprodMGs 'Microsoft.Management/managementGroups@2023-04-01' = [for product in products: {
  name: 'mg-${orgCode}-nonprod-${product}'
  properties: {
    displayName: 'Non-Production - ${product}'
    details: {
      parent: {
        id: productsMG.id
      }
    }
  }
}]

// Outputs
output platformMGId string = platformMG.id
output corpMGId string = corpMG.id
output sandboxMGId string = sandboxMG.id
output productsMGId string = productsMG.id
output prodMGIds array = [for i in range(0, length(products)): prodMGs[i].id]
output nonprodMGIds array = [for i in range(0, length(products)): nonprodMGs[i].id]
