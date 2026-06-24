BeforeAll {
    . $PSScriptRoot/../../GLic-PS/Private/Invoke-GlicPagedRequest.ps1
}

Describe 'Invoke-GlicPagedRequest' {
    It 'yields items from a single-page response' {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ items = @('a','b','c'); nextPageToken = $null }
        }
        $result = @(Invoke-GlicPagedRequest -Uri 'https://example.com/api' -Headers @{} -ItemsProperty 'items')
        $result | Should -HaveCount 3
        $result[0] | Should -Be 'a'
    }

    It 'follows nextPageToken across two pages' {
        $script:callCount = 0
        Mock Invoke-RestMethod {
            $script:callCount++
            if ($script:callCount -eq 1) {
                [PSCustomObject]@{ items = @('a'); nextPageToken = 'tok2' }
            } else {
                [PSCustomObject]@{ items = @('b'); nextPageToken = $null }
            }
        }
        $result = @(Invoke-GlicPagedRequest -Uri 'https://example.com/api' -Headers @{} -ItemsProperty 'items')
        $result | Should -HaveCount 2
        Should -Invoke Invoke-RestMethod -Times 2
    }

    It 'passes query params in the URL' {
        Mock Invoke-RestMethod { [PSCustomObject]@{ items = @(); nextPageToken = $null } }
        Invoke-GlicPagedRequest -Uri 'https://example.com/api' -Headers @{} `
            -Query @{ pageSize = 100; projection = 'FULL' } -ItemsProperty 'items'
        Should -Invoke Invoke-RestMethod -ParameterFilter {
            $Uri -match 'pageSize=100' -and $Uri -match 'projection=FULL'
        }
    }
}
