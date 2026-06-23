function Get-GlicServiceAccount {
    param([string]$Path)

    if ($script:GlicSession) { return $script:GlicSession.ServiceAccount }

    if (-not $Path) { $Path = Resolve-GlicConfigPath 'service-account.json' }

    if ($Path -and (Test-Path $Path)) {
        $raw = Get-Content $Path -Raw
        # Strip UTF-8 BOM if present
        if ($raw.Length -gt 0 -and [int][char]$raw[0] -eq 0xFEFF) { $raw = $raw.Substring(1) }
        return $raw | ConvertFrom-Json
    }

    # Fall back to SecretStore vault
    try {
        $json = Get-Secret -Name 'GlicServiceAccountKey' -Vault 'GlicVault' -AsPlainText -ErrorAction Stop
        return $json | ConvertFrom-Json
    } catch {
        throw "No service account credential found at '$Path'. Run Connect-Glic -KeyPath <path-to-service-account.json>."
    }
}
