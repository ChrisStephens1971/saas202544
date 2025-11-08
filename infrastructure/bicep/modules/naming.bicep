// Azure Naming Module
// Generates Azure resource names following Verdaio naming standard v1.1

@description('Organization code (2-4 chars)')
@minLength(2)
@maxLength(4)
param org string = 'vrd'

@description('Project code (2-5 chars)')
@minLength(2)
@maxLength(5)
param project string = '202544'

@description('Environment')
@allowed([
  'prd'
  'stg'
  'dev'
  'tst'
  'sbx'
])
param env string

@description('Azure region short code')
param region string

@description('Azure location full name')
param location string

@description('Logical slice')
@allowed([
  'app'
  'data'
  'net'
  'sec'
  'ops'
])
param slice string

@description('Owner email')
param owner string

@description('Cost center')
param costCenter string

@description('Data sensitivity level')
@allowed([
  'public'
  'internal'
  'confidential'
  'regulated'
])
param dataSensitivity string = 'internal'

@description('Compliance requirements')
@allowed([
  'none'
  'pci'
  'hipaa'
  'sox'
  'gdpr'
])
param compliance string = 'none'

@description('Business unit (optional)')
param businessUnit string = ''

@description('Application name (optional)')
param application string = ''

// Build name prefix
var namePrefix = '${org}-${project}-${env}-${region}'

// Build common tags
var commonTags = union(
  {
    Org: org
    Project: project
    Environment: env
    Region: region
    Owner: owner
    CostCenter: costCenter
    DataSensitivity: dataSensitivity
    Compliance: compliance
    CreatedDate: utcNow('yyyy-MM-dd')
    ManagedBy: 'bicep'
  },
  !empty(businessUnit) ? { BusinessUnit: businessUnit } : {},
  !empty(application) ? { Application: application } : {}
)

// Resource naming outputs
output namePrefix string = namePrefix
output resourceGroupName string = 'rg-${namePrefix}-${slice}'
output appServicePlanName string = 'asp-${namePrefix}'
output appServiceName string = 'app-${namePrefix}'
output functionAppName string = 'func-${namePrefix}'
output storageAccountName string = 'st${org}${project}${env}${region}'
output keyVaultName string = 'kv-${namePrefix}'
output containerRegistryName string = 'acr${org}${project}${env}${region}'
output sqlServerName string = 'sqlsvr-${namePrefix}'
output sqlDatabaseName string = 'sqldb-${namePrefix}'
output cosmosDbName string = 'cosmos-${namePrefix}'
output redisCacheName string = 'redis-${namePrefix}'
output serviceBusName string = 'sb-${namePrefix}'
output eventHubName string = 'eh-${namePrefix}'
output logAnalyticsName string = 'la-${namePrefix}'
output appInsightsName string = 'appi-${namePrefix}'
output vnetName string = 'vnet-${namePrefix}'
output subnetName string = 'snet-${namePrefix}'
output nsgName string = 'nsg-${namePrefix}'
output aksClusterName string = 'aks-${namePrefix}'
output commonTags object = commonTags
output location string = location
