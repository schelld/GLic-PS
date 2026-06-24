BeforeAll {
    . $PSScriptRoot/../../GLic-PS/Private/Invoke-GlicPagedRequest.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicContext.ps1
    . $PSScriptRoot/../../GLic-PS/Public/Get-GlicTelemetry.ps1
}

Describe 'Get-GlicTelemetry' {
    BeforeEach {
        Mock Get-GlicContext { [PSCustomObject]@{ CustomerId = 'C03test'; Headers = @{ Authorization = 'Bearer fake' } } }

        # Paginator returns telemetry rows on first two calls, directory rows on the next two
        $script:InvokeCount = 0
        Mock Invoke-GlicPagedRequest {
            $script:InvokeCount++
            if ($script:InvokeCount -eq 1) {
                # telemetry call
                [PSCustomObject]@{
                    deviceId       = 'dev-001'
                    serialNumber   = 'SN001'
                    osUpdateStatus = [PSCustomObject]@{
                        updateState           = 'OS_UP_TO_DATE'
                        updateTargetOsVersion = '130.0.6723.58'
                        lastUpdateCheckTime   = '2026-06-01T00:00:00Z'
                    }
                }
            } else {
                # directory call
                [PSCustomObject]@{
                    deviceId      = 'dev-001'
                    serialNumber  = 'SN001'
                    model         = 'HP 14'
                    status        = 'ACTIVE'
                    orgUnitPath   = '/Test'
                    osVersion     = '130.0.6723.58'
                    recentUsers   = @([PSCustomObject]@{ email = 'u@x.com' })
                }
            }
        }
    }

    It 'merges telemetry UpdateState into the output row' {
        $row = Get-GlicTelemetry | Select-Object -First 1
        $row.DeviceId    | Should -Be 'dev-001'
        $row.UpdateState | Should -Be 'OS_UP_TO_DATE'
    }
}
