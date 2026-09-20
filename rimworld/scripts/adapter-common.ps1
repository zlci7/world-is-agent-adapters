Set-StrictMode -Version Latest

function Get-AdapterRoot { return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }

function Get-AdapterVersion([string]$AdapterRoot) {
    $path = Join-Path $AdapterRoot 'VERSION'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Adapter version file not found: $path" }
    $value = (Get-Content -Raw -LiteralPath $path).Trim()
    if ($value -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') { throw "Invalid adapter version: $value" }
    return $value
}

function Resolve-ProtocolDependency([string]$AdapterRoot, [string]$ProtocolDir, [string]$ProtocolRepository) {
    if (-not $ProtocolDir) { $ProtocolDir = $env:WIA_PROTOCOL_DIR }
    if (-not $ProtocolRepository) { $ProtocolRepository = $env:WIA_PROTOCOL_REPOSITORY }
    if (-not $ProtocolDir) { throw 'Protocol directory missing. Pass -ProtocolDir or set WIA_PROTOCOL_DIR.' }
    if (-not $ProtocolRepository) { throw 'Protocol repository missing. Pass -ProtocolRepository or set WIA_PROTOCOL_REPOSITORY.' }
    if (-not (Test-Path -LiteralPath $ProtocolDir -PathType Container)) { throw "Protocol directory not found: $ProtocolDir" }
    if (-not (Test-Path -LiteralPath $ProtocolRepository -PathType Container)) { throw "Protocol repository not found: $ProtocolRepository" }
    $ProtocolDir = (Resolve-Path -LiteralPath $ProtocolDir).Path
    $ProtocolRepository = (Resolve-Path -LiteralPath $ProtocolRepository).Path

    $pinPath = Join-Path $AdapterRoot 'protocol.version'
    if (-not (Test-Path -LiteralPath $pinPath -PathType Leaf)) { throw "Protocol pin missing: $pinPath" }
    $pin = (Get-Content -Raw -LiteralPath $pinPath).Trim()
    if ($pin -notmatch '^protocol-v[0-9A-Za-z.-]+$') { throw "Invalid protocol pin: $pin" }
    $commit = (& git -C $ProtocolRepository rev-parse --verify "refs/tags/$pin^{commit}" 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $commit) { throw "Protocol pin cannot be resolved: $pin" }
    $commit = $commit.Trim()
    $files = @(& git -C $ProtocolRepository ls-tree -r --name-only $commit -- protocol/proto)
    if ($LASTEXITCODE -ne 0 -or $files.Count -eq 0) { throw "Pinned protocol contains no proto files: $pin" }
    foreach ($repoFile in $files) {
        if (-not $repoFile.EndsWith('.proto', [StringComparison]::OrdinalIgnoreCase)) { continue }
        $relative = $repoFile.Substring('protocol/'.Length).Replace('/', [IO.Path]::DirectorySeparatorChar)
        $local = Join-Path $ProtocolDir $relative
        if (-not (Test-Path -LiteralPath $local -PathType Leaf)) { throw "Pinned protocol file missing from ProtocolDir: $relative" }
        $expectedHash = (& git -C $ProtocolRepository rev-parse "$commit`:$repoFile" 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $expectedHash) { throw "Could not resolve pinned protocol blob: $repoFile" }
        $actualHash = (& git hash-object --no-filters -- $local 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $actualHash) { throw "Could not hash ProtocolDir file: $local" }
        if ($actualHash.Trim() -cne $expectedHash.Trim()) { throw "Protocol content does not match $pin`: $relative" }
    }
    return [pscustomobject]@{ Directory=$ProtocolDir; Repository=$ProtocolRepository; Pin=$pin; Commit=$commit }
}

function Assert-SafeChildPath([string]$Parent, [string]$Child) {
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
    $childFull = [IO.Path]::GetFullPath($Child)
    if (-not $childFull.StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the expected parent: $childFull"
    }
}
