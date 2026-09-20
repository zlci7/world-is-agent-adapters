$ErrorActionPreference = 'Stop'

function Get-AdapterRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Get-AdapterVersion([string]$AdapterRoot) {
    $value = (Get-Content -Raw -LiteralPath (Join-Path $AdapterRoot 'VERSION')).Trim()
    if ($value -notmatch '^\d+\.\d+\.\d+$') { throw "Invalid adapter VERSION: $value" }
    return $value
}

function Assert-ExplicitDirectory([string]$Path, [string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "$Name is required." }
    if ($Path -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+(?:[\\/]|$))') { throw "$Name must be an absolute path: $Path" }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "$Name directory not found: $Path" }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Assert-SafePayloadDestinations([string]$ModsPath, [string]$InstallDirectoryName, [string[]]$PayloadFiles) {
    $resolvedMods = [IO.Path]::GetFullPath($ModsPath).TrimEnd('\')
    $targetRoot = [IO.Path]::GetFullPath((Join-Path $resolvedMods $InstallDirectoryName))
    $targetPrefix = $targetRoot.TrimEnd('\') + '\'
    $modsPrefix = $resolvedMods + '\'
    if (-not $targetRoot.StartsWith($modsPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Install target escapes ModsPath: $targetRoot" }

    foreach ($relative in $PayloadFiles) {
        $destination = [IO.Path]::GetFullPath((Join-Path $targetRoot $relative))
        if (-not $destination.StartsWith($targetPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Payload destination escapes install target: $relative" }
        $current = $destination
        while ($current.StartsWith($modsPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            if (Test-Path -LiteralPath $current) {
                $item = Get-Item -LiteralPath $current -Force
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Payload destination contains a junction or reparse point: $current" }
                if ($current -ne $destination -and -not $item.PSIsContainer) { throw "Payload destination ancestor is not a directory: $current" }
                if ($current -eq $destination -and $item.PSIsContainer) { throw "Payload file destination is an existing directory: $current" }
            }
            if ($current -eq $resolvedMods) { break }
            $current = Split-Path -Parent $current
        }
    }
}

function Assert-NoReparsePointAncestry([string]$Path, [string]$Name) {
    $current = [IO.DirectoryInfo]::new([IO.Path]::GetFullPath($Path))
    while ($null -ne $current) {
        if ($current.Exists -and ($current.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "$Name must not contain a junction or reparse point: $($current.FullName)"
        }
        $current = $current.Parent
    }
}

function Get-AdapterPayloadFiles {
    return @('GameAgent.Stardew.dll', 'GameAgent.Stardew.deps.json', 'Google.Protobuf.dll',
        'Grpc.Core.Api.dll', 'Grpc.Net.Client.dll', 'Grpc.Net.Common.dll',
        'Microsoft.Extensions.Logging.Abstractions.dll', 'manifest.json', 'assets\landmarks.json')
}

function Resolve-ProtocolDependency([string]$AdapterRoot, [string]$ProtocolRepository, [string]$ProtocolDir) {
    $ProtocolRepository = Assert-ExplicitDirectory $ProtocolRepository 'ProtocolRepository'
    $ProtocolDir = Assert-ExplicitDirectory $ProtocolDir 'ProtocolDir'
    $pin = (Get-Content -Raw -LiteralPath (Join-Path $AdapterRoot 'protocol.version')).Trim()
    if ([string]::IsNullOrWhiteSpace($pin)) { throw 'protocol.version is empty.' }

    $commit = (& git -C $ProtocolRepository rev-parse --verify "refs/tags/$pin^{commit}" 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Protocol tag cannot be resolved: $pin`n$commit" }
    $commit = ($commit | Select-Object -Last 1).Trim()
    $sourcePrefix = 'protocol/'
    $tracked = @(& git -C $ProtocolRepository ls-tree -r --name-only $commit -- protocol/proto)
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect Protocol tag: $pin" }
    if ($tracked.Count -eq 0) {
        $sourcePrefix = ''
        $tracked = @(& git -C $ProtocolRepository ls-tree -r --name-only $commit -- proto)
    }
    if ($LASTEXITCODE -ne 0 -or $tracked.Count -eq 0) { throw "Protocol tag has no proto files: $pin" }

    foreach ($repoPath in $tracked) {
        $relative = $repoPath.Substring($sourcePrefix.Length)
        $exportPath = Join-Path $ProtocolDir ($relative -replace '/', '\')
        if (-not (Test-Path -LiteralPath $exportPath -PathType Leaf)) { throw "Protocol export is missing $relative" }
        $expectedBlob = (& git -C $ProtocolRepository rev-parse "${commit}:$repoPath" 2>&1 | Select-Object -Last 1).Trim()
        if ($LASTEXITCODE -ne 0) { throw "Cannot resolve pinned protocol file: $repoPath" }
        $actualBlob = (& git -C $ProtocolRepository hash-object -- $exportPath 2>&1 | Select-Object -Last 1).Trim()
        if ($LASTEXITCODE -ne 0 -or $actualBlob -cne $expectedBlob) {
            throw "Protocol export content does not match $pin ($commit): $relative"
        }
    }
    return [pscustomobject]@{ Pin = $pin; Commit = $commit; Directory = $ProtocolDir }
}
