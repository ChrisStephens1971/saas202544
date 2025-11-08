// Azure Hub Network with Firewall + DDoS + Bastion
// Part of: Azure Security Playbook v2.0
// Purpose: Deploy secure hub network infrastructure

targetScope = 'resourceGroup'

@description('Organization code (2-4 chars)')
param org string

@description('Environment (dev, tst, prd)')
param env string

@description('Azure region (short code, e.g., eus2, wus2)')
param region string

@description('Hub VNet address space')
param hubVNetAddressPrefix string = '10.0.0.0/16'

@description('Azure Firewall subnet address space')
param firewallSubnetPrefix string = '10.0.1.0/24'

@description('Azure Bastion subnet address space')
param bastionSubnetPrefix string = '10.0.2.0/24'

@description('Azure Firewall SKU (Standard or Premium)')
@allowed([
  'Standard'
  'Premium'
])
param firewallSku string = 'Premium'

@description('Enable DDoS Protection Standard')
param enableDDoS bool = true

@description('Tags for all resources')
param tags object = {
  Org: org
  Environment: env
  Region: region
  Purpose: 'hub-network'
}

var location = resourceGroup().location
var hubVNetName = 'vnet-${org}-hub-${env}-${region}'
var firewallName = 'azfw-${org}-hub-${env}-${region}'
var firewallPolicyName = 'azfw-policy-${org}-hub-${env}-${region}'
var bastionName = 'bastion-${org}-hub-${env}-${region}'
var bastionPipName = 'pip-bastion-${org}-hub-${env}-${region}'
var firewallPipName = 'pip-firewall-${org}-hub-${env}-${region}'
var ddosPlanName = 'ddos-plan-${org}-hub-${env}-${region}'

// DDoS Protection Plan (only for production)
resource ddosPlan 'Microsoft.Network/ddosProtectionPlans@2023-05-01' = if (enableDDoS) {
  name: ddosPlanName
  location: location
  tags: tags
  properties: {}
}

// Hub VNet
resource hubVNet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: hubVNetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVNetAddressPrefix
      ]
    }
    ddosProtectionPlan: enableDDoS ? {
      id: ddosPlan.id
    } : null
    enableDdosProtection: enableDDoS
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: firewallSubnetPrefix
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
    ]
  }
}

// Azure Firewall Policy
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-05-01' = {
  name: firewallPolicyName
  location: location
  tags: tags
  properties: {
    sku: {
      tier: firewallSku
    }
    threatIntelMode: 'Alert'
    threatIntelWhitelist: {
      ipAddresses: []
      fqdns: []
    }
    intrusionDetection: firewallSku == 'Premium' ? {
      mode: 'Alert'
      configuration: {
        signatureOverrides: []
        bypassTrafficSettings: []
      }
    } : null
    dnsSettings: {
      enableProxy: true
    }
    // TLS inspection (Premium only)
    transportSecurity: firewallSku == 'Premium' ? {
      certificateAuthority: {
        name: 'tls-inspection'
        // keyVaultSecretId: <key-vault-certificate-url>
      }
    } : null
  }
}

// Application rule collection - Allow-list
resource appRuleCollection 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-05-01' = {
  name: 'DefaultApplicationRuleCollectionGroup'
  parent: firewallPolicy
  properties: {
    priority: 100
    ruleCollections: [
      {
        name: 'AllowedOutbound'
        priority: 100
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'AllowPackageRepos'
            ruleType: 'ApplicationRule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              '*.npmjs.com'
              '*.pypi.org'
              '*.nuget.org'
              'github.com'
              '*.githubusercontent.com'
              'registry.hub.docker.com'
              '*.docker.io'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
            ]
          }
          {
            name: 'AllowAzureServices'
            ruleType: 'ApplicationRule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              '*.azure.com'
              '*.microsoft.com'
              '*.windows.net'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
            ]
          }
        ]
      }
    ]
  }
}

// Network rule collection - Basic connectivity
resource networkRuleCollection 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-05-01' = {
  name: 'DefaultNetworkRuleCollectionGroup'
  parent: firewallPolicy
  properties: {
    priority: 200
    ruleCollections: [
      {
        name: 'AllowDNS'
        priority: 100
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'AllowDNS'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'UDP'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '53'
            ]
          }
        ]
      }
    ]
  }
}

// Azure Firewall Public IP
resource firewallPip 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: firewallPipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Azure Firewall
resource firewall 'Microsoft.Network/azureFirewalls@2023-05-01' = {
  name: firewallName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: firewallSku
    }
    threatIntelMode: 'Alert'
    ipConfigurations: [
      {
        name: 'firewallIpConfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVNetName, 'AzureFirewallSubnet')
          }
          publicIPAddress: {
            id: firewallPip.id
          }
        }
      }
    ]
    firewallPolicy: {
      id: firewallPolicy.id
    }
  }
  dependsOn: [
    hubVNet
  ]
}

// Azure Bastion Public IP
resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: bastionPipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Azure Bastion
resource bastion 'Microsoft.Network/bastionHosts@2023-05-01' = {
  name: bastionName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVNetName, 'AzureBastionSubnet')
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
    enableFileCopy: true
    enableTunneling: true
  }
  dependsOn: [
    hubVNet
  ]
}

// Private DNS zones for Private Link services
var privateDnsZones = [
  'privatelink.vaultcore.azure.net'          // Key Vault
  'privatelink.blob.core.windows.net'        // Storage (Blob)
  'privatelink.file.core.windows.net'        // Storage (File)
  'privatelink.queue.core.windows.net'       // Storage (Queue)
  'privatelink.table.core.windows.net'       // Storage (Table)
  'privatelink.database.windows.net'         // SQL Database
  'privatelink.documents.azure.com'          // Cosmos DB
  'privatelink.azurecr.io'                   // Container Registry
  'privatelink.postgres.database.azure.com'  // PostgreSQL
  'privatelink.mysql.database.azure.com'     // MySQL
  'privatelink.redis.cache.windows.net'      // Redis Cache
]

resource privateDns 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zone in privateDnsZones: {
  name: zone
  location: 'global'
  tags: tags
}]

// Link private DNS zones to hub VNet
resource privateDnsLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zone, i) in privateDnsZones: {
  name: '${zone}-link-hub'
  parent: privateDns[i]
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVNet.id
    }
  }
}]

// Outputs
output hubVNetId string = hubVNet.id
output hubVNetName string = hubVNet.name
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallId string = firewall.id
output bastionId string = bastion.id
output privateDnsZoneIds array = [for i in range(0, length(privateDnsZones)): privateDns[i].id]
