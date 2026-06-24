function Get-GlicManagedBrowsers {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string]$OrgUnit,
        [string]$Config,
        [string]$ServiceAccountPath
    )

    $ctx        = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath
    $reportDate = (Get-Date).ToString('yyyy-MM-dd')

    $filter = $null
    if ($OrgUnit) {
        $ouUri = "https://admin.googleapis.com/admin/directory/v1/customer/$($ctx.CustomerId)/orgunits/$([Uri]::EscapeDataString($OrgUnit.TrimStart('/')))"
        try {
            $ou     = Invoke-RestMethod -Uri $ouUri -Headers $ctx.Headers -ErrorAction Stop
            $filter = "org_unit_id = `"$($ou.orgUnitId)`""
        } catch {
            if ($_.Exception.Response.StatusCode.value__ -eq 404) {
                throw "Org unit not found: $OrgUnit"
            }
            throw
        }
    }

    $uri   = "https://chromemanagement.googleapis.com/v1/customers/$($ctx.CustomerId)/profiles"
    $query = @{ pageSize = 100 }
    if ($filter) { $query['filter'] = $filter }

    $results = @(Invoke-GlicPagedRequest -Uri $uri -Headers $ctx.Headers -Query $query -ItemsProperty 'customerProfiles')

    if ($filter -and $results.Count -eq 0) {
        Write-Warning 'Org unit filter returned no results — retrying without filter'
        $results = @(Invoke-GlicPagedRequest -Uri $uri -Headers $ctx.Headers -Query @{ pageSize = 100 } -ItemsProperty 'customerProfiles')
    }

    $results | ForEach-Object {
        [PSCustomObject]@{
            ReportDate       = $reportDate
            CustomerId       = $ctx.CustomerId
            ProfileId        = if ($_.profileId)              { $_.profileId }                         else { '' }
            DisplayName      = if ($_.displayName)            { $_.displayName }                       else { '' }
            AffiliatedUser   = if ($_.affiliatedUser)         { $_.affiliatedUser.userEmail }          else { '' }
            OrgUnitPath      = if ($_.orgUnitPath)            { $_.orgUnitPath }                       else { '' }
            BrowserVersion   = if ($_.browserVersion)         { $_.browserVersion }                    else { '' }
            Os               = if ($_.osInfo)                 { $_.osInfo.operatingSystem }            else { '' }
            OsVersion        = if ($_.osInfo)                 { $_.osInfo.osVersion }                  else { '' }
            LastActivityTime = if ($_.lastActivityTime)       { [DateTimeOffset]::Parse($_.lastActivityTime) } else { $null }
        }
    }
}
