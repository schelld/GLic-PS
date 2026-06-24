function Connect-Glic {
    [CmdletBinding()]
    param(
        [string]$AdminEmail,
        [string]$ServiceAccountPath,
        [string]$KeyPath,
        [switch]$Force
    )

    if ($script:GlicSession -and -not $Force -and -not $KeyPath) { return }

    # Store key in vault if -KeyPath supplied
    if ($KeyPath) {
        if (-not (Test-Path $KeyPath)) { throw "File not found: $KeyPath" }
        $raw    = Get-Content $KeyPath -Raw
        $parsed = $raw | ConvertFrom-Json
        if ($parsed.type -ne 'service_account') {
            throw "'$KeyPath' is not a service account key - expected ""type"": ""service_account""."
        }
        _Set-GlicVaultSecret 'GlicServiceAccountKey'   $raw
        _Set-GlicVaultSecret 'GlicServiceAccountEmail' $parsed.client_email
        Write-Host "Credential stored in GlicVault ($($parsed.client_email))."
    }

    if (-not $AdminEmail) {
        $AdminEmail = Read-Host 'Admin email (e.g. admin@domain.com)'
    }
    if (-not $AdminEmail) { throw 'Admin email is required.' }

    $sa  = Get-GlicServiceAccount -Path $ServiceAccountPath
    $tok = Get-GlicAccessToken    -AdminEmail $AdminEmail -ServiceAccount $sa

    Write-Host 'Connecting to Google Workspace...'
    $headers  = @{ Authorization = "Bearer $tok" }
    $customer = Invoke-RestMethod -Uri 'https://admin.googleapis.com/admin/directory/v1/customers/my_customer' -Headers $headers
    $customerId = $customer.id
    if (-not $customerId) {
        throw 'customers.get returned no customer ID. Verify admin_email has Workspace admin rights.'
    }

    $configDir = Join-Path $env:APPDATA 'GLic'
    $null = New-Item -ItemType Directory -Path $configDir -Force
    [PSCustomObject]@{ customer_id = $customerId; admin_email = $AdminEmail } |
        ConvertTo-Json | Set-Content (Join-Path $configDir 'glic.json') -Encoding UTF8

    $script:GlicSession = @{
        Config         = [PSCustomObject]@{ CustomerId = $customerId; AdminEmail = $AdminEmail }
        ServiceAccount = $sa
    }
    Write-Host "Connected: $AdminEmail ($customerId)"
}

function _Set-GlicVaultSecret {
    param([string]$Name, [string]$Value)
    foreach ($mod in @('Microsoft.PowerShell.SecretManagement','Microsoft.PowerShell.SecretStore')) {
        if (-not (Get-Module $mod -ListAvailable -ErrorAction SilentlyContinue)) {
            throw "Required module '$mod' is not installed. Run: Install-Module $mod -Scope CurrentUser."
        }
    }
    if (-not (Get-SecretVault -Name 'GlicVault' -ErrorAction SilentlyContinue)) {
        Set-SecretStoreConfiguration -Scope CurrentUser -Authentication None -Interaction None -Confirm:$false -ErrorAction Stop
        Register-SecretVault -Name 'GlicVault' -ModuleName 'Microsoft.PowerShell.SecretStore' -ErrorAction Stop
    }
    Set-Secret -Name $Name -Secret $Value -Vault 'GlicVault' -ErrorAction Stop
}
