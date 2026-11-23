<#
.SYNOPSIS
  Bumps the pubspec build number and runs a Flutter release build.

.DESCRIPTION
  Increments the +N build number in pubspec.yaml (which becomes Android
  versionCode via the Flutter Gradle plugin), then runs the requested release
  build. Fails fast when release signing is not configured so a build number
  is never consumed by a doomed build. If the build fails, the bump is rolled
  back. Actual output files and sizes are reported after a successful build.

.EXAMPLE
  .\build_release.ps1
  Bump build number and build a release APK.

.EXAMPLE
  .\build_release.ps1 -Target AppBundle
  Bump build number and build a release App Bundle (.aab) for Play Store.

.EXAMPLE
  .\build_release.ps1 -Fast -NoBump
  Build only the arm64 APK - one AOT compile instead of four. Best for device testing.

.EXAMPLE
  .\build_release.ps1 -SplitPerAbi
  Build one small APK per CPU architecture (~35-40 MB each instead of ~95 MB).

.EXAMPLE
  .\build_release.ps1 -DryRun -NoBump
  Show what would happen without changing pubspec.yaml or building.

.EXAMPLE
  .\build_release.ps1 -Target Both -NoBump -- --dart-define=ENV=prod
  Build APK + AAB without bumping; extra args after -- go to flutter.
#>
param(
    [ValidateSet('Apk', 'AppBundle', 'Both')]
    [string]$Target = 'Apk',
    [switch]$NoBump,
    [switch]$Fast,
    [switch]$SplitPerAbi,
    [switch]$DryRun,
    [string[]]$FlutterArgs = @()
)

$ErrorActionPreference = 'Stop'

if ($Fast -and $SplitPerAbi) {
    throw "-Fast and -SplitPerAbi are mutually exclusive: -Fast builds one ABI, -SplitPerAbi builds all four."
}

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$keyPropertiesPath = Join-Path $projectRoot 'android/key.properties'
$apkDir = Join-Path $projectRoot 'build/app/outputs/flutter-apk'
$aabDir = Join-Path $projectRoot 'build/app/outputs/bundle/release'

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
    if (-not $DryRun) {
        Set-Content -Path $pubspecPath -Value $updatedContent -NoNewline -Encoding utf8
    }
    Write-Host "pubspec.yaml version: $major.$minor.$patch+$buildNumber"
} else {
    Write-Host "pubspec.yaml version: $major.$minor.$patch+$buildNumber (no bump)"
}

$versionName = "$major.$minor.$patch"
Write-Host "Building version $versionName+$buildNumber (target: $Target, fast: $Fast, splitPerAbi: $SplitPerAbi)"

if ($DryRun) {
    Write-Host 'Dry run: no files written, no build started.'
    exit 0
}

$targets = if ($Target -eq 'Both') {
    @('apk', 'appbundle')
} elseif ($Target -eq 'AppBundle') {
    @('appbundle')
} else {
    @('apk')
}

try {
    foreach ($t in $targets) {
        $buildArgs = @($t, '--release')
        if ($Fast -and $t -eq 'apk') {
            $buildArgs += @('--target-platform', 'android-arm64')
        }
        if ($SplitPerAbi -and $t -eq 'apk') {
            $buildArgs += '--split-per-abi'
        }
        $buildArgs += $FlutterArgs
        Write-Host "Running: flutter $($buildArgs -join ' ')"
        & flutter build @buildArgs
        if ($LASTEXITCODE -ne 0) {
            throw "flutter build $t --release failed with exit code $LASTEXITCODE"
        }
    }
} catch {
    # A failed build must not consume a version code. Restore the exact bytes
    # we replaced so the next attempt can reuse this build number.
    if (-not $NoBump) {
        Set-Content -Path $pubspecPath -Value $pubspecContent -NoNewline -Encoding utf8
        Write-Warning "Build failed - restored pubspec.yaml to $major.$minor.$patch+$(($buildNumber - 1))."
    }
    throw
}

# Report what was actually produced instead of guessing the output filename -
# Gradle owns that name and it has changed between AGP versions.
if ($targets -contains 'apk') {
    $apks = Get-ChildItem -Path $apkDir -Filter '*.apk' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    if (-not $apks) {
        Write-Warning "No APK found in $apkDir"
    }
    foreach ($f in $apks) {
        Write-Host ("APK: {0} ({1:N1} MB, {2})" -f $f.FullName, ($f.Length / 1MB), $f.LastWriteTime)
    }
}
if ($targets -contains 'appbundle') {
    $aabs = Get-ChildItem -Path $aabDir -Filter '*.aab' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    if (-not $aabs) {
        Write-Warning "No AAB found in $aabDir"
    }
    foreach ($f in $aabs) {
        Write-Host ("AAB: {0} ({1:N1} MB, {2})" -f $f.FullName, ($f.Length / 1MB), $f.LastWriteTime)
    }
}
