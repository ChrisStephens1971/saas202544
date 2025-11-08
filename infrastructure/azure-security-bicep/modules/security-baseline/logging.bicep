// Logging & Monitoring Infrastructure
// Part of: Azure Security Playbook v2.0
// Purpose: Deploy Log Analytics workspace and enable Azure Sentinel

targetScope = 'resourceGroup'

@description('Organization code (2-4 chars)')
param org string

@description('Environment (dev, tst, prd)')
param env string

@description('Azure region (short code, e.g., eus2, wus2)')
param region string

@description('Log Analytics retention in days (30-730)')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

@description('Log Analytics daily quota in GB (-1 for unlimited)')
param dailyQuotaGb int = -1

@description('Enable Azure Sentinel')
param enableSentinel bool = true

@description('Enable Application Insights')
param enableAppInsights bool = true

@description('Tags for all resources')
param tags object = {
  Org: org
  Environment: env
  Region: region
  Purpose: 'logging-monitoring'
}

var location = resourceGroup().location
var lawName = 'la-${org}-platform-${env}-${region}'
var sentinelName = 'sentinel-${org}-platform-${env}-${region}'
var appInsightsName = 'appi-${org}-platform-${env}-${region}'

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: lawName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: dailyQuotaGb > 0 ? {
      dailyQuotaGb: dailyQuotaGb
    } : null
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Sentinel workspace (built on Log Analytics)
resource sentinel 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = if (enableSentinel) {
  name: sentinelName
  location: location
  tags: tags
  plan: {
    name: sentinelName
    publisher: 'Microsoft'
    product: 'OMSGallery/SecurityInsights'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
}

// Application Insights (for application monitoring)
resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (enableAppInsights) {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Table-level retention settings (configure specific tables)
resource azureActivityTable 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  name: 'AzureActivity'
  parent: logAnalyticsWorkspace
  properties: {
    retentionInDays: 90
    plan: 'Analytics'
  }
}

resource azureDiagnosticsTable 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  name: 'AzureDiagnostics'
  parent: logAnalyticsWorkspace
  properties: {
    retentionInDays: retentionInDays
    totalRetentionInDays: 365  // Archive after retention period
    plan: 'Analytics'
  }
}

resource securityEventTable 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  name: 'SecurityEvent'
  parent: logAnalyticsWorkspace
  properties: {
    retentionInDays: 90
    plan: 'Analytics'
  }
}

// Data collection rules for cost optimization
resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcr-${org}-platform-${env}-${region}'
  location: location
  tags: tags
  kind: 'Linux'
  properties: {
    dataSources: {
      performanceCounters: [
        {
          name: 'perfCounterDataSource'
          streams: [
            'Microsoft-Perf'
          ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            'Processor(*)\\% Processor Time'
            'Memory(*)\\Available MBytes'
            'LogicalDisk(*)\\Disk Bytes/sec'
          ]
        }
      ]
      syslog: [
        {
          name: 'syslogDataSource'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'auth'
            'authpriv'
            'cron'
            'daemon'
            'mark'
            'kern'
            'syslog'
          ]
          logLevels: [
            'Warning'
            'Error'
            'Critical'
            'Alert'
            'Emergency'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsWorkspace.id
          name: 'centralWorkspace'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Perf'
          'Microsoft-Syslog'
        ]
        destinations: [
          'centralWorkspace'
        ]
      }
    ]
  }
}

// Outputs
output workspaceId string = logAnalyticsWorkspace.id
output workspaceName string = logAnalyticsWorkspace.name
output workspaceResourceId string = logAnalyticsWorkspace.properties.customerId
output appInsightsId string = enableAppInsights ? appInsights.id : ''
output appInsightsInstrumentationKey string = enableAppInsights ? appInsights.properties.InstrumentationKey : ''
output appInsightsConnectionString string = enableAppInsights ? appInsights.properties.ConnectionString : ''
output dataCollectionRuleId string = dataCollectionRule.id
