#Requires -Version 5.1
. "$PSScriptRoot\GLic-Runtime.ps1"

$ReportFile = "$PSScriptRoot\reports\devices.csv"
$LogFile    = "$PSScriptRoot\logs\Export-Devices.log"
$null = New-Item -ItemType Directory -Force "$PSScriptRoot\reports","$PSScriptRoot\logs"

try {
    Start-GlicLog $LogFile 'Export-Devices starting'
    Get-GlicDevices | Export-Csv $ReportFile -NoTypeInformation -Force
    $count = (Import-Csv $ReportFile | Measure-Object).Count
    Start-GlicLog $LogFile "Completed — $count rows"
    '' | Add-Content -LiteralPath $LogFile
}
catch {
    Start-GlicLog $LogFile "ERROR: $($_.Exception.Message)"
    '' | Add-Content -LiteralPath $LogFile
    exit 1
}
