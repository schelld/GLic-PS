function Get-GlicContext {
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        [string]$ServiceAccountPath
    )

    $cfg = Get-GlicConfig         -Path $ConfigPath
    $sa  = Get-GlicServiceAccount -Path $ServiceAccountPath
    $tok = Get-GlicAccessToken    -AdminEmail $cfg.AdminEmail -ServiceAccount $sa

    return [PSCustomObject]@{
        CustomerId = $cfg.CustomerId
        Headers    = @{ Authorization = "Bearer $tok" }
    }
}
