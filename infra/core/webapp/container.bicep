param webAppName string
param containerRegistry string
param imageName string

// Reference the Web App resource
resource webApp 'Microsoft.Web/sites@2021-02-01' existing = {
  name: webAppName
  scope: resourceGroup()
}

// Update the container configuration for the Web App
resource containerSettings 'Microsoft.Web/sites/config@2021-02-01' = {
  name: '${webApp.name}/containerSettings'
  properties: {
    linuxFxVersion: 'DOCKER|${containerRegistry}/${imageName}'
    containerRegistryUrl: 'https://${containerRegistry}'
  }
}
