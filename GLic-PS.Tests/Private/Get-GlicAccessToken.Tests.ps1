BeforeAll {
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicAccessToken.ps1

    # Set module-scope scopes (normally declared in GLic.psm1)
    $script:GlicScopes = @(
        'https://www.googleapis.com/auth/chrome.management.reports.readonly'
        'https://www.googleapis.com/auth/chrome.management.telemetry.readonly'
        'https://www.googleapis.com/auth/chrome.management.profiles.readonly'
        'https://www.googleapis.com/auth/admin.directory.customer.readonly'
        'https://www.googleapis.com/auth/admin.directory.device.chromeos.readonly'
        'https://www.googleapis.com/auth/admin.directory.user.readonly'
        'https://www.googleapis.com/auth/admin.directory.orgunit.readonly'
        'https://www.googleapis.com/auth/apps.licensing'
    )

    # Generate a real RSA key for signing (no network; key is ephemeral)
    $cngParams = New-Object Security.Cryptography.CngKeyCreationParameters
    $cngParams.ExportPolicy = [Security.Cryptography.CngExportPolicies]::AllowPlaintextExport
    $cngKey    = [Security.Cryptography.CngKey]::Create([Security.Cryptography.CngAlgorithm]::Rsa, $null, $cngParams)
    $rsaExport = New-Object Security.Cryptography.RSACng $cngKey
    $keyDer    = $cngKey.Export([Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob)
    $b64       = [Convert]::ToBase64String($keyDer)
    $script:TestSA = [PSCustomObject]@{
        client_email = 'test@project.iam.gserviceaccount.com'
        private_key  = "-----BEGIN PRIVATE KEY-----`n$b64`n-----END PRIVATE KEY-----"
    }
    $script:_glicToken       = $null
    $script:_glicTokenExpiry = [datetime]::MinValue
}

Describe 'Get-GlicAccessToken' {
    BeforeEach {
        $script:_glicToken       = $null
        $script:_glicTokenExpiry = [datetime]::MinValue
        Mock Invoke-RestMethod { [PSCustomObject]@{ access_token = 'test-access-token'; expires_in = 3600 } }
    }

    It 'returns the access_token from the token endpoint response' {
        $tok = Get-GlicAccessToken -AdminEmail 'admin@example.com' -ServiceAccount $script:TestSA
        $tok | Should -Be 'test-access-token'
    }

    It 'calls the token endpoint exactly once' {
        Get-GlicAccessToken -AdminEmail 'admin@example.com' -ServiceAccount $script:TestSA
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Uri -eq 'https://oauth2.googleapis.com/token'
        }
    }

    It 'reuses cached token on second call' {
        Get-GlicAccessToken -AdminEmail 'admin@example.com' -ServiceAccount $script:TestSA
        Get-GlicAccessToken -AdminEmail 'admin@example.com' -ServiceAccount $script:TestSA
        Should -Invoke Invoke-RestMethod -Times 1
    }

    It 'refreshes when cache is expired' {
        $script:_glicToken       = 'old-token'
        $script:_glicTokenExpiry = (Get-Date).AddMinutes(-1)
        $tok = Get-GlicAccessToken -AdminEmail 'admin@example.com' -ServiceAccount $script:TestSA
        $tok | Should -Be 'test-access-token'
        Should -Invoke Invoke-RestMethod -Times 1
    }
}
