param(
    [Parameter(Mandatory = $true)][string]$GamePath,
    [Parameter(Mandatory = $true)][string]$ProtocolRepository,
    [Parameter(Mandatory = $true)][string]$ProtocolDir,
    [string]$ModsPath,
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug'
)

. (Join-Path $PSScriptRoot 'common.ps1')
$adapterRoot = Get-AdapterRoot
$GamePath = Assert-ExplicitDirectory $GamePath 'GamePath'
if (-not $ModsPath) { $ModsPath = Join-Path $GamePath 'Mods' }
$ModsPath = Assert-ExplicitDirectory $ModsPath 'ModsPath'
Assert-NoReparsePointAncestry $ModsPath 'ModsPath'
if (Get-Process -Name 'Stardew Valley', 'StardewModdingAPI' -ErrorAction SilentlyContinue) { throw 'Close Stardew Valley and SMAPI before installing the adapter.' }

& (Join-Path $PSScriptRoot 'build-adapter.ps1') -GamePath $GamePath -ProtocolRepository $ProtocolRepository -ProtocolDir $ProtocolDir -Configuration $Configuration
$output = Join-Path $adapterRoot "bin\$Configuration"
$payloadFiles = Get-AdapterPayloadFiles
foreach ($relative in $payloadFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $output $relative) -PathType Leaf)) { throw "Required install output missing: $relative" }
}
$targetPath = Join-Path $ModsPath 'GameAgentStardew'
Assert-SafePayloadDestinations $ModsPath 'GameAgentStardew' $payloadFiles
New-Item -ItemType Directory -Force -Path $targetPath | Out-Null
foreach ($relative in $payloadFiles) {
    $destination = Join-Path $targetPath $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -LiteralPath (Join-Path $output $relative) -Destination $destination -Force
}
Write-Host "Stardew adapter installed to: $targetPath"
