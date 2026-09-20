param(
    [Parameter(Mandatory=$true)][string]$ProtocolDir,
    [Parameter(Mandatory=$true)][string]$ProtocolRepository,
    [string]$Configuration='Release'
)
$ErrorActionPreference = 'Stop'
$adapter = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scratch = Join-Path ([IO.Path]::GetTempPath()) ("wia-rimworld-review-" + [guid]::NewGuid().ToString('N'))
$scratchPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
if (-not ([IO.Path]::GetFullPath($scratch)).StartsWith($scratchPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test path.' }
New-Item -ItemType Directory -Force -Path $scratch | Out-Null
try {
    $installOutput = Join-Path $scratch 'install-output'
    New-Item -ItemType Directory -Force -Path $installOutput | Out-Null
    foreach ($name in @('WiaRimWorld.dll','Google.Protobuf.dll','Grpc.Core.dll','Grpc.Core.Api.dll','System.Memory.dll','System.Buffers.dll','System.Numerics.Vectors.dll','System.Runtime.CompilerServices.Unsafe.dll','grpc_csharp_ext.x64.dll')) {
        Set-Content -LiteralPath (Join-Path $installOutput $name) -Value 'fixture'
    }

    # A target junction must be rejected before its external children can be deleted.
    $mods = Join-Path $scratch 'Mods'
    $external = Join-Path $scratch 'external-mod'
    $externalAssemblies = Join-Path $external 'Assemblies'
    New-Item -ItemType Directory -Force -Path $mods,$externalAssemblies | Out-Null
    $marker = Join-Path $externalAssemblies 'keep.txt'
    Set-Content -LiteralPath $marker -Value 'must survive'
    New-Item -ItemType Junction -Path (Join-Path $mods 'WiaRimWorld') -Target $external | Out-Null
    $rejected = $false
    $rejection = ''
    try {
        & (Join-Path $adapter 'scripts/install-rimworld-adapter.ps1') -ProjectPath (Join-Path $adapter 'WiaRimWorld.csproj') -OutputPath $installOutput -ModsPath $mods -SkipBuild
    }
    catch { $rejected = $true; $rejection = $_.Exception.Message }
    if (-not $rejected) { throw 'Install accepted a junction target outside Mods.' }
    if ($rejection -notmatch 'reparse point') { throw "Install junction probe failed for the wrong reason: $rejection" }
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { throw 'Install mutated the external junction target before rejecting it.' }
    Write-Host 'PASS: external install junction rejected without mutation'

    # About is written after staged folders are replaced, so its junction must fail the same preflight.
    $aboutMods = Join-Path $scratch 'about-Mods'
    $aboutTarget = Join-Path $aboutMods 'WiaRimWorld'
    $aboutExternal = Join-Path $scratch 'external-about'
    New-Item -ItemType Directory -Force -Path (Join-Path $aboutTarget 'Assemblies'),$aboutExternal | Out-Null
    $installSentinel = Join-Path $aboutTarget 'Assemblies/existing.dll'
    $aboutMarker = Join-Path $aboutExternal 'About.xml'
    Set-Content -LiteralPath $installSentinel -Value 'installed state must survive'
    Set-Content -LiteralPath $aboutMarker -Value 'external metadata must survive'
    New-Item -ItemType Junction -Path (Join-Path $aboutTarget 'About') -Target $aboutExternal | Out-Null
    $rejected = $false
    $rejection = ''
    try {
        & (Join-Path $adapter 'scripts/install-rimworld-adapter.ps1') -ProjectPath (Join-Path $adapter 'WiaRimWorld.csproj') -OutputPath $installOutput -ModsPath $aboutMods -SkipBuild
    }
    catch { $rejected = $true; $rejection = $_.Exception.Message }
    if (-not $rejected) { throw 'Install accepted an About junction outside Mods.' }
    if ($rejection -notmatch 'reparse point') { throw "About junction probe failed for the wrong reason: $rejection" }
    if ((Get-Content -Raw -LiteralPath $aboutMarker).Trim() -ne 'external metadata must survive') { throw 'Install wrote through the external About junction.' }
    if (-not (Test-Path -LiteralPath $installSentinel -PathType Leaf)) { throw 'Install replaced staged folders before rejecting the About junction.' }
    Write-Host 'PASS: external About junction rejected before any install mutation'

    # Recursive deletion must reject a reparse point nested anywhere in an owned staged folder.
    $nestedMods = Join-Path $scratch 'nested-Mods'
    $nestedTarget = Join-Path $nestedMods 'WiaRimWorld'
    $nestedAssemblies = Join-Path $nestedTarget 'Assemblies'
    $nestedExternal = Join-Path $scratch 'external-nested'
    New-Item -ItemType Directory -Force -Path $nestedAssemblies,$nestedExternal | Out-Null
    $nestedSentinel = Join-Path $nestedAssemblies 'existing.dll'
    $nestedMarker = Join-Path $nestedExternal 'keep.txt'
    Set-Content -LiteralPath $nestedSentinel -Value 'installed state must survive'
    Set-Content -LiteralPath $nestedMarker -Value 'external tree must survive'
    New-Item -ItemType Junction -Path (Join-Path $nestedAssemblies 'linked') -Target $nestedExternal | Out-Null
    $rejected = $false
    $rejection = ''
    try {
        & (Join-Path $adapter 'scripts/install-rimworld-adapter.ps1') -ProjectPath (Join-Path $adapter 'WiaRimWorld.csproj') -OutputPath $installOutput -ModsPath $nestedMods -SkipBuild
    }
    catch { $rejected = $true; $rejection = $_.Exception.Message }
    if (-not $rejected) { throw 'Install accepted a nested junction in a recursively replaced folder.' }
    if ($rejection -notmatch 'reparse point') { throw "Nested junction probe failed for the wrong reason: $rejection" }
    if (-not (Test-Path -LiteralPath $nestedSentinel -PathType Leaf)) { throw 'Install mutated staged folders before rejecting the nested junction.' }
    if (-not (Test-Path -LiteralPath $nestedMarker -PathType Leaf)) { throw 'Install mutated the nested external junction target.' }
    Write-Host 'PASS: nested staged-folder junction rejected before any install mutation'

    # A branch named like a protocol release is not the required Git tag.
    $fixtureRepo = Join-Path $scratch 'branch-only-protocol'
    New-Item -ItemType Directory -Force -Path (Join-Path $fixtureRepo 'protocol/proto') | Out-Null
    Copy-Item -LiteralPath (Join-Path $ProtocolDir 'proto/gameagent.proto') -Destination (Join-Path $fixtureRepo 'protocol/proto/gameagent.proto')
    & git -C $fixtureRepo init --quiet
    & git -C $fixtureRepo config user.email test@example.invalid
    & git -C $fixtureRepo config user.name 'WIA Test'
    & git -C $fixtureRepo add .
    & git -C $fixtureRepo commit --quiet -m fixture
    & git -C $fixtureRepo branch protocol-vbranch-only
    $fixtureAdapter = Join-Path $scratch 'adapter-pin'
    New-Item -ItemType Directory -Force -Path $fixtureAdapter | Out-Null
    Set-Content -LiteralPath (Join-Path $fixtureAdapter 'protocol.version') -Value 'protocol-vbranch-only' -NoNewline
    . (Join-Path $adapter 'scripts/adapter-common.ps1')
    $rejected = $false
    try { Resolve-ProtocolDependency $fixtureAdapter $ProtocolDir $fixtureRepo | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw 'Protocol resolution accepted a branch when the release tag was absent.' }
    Write-Host 'PASS: branch-only protocol pin rejected'

    # Normal validation follows the authoritative files after an independent release bump.
    $versionFixture = Join-Path $scratch 'version-fixture'
    New-Item -ItemType Directory -Force -Path $versionFixture | Out-Null
    Get-ChildItem -LiteralPath $adapter -Force | Where-Object Name -notin @('bin','obj','artifacts') |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $versionFixture -Recurse -Force }
    Set-Content -LiteralPath (Join-Path $versionFixture 'VERSION') -Value '0.1.1' -NoNewline
    Set-Content -LiteralPath (Join-Path $versionFixture 'protocol.version') -Value 'protocol-v1alpha2.1' -NoNewline
    & (Join-Path $versionFixture 'tests/check-productization-contract.ps1') -AdapterDir $versionFixture
    Write-Host 'PASS: contract accepts valid authoritative version and protocol pin updates'
}
finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
