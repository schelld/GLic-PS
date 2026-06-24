# Copyright (c) 2026 D. Schell <schelld@live.com>
# https://github.com/schelld/GLIC-ps
# GLic-Runtime.ps1 — dot-source this file in runner scripts
#Requires -Version 5.1

# Config files (glic.json, service-account.json, skus.json) are read from and written to
# the same folder as this script. To store them in a shared location instead, set
# $env:GLIC_CONFIG before dot-sourcing, for example in a wrapper or scheduled-task script:
#
#   $env:GLIC_CONFIG = 'C:\ProgramData\GLic'
#   . 'C:\Scripts\GLic\GLic-Runtime.ps1'

# Session-scope state
$script:GlicModuleRoot   = $PSScriptRoot
$script:GlicSession      = $null
$script:_glicToken       = $null
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

function Start-GlicLog {
    param([string]$Path, [string]$Message)
    $null = New-Item -ItemType Directory -Force (Split-Path $Path) -ErrorAction SilentlyContinue
    "$([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss'))Z  $Message" | Add-Content -LiteralPath $Path
}

function Resolve-GlicConfigPath {
    param([string]$FileName)
    $root = if ($env:GLIC_CONFIG) { $env:GLIC_CONFIG } else { $script:GlicModuleRoot }
    $p = Join-Path $root $FileName
    if (Test-Path $p) { return $p }
    return $null
}

function Get-GlicConfig {
    param([string]$Path)
    if ($script:GlicSession) { return $script:GlicSession.Config }
    if (-not $Path) { $Path = Resolve-GlicConfigPath 'glic.json' }
    if (-not $Path -or -not (Test-Path $Path)) {
        throw "glic.json not found. Copy glic.json.example to glic.json and fill in customer_id and admin_email."
    }
    $json = Get-Content $Path -Raw | ConvertFrom-Json
    return [PSCustomObject]@{
        CustomerId = $json.customer_id
        AdminEmail = $json.admin_email
    }
}

function Get-GlicServiceAccount {
    param([string]$Path)
    if ($script:GlicSession) { return $script:GlicSession.ServiceAccount }
    if (-not $Path) { $Path = Resolve-GlicConfigPath 'service-account.json' }
    if ($Path -and (Test-Path $Path)) {
        $raw = Get-Content $Path -Raw
        if ($raw.Length -gt 0 -and [int][char]$raw[0] -eq 0xFEFF) { $raw = $raw.Substring(1) }
        return $raw | ConvertFrom-Json
    }
    try {
        $json = Get-Secret -Name 'GlicServiceAccountKey' -Vault 'GlicVault' -AsPlainText -ErrorAction Stop
        return $json | ConvertFrom-Json
    } catch {
        throw "service-account.json not found in '$($script:GlicModuleRoot)' or SecretStore vault."
    }
}

function Get-GlicAccessToken {
    [CmdletBinding()]
    param([string]$AdminEmail, [psobject]$ServiceAccount)

    if ($script:_glicToken -and $script:_glicTokenExpiry -gt (Get-Date).AddMinutes(2)) {
        return $script:_glicToken
    }

    $iat = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $exp = $iat + 3600

    $header    = [ordered]@{ alg = 'RS256'; typ = 'JWT'; kid = $ServiceAccount.private_key_id }
    $headerB64 = [Convert]::ToBase64String(
        [Text.Encoding]::UTF8.GetBytes(($header | ConvertTo-Json -Compress))
    ) -replace '\+','-' -replace '/','_' -replace '='

    $payload = [ordered]@{
        iss   = $ServiceAccount.client_email
        sub   = $AdminEmail
        scope = ($script:GlicScopes -join ' ')
        aud   = 'https://oauth2.googleapis.com/token'
        iat   = $iat
        exp   = $exp
    }
    $payloadB64 = [Convert]::ToBase64String(
        [Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Compress))
    ) -replace '\+','-' -replace '/','_' -replace '='

    $signingInput = "${headerB64}.${payloadB64}"

    $pemBody  = $ServiceAccount.private_key -replace '-----[^-]+-----' -replace '\s'
    $keyBytes = [Convert]::FromBase64String($pemBody)
    $cngKey   = [Security.Cryptography.CngKey]::Import(
        $keyBytes, [Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob)
    $rsa = New-Object Security.Cryptography.RSACng $cngKey

    $inputBytes = [Text.Encoding]::UTF8.GetBytes($signingInput)
    $sigBytes   = $rsa.SignData(
        $inputBytes,
        [Security.Cryptography.HashAlgorithmName]::SHA256,
        [Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $sigB64 = [Convert]::ToBase64String($sigBytes) -replace '\+','-' -replace '/','_' -replace '='

    $jwt = "${signingInput}.${sigB64}"

    $body = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=$jwt"
    try {
        $response = Invoke-RestMethod -Method Post `
            -Uri 'https://oauth2.googleapis.com/token' `
            -ContentType 'application/x-www-form-urlencoded' `
            -Body $body `
            -ErrorAction Stop
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        $errBody = ''
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader $stream
            $errBody = $reader.ReadToEnd()
            $reader.Close()
        } catch {}
        throw "Token exchange failed (HTTP $code): $errBody"
    }

    $script:_glicToken       = $response.access_token
    $script:_glicTokenExpiry = (Get-Date).AddSeconds($response.expires_in - 120)
    return $script:_glicToken
}

function Get-GlicContext {
    [CmdletBinding()]
    param([string]$ConfigPath, [string]$ServiceAccountPath)
    $cfg = Get-GlicConfig         -Path $ConfigPath
    $sa  = Get-GlicServiceAccount -Path $ServiceAccountPath
    $tok = Get-GlicAccessToken    -AdminEmail $cfg.AdminEmail -ServiceAccount $sa
    return [PSCustomObject]@{
        CustomerId = $cfg.CustomerId
        Headers    = @{ Authorization = "Bearer $tok" }
    }
}

function Invoke-GlicPagedRequest {
    [CmdletBinding()]
    param(
        [string]$Uri,
        [hashtable]$Headers,
        [hashtable]$Query        = @{},
        [string]$ItemsProperty,
        [string]$NextTokenProp   = 'nextPageToken'
    )
    $pageToken = $null
    do {
        $q = @{} + $Query
        if ($pageToken) { $q['pageToken'] = $pageToken }
        $qs = ($q.GetEnumerator() | Sort-Object Key | ForEach-Object {
            "$([Uri]::EscapeDataString($_.Key))=$([Uri]::EscapeDataString([string]$_.Value))"
        }) -join '&'
        $fullUri  = if ($qs) { "${Uri}?${qs}" } else { $Uri }
        $response = Invoke-RestMethod -Uri $fullUri -Headers $Headers -Method Get -ErrorAction Stop
        if ($ItemsProperty -and $response.$ItemsProperty) { $response.$ItemsProperty }
        $pageToken = $response.$NextTokenProp
    } while ($pageToken)
}

function Get-GlicSkuCatalog {
    [CmdletBinding()]
    param([string]$Path, [string]$SkuIds)
    if ($SkuIds) {
        return $SkuIds -split ',' | ForEach-Object {
            $parts = $_ -split ':',2
            if ($parts.Count -ne 2) { throw "Invalid SkuIds entry '$_'. Expected productId:skuId" }
            [PSCustomObject]@{ ProductId=$parts[0]; ProductName=$parts[0]; SkuId=$parts[1]; SkuName=$parts[1]; Active=$true }
        }
    }
    $resolved = if ($Path -and (Test-Path $Path)) { $Path } else { Resolve-GlicConfigPath 'skus.json' }
    if ($resolved -and (Test-Path $resolved)) {
        return (Get-Content $resolved -Raw | ConvertFrom-Json) |
            Where-Object { $_.active -ne $false } |
            ForEach-Object {
                [PSCustomObject]@{
                    ProductId   = $_.productId
                    ProductName = $_.productName
                    SkuId       = $_.skuId
                    SkuName     = $_.skuName
                    Active      = if ($null -eq $_.active) { $true } else { [bool]$_.active }
                }
            }
    }
    return @(
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace (Legacy)';           SkuId='Google-Apps-Unlimited';    SkuName='Business Starter';             Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace (Legacy)';           SkuId='Google-Apps-For-Business'; SkuName='Legacy G Suite Basic';         Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace (Legacy)';           SkuId='Google-Apps-Lite';         SkuName='Essentials Starter';           Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Enterprise (Legacy)';SkuId='1010020020';               SkuName='Enterprise Plus';              Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Business Plus';      SkuId='1010020025';               SkuName='Business Plus';                Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Enterprise Standard'; SkuId='1010020026';               SkuName='Google Workspace Enterprise Standard'; Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Business Standard';  SkuId='1010020028';               SkuName='Business Standard';            Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Business Plus';      SkuId='1010020030';               SkuName='Business Plus';                Active=$true }
        [PSCustomObject]@{ ProductId='101001';      ProductName='Cloud Identity';                      SkuId='1010010001';               SkuName='Cloud Identity Free';          Active=$true }
        [PSCustomObject]@{ ProductId='101005';      ProductName='Cloud Identity Premium';              SkuId='1010050001';               SkuName='Cloud Identity Premium';       Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Frontline';          SkuId='1010020031';               SkuName='Frontline Starter';            Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Frontline';          SkuId='1010020033';               SkuName='Frontline Standard';           Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Education';          SkuId='1010020034';               SkuName='Education Fundamentals';       Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Education';          SkuId='1010020035';               SkuName='Education Standard';           Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Education';          SkuId='1010020037';               SkuName='Teaching and Learning Upgrade';Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Education';          SkuId='1010020038';               SkuName='Education Plus';               Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Voice';                        SkuId='1010060001';               SkuName='Voice Starter';                Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Voice';                        SkuId='1010060002';               SkuName='Voice Standard';               Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Voice';                        SkuId='1010060003';               SkuName='Voice Premier';                Active=$true }
    )
}

function Get-GlicDevices {
    [CmdletBinding()]
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
        $lastSync   = if ($_.lastSync)           { [DateTimeOffset]::Parse($_.lastSync) }           else { $null }
        $enrollment = if ($_.lastEnrollmentTime) { [DateTimeOffset]::Parse($_.lastEnrollmentTime) } else { $null }
        [PSCustomObject]@{
            ReportDate         = $reportDate
            CustomerId         = $ctx.CustomerId
            DeviceId           = if ($_.deviceId)           { $_.deviceId }             else { '' }
            SerialNumber       = if ($_.serialNumber)       { $_.serialNumber }         else { '' }
            Model              = if ($_.model)              { $_.model }                else { '' }
            Status             = if ($_.status)             { $_.status }               else { '' }
            OrgUnitPath        = if ($_.orgUnitPath)        { $_.orgUnitPath }          else { '' }
            AnnotatedUser      = if ($_.annotatedUser)      { $_.annotatedUser }        else { '' }
            LastSyncUser       = if ($_.recentUsers)        { $_.recentUsers[0].email } else { '' }
            AnnotatedLocation  = if ($_.annotatedLocation)  { $_.annotatedLocation }    else { '' }
            LastSync           = $lastSync
            EnrollmentTime     = $enrollment
            OsVersion          = if ($_.osVersion)          { $_.osVersion }            else { '' }
            MacAddress         = if ($_.macAddress)         { $_.macAddress }           else { '' }
            EthernetMacAddress = if ($_.ethernetMacAddress) { $_.ethernetMacAddress }   else { '' }
            LastKnownIp        = if ($_.lastKnownNetwork)   { $_.lastKnownNetwork[0].ipAddress } else { '' }
            AnnotatedAssetId   = if ($_.annotatedAssetId)   { $_.annotatedAssetId }     else { '' }
            OrderNumber        = if ($_.orderNumber)        { $_.orderNumber -join ',' } else { '' }
            PlatformVersion    = if ($_.platformVersion)    { $_.platformVersion }       else { '' }
            FirmwareVersion    = if ($_.firmwareVersion)    { $_.firmwareVersion }       else { '' }
            BootMode           = if ($_.bootMode)           { $_.bootMode }              else { '' }
            Notes              = if ($_.notes)              { $_.notes }                 else { '' }
            Meid               = if ($_.meid)               { $_.meid }                  else { '' }
        }
    }
}

function Get-GlicApps {
    [CmdletBinding()]
    param([string]$Config, [string]$ServiceAccountPath)
    $ctx        = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath
    $reportDate = (Get-Date).ToString('yyyy-MM-dd')
    $uri        = "https://chromemanagement.googleapis.com/v1/customers/$($ctx.CustomerId)/reports:countInstalledApps"
    Invoke-GlicPagedRequest -Uri $uri -Headers $ctx.Headers -Query @{ pageSize = 100 } -ItemsProperty 'installedApps' |
    ForEach-Object {
        [PSCustomObject]@{
            ReportDate         = $reportDate
            CustomerId         = $ctx.CustomerId
            DisplayName        = if ($_.displayName)        { $_.displayName }                       else { '' }
            AppId              = if ($_.appId)              { $_.appId }                             else { '' }
            AppType            = if ($_.appType)            { $_.appType }                           else { '' }
            Publisher          = ''
            BrowserDeviceCount = if ($_.browserDeviceCount) { [long]$_.browserDeviceCount }         else { 0L }
        }
    }
}

function Get-GlicUsers {
    [CmdletBinding()]
    param(
        [string]$OrgUnit,
        [ValidateSet('Active','All','Suspended')]
        [string]$Suspended = 'Active',
        [string]$Config,
        [string]$ServiceAccountPath
    )
    $ctx   = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath
    $uri   = 'https://admin.googleapis.com/admin/directory/v1/users'
    $query = @{ customer = $ctx.CustomerId; maxResults = 500; projection = 'full' }
    if ($OrgUnit) { $query['query'] = "orgUnitPath='$($OrgUnit -replace "'","\\'")'" }
    $reportDate = (Get-Date).ToString('yyyy-MM-dd')
    Invoke-GlicPagedRequest -Uri $uri -Headers $ctx.Headers -Query $query -ItemsProperty 'users' |
    ForEach-Object {
        $isSuspended = $_.suspended -eq $true
        if ($Suspended -eq 'Active'    -and $isSuspended)      { return }
        if ($Suspended -eq 'Suspended' -and -not $isSuspended)  { return }
        $org          = $_.organizations | Where-Object { $_.primary -eq $true } | Select-Object -First 1
        if (-not $org) { $org = $_.organizations | Select-Object -First 1 }
        $managerEmail = ($_.relations  | Where-Object { $_.type -eq 'manager' }      | Select-Object -First 1).value
        $employeeId   = ($_.externalIds | Where-Object { $_.type -eq 'organization' } | Select-Object -First 1).value
        $aliases      = ($_.aliases -join ';')
        $creation     = if ($_.creationTime)  { [DateTimeOffset]::Parse($_.creationTime) }  else { $null }
        $lastLogin    = if ($_.lastLoginTime) { [DateTimeOffset]::Parse($_.lastLoginTime) } else { $null }
        [PSCustomObject]@{
            ReportDate       = $reportDate
            CustomerId       = $ctx.CustomerId
            PrimaryEmail     = if ($_.primaryEmail)  { $_.primaryEmail }      else { '' }
            FullName         = if ($_.name)          { $_.name.fullName }     else { '' }
            GivenName        = if ($_.name)          { $_.name.givenName }    else { '' }
            FamilyName       = if ($_.name)          { $_.name.familyName }   else { '' }
            CreationTime     = $creation
            LastLoginTime    = $lastLogin
            IsEnrolledIn2Sv  = $_.isEnrolledIn2Sv
            IsEnforcedIn2Sv  = $_.isEnforcedIn2Sv
            RecoveryEmail    = if ($_.recoveryEmail) { $_.recoveryEmail }     else { '' }
            RecoveryPhone    = if ($_.recoveryPhone) { $_.recoveryPhone }     else { '' }
            OrgUnit          = if ($_.orgUnitPath)   { $_.orgUnitPath }       else { '' }
            IsAdmin          = $_.isAdmin
            IsDelegatedAdmin = $_.isDelegatedAdmin
            Suspended        = $_.suspended
            Archived         = $_.archived
            Department       = if ($org)             { $org.department }      else { '' }
            JobTitle         = if ($org)             { $org.title }           else { '' }
            CostCenter       = if ($org)             { $org.costCenter }      else { '' }
            EmployeeId       = if ($employeeId)      { $employeeId }          else { '' }
            ManagerEmail     = if ($managerEmail)    { $managerEmail }        else { '' }
            Aliases          = $aliases
        }
    }
}

function Get-GlicTelemetry {
    [CmdletBinding()]
    param(
        [ValidateSet('all','active','deprovisioned','disabled')]
        [string]$Status = 'active',
        [string]$OrgUnit,
        [string]$Config,
        [string]$ServiceAccountPath
    )
    $ctx        = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath
    $reportDate = (Get-Date).ToString('yyyy-MM-dd')
    $telemetry  = @{}
    Invoke-GlicPagedRequest `
        -Uri     "https://chromemanagement.googleapis.com/v1/customers/$($ctx.CustomerId)/telemetry/devices" `
        -Headers $ctx.Headers `
        -Query   @{ readMask = 'name,device_id,serial_number,os_update_status'; pageSize = 100 } `
        -ItemsProperty 'devices' |
    ForEach-Object { if ($_.deviceId) { $telemetry[$_.deviceId] = $_ } }
    $dirUri   = "https://admin.googleapis.com/admin/directory/v1/customer/$($ctx.CustomerId)/devices/chromeos"
    $dirQuery = @{ projection = 'FULL'; maxResults = 200 }
    if ($Status -ne 'all') { $dirQuery['query'] = "status:$($Status.ToUpper())" }
    if ($OrgUnit) { $dirQuery['orgUnitPath'] = $OrgUnit }
    Invoke-GlicPagedRequest -Uri $dirUri -Headers $ctx.Headers -Query $dirQuery -ItemsProperty 'chromeosdevices' |
    ForEach-Object {
        $td  = if ($_.deviceId) { $telemetry[$_.deviceId] } else { $null }
        $ous = if ($td) { $td.osUpdateStatus } else { $null }
        [PSCustomObject]@{
            ReportDate            = $reportDate
            CustomerId            = $ctx.CustomerId
            DeviceId              = if ($_.deviceId)     { $_.deviceId }     else { '' }
            SerialNumber          = if ($_.serialNumber) { $_.serialNumber } else { '' }
            Model                 = if ($_.model)        { $_.model }        else { '' }
            Status                = if ($_.status)       { $_.status }       else { '' }
            OrgUnitPath           = if ($_.orgUnitPath)  { $_.orgUnitPath }  else { '' }
            OsVersion             = if ($_.osVersion)    { $_.osVersion }    else { '' }
            LastSyncUser          = if ($_.recentUsers)  { $_.recentUsers[0].email } else { '' }
            UpdateState           = if ($ous) { $ous.updateState }           else { '' }
            UpdateTargetOsVersion = if ($ous) { $ous.updateTargetOsVersion } else { '' }
            LastUpdateCheckTime   = if ($ous -and $ous.lastUpdateCheckTime) { [DateTimeOffset]::Parse($ous.lastUpdateCheckTime) } else { $null }
        }
    }
}

function Get-GlicHardware {
    [CmdletBinding()]
    param(
        [ValidateSet('all','active','deprovisioned','disabled')]
        [string]$Status = 'all',
        [string]$OrgUnit,
        [string]$Config,
        [string]$ServiceAccountPath
    )
    $ctx      = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath
    $readMask = 'name,device_id,serial_number,cpu_info,memory_info,battery_info,' +
                'battery_status_report,storage_info,storage_status_report,' +
                'network_info,graphics_info,os_update_status'
    $telemetry = @{}
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
        $ramGb          = if ($mem -and $mem.totalRamBytes)       { [int]([long]($mem.totalRamBytes) / 1GB) }          else { 0 }
        $storageAvailGb = if ($sto -and $sto.availableDiskBytes)  { [int]([long]($sto.availableDiskBytes[0]) / 1GB) }  else { 0 }
        $storageTotalGb = if ($sto -and $sto.totalStorageBytes)   { [int]([long]($sto.totalStorageBytes[0])  / 1GB) }  else { 0 }
        $batDesign      = if ($bat -and $bat.designCapacity)      { [int]$bat.designCapacity }     else { 0 }
        $batFull        = if ($bat -and $bat.fullChargeCapacity)  { [int]$bat.fullChargeCapacity } else { 0 }
        $lastSync       = if ($_.lastSync)           { [DateTimeOffset]::Parse($_.lastSync) }           else { $null }
        $enrollment     = if ($_.lastEnrollmentTime) { [DateTimeOffset]::Parse($_.lastEnrollmentTime) } else { $null }
        [PSCustomObject]@{
            ReportDate           = (Get-Date).ToString('yyyy-MM-dd')
            CustomerId           = $ctx.CustomerId
            DeviceId             = if ($_.deviceId)         { $_.deviceId }         else { '' }
            SerialNumber         = if ($_.serialNumber)     { $_.serialNumber }     else { '' }
            Model                = if ($_.model)            { $_.model }            else { '' }
            Status               = if ($_.status)           { $_.status }           else { '' }
            OrgUnitPath          = if ($_.orgUnitPath)      { $_.orgUnitPath }      else { '' }
            AnnotatedAssetId     = if ($_.annotatedAssetId) { $_.annotatedAssetId } else { '' }
            AnnotatedUser        = if ($_.annotatedUser)    { $_.annotatedUser }    else { '' }
            OsVersion            = if ($_.osVersion)        { $_.osVersion }        else { '' }
            LastSync             = $lastSync
            EnrollmentTime       = $enrollment
            CpuModel             = if ($cpu -and $cpu.model)        { $cpu.model }        else { '' }
            CpuArchitecture      = if ($cpu -and $cpu.architecture) { $cpu.architecture } else { '' }
            RamGb                = $ramGb
            StorageAvailableGb   = $storageAvailGb
            StorageTotalGb       = $storageTotalGb
            BatteryDesignMah     = $batDesign
            BatteryFullChargeMah = $batFull
            GpuName              = if ($gpu -and $gpu.name) { $gpu.name } else { '' }
        }
    }
}

function Get-GlicLicenses {
    [CmdletBinding()]
    param([string[]]$SkuIds, [string]$Config, [string]$ServiceAccountPath)
    $ctx        = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath
    $reportDate = (Get-Date).ToString('yyyy-MM-dd')
    $skuIdsFlag = if ($SkuIds) { $SkuIds -join ',' } else { $null }
    $skus       = Get-GlicSkuCatalog -SkuIds $skuIdsFlag
    $userMap    = @{}
    Invoke-GlicPagedRequest `
        -Uri     'https://admin.googleapis.com/admin/directory/v1/users' `
        -Headers $ctx.Headers `
        -Query   @{ customer = $ctx.CustomerId; maxResults = 500; projection = 'full' } `
        -ItemsProperty 'users' |
    ForEach-Object { if ($_.primaryEmail) { $userMap[$_.primaryEmail] = $_ } }
    foreach ($sku in $skus) {
        $uri   = "https://licensing.googleapis.com/apps/licensing/v1/product/$($sku.ProductId)/sku/$($sku.SkuId)/users"
        $query = @{ customerId = $ctx.CustomerId; maxResults = 1000 }
        try {
            $assignments = @(Invoke-GlicPagedRequest -Uri $uri -Headers $ctx.Headers -Query $query -ItemsProperty 'items')
        } catch {
            if ($_.Exception.Response.StatusCode.value__ -in @(400,403,404)) { continue }
            Write-Warning "Skipping $($sku.SkuId): $($_.Exception.Message)"
            continue
        }
        if ($assignments.Count -eq 0) {
            Write-Warning "SKU '$($sku.SkuName)' ($($sku.SkuId)) returned no individual assignments - skipped."
            continue
        }
        foreach ($a in $assignments) {
            $user      = if ($a.userId) { $userMap[$a.userId] } else { $null }
            $lastLogin = if ($user -and $user.lastLoginTime) { [DateTimeOffset]::Parse($user.lastLoginTime) } else { $null }
            [PSCustomObject]@{
                ReportDate       = $reportDate
                CustomerId       = $ctx.CustomerId
                UserEmail        = if ($a.userId)             { $a.userId }             else { '' }
                FullName         = if ($user -and $user.name) { $user.name.fullName }   else { '' }
                GivenName        = if ($user -and $user.name) { $user.name.givenName }  else { '' }
                FamilyName       = if ($user -and $user.name) { $user.name.familyName } else { '' }
                OrgUnit          = if ($user -and $user.orgUnitPath) { $user.orgUnitPath } else { '' }
                IsAdmin          = if ($user) { $user.isAdmin }   else { $null }
                Suspended        = if ($user) { $user.suspended } else { $null }
                LastLoginTime    = $lastLogin
                ProductId        = $sku.ProductId
                ProductName      = $sku.ProductName
                SkuId            = $sku.SkuId
                SkuName          = $sku.SkuName
                AssignmentStatus = 'ACTIVE'
            }
        }
    }
}

function Get-GlicManagedBrowsers {
    [CmdletBinding()]
    param([string]$OrgUnit, [string]$Config, [string]$ServiceAccountPath)
    $ctx        = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath
    $reportDate = (Get-Date).ToString('yyyy-MM-dd')
    $filter     = $null
    if ($OrgUnit) {
        $ouUri = "https://admin.googleapis.com/admin/directory/v1/customer/$($ctx.CustomerId)/orgunits/$([Uri]::EscapeDataString($OrgUnit.TrimStart('/')))"
        try {
            $ou     = Invoke-RestMethod -Uri $ouUri -Headers $ctx.Headers -ErrorAction Stop
            $filter = "org_unit_id = `"$($ou.orgUnitId)`""
        } catch {
            if ($_.Exception.Response.StatusCode.value__ -eq 404) { throw "Org unit not found: $OrgUnit" }
            throw
        }
    }
    $uri   = "https://chromemanagement.googleapis.com/v1/customers/$($ctx.CustomerId)/profiles"
    $query = @{ pageSize = 100 }
    if ($filter) { $query['filter'] = $filter }
    $results = @(Invoke-GlicPagedRequest -Uri $uri -Headers $ctx.Headers -Query $query -ItemsProperty 'customerProfiles')
    if ($filter -and $results.Count -eq 0) {
        Write-Warning "Org unit filter returned no results $([char]0x2014) retrying without filter"
        $results = @(Invoke-GlicPagedRequest -Uri $uri -Headers $ctx.Headers -Query @{ pageSize = 100 } -ItemsProperty 'customerProfiles')
    }
    $results | ForEach-Object {
        [PSCustomObject]@{
            ReportDate       = $reportDate
            CustomerId       = $ctx.CustomerId
            ProfileId        = if ($_.profileId)     { $_.profileId }                                  else { '' }
            DisplayName      = if ($_.displayName)   { $_.displayName }                                else { '' }
            AffiliatedUser   = if ($_.affiliatedUser){ $_.affiliatedUser.userEmail }                   else { '' }
            OrgUnitPath      = if ($_.orgUnitPath)   { $_.orgUnitPath }                                else { '' }
            BrowserVersion   = if ($_.browserVersion){ $_.browserVersion }                             else { '' }
            Os               = if ($_.osInfo)        { $_.osInfo.operatingSystem }                     else { '' }
            OsVersion        = if ($_.osInfo)        { $_.osInfo.osVersion }                           else { '' }
            LastActivityTime = if ($_.lastActivityTime) { [DateTimeOffset]::Parse($_.lastActivityTime) } else { $null }
        }
    }
}

function Get-GlicDeviceApps {
    [CmdletBinding()]
    param([string]$OrgUnit, [string]$Config, [string]$ServiceAccountPath)
    $ctx        = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath
    $reportDate = (Get-Date).ToString('yyyy-MM-dd')
    $orgUnitId  = $null
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
            DisplayName        = if ($_.displayName)        { $_.displayName }                  else { '' }
            AppType            = if ($_.appType)            { $_.appType }                      else { '' }
            BrowserDeviceCount = if ($_.browserDeviceCount) { [long]$_.browserDeviceCount }    else { 0L }
            OsUserCount        = if ($_.osUserCount)        { [long]$_.osUserCount }            else { 0L }
        }
    }
}

function Get-GlicBrowserExtensions {
    [CmdletBinding()]
    param([string]$OrgUnit, [string]$Config, [string]$ServiceAccountPath)
    $ctx        = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath
    $reportDate = (Get-Date).ToString('yyyy-MM-dd')
    $orgUnitId  = $null
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
        if ($_.appType -notin @('EXTENSION','THEME')) { return }
        [PSCustomObject]@{
            ReportDate         = $reportDate
            CustomerId         = $ctx.CustomerId
            AppId              = $_.appId
            DisplayName        = if ($_.displayName)        { $_.displayName }               else { '' }
            AppType            = if ($_.appType)            { $_.appType }                   else { '' }
            BrowserDeviceCount = if ($_.browserDeviceCount) { [long]$_.browserDeviceCount } else { 0L }
            OsUserCount        = if ($_.osUserCount)        { [long]$_.osUserCount }         else { 0L }
        }
    }
}

function Invoke-GlicDiscover {
    [CmdletBinding()]
    param([string]$Config, [string]$ServiceAccountPath)
    $ctx   = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath
    $skus  = Get-GlicSkuCatalog
    $found = @{}
    Write-Verbose 'Probing SKU catalog...'
    foreach ($sku in $skus) {
        $uri = "https://licensing.googleapis.com/apps/licensing/v1/product/$($sku.ProductId)/sku/$($sku.SkuId)/users"
        try {
            $resp = Invoke-RestMethod -Uri "${uri}?customerId=$($ctx.CustomerId)&maxResults=1" -Headers $ctx.Headers -ErrorAction Stop
            if ($resp.items -and $resp.items.Count -gt 0) { $found[$sku.SkuId] = $true }
        } catch {
            $code = $_.Exception.Response.StatusCode.value__
            if ($code -in @(400,403,404)) { continue }
            Write-Verbose "Warning - $($sku.SkuId): $($_.Exception.Message)"
        }
    }
    foreach ($sku in $skus) {
        [PSCustomObject]@{
            SkuId     = $sku.SkuId
            SkuName   = $sku.SkuName
            ProductId = $sku.ProductId
            WasActive = $sku.Active
            NowActive = $found.ContainsKey($sku.SkuId)
            Changed   = ($sku.Active -ne $found.ContainsKey($sku.SkuId))
        }
    }
    $merged    = $skus | ForEach-Object {
        [PSCustomObject]@{
            productId   = $_.ProductId
            productName = $_.ProductName
            skuId       = $_.SkuId
            skuName     = $_.SkuName
            active      = $found.ContainsKey($_.SkuId)
        }
    }
    $configDir = if ($env:GLIC_CONFIG) { $env:GLIC_CONFIG } else { $script:GlicModuleRoot }
    $null = New-Item -ItemType Directory -Path $configDir -Force -ErrorAction SilentlyContinue
    $merged | ConvertTo-Json | Set-Content (Join-Path $configDir 'skus.json') -Encoding UTF8
    Write-Verbose "skus.json written to $configDir"
}
