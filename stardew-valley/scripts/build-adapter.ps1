param(
    [Parameter(Mandatory = $true)][string]$GamePath,
    [Parameter(Mandatory = $true)][string]$ProtocolRepository,
    [Parameter(Mandatory = $true)][string]$ProtocolDir,
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug'
)

. (Join-Path $PSScriptRoot 'common.ps1')
$adapterRoot = Get-AdapterRoot
$GamePath = Assert-ExplicitDirectory $GamePath 'GamePath'
$protocol = Resolve-ProtocolDependency $adapterRoot $ProtocolRepository $ProtocolDir
$project = Join-Path $adapterRoot 'GameAgent.Stardew.csproj'

& dotnet build $project --configuration $Configuration -p:GamePath="$GamePath" -p:WIA_PROTOCOL_DIR="$($protocol.Directory)"
if ($LASTEXITCODE -ne 0) { throw "Stardew adapter build failed with exit code $LASTEXITCODE." }

$output = Join-Path $adapterRoot "bin\$Configuration"
Write-Host "Built Stardew adapter $((Get-AdapterVersion $adapterRoot)) against $($protocol.Pin) ($($protocol.Commit))."
Write-Host "Output: $output"
