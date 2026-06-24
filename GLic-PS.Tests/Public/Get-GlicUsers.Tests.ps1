BeforeAll {
    . $PSScriptRoot/../../GLic-PS/Private/Invoke-GlicPagedRequest.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicContext.ps1
    . $PSScriptRoot/../../GLic-PS/Public/Get-GlicUsers.ps1
}

Describe 'Get-GlicUsers' {
    BeforeEach {
        Mock Get-GlicContext { [PSCustomObject]@{ CustomerId = 'C03test'; Headers = @{ Authorization = 'Bearer fake' } } }
        $script:FakeUser = [PSCustomObject]@{
            primaryEmail    = 'jane@example.com'
            name            = [PSCustomObject]@{ fullName = 'Jane Doe'; givenName = 'Jane'; familyName = 'Doe' }
            creationTimeRaw = '2024-01-01T00:00:00Z'
            lastLoginTimeRaw = '2026-06-01T00:00:00Z'
            isEnrolledIn2Sv = $true
            isEnforcedIn2Sv = $false
            recoveryEmail   = 'jane.recovery@example.com'
            recoveryPhone   = $null
            orgUnitPath     = '/Engineering'
            isAdmin         = $false
            isDelegatedAdmin = $false
            suspended       = $false
            archived        = $false
            organizations   = @([PSCustomObject]@{ primary=$true; department='Eng'; title='SWE'; costCenter='CC01' })
            relations       = @([PSCustomObject]@{ type='manager'; value='boss@example.com' })
            externalIds     = @([PSCustomObject]@{ type='organization'; value='EMP001' })
            aliases         = @('jane.doe@example.com')
        }
        Mock Invoke-GlicPagedRequest { $script:FakeUser }
    }

    It 'maps all user fields correctly' {
        $row = Get-GlicUsers | Select-Object -First 1
        $row.PrimaryEmail  | Should -Be 'jane@example.com'
        $row.FullName      | Should -Be 'Jane Doe'
        $row.Department    | Should -Be 'Eng'
        $row.JobTitle      | Should -Be 'SWE'
        $row.ManagerEmail  | Should -Be 'boss@example.com'
        $row.EmployeeId    | Should -Be 'EMP001'
        $row.Aliases       | Should -Be 'jane.doe@example.com'
    }

    It 'filters out suspended users by default' {
        # Create an active user and a suspended user
        $active = $script:FakeUser
        $suspended = [PSCustomObject]@{
            primaryEmail    = 'bob@example.com'
            name            = [PSCustomObject]@{ fullName = 'Bob Smith'; givenName = 'Bob'; familyName = 'Smith' }
            creationTimeRaw = '2024-01-01T00:00:00Z'
            lastLoginTimeRaw = '2026-06-01T00:00:00Z'
            isEnrolledIn2Sv = $true
            isEnforcedIn2Sv = $false
            recoveryEmail   = 'bob.recovery@example.com'
            recoveryPhone   = $null
            orgUnitPath     = '/Engineering'
            isAdmin         = $false
            isDelegatedAdmin = $false
            suspended       = $true
            archived        = $false
            organizations   = @([PSCustomObject]@{ primary=$true; department='Eng'; title='SWE'; costCenter='CC01' })
            relations       = @([PSCustomObject]@{ type='manager'; value='boss@example.com' })
            externalIds     = @([PSCustomObject]@{ type='organization'; value='EMP002' })
            aliases         = @('bob.smith@example.com')
        }
        Mock Invoke-GlicPagedRequest { $active; $suspended }
        $rows = @(Get-GlicUsers)
        $rows | Where-Object { $_.Suspended -eq $true } | Should -HaveCount 0
    }
}
