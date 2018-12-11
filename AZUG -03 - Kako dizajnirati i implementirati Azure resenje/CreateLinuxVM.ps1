# Login to Azure account
Login-AzureRmAccount

# Assign variables
$location = (Get-AzureRmLocation).Location | Out-GridView -OutputMode Single
$projectName = Read-Host "Enter project name"
$rgName		= "$projectName-RG"
$vmName 	= Read-Host "Enter virtual machine name"
$pubName	= 'Canonical'
$offerName	= 'UbuntuServer'
$skuName	= '18.04-LTS'
$vmSize 	= 'Standard_D1_v2'
$vnetName 	= "$projectName-vNet"
$addressprefix = '10.200.0.0/16' 
$subnetName = Read-Host "Enter subnet name"
$subnetprefix = '10.200.1.0/24'
$nsgName    = "$vmName-nsg"
$pipName    = "$vmName-pip" 
$nicName    = "$vmName-nic"
$osDiskName = "$vmName-osdisk"
$osDiskSize = '30'
$osDiskType = 'Premium_LRS'
$storageaccountname = 'azuglinuxdiag'

# Create resource group
New-AzureRmResourceGroup -Name $rgName -Location $location

# Create virtual network
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $rgName `
            -Name $vnetName `
            -AddressPrefix $addressprefix `
            -Location $location
Add-AzureRmVirtualNetworkSubnetConfig -Name $subnetName `
            -VirtualNetwork $vnet `
            -AddressPrefix $subnetprefix
Set-AzureRmVirtualNetwork -VirtualNetwork $vnet


# Identify virtual network and subnet
$vnet = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $rgName
$subnetid = (Get-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet).Id

# Identify the diagnostics storage account
$storageAccount	= New-AzureRmStorageAccount -Name $storageaccountname `
                    -ResourceGroupName $rgName `
                    -Location $location `
                    -SkuName Standard_LRS

# Create admin credentials
$adminUsername = 'username'
$adminPassword = 'Pa55w.rd1234'
$adminCreds = New-Object PSCredential $adminUsername, ($adminPassword | ConvertTo-SecureString -AsPlainText -Force) 

# Create an NSG
$nsgRuleSSH = New-AzureRmNetworkSecurityRuleConfig -Name 'allow-ssh' `
                -Protocol Tcp `
                -Direction Inbound `
                -Priority 100 `
                -SourceAddressPrefix * `
                -SourcePortRange * `
                -DestinationAddressPrefix * `
                -DestinationPortRange 22 `
                -Access Allow
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $rgName `
        -Location $location `
        -Name $nsgName `
        -SecurityRules $nsgRuleSSH

# Create a public IP and NIC
$pip = New-AzureRmPublicIpAddress -Name $pipName `
            -ResourceGroupName $rgName `
            -Location $location `
            -AllocationMethod Static 
$nic = New-AzureRmNetworkInterface -Name $nicName `
            -ResourceGroupName $rgName `
            -Location $location `
            -SubnetId $subnetid `
            -PublicIpAddressId $pip.Id `
            -NetworkSecurityGroupId $nsg.Id

# Set VM Configuration
$vmConfig	= New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize
Add-AzureRmVMNetworkInterface -VM $vmConfig -Id $nic.Id
Set-AzureRmVMBootDiagnostics -Enable -ResourceGroupName $rgName `
    -VM $vmConfig `
    -StorageAccountName $storageAccountname
Set-AzureRmVMOperatingSystem -VM $vmConfig `
    -Linux `
    -ComputerName $vmName `
    -Credential $adminCreds 
Set-AzureRmVMSourceImage -VM $vmConfig `
    -PublisherName $pubName `
    -Offer $offerName `
    -Skus $skuName `
    -Version 'latest'
Set-AzureRmVMOSDisk -VM $vmConfig `
    -Name $osDiskName `
    -DiskSizeInGB $osDiskSize `
    -StorageAccountType $osDiskType `
    -CreateOption fromImage

#Create the VM
New-AzureRmVM -ResourceGroupName $rgName -Location $location -VM $vmConfig
