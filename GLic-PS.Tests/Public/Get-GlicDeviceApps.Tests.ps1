BeforeAll {
    . $PSScriptRoot/../../GLic-PS/Private/Invoke-GlicPagedRequest.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicContext.ps1
    . $PSScriptRoot/../../GLic-PS/Public/Get-GlicDeviceApps.ps1
}

Describe 'Get-GlicDeviceApps' {
    BeforeEach {
        Mock Get-GlicContext { [PSCustomObject]@{ CustomerId = 'C03test'; Headers = @{ Authorization = 'Bearer fake' } } }
        Mock Invoke-GlicPagedRequest {
            [PSCustomObject]@{
                appId              = 'app.id.one'
                displayName        = 'My App'
                appType            = 'ANDROID'
                browserDeviceCount = 12
                osUserCount        = 5
            }
        }
    }

    It 'returns a row with DeviceApp fields' {
        $row = Get-GlicDeviceApps | Select-Object -First 1
        $row.AppId              | Should -Be 'app.id.one'
        $row.DisplayName        | Should -Be 'My App'
        $row.BrowserDeviceCount | Should -Be 12
        $row.OsUserCount        | Should -Be 5
    }

    It 'skips rows with null appId' {
        Mock Invoke-GlicPagedRequest {
            [PSCustomObject]@{ appId = $null; displayName = 'No ID'; appType = 'BROWSER'; browserDeviceCount = 1; osUserCount = 0 }
            [PSCustomObject]@{ appId = 'real.id'; displayName = 'Real'; appType = 'BROWSER'; browserDeviceCount = 1; osUserCount = 0 }
        }
        $rows = @(Get-GlicDeviceApps)
        $rows | Should -HaveCount 1
        $rows[0].AppId | Should -Be 'real.id'
    }
}
