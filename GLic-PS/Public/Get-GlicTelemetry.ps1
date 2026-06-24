function Get-GlicTelemetry {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [ValidateSet('all','active','deprovisioned','disabled')]
        [string]$Status = 'active',
        [string]$OrgUnit,
        [string]$Config,
        [string]$ServiceAccountPath
    )

    $ctx = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath

    # Step 1: fetch telemetry into dictionary keyed by deviceId
    $telemetry = @{}
    Invoke-GlicPagedRequest `
        -Uri     "https://chromemanagement.googleapis.com/v1/customers/$($ctx.CustomerId)/telemetry/devices" `
        -Headers $ctx.Headers `
        -Query   @{ readMask = 'name,device_id,serial_number,os_update_status'; pageSize = 100 } `
        -ItemsProperty 'devices' |
    ForEach-Object { if ($_.deviceId) { $telemetry[$_.deviceId] = $_ } }

    # Step 2: fetch directory devices and merge
    $dirUri   = "https://admin.googleapis.com/admin/directory/v1/customer/$($ctx.CustomerId)/devices/chromeos"
    $dirQuery = @{ projection = 'FULL'; maxResults = 200 }
    if ($Status -ne 'all') { $dirQuery['query'] = "status:$($Status.ToUpper())" }
    if ($OrgUnit) { $dirQuery['orgUnitPath'] = $OrgUnit }

    Invoke-GlicPagedRequest -Uri $dirUri -Headers $ctx.Headers -Query $dirQuery -ItemsProperty 'chromeosdevices' |
    ForEach-Object {
        $td  = if ($_.deviceId) { $telemetry[$_.deviceId] } else { $null }
        $ous = if ($td) { $td.osUpdateStatus } else { $null }
        [PSCustomObject]@{
            CustomerId            = $ctx.CustomerId
            DeviceId              = if ($_.deviceId)      { $_.deviceId }      else { '' }
            SerialNumber          = if ($_.serialNumber)  { $_.serialNumber }  else { '' }
            Model                 = if ($_.model)         { $_.model }         else { '' }
            Status                = if ($_.status)        { $_.status }        else { '' }
            OrgUnitPath           = if ($_.orgUnitPath)   { $_.orgUnitPath }   else { '' }
            OsVersion             = if ($_.osVersion)     { $_.osVersion }     else { '' }
            LastSyncUser          = if ($_.recentUsers)   { $_.recentUsers[0].email } else { '' }
            UpdateState           = if ($ous)             { $ous.updateState }            else { '' }
            UpdateTargetOsVersion = if ($ous)             { $ous.updateTargetOsVersion }  else { '' }
            LastUpdateCheckTime   = if ($ous) { if ($ous.lastUpdateCheckTime) { [DateTimeOffset]::Parse($ous.lastUpdateCheckTime) } else { $null } } else { $null }
        }
    }
}
