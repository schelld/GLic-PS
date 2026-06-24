function Invoke-GlicDiscover {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string]$Config,
        [string]$ServiceAccountPath
    )

    $ctx   = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath
    $skus  = Get-GlicSkuCatalog
    $found = @{}

    Write-Verbose 'Probing SKU catalog...'
    foreach ($sku in $skus) {
        $uri = "https://licensing.googleapis.com/apps/licensing/v1/product/$($sku.ProductId)/sku/$($sku.SkuId)/users"
        try {
            $resp = Invoke-RestMethod -Uri "${uri}?customerId=$($ctx.CustomerId)&maxResults=1" -Headers $ctx.Headers -ErrorAction Stop
            if ($resp.items -and $resp.items.Count -gt 0) { $found[$sku.SkuId] = $true }
        } catch {
            $code = $_.Exception.Response.StatusCode.value__
            if ($code -in @(400,403,404)) { continue }
            Write-Verbose "Warning - $($sku.SkuId): $($_.Exception.Message)"
        }
    }

    # Emit change rows for caller visibility
    foreach ($sku in $skus) {
        $wasActive  = $sku.Active
        $nowActive  = $found.ContainsKey($sku.SkuId)
        [PSCustomObject]@{
            SkuId      = $sku.SkuId
            SkuName    = $sku.SkuName
            ProductId  = $sku.ProductId
            WasActive  = $wasActive
            NowActive  = $nowActive
            Changed    = ($wasActive -ne $nowActive)
        }
    }

    # Write updated skus.json to config dir
    $merged     = $skus | ForEach-Object {
        [PSCustomObject]@{
            productId   = $_.ProductId
            productName = $_.ProductName
            skuId       = $_.SkuId
            skuName     = $_.SkuName
            active      = $found.ContainsKey($_.SkuId)
        }
    }
    $configDir  = Join-Path $env:APPDATA 'GLic'
    $null = New-Item -ItemType Directory -Path $configDir -Force
    $merged | ConvertTo-Json | Set-Content (Join-Path $configDir 'skus.json') -Encoding UTF8
    Write-Verbose "skus.json written to $configDir"
}
