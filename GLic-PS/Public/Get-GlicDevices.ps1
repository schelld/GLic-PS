function Get-GlicDevices {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [ValidateSet('all','active','deprovisioned','disabled')]
        [string]$Status = 'active',
        [string]$Config,
        [string]$ServiceAccountPath
    )

    $ctx        = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath
    $reportDate = (Get-Date).ToString('yyyy-MM-dd')
    $uri        = "https://admin.googleapis.com/admin/directory/v1/customer/$($ctx.CustomerId)/devices/chromeos"
    $query      = @{ projection = 'FULL'; maxResults = 200 }
    if ($Status -ne 'all') { $query['query'] = "status:$($Status.ToUpper())" }

    Invoke-GlicPagedRequest -Uri $uri -Headers $ctx.Headers -Query $query -ItemsProperty 'chromeosdevices' |
    ForEach-Object {
        $lastSync    = if ($_.lastSync)            { [DateTimeOffset]::Parse($_.lastSync) }            else { $null }
        $enrollment  = if ($_.lastEnrollmentTime)  { [DateTimeOffset]::Parse($_.lastEnrollmentTime) }  else { $null }
        [PSCustomObject]@{
            ReportDate         = $reportDate
            CustomerId         = $ctx.CustomerId
            DeviceId           = if ($_.deviceId)           { $_.deviceId }           else { '' }
            SerialNumber       = if ($_.serialNumber)       { $_.serialNumber }       else { '' }
            Model              = if ($_.model)              { $_.model }              else { '' }
            Status             = if ($_.status)             { $_.status }             else { '' }
            OrgUnitPath        = if ($_.orgUnitPath)        { $_.orgUnitPath }        else { '' }
            AnnotatedUser      = if ($_.annotatedUser)      { $_.annotatedUser }      else { '' }
            LastSyncUser       = if ($_.recentUsers)        { $_.recentUsers[0].email } else { '' }
            AnnotatedLocation  = if ($_.annotatedLocation)  { $_.annotatedLocation }  else { '' }
            LastSync           = $lastSync
            EnrollmentTime     = $enrollment
            OsVersion          = if ($_.osVersion)          { $_.osVersion }          else { '' }
            MacAddress         = if ($_.macAddress)         { $_.macAddress }         else { '' }
            EthernetMacAddress = if ($_.ethernetMacAddress) { $_.ethernetMacAddress } else { '' }
            LastKnownIp        = if ($_.lastKnownNetwork)   { $_.lastKnownNetwork[0].ipAddress } else { '' }
            AnnotatedAssetId   = if ($_.annotatedAssetId)   { $_.annotatedAssetId }   else { '' }
            OrderNumber        = if ($_.orderNumber)        { $_.orderNumber -join ',' } else { '' }
            PlatformVersion    = if ($_.platformVersion)    { $_.platformVersion }    else { '' }
            FirmwareVersion    = if ($_.firmwareVersion)    { $_.firmwareVersion }    else { '' }
            BootMode           = if ($_.bootMode)           { $_.bootMode }           else { '' }
            Notes              = if ($_.notes)              { $_.notes }              else { '' }
            Meid               = if ($_.meid)               { $_.meid }               else { '' }
        }
    }
}
