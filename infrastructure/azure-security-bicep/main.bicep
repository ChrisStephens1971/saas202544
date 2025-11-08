// Azure Security Baseline - Main Deployment
// Part of: Azure Security Playbook v2.0
// Purpose: Orchestrate deployment of complete security baseline

targetScope = 'subscription'

@description('Organization code (2-4 chars)')
param org string = 'vrd'

@description('Project code (2-5 chars)')
param proj string = 'tmt'

@description('Environment (dev, tst, prd)')
@allowed([
  'dev'
  'tst'
  'prd'
])
param env string = 'prd'

@description('Primary Azure region (short code)')
param primaryRegion string = 'eus2'

@description('Deploy hub network infrastructure')
param deployHub bool = true

@description('Deploy spoke network infrastructure')
param deploySpoke bool = true

@description('Enable DDoS Protection (recommended for production only)')
param enableDDoS bool = (env == 'prd')

@description('Azure Firewall SKU (Standard for dev/test, Premium for production)')
@allowed([
  'Standard'
  'Premium'
])
param firewallSku string = (env == 'prd') ? 'Premium' : 'Standard'

@description('Products to create management groups for')
param products array = [
  'tmt'
  'hoa'
]

@description('Tags for all resources')
param tags object = {
  Org: org
  Project: proj
  Environment: env
  Region: primaryRegion
  DeployedBy: 'Bicep'
  DeployedDate: utcNow('yyyy-MM-dd')
}

var location = primaryRegion == 'eus2' ? 'eastus2' : primaryRegion == 'wus2' ? 'westus2' : 'centralus'
var platformRgName = 'rg-${org}-platform-${env}-${primaryRegion}'
var opsRgName = 'rg-${org}-platform-${env}-${primaryRegion}-ops'
var networkRgName = 'rg-${org}-platform-${env}-${primaryRegion}-net'
var projectRgName = 'rg-${org}-${proj}-${env}-${primaryRegion}'

// Resource Groups
resource platformRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: platformRgName
  location: location
  tags: tags
}

resource opsRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: opsRgName
  location: location
  tags: union(tags, {
    Purpose: 'logging-monitoring'
  })
}

resource networkRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: networkRgName
  location: location
  tags: union(tags, {
    Purpose: 'network-infrastructure'
  })
}

resource projectRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: projectRgName
  location: location
  tags: union(tags, {
    Purpose: 'application-workload'
  })
}

// Module: Logging & Monitoring
module logging 'modules/security-baseline/logging.bicep' = {
  name: 'deploy-logging'
  scope: opsRg
  params: {
    org: org
    env: env
    region: primaryRegion
    retentionInDays: env == 'prd' ? 90 : 30
    enableSentinel: true
    enableAppInsights: true
    tags: tags
  }
}

// Module: Microsoft Defender for Cloud
module defender 'modules/security-baseline/defender.bicep' = {
  name: 'deploy-defender'
  params: {
    enableVirtualMachines: true
    enableAppServices: true
    enableSqlServers: true
    enableStorageAccounts: true
    enableKubernetes: true
    enableContainerRegistry: true
    enableKeyVaults: true
    enableDns: true
    enableArm: true
    enableCosmosDb: true
    enableDatabases: true
  }
}

// Module: Hub Network
module hubNetwork 'modules/security-baseline/hub-network.bicep' = if (deployHub) {
  name: 'deploy-hub-network'
  scope: networkRg
  params: {
    org: org
    env: env
    region: primaryRegion
    hubVNetAddressPrefix: '10.0.0.0/16'
    firewallSubnetPrefix: '10.0.1.0/24'
    bastionSubnetPrefix: '10.0.2.0/24'
    firewallSku: firewallSku
    enableDDoS: enableDDoS
    tags: tags
  }
}

// Module: Spoke Network
module spokeNetwork 'modules/security-baseline/spoke-network.bicep' = if (deploySpoke && deployHub) {
  name: 'deploy-spoke-network'
  scope: projectRg
  params: {
    org: org
    proj: proj
    env: env
    region: primaryRegion
    spokeVNetAddressPrefix: '10.1.0.0/16'
    appSubnetPrefix: '10.1.1.0/24'
    dataSubnetPrefix: '10.1.2.0/24'
    privateEndpointSubnetPrefix: '10.1.3.0/24'
    hubVNetId: deployHub ? hubNetwork.outputs.hubVNetId : ''
    hubFirewallPrivateIp: deployHub ? hubNetwork.outputs.firewallPrivateIp : ''
    tags: tags
  }
  dependsOn: [
    hubNetwork
  ]
}

// Outputs
output resourceGroups object = {
  platform: platformRg.id
  ops: opsRg.id
  network: networkRg.id
  project: projectRg.id
}

output logging object = {
  workspaceId: logging.outputs.workspaceId
  workspaceName: logging.outputs.workspaceName
  appInsightsId: logging.outputs.appInsightsId
}

output network object = deployHub ? {
  hubVNetId: hubNetwork.outputs.hubVNetId
  firewallPrivateIp: hubNetwork.outputs.firewallPrivateIp
  spokeVNetId: deploySpoke ? spokeNetwork.outputs.spokeVNetId : ''
  appSubnetId: deploySpoke ? spokeNetwork.outputs.appSubnetId : ''
} : {}

output defenderPlans array = defender.outputs.defenderPlansEnabled
