function Get-GlicConfig {
    param([string]$Path)

    if ($script:GlicSession) { return $script:GlicSession.Config }

    if (-not $Path) { $Path = Resolve-GlicConfigPath 'glic.json' }
    if (-not $Path -or -not (Test-Path $Path)) {
        throw "glic.json not found. Run Connect-Glic first."
    }

    $json = Get-Content $Path -Raw | ConvertFrom-Json
    return [PSCustomObject]@{
        CustomerId = $json.customer_id
        AdminEmail = $json.admin_email
    }
}
