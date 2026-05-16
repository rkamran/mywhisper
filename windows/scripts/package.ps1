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

Write-Host "==> Publishing MyWhisper $version ($Runtime, self-contained)..."
dotnet publish $csproj `
    -c Release `
    -r $Runtime `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -o $publishD

$exe = Join-Path $publishD 'MyWhisper.exe'
if (-not (Test-Path $exe)) {
    Write-Error "Build failed -- MyWhisper.exe not found in $publishD"
    exit 1
}

# Copy VC++ runtime DLLs from the build machine into the publish output for
# app-local deployment. Microsoft permits this per the VC++ Redistributable
# license. Without these alongside MyWhisper.exe, recipients without the
# VC++ Redistributable installed hit "Cannot load the library on this
# platform" when Whisper.net's native whisper.dll calls LoadLibrary.
Write-Host "==> Copying VC++ runtime DLLs for app-local deployment..."
$vcDlls = @('VCRUNTIME140.dll', 'VCRUNTIME140_1.dll', 'MSVCP140.dll')
$missing = @()
foreach ($dll in $vcDlls) {
    $src = Join-Path $env:WINDIR "System32\$dll"
    if (Test-Path $src) {
        Copy-Item $src $publishD -Force
    } else {
        $missing += $dll
    }
}
if ($missing.Count -gt 0) {
    Write-Warning ("VC++ runtime DLLs missing on this build machine: {0}" -f ($missing -join ', '))
    Write-Warning "Install with: winget install Microsoft.VCRedist.2015+.x64"
    Write-Warning "The shipped zip will require recipients to install the VC++ Redistributable themselves."
}

# Copy license + attribution files into the publish output so they end up
# inside both the zip and the Inno Setup installer (the .iss [Files] section
# packs everything in $publishD).
Write-Host "==> Copying license + attribution files..."
$repoRoot = Split-Path -Parent $projDir
$licenseFiles = @(
    @{ Src = Join-Path $repoRoot 'LICENSE';                  Dest = 'LICENSE.txt' },
    @{ Src = Join-Path $repoRoot 'THIRD_PARTY_LICENSES.md';  Dest = 'THIRD_PARTY_LICENSES.md' }
)
foreach ($f in $licenseFiles) {
    if (Test-Path $f.Src) {
        Copy-Item $f.Src (Join-Path $publishD $f.Dest) -Force
    } else {
        Write-Warning ("License file missing at {0}; skipping." -f $f.Src)
    }
}

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$zipPath = Join-Path $distDir "MyWhisper-$version-$Runtime.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath }

Write-Host "==> Zipping to $zipPath..."
Compress-Archive -Path (Join-Path $publishD '*') -DestinationPath $zipPath

$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-Host ""
Write-Host ("OK  Wrote {0} ({1} MB)" -f $zipPath, $sizeMB)

# Optional: also build an Inno Setup installer if iscc.exe is available.
# Install with:  winget install JRSoftware.InnoSetup
# Inno Setup's installer doesn't add iscc.exe to PATH, so we fall back to
# probing the standard install locations after the PATH lookup.
$isccPath = $null
$cmd = Get-Command iscc.exe -ErrorAction SilentlyContinue
if ($cmd) { $isccPath = $cmd.Source }
if (-not $isccPath) {
    $probes = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\iscc.exe",
        "$env:ProgramFiles\Inno Setup 6\iscc.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\iscc.exe"
    )
    foreach ($probe in $probes) {
        if ($probe -and (Test-Path $probe)) {
            $isccPath = $probe
            break
        }
    }
}

if ($isccPath) {
    Write-Host ""
    Write-Host "==> Building Inno Setup installer..."
    Write-Host "    iscc: $isccPath"
    $issPath = Join-Path $projDir 'installer\MyWhisper.iss'
    $publishAbs = (Resolve-Path $publishD).Path
    & $isccPath `
        "/Q" `
        "/DProductVersion=$version" `
        "/DPublishDir=$publishAbs" `
        $issPath
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Inno Setup compilation failed (exit $LASTEXITCODE). Zip is still good."
    } else {
        $setupExe = Join-Path $distDir "MyWhisper-$version-Setup.exe"
        if (Test-Path $setupExe) {
            $setupMB = [math]::Round((Get-Item $setupExe).Length / 1MB, 1)
            Write-Host ("OK  Wrote {0} ({1} MB)" -f $setupExe, $setupMB)
        }
    }
} else {
    Write-Host ""
    Write-Host "Skipping installer build -- Inno Setup not found."
    Write-Host "  Install with:  winget install JRSoftware.InnoSetup"
    Write-Host "  Then re-run this script to produce a setup .exe alongside the zip."
}

Write-Host ""
Write-Host "Share with recipients:"
Write-Host "  * Zip: extract anywhere and run MyWhisper.exe (portable)"
Write-Host "  * Setup.exe (if built): wizard installer with Start Menu shortcut, uninstaller, optional run-at-login"
Write-Host "  * SmartScreen may warn on either (unsigned) -> More info -> Run anyway"
