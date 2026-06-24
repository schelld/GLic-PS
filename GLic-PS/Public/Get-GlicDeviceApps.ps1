function Get-GlicDeviceApps {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string]$OrgUnit,
        [string]$Config,
        [string]$ServiceAccountPath
    )

    $ctx        = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath
    $reportDate = (Get-Date).ToString('yyyy-MM-dd')

    $orgUnitId = $null
    if ($OrgUnit) {
        $ouUri = "https://admin.googleapis.com/admin/directory/v1/customer/$($ctx.CustomerId)/orgunits/$([Uri]::EscapeDataString($OrgUnit.TrimStart('/')))"
        try   { $orgUnitId = (Invoke-RestMethod -Uri $ouUri -Headers $ctx.Headers -ErrorAction Stop).orgUnitId }
        catch { if ($_.Exception.Response.StatusCode.value__ -eq 404) { throw "Org unit not found: $OrgUnit" } throw }
    }

    $uri   = "https://chromemanagement.googleapis.com/v1/customers/$($ctx.CustomerId)/reports:countInstalledApps"
    $query = @{ pageSize = 100 }
    if ($orgUnitId) { $query['orgUnitId'] = $orgUnitId }

    Invoke-GlicPagedRequest -Uri $uri -Headers $ctx.Headers -Query $query -ItemsProperty 'installedApps' |
    ForEach-Object {
        if (-not $_.appId) { return }
        [PSCustomObject]@{
            ReportDate         = $reportDate
            CustomerId         = $ctx.CustomerId
            AppId              = $_.appId
            DisplayName        = if ($_.displayName)        { $_.displayName }        else { '' }
            AppType            = if ($_.appType)            { $_.appType }            else { '' }
            BrowserDeviceCount = if ($_.browserDeviceCount) { [long]$_.browserDeviceCount } else { 0L }
            OsUserCount        = if ($_.osUserCount)        { [long]$_.osUserCount }        else { 0L }
        }
    }
}
