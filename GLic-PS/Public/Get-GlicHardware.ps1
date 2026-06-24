function Get-GlicHardware {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [ValidateSet('all','active','deprovisioned','disabled')]
        [string]$Status = 'all',
        [string]$OrgUnit,
        [string]$Config,
        [string]$ServiceAccountPath
    )

    $ctx = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath

    $telemetry = @{}
    $readMask  = 'name,device_id,serial_number,cpu_info,memory_info,battery_info,' +
                 'battery_status_report,storage_info,storage_status_report,' +
                 'network_info,graphics_info,os_update_status'

    Invoke-GlicPagedRequest `
        -Uri     "https://chromemanagement.googleapis.com/v1/customers/$($ctx.CustomerId)/telemetry/devices" `
        -Headers $ctx.Headers `
        -Query   @{ readMask = $readMask; pageSize = 100 } `
        -ItemsProperty 'devices' |
    ForEach-Object { if ($_.deviceId) { $telemetry[$_.deviceId] = $_ } }

    $dirUri   = "https://admin.googleapis.com/admin/directory/v1/customer/$($ctx.CustomerId)/devices/chromeos"
    $dirQuery = @{ projection = 'FULL'; maxResults = 200 }
    if ($Status -ne 'all') { $dirQuery['query'] = "status:$($Status.ToUpper())" }
    if ($OrgUnit) { $dirQuery['orgUnitPath'] = $OrgUnit }

    Invoke-GlicPagedRequest -Uri $dirUri -Headers $ctx.Headers -Query $dirQuery -ItemsProperty 'chromeosdevices' |
    ForEach-Object {
        $td  = if ($_.deviceId) { $telemetry[$_.deviceId] } else { $null }
        $cpu = if ($td) { $td.cpuInfo | Select-Object -First 1 } else { $null }
        $mem = if ($td) { $td.memoryInfo } else { $null }
        $bat = if ($td) { $td.batteryInfo | Select-Object -First 1 } else { $null }
        $sto = if ($td) { $td.storageInfo } else { $null }
        $gpu = if ($td -and $td.graphicsInfo -and $td.graphicsInfo.adapterInfo) { $td.graphicsInfo.adapterInfo | Select-Object -First 1 } else { $null }
        $ramGb = if ($mem -and $mem.totalRamBytes) { [int]([long]($mem.totalRamBytes) / 1GB) } else { 0 }
        $storageAvailGb = if ($sto -and $sto.availableDiskBytes) { [int]([long]($sto.availableDiskBytes[0]) / 1GB) } else { 0 }
        $storageTotalGb = if ($sto -and $sto.totalStorageBytes)  { [int]([long]($sto.totalStorageBytes[0])  / 1GB) } else { 0 }
        $batDesign  = if ($bat -and $bat.designCapacity)      { [int]$bat.designCapacity }      else { 0 }
        $batFull    = if ($bat -and $bat.fullChargeCapacity)   { [int]$bat.fullChargeCapacity }  else { 0 }
        $lastSync   = if ($_.lastSync)            { [DateTimeOffset]::Parse($_.lastSync) } else { $null }
        $enrollment = if ($_.lastEnrollmentTime)  { [DateTimeOffset]::Parse($_.lastEnrollmentTime) } else { $null }
        [PSCustomObject]@{
            ReportDate           = (Get-Date).ToString('yyyy-MM-dd')
            CustomerId           = $ctx.CustomerId
            DeviceId             = if ($_.deviceId)          { $_.deviceId }          else { '' }
            SerialNumber         = if ($_.serialNumber)      { $_.serialNumber }      else { '' }
            Model                = if ($_.model)             { $_.model }             else { '' }
            Status               = if ($_.status)            { $_.status }            else { '' }
            OrgUnitPath          = if ($_.orgUnitPath)       { $_.orgUnitPath }       else { '' }
            AnnotatedAssetId     = if ($_.annotatedAssetId)  { $_.annotatedAssetId }  else { '' }
            AnnotatedUser        = if ($_.annotatedUser)     { $_.annotatedUser }     else { '' }
            OsVersion            = if ($_.osVersion)         { $_.osVersion }         else { '' }
            LastSync             = $lastSync
            EnrollmentTime       = $enrollment
            CpuModel             = if ($cpu -and $cpu.model)          { $cpu.model }           else { '' }
            CpuArchitecture      = if ($cpu -and $cpu.architecture)   { $cpu.architecture }    else { '' }
            RamGb                = $ramGb
            StorageAvailableGb   = $storageAvailGb
            StorageTotalGb       = $storageTotalGb
            BatteryDesignMah     = $batDesign
            BatteryFullChargeMah = $batFull
            GpuName              = if ($gpu -and $gpu.name)           { $gpu.name }            else { '' }
        }
    }
}
