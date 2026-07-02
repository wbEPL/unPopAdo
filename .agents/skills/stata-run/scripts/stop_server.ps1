# stop_server.ps1 - Stop the Stata MCP server. Windows only.
#
# Usage:
#   .\stop_server.ps1            # stop server on port 4000
#   .\stop_server.ps1 -Port 4001
#
# Strategy: kill whatever process owns the TCP port (most reliable), and also
# clean up the recorded PID file. Use this to recover a hung/unresponsive server.

[CmdletBinding()]
param(
    [int] $Port = 4000
)

$ErrorActionPreference = 'SilentlyContinue'

$killed = $false

# 1. Kill by TCP port owner (covers hung servers that ignore signals).
#    NOTE: do not use $pid as a loop variable - it is a reserved PowerShell
#    automatic variable (current process id).
$conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
foreach ($ownerPid in ($conns.OwningProcess | Sort-Object -Unique)) {
    if ($ownerPid) {
        try {
            Stop-Process -Id $ownerPid -Force -ErrorAction Stop
            Write-Host "Stopped process PID $ownerPid listening on port $Port." -ForegroundColor Yellow
            $killed = $true
        } catch {
            Write-Warning "Could not stop PID ${ownerPid}: $($_.Exception.Message)"
        }
    }
}

# 2. Clean up the recorded PID file (kill that PID too if still alive).
$pidFile = Join-Path $env:TEMP "stata_mcp_server_${Port}.pid"
if (Test-Path $pidFile) {
    $recordedPid = Get-Content $pidFile | Select-Object -First 1
    if ($recordedPid -and (Get-Process -Id $recordedPid -ErrorAction SilentlyContinue)) {
        Stop-Process -Id $recordedPid -Force -ErrorAction SilentlyContinue
        $killed = $true
    }
    Remove-Item $pidFile -ErrorAction SilentlyContinue
}

if ($killed) {
    Write-Host "Stata MCP server on port $Port stopped." -ForegroundColor Green
} else {
    Write-Host "No Stata MCP server was running on port $Port." -ForegroundColor Gray
}
