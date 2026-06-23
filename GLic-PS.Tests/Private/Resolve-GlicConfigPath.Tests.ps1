BeforeAll {
    . $PSScriptRoot/../../GLic-PS/Private/Resolve-GlicConfigPath.ps1
    $script:GlicModuleRoot = $PSScriptRoot  # simulate module root
}

Describe 'Resolve-GlicConfigPath' {
    BeforeEach {
        $env:GLIC_CONFIG = $null
    }

    It 'returns null when file does not exist anywhere' {
        $result = Resolve-GlicConfigPath 'nonexistent-file-xyz.json'
        $result | Should -BeNullOrEmpty
    }

    It 'prefers GLIC_CONFIG env var when set and file exists' {
        $tmp = New-TemporaryFile
        $dir = Split-Path $tmp
        $name = 'test-config.json'
        $null = New-Item (Join-Path $dir $name) -ItemType File -Force
        $env:GLIC_CONFIG = $dir
        try {
            $result = Resolve-GlicConfigPath $name
            $result | Should -Be (Join-Path $dir $name)
        } finally {
            $env:GLIC_CONFIG = $null
            Remove-Item (Join-Path $dir $name) -ErrorAction SilentlyContinue
        }
    }
}
