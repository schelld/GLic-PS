BeforeAll {
    . $PSScriptRoot/../../GLic-PS/Private/Resolve-GlicConfigPath.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Invoke-GlicPagedRequest.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicContext.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicSkuCatalog.ps1
    . $PSScriptRoot/../../GLic-PS/Public/Invoke-GlicDiscover.ps1
    $script:GlicModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:GlicSession    = $null
}

Describe 'Invoke-GlicDiscover' {
    BeforeEach {
        Mock Get-GlicContext { [PSCustomObject]@{ CustomerId = 'C03test'; Headers = @{ Authorization = 'Bearer fake' } } }
        Mock Get-GlicSkuCatalog {
            @(
                [PSCustomObject]@{ ProductId='P1'; ProductName='Prod1'; SkuId='SKU-FOUND';   SkuName='Found';   Active=$true }
                [PSCustomObject]@{ ProductId='P1'; ProductName='Prod1'; SkuId='SKU-MISSING'; SkuName='Missing'; Active=$true }
            )
        }
        Mock Invoke-RestMethod {
            if ($Uri -match 'SKU-FOUND')   { [PSCustomObject]@{ items = @([PSCustomObject]@{ userId='u@x.com' }) } }
            else                           { throw [System.Net.WebException]::new('Not Found') }
        }
        Mock Set-Content { }
        Mock New-Item { }
    }

    It 'emits a DiscoverChangeRow for each probed SKU' {
        $rows = @(Invoke-GlicDiscover)
        $rows | Should -Not -BeNullOrEmpty
    }

    It 'writes skus.json to %APPDATA%\GLic' {
        Invoke-GlicDiscover | Out-Null
        Should -Invoke Set-Content -ParameterFilter { $Path -match 'GLic.*skus\.json' }
    }
}
