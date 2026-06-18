$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$workspaceDrive = "T:"
if (-not (Test-Path -LiteralPath "$workspaceDrive\")) {
    & subst.exe $workspaceDrive $repoRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Could not create workspace drive alias $workspaceDrive"
    }
}

if (-not (Test-Path -LiteralPath "$workspaceDrive\.flutter")) {
    throw "$workspaceDrive is already in use and does not point to this repository"
}

$flutterRoot = "$workspaceDrive\.flutter"
$toolchainRoot = "$workspaceDrive\.android-toolchain"
$javaHome = Get-ChildItem -LiteralPath (Join-Path $toolchainRoot "jdk") -Directory |
    Select-Object -First 1 -ExpandProperty FullName
$androidHome = Join-Path $toolchainRoot "sdk"
$flutter = Join-Path $flutterRoot "bin\flutter.bat"
$source = Join-Path $repoRoot "flutter_app"
$buildRoot = Join-Path $env:LOCALAPPDATA "IoTTrafficLight\flutter-build"
$output = Join-Path $repoRoot "dist\android\iot-traffic-light-v1.0.0.apk"

if (-not (Test-Path -LiteralPath $flutter)) {
    throw "Flutter SDK not found at $flutter"
}

if (-not $javaHome -or -not (Test-Path -LiteralPath $androidHome)) {
    throw "Portable Android toolchain is missing under $toolchainRoot"
}

$expectedBuildRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $env:LOCALAPPDATA "IoTTrafficLight\flutter-build")
)
$resolvedBuildRoot = [System.IO.Path]::GetFullPath($buildRoot)
if ($resolvedBuildRoot -ne $expectedBuildRoot) {
    throw "Refusing to clean unexpected build path: $resolvedBuildRoot"
}

if (Test-Path -LiteralPath $resolvedBuildRoot) {
    Remove-Item -LiteralPath $resolvedBuildRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedBuildRoot | Out-Null

$robocopyArgs = @(
    $source,
    $resolvedBuildRoot,
    "/E",
    "/XD", "build", ".dart_tool",
    "/XF", ".flutter-plugins", ".flutter-plugins-dependencies",
    "/NFL", "/NDL", "/NJH", "/NJS", "/NP"
)
& robocopy.exe @robocopyArgs | Out-Null
if ($LASTEXITCODE -gt 7) {
    throw "Could not stage Flutter project. Robocopy exit code: $LASTEXITCODE"
}

$localProperties = @(
    "sdk.dir=$($androidHome.Replace('\', '\\'))",
    "flutter.sdk=$($flutterRoot.Replace('\', '\\'))"
)
Set-Content -LiteralPath (
    Join-Path $resolvedBuildRoot "android\local.properties"
) -Value $localProperties -Encoding Ascii

$env:JAVA_HOME = $javaHome
$env:ANDROID_HOME = $androidHome
$env:ANDROID_SDK_ROOT = $androidHome
$env:PATH = "$javaHome\bin;$androidHome\platform-tools;$env:PATH"

Push-Location $resolvedBuildRoot
try {
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw "flutter pub get failed with exit code $LASTEXITCODE"
    }

    & $flutter analyze
    if ($LASTEXITCODE -ne 0) {
        throw "flutter analyze failed with exit code $LASTEXITCODE"
    }

    & $flutter test
    if ($LASTEXITCODE -ne 0) {
        throw "flutter test failed with exit code $LASTEXITCODE"
    }

    & $flutter build apk --release
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build apk failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) |
    Out-Null
Copy-Item -LiteralPath (
    Join-Path $resolvedBuildRoot "build\app\outputs\flutter-apk\app-release.apk"
) -Destination $output -Force

$artifact = Get-Item -LiteralPath $output
Write-Host "APK ready: $($artifact.FullName)"
Write-Host "Size: $([math]::Round($artifact.Length / 1MB, 1)) MB"
