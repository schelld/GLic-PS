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
function Get-GlicApps {
    [PSCustomObject]@{ ReportDate='2026-01-01'; AppId='com.example'; DisplayName='Test App'; AppType='EXTENSION'; BrowserDeviceCount=5L }
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
function Get-GlicApps { throw 'Simulated failure' }
'@
}

Describe 'Export-Apps.ps1 — happy path' {
    BeforeAll {
        $script:Dir = Join-Path $TestDrive 'happy'
        $null = New-Item -ItemType Directory -Force $script:Dir
        Set-Content (Join-Path $script:Dir 'GLic-Runtime.ps1') $script:StubRuntime -Encoding UTF8
        Copy-Item "$PSScriptRoot\..\GLic-Scripts\Export-Apps.ps1" $script:Dir
        & $script:Ps -NonInteractive -File (Join-Path $script:Dir 'Export-Apps.ps1')
    }
    It 'exits 0' { $LASTEXITCODE | Should -Be 0 }
    It 'creates reports\apps.csv' { Test-Path (Join-Path $script:Dir 'reports\apps.csv') | Should -BeTrue }
    It 'log contains Completed' {
        Get-Content (Join-Path $script:Dir 'logs\Export-Apps.log') -Raw | Should -Match 'Completed'
    }
}

Describe 'Export-Apps.ps1 — error path' {
    BeforeAll {
        $script:Dir = Join-Path $TestDrive 'error'
        $null = New-Item -ItemType Directory -Force $script:Dir
        Set-Content (Join-Path $script:Dir 'GLic-Runtime.ps1') $script:ErrorRuntime -Encoding UTF8
        Copy-Item "$PSScriptRoot\..\GLic-Scripts\Export-Apps.ps1" $script:Dir
        & $script:Ps -NonInteractive -File (Join-Path $script:Dir 'Export-Apps.ps1')
    }
    It 'exits 1' { $LASTEXITCODE | Should -Be 1 }
    It 'log contains ERROR' {
        Get-Content (Join-Path $script:Dir 'logs\Export-Apps.log') -Raw | Should -Match 'ERROR'
    }
}
