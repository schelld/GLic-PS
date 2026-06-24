# Copyright (c) 2026 D. Schell <schelld@live.com>
# https://github.com/schelld/GLIC-ps
#Requires -Version 5.1
. "$PSScriptRoot\GLic-Runtime.ps1"

$ReportFile = "$PSScriptRoot\reports\device-apps.csv"
$LogFile    = "$PSScriptRoot\logs\Export-DeviceApps.log"
$null = New-Item -ItemType Directory -Force "$PSScriptRoot\reports","$PSScriptRoot\logs"

try {
    Start-GlicLog $LogFile 'Export-DeviceApps starting'
    Get-GlicDeviceApps | Export-Csv $ReportFile -NoTypeInformation -Force
    $count = (Import-Csv $ReportFile | Measure-Object).Count
    Start-GlicLog $LogFile "Completed $([char]0x2014) $count rows"
    '' | Add-Content -LiteralPath $LogFile
}
catch {
    Start-GlicLog $LogFile "ERROR: $($_.Exception.Message)"
    '' | Add-Content -LiteralPath $LogFile
    exit 1
}
