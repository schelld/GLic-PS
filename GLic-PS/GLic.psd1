@{
    ModuleVersion     = '1.0.0'
    GUID              = '1400e630-bb96-4f3d-b106-201f663f2420'
    Author            = 'D. Schell'
    CompanyName       = 'schelld'
    Description       = 'Google Workspace Chrome Management PowerShell module (pure-PS edition)'
    PowerShellVersion = '5.1'
    RootModule        = 'GLic.psm1'
    FunctionsToExport = @(
        'Connect-Glic','Get-GlicApps','Get-GlicDevices','Get-GlicTelemetry',
        'Get-GlicHardware','Get-GlicLicenses','Get-GlicUsers','Get-GlicManagedBrowsers',
        'Get-GlicDeviceApps','Get-GlicBrowserExtensions','Invoke-GlicDiscover'
    )
    CmdletsToExport   = @()
    AliasesToExport   = @()
    PrivateData       = @{ PSData = @{ Tags = @('Google','Workspace','Chrome','ITAM') } }
}
