#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

BeforeAll {
    . "$PSScriptRoot\..\GLic-Scripts\GLic-Runtime.ps1"
}

Describe 'GLic-Runtime.ps1 — function surface' {
    $expectedFunctions = @(
        'Start-GlicLog','Resolve-GlicConfigPath','Get-GlicConfig',
        'Get-GlicServiceAccount','Get-GlicAccessToken','Get-GlicContext',
        'Invoke-GlicPagedRequest','Get-GlicSkuCatalog','Get-GlicDevices',
        'Get-GlicApps','Get-GlicUsers','Get-GlicTelemetry','Get-GlicHardware',
        'Get-GlicLicenses','Get-GlicManagedBrowsers','Get-GlicDeviceApps',
        'Get-GlicBrowserExtensions','Invoke-GlicDiscover'
    )
    It 'defines <_>' -ForEach $expectedFunctions {
        Get-Command -Name $_ -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'does NOT define Connect-Glic' {
        Get-Command -Name 'Connect-Glic' -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }
}

Describe 'Start-GlicLog' {
    It 'writes a UTC-timestamped line to the log file' {
        $logFile = Join-Path $TestDrive 'test.log'
        Start-GlicLog $logFile 'hello world'
        $content = Get-Content $logFile -Raw
        $content | Should -Match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}Z  hello world'
    }

    It 'creates parent directory if it does not exist' {
        $logFile = Join-Path $TestDrive 'subdir\nested\test.log'
        Start-GlicLog $logFile 'msg'
        Test-Path $logFile | Should -BeTrue
    }

    It 'appends to an existing log file' {
        $logFile = Join-Path $TestDrive 'append.log'
        Start-GlicLog $logFile 'first'
        Start-GlicLog $logFile 'second'
        $lines = Get-Content $logFile
        $lines.Count | Should -Be 2
        $lines[0] | Should -Match 'first'
        $lines[1] | Should -Match 'second'
    }
}
