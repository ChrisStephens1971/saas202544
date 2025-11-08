// Azure Spoke Network with NSGs and Private Endpoints
// Part of: Azure Security Playbook v2.0
// Purpose: Deploy secure spoke network for workloads

targetScope = 'resourceGroup'

@description('Organization code (2-4 chars)')
param org string

@description('Project code (2-5 chars)')
param proj string

@description('Environment (dev, tst, prd)')
param env string

@description('Azure region (short code, e.g., eus2, wus2)')
param region string

@description('Spoke VNet address space')
param spokeVNetAddressPrefix string = '10.1.0.0/16'

@description('Application subnet address space')
param appSubnetPrefix string = '10.1.1.0/24'

@description('Data subnet address space')
param dataSubnetPrefix string = '10.1.2.0/24'

@description('Private endpoint subnet address space')
param privateEndpointSubnetPrefix string = '10.1.3.0/24'

@description('Hub VNet resource ID for peering')
param hubVNetId string

@description('Hub firewall private IP for routing')
param hubFirewallPrivateIp string

@description('Tags for all resources')
param tags object = {
  Org: org
  Project: proj
  Environment: env
  Region: region
}

var location = resourceGroup().location
var spokeVNetName = 'vnet-${org}-${proj}-${env}-${region}'
var appNsgName = 'nsg-${org}-${proj}-${env}-${region}-app'
var dataNsgName = 'nsg-${org}-${proj}-${env}-${region}-data'
var peNsgName = 'nsg-${org}-${proj}-${env}-${region}-pe'
var routeTableName = 'rt-${org}-${proj}-${env}-${region}'

// Route table to force traffic through hub firewall
resource routeTable 'Microsoft.Network/routeTables@2023-05-01' = {
  name: routeTableName
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'DefaultRouteToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: hubFirewallPrivateIp
        }
      }
    ]
  }
}

// NSG for application subnet
resource appNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: appNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all inbound from Internet'
        }
      }
      {
        name: 'AllowVNetInbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
          description: 'Allow VNet to VNet'
        }
      }
      {
        name: 'DenyAllOutbound'
        properties: {
          priority: 4096
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all outbound (forced through firewall)'
        }
      }
    ]
  }
}

// NSG for data subnet
resource dataNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: dataNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all inbound from Internet'
        }
      }
      {
        name: 'AllowAppSubnetInbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: appSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '1433'  // SQL
            '5432'  // PostgreSQL
            '3306'  // MySQL
            '6379'  // Redis
            '27017' // MongoDB
          ]
          description: 'Allow app subnet to access data services'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all other inbound'
        }
      }
    ]
  }
}

// NSG for private endpoint subnet (minimal restrictions)
resource peNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: peNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowVNetInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
          description: 'Allow VNet to VNet for private endpoints'
        }
      }
    ]
  }
}

// Spoke VNet
resource spokeVNet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: spokeVNetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeVNetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-${org}-${proj}-${env}-${region}-app'
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: {
            id: appNsg.id
          }
          routeTable: {
            id: routeTable.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'snet-${org}-${proj}-${env}-${region}-data'
        properties: {
          addressPrefix: dataSubnetPrefix
          networkSecurityGroup: {
            id: dataNsg.id
          }
          routeTable: {
            id: routeTable.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'snet-${org}-${proj}-${env}-${region}-pe'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          networkSecurityGroup: {
            id: peNsg.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// VNet peering to hub
resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  name: 'peer-spoke-to-hub'
  parent: spokeVNet
  properties: {
    remoteVirtualNetwork: {
      id: hubVNetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// Note: Hub-to-spoke peering must be created in hub deployment
// See hub-network.bicep for bidirectional peering setup

// Outputs
output spokeVNetId string = spokeVNet.id
output spokeVNetName string = spokeVNet.name
output appSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVNetName, 'snet-${org}-${proj}-${env}-${region}-app')
output dataSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVNetName, 'snet-${org}-${proj}-${env}-${region}-data')
output privateEndpointSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVNetName, 'snet-${org}-${proj}-${env}-${region}-pe')
output appNsgId string = appNsg.id
output dataNsgId string = dataNsg.id
