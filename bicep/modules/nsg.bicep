param name string
param location string
param tags object

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow-sftp-inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          description: 'Allow SFTP'
        }
      }
      {
        name: 'allow-ftp-inbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '21'
          description: 'Allow FTP control channel'
        }
      }
      {
        name: 'allow-ftps-inbound'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '990'
          description: 'Allow implicit FTPS'
        }
      }
      {
        name: 'allow-https-admin-inbound'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          description: 'Allow HTTPS for EFT admin and explicit FTPS'
        }
      }
      {
        name: 'allow-ftp-passive-inbound'
        properties: {
          priority: 140
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '50000-51000'
          description: 'Allow FTP passive data ports - configure matching range in EFT'
        }
      }
      {
        name: 'allow-rdp-vnet-only'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
          description: 'Allow RDP from VNet only - use Bastion or VPN for remote management'
        }
      }
      {
        name: 'allow-wsfc-cluster-internal'
        properties: {
          priority: 300
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
          description: 'Allow WSFC heartbeat and cluster communication between nodes'
        }
      }
      {
        name: 'allow-azure-lb-probes'
        properties: {
          priority: 400
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Allow Azure Load Balancer health probe traffic'
        }
      }
    ]
  }
}

output id string = nsg.id
output name string = nsg.name
