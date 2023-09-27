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
     Author: Andy Kruesi
     Date created: 2023/08/31

    .EXAMPLE 
    .\Script.ps1 -PrismCentralIp '10.0.200.100' -PrismCentralApiKey 'sfdih34sdauighs4rag5he==' -VeeamProxyApiKey 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiJkOTgyMTc1NS0wODM2LTQ1ZjctYmU3ZS03YTA4MzA0ODQ4ZTQiLCJuYW1laWQiOiIxMDAwIiwidW5pcXVlX25hbWUiOiJhZG1pbiIsInNpZCI6IjM4YWNhZGIyLWM5ZTUtNDMyNC1hYjUxLTAzYzA0YWFjZjUwOCIsIm5iZiI6MTY5MzQ5NTE3MCwiZXhwIjoxNjkzNDk2OTcwLCJpYXQiOjE2OTM0OTUxNzAsImlzcyI6Imlzc3VlciIsImF1ZCI6ImFwaS9kZWZhdWx0LzYzZTgwODEyLTE2ZDYtNDFmMi05NGZhLTVlNTU0NmIzMmJkMSJ9.McGboYzUyDRa8T67LEQHiR6QBa1GU4xOLKGt_gBd0YQ'
#>

#region param
[CmdlletBinding()]
param(
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Enter Nutanix Prism Central IP or hostname'
    )]
    [String]$PrismCentralIp = '',

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Enter the path to the file with cluster to proxy mapping'
    )]
    [String]$ProxyMappingFilePath = '.\ProxyMapping.csv',
    
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Enter API key created in Veeam Proxy for Nutanix AHV'
    )]
    [String]$VeeamAhvProxyApiKey = ''
)
#endregion

#region functions

function Get-NutanixClusters {}

function Get-VmCategories {}

function Get-VeeamNutanixAhvJobs {}

#endregion


#region main

# Import Nutanix cluster to Veeam AHV proxy mapping list | could be replaced by identifying the Nutanix clusters via the Veeam Proxy REST API
$ProxyMappingList = Import-Csv -Path '.\ProxyMapping.csv' -Delimiter ';'

# Get credentials from vault
$CredPrismCentral  = Get-Secret -Vault GRBR-NX-V -Name PrismCentral
$CredVeeamAhvProxy = Get-Secret -Vault GRBR-NX-V -Name VeeamAhvProxy

# Import functions
. .\Get-NutanixVmInfo.ps1
. .\Get-VeeamAhvProxyToken.ps1
. .\Get-VeeamNutanixAhvProtectionStatus
. .\Add-VmToVeeamNutanixAhvJob.ps1

# Retrieve all VMs with additional infos from Prism Central
$NutanixVmInfo = Get-NutanixVmInfo -Ip $PrismCentralIp -Username $CredPrismCentral.UserName -Password $CredPrismCentral.Password -ProtectionPolicyCategoryName 'PD-GRBR'

# Show VMs without Data Protection Category applied
$NutanixVmInfo | Where-Object {$_.DataProtectionCategory -eq $null} | Format-Table -AutoSize

# Filter VMs with data protection category applied
$VmsToProcess = $NutanixVmInfo | Where-Object {$_.DataProtectionCategory -ne $null}

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

# Check if VM is protected or unprotected
$VmsToProcess | ForEach-Object {
    foreach ($item in $ProxyMappingList) {
        if ($item.VeeamAhvProxyIp -eq $_.VeeamAhvProxyIp) { 
            $ApiKey = $item.VeeamAhvProxyApiKey
        }
    }
    if ($ApiKey) {
        $_.ProtectionStatus = Get-VeeamNutanixAhvVmInfo -ProxyIp $_.VeeamAhvProxyIp -ApiKey $ApiKey -ClusterId $_.ClusterUuid -VmId $_.VmUuid
    }
    else {
        throw 'The API key to access the Veeam proxy is empty.'
    }
}

# Add VMs to Veeam Backup Job
$VmsToProcess | Where-Object {$_.ProtectionStatus -eq $false} | ForEach-Object {
        Add-VmToVeeamNutanixAhvJob -ProxylIp $_.VeeamAhvProxyIp -ApiKey $ApiKey -JobName -ClusterId $_.ClusterUuid -VmId $_.VmUuid
}
#endregion