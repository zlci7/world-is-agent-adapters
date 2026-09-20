param(
    [Parameter(Mandatory = $true)][string]$GamePath,
    [Parameter(Mandatory = $true)][string]$ProtocolRepository,
    [Parameter(Mandatory = $true)][string]$ProtocolDir,
    [string]$SourceCommit = '0000000000000000000000000000000000000000',
    [switch]$KeepTemp
)

$ErrorActionPreference = 'Stop'
$adapterSource = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("wia-stardew-standalone-" + [guid]::NewGuid().ToString('N'))
$adapterCopy = Join-Path $tempRoot 'stardew-valley'
$protocolCopy = Join-Path $tempRoot 'protocol'
$protocolRepositoryCopy = Join-Path $tempRoot 'protocol-repository'
$packageOutput = Join-Path $tempRoot 'packages'
$modsPath = Join-Path $tempRoot 'Mods'

function Expect-Failure([scriptblock]$Action, [string]$Name) {
    try { & $Action; throw "$Name unexpectedly succeeded." }
    catch {
        if ($_.Exception.Message -eq "$Name unexpectedly succeeded.") { throw }
        Write-Host "PASS: $Name failed as required."
    }
}

try {
    New-Item -ItemType Directory -Force -Path $adapterCopy, $modsPath | Out-Null
    Get-ChildItem -LiteralPath $adapterSource -Force | Where-Object { $_.Name -notin @('bin', 'obj', 'artifacts') } |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $adapterCopy -Recurse -Force }
    Copy-Item -LiteralPath $ProtocolDir -Destination $protocolCopy -Recurse -Force

    $originalVersion = (Get-Content -Raw -LiteralPath (Join-Path $adapterCopy 'VERSION')).Trim()
    $originalPin = (Get-Content -Raw -LiteralPath (Join-Path $adapterCopy 'protocol.version')).Trim()
    $versionParts = $originalVersion.Split('.')
    $alternativeVersion = "$($versionParts[0]).$($versionParts[1]).$([int]$versionParts[2] + 1)"
    $alternativePin = "$originalPin-standalone"
    & git clone --quiet --no-checkout $ProtocolRepository $protocolRepositoryCopy
    if ($LASTEXITCODE -ne 0) { throw 'Could not create isolated Protocol Git fixture.' }
    & git -C $protocolRepositoryCopy tag $alternativePin "refs/tags/$originalPin^{commit}"
    if ($LASTEXITCODE -ne 0) { throw 'Could not create alternate resolvable Protocol tag.' }

    $scripts = Join-Path $adapterCopy 'scripts'
    & (Join-Path $scripts 'build-adapter.ps1') -GamePath $GamePath -ProtocolRepository $protocolRepositoryCopy -ProtocolDir $protocolCopy
    & (Join-Path $scripts 'test-adapter.ps1') -GamePath $GamePath -ProtocolRepository $protocolRepositoryCopy -ProtocolDir $protocolCopy
    $releaseOutput = Join-Path $adapterCopy 'bin\Release'
    New-Item -ItemType Directory -Force -Path $releaseOutput | Out-Null
    Set-Content -LiteralPath (Join-Path $releaseOutput 'config.json') -Value '{"private":true}'
    Set-Content -LiteralPath (Join-Path $releaseOutput 'private.json') -Value '{"secret":true}'
    $initialTag = "stardew-valley-v$originalVersion"
    $initialPackage = "wia-adapter-stardew-valley-v$originalVersion.zip"
    & (Join-Path $scripts 'release-adapter.ps1') -GamePath $GamePath -ProtocolRepository $protocolRepositoryCopy -ProtocolDir $protocolCopy -ReleaseTag $initialTag -SourceCommit $SourceCommit -OutputDirectory $packageOutput
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead((Join-Path $packageOutput $initialPackage))
    try {
        $packageNames = @($zip.Entries | ForEach-Object FullName)
        if ($packageNames -match '(^|/)(config|private)\.json$') { throw 'Release package included contaminated build output.' }
    }
    finally { $zip.Dispose() }

    $existingTarget = Join-Path $modsPath 'GameAgentStardew'
    New-Item -ItemType Directory -Force -Path $existingTarget | Out-Null
    Set-Content -LiteralPath (Join-Path $existingTarget 'config.json') -Value '{"user":"keep"}'
    Set-Content -LiteralPath (Join-Path $existingTarget 'unrelated.txt') -Value 'keep'
    & (Join-Path $scripts 'install-stardew-adapter.ps1') -GamePath $GamePath -ProtocolRepository $protocolRepositoryCopy -ProtocolDir $protocolCopy -ModsPath $modsPath
    if (-not (Test-Path -LiteralPath (Join-Path $existingTarget 'config.json')) -or -not (Test-Path -LiteralPath (Join-Path $existingTarget 'unrelated.txt'))) {
        throw 'Installer removed user configuration or unrelated files.'
    }

    Expect-Failure { & (Join-Path $scripts 'build-adapter.ps1') -GamePath $GamePath -ProtocolRepository $protocolRepositoryCopy -ProtocolDir (Join-Path $tempRoot 'missing') } 'missing protocol directory'
    Expect-Failure { & (Join-Path $scripts 'release-adapter.ps1') -GamePath $GamePath -ProtocolRepository $protocolRepositoryCopy -ProtocolDir $protocolCopy -ReleaseTag "rimworld-v$originalVersion" -SourceCommit $SourceCommit -OutputDirectory $packageOutput } 'wrong game release tag'
    Expect-Failure { & (Join-Path $scripts 'release-adapter.ps1') -GamePath $GamePath -ProtocolRepository $protocolRepositoryCopy -ProtocolDir $protocolCopy -ReleaseTag "stardew-valley-v$alternativeVersion" -SourceCommit $SourceCommit -OutputDirectory $packageOutput } 'wrong version release tag'

    $protoFile = Join-Path $protocolCopy 'proto\gameagent.proto'
    Add-Content -LiteralPath $protoFile -Value '// mismatch probe'
    Expect-Failure { & (Join-Path $scripts 'build-adapter.ps1') -GamePath $GamePath -ProtocolRepository $protocolRepositoryCopy -ProtocolDir $protocolCopy } 'protocol content mismatch'
    Copy-Item -LiteralPath (Join-Path $ProtocolDir 'proto\gameagent.proto') -Destination $protoFile -Force

    Set-Content -LiteralPath (Join-Path $adapterCopy 'protocol.version') -Value 'protocol-does-not-exist'
    Expect-Failure { & (Join-Path $scripts 'build-adapter.ps1') -GamePath $GamePath -ProtocolRepository $protocolRepositoryCopy -ProtocolDir $protocolCopy } 'unresolvable protocol pin'
    Set-Content -LiteralPath (Join-Path $adapterCopy 'protocol.version') -Value $originalPin

    Set-Content -LiteralPath (Join-Path $adapterCopy 'VERSION') -Value $alternativeVersion
    Set-Content -LiteralPath (Join-Path $adapterCopy 'protocol.version') -Value $alternativePin
    & (Join-Path $scripts 'release-adapter.ps1') -GamePath $GamePath -ProtocolRepository $protocolRepositoryCopy -ProtocolDir $protocolCopy -ReleaseTag "stardew-valley-v$alternativeVersion" -SourceCommit $SourceCommit -OutputDirectory $packageOutput
    if (-not (Test-Path -LiteralPath (Join-Path $packageOutput "wia-adapter-stardew-valley-v$alternativeVersion.zip"))) { throw 'Temporary version bump did not produce its own package name.' }

    Write-Host 'Standalone Stardew build, tests, package, install, and negative probes passed.'
}
finally {
    if ($KeepTemp) { Write-Host "Temporary directory kept: $tempRoot" }
    elseif (Test-Path -LiteralPath $tempRoot) {
        $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        $resolved = [IO.Path]::GetFullPath($tempRoot)
        if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe cleanup target: $resolved" }
        [IO.Directory]::Delete($resolved, $true)
    }
}
