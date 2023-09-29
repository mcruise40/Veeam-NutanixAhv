function Get-VeeamNutanixAhvProtectionStatus {
    <#
    .SYNOPSIS
        Retrieve jobs from a Veeam proxy for Nutanix AHV.
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .PARAMETER InputObject
        Specify the input of this parameter.
    .NOTES
        Information or caveats about the function e.g. 'This function is not supported in Linux'
    .EXAMPLE
        New-MwaFunction @{Name='MyName';Value='MyValue'} -Verbose
        Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
    #>
    [CmdletBinding()]
    param(
        #region parameter, to add a new parameter, copy and paste the Parameter-region
        [Parameter(Mandatory=$true)][String] $ProxyIp,
        [Parameter(Mandatory=$true)][SecureString] $ApiKey,
        [Parameter(Mandatory=$true)][String] $ClusterId,
        [Parameter(Mandatory=$true)][String] $VmName,
        [Parameter(Mandatory=$true)][String] $VmId
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
                $resultLimit = 9999

                $RestUriProtectedVms = "https://$ProxyIp/api/v4/dashboard/protectedVmsInCluster?offset=0&limit=$resultLimit"
                $ProtectedVms   = (Invoke-RestMethod -Method 'GET' -SkipCertificateCheck -Uri $RestUriProtectedVms -Authentication Bearer -Token $ApiKey).results

                $RestUriUnprotectedVms = "https://$ProxyIp/api/v4/dashboard/unprotectedVmsInCluster?offset=0&limit=$resultLimit"
                $UnprotectedVms = (Invoke-RestMethod -Method 'GET' -SkipCertificateCheck -Uri $RestUriUnprotectedVms -Authentication Bearer -Token $ApiKey).results

                if ($VmId -in $ProtectedVms.id) {
                    Write-Verbose "VM $VmName is already marked as protected"
                    $ret = $true
                }
                elseif ($VmId -in $UnprotectedVms.id) {
                    Write-Verbose "VM $VmName is not marked as proteceted"
                    $ret = $false
                }
                else {
                    Throw 'VM not found!'
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