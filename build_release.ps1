param(
    [string[]]$FlutterArgs = @()
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'

if (-not (Test-Path $pubspecPath)) {
    throw "pubspec.yaml not found at $pubspecPath"
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
$buildNumber = [int]$match.Groups[4].Value + 1
$newVersion = "version: $major.$minor.$patch+$buildNumber"

$updatedContent = [regex]::Replace($pubspecContent, $versionPattern, $newVersion)
Set-Content -Path $pubspecPath -Value $updatedContent -NoNewline

Write-Host "Updated pubspec.yaml to $major.$minor.$patch+$buildNumber"

& flutter build apk --release @FlutterArgs
