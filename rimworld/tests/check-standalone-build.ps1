param(
    [Parameter(Mandatory=$true)][string]$ProtocolDir,
    [Parameter(Mandatory=$true)][string]$ProtocolRepository,
    [Parameter(Mandatory=$true)][string]$SourceCommit,
    [string]$Configuration='Release',
    [switch]$KeepTemp
)
$ErrorActionPreference = 'Stop'
$source = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ProtocolDir = (Resolve-Path -LiteralPath $ProtocolDir).Path
$ProtocolRepository = (Resolve-Path -LiteralPath $ProtocolRepository).Path
$temp = Join-Path ([IO.Path]::GetTempPath()) ("wia-rimworld-standalone-" + [guid]::NewGuid().ToString('N'))
$adapter = Join-Path $temp 'rimworld'
$protocol = Join-Path $temp 'protocol'
$artifacts = Join-Path $temp 'artifacts'
$tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
if (-not ([IO.Path]::GetFullPath($temp)).StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe temporary path.' }
New-Item -ItemType Directory -Force -Path $adapter | Out-Null
try {
    Get-ChildItem -LiteralPath $source -Force | Where-Object Name -notin @('bin','obj','artifacts') |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $adapter -Recurse -Force }
    Copy-Item -LiteralPath $ProtocolDir -Destination $protocol -Recurse -Force
    $adapterVersion = (Get-Content -Raw -LiteralPath (Join-Path $adapter 'VERSION')).Trim()
    $protocolPin = (Get-Content -Raw -LiteralPath (Join-Path $adapter 'protocol.version')).Trim()
    if ($adapterVersion -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') { throw "Invalid fixture adapter version: $adapterVersion" }
    if ($protocolPin -notmatch '^protocol-v[0-9A-Za-z.-]+$') { throw "Invalid fixture protocol pin: $protocolPin" }
    $releaseTag = "rimworld-v$adapterVersion"
    $archiveName = "wia-adapter-rimworld-v$adapterVersion.zip"

    & (Join-Path $adapter 'scripts/test-adapter.ps1') -ProtocolDir $protocol -ProtocolRepository $ProtocolRepository -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Standalone test entry point failed.' }
    & (Join-Path $adapter 'scripts/release-adapter.ps1') -ProtocolDir $protocol -ProtocolRepository $ProtocolRepository -ReleaseTag $releaseTag -SourceCommit $SourceCommit -OutputDirectory $artifacts -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Standalone release entry point failed.' }
    $archivePath = Join-Path $artifacts $archiveName
    if (-not (Test-Path -LiteralPath $archivePath)) { throw 'Release archive missing.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $names = @($zip.Entries | ForEach-Object FullName)
        foreach ($required in @('WiaRimWorld/Assemblies/WiaRimWorld.dll','WiaRimWorld/Native/grpc_csharp_ext.dll','WiaRimWorld/Patches/WiaEntryPoint.xml','WiaRimWorld/PROVENANCE.txt','WiaRimWorld/LICENSE')) {
            if ($required -notin $names) { throw "Package entry missing: $required" }
        }
        if ($names | Where-Object { $_ -match '(^|/)(src|obj|tests)/|Assembly-CSharp|UnityEngine|\.pdb$|\.git' }) { throw 'Package contains excluded source, cache, debug, or game files.' }
    } finally { $zip.Dispose() }

    $negative = @(
        @{ Name='missing protocol directory'; Run={ & (Join-Path $adapter 'scripts/build-adapter.ps1') -ProtocolDir (Join-Path $temp 'missing') -ProtocolRepository $ProtocolRepository } },
        @{ Name='wrong-game release tag'; Run={ & (Join-Path $adapter 'scripts/release-adapter.ps1') -ProtocolDir $protocol -ProtocolRepository $ProtocolRepository -ReleaseTag "stardew-valley-v$adapterVersion" -SourceCommit $SourceCommit -OutputDirectory $artifacts } },
        @{ Name='wrong-version release tag'; Run={ & (Join-Path $adapter 'scripts/release-adapter.ps1') -ProtocolDir $protocol -ProtocolRepository $ProtocolRepository -ReleaseTag "$releaseTag-wrong" -SourceCommit $SourceCommit -OutputDirectory $artifacts } }
    )
    foreach ($probe in $negative) {
        $failed = $false
        try { & $probe.Run } catch { $failed = $true }
        if (-not $failed) { throw "Negative probe unexpectedly succeeded: $($probe.Name)" }
        Write-Host "PASS: rejected $($probe.Name)"
    }

    $versionPath = Join-Path $adapter 'VERSION'
    $stableVersion = [version](($adapterVersion -split '[-+]')[0])
    $bumpedVersion = "$($stableVersion.Major).$($stableVersion.Minor).$($stableVersion.Build + 1)"
    $bumpedTag = "rimworld-v$bumpedVersion"
    $bumpedArchive = "wia-adapter-rimworld-v$bumpedVersion.zip"
    Set-Content -LiteralPath $versionPath -Value $bumpedVersion -NoNewline
    $failed = $false
    try { & (Join-Path $adapter 'scripts/release-adapter.ps1') -ProtocolDir $protocol -ProtocolRepository $ProtocolRepository -ReleaseTag $bumpedTag -SourceCommit $SourceCommit -OutputDirectory $artifacts -Configuration $Configuration -SkipBuild } catch { $failed = $true }
    if (-not $failed) { throw 'Artifact/version mismatch was accepted.' }
    & (Join-Path $adapter 'scripts/test-adapter.ps1') -ProtocolDir $protocol -ProtocolRepository $ProtocolRepository -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Test entry point failed after the temporary version bump.' }
    & (Join-Path $adapter 'scripts/release-adapter.ps1') -ProtocolDir $protocol -ProtocolRepository $ProtocolRepository -ReleaseTag $bumpedTag -SourceCommit $SourceCommit -OutputDirectory $artifacts -Configuration $Configuration -SkipBuild
    if (-not (Test-Path -LiteralPath (Join-Path $artifacts $bumpedArchive))) { throw 'Temporary adapter version bump did not change its package name.' }
    Set-Content -LiteralPath $versionPath -Value $adapterVersion -NoNewline

    $pinPath = Join-Path $adapter 'protocol.version'
    $originalPin = Get-Content -Raw -LiteralPath $pinPath
    Remove-Item -LiteralPath $pinPath -Force
    $failed = $false
    try { & (Join-Path $adapter 'scripts/build-adapter.ps1') -ProtocolDir $protocol -ProtocolRepository $ProtocolRepository } catch { $failed = $true }
    if (-not $failed) { throw 'Missing protocol pin was accepted.' }
    foreach ($badPin in @('not-a-protocol-tag', 'protocol-v-does-not-exist')) {
        Set-Content -LiteralPath $pinPath -Value $badPin -NoNewline
        $failed = $false
        try { & (Join-Path $adapter 'scripts/build-adapter.ps1') -ProtocolDir $protocol -ProtocolRepository $ProtocolRepository } catch { $failed = $true }
        if (-not $failed) { throw "Negative pin probe unexpectedly succeeded: '$badPin'" }
    }
    Set-Content -LiteralPath $pinPath -Value $originalPin -NoNewline

    $protoFile = Join-Path $protocol 'proto/gameagent.proto'
    Add-Content -LiteralPath $protoFile -Value '// mismatch'
    $failed = $false
    try { & (Join-Path $adapter 'scripts/build-adapter.ps1') -ProtocolDir $protocol -ProtocolRepository $ProtocolRepository } catch { $failed = $true }
    if (-not $failed) { throw 'Mismatched protocol content was accepted.' }
    Write-Host 'PASS: standalone build, tests, package, install staging, and negative probes'
}
finally {
    if ($KeepTemp) { Write-Host "Temporary directory kept: $temp" }
    elseif (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
