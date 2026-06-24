BeforeAll {
    . $PSScriptRoot/../../GLic-PS/Private/Resolve-GlicConfigPath.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Invoke-GlicPagedRequest.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicContext.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicSkuCatalog.ps1
    . $PSScriptRoot/../../GLic-PS/Public/Get-GlicLicenses.ps1
    $script:GlicModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:GlicSession    = $null
}

Describe 'Get-GlicLicenses' {
    BeforeEach {
        Mock Get-GlicContext { [PSCustomObject]@{ CustomerId = 'C03test'; Headers = @{ Authorization = 'Bearer fake' } } }
        Mock Get-GlicSkuCatalog {
            @([PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Workspace'; SkuId='1010020026'; SkuName='Business Starter'; Active=$true })
        }
        $script:LicCallCount = 0
        Mock Invoke-GlicPagedRequest {
            $script:LicCallCount++
            if ($script:LicCallCount -eq 1) {
                # users call
                [PSCustomObject]@{ primaryEmail='jane@example.com'; name=[PSCustomObject]@{fullName='Jane Doe';givenName='Jane';familyName='Doe'}; orgUnitPath='/Eng'; isAdmin=$false; suspended=$false; lastLoginTime='2026-06-01T00:00:00Z' }
            } else {
                # license assignment call
                [PSCustomObject]@{ userId = 'jane@example.com'; productId = 'Google-Apps'; skuId = '1010020026' }
            }
        }
    }

    It 'returns a license row with user and SKU details merged' {
        $row = Get-GlicLicenses | Select-Object -First 1
        $row.UserEmail   | Should -Be 'jane@example.com'
        $row.FullName    | Should -Be 'Jane Doe'
        $row.SkuName     | Should -Be 'Business Starter'
        $row.ProductName | Should -Be 'Workspace'
    }
}
