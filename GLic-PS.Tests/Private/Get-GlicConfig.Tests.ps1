BeforeAll {
    . $PSScriptRoot/../../GLic-PS/Private/Resolve-GlicConfigPath.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicConfig.ps1
    $script:GlicModuleRoot = $PSScriptRoot
    $script:GlicSession    = $null
}

Describe 'Get-GlicConfig' {
    It 'reads customer_id and admin_email from a glic.json file' {
        $tmp = New-TemporaryFile | Rename-Item -NewName { $_.Name -replace '\.tmp$','.json' } -PassThru
        '{"customer_id":"C03test","admin_email":"admin@example.com"}' | Set-Content $tmp -Encoding UTF8
        $result = Get-GlicConfig -Path $tmp.FullName
        $result.CustomerId | Should -Be 'C03test'
        $result.AdminEmail | Should -Be 'admin@example.com'
        Remove-Item $tmp
    }

    It 'throws when file does not exist and no session is set' {
        $script:GlicSession = $null
        { Get-GlicConfig -Path 'C:\nonexistent\glic.json' } | Should -Throw
    }

    It 'returns session config when GlicSession is set' {
        $script:GlicSession = @{ Config = [PSCustomObject]@{ CustomerId = 'C03sess'; AdminEmail = 'sess@example.com' } }
        $result = Get-GlicConfig
        $result.CustomerId | Should -Be 'C03sess'
        $script:GlicSession = $null
    }
}
