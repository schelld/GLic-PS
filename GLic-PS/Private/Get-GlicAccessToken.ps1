function Get-GlicAccessToken {
    [CmdletBinding()]
    param(
        [string]$AdminEmail,
        [psobject]$ServiceAccount   # parsed service-account.json (client_email + private_key)
    )

    # Return cached token if still valid (expires in > 2 min)
    if ($script:_glicToken -and $script:_glicTokenExpiry -gt (Get-Date).AddMinutes(2)) {
        return $script:_glicToken
    }

    $iat = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $exp = $iat + 3600

    # --- Build JWT header (base64url) ---
    $headerB64 = [Convert]::ToBase64String(
        [Text.Encoding]::UTF8.GetBytes('{"alg":"RS256","typ":"JWT"}')
    ) -replace '\+','-' -replace '/','_' -replace '='

    # --- Build JWT payload (base64url) ---
    $payload = [ordered]@{
        iss   = $ServiceAccount.client_email
        sub   = $AdminEmail
        scope = ($script:GlicScopes -join ' ')
        aud   = 'https://oauth2.googleapis.com/token'
        iat   = $iat
        exp   = $exp
    }
    $payloadB64 = [Convert]::ToBase64String(
        [Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Compress))
    ) -replace '\+','-' -replace '/','_' -replace '='

    $signingInput = "${headerB64}.${payloadB64}"

    # --- Import RSA private key (PKCS8 PEM) via CNG ---
    # Works on PS 5.1/.NET 4.7.2 and PS 7+/.NET 6+ on Windows.
    $pemBody  = $ServiceAccount.private_key -replace '-----[^-]+-----' -replace '\s'
    $keyBytes = [Convert]::FromBase64String($pemBody)
    $cngKey   = [Security.Cryptography.CngKey]::Import(
        $keyBytes, [Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob)
    $rsa = New-Object Security.Cryptography.RSACng $cngKey

    # --- Sign RS256 ---
    $inputBytes = [Text.Encoding]::UTF8.GetBytes($signingInput)
    $sigBytes   = $rsa.SignData(
        $inputBytes,
        [Security.Cryptography.HashAlgorithmName]::SHA256,
        [Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $sigB64 = [Convert]::ToBase64String($sigBytes) -replace '\+','-' -replace '/','_' -replace '='

    $jwt = "${signingInput}.${sigB64}"

    # --- Exchange JWT for access token ---
    $body     = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=$jwt"
    $response = Invoke-RestMethod -Method Post `
        -Uri 'https://oauth2.googleapis.com/token' `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body $body

    $script:_glicToken       = $response.access_token
    $script:_glicTokenExpiry = (Get-Date).AddSeconds($response.expires_in - 120)

    return $script:_glicToken
}
