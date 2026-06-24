BeforeAll {
    . $PSScriptRoot/../../GLic-PS/Private/Resolve-GlicConfigPath.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicSkuCatalog.ps1
    $script:GlicModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

Describe 'Get-GlicSkuCatalog' {
    It 'returns embedded defaults when no file exists' {
        $skus = Get-GlicSkuCatalog -Path 'C:\nonexistent\skus.json'
        $skus | Should -Not -BeNullOrEmpty
        $skus[0].ProductId | Should -Not -BeNullOrEmpty
        $skus[0].SkuId     | Should -Not -BeNullOrEmpty
    }

    It 'loads skus from a JSON file' {
        $tmp = New-TemporaryFile
        @'
[{"productId":"TestProduct","productName":"Test","skuId":"TestSku","skuName":"Test SKU","active":true}]
'@ | Set-Content $tmp -Encoding UTF8
        $skus = Get-GlicSkuCatalog -Path $tmp.FullName
        $skus | Should -HaveCount 1
        $skus[0].SkuId | Should -Be 'TestSku'
        Remove-Item $tmp
    }

    It 'filters out inactive SKUs' {
        $tmp = New-TemporaryFile
        @'
[{"productId":"P","productName":"P","skuId":"active-sku","skuName":"A","active":true},
 {"productId":"P","productName":"P","skuId":"inactive-sku","skuName":"I","active":false}]
'@ | Set-Content $tmp -Encoding UTF8
        $skus = Get-GlicSkuCatalog -Path $tmp.FullName
        $skus | Should -HaveCount 1
        $skus[0].SkuId | Should -Be 'active-sku'
        Remove-Item $tmp
    }
}
