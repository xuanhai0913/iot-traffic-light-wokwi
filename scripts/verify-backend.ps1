$ErrorActionPreference = "Stop"

# Runs dotnet build + dotnet test for the C# backend using the
# portable .NET SDK shipped in the repo's .dotnet/ folder.
#
# Usage (from repo root):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-backend.ps1

$repoRoot = (Get-Location).Path
$dotnet = Join-Path $repoRoot ".dotnet\dotnet.exe"
$backend = Join-Path $repoRoot "backend\TrafficLightMvp.csproj"
$tests = Join-Path $repoRoot "backend\tests\TrafficLightMvp.IntegrationTests\TrafficLightMvp.IntegrationTests.csproj"

if (-not (Test-Path -LiteralPath $dotnet)) {
    throw "dotnet not found at $dotnet. Re-run ./scripts/setup-portable.ps1 if needed."
}
if (-not (Test-Path -LiteralPath $backend)) {
    throw "backend project not found at $backend"
}
if (-not (Test-Path -LiteralPath $tests)) {
    throw "integration test project not found at $tests"
}

Write-Host "=== dotnet build (--no-restore) ==="
& $dotnet build $backend --no-restore 2>&1 | Out-Host
$buildExit = $LASTEXITCODE
Write-Host "build exit: $buildExit"
if ($buildExit -ne 0) {
    throw "dotnet build failed with exit $buildExit"
}

Write-Host ""
Write-Host "=== dotnet test (--no-restore) ==="
& $dotnet test $tests --no-restore 2>&1 | Out-Host
$testExit = $LASTEXITCODE
Write-Host "test exit: $testExit"
if ($testExit -ne 0) {
    throw "dotnet test failed with exit $testExit"
}

Write-Host ""
Write-Host "Backend build + tests passed."
exit 0
