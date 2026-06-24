BeforeAll {
    . $PSScriptRoot/../../GLic-PS/Private/Invoke-GlicPagedRequest.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicContext.ps1
    . $PSScriptRoot/../../GLic-PS/Public/Get-GlicApps.ps1
    $script:GlicSession = @{
        Config         = [PSCustomObject]@{ CustomerId = 'C03test'; AdminEmail = 'a@b.com' }
        ServiceAccount = [PSCustomObject]@{ client_email = 'sa@p.iam.gserviceaccount.com'; private_key = 'x' }
    }
    $script:_glicToken       = 'fake'
    $script:_glicTokenExpiry = (Get-Date).AddHours(1)
}

Describe 'Get-GlicApps' {
    BeforeEach {
        Mock Get-GlicContext {
            [PSCustomObject]@{ CustomerId = 'C03test'; Headers = @{ Authorization = 'Bearer fake' } }
        }
        Mock Invoke-GlicPagedRequest {
            [PSCustomObject]@{
                displayName        = 'Test App'
                appId              = 'test.app.id'
                appType            = 'BROWSER'
                browserDeviceCount = 7
            }
        }
    }

    It 'returns a row with all expected properties' {
        $rows = @(Get-GlicApps)
        $rows | Should -HaveCount 1
        $rows[0].DisplayName        | Should -Be 'Test App'
        $rows[0].AppId              | Should -Be 'test.app.id'
        $rows[0].AppType            | Should -Be 'BROWSER'
        $rows[0].BrowserDeviceCount | Should -Be 7
        $rows[0].ReportDate         | Should -Match '^\d{4}-\d{2}-\d{2}$'
        $rows[0].CustomerId         | Should -Be 'C03test'
    }

    It 'calls the Chrome Management reports endpoint' {
        Get-GlicApps
        Should -Invoke Invoke-GlicPagedRequest -ParameterFilter {
            $Uri -match 'chromemanagement\.googleapis\.com.*countInstalledApps'
        }
    }
}
