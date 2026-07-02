---
name: stata-run
description: Run, troubleshoot, or build-and-execute Stata code through an independently-started Stata MCP server's REST API. Use whenever the user asks to run Stata code, a .do file, debug/troubleshoot Stata code, or build Stata code and execute it. Windows only.
---

# stata-run

Run Stata code by calling the REST API of an **independently started** Stata MCP
server (the `deepecon.stata-mcp` extension's server, launched as a standalone
background process). Do **not** use any VS Code MCP tools for Stata.

## Hard rules

- **NEVER use VS Code MCP tools** (e.g. built-in `stata` MCP tools). Always go
  through the standalone server's REST API described here.
- Windows only. Lifecycle is managed with PowerShell scripts in `scripts/`.
- The server exposes exactly **two** REST endpoints:
  - `GET  /run_file?file_path=<path>[&timeout=600&session_id=&working_dir=]`
  - `POST /run_selection?selection=<urlencoded code>[&session_id=&working_dir=]`
- Health check: `GET /openapi.json` returns 200 when ready. `GET /` returns 404
  (do not use `/` for health).
- **NEVER use `--code` for Stata code that contains double-quotes** (variable
  labels, `display "..."`, file paths, etc.). PowerShell word-splits the argument
  before `run_stata.py` sees it. Write the code to a temp `.do` file and use
  `--file` instead. Only use `--code` for single-line, quote-free snippets such
  as `display 6*7` or `summarize price`.

## Workflow

1. **Check the server is up** — fetch `http://localhost:4000/openapi.json`.
   - 200 + JSON body → healthy, proceed.
   - Error or timeout → start it (step 2).
   - If the `fetch` tool is unavailable, use the terminal:
     `& "<venvPython>" scripts/run_stata.py --health` (exits 0 = HEALTHY, 1 = DOWN).
2. **Start it if down**: run `scripts/start_server.ps1` (idempotent; prints
   `venvPython` path to stdout — capture it for use in step 3).
3. **Resolve `<venvPython>`** (needed for steps 4 and 5):
   ```powershell
   # One-liner; works even when the server is already up:
   $venvPython = (. scripts/common.ps1; Find-VenvPython)
   ```
   If `common.ps1` does not export `Find-VenvPython`, fall back to:
   ```powershell
   $ext = (Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Directory |
     Where-Object Name -match '^deepecon\.stata-mcp' |
     Sort-Object Name | Select-Object -Last 1).FullName
   $venvPython = "$ext\.venv\Scripts\python.exe"
   ```
4. **Run a `.do` file** (primary path for any real script):
   ```powershell
   & $venvPython scripts/run_stata.py --file "C:/abs/path/to/script.do" `
     --timeout 600 --session-id <label> --working-dir "C:/abs/working/dir"
   ```
   Always supply `--working-dir` for pipeline scripts so graph exports and temp
   files land in the right place. Always use a fresh `--session-id` per run.
5. **Run inline code** (only for quote-free single-line snippets):
   ```powershell
   & $venvPython scripts/run_stata.py --code "display 6*7" --session-id smoke
   ```
   For anything with double-quotes or multiple lines: write a temp `.do` file and
   use step 4 instead (see Hard rules above).
6. **Read the returned Stata log** and report results / errors.

> **`fetch` tool limitation**: the agent's `fetch` tool works for health checks
> and instant results, but it silently cancels on do-files that take more than a
> few seconds (package installs, large datasets). Always use the terminal +
> `run_stata.py` for real pipeline scripts.

## Starting & stopping the server

```powershell
# Start (idempotent; discovers everything; waits until healthy):
powershell -ExecutionPolicy Bypass -File scripts/start_server.ps1

# Start on a different port / explicit Stata path / edition:
powershell -ExecutionPolicy Bypass -File scripts/start_server.ps1 -Port 4000 -Edition mp

# Stop (also used to recover a hung server — kills the process on the port):
powershell -ExecutionPolicy Bypass -File scripts/stop_server.ps1
```

`start_server.ps1` is **uv-first**: it reuses the extension's existing `.venv`
(built by `uv`); if missing/broken it rebuilds with `uv venv` +
`uv pip install -r requirements.txt`, falling back to `python -m venv` + `pip`.

## Calling the API with run_stata.py

Run it with the extension's venv python (see Workflow step 3 for discovery).
The script only uses the standard library, so any Python 3 ≥ 3.8 also works.

```powershell
# A .do file — the standard path for any real script:
& $venvPython scripts/run_stata.py --file "C:/path/to/script.do" `
  --timeout 600 --session-id myrun --working-dir "C:/path/to/workdir"

# Quote-free single-line snippet only (see Hard rules before using --code):
& $venvPython scripts/run_stata.py --code "display 6*7" --session-id smoke

# Health only:
& $venvPython scripts/run_stata.py --health
```

## Recovering a hung Stata session

1. **First, try a fresh session** (server is multi-session — no restart needed):
   add `--session-id <newName>` to `run_stata.py` (or `&session_id=<newName>` to
   the URL). This gives a clean Stata instance.
2. **If the server itself is unresponsive** (health check times out):
   `scripts/stop_server.ps1` (kills the process holding port 4000), then
   `scripts/start_server.ps1` to relaunch.

## Commands to allow / bypass approval

To avoid the agent being blocked mid-task, pre-approve these. See
[REFERENCE.md](REFERENCE.md) for exact `settings.json` entries (user level) and
the session-level allowlist. In short, allow: `uv`, the extension venv
`python.exe`, `scripts/start_server.ps1`, `scripts/stop_server.ps1`,
`scripts/run_stata.py`, and `Invoke-RestMethod`/`Invoke-WebRequest`/`curl`
targeting `localhost:4000`.

## Notes

- Graphs: have the Stata code `graph export "name.png", replace`. PNGs land in
  Stata's working directory (pass `--working-dir`/`working_dir` to control it).
- Detailed endpoint params, discovery logic, and troubleshooting:
  [REFERENCE.md](REFERENCE.md).
