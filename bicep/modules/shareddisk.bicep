param name string
param location string
param tags object

@description('Disk size in GB - must accommodate EFT sites, config, keys, and logs')
param diskSizeGb int = 256

resource sharedDisk 'Microsoft.Compute/disks@2023-10-02' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: diskSizeGb
    maxShares: 2
  }
}

output id string = sharedDisk.id
output name string = sharedDisk.name
