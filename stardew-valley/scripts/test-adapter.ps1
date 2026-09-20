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

& (Join-Path $adapterRoot 'tests\check-release-contract.ps1')
& (Join-Path $adapterRoot 'tests\check-context-static.ps1')
& (Join-Path $adapterRoot 'tests\check-install-destination-safety.ps1')

$projects = Get-ChildItem -LiteralPath (Join-Path $adapterRoot 'tests') -Filter '*.csproj' -Recurse | Sort-Object FullName
foreach ($project in $projects) {
    & dotnet test $project.FullName --configuration $Configuration -p:GamePath="$GamePath" -p:WIA_PROTOCOL_DIR="$($protocol.Directory)"
    if ($LASTEXITCODE -ne 0) { throw "Test project failed: $($project.FullName)" }
}

Write-Host "All Stardew adapter tests passed against $($protocol.Pin) ($($protocol.Commit))."
