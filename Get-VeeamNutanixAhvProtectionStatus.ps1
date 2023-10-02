function Get-VeeamNutanixAhvProtectionStatus {
    <#
    .SYNOPSIS
        Retrieve jobs from a Veeam proxy for Nutanix AHV and check if VM is already protected in any backup job
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
                $vmFoundInJob = $false

                # Check if VM is already listet in Veeam backup job
                $RestUriJobSettings = "https://$ProxyIp/api/v4/jobs?limit=$resultLimit"
                $JobSettings = (Invoke-RestMethod -Method 'GET' -SkipCertificateCheck -Uri $RestUriJobSettings -Authentication Bearer -Token $ApiKey).results

                $JobSettings.settings | ForEach-Object {
                    if ($VmId -in $_.vmIds) {
                        $JobName = $_.name
                        Write-Verbose "VM $VmName is already protected in backup job $JobName"
                        $vmFoundInJob = $true
                        $ret = $_.id
                        break
                    }
                }
                    
                if (-not $vmFoundInJob) {
                    Write-Verbose "VM $VmName was not found in any backup job"
                    $ret = $false
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