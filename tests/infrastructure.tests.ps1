param(
    [Parameter(Mandatory)] [string] $ResourceGroupName,
    [Parameter(Mandatory)] [string] $SubscriptionId
)

BeforeAll {
    Connect-AzAccount -Identity -ErrorAction SilentlyContinue
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    $script:rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
}

# ─── Resource Group ───────────────────────────────────────────────────────────
Describe 'Resource Group' {
    It 'should exist' {
        $script:rg | Should -Not -BeNullOrEmpty
    }

    It 'should have required tags' {
        $script:rg.Tags['project']   | Should -Be 'globalscape-eft'
        $script:rg.Tags['managedBy'] | Should -Be 'bicep'
    }
}

# ─── Networking ───────────────────────────────────────────────────────────────
Describe 'Virtual Network' {
    BeforeAll {
        $script:vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName |
                       Where-Object { $_.Name -like 'vnet-eft-*' }
        $script:nsg  = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName |
                       Where-Object { $_.Name -like 'nsg-eft-*' }
    }

    It 'VNet should exist' {
        $script:vnet | Should -Not -BeNullOrEmpty
    }

    It 'EFT subnet should exist' {
        $script:vnet.Subnets | Where-Object { $_.Name -eq 'snet-eft' } | Should -Not -BeNullOrEmpty
    }

    It 'EFT subnet should be associated with the NSG' {
        $subnet = $script:vnet.Subnets | Where-Object { $_.Name -eq 'snet-eft' }
        $subnet.NetworkSecurityGroup | Should -Not -BeNullOrEmpty
    }
}

Describe 'Network Security Group' {
    BeforeAll {
        $script:nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName |
                      Where-Object { $_.Name -like 'nsg-eft-*' }
    }

    It 'NSG should exist' {
        $script:nsg | Should -Not -BeNullOrEmpty
    }

    It 'should allow SFTP (port 22)' {
        $rule = $script:nsg.SecurityRules | Where-Object { $_.Name -eq 'allow-sftp-inbound' }
        $rule | Should -Not -BeNullOrEmpty
        $rule.Access | Should -Be 'Allow'
        $rule.DestinationPortRange | Should -Be '22'
    }

    It 'should allow FTP (port 21)' {
        $rule = $script:nsg.SecurityRules | Where-Object { $_.Name -eq 'allow-ftp-inbound' }
        $rule | Should -Not -BeNullOrEmpty
        $rule.Access | Should -Be 'Allow'
        $rule.DestinationPortRange | Should -Be '21'
    }

    It 'should allow HTTPS (port 443)' {
        $rule = $script:nsg.SecurityRules | Where-Object { $_.Name -eq 'allow-https-admin-inbound' }
        $rule | Should -Not -BeNullOrEmpty
        $rule.Access | Should -Be 'Allow'
        $rule.DestinationPortRange | Should -Be '443'
    }

    It 'should restrict RDP to VNet only' {
        $rule = $script:nsg.SecurityRules | Where-Object { $_.Name -eq 'allow-rdp-vnet-only' }
        $rule | Should -Not -BeNullOrEmpty
        $rule.SourceAddressPrefix | Should -Be 'VirtualNetwork'
    }

    It 'should allow Azure LB health probes' {
        $rule = $script:nsg.SecurityRules | Where-Object { $_.Name -eq 'allow-azure-lb-probes' }
        $rule | Should -Not -BeNullOrEmpty
        $rule.SourceAddressPrefix | Should -Be 'AzureLoadBalancer'
    }
}

# ─── Availability Set ─────────────────────────────────────────────────────────
Describe 'Availability Set' {
    BeforeAll {
        $script:avset = Get-AzAvailabilitySet -ResourceGroupName $ResourceGroupName |
                        Where-Object { $_.Name -like 'avset-eft-*' }
    }

    It 'should exist' {
        $script:avset | Should -Not -BeNullOrEmpty
    }

    It 'should have 2 fault domains' {
        $script:avset.PlatformFaultDomainCount | Should -Be 2
    }

    It 'should have 5 update domains' {
        $script:avset.PlatformUpdateDomainCount | Should -Be 5
    }
}

# ─── Virtual Machines ─────────────────────────────────────────────────────────
Describe 'Virtual Machines' {
    BeforeAll {
        $script:vm01 = Get-AzVM -ResourceGroupName $ResourceGroupName -Name 'EFT-VM-01' -ErrorAction SilentlyContinue
        $script:vm02 = Get-AzVM -ResourceGroupName $ResourceGroupName -Name 'EFT-VM-02' -ErrorAction SilentlyContinue
        $script:nic01 = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName |
                        Where-Object { $_.VirtualMachine.Id -eq $script:vm01.Id }
        $script:nic02 = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName |
                        Where-Object { $_.VirtualMachine.Id -eq $script:vm02.Id }
    }

    It 'EFT-VM-01 should exist' {
        $script:vm01 | Should -Not -BeNullOrEmpty
    }

    It 'EFT-VM-02 should exist' {
        $script:vm02 | Should -Not -BeNullOrEmpty
    }

    It 'EFT-VM-01 should run Windows Server 2022' {
        $script:vm01.StorageProfile.ImageReference.Offer | Should -Be 'WindowsServer'
        $script:vm01.StorageProfile.ImageReference.Sku   | Should -Be '2022-datacenter-g2'
    }

    It 'EFT-VM-02 should run Windows Server 2022' {
        $script:vm02.StorageProfile.ImageReference.Offer | Should -Be 'WindowsServer'
        $script:vm02.StorageProfile.ImageReference.Sku   | Should -Be '2022-datacenter-g2'
    }

    It 'EFT-VM-01 should be in the availability set' {
        $script:vm01.AvailabilitySetReference | Should -Not -BeNullOrEmpty
    }

    It 'EFT-VM-02 should be in the availability set' {
        $script:vm02.AvailabilitySetReference | Should -Not -BeNullOrEmpty
    }

    It 'EFT-VM-01 NIC should have static private IP 10.x.1.10' {
        $script:nic01.IpConfigurations[0].PrivateIpAllocationMethod | Should -Be 'Static'
        $script:nic01.IpConfigurations[0].PrivateIpAddress | Should -Match '^10\.\d+\.1\.10$'
    }

    It 'EFT-VM-02 NIC should have static private IP 10.x.1.11' {
        $script:nic02.IpConfigurations[0].PrivateIpAllocationMethod | Should -Be 'Static'
        $script:nic02.IpConfigurations[0].PrivateIpAddress | Should -Match '^10\.\d+\.1\.11$'
    }

    It 'both VMs should have the shared disk attached at LUN 0' {
        $disk01 = $script:vm01.StorageProfile.DataDisks | Where-Object { $_.Lun -eq 0 }
        $disk02 = $script:vm02.StorageProfile.DataDisks | Where-Object { $_.Lun -eq 0 }
        $disk01 | Should -Not -BeNullOrEmpty
        $disk02 | Should -Not -BeNullOrEmpty
        $disk01.ManagedDisk.Id | Should -Be $disk02.ManagedDisk.Id
    }

    It 'both VM NICs should be registered in the LB backend pool' {
        $script:nic01.IpConfigurations[0].LoadBalancerBackendAddressPools | Should -Not -BeNullOrEmpty
        $script:nic02.IpConfigurations[0].LoadBalancerBackendAddressPools | Should -Not -BeNullOrEmpty
    }
}

# ─── Shared Disk ──────────────────────────────────────────────────────────────
Describe 'Shared Disk' {
    BeforeAll {
        $script:disk = Get-AzDisk -ResourceGroupName $ResourceGroupName |
                       Where-Object { $_.Name -like 'disk-eft-*-shared' }
    }

    It 'should exist' {
        $script:disk | Should -Not -BeNullOrEmpty
    }

    It 'should be Premium SSD' {
        $script:disk.Sku.Name | Should -Be 'Premium_LRS'
    }

    It 'should allow 2 simultaneous shares (maxShares = 2)' {
        $script:disk.MaxShares | Should -Be 2
    }

    It 'should be at least 256 GB' {
        $script:disk.DiskSizeGB | Should -BeGreaterOrEqual 256
    }

    It 'should be attached to both VMs' {
        $script:disk.ManagedByExtended.Count | Should -Be 2
    }
}

# ─── Load Balancer ────────────────────────────────────────────────────────────
Describe 'Internal Load Balancer' {
    BeforeAll {
        $script:lb = Get-AzLoadBalancer -ResourceGroupName $ResourceGroupName |
                     Where-Object { $_.Name -like 'lb-eft-*' }
    }

    It 'should exist' {
        $script:lb | Should -Not -BeNullOrEmpty
    }

    It 'should be Standard SKU' {
        $script:lb.Sku.Name | Should -Be 'Standard'
    }

    It 'frontend IP should be static at 10.x.1.100' {
        $fe = $script:lb.FrontendIpConfigurations[0]
        $fe.PrivateIpAllocationMethod | Should -Be 'Static'
        $fe.PrivateIpAddress | Should -Match '^10\.\d+\.1\.100$'
    }

    It 'backend pool should exist' {
        $script:lb.BackendAddressPools | Should -Not -BeNullOrEmpty
    }

    It 'health probe should target port 22 (SFTP)' {
        $probe = $script:lb.Probes | Where-Object { $_.Port -eq 22 }
        $probe | Should -Not -BeNullOrEmpty
        $probe.Protocol | Should -Be 'Tcp'
    }

    It 'all LB rules should have floating IP enabled (required for WSFC)' {
        $script:lb.LoadBalancingRules | ForEach-Object {
            $_.EnableFloatingIP | Should -Be $true -Because "floating IP is required for Windows Failover Cluster"
        }
    }

    It 'should have rules for FTP (21), SFTP (22), FTPS (990), HTTPS (443)' {
        $ports = $script:lb.LoadBalancingRules | Select-Object -ExpandProperty FrontendPort
        $ports | Should -Contain 21
        $ports | Should -Contain 22
        $ports | Should -Contain 990
        $ports | Should -Contain 443
    }
}

# ─── Storage Account (Quorum Witness) ─────────────────────────────────────────
Describe 'Storage Account - Quorum Witness' {
    BeforeAll {
        $script:storage = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName |
                          Where-Object { $_.StorageAccountName -like 'steft*' }
    }

    It 'should exist' {
        $script:storage | Should -Not -BeNullOrEmpty
    }

    It 'should enforce HTTPS only' {
        $script:storage.EnableHttpsTrafficOnly | Should -Be $true
    }

    It 'should enforce minimum TLS 1.2' {
        $script:storage.MinimumTlsVersion | Should -Be 'TLS1_2'
    }

    It 'should not allow public blob access' {
        $script:storage.AllowBlobPublicAccess | Should -Be $false
    }
}
