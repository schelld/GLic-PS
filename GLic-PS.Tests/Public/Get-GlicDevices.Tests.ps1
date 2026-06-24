BeforeAll {
    . $PSScriptRoot/../../GLic-PS/Private/Invoke-GlicPagedRequest.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicContext.ps1
    . $PSScriptRoot/../../GLic-PS/Public/Get-GlicDevices.ps1
}

Describe 'Get-GlicDevices' {
    BeforeEach {
        Mock Get-GlicContext { [PSCustomObject]@{ CustomerId = 'C03test'; Headers = @{ Authorization = 'Bearer fake' } } }
        Mock Invoke-GlicPagedRequest {
            [PSCustomObject]@{
                deviceId            = 'dev-001'
                serialNumber        = 'SN12345'
                model               = 'HP Chromebook 14'
                status              = 'ACTIVE'
                orgUnitPath         = '/Test'
                annotatedUser       = 'user@example.com'
                recentUsers         = @([PSCustomObject]@{ email = 'user@example.com' })
                annotatedLocation   = 'Building A'
                lastSync              = '2026-01-15T10:00:00Z'
                lastEnrollmentTime    = '2025-06-01T08:00:00Z'
                osVersion           = '130.0.0.0'
                macAddress          = 'AA:BB:CC:DD:EE:FF'
                ethernetMacAddress  = $null
                lastKnownNetwork    = @([PSCustomObject]@{ ipAddress = '10.0.0.1' })
                annotatedAssetId    = 'ASSET-001'
                orderNumber         = @('ORD-123')
                platformVersion     = '15183.0.0'
                firmwareVersion     = '15183.0.0'
                bootMode            = 'Verified'
                notes               = ''
                meid                = ''
            }
        }
    }

    It 'returns a row with all 23 properties' {
        $row = Get-GlicDevices | Select-Object -First 1
        $row.DeviceId     | Should -Be 'dev-001'
        $row.SerialNumber | Should -Be 'SN12345'
        $row.Model        | Should -Be 'HP Chromebook 14'
        $row.LastSyncUser | Should -Be 'user@example.com'
        $row.OrderNumber  | Should -Be 'ORD-123'
        $row.LastSync     | Should -BeOfType [System.DateTimeOffset]
    }

    It 'passes status query param when -Status active is set' {
        Get-GlicDevices -Status active
        Should -Invoke Invoke-GlicPagedRequest -ParameterFilter {
            $Query['query'] -eq 'status:ACTIVE'
        }
    }

    It 'omits status query param when -Status all' {
        Get-GlicDevices -Status all
        Should -Invoke Invoke-GlicPagedRequest -ParameterFilter {
            -not $Query.ContainsKey('query')
        }
    }
}
