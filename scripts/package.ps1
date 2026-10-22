# Packs the addon folder into dist\Klarsicht-<version>.zip.
# The version comes from the "## Version:" line of Klarsicht.toc.
$root = Split-Path -Parent $PSScriptRoot
$toc = Get-Content (Join-Path $root 'Klarsicht\Klarsicht.toc')
$version = ($toc | Where-Object { $_ -match '^## Version:' }) -replace '^## Version:\s*', ''
if (-not $version) { throw 'No "## Version:" line in Klarsicht.toc' }

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$zip = Join-Path $dist "Klarsicht-$version.zip"
if (Test-Path $zip) { Remove-Item $zip }

# Windows' own tar.exe (not Git's GNU tar, which may come first on PATH)
# writes forward slashes into the zip, which every unzip tool accepts.
$tar = Join-Path $env:SystemRoot 'System32\tar.exe'
Push-Location $root
try { & $tar -a -c -f $zip Klarsicht } finally { Pop-Location }
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $zip)) { throw "Packing failed: $zip" }
Write-Output $zip
