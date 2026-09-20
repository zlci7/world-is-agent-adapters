$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\common.ps1')

$scratch = Join-Path ([IO.Path]::GetTempPath()) ("wia-stardew-install-safety-" + [guid]::NewGuid().ToString('N'))
$mods = Join-Path $scratch 'Mods'
$target = Join-Path $mods 'GameAgentStardew'
$external = Join-Path $scratch 'external'
try {
    New-Item -ItemType Directory -Force -Path $target, $external | Out-Null
    Set-Content -LiteralPath (Join-Path $target 'config.json') -Value 'keep-current'
    Set-Content -LiteralPath (Join-Path $external 'landmarks.json') -Value 'keep-external'
    New-Item -ItemType Junction -Path (Join-Path $target 'assets') -Target $external | Out-Null

    try {
        Assert-SafePayloadDestinations $mods 'GameAgentStardew' @('manifest.json', 'assets\landmarks.json')
        throw 'Junction destination unexpectedly passed preflight.'
    }
    catch {
        if ($_.Exception.Message -eq 'Junction destination unexpectedly passed preflight.') { throw }
        if ($_.Exception.Message -notmatch '(?i)(junction|reparse)') { throw }
    }
    if ((Get-Content -Raw (Join-Path $target 'config.json')).Trim() -ne 'keep-current') { throw 'Existing installation changed during failed preflight.' }
    if ((Get-Content -Raw (Join-Path $external 'landmarks.json')).Trim() -ne 'keep-external') { throw 'External junction target changed during failed preflight.' }

    Remove-Item -LiteralPath (Join-Path $target 'assets') -Force
    New-Item -ItemType Directory -Force -Path (Join-Path $target 'assets') | Out-Null
    $fileLinkCreated = $false
    try {
        New-Item -ItemType SymbolicLink -Path (Join-Path $target 'assets\landmarks.json') -Target (Join-Path $external 'landmarks.json') -ErrorAction Stop | Out-Null
        $fileLinkCreated = $true
    }
    catch {
        if ($_.Exception.Message -notmatch '(?i)(privilege|privileg|administrator)') { throw }
        Write-Host 'SKIP: file symlink creation requires Windows developer mode or elevation.'
    }
    if ($fileLinkCreated) {
        try {
            Assert-SafePayloadDestinations $mods 'GameAgentStardew' @('manifest.json', 'assets\landmarks.json')
            throw 'File symlink destination unexpectedly passed preflight.'
        }
        catch {
            if ($_.Exception.Message -eq 'File symlink destination unexpectedly passed preflight.') { throw }
            if ($_.Exception.Message -notmatch '(?i)(junction|reparse)') { throw }
        }
    }
    if ((Get-Content -Raw (Join-Path $external 'landmarks.json')).Trim() -ne 'keep-external') { throw 'External symlink target changed during failed preflight.' }
    Write-Host 'Install destination safety check passed.'
}
finally {
    $junction = Join-Path $target 'assets'
    $fileLink = Join-Path $junction 'landmarks.json'
    if (Test-Path -LiteralPath $fileLink) { Remove-Item -LiteralPath $fileLink -Force }
    if (Test-Path -LiteralPath $junction) { Remove-Item -LiteralPath $junction -Force -Recurse }
    if (Test-Path -LiteralPath $scratch) { [IO.Directory]::Delete($scratch, $true) }
}
