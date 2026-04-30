param name string
param location string
param tags object
param subnetId string
param frontendPrivateIp string

resource lb 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'fe-eft'
        properties: {
          privateIPAddress: frontendPrivateIp
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'be-eft'
      }
    ]
    probes: [
      {
        name: 'probe-eft-sftp'
        properties: {
          protocol: 'Tcp'
          port: 22
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'rule-eft-sftp'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', name, 'fe-eft')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', name, 'be-eft')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', name, 'probe-eft-sftp')
          }
          protocol: 'Tcp'
          frontendPort: 22
          backendPort: 22
          enableFloatingIP: true
          idleTimeoutInMinutes: 4
          loadDistribution: 'Default'
        }
      }
      {
        name: 'rule-eft-ftp'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', name, 'fe-eft')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', name, 'be-eft')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', name, 'probe-eft-sftp')
          }
          protocol: 'Tcp'
          frontendPort: 21
          backendPort: 21
          enableFloatingIP: true
          idleTimeoutInMinutes: 4
          loadDistribution: 'Default'
        }
      }
      {
        name: 'rule-eft-ftps'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', name, 'fe-eft')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', name, 'be-eft')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', name, 'probe-eft-sftp')
          }
          protocol: 'Tcp'
          frontendPort: 990
          backendPort: 990
          enableFloatingIP: true
          idleTimeoutInMinutes: 4
          loadDistribution: 'Default'
        }
      }
      {
        name: 'rule-eft-https'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', name, 'fe-eft')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', name, 'be-eft')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', name, 'probe-eft-sftp')
          }
          protocol: 'Tcp'
          frontendPort: 443
          backendPort: 443
          enableFloatingIP: true
          idleTimeoutInMinutes: 4
          loadDistribution: 'Default'
        }
      }
    ]
  }
}

output id string = lb.id
output name string = lb.name
output backendPoolId string = lb.properties.backendAddressPools[0].id
output frontendIp string = lb.properties.frontendIPConfigurations[0].properties.privateIPAddress
