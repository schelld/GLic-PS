BeforeAll {
    . $PSScriptRoot/../../GLic-PS/Private/Invoke-GlicPagedRequest.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicContext.ps1
    . $PSScriptRoot/../../GLic-PS/Public/Get-GlicHardware.ps1
}

Describe 'Get-GlicHardware' {
    BeforeEach {
        Mock Get-GlicContext { [PSCustomObject]@{ CustomerId = 'C03test'; Headers = @{ Authorization = 'Bearer fake' } } }
        $script:HwCallCount = 0
        Mock Invoke-GlicPagedRequest {
            $script:HwCallCount++
            if ($script:HwCallCount -eq 1) {
                [PSCustomObject]@{
                    deviceId   = 'dev-hw-001'
                    memoryInfo = [PSCustomObject]@{ totalRamBytes = '8589934592' }  # 8 GB
                    cpuInfo    = @([PSCustomObject]@{ model = 'Intel Core i5'; architecture = 'X86_64' })
                    storageInfo = [PSCustomObject]@{
                        availableDiskBytes = @('107374182400')
                        totalStorageBytes  = @('128849018880')
                    }
                    batteryInfo = @([PSCustomObject]@{ designCapacity = '45000'; fullChargeCapacity = '42000' })
                    graphicsInfo = [PSCustomObject]@{ adapterInfo = @([PSCustomObject]@{ name = 'Intel UHD' }) }
                }
            } else {
                [PSCustomObject]@{
                    deviceId     = 'dev-hw-001'
                    serialNumber = 'HWSN001'
                    model        = 'Dell Chromebook 3110'
                    status       = 'ACTIVE'
                    orgUnitPath  = '/IT'
                    osVersion    = '130.0.0.0'
                    annotatedAssetId = 'ASSET-HW-001'
                }
            }
        }
    }

    It 'returns a row with hardware fields including RAM and CPU' {
        $row = Get-GlicHardware | Select-Object -First 1
        $row.DeviceId    | Should -Be 'dev-hw-001'
        $row.RamGb       | Should -Be 8
        $row.CpuModel    | Should -Be 'Intel Core i5'
    }
}
