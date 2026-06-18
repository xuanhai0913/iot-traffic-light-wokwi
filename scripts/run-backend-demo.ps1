param(
    [int]$Port = 8000,
    [switch]$NoMqtt,
    [switch]$DryRun,
    [string]$MqttHost = "broker.hivemq.com",
    [int]$MqttPort = 1883,
    [string]$TopicPrefix = "traffic/hainx-iot-traffic-light"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$backendProject = Join-Path $repoRoot "backend\TrafficLightMvp.csproj"
$portableDotnet = Join-Path $repoRoot ".dotnet\dotnet.exe"
$dotnet = "dotnet"

if (Test-Path -LiteralPath $portableDotnet) {
    $dotnet = $portableDotnet
}

if (-not (Test-Path -LiteralPath $backendProject)) {
    throw "Backend project not found: $backendProject"
}

$listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($listeners) {
    Write-Warning "Port $Port is already in use. Stop the existing backend or rerun with -Port <other-port>."
}

$lanIps = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254.*"
    } |
    Sort-Object InterfaceAlias, IPAddress

Write-Host "Traffic Light backend demo"
Write-Host "Repository: $repoRoot"
Write-Host "Backend URL on this PC: http://127.0.0.1:$Port"

if ($lanIps) {
    Write-Host ""
    Write-Host "Use one of these URLs on a real phone on the same WiFi/LAN:"
    foreach ($ip in $lanIps) {
        Write-Host ("  {0,-22} http://{1}:{2}" -f $ip.InterfaceAlias, $ip.IPAddress, $Port)
    }
}
else {
    Write-Warning "No LAN IPv4 address was found. Check WiFi/LAN before testing a physical phone."
}

$env:PORT = "$Port"
$env:MQTT_ENABLED = if ($NoMqtt) { "false" } else { "true" }
$env:MQTT_HOST = $MqttHost
$env:MQTT_PORT = "$MqttPort"
$env:MQTT_TOPIC_PREFIX = $TopicPrefix

Write-Host ""
Write-Host "MQTT enabled: $($env:MQTT_ENABLED)"
Write-Host "MQTT broker: ${MqttHost}:$MqttPort"
Write-Host "MQTT topic prefix: $TopicPrefix"
Write-Host ""
Write-Host "Health check after startup:"
Write-Host "  http://127.0.0.1:$Port/api/health"
Write-Host "  http://127.0.0.1:$Port/api/mqtt/status"
Write-Host ""

if ($DryRun) {
    Write-Host "Dry run complete. Backend was not started."
    exit 0
}

Write-Host "Starting backend. Keep this terminal open during the demo."

& $dotnet run --project $backendProject
