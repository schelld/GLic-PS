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
function Get-GlicHardware {
    [PSCustomObject]@{ ReportDate='2026-01-01'; DeviceId='d1'; SerialNumber='S1'; Model='CB'; RamGb=8; StorageTotalGb=64 }
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
function Get-GlicHardware { throw 'Simulated failure' }
'@
}

Describe 'Export-Hardware.ps1 — happy path' {
    BeforeAll {
        $script:Dir = Join-Path $TestDrive 'happy'
        $null = New-Item -ItemType Directory -Force $script:Dir
        Set-Content (Join-Path $script:Dir 'GLic-Runtime.ps1') $script:StubRuntime -Encoding UTF8
        Copy-Item "$PSScriptRoot\..\GLic-Scripts\Export-Hardware.ps1" $script:Dir
        & $script:Ps -NonInteractive -File (Join-Path $script:Dir 'Export-Hardware.ps1')
    }
    It 'exits 0' { $LASTEXITCODE | Should -Be 0 }
    It 'creates reports\hardware.csv' { Test-Path (Join-Path $script:Dir 'reports\hardware.csv') | Should -BeTrue }
    It 'log contains Completed' {
        Get-Content (Join-Path $script:Dir 'logs\Export-Hardware.log') -Raw | Should -Match 'Completed'
    }
}

Describe 'Export-Hardware.ps1 — error path' {
    BeforeAll {
        $script:Dir = Join-Path $TestDrive 'error'
        $null = New-Item -ItemType Directory -Force $script:Dir
        Set-Content (Join-Path $script:Dir 'GLic-Runtime.ps1') $script:ErrorRuntime -Encoding UTF8
        Copy-Item "$PSScriptRoot\..\GLic-Scripts\Export-Hardware.ps1" $script:Dir
        & $script:Ps -NonInteractive -File (Join-Path $script:Dir 'Export-Hardware.ps1')
    }
    It 'exits 1' { $LASTEXITCODE | Should -Be 1 }
    It 'log contains ERROR' {
        Get-Content (Join-Path $script:Dir 'logs\Export-Hardware.log') -Raw | Should -Match 'ERROR'
    }
}
