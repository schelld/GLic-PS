# Module-scope state (visible to all dot-sourced private functions)
$script:GlicModuleRoot  = $PSScriptRoot
$script:GlicSession     = $null   # set by Connect-Glic: @{ Config; ServiceAccount }
$script:_glicToken      = $null
$script:_glicTokenExpiry = [datetime]::MinValue

$script:GlicScopes = @(
    'https://www.googleapis.com/auth/chrome.management.reports.readonly'
    'https://www.googleapis.com/auth/chrome.management.telemetry.readonly'
    'https://www.googleapis.com/auth/chrome.management.profiles.readonly'
    'https://www.googleapis.com/auth/admin.directory.customer.readonly'
    'https://www.googleapis.com/auth/admin.directory.device.chromeos.readonly'
    'https://www.googleapis.com/auth/admin.directory.user.readonly'
    'https://www.googleapis.com/auth/admin.directory.orgunit.readonly'
    'https://www.googleapis.com/auth/apps.licensing'
)

Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

Export-ModuleMember -Function @(
    'Connect-Glic'
    'Get-GlicApps'
    'Get-GlicDevices'
    'Get-GlicTelemetry'
    'Get-GlicHardware'
    'Get-GlicLicenses'
    'Get-GlicUsers'
    'Get-GlicManagedBrowsers'
    'Get-GlicDeviceApps'
    'Get-GlicBrowserExtensions'
    'Invoke-GlicDiscover'
)
