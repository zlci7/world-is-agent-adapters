param([string]$AdapterDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'

function Assert-File([string]$RelativePath) {
    $path = Join-Path $AdapterDir $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing required file: $RelativePath" }
}

foreach ($file in @(
    'VERSION',
    'protocol.version',
    'scripts/build-adapter.ps1',
    'scripts/test-adapter.ps1',
    'scripts/release-adapter.ps1'
)) { Assert-File $file }

$version = (Get-Content -Raw -LiteralPath (Join-Path $AdapterDir 'VERSION')).Trim()
$pin = (Get-Content -Raw -LiteralPath (Join-Path $AdapterDir 'protocol.version')).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') { throw "Invalid adapter version: $version" }
if ($pin -notmatch '^protocol-v[0-9A-Za-z.-]+$') { throw "Invalid protocol pin: $pin" }

$projectText = Get-Content -Raw -LiteralPath (Join-Path $AdapterDir 'WiaRimWorld.csproj')
if ($projectText -match '\.\.\\.*protocol') { throw 'Project must not contain a parent-relative protocol fallback.' }
if ($projectText -notmatch '<InformationalVersion>\$\(WiaAdapterVersion\)</InformationalVersion>') {
    throw 'Project must derive the assembly informational version from WiaAdapterVersion.'
}
if ($projectText -notmatch '<IncludeSourceRevisionInInformationalVersion>false</IncludeSourceRevisionInInformationalVersion>') {
    throw 'Assembly informational version must remain exactly equal to VERSION.'
}

$identityText = Get-Content -Raw -LiteralPath (Join-Path $AdapterDir 'src/Runtime/AdapterIdentity.cs')
if ($identityText -match 'const string AdapterVersion') { throw 'Hello version must not be hard-coded.' }
if ($identityText -notmatch 'AssemblyInformationalVersionAttribute') { throw 'Hello version must read assembly informational version.' }
$connectionText = Get-Content -Raw -LiteralPath (Join-Path $AdapterDir 'src/Runtime/RuntimeConnection.cs')
if ($connectionText -notmatch 'AdapterVersion\s*=\s*AdapterIdentity\.AdapterVersion') {
    throw 'AdapterHello must use AdapterIdentity.AdapterVersion.'
}

Write-Host 'PASS: RimWorld productization contract'
