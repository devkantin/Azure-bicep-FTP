param name string
param location string
param tags object

resource availabilitySet 'Microsoft.Compute/availabilitySets@2023-09-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 5
  }
}

output id string = availabilitySet.id
output name string = availabilitySet.name
