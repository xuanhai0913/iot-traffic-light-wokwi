$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$wokwiRoot = Join-Path $repoRoot "wokwi"
$sketchPath = Join-Path $wokwiRoot "sketch.ino"
$diagramPath = Join-Path $wokwiRoot "diagram.json"
$librariesPath = Join-Path $wokwiRoot "libraries.txt"

foreach ($path in @($sketchPath, $diagramPath, $librariesPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required Wokwi file not found: $path"
    }
}

function Test-BraceBalance {
    param([Parameter(Mandatory = $true)][string]$Source)

    $stack = New-Object System.Collections.Stack
    $state = "normal"
    $escaped = $false
    $line = 1
    $col = 0

    $slash = [char]47
    $asterisk = [char]42
    $quote = [char]34
    $singleQuote = [char]39
    $backslash = [char]92
    $lf = [char]10
    $openBrace = [char]123
    $closeBrace = [char]125

    for ($i = 0; $i -lt $Source.Length; $i++) {
        $ch = $Source[$i]
        $next = if ($i + 1 -lt $Source.Length) { $Source[$i + 1] } else { [char]0 }
        $currentColumn = $col + 1

        switch ($state) {
            "line-comment" {
                if ($ch -eq $lf) {
                    $state = "normal"
                }
            }
            "block-comment" {
                if ($ch -eq $asterisk -and $next -eq $slash) {
                    $state = "normal"
                }
            }
            "string" {
                if ($escaped) {
                    $escaped = $false
                }
                elseif ($ch -eq $backslash) {
                    $escaped = $true
                }
                elseif ($ch -eq $quote) {
                    $state = "normal"
                }
            }
            "char" {
                if ($escaped) {
                    $escaped = $false
                }
                elseif ($ch -eq $backslash) {
                    $escaped = $true
                }
                elseif ($ch -eq $singleQuote) {
                    $state = "normal"
                }
            }
            default {
                if ($ch -eq $slash -and $next -eq $slash) {
                    $state = "line-comment"
                }
                elseif ($ch -eq $slash -and $next -eq $asterisk) {
                    $state = "block-comment"
                }
                elseif ($ch -eq $quote) {
                    $state = "string"
                    $escaped = $false
                }
                elseif ($ch -eq $singleQuote) {
                    $state = "char"
                    $escaped = $false
                }
                elseif ($ch -eq $openBrace) {
                    $stack.Push([pscustomobject]@{
                        Line = $line
                        Column = $currentColumn
                    })
                }
                elseif ($ch -eq $closeBrace) {
                    if ($stack.Count -eq 0) {
                        throw "Unmatched closing brace at line $line, column $currentColumn"
                    }
                    [void]$stack.Pop()
                }
            }
        }

        if ($ch -eq $lf) {
            $line++
            $col = 0
        }
        else {
            $col++
        }
    }

    if ($state -eq "block-comment") {
        throw "Unclosed block comment in sketch.ino"
    }

    if ($stack.Count -ne 0) {
        $open = $stack.Peek()
        throw "Unclosed opening brace from line $($open.Line), column $($open.Column)"
    }
}

$diagram = Get-Content -LiteralPath $diagramPath -Raw | ConvertFrom-Json
if (-not $diagram.parts -or $diagram.parts.Count -lt 1) {
    throw "diagram.json does not contain Wokwi parts"
}
if (-not $diagram.connections -or $diagram.connections.Count -lt 1) {
    throw "diagram.json does not contain Wokwi connections"
}

$libraries = Get-Content -LiteralPath $librariesPath -Raw
foreach ($requiredLibrary in @("LiquidCrystal I2C", "PubSubClient")) {
    if ($libraries -notmatch [regex]::Escape($requiredLibrary)) {
        throw "libraries.txt is missing required library: $requiredLibrary"
    }
}

$sketch = Get-Content -LiteralPath $sketchPath -Raw
foreach ($requiredToken in @("class TrafficLight", "class RoadApproach", "PubSubClient", "publishStatus", "publishAck")) {
    if ($sketch -notmatch [regex]::Escape($requiredToken)) {
        throw "sketch.ino is missing expected token: $requiredToken"
    }
}

Test-BraceBalance -Source $sketch

Write-Host "Wokwi source sanity check passed."
Write-Host "Parts:" $diagram.parts.Count
Write-Host "Connections:" $diagram.connections.Count
Write-Host "Libraries: LiquidCrystal I2C, PubSubClient"
Write-Host "Brace balance: OK"
