$ErrorActionPreference = 'Stop'

$adapterRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Require-File([string]$RelativePath) {
    $path = Join-Path $adapterRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required file missing: $RelativePath"
    }
}

function Require-Content([string]$RelativePath, [string]$Pattern, [string]$Message) {
    $path = Join-Path $adapterRoot $RelativePath
    if (-not (Select-String -LiteralPath $path -Pattern $Pattern -Quiet)) {
        throw $Message
    }
}

function Reject-Content([string]$RelativePath, [string]$Pattern, [string]$Message) {
    $path = Join-Path $adapterRoot $RelativePath
    if (Select-String -LiteralPath $path -Pattern $Pattern -Quiet) {
        throw $Message
    }
}

@('VERSION', 'protocol.version', 'scripts/build-adapter.ps1', 'scripts/test-adapter.ps1',
  'scripts/release-adapter.ps1', 'scripts/install-stardew-adapter.ps1') | ForEach-Object { Require-File $_ }

$version = (Get-Content -Raw (Join-Path $adapterRoot 'VERSION')).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "VERSION must be semantic: $version" }
$protocolPin = (Get-Content -Raw (Join-Path $adapterRoot 'protocol.version')).Trim()
if ($protocolPin -notmatch '^protocol-[A-Za-z0-9._-]+$') { throw "Invalid protocol.version tag: $protocolPin" }

Reject-Content 'GameAgent.Stardew.csproj' '<GamePath Condition=' 'GamePath must be explicit.'
Reject-Content 'GameAgent.Stardew.csproj' '<WIA_PROTOCOL_DIR Condition=' 'WIA_PROTOCOL_DIR must be explicit.'
Require-Content 'GameAgent.Stardew.csproj' 'AssemblyInformationalVersion>\$\(AdapterVersion\)' 'The assembly informational version must come from VERSION.'
Require-Content 'src/Runtime/RuntimeClient.cs' 'AdapterIdentity\.BuildHello' 'AdapterHello must use generated build identity.'
Require-Content 'src/Runtime/AdapterIdentity.cs' 'AdapterBuildInfo\.Version' 'Adapter identity must use generated build version metadata.'
Reject-Content 'src/Runtime/RuntimeClient.cs' 'this\.config\.AdapterVersion' 'AdapterHello must not use user configuration as its version source.'
Reject-Content 'src/Runtime/AdapterConfig.cs' 'AdapterVersion' 'Adapter version must not be configurable.'

Write-Host 'Stardew release contract checks passed.'
