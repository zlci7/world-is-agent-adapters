param([string]$ProtocolDir, [string]$ProtocolRepository, [string]$Configuration='Release')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'adapter-common.ps1')
$root = Get-AdapterRoot
$version = Get-AdapterVersion $root
$protocol = Resolve-ProtocolDependency $root $ProtocolDir $ProtocolRepository
& dotnet build (Join-Path $root 'WiaRimWorld.csproj') --configuration $Configuration -p:WIA_PROTOCOL_DIR=$($protocol.Directory) -p:WiaAdapterVersion=$version
if ($LASTEXITCODE -ne 0) { throw "RimWorld adapter build failed with exit code $LASTEXITCODE" }
Write-Host "Built RimWorld adapter $version against $($protocol.Pin) ($($protocol.Commit))."
