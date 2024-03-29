function Update-VeeamNutanixAhvJobs {
        <#
        .SYNOPSIS
        Job Update for Veeam for Nutanix AHV based on Prsim Central categories

        .DESCRIPTION
        Checks all VMs in Nutanix Prism Central for backup categories und updates Veeam Backup jobs based on the categorie applied on the VMs

        .PARAMETER PrismCentralIp
        IP or hostname of Nutanix Prism Central

        .PARAMETER PrismCentralUsername
        Username to access Prism Central

        .PARAMETER PrismCentralPassword
        Password to access Prism Central

        .PARAMETER PrismCentralCred
        Secret name for credentials to access Prism Central

        .PARAMETER ProxyMappingFilePath
        Path to file with Nutanix Cluster to Veeam AHV Proxy mapping list (as CSV)

        .PARAMETER VeeamAhvProxyUsername
        Username to access Veeam Proxies

        .PARAMETER VeeamAhvProxyPassword
        Password to access Veeam Proxies

        .PARAMETER VeeamAhvProxyCred
        Secret name for credentials to access Veeam Proxies

        .PARAMETER SecretStoreName
        Name of PowerShell SecretStore which holds the credentials for Prism Central, Veeam AHV Proxies and SMTP server

        .PARAMETER SecretStoreXmlPath
        Path to the password file to access Secret Store

        .PARAMETER ProtectionPolicyCategoryName
        Name of the Category used for Veeam backup job assignment

        .PARAMETER SecretStoreXmlPath
        Path to the password file to access Secret Store

        .PARAMETER MailNotification
        Enable mail notification about unprotected VMs

        .PARAMETER MailAuth
        Enable authentication to SMTP server

        .PARAMETER MailStylePath
        Path to HTML file with style sheet information for mail notification

        .PARAMETER excludedVmsPrefix
        Prefix for VM Names to exclude from check and assignment

        .PARAMETER JobNamePrefix
        Prefix for the Veeam backup job name. The job name always starts with the cluster name
    
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
            HelpMessage = 'Enter name for credentials to authenticate to Veeam Proxy for Nutanix AHV'
        )]
        [String]$VeeamAhvProxyCred = 'VeeamAhvProxy',
            
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter Microsoft Secret Store Name'
        )]
        [String]$SecretStoreName,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter path for the secret store XML'
        )]
        [String]$SecretStoreXmlPath = '.\password.xml',

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Enter name for Prism Central Protection Policy category'
        )]
        [String]$ProtectionPolicyCategoryName,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter path to mail config json'
        )]
        [String]$MailConfigPath = '.\mailconf.json',

        [Parameter(
            Mandatory = $false
        )]
        [Switch]$MailNotification = $false,

        [Parameter(
            Mandatory = $false
        )]
        [Switch]$MailAuth = $false,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter name for credentials to authenticate to SMTP server'
        )]
        [String]$MailAuthCred = 'SmtpServer',
        

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter path to mail stalye HTML'
        )]
        [String]$MailStylePath = '.\mailstyle.html',

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter a prefix for VMs excluded from the check'
        )]
        [String]$excludedVmsPrefix,
        
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Ignore the protection status for a VM received from Veeam proxy'
        )]
        [Switch]$ignoreProtectionStatus = $false,

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
    . .\Get-VmJobMembership.ps1

    #endregion

    #region globalsettings
    $ErrorActionPreference='Stop'
    #endregion

    #region modules
    Write-Verbose "Import modules"
    Import-Module -Name 'Microsoft.PowerShell.SecretManagement' -Force -Verbose:$false
    Import-Module -Name 'Microsoft.PowerShell.SecretStore' -Force -Verbose:$false
    #endregion

    #region main

    # Import Nutanix cluster to Veeam AHV proxy mapping list | could be replaced by identifying the Nutanix clusters via the Veeam Proxy REST API
    $ProxyMappingList = Import-Csv -Path $ProxyMappingFilePath -Delimiter ';'

    # Get credentials from vault
    if ($SecretStoreName) {
        $SecretStorePassword = Import-CliXml -Path $SecretStoreXmlPath
        Unlock-SecretStore -Password $SecretStorePassword
        if ($PrismCentralCred) {
            $CredPrismCentral  = Get-Secret -Vault $SecretStoreName -Name $PrismCentralCred
        }
        if ($VeeamAhvProxyCred) {
            $CredVeeamAhvProxy = Get-Secret -Vault $SecretStoreName -Name $VeeamAhvProxyCred
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

    # Exclude VMs starts with string or match regex pattern
    if ($excludedVmsPrefix -or $excludedVmsRegex) {
        # Change prefix to regex pattern
        if ($excludedVmsPrefix) {
            $excludedVmsRegex = '(?i)^' + $excludedVmsPrefix
        }
        $excludedVms = ($NutanixVmInfo | Where-Object {$_.Name -match $excludedVmsRegex}).Name
        foreach ($Vm in $excludedVms) {
            Write-Verbose "Excluded VM: $VM"
        }
        # Filter hash table
        $NutanixVmInfo = $NutanixVmInfo | Where-Object {$_.Name -notmatch $excludedVmsRegex}
    }

    # Get VMs without data protection category applied
    $VmsMissingCategory = $NutanixVmInfo | Where-Object {$null -eq $_.DataProtectionCategory}
    $VmsMissingCategory | Select-Object ClusterName,Name | Sort-Object ClusterName,Name | Format-Table -AutoSize

    # Send mail notification with VMs without data protection category applied
    if ($MailNotification -and $VmsMissingCategory.count -gt 0) {
        # Get mail config from file
        $MailConfig = @(Get-Content -Path $MailConfigPath | ConvertFrom-Json)
        [String]$MailStyle = Get-Content -Path $MailStylePath
        [String]$MailBody = $VmsMissingCategory | Select-Object ClusterName,Name | Sort-Object ClusterName,Name | ConvertTo-Html -PreContent $MailStyle
        
        # Define mail parameters
        $MailParams = @{
            SmtpServer = $MailConfig.SmtpServer
            Port = $MailConfig.Port
            To = $MailConfig.To
            From = $MailConfig.From
            Body = $MailBody
            Subject = "Found VMs without backup tag"
            BodyAsHTML = $true
            ErrorAction = "Stop"
            UseSsl = $MailConfig.UseSSL
        }

        # Check if mail authentication is needed
        if ($MailAuth) {
            if ($SecretStoreName -and $MailAuthCred) {
                $CredMailAuth = Get-Secret -Vault $SecretStoreCred -Name $MailAuthCred
            }
            elseif ($MailConfig.Username -and $MailConfig.Password) {
                $secMailAuthPassword = $MailConfig.Password | ConvertTo-SecureString
                $CredMailAuth = New-Object System.Management.Automation.PSCredential($MailConfig.Username, $secMailAuthPassword)
            }
    
            if ($CredMailAuth) {
                Write-Verbose 'Credentials from Secret Store or config file received'
            }
            else {
                Throw 'No credentials from Secret Store or config file received'
            }
    
            # Send mail with authentication
            Send-MailMessage @MailParams -Credential $CredMailAuth -Verbose
        }
        else {
            # Send mail without authentication
            Send-MailMessage @MailParams
        }
    }

    # Filter VMs with data protection category applied
    $VmsToProcess = $NutanixVmInfo | Where-Object {$null -ne $_.DataProtectionCategory}

    # Add Veeam Proxy IP to $NutanixVmInfo array
    $VmsToProcess | ForEach-Object {
        foreach ($item in $ProxyMappingList) {
            if ($item.ClusterName -eq $_.ClusterName) { $_.VeeamAhvProxyIp = $item.VeeamAhvProxyIp }
        }
    }

    # Get Veeam access token
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
        if ($_.VeeamAhvProxyIp) {
            if ($ApiKey) {
                $VmName = $_.Name
                Write-Verbose "--- Processing VM $VmName ---"
                if ($ignoreProtectionStatus -eq $false) {
                    # Get protection status from Veeam proxy
                    $_.ProtectionStatus = Get-VeeamNutanixAhvProtectionStatus -ProxyIp $_.VeeamAhvProxyIp -ApiKey $ApiKey -VmName $VmName -VmId $_.VmUuid
                }
                else {
                    # Set protection status to false, if protection status should be ignored
                    $_.ProtectionStatus = $false
                }
                # Check if VM is already a member of any backup job
                $VmJobId = Get-VmJobMembership -ProxyIp $_.VeeamAhvProxyIp -ApiKey $ApiKey -VmName $VmName -VmId $_.VmUuid

                if (($_.ProtectionStatus -eq $false) -and ($null -eq $VmJobId)) {
                    $JobName = $_.ClusterName + '-' + $JobNamePrefix + $_.DataProtectionCategory
                    Write-Verbose "Add VM $VmName to $JobName"
                    $_.ActionStatus = "added to job $JobName"
                    Add-VmToVeeamNutanixAhvJob -ProxyIp $_.VeeamAhvProxyIp -ApiKey $ApiKey -JobName $JobName -ClusterId $_.ClusterUuid -VmId $_.VmUuid -Verbose
                }
            }
            else {
                throw 'API key to access the Veeam proxy is empty.'
            }
        }
        else {
            throw 'No Veeam Proxy found in proxy mapping list for VM'
        }
    }

    # 
    $ChangedVms = $VmsToProcess | Where-Object {$null -ne $_.ActionStatus} | Select-Object Name,ClusterName,ActionStatus
    $ChangedVms | Sort-Object ClusterName,Name | Format-Table -AutoSize
    Write-Host $ChangedVms.count "changes"

    if ($ChangedVms.count -gt 0) {
        if ($MailNotification) {
            if ($MailAuth) {
                [String]$MailBody = $ChangedVms | Select-Object ClusterName,Name | Sort-Object ClusterName,Name | ConvertTo-Html -PreContent $MailStyle     
                $MailParams.Subject = "Veeam job assigment modified"
                Send-MailMessage @MailParams -Credential $CredMailAuth -Verbose
            }
            else {
                Send-MailMessage @MailParams
            }
        }
    }

    #endregion
}
