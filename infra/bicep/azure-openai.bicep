// azure-openai.bicep
// Provisions Azure OpenAI resource, model deployments, and Managed Identity
// role assignment for the DFM PoC AI capabilities.
//
// Deploy with:
//   az deployment group create \
//     --resource-group <rg> \
//     --template-file infra/bicep/azure-openai.bicep \
//     --parameters environmentName=staging fabricWorkspaceObjectId=<objectId>

@description('Environment name (staging or production).')
@allowed(['staging', 'production'])
param environmentName string = 'staging'

@description('Object ID of the Microsoft Fabric workspace Managed Identity. Required for role assignment.')
param fabricWorkspaceObjectId string

@description('Azure region for the OpenAI resource.')
param location string = resourceGroup().location

@description('GPT-4o deployment capacity in thousands of tokens per minute (TPM).')
param gpt4oCapacityKtpm int = 30

@description('GPT-4o-mini deployment capacity in thousands of tokens per minute (TPM).')
param gpt4oMiniCapacityKtpm int = 50

@description('text-embedding-3-small deployment capacity in thousands of tokens per minute (TPM).')
param embeddingCapacityKtpm int = 100

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var resourceSuffix = environmentName == 'production' ? 'prod' : 'stg'
var openAiName = 'dfm-poc-openai-${resourceSuffix}'

// Built-in role: Cognitive Services OpenAI User
// https://learn.microsoft.com/azure/ai-services/openai/how-to/role-based-access-control
var cognitiveServicesOpenAiUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

// ---------------------------------------------------------------------------
// Azure OpenAI resource
// ---------------------------------------------------------------------------

resource openAi 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: openAiName
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: openAiName
    publicNetworkAccess: 'Enabled'
    // Note: For production, set publicNetworkAccess to 'Disabled' and configure
    // a private endpoint within the same VNet as the Fabric workspace.
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// ---------------------------------------------------------------------------
// Model deployments
// ---------------------------------------------------------------------------

resource gpt4oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: openAi
  name: 'gpt-4o'
  sku: {
    name: 'GlobalStandard'
    capacity: gpt4oCapacityKtpm
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-11-20'
    }
    versionUpgradeOption: 'OnceCurrentVersionExpired'
  }
}

resource gpt4oMiniDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: openAi
  name: 'gpt-4o-mini'
  dependsOn: [gpt4oDeployment]
  sku: {
    name: 'GlobalStandard'
    capacity: gpt4oMiniCapacityKtpm
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
    versionUpgradeOption: 'OnceCurrentVersionExpired'
  }
}

resource embeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: openAi
  name: 'text-embedding-3-small'
  dependsOn: [gpt4oMiniDeployment]
  sku: {
    name: 'Standard'
    capacity: embeddingCapacityKtpm
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-3-small'
      version: '1'
    }
    versionUpgradeOption: 'OnceCurrentVersionExpired'
  }
}

// ---------------------------------------------------------------------------
// Role assignment — Fabric workspace Managed Identity → OpenAI User
// ---------------------------------------------------------------------------

resource fabricRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAi.id, fabricWorkspaceObjectId, cognitiveServicesOpenAiUserRoleId)
  scope: openAi
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      cognitiveServicesOpenAiUserRoleId
    )
    principalId: fabricWorkspaceObjectId
    principalType: 'ServicePrincipal'
    description: 'Allows the Fabric workspace Managed Identity to call Azure OpenAI deployments.'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Azure OpenAI resource endpoint URL.')
output endpoint string = openAi.properties.endpoint

@description('Azure OpenAI resource name.')
output resourceName string = openAi.name

@description('GPT-4o deployment name.')
output gpt4oDeploymentName string = gpt4oDeployment.name

@description('GPT-4o-mini deployment name.')
output gpt4oMiniDeploymentName string = gpt4oMiniDeployment.name

@description('text-embedding-3-small deployment name.')
output embeddingDeploymentName string = embeddingDeployment.name
