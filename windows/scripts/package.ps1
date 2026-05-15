# Builds MyWhisper for Windows as a self-contained single-file executable and
# zips it for distribution. Run from anywhere:  pwsh windows/scripts/package.ps1
# Requires the .NET 8 SDK.

param(
    [ValidateSet('win-x64', 'win-arm64')]
    [string]$Runtime = 'win-x64'
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projDir   = Split-Path -Parent $scriptDir          # windows/
$csproj    = Join-Path $projDir 'MyWhisper\MyWhisper.csproj'
$distDir   = Join-Path $projDir 'dist'
$publishD  = Join-Path $projDir ".publish\$Runtime"

# Version comes from the .csproj <Version> element.
[xml]$proj = Get-Content $csproj
$version = $proj.Project.PropertyGroup.Version | Select-Object -First 1
if (-not $version) { $version = '1.0.0' }

Write-Host "==> Publishing MyWhisper $version ($Runtime, self-contained)…"
dotnet publish $csproj `
    -c Release `
    -r $Runtime `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -o $publishD

$exe = Join-Path $publishD 'MyWhisper.exe'
if (-not (Test-Path $exe)) {
    Write-Error "Build failed — MyWhisper.exe not found in $publishD"
    exit 1
}

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$zipPath = Join-Path $distDir "MyWhisper-$version-$Runtime.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath }

Write-Host "==> Zipping to $zipPath…"
Compress-Archive -Path (Join-Path $publishD '*') -DestinationPath $zipPath

$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-Host ""
Write-Host ("OK  Wrote {0} ({1} MB)" -f $zipPath, $sizeMB)
Write-Host ""
Write-Host "Share that zip. Tell the recipient:"
Write-Host "  1. Extract anywhere and run MyWhisper.exe"
Write-Host "  2. SmartScreen may warn (unsigned app) -> More info -> Run anyway"
Write-Host "  3. The setup window walks through downloading a Whisper model"
Write-Host "     (148 MB to 3 GB depending on the size you pick)"
