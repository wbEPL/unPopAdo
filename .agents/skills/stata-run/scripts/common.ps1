# common.ps1 - Shared discovery helpers for the stata-run skill (Windows only).
# Dot-source this file: . "$PSScriptRoot\common.ps1"
#
# Provides:
#   Find-StataMcpExtension   -> path to newest deepecon.stata-mcp-* extension folder
#   Find-StataInstall        -> path to newest Stata / StataNow install
#   Get-VenvPython           -> path to the extension's venv python.exe (uv-built)
#   Test-StataServer         -> $true if the MCP server answers on the given port

$ErrorActionPreference = 'Stop'

function Find-StataMcpExtension {
    <#
      Locate the most recent deepecon.stata-mcp-<version> extension folder across
      common IDE extension directories. Never hardcodes username or version.
    #>
    $roots = @(
        (Join-Path $env:USERPROFILE '.vscode\extensions'),
        (Join-Path $env:USERPROFILE '.vscode-insiders\extensions'),
        (Join-Path $env:USERPROFILE '.vscode-server\extensions'),
        (Join-Path $env:USERPROFILE '.cursor\extensions'),
        (Join-Path $env:USERPROFILE '.windsurf\extensions')
    ) | Where-Object { Test-Path $_ }

    $candidates = foreach ($root in $roots) {
        Get-ChildItem -Path $root -Directory -Filter 'deepecon.stata-mcp-*' -ErrorAction SilentlyContinue
    }
    if (-not $candidates) {
        throw "Stata MCP extension (deepecon.stata-mcp-*) not found. Install it in VS Code / Cursor / Windsurf first."
    }

    # Sort by parsed semantic version (the trailing -x.y.z), newest first.
    $newest = $candidates | Sort-Object -Property @{
        Expression = {
            if ($_.Name -match 'stata-mcp-(\d+)\.(\d+)\.(\d+)') {
                [version]("{0}.{1}.{2}" -f $Matches[1], $Matches[2], $Matches[3])
            } else { [version]'0.0.0' }
        }
    } -Descending | Select-Object -First 1

    return $newest.FullName
}

function Find-StataInstall {
    <#
      Locate the newest Stata or StataNow install under Program Files.
      Returns the install directory (contains StataMP-64.exe etc.).
    #>
    $bases = @(${env:ProgramFiles}, ${env:ProgramFiles(x86)}) | Where-Object { $_ -and (Test-Path $_) }
    $candidates = foreach ($base in $bases) {
        Get-ChildItem -Path $base -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^Stata(Now)?\d*$' }
    }
    if (-not $candidates) {
        throw "No Stata install found under Program Files (looked for Stata* / StataNow*)."
    }
    # Prefer highest trailing version number; StataNow before Stata when equal.
    $newest = $candidates | Sort-Object -Property @{
        Expression = { if ($_.Name -match '(\d+)$') { [int]$Matches[1] } else { 0 } }
    }, @{ Expression = { $_.Name -like 'StataNow*' } } -Descending | Select-Object -First 1
    return $newest.FullName
}

function Get-VenvPython {
    param([Parameter(Mandatory)] [string] $ExtensionPath)
    return (Join-Path $ExtensionPath '.venv\Scripts\python.exe')
}

function Test-StataServer {
    param(
        [string] $StataHost = 'localhost',
        [int]    $Port = 4000,
        [int]    $TimeoutSec = 3
    )
    # The server returns 404 on '/', but /openapi.json answers 200 once ready.
    try {
        $resp = Invoke-WebRequest -Uri "http://${StataHost}:${Port}/openapi.json" `
            -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        return $resp.StatusCode -eq 200
    } catch {
        return $false
    }
}
