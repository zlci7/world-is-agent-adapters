param(
    [string]$ProtocolDir,
    [string]$ProtocolRepository,
    [string]$ReleaseTag,
    [string]$SourceCommit,
    [string]$OutputDirectory,
    [string]$Configuration='Release',
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'adapter-common.ps1')
$root = Get-AdapterRoot
$version = Get-AdapterVersion $root
$expectedTag = "rimworld-v$version"
if ($ReleaseTag -and $ReleaseTag -cne $expectedTag) { throw "Release tag must be $expectedTag, got $ReleaseTag" }
$protocol = Resolve-ProtocolDependency $root $ProtocolDir $ProtocolRepository
if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot 'build-adapter.ps1') -ProtocolDir $protocol.Directory -ProtocolRepository $protocol.Repository -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed.' }
}
$build = Join-Path $root "bin/$Configuration/net472"
$assembly = Join-Path $build 'WiaRimWorld.dll'
$actualVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($assembly).ProductVersion
if ($actualVersion -cne $version) { throw "Artifact informational version mismatch: expected $version, got $actualVersion" }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $root 'artifacts' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$scratch = Join-Path ([IO.Path]::GetTempPath()) ("wia-rimworld-release-" + [guid]::NewGuid().ToString('N'))
$stage = Join-Path $scratch 'WiaRimWorld'
Assert-SafeChildPath $scratch $stage
New-Item -ItemType Directory -Force -Path $scratch | Out-Null
try {
    & (Join-Path $PSScriptRoot 'install-rimworld-adapter.ps1') -ProjectPath (Join-Path $root 'WiaRimWorld.csproj') -OutputPath $build -ModsPath $scratch -Configuration $Configuration -ProtocolDir $protocol.Directory -AdapterVersion $version -SkipBuild
    if (-not $SourceCommit) { $SourceCommit = (& git -C $root rev-parse HEAD 2>$null) }
    if (-not $SourceCommit) { throw 'Source commit unavailable. Commit the adapter repository or pass -SourceCommit for an isolated snapshot.' }
    if ($SourceCommit -notmatch '^[0-9a-fA-F]{7,40}$') { throw "Invalid source commit: $SourceCommit" }
    Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $stage 'LICENSE') -Force
    @("adapter_version=$version", "source_commit=$($SourceCommit.Trim())", "protocol_pin=$($protocol.Pin)", "protocol_commit=$($protocol.Commit)") |
        Set-Content -LiteralPath (Join-Path $stage 'PROVENANCE.txt') -Encoding UTF8
    $archive = Join-Path $OutputDirectory "wia-adapter-rimworld-v$version.zip"
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
    Compress-Archive -LiteralPath $stage -DestinationPath $archive -CompressionLevel Optimal
    Write-Host "Created $archive"
}
finally {
    if (Test-Path -LiteralPath $scratch) { Assert-SafeChildPath ([IO.Path]::GetTempPath()) $scratch; Remove-Item -LiteralPath $scratch -Recurse -Force }
}
