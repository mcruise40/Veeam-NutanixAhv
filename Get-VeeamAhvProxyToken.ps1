function Get-VeeamAhvProxyToken {
    <#
    .SYNOPSIS
        Get API access token for Veeam proxy for Nutanix AHV.
    .DESCRIPTION
        Authenticates via username/password and retrieves a valid API access token.
    .PARAMETER ProxyIp
        Specify the IP address or hostname for Veeam Proxy for Nutanix AHV.
    .PARAMETER Username
        Specify the username for Veeam Proxy for Nutanix AHV.
    .PARAMETER Password
        Specify the password for Veeam Proxy for Nutanix AHV.
    .NOTES
        It's not recommeded to store credentials in a script.
    .EXAMPLE
        Get-VeeamAhvProxyToken -ProxyIp '10.0.200.100' -Username 'admin' -Password 'password'
    #>
    [CmdletBinding(SupportsShouldProcess=$True)]
    param(
        #region parameter, to add a new parameter, copy and paste the Parameter-region
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            Position = 0
        )]
        [String] $ProxyIp,

        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            Position = 1
        )]
        [String] $Username,
        
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            Position = 2
        )]
        [SecureString] $Password
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
                $Uri = "https://$ProxyIp/api/oauth2/token"
                $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                $headers.Add("Content-Type", "application/x-www-form-urlencoded")
                $body = "grantType=Password&userName=$Username&password=" + (ConvertFrom-SecureString -SecureString $Password -AsPlainText)
                
                $AuthResponse = Invoke-RestMethod $Uri -Method 'POST' -Headers $headers -Body $body -SkipCertificateCheck

                $ret = ConvertTo-SecureString $AuthResponse.accessToken -AsPlainText -Force

                if ($null -eq $ret) {
                    throw 'No token received.'
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