BeforeAll {
    . $PSScriptRoot/../../GLic-PS/Private/Invoke-GlicPagedRequest.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicContext.ps1
    . $PSScriptRoot/../../GLic-PS/Public/Get-GlicBrowserExtensions.ps1
}

Describe 'Get-GlicBrowserExtensions' {
    BeforeEach {
        Mock Get-GlicContext { [PSCustomObject]@{ CustomerId = 'C03test'; Headers = @{ Authorization = 'Bearer fake' } } }
        Mock Invoke-GlicPagedRequest {
            [PSCustomObject]@{ appId='ext-001'; displayName='My Ext'; appType='EXTENSION'; browserDeviceCount=3; osUserCount=2 }
            [PSCustomObject]@{ appId='app-001'; displayName='My App'; appType='BROWSER';   browserDeviceCount=5; osUserCount=4 }
        }
    }

    It 'filters to EXTENSION and THEME app types only' {
        $rows = @(Get-GlicBrowserExtensions)
        $rows | Should -HaveCount 1
        $rows[0].AppType | Should -Be 'EXTENSION'
    }
}
