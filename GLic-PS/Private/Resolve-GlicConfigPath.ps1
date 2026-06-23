function Resolve-GlicConfigPath {
    param([string]$FileName)

    if ($env:GLIC_CONFIG) {
        $p = Join-Path -Path $env:GLIC_CONFIG -ChildPath $FileName
        if (Test-Path $p) { return $p }
    }
    $p = Join-Path -Path (Join-Path -Path $env:ProgramData -ChildPath 'GLic') -ChildPath $FileName
    if (Test-Path $p) { return $p }
    $p = Join-Path -Path (Join-Path -Path $env:APPDATA -ChildPath 'GLic') -ChildPath $FileName
    if (Test-Path $p) { return $p }
    $p = Join-Path -Path $script:GlicModuleRoot -ChildPath $FileName
    if (Test-Path $p) { return $p }
    return $null
}
