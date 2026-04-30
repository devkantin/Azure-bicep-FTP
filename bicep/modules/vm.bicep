param vmName string
param location string
param tags object

param adminUsername string

@secure()
param adminPassword string

param vmSize string
param subnetId string
param availabilitySetId string
param privateIpAddress string
param lbBackendPoolId string
param sharedDiskId string
param sharedDiskLun int

var nicName = '${vmName}-nic'
var osDiskName = '${vmName}-osdisk'

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    enableAcceleratedNetworking: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: privateIpAddress
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: subnetId
          }
          loadBalancerBackendAddressPools: [
            {
              id: lbBackendPoolId
            }
          ]
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    availabilitySet: {
      id: availabilitySetId
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-g2'
        version: 'latest'
      }
      osDisk: {
        name: osDiskName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: 128
        deleteOption: 'Delete'
      }
      dataDisks: [
        {
          lun: sharedDiskLun
          createOption: 'Attach'
          managedDisk: {
            id: sharedDiskId
          }
          deleteOption: 'Detach'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

output vmName string = vm.name
output vmId string = vm.id
output nicId string = nic.id
output privateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
