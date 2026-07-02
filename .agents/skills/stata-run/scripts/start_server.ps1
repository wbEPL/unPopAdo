# start_server.ps1 - Launch the Stata MCP server in a detached background process.
# Windows only. uv-first environment handling.
#
# Usage:
#   .\start_server.ps1                 # discover everything, start on localhost:4000
#   .\start_server.ps1 -Port 4001
#   .\start_server.ps1 -StataPath "C:\Program Files\StataNow19" -Edition mp
#
# Idempotent: if a healthy server already answers on the port, it does nothing.

[CmdletBinding()]
param(
    [string] $StataHost = 'localhost',
    [int]    $Port = 4000,
    [string] $StataPath,
    [ValidateSet('mp', 'se', 'be')]
    [string] $Edition = 'mp',
    [string] $WorkspaceRoot,
    [switch] $Reinstall   # force-recreate the venv before starting
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

# 1. Already running? Do nothing.
if (Test-StataServer -StataHost $StataHost -Port $Port) {
    Write-Host "Stata MCP server already healthy at http://${StataHost}:${Port}" -ForegroundColor Green
    return
}

# 2. Discover paths.
$ext = Find-StataMcpExtension
Write-Host "Extension : $ext"
$serverScript = Join-Path $ext 'src\stata_mcp_server.py'
if (-not (Test-Path $serverScript)) { throw "Server script not found: $serverScript" }

if (-not $StataPath) { $StataPath = Find-StataInstall }
Write-Host "Stata     : $StataPath"

$venvPython  = Get-VenvPython -ExtensionPath $ext
$requirements = Join-Path $ext 'src\requirements.txt'

# 3. Ensure the venv exists & is usable (uv-first). The extension normally
#    builds this itself; we only repair it when missing or -Reinstall is set.
$needBuild = $Reinstall -or -not (Test-Path $venvPython)
if ($needBuild) {
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    $venvDir = Join-Path $ext '.venv'
    if ($uv) {
        Write-Host "Building venv with uv ..." -ForegroundColor Cyan
        & uv venv $venvDir --python 3.11
        & uv pip install --python $venvPython -r $requirements
    } else {
        Write-Warning "uv not found on PATH; falling back to python -m venv + pip."
        $sysPy = (Get-Command python -ErrorAction Stop).Source
        & $sysPy -m venv $venvDir
        & $venvPython -m pip install --upgrade pip
        & $venvPython -m pip install -r $requirements
    }
}
if (-not (Test-Path $venvPython)) { throw "venv python missing after build: $venvPython" }

# 4. Build argument list.
if (-not $WorkspaceRoot) { $WorkspaceRoot = (Get-Location).Path }
$logFile = Join-Path $env:TEMP "stata_mcp_server_${Port}.log"
# Quote values that can contain spaces. Start-Process -ArgumentList otherwise
# splits "C:\Program Files\StataNow19" at the space; the server's own parser
# understands embedded double quotes and reassembles the path.
$serverArgs = @(
    ('"{0}"' -f $serverScript),
    '--stata-path',     ('"{0}"' -f $StataPath),
    '--stata-edition',  $Edition,
    '--host',           $StataHost,
    '--port',           $Port,
    '--workspace-root', ('"{0}"' -f $WorkspaceRoot),
    '--log-file',       ('"{0}"' -f $logFile)
)

# 5. Launch detached so it survives the agent's terminal.
Write-Host "Starting Stata MCP server (log: $logFile) ..." -ForegroundColor Cyan
$proc = Start-Process -FilePath $venvPython -ArgumentList $serverArgs `
    -WindowStyle Hidden -PassThru
$proc.Id | Set-Content -Path (Join-Path $env:TEMP "stata_mcp_server_${Port}.pid")

# 6. Wait for health (Stata + JVM init can take a while on first start).
$deadline = (Get-Date).AddSeconds(90)
while ((Get-Date) -lt $deadline) {
    if (Test-StataServer -StataHost $StataHost -Port $Port) {
        Write-Host "Stata MCP server is healthy at http://${StataHost}:${Port} (PID $($proc.Id))" -ForegroundColor Green
        return
    }
    Start-Sleep -Seconds 2
}
throw "Server did not become healthy within 90s. Check log: $logFile"
