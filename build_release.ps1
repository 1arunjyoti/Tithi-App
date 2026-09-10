<#
.SYNOPSIS
  Bumps the pubspec build number and runs a Flutter release build.

.DESCRIPTION
  Increments the +N build number in pubspec.yaml (which becomes Android
  versionCode / versionName via the Flutter Gradle plugin), then runs the
  requested release build. Fails fast when release signing is not
  configured so a build number is never consumed by a doomed build.

.EXAMPLE
  .\build_release.ps1
  Bump build number and build a release APK.

.EXAMPLE
  .\build_release.ps1 -Target AppBundle
  Bump build number and build a release App Bundle (.aab) for Play Store.

.EXAMPLE
  .\build_release.ps1 -Target Both -NoBump -- --dart-define=ENV=prod
  Build APK + AAB without bumping; extra args after -- go to flutter.
#>
param(
    [ValidateSet('Apk', 'AppBundle', 'Both')]
    [string]$Target = 'Apk',
    [switch]$NoBump,
    [string[]]$FlutterArgs = @()
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$keyPropertiesPath = Join-Path $projectRoot 'android/key.properties'

if (-not (Test-Path $pubspecPath)) {
    throw "pubspec.yaml not found at $pubspecPath"
}

# Fail fast before consuming a build number: release builds require signing
# (see android/app/build.gradle.kts). Accept key.properties or env vars.
$signingConfigured = (Test-Path -LiteralPath $keyPropertiesPath) -or (
    $env:TITHI_RELEASE_STORE_FILE -and $env:TITHI_RELEASE_STORE_PASSWORD -and
    $env:TITHI_RELEASE_KEY_ALIAS -and $env:TITHI_RELEASE_KEY_PASSWORD
)
if (-not $signingConfigured) {
    throw "Release signing is not configured. Add android/key.properties or set TITHI_RELEASE_STORE_FILE / TITHI_RELEASE_STORE_PASSWORD / TITHI_RELEASE_KEY_ALIAS / TITHI_RELEASE_KEY_PASSWORD."
}

$pubspecContent = Get-Content $pubspecPath -Raw
$versionPattern = '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$'
$match = [regex]::Match($pubspecContent, $versionPattern)

if (-not $match.Success) {
    throw "Could not find a version line in pubspec.yaml"
}

$major = [int]$match.Groups[1].Value
$minor = [int]$match.Groups[2].Value
$patch = [int]$match.Groups[3].Value
$buildNumber = [int]$match.Groups[4].Value
if (-not $NoBump) {
    $buildNumber++
    $updatedContent = [regex]::Replace($pubspecContent, $versionPattern, "version: $major.$minor.$patch+$buildNumber")
    Set-Content -Path $pubspecPath -Value $updatedContent -NoNewline -Encoding utf8
    Write-Host "Updated pubspec.yaml to $major.$minor.$patch+$buildNumber"
}

$versionName = "$major.$minor.$patch"
Write-Host "Building version $versionName+$buildNumber (target: $Target)"

$targets = if ($Target -eq 'Both') {
    @('apk', 'appbundle')
} elseif ($Target -eq 'AppBundle') {
    @('appbundle')
} else {
    @('apk')
}
foreach ($t in $targets) {
    Write-Host "Running: flutter build $t --release"
    & flutter build $t --release @FlutterArgs
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build $t --release failed with exit code $LASTEXITCODE"
    }
}

if ($targets -contains 'apk') {
    Write-Host "APK: build/app/outputs/flutter-apk/tithi-$versionName+$buildNumber-release.apk"
}
if ($targets -contains 'appbundle') {
    Write-Host "AAB: build/app/outputs/bundle/release/"
}
