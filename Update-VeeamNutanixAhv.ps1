function Update-VeeamNutanixAhv {
    <#
    .SYNOPSIS
        A short one-line action-based description, e.g. 'Tests if a function is valid'
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
        [Parameter(Mandatory=$true)][String]       $ProxyIp,
        [Parameter(Mandatory=$true)][SecureString] $ApiKey,
        [Parameter(Mandatory=$true)][String]       $ClusterId
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

                $RestUriClusterRefresh = "https://$ProxyIp/api/v4/clusters/$ClusterId/vms/refreshAsync"
                $Refresh = Invoke-RestMethod -Method 'POST' -SkipCertificateCheck -Uri $RestUriClusterRefresh -Authentication Bearer -Token $ApiKey

                $RestUriServerRescan = "https://$ProxyIp/api/v4/backupServer/rescanBackups"
                $Rescan = Invoke-RestMethod -Method 'POST' -SkipCertificateCheck -Uri $RestUriServerRescan -Authentication Bearer -Token $ApiKey

                $RestUriJobs = "https://$ProxyIp/api/v4/jobs"
                $Jobs = Invoke-RestMethod -Method 'GET' -SkipCertificateCheck -Uri $RestUriJobs -Authentication Bearer -Token $ApiKey


                if($ret.StatusCode -ne 204) {
                    throw 'There is something wrong'
                }

                # Disable and re-enable job
                Invoke-WebRequest -Method 'POST' -SkipCertificateCheck -Uri $RestUriJobDisable -Authentication Bearer -Token $ApiKey
                Invoke-WebRequest -Method 'POST' -SkipCertificateCheck -Uri $RestUriJobEnable -Authentication Bearer -Token $ApiKey
                
                
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