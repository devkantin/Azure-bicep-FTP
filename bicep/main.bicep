targetScope = 'resourceGroup'

@description('Deployment environment')
@allowed(['dev', 'staging', 'prod'])
param environment string

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('VM administrator username')
param adminUsername string

@description('VM administrator password')
@secure()
param adminPassword string

@description('Size of each EFT VM')
param vmSize string = 'Standard_D4s_v3'

@description('Address space for the virtual network')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Address prefix for the EFT subnet')
param subnetPrefix string = '10.0.1.0/24'

@description('Private IP for the load balancer frontend (cluster VIP)')
param lbFrontendIp string = '10.0.1.100'

@description('Private IP for EFT VM 01 - Active node')
param vm01Ip string = '10.0.1.10'

@description('Private IP for EFT VM 02 - Passive node')
param vm02Ip string = '10.0.1.11'

var prefix = 'eft-${environment}'
var tags = {
  environment: environment
  project: 'globalscape-eft'
  managedBy: 'bicep'
}

module nsg 'modules/nsg.bicep' = {
  name: 'nsg-${uniqueString(deployment().name)}'
  params: {
    name: 'nsg-${prefix}'
    location: location
    tags: tags
  }
}

module network 'modules/network.bicep' = {
  name: 'network-${uniqueString(deployment().name)}'
  params: {
    vnetName: 'vnet-${prefix}'
    location: location
    tags: tags
    nsgId: nsg.outputs.id
    vnetAddressPrefix: vnetAddressPrefix
    subnetPrefix: subnetPrefix
  }
}

module availabilitySet 'modules/availabilityset.bicep' = {
  name: 'avset-${uniqueString(deployment().name)}'
  params: {
    name: 'avset-${prefix}'
    location: location
    tags: tags
  }
}

module sharedDisk 'modules/shareddisk.bicep' = {
  name: 'disk-${uniqueString(deployment().name)}'
  params: {
    name: 'disk-${prefix}-shared'
    location: location
    tags: tags
  }
}

module loadBalancer 'modules/loadbalancer.bicep' = {
  name: 'lb-${uniqueString(deployment().name)}'
  params: {
    name: 'lb-${prefix}'
    location: location
    tags: tags
    subnetId: network.outputs.subnetId
    frontendPrivateIp: lbFrontendIp
  }
}

module storageAccount 'modules/storageaccount.bicep' = {
  name: 'storage-${uniqueString(deployment().name)}'
  params: {
    name: take('st${replace(prefix, '-', '')}${uniqueString(resourceGroup().id)}', 24)
    location: location
    tags: tags
  }
}

module vm01 'modules/vm.bicep' = {
  name: 'vm01-${uniqueString(deployment().name)}'
  params: {
    vmName: 'EFT-VM-01'
    location: location
    tags: tags
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
    subnetId: network.outputs.subnetId
    availabilitySetId: availabilitySet.outputs.id
    privateIpAddress: vm01Ip
    lbBackendPoolId: loadBalancer.outputs.backendPoolId
    sharedDiskId: sharedDisk.outputs.id
    sharedDiskLun: 0
  }
}

// dependsOn vm01 so both nodes don't race to attach the shared disk simultaneously
module vm02 'modules/vm.bicep' = {
  name: 'vm02-${uniqueString(deployment().name)}'
  dependsOn: [vm01]
  params: {
    vmName: 'EFT-VM-02'
    location: location
    tags: tags
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
    subnetId: network.outputs.subnetId
    availabilitySetId: availabilitySet.outputs.id
    privateIpAddress: vm02Ip
    lbBackendPoolId: loadBalancer.outputs.backendPoolId
    sharedDiskId: sharedDisk.outputs.id
    sharedDiskLun: 0
  }
}

output resourceGroupName string = resourceGroup().name
output vnetId string = network.outputs.vnetId
output lbPrivateIp string = loadBalancer.outputs.frontendIp
output vm01Name string = vm01.outputs.vmName
output vm02Name string = vm02.outputs.vmName
output storageAccountName string = storageAccount.outputs.name
