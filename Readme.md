# Veeam-NutanixAhv
> Powershell script to use categories from Nutanix Prism Central with Veeam for Nutanix AHV

The script will update jobs in Veeam Proxy for Nutanix AHV based on categories defined in Prism Central.

## Installation

### Credentials
For Credentials you can use SecretManagement / SecretStore to store passwords:
- https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/how-to/using-secrets-in-automation?view=ps-modules 

```PowerShell
Install-Module -Name Microsoft.PowerShell.SecretStore -Repository PSGallery -Force
Install-Module -Name Microsoft.PowerShell.SecretManagement -Repository PSGallery -Force
Import-Module Microsoft.PowerShell.SecretStore
Import-Module Microsoft.PowerShell.SecretManagement
```

Create a new vault
```PowerShell
register-SecretVault -Name SecretStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
```



## Usage example

Update-VeeamNutanixAhvJobs -PrismCentralIp '10.30.0.5' -PrismCentralCred 'PrismCentral' -ProxyMappingFilePath '.\ProxyMapping.csv' -VeeamAhvProxyCred 'VeeamNutanixAhv' -SecretStoreCred 'SecretStore'

## Release History

* 0.1.0
    * The first proper release
    * CHANGE: Rename `foo()` to `bar()`
* 0.0.1
    * Work in progress

## Meta

Andy Kruesi // Ceruno AG

Distributed under the GPLv3 license

[https://github.com/mcruise40](https://github.com/mcruise40)

## Contributing

1. Fork it (<https://github.com/mcruise40/Veeam-NutanixAhv/fork>)
2. Create your feature branch (`git checkout -b feature/fooBar`)
3. Commit your changes (`git commit -am 'Add some fooBar'`)
4. Push to the branch (`git push origin feature/fooBar`)
5. Create a new Pull Request

<!-- Markdown link & img dfn's -->
[wiki]: https://github.com/mcruise40/Veeam-NutanixAhv/wiki
