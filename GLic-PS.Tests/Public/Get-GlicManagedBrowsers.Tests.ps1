BeforeAll {
    . $PSScriptRoot/../../GLic-PS/Private/Invoke-GlicPagedRequest.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicContext.ps1
    . $PSScriptRoot/../../GLic-PS/Public/Get-GlicManagedBrowsers.ps1
}

Describe 'Get-GlicManagedBrowsers' {
    BeforeEach {
        Mock Get-GlicContext { [PSCustomObject]@{ CustomerId = 'C03test'; Headers = @{ Authorization = 'Bearer fake' } } }
        Mock Invoke-GlicPagedRequest {
            [PSCustomObject]@{
                name          = 'customers/C03test/profiles/prof-001'
                profileId     = 'prof-001'
                displayName   = 'Jane Doe'
                osInfo        = [PSCustomObject]@{ operatingSystem = 'ChromeOS'; osVersion = '130.0.0.0' }
                browserVersion = '130.0.6723.58'
                lastActivityTime = '2026-06-01T00:00:00Z'
                affiliatedUser  = [PSCustomObject]@{ userEmail = 'jane@example.com' }
                orgUnitPath     = '/Engineering'
            }
        }
    }

    It 'returns a row with expected profile properties' {
        $row = Get-GlicManagedBrowsers | Select-Object -First 1
        $row.ProfileId      | Should -Be 'prof-001'
        $row.AffiliatedUser | Should -Be 'jane@example.com'
        $row.OsVersion      | Should -Be '130.0.0.0'
    }

    It 'resolves OrgUnit ID when -OrgUnit is specified' {
        Mock Invoke-RestMethod { [PSCustomObject]@{ orgUnitId = 'id:abc123' } }
        Get-GlicManagedBrowsers -OrgUnit '/Engineering'
        Should -Invoke Invoke-RestMethod -ParameterFilter { $Uri -match 'orgunits' }
    }
}
