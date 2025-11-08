// Microsoft Defender for Cloud - Enable All Plans
// Part of: Azure Security Playbook v2.0
// Purpose: Enable Defender for Cloud for all resource types

targetScope = 'subscription'

@description('Enable Defender for Virtual Machines')
param enableVirtualMachines bool = true

@description('Enable Defender for App Services')
param enableAppServices bool = true

@description('Enable Defender for SQL Servers')
param enableSqlServers bool = true

@description('Enable Defender for SQL Server on Machines')
param enableSqlServerVirtualMachines bool = true

@description('Enable Defender for Storage Accounts')
param enableStorageAccounts bool = true

@description('Enable Defender for Kubernetes')
param enableKubernetes bool = true

@description('Enable Defender for Container Registries')
param enableContainerRegistry bool = true

@description('Enable Defender for Key Vaults')
param enableKeyVaults bool = true

@description('Enable Defender for DNS')
param enableDns bool = true

@description('Enable Defender for Resource Manager')
param enableArm bool = true

@description('Enable Defender for Cosmos DB')
param enableCosmosDb bool = true

@description('Enable Defender for Databases')
param enableDatabases bool = true

// Defender for Virtual Machines (Plan 2)
resource defenderVms 'Microsoft.Security/pricings@2023-01-01' = if (enableVirtualMachines) {
  name: 'VirtualMachines'
  properties: {
    pricingTier: 'Standard'
    subPlan: 'P2'
  }
}

// Defender for App Services
resource defenderAppServices 'Microsoft.Security/pricings@2023-01-01' = if (enableAppServices) {
  name: 'AppServices'
  properties: {
    pricingTier: 'Standard'
  }
}

// Defender for SQL Servers (PaaS)
resource defenderSqlServers 'Microsoft.Security/pricings@2023-01-01' = if (enableSqlServers) {
  name: 'SqlServers'
  properties: {
    pricingTier: 'Standard'
  }
}

// Defender for SQL Server on VMs
resource defenderSqlServerVMs 'Microsoft.Security/pricings@2023-01-01' = if (enableSqlServerVirtualMachines) {
  name: 'SqlServerVirtualMachines'
  properties: {
    pricingTier: 'Standard'
  }
}

// Defender for Storage Accounts (with malware scanning)
resource defenderStorage 'Microsoft.Security/pricings@2023-01-01' = if (enableStorageAccounts) {
  name: 'StorageAccounts'
  properties: {
    pricingTier: 'Standard'
    subPlan: 'DefenderForStorageV2'
    extensions: [
      {
        name: 'OnUploadMalwareScanning'
        isEnabled: 'True'
        additionalExtensionProperties: {
          CapGBPerMonthPerStorageAccount: '5000'
        }
      }
      {
        name: 'SensitiveDataDiscovery'
        isEnabled: 'True'
      }
    ]
  }
}

// Defender for Kubernetes (AKS)
resource defenderKubernetes 'Microsoft.Security/pricings@2023-01-01' = if (enableKubernetes) {
  name: 'KubernetesService'
  properties: {
    pricingTier: 'Standard'
  }
}

// Defender for Container Registries
resource defenderContainerRegistry 'Microsoft.Security/pricings@2023-01-01' = if (enableContainerRegistry) {
  name: 'ContainerRegistry'
  properties: {
    pricingTier: 'Standard'
  }
}

// Defender for Key Vaults
resource defenderKeyVault 'Microsoft.Security/pricings@2023-01-01' = if (enableKeyVaults) {
  name: 'KeyVaults'
  properties: {
    pricingTier: 'Standard'
  }
}

// Defender for DNS
resource defenderDns 'Microsoft.Security/pricings@2023-01-01' = if (enableDns) {
  name: 'Dns'
  properties: {
    pricingTier: 'Standard'
  }
}

// Defender for Azure Resource Manager
resource defenderArm 'Microsoft.Security/pricings@2023-01-01' = if (enableArm) {
  name: 'Arm'
  properties: {
    pricingTier: 'Standard'
  }
}

// Defender for Cosmos DB
resource defenderCosmosDb 'Microsoft.Security/pricings@2023-01-01' = if (enableCosmosDb) {
  name: 'CosmosDbs'
  properties: {
    pricingTier: 'Standard'
  }
}

// Defender for Open Source Databases (PostgreSQL, MySQL, MariaDB)
resource defenderDatabases 'Microsoft.Security/pricings@2023-01-01' = if (enableDatabases) {
  name: 'OpenSourceRelationalDatabases'
  properties: {
    pricingTier: 'Standard'
  }
}

// Security Contacts
resource securityContacts 'Microsoft.Security/securityContacts@2020-01-01-preview' = {
  name: 'default'
  properties: {
    emails: 'security@verdaio.com'
    phone: ''
    alertNotifications: {
      state: 'On'
      minimalSeverity: 'High'
    }
    notificationsByRole: {
      state: 'On'
      roles: [
        'Owner'
        'Contributor'
      ]
    }
  }
}

// Auto-provisioning for Log Analytics agent
resource autoProvisioningSettings 'Microsoft.Security/autoProvisioningSettings@2017-08-01-preview' = {
  name: 'default'
  properties: {
    autoProvision: 'On'
  }
}

// Outputs
output defenderPlansEnabled array = [
  {
    plan: 'VirtualMachines'
    enabled: enableVirtualMachines
  }
  {
    plan: 'AppServices'
    enabled: enableAppServices
  }
  {
    plan: 'SqlServers'
    enabled: enableSqlServers
  }
  {
    plan: 'SqlServerVirtualMachines'
    enabled: enableSqlServerVirtualMachines
  }
  {
    plan: 'StorageAccounts'
    enabled: enableStorageAccounts
  }
  {
    plan: 'KubernetesService'
    enabled: enableKubernetes
  }
  {
    plan: 'ContainerRegistry'
    enabled: enableContainerRegistry
  }
  {
    plan: 'KeyVaults'
    enabled: enableKeyVaults
  }
  {
    plan: 'Dns'
    enabled: enableDns
  }
  {
    plan: 'Arm'
    enabled: enableArm
  }
  {
    plan: 'CosmosDbs'
    enabled: enableCosmosDb
  }
  {
    plan: 'OpenSourceRelationalDatabases'
    enabled: enableDatabases
  }
]
