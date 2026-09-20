param(
    [Parameter(Mandatory = $true)][string]$GamePath,
    [Parameter(Mandatory = $true)][string]$ProtocolRepository,
    [Parameter(Mandatory = $true)][string]$ProtocolDir,
    [Parameter(Mandatory = $true)][string]$ReleaseTag,
    [Parameter(Mandatory = $true)][string]$SourceCommit,
    [string]$OutputDirectory
)

. (Join-Path $PSScriptRoot 'common.ps1')
$adapterRoot = Get-AdapterRoot
$version = Get-AdapterVersion $adapterRoot
$expectedTag = "stardew-valley-v$version"
if ($ReleaseTag -cne $expectedTag) { throw "Release tag must be $expectedTag, got $ReleaseTag." }
if ($SourceCommit -notmatch '^[0-9a-fA-F]{40}$') { throw 'SourceCommit must be a full 40-character Git commit.' }
$protocol = Resolve-ProtocolDependency $adapterRoot $ProtocolRepository $ProtocolDir

& (Join-Path $PSScriptRoot 'build-adapter.ps1') -GamePath $GamePath -ProtocolRepository $ProtocolRepository -ProtocolDir $ProtocolDir -Configuration Release
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $adapterRoot 'artifacts' }
if ($OutputDirectory -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+(?:[\\/]|$))') { $OutputDirectory = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputDirectory)) }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path

$buildOutput = Join-Path $adapterRoot 'bin\Release'
$payloadFiles = Get-AdapterPayloadFiles
foreach ($relative in $payloadFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $buildOutput $relative) -PathType Leaf)) { throw "Required release output missing: $relative" }
}
$manifest = Get-Content -Raw -LiteralPath (Join-Path $buildOutput 'manifest.json') | ConvertFrom-Json
if ($manifest.Version -cne $version) { throw "Generated manifest version $($manifest.Version) does not match VERSION $version." }
$informational = [Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $buildOutput 'GameAgent.Stardew.dll')).ProductVersion
if ($informational -cne $version) { throw "Assembly informational version $informational does not match VERSION $version." }

$scratchRoot = Join-Path ([IO.Path]::GetTempPath()) ("wia-stardew-release-" + [guid]::NewGuid().ToString('N'))
$packageRoot = Join-Path $scratchRoot 'GameAgentStardew'
$archive = Join-Path $OutputDirectory "wia-adapter-stardew-valley-v$version.zip"
try {
    New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
    foreach ($relative in $payloadFiles) {
        $destination = Join-Path $packageRoot $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        Copy-Item -LiteralPath (Join-Path $buildOutput $relative) -Destination $destination -Force
    }
    Copy-Item -LiteralPath (Join-Path $adapterRoot 'LICENSE') -Destination $packageRoot
    [ordered]@{ source_commit = $SourceCommit.ToLowerInvariant(); adapter_version = $version; protocol_pin = $protocol.Pin; protocol_commit = $protocol.Commit; protocol_content_verified = $true } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $packageRoot 'provenance.json') -Encoding UTF8
    $forbidden = Get-ChildItem -LiteralPath $packageRoot -File -Recurse | Where-Object {
        $_.Name -in @('Stardew Valley.dll', 'StardewModdingAPI.dll', 'MonoGame.Framework.dll', 'xTile.dll', 'StardewValley.GameData.dll') -or $_.Extension -in @('.cache', '.user') -or $_.Name -match '(?i)(secret|credential)'
    }
    if ($forbidden) { throw "Forbidden package content: $($forbidden.FullName -join ', ')" }
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
    Compress-Archive -LiteralPath $packageRoot -DestinationPath $archive -CompressionLevel Optimal
}
finally {
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    $resolvedScratch = [IO.Path]::GetFullPath($scratchRoot)
    if ($resolvedScratch.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedScratch)) { Remove-Item -LiteralPath $resolvedScratch -Recurse -Force }
}
Write-Host "Release package: $archive"
