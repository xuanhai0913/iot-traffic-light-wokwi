$ErrorActionPreference = "Stop"

# Runs flutter analyze and flutter test against the Flutter operator app,
# using a T: subst drive to bypass the Unicode OneDrive path that breaks
# the Gradle wrapper and several Flutter Windows sub-commands.
#
# Usage (from repo root):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-flutter.ps1

$repoRoot = (Get-Location).Path
Write-Host "Repo root: $repoRoot"

$flutterAppRelative = "flutter_app"
$flutterBatRelative = ".flutter\bin\flutter.bat"
$workspaceDrive = "T:"

# If T: is already mapped, only continue if it points at this repo.
$mappings = & subst.exe 2>&1
foreach ($line in $mappings) {
    if ($line -match "^T:\\s*=>\\s*(.+)$") {
        $target = $Matches[1].TrimEnd('\')
        $expected = $repoRoot.TrimEnd('\')
        if ($target -ne $expected) {
            throw "T: is mapped to '$target', not this repo. Unmap first with: subst T: /D"
        }
        break
    }
}

# Create T: mapping if it does not exist yet.
$flutterAppOnT = "T:\$flutterAppRelative"
if (-not (Test-Path -LiteralPath $flutterAppOnT)) {
    Write-Host "Creating T: subst -> $repoRoot"
    & subst.exe T: $repoRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to subst T:. Check whether the drive is in use by another process."
    }
}

if (-not (Test-Path -LiteralPath $flutterAppOnT)) {
    throw "$flutterAppOnT is not reachable after subst"
}

# Remove any stale build dir that may hold a Windows lock from a prior run.
$staleBuild = "$flutterAppOnT\build"
if (Test-Path -LiteralPath $staleBuild) {
    Write-Host "Removing stale build dir: $staleBuild"
    try {
        Remove-Item -LiteralPath $staleBuild -Recurse -Force -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not fully remove $staleBuild (file lock). Continuing without it: $($_.Exception.Message)"
    }
}

Push-Location $flutterAppOnT
try {
    Write-Host ""
    Write-Host "=== flutter analyze ==="
    & "T:\$flutterBatRelative" analyze 2>&1 | Out-Host
    $analyzeExit = $LASTEXITCODE
    Write-Host "=== analyze exit: $analyzeExit ==="

    if ($analyzeExit -ne 0) {
        throw "flutter analyze failed with exit $analyzeExit"
    }

    Write-Host ""
    Write-Host "=== flutter test ==="
    & "T:\$flutterBatRelative" test 2>&1 | Out-Host
    $testExit = $LASTEXITCODE
    Write-Host "=== test exit: $testExit ==="

    if ($testExit -ne 0) {
        throw "flutter test failed with exit $testExit"
    }

    Write-Host ""
    Write-Host "Flutter analyze + test passed."
    exit 0
}
finally {
    Pop-Location
}
