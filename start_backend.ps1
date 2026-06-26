param(
    [switch]$ForcePortKill
)

$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$backend = Join-Path $repoRoot "backend\TrafficLightMvp.csproj"
$dotnet = Join-Path $repoRoot ".dotnet\dotnet.exe"

if (-not (Test-Path -LiteralPath $backend)) {
    throw "backend not found"
}
if (-not (Test-Path -LiteralPath $dotnet)) {
    throw ".dotnet/dotnet.exe not found"
}

# Free port 8000 only when explicitly requested.
$existing = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
if ($existing) {
    $pids = ($existing | Select-Object -ExpandProperty OwningProcess -Unique) -join ", "
    if (-not $ForcePortKill) {
        throw "Port 8000 is already in use by PID(s): $pids. Stop it manually or rerun with -ForcePortKill."
    }

    foreach ($c in $existing) {
        Write-Warning "Port 8000 in use by PID $($c.OwningProcess). Stopping."
        try {
            Stop-Process -Id $c.OwningProcess -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Could not stop PID $($c.OwningProcess): $($_.Exception.Message)"
        }
    }
    Start-Sleep -Seconds 2
}

$env:PORT = "8000"
$env:MQTT_ENABLED = "true"
$env:MQTT_HOST = "broker.hivemq.com"
$env:MQTT_PORT = "1883"
$env:MQTT_TOPIC_PREFIX = "traffic/hainx-iot-traffic-light"
$env:ASPNETCORE_URLS = "http://0.0.0.0:8000"

Write-Host "Starting backend on http://0.0.0.0:8000 with MQTT on broker.hivemq.com:1883"
Write-Host "Logs go to backend_smoke.log. Press Ctrl+C in the parent terminal to stop."

& $dotnet run --project $backend --no-build 2>&1 | Tee-Object -FilePath "$repoRoot\backend_smoke.log"
