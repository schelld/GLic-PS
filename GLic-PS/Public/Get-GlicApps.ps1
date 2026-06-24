function Get-GlicApps {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string]$Config,
        [string]$ServiceAccountPath
    )

    $ctx        = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath
    $reportDate = (Get-Date).ToString('yyyy-MM-dd')
    $uri        = "https://chromemanagement.googleapis.com/v1/customers/$($ctx.CustomerId)/reports:countInstalledApps"

    Invoke-GlicPagedRequest -Uri $uri -Headers $ctx.Headers `
        -Query @{ pageSize = 100 } -ItemsProperty 'installedApps' |
    ForEach-Object {
        [PSCustomObject]@{
            ReportDate         = $reportDate
            CustomerId         = $ctx.CustomerId
            DisplayName        = if ($_.displayName)        { $_.displayName }        else { '' }
            AppId              = if ($_.appId)              { $_.appId }              else { '' }
            AppType            = if ($_.appType)            { $_.appType }            else { '' }
            Publisher          = ''   # countInstalledApps does not return publisher data
            BrowserDeviceCount = if ($_.browserDeviceCount) { [long]$_.browserDeviceCount } else { 0L }
        }
    }
}
