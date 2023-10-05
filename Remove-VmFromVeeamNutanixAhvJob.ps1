function Remove-VmFromVeeamNutanixAhvJob {
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
        [Parameter(Mandatory=$true)]
        [String]$ProxyIp,

        [Parameter(Mandatory=$true)]
        [SecureString] $ApiKey,

        [Parameter(Mandatory=$true,
            ParameterSetName='Name')]
        [String]$JobName,

        [Parameter(Mandatory=$true,
            ParameterSetName='Id')]
        [String]$JobId,

        [Parameter(Mandatory=$true)]
        [String]$ClusterId,

        [Parameter(Mandatory=$true)]
        [String]$VmId
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

                if ($JobName) {
                    $RestUriJobs = "https://$ProxyIp/api/v4/jobs"

                    $Jobs = (Invoke-RestMethod -Method 'GET' -SkipCertificateCheck -Uri $RestUriJobs -Authentication Bearer -Token $ApiKey).results

                    # Find job on proxy
                    foreach ($item in $Jobs) {
                        if ($item.name -eq $JobName -and $item.mode -eq 'Backup') {
                            Write-Verbose "Found Veeam job $JobName on proxy"
                            $JobId = $item.id
                        }
                    }
                }
                
                if ($JobId) {
                    $RestUriJobSettings = 'https://' + $ProxyIp + '/api/v4/jobs/' + $JobId + '/settings'
                    
                    $JobSettings = Invoke-RestMethod -Method 'GET' -SkipCertificateCheck -Uri $RestUriJobSettings -Authentication Bearer -Token $ApiKey

                    if ($VmId -in $JobSettings.vmIds) {
                        Write-Verbose "Remove VM with ID $VmId"
                        
                        # Remove multiple VM IDs
                        $JobSettings.vmIds = $JobSettings.vmIds | Select-Object -Unique
                        
                        # Remove VM from job
                        $JobSettings.vmIds -= $VmId
                        
                        # Need to remove .CustomScript.FileName because of an error message for the re-import
                        $JobSettings.customScript.PSObject.Properties.Remove('fileName')
                        $JobSettings_json = ConvertTo-Json($JobSettings) -Depth 10
        
                        $ret = Invoke-WebRequest -Method 'PUT' -ContentType 'application/json' -SkipCertificateCheck -Uri $RestUriJobSettings -Authentication Bearer -Token $ApiKey -Body $JobSettings_json
    
                        if($ret.StatusCode -ne 204) {
                            throw 'Error in API call'
                        }
                    }
                    else {
                        Write-Verbose "VM not found in the job"
                        $ret = $null
                    }
                }
                else {
                    Write-Verbose "Job name or ID is wrong or could not be found"
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