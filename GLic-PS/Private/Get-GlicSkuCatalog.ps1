function Get-GlicSkuCatalog {
    [CmdletBinding()]
    param([string]$Path, [string]$SkuIds)

    # Explicit SkuIds flag: parse "productId:skuId,..." directly
    if ($SkuIds) {
        return $SkuIds -split ',' | ForEach-Object {
            $parts = $_ -split ':',2
            if ($parts.Count -ne 2) { throw "Invalid SkuIds entry '$_'. Expected productId:skuId" }
            [PSCustomObject]@{ ProductId = $parts[0]; ProductName = $parts[0]; SkuId = $parts[1]; SkuName = $parts[1]; Active = $true }
        }
    }

    $resolved = if ($Path -and (Test-Path $Path)) { $Path }
                else { Resolve-GlicConfigPath 'skus.json' }

    if ($resolved -and (Test-Path $resolved)) {
        return (Get-Content $resolved -Raw | ConvertFrom-Json) |
            Where-Object { $_.active -ne $false } |
            ForEach-Object {
                [PSCustomObject]@{
                    ProductId   = $_.productId
                    ProductName = $_.productName
                    SkuId       = $_.skuId
                    SkuName     = $_.skuName
                    Active      = if ($null -eq $_.active) { $true } else { [bool]$_.active }
                }
            }
    }

    # Embedded defaults (mirrors SkuCatalog.EmbeddedDefaults in C# project)
    return @(
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace (Legacy)';           SkuId='Google-Apps-Unlimited';    SkuName='Business Starter';            Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace (Legacy)';           SkuId='Google-Apps-For-Business'; SkuName='Legacy G Suite Basic';        Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace (Legacy)';           SkuId='Google-Apps-Lite';         SkuName='Essentials Starter';          Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Enterprise (Legacy)';SkuId='1010020020';               SkuName='Enterprise Plus';             Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Business Plus';      SkuId='1010020025';               SkuName='Business Plus';               Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Business Starter';   SkuId='1010020026';               SkuName='Business Starter';            Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Business Standard';  SkuId='1010020028';               SkuName='Business Standard';           Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Business Plus';      SkuId='1010020030';               SkuName='Business Plus';               Active=$true }
        [PSCustomObject]@{ ProductId='101001';      ProductName='Cloud Identity';                      SkuId='1010010001';               SkuName='Cloud Identity Free';         Active=$true }
        [PSCustomObject]@{ ProductId='101005';      ProductName='Cloud Identity Premium';              SkuId='1010050001';               SkuName='Cloud Identity Premium';      Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Frontline';          SkuId='1010020031';               SkuName='Frontline Starter';           Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Frontline';          SkuId='1010020033';               SkuName='Frontline Standard';          Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Education';          SkuId='1010020034';               SkuName='Education Fundamentals';      Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Education';          SkuId='1010020035';               SkuName='Education Standard';          Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Education';          SkuId='1010020037';               SkuName='Teaching and Learning Upgrade';Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Workspace Education';          SkuId='1010020038';               SkuName='Education Plus';              Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Voice';                        SkuId='1010060001';               SkuName='Voice Starter';               Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Voice';                        SkuId='1010060002';               SkuName='Voice Standard';              Active=$true }
        [PSCustomObject]@{ ProductId='Google-Apps'; ProductName='Google Voice';                        SkuId='1010060003';               SkuName='Voice Premier';               Active=$true }
    )
}
