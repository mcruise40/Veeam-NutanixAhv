function Get-NutanixVmInfo {
    <#
    .SYNOPSIS
        Retrieve VMs from Prism Central
    .DESCRIPTION
        Retrieve all managed VMs form Prism Central via API.
    .PARAMETER Ip
        Specify the IP of Prism Central.
    .PARAMETER Port
        Specify the Port of Prism Central.
    .PARAMETER Username
        Specify the username to login to Prism Central.
    .PARAMETER Password
        Specify the password to login to Prism Central.
    .PARAMETER ApiKey
        Specify an API Key (Token) to authenticate to Prism Central.
    .PARAMETER ProtectionPolicyCategoryName
        Specify the category name which is used for data protection tagging.
    .NOTES
        None
    .EXAMPLE
        Get-NutanixVmInfo -Ip '10.0.200.100' -Username 'operator' -Password 'password'
        Retrieves all VMs from Prism Central with IP 10.0.200.100 and use username/password authentication.
    #>
    [CmdletBinding()]
    param(
        #region parameter, to add a new parameter, copy and paste the Parameter-region
        [Parameter(Mandatory=$true)] [String]       $Ip,
        [Parameter(Mandatory=$false)][String]       $Port = '9440',
        [Parameter(Mandatory=$false)][String]       $Username,
        [Parameter(Mandatory=$false)][SecureString] $Password,
        [Parameter(Mandatory=$false)][String]       $ApiKey,
        [Parameter(Mandatory=$false)][String]       $ProtectionPolicyCategoryName = 'DataProtection'
        #endregion
    )
    begin{
        #region Do not change this region
        $StartTime = Get-Date
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose $('[', (Get-Date -f 'yyyy-MM-dd HH:mm:ss.fff'), ']', '[ Begin   ]', $function -Join ' ')
        #endregion
        $ret = $null # or @()
    }
    process{
        Write-Verbose $('[', (Get-Date -f 'yyyy-MM-dd HH:mm:ss.fff'), ']', '[ Process ]', $function -Join ' ')
        foreach($item in $PSBoundParameters.keys){ $params = "$($params) -$($item) $($PSBoundParameters[$item])" }
        if ($PSCmdlet.ShouldProcess($params.Trim())){
            try{
                $RestUriListVms = "https://$($Ip):$($Port)/api/nutanix/v3/vms/list"
                $Payload = "{""kind"":""vm"", ""length"":99999}"

                # create the HTTP Basic Authorization header
                $pair = $Username + ":" + (ConvertFrom-SecureString -SecureString $Password -AsPlainText)
                $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
                $base64 = [System.Convert]::ToBase64String($bytes)
                $basicAuthValue = "Basic $base64"
                # setup the request headers
                $Headers = @{
                    'Accept' = 'application/json'
                    'Authorization' = $basicAuthValue
                    'Content-Type' = 'application/json'
                }
                
                # RestAPI Call to get all VMs from Prism Central
                $VmList = Invoke-WebRequest -Method 'POST' -SkipCertificateCheck -Uri $RestUriListVms -Headers $Headers -Body $Payload | ConvertFrom-Json
                
                $ret = foreach ($vm in $VmList.entities) {
                    if ($vm.status.resources.hypervisor_type -eq 'AHV') {
                        [pscustomobject]@{
                            Name                    = $vm.spec.name
                            VmUuid                  = $vm.metadata.uuid
                            ClusterName             = $vm.spec.cluster_reference.name
                            ClusterUuid             = $vm.spec.cluster_reference.uuid
                            VeeamAhvProxyIp         = $null
                            DataProtectionCategory  = $vm.metadata.categories.$ProtectionPolicyCategoryName
                            ProtectionStatus        = $null

                        }
                    }
                }

                if (-not ($VmList.metadata.length -gt 0)) {
                    throw 'No data received.'
                }
                
            }catch{
                Write-Warning $('ScriptName:', $($_.InvocationInfo.ScriptName), 'LineNumber:', $($_.InvocationInfo.ScriptLineNumber), 'Message:', $($_.Exception.Message) -Join ' ')
                $Error.Clear()
            }
        }
    }

    end{
        #region Do not change this region
        Write-Verbose $('[', (Get-Date -f 'yyyy-MM-dd HH:mm:ss.fff'), ']', '[ End     ]', $function -Join ' ')
        $TimeSpan  = New-TimeSpan -Start $StartTime -End (Get-Date)
        $Formatted = $TimeSpan | ForEach-Object {
            '{1:0}h {2:0}m {3:0}s {4:000}ms' -f $_.Days, $_.Hours, $_.Minutes, $_.Seconds, $_.Milliseconds
        }
        Write-Verbose $('Finished in:', $Formatted -Join ' ')
        #endregion
        return $ret
    }
}