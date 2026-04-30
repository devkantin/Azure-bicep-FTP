param vnetName string
param location string
param tags object
param nsgId string
param vnetAddressPrefix string
param subnetPrefix string

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: 'snet-eft'
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: nsgId
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output subnetId string = vnet.properties.subnets[0].id
