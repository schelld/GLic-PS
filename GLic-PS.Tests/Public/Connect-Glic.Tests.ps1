BeforeAll {
    . $PSScriptRoot/../../GLic-PS/Private/Resolve-GlicConfigPath.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicConfig.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicServiceAccount.ps1
    . $PSScriptRoot/../../GLic-PS/Private/Get-GlicAccessToken.ps1
    . $PSScriptRoot/../../GLic-PS/Public/Connect-Glic.ps1
    $script:GlicModuleRoot   = $PSScriptRoot
    $script:GlicSession      = $null
    $script:_glicToken       = $null
    $script:_glicTokenExpiry = [datetime]::MinValue
    $script:GlicScopes       = @('https://www.googleapis.com/auth/admin.directory.customer.readonly')

    $script:TmpSA = New-TemporaryFile
    @'
{"type":"service_account","client_email":"test@proj.iam.gserviceaccount.com","private_key":"PLACEHOLDER"}
'@ | Set-Content $script:TmpSA -Encoding UTF8
}

AfterAll { Remove-Item $script:TmpSA -ErrorAction SilentlyContinue }

Describe 'Connect-Glic' {
    BeforeEach {
        $script:GlicSession = $null
        Mock Get-GlicAccessToken { 'fake-token' }
        Mock Invoke-RestMethod { [PSCustomObject]@{ id = 'C03test' } }   # customers.get
        Mock Set-Content { }   # suppress glic.json write
        Mock New-Item { }
    }

    It 'sets GlicSession after successful connect' {
        Connect-Glic -AdminEmail 'admin@example.com' -ServiceAccountPath $script:TmpSA.FullName
        $script:GlicSession | Should -Not -BeNullOrEmpty
        $script:GlicSession.Config.CustomerId | Should -Be 'C03test'
    }

    It 'skips connect when already connected and -Force not set' {
        $script:GlicSession = @{ Config = [PSCustomObject]@{ CustomerId = 'existing' }; ServiceAccount = @{} }
        Connect-Glic -AdminEmail 'admin@example.com' -ServiceAccountPath $script:TmpSA.FullName
        Should -Invoke Invoke-RestMethod -Times 0
    }

    It 'reconnects when -Force is set' {
        $script:GlicSession = @{ Config = [PSCustomObject]@{ CustomerId = 'existing' }; ServiceAccount = @{} }
        Connect-Glic -AdminEmail 'admin@example.com' -ServiceAccountPath $script:TmpSA.FullName -Force
        Should -Invoke Invoke-RestMethod -Times 1
    }
}
