param(
    [string]$Root = (Join-Path $PSScriptRoot '..')
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath $Root).Path
$violations = New-Object System.Collections.Generic.List[string]

foreach ($gameDirectory in Get-ChildItem -LiteralPath $Root -Directory) {
    if (-not (Get-ChildItem -LiteralPath $gameDirectory.FullName -Filter '*.csproj' -File)) {
        continue
    }
    $sources = Get-ChildItem -LiteralPath $gameDirectory.FullName -Recurse -File |
        Where-Object {
            $_.Extension -in @('.cs', '.csproj', '.props', '.targets') -and
            $_.FullName -notmatch '[\\/](bin|obj|\.local|dist)[\\/]'
        }
    foreach ($source in $sources) {
        $matches = Select-String -LiteralPath $source.FullName -Pattern 'runtime[/\\]internal|runtime\.internal' -CaseSensitive:$false
        foreach ($match in $matches) {
            $violations.Add("$($match.Path):$($match.LineNumber): Adapter references Runtime internals")
        }
    }
}

if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Host $_ }
    exit 1
}
Write-Host 'Adapter architecture check passed.'
