// Main Bicep Configuration
// Azure SaaS Project: saas202544

targetScope = 'subscription'

@description('Environment')
@allowed([
  'prd'
  'stg'
  'dev'
  'tst'
  'sbx'
])
param env string

@description('Azure location')
param location string

@description('Logical slice')
@allowed([
  'app'
  'data'
  'net'
])
param slice string

// Import naming module
module naming 'modules/naming.bicep' = {
  name: 'naming'
  params: {
    env: env
    region: regionShortCode
    location: location
    slice: slice
    owner: 'ops@verdaio.com'
    costCenter: '202544-llc'
  }
}

// Region mapping
var regionShortCode = location == 'eastus2' ? 'eus2' : location == 'westus2' ? 'wus2' : 'eus2'

// Resource Groups
resource rgApp 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${naming.outputs.resourceGroupName}-app'
  location: location
  tags: naming.outputs.commonTags
}

resource rgData 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${naming.outputs.resourceGroupName}-data'
  location: location
  tags: naming.outputs.commonTags
}

resource rgNet 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${naming.outputs.resourceGroupName}-net'
  location: location
  tags: naming.outputs.commonTags
}

// Log Analytics Workspace
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'logAnalytics'
  scope: rgApp
  params: {
    name: naming.outputs.logAnalyticsName
    location: location
    tags: naming.outputs.commonTags
  }
}

// Application Insights
module appInsights 'modules/app-insights.bicep' = {
  name: 'appInsights'
  scope: rgApp
  params: {
    name: naming.outputs.appInsightsName
    location: location
    workspaceId: logAnalytics.outputs.id
    tags: naming.outputs.commonTags
  }
}

// Key Vault
module keyVault 'modules/key-vault.bicep' = {
  name: 'keyVault'
  scope: rgApp
  params: {
    name: '${naming.outputs.keyVaultName}-01'
    location: location
    tags: naming.outputs.commonTags
  }
}

// Virtual Network
module vnet 'modules/vnet.bicep' = {
  name: 'vnet'
  scope: rgNet
  params: {
    name: naming.outputs.vnetName
    location: location
    addressPrefix: '10.0.0.0/16'
    tags: naming.outputs.commonTags
  }
}

// Outputs
output resourceGroupAppName string = rgApp.name
output resourceGroupDataName string = rgData.name
output resourceGroupNetName string = rgNet.name
output keyVaultName string = keyVault.outputs.name
output vnetName string = vnet.outputs.name
output appInsightsInstrumentationKey string = appInsights.outputs.instrumentationKey
