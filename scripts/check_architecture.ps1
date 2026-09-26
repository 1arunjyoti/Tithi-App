# Phase 0 architecture guardrails (read-only, exit 1 on violation).
# Usage: pwsh scripts/check_architecture.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Find-Pattern($relPath, $pattern) {
  $full = Join-Path $root $relPath
  Select-String -Path "$full\*.dart","$full\*\*.dart" -Pattern $pattern -ErrorAction SilentlyContinue
}

$violations = @()

# 1. No direct Hive.box() reads in presentation layer (must go via core/storage or repository).
$hiveInUi = @(Find-Pattern "lib\widgets" "Hive\.box\(|Hive\.isBoxOpen") + @(Find-Pattern "lib\screens" "Hive\.box\(|Hive\.isBoxOpen")
if ($hiveInUi.Count -gt 0) {
  Write-Output "WARN: $($hiveInUi.Count) direct Hive access in widgets/screens (migrate to core/storage):"
  $hiveInUi | Select-Object Filename, LineNumber, Line | Format-Table -AutoSize | Out-String -Width 250 | Write-Output
}

# 2. No provider definitions inside widgets/ (providers belong in features/*/providers or lib/providers).
$providersInWidgets = Find-Pattern "lib\widgets" "^\s*final \w+Provider\s*="
if ($providersInWidgets.Count -gt 0) {
  Write-Output "WARN: $($providersInWidgets.Count) providers defined in lib/widgets (move to presentation/providers):"
  $providersInWidgets | Select-Object Filename, LineNumber, Line | Format-Table -AutoSize | Out-String -Width 250 | Write-Output
}

# 3. New core singletons must be used: flag duplicated adapter registration blocks.
$dupAdapters = Select-String -Path "$root\lib\*.dart","$root\lib\*\*.dart","$root\lib\*\*\*.dart" -Pattern "Hive\.registerAdapter\(FestivalAdapter" -ErrorAction SilentlyContinue
if ($dupAdapters.Count -gt 1) {
  Write-Output "FAIL: FestivalAdapter registered in $($dupAdapters.Count) places, use registerHiveAdapters() from core/storage/hive_adapters.dart:"
  $dupAdapters | Select-Object Filename, LineNumber | Format-Table -AutoSize | Out-String -Width 200 | Write-Output
  exit 1
}

Write-Output "Architecture check done."
