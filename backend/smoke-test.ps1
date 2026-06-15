$ErrorActionPreference = "Stop"

$BaseUrl = $env:TRAFFIC_API_BASE
if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  $BaseUrl = "http://127.0.0.1:8000"
}

function Invoke-TrafficApi {
  param(
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][string]$Path,
    [object]$Body = $null
  )

  $uri = "$BaseUrl$Path"
  if ($null -eq $Body) {
    return Invoke-RestMethod -Method $Method -Uri $uri
  }

  return Invoke-RestMethod `
    -Method $Method `
    -Uri $uri `
    -ContentType "application/json" `
    -Body ($Body | ConvertTo-Json -Depth 10)
}

Write-Host "Checking Traffic Light MVP API at $BaseUrl"

$health = Invoke-TrafficApi -Method GET -Path "/api/health"
Write-Host "Health:" $health.status

$status = Invoke-TrafficApi -Method GET -Path "/api/intersections/1/status"
Write-Host "Initial mode:" $status.data.modeCode

$dashboard = Invoke-TrafficApi -Method GET -Path "/api/intersections/1/dashboard"
Write-Host "Dashboard roads:" $dashboard.data.approaches.Count

$command = Invoke-TrafficApi -Method POST -Path "/api/intersections/1/commands" -Body @{
  command = "SET_NIGHT"
  source = "smoke-test"
  createdBy = "operator"
}
Write-Host "Command result:" $command.data.command $command.data.status

$history = Invoke-TrafficApi -Method GET -Path "/api/intersections/1/commands?limit=5"
Write-Host "History rows:" $history.data.Count

$phasePlans = Invoke-TrafficApi -Method GET -Path "/api/intersections/1/phase-plans"
Write-Host "Phase plans:" $phasePlans.data.Count

$approaches = Invoke-TrafficApi -Method GET -Path "/api/intersections/1/approaches"
Write-Host "Approaches:" $approaches.data.Count

Write-Host "Smoke test completed."
