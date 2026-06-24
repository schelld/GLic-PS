#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

BeforeAll {
    $script:Ps = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }

    $script:StubRuntime = @'
$script:GlicModuleRoot   = $PSScriptRoot
$script:GlicSession      = $null
$script:_glicToken       = $null
$script:_glicTokenExpiry = [datetime]::MinValue
$script:GlicScopes       = @()
function Start-GlicLog {
    param([string]$Path,[string]$Message)
    $null = New-Item -ItemType Directory -Force (Split-Path $Path) -ErrorAction SilentlyContinue
    "$([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss'))Z  $Message" | Add-Content -LiteralPath $Path
}
function Get-GlicDevices {
    [PSCustomObject]@{ ReportDate='2026-01-01'; DeviceId='d1'; SerialNumber='S1'; Model='CB'; Status='ACTIVE' }
}
'@

    $script:ErrorRuntime = @'
$script:GlicModuleRoot   = $PSScriptRoot
$script:GlicSession      = $null
$script:_glicToken       = $null
$script:_glicTokenExpiry = [datetime]::MinValue
$script:GlicScopes       = @()
function Start-GlicLog {
    param([string]$Path,[string]$Message)
    $null = New-Item -ItemType Directory -Force (Split-Path $Path) -ErrorAction SilentlyContinue
    "$([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss'))Z  $Message" | Add-Content -LiteralPath $Path
}
function Get-GlicDevices { throw 'Simulated failure' }
'@
}

Describe 'Export-Devices.ps1 — happy path' {
    BeforeAll {
        $script:Dir = Join-Path $TestDrive 'happy'
        $null = New-Item -ItemType Directory -Force $script:Dir
        Set-Content (Join-Path $script:Dir 'GLic-Runtime.ps1') $script:StubRuntime -Encoding UTF8
        Copy-Item "$PSScriptRoot\..\GLic-Scripts\Export-Devices.ps1" $script:Dir
        & $script:Ps -NonInteractive -File (Join-Path $script:Dir 'Export-Devices.ps1')
    }

    It 'exits 0' { $LASTEXITCODE | Should -Be 0 }
    It 'creates reports\devices.csv' { Test-Path (Join-Path $script:Dir 'reports\devices.csv') | Should -BeTrue }
    It 'creates logs\Export-Devices.log' { Test-Path (Join-Path $script:Dir 'logs\Export-Devices.log') | Should -BeTrue }
    It 'log contains Completed' {
        Get-Content (Join-Path $script:Dir 'logs\Export-Devices.log') -Raw | Should -Match 'Completed'
    }
}

Describe 'Export-Devices.ps1 — error path' {
    BeforeAll {
        $script:Dir = Join-Path $TestDrive 'error'
        $null = New-Item -ItemType Directory -Force $script:Dir
        Set-Content (Join-Path $script:Dir 'GLic-Runtime.ps1') $script:ErrorRuntime -Encoding UTF8
        Copy-Item "$PSScriptRoot\..\GLic-Scripts\Export-Devices.ps1" $script:Dir
        & $script:Ps -NonInteractive -File (Join-Path $script:Dir 'Export-Devices.ps1')
    }

    It 'exits 1' { $LASTEXITCODE | Should -Be 1 }
    It 'log contains ERROR' {
        Get-Content (Join-Path $script:Dir 'logs\Export-Devices.log') -Raw | Should -Match 'ERROR'
    }
}
