param([string]$ProtocolDir, [string]$ProtocolRepository, [string]$Configuration='Release')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'adapter-common.ps1')
$root = Get-AdapterRoot
$version = Get-AdapterVersion $root
$protocol = Resolve-ProtocolDependency $root $ProtocolDir $ProtocolRepository
& (Join-Path $root 'tests/check-productization-contract.ps1') -AdapterDir $root
& (Join-Path $root 'tests/check-review-regressions.ps1') -ProtocolDir $protocol.Directory -ProtocolRepository $protocol.Repository -Configuration $Configuration
& dotnet test (Join-Path $root 'tests/Projection.Tests/WiaRimWorld.Projection.Tests.csproj') --configuration $Configuration
if ($LASTEXITCODE -ne 0) { throw "RimWorld adapter tests failed with exit code $LASTEXITCODE" }
& dotnet build (Join-Path $root 'WiaRimWorld.csproj') --configuration $Configuration -p:WIA_PROTOCOL_DIR=$($protocol.Directory) -p:WiaAdapterVersion=$version
if ($LASTEXITCODE -ne 0) { throw "RimWorld adapter build failed with exit code $LASTEXITCODE" }
Write-Host "Tested RimWorld adapter $version against $($protocol.Pin) ($($protocol.Commit))."
