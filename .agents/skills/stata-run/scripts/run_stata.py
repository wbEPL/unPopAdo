#!/usr/bin/env python
"""run_stata.py - Call the independent Stata MCP server's REST API.

Windows-friendly helper that does clean URL-encoding (PowerShell mangles
multiline/quoted Stata code in query strings). Run it with the extension's
venv python, but it only needs the standard library, so any Python 3 works.

Endpoints used (the ONLY two the server exposes over REST):
  POST /run_selection?selection=<code>[&session_id=&working_dir=]
  GET  /run_file?file_path=<path>[&timeout=600&session_id=&working_dir=]

Examples:
  python run_stata.py --code "sysuse auto, clear`nsummarize price"
  python run_stata.py --file "C:/path/to/script.do" --timeout 300
  python run_stata.py --code "display 1+1" --session-id myrun
  python run_stata.py --health
"""

import argparse
import sys
import urllib.parse
import urllib.request


def _request(url: str, method: str, timeout: int) -> str:
    req = urllib.request.Request(url, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="replace")


def health(base: str, timeout: int) -> bool:
    try:
        _request(f"{base}/openapi.json", "GET", timeout)
        return True
    except Exception:
        return False


def run_selection(base, code, session_id, working_dir, timeout):
    params = {"selection": code}
    if session_id:
        params["session_id"] = session_id
    if working_dir:
        params["working_dir"] = working_dir
    url = f"{base}/run_selection?" + urllib.parse.urlencode(params)
    return _request(url, "POST", timeout)


def run_file(base, file_path, session_id, working_dir, stata_timeout, timeout):
    params = {"file_path": file_path, "timeout": stata_timeout}
    if session_id:
        params["session_id"] = session_id
    if working_dir:
        params["working_dir"] = working_dir
    url = f"{base}/run_file?" + urllib.parse.urlencode(params)
    return _request(url, "GET", timeout)


def main() -> int:
    p = argparse.ArgumentParser(description="Call the Stata MCP server REST API.")
    p.add_argument("--host", default="localhost")
    p.add_argument("--port", type=int, default=4000)
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--code", help="Inline Stata code to run via /run_selection.")
    g.add_argument("--file", help="Path to a .do file to run via /run_file.")
    g.add_argument("--health", action="store_true", help="Check server health and exit.")
    p.add_argument("--session-id", default=None,
                   help="Run in an isolated named session (use a fresh name to recover a hung session).")
    p.add_argument("--working-dir", default=None, help="Working directory for the run.")
    p.add_argument("--timeout", type=int, default=600,
                   help="Stata execution timeout in seconds (run_file). Default 600.")
    p.add_argument("--http-timeout", type=int, default=900,
                   help="HTTP client timeout in seconds. Default 900.")
    args = p.parse_args()

    base = f"http://{args.host}:{args.port}"

    if args.health:
        ok = health(base, timeout=5)
        print("HEALTHY" if ok else "DOWN")
        return 0 if ok else 1

    if not health(base, timeout=5):
        print(f"ERROR: Stata MCP server is not responding at {base}. "
              f"Start it with scripts/start_server.ps1.", file=sys.stderr)
        return 2

    try:
        if args.code is not None:
            out = run_selection(base, args.code, args.session_id,
                                args.working_dir, args.http_timeout)
        else:
            out = run_file(base, args.file, args.session_id, args.working_dir,
                           args.timeout, args.http_timeout)
    except Exception as exc:  # noqa: BLE001 - surface any transport error to the agent
        print(f"ERROR calling Stata MCP server: {exc}", file=sys.stderr)
        return 3

    print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
