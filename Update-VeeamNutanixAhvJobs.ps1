function Update-VeeamNutanixAhvJobs {
        <#
        .SYNOPSIS
        Job Update for Veeam for Nutanix AHV based on Prsim Central categories

        .DESCRIPTION
        Checks all VMs in Nutanix Prism Central for backup categories und updates Veeam Backup jobs based on the categorie applied on the VMs

        .PARAMETER PrismCentralIp
        IP or hostname of Nutanix Prism Central

        .PARAMETER PrismCentralApiKey
        API key to access Prism Central

        .PARAMETER VeeamAhvProxylIp
        IP or hostname of Nutanix Prism Central
        
        .PARAMETER VeeamAhvProxyApiKey
        API key to access Veeam Proxy for Nutanix AHV
    
        .NOTES

        .EXAMPLE 
    #>

    #region param
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Enter Nutanix Prism Central IP or hostname'
        )]
        [String]$PrismCentralIp,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter username to authenticate to Prism Central'
        )]
        [String]$PrismCentralUsername = 'admin',

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter password to authenticate to Prism Central'
        )]
        [SecureString]$PrismCentralPassword,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter name for credentials to authenticate to Prism Central'
        )]
        [String]$PrismCentralCred = 'PrismCentral',

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Enter the path to the file with cluster to proxy mapping'
        )]
        [String]$ProxyMappingFilePath = '.\ProxyMapping.csv',
        
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter API key created in Veeam Proxy for Nutanix AHV'
        )]
        [String]$VeeamAhvProxyApiKey,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter username to authenticate to Veeam Proxy for Nutanix AHV'
        )]
        [String]$VeeamAhvProxyUsername = 'admin',

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter password to authenticate to Veeam Proxy for Nutanix AHV'
        )]
        [SecureString]$VeeamAhvProxyPassword,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter Microsoft Secret Store Name'
        )]
        [String]$SecretStoreCred,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter name for credentials to authenticate to Veeam Proxy for Nutanix AHV'
        )]
        [String]$VeeamAhvProxyCred = 'VeeamAhvProxy',

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Enter name for Prism Central Protection Policy category'
        )]
        [String]$ProtectionPolicyCategoryName,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter a prefix to attend to the job name in Veeam Proxy for Nutanix AHV'
        )]
        [String]$JobNamePrefix
    )
    #endregion

    #region functions

    # Import functions
    . .\Get-NutanixVmInfo.ps1
    . .\Get-VeeamAhvProxyToken.ps1
    . .\Get-VeeamNutanixAhvProtectionStatus
    . .\Add-VmToVeeamNutanixAhvJob.ps1
    . .\Update-VeeamNutanixAhv.ps1

    #endregion


    #region main

    # Import Nutanix cluster to Veeam AHV proxy mapping list | could be replaced by identifying the Nutanix clusters via the Veeam Proxy REST API
    $ProxyMappingList = Import-Csv -Path $ProxyMappingFilePath -Delimiter ';'

    # Get credentials from vault
    if ($SecretStoreCred) {
        if ($PrismCentralCred) {
            $CredPrismCentral  = Get-Secret -Vault $SecretStoreCred -Name $PrismCentralCred
        }
        if ($VeeamAhvProxyCred) {
            $CredVeeamAhvProxy = Get-Secret -Vault $SecretStoreCred -Name $VeeamAhvProxyCred
        }
    }

    # Check if credentials could be read from Secret Store
    if ($CredPrismCentral -and $CredVeeamAhvProxy) {
        Write-Verbose 'Credentials from Secret Store received'
    }
    else {
        Throw 'No credentials from Secret Store received'
    }

    # Retrieve all VMs with additional infos from Prism Central
    $NutanixVmInfo = Get-NutanixVmInfo -Ip $PrismCentralIp -Username $CredPrismCentral.UserName -Password $CredPrismCentral.Password -ProtectionPolicyCategoryName $ProtectionPolicyCategoryName

    # Show VMs without Data Protection Category applied
    $NutanixVmInfo | Where-Object {$null -eq $_.DataProtectionCategory} | Format-Table -AutoSize

    # Filter VMs with data protection category applied
    $VmsToProcess = $NutanixVmInfo | Where-Object {$null -ne $_.DataProtectionCategory}

    # Add Veeam Proxy IP to $NutanixVmInfo Array
    $VmsToProcess | ForEach-Object {
        foreach ($item in $ProxyMappingList) {
            if ($item.ClusterName -eq $_.ClusterName) { $_.VeeamAhvProxyIp = $item.VeeamAhvProxyIp }
        }
    }

    # Get Veeam Access Token
    $ProxyMappingList | Add-Member -NotePropertyName 'VeeamAhvProxyApiKey' -NotePropertyValue $null
    $ProxyMappingList | ForEach-Object {
        $_.VeeamAhvProxyApiKey = Get-VeeamAhvProxyToken -ProxyIp $_.VeeamAhvProxyIp -Username $CredVeeamAhvProxy.UserName -Password $CredVeeamAhvProxy.Password
    }

    # Check if VM is protected or unprotected and add VM to Veeam Backup Job
    $VmsToProcess | ForEach-Object {
        foreach ($item in $ProxyMappingList) {
            if ($item.VeeamAhvProxyIp -eq $_.VeeamAhvProxyIp) { 
                $ApiKey = $item.VeeamAhvProxyApiKey
            }
        }
        if ($ApiKey) {
            $_.ProtectionStatus = Get-VeeamNutanixAhvProtectionStatus -ProxyIp $_.VeeamAhvProxyIp -ApiKey $ApiKey -ClusterId $_.ClusterUuid -VmId $_.VmUuid
            if ($_.ProtectionStatus -eq $false) {
                $VmName = $_.Name
                $JobName = $_.ClusterName.ToUpper() + $JobNamePrefix + $_.DataProtectionCategory
                Write-Verbose "Add VM $VmName to $JobName"
                Add-VmToVeeamNutanixAhvJob -ProxyIp $_.VeeamAhvProxyIp -ApiKey $ApiKey -JobName $JobName -ClusterId $_.ClusterUuid -VmId $_.VmUuid -Verbose
                # Update-VeeamNutanixAhv -ProxyIp $_.VeeamAhvProxyIp -ApiKey $ApiKey -ClusterId $_.ClusterUuid
            }
        }
        else {
            throw 'The API key to access the Veeam proxy is empty.'
        }
    }

    # Logout
    

    #endregion
}