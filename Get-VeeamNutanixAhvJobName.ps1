function Get-VeeamNutanixAhvJobName {
    <#
    .SYNOPSIS
        Retrieve jobs from a Veeam proxy for Nutanix AHV.
    .DESCRIPTION
        The Get-VeeamNutanixAhvProtectionStatus function is designed to interact with a Veeam proxy for Nutanix AHV clusters. The main purpose of this script is to determine whether a specific virtual machine, identified by its VmId, is marked as protected or not in the dashboard
    .PARAMETER ProxyIp
    The IP address of the Veeam proxy server. This is used to construct the API endpoint URLs for requests. It is mandatory to provide this IP address for the script to correctly connect to the desired Veeam proxy.
    .PARAMETER ApiKey
    The API key used for authentication when communicating with the Veeam proxy server's API. This is provided as a SecureString to ensure the confidentiality of the API key during script execution. The key allows the script to fetch data about protected and unprotected VMs.
    .PARAMETER VmName
    The human-readable name of the virtual machine that you wish to check the protection status for. The script uses the VmId primarily for determining protection status, but the VmName is used for providing context in verbose outputs.
    .PARAMETER VmId
    A unique identifier for the virtual machine. This ID is crucial as it's used to determine whether the VM is in the list of protected or unprotected VMs. Always ensure that the correct VM ID is provided to get accurate results.

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
        [Parameter(Mandatory=$true)][String] $JobId
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

                $RestUriJobInfo = "https://$ProxyIp/api/v4/jobs/$JobId"
                $JobInfo = Invoke-RestMethod -Method 'GET' -SkipCertificateCheck -Uri $RestUriJobInfo -Authentication Bearer -Token $ApiKey

                if ($JobInfo -and $JobInfo.name) {
                    $JobName = $JobInfo.name
                    Write-Verbose "Job with ID $JobId has name $JobName"
                    $ret = $JobName
                }
                else {
                    Throw 'Job not found!'
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