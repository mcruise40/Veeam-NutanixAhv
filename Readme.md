# Product Name
> Veeam for Nutanix AHV integration with Nutanix Prism Central

The script will update jobs in Veeam Proxy for Nutanix AHV based on Categories defined in Prism Central.

## Installation

You need to install SecretManagement / SecretStore to save passwords

```Powershell
Install-Module -Name Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore
```


## Usage example

Update-VeeamNutanixAhvJobs 

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