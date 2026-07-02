# stata-run — Reference

Detailed reference for the `stata-run` skill. Windows only.

## 1. Path discovery (no hardcoded username or version)

`scripts/common.ps1` discovers everything at runtime:

- **Extension** — newest `deepecon.stata-mcp-<version>` folder across:
  - `%USERPROFILE%\.vscode\extensions`
  - `%USERPROFILE%\.vscode-insiders\extensions`
  - `%USERPROFILE%\.vscode-server\extensions`
  - `%USERPROFILE%\.cursor\extensions`
  - `%USERPROFILE%\.windsurf\extensions`

  Picks the highest semantic version, so extension upgrades are handled
  automatically.
- **Server script** — `<ext>\src\stata_mcp_server.py`.
- **venv python** — `<ext>\.venv\Scripts\python.exe` (uv-built by the extension).
- **Stata install** — newest `Stata*` / `StataNow*` under
  `%ProgramFiles%` / `%ProgramFiles(x86)%`.

## 2. Server command-line parameters

`stata_mcp_server.py` (key flags; defaults shown):

| Flag | Default | Meaning |
|------|---------|---------|
| `--stata-path` | (discovered) | Stata install directory |
| `--stata-edition` | `mp` | `mp` \| `se` \| `be` |
| `--host` | `localhost` | Bind host |
| `--port` | `4000` | Port |
| `--workspace-root` | (cwd) | Workspace root for logs |
| `--log-file` | `stata_mcp_server.log` | Log path |
| `--log-level` | `INFO` | DEBUG/INFO/WARNING/ERROR/CRITICAL |
| `--force-port` | off | Kill whatever holds the port |
| `--result-display-mode` | `compact` | `compact` \| `full` |
| `--max-output-tokens` | `10000` | 0 = unlimited |
| `--no-multi-session` | off | Use a single shared Stata instance |
| `--max-sessions` | `100` | Concurrent sessions |
| `--session-timeout` | `3600` | Idle session timeout (s) |

## 3. REST endpoints (the only two exposed)

### `GET /run_file`
Query params:
- `file_path` (required) — absolute path to a `.do` file.
- `timeout` (default `600`) — Stata execution timeout in seconds.
- `session_id` (optional) — isolated named session.
- `working_dir` (optional) — working directory for the run.

Usable directly with the agent's **`fetch` tool** since it's a GET.

### `POST /run_selection`
Query params:
- `selection` (required, URL-encoded) — Stata code (newlines OK once encoded).
- `session_id` (optional), `working_dir` (optional).

Use `run_stata.py --file` (write code to a temp `.do`) for any code containing
double-quotes or multiple lines. PowerShell word-splits double-quoted arguments
before `run_stata.py` receives them — the Python helper's URL-encoding never
gets a chance to fix it. `--code` is safe only for quote-free single-liners.

### Health
`GET /openapi.json` → 200 + JSON when ready. `GET /` → 404 (never use for health).

**`fetch` tool limitation**: the agent's `fetch` tool works reliably for the
health check and for do-files that finish in a few seconds. For any do-file that
installs packages, loads large datasets, or runs a simulation, the `fetch` tool
returns `"Error: Execution cancelled"` mid-execution. Always use the terminal +
`run_stata.py --file` for real pipeline scripts.

## 4. run_stata.py options

```
--host           default localhost
--port           default 4000
--code  <str>    inline code -> POST /run_selection   (mutually exclusive)
--file  <path>   .do file     -> GET  /run_file        (mutually exclusive)
--health         check health and exit                 (mutually exclusive)
--session-id     isolated named session (fresh name = recover a hung session)
--working-dir    working directory for the run
--timeout        Stata exec timeout (run_file), default 600
--http-timeout   HTTP client timeout, default 900
```

Exit codes: `0` ok, `1` health DOWN, `2` server not responding, `3` transport error.

## 5. Recovering a hung session

1. Fresh session — `run_stata.py --code "..." --session-id run2` (no restart).
2. Server unresponsive — `stop_server.ps1` (kills port-4000 owner) then
   `start_server.ps1`.
3. Force a clean rebuild of the env — `start_server.ps1 -Reinstall`.

## 6. Commands to allow / bypass approval

### Session level
When prompted to approve a terminal command, approve these patterns once and
choose "always allow" for the session:
- `powershell -File ...start_server.ps1` / `...stop_server.ps1`
- `& "...\.venv\Scripts\python.exe" ...run_stata.py ...`
- `uv venv ...`, `uv pip install ...`
- `Invoke-RestMethod`/`Invoke-WebRequest`/`curl` to `http://localhost:4000/...`

### User level (VS Code `settings.json`)
Add auto-approve entries (regex) so the agent never blocks on these:

```jsonc
{
  "chat.tools.terminal.autoApprove": {
    "/start_server\\.ps1/": true,
    "/stop_server\\.ps1/": true,
    "/run_stata\\.py/": true,
    "/^uv (venv|pip) /": true,
    "/localhost:4000/": true
  }
}
```

> Adjust to your VS Code version's auto-approve schema. Keep approvals scoped to
> these specific scripts/host — do not blanket-approve all terminal commands.

## 7. Graphs

Stata writes graphs only when the code exports them:
```stata
graph export "myplot.png", replace
```
PNGs are written to Stata's working directory; set it via `--working-dir`
(run_stata.py) or `working_dir` (query param). Open them in the editor with
`code "<path>.png"`.
