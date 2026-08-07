---
name: setup-re-toolchain
description: Installs and tests a Windows reverse-engineering toolchain (Cheat Engine, ReClass.NET, x64dbg, Ghidra, DynamoRIO, Frida, YARA, Wireshark, RenderDoc, Prometheus/Grafana/Elasticsearch, PyTorch/OpenCV) via scoop and pip, deploys the bundled Cheat Engine MCP server, and verifies every tool. Use when the user asks to set up RE tools, install Cheat Engine MCP, build an anti-cheat / game hacking research lab, or when the bundled cheat-engine MCP server fails with "no python with mcp found".
license: MIT
compatibility: Windows 10/11, scoop, git, uv; requires an internet connection; Python via scoop anaconda3
metadata:
  author: lilyco-42
  plugin: rev-tools-setup
  version: "1.0.0"
---

# Setup RE Toolchain

Provisions the full reverse-engineering / anti-cheat research toolchain and a portable **Cheat Engine MCP server** on Windows. The MCP server is bundled in this plugin at `../server` and launched via `../../bin/ce-mcp.cmd`.

> Boundary: for security research, single-machine debugging, and your own private servers only. Keep the MCP server in `--read-only` mode. Respect software licenses and game terms of service.

## Prerequisites

- Windows 10/11 (64-bit)
- `scoop` (script installs it if missing)
- `git`, `uv` (for the MCP server venv)
- PowerShell (prefer an **Administrator** shell)

## Quick start

Run the main setup script (about 10-20 minutes, downloads ~1.5 GB):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup.ps1
```

The script:
1. Checks/installs `scoop`, adds it to PATH.
2. Installs packages: `7zip cheat-engine x64dbg gdb llvm dynamorio sysinternals vmmap procmon ghidra yara wireshark mitmproxy renderdoc prometheus grafana elasticsearch anaconda3`.
3. Deploys ReClass.NET manually (no scoop manifest) from GitHub `v1.2`.
4. Installs Python libs into the **anaconda3** interpreter: `scapy frida-tools opencv-python-headless torch(cpu)`.
5. Creates a venv for the bundled CE MCP server and installs `mcp>=1.0.0,<2.0.0 trio psutil capstone`.
6. Prints verification commands for each tool.

## After setup

### 1. Enable the Cheat Engine MCP server

The plugin ships a portable `mcp.json` (stdio). Any Agent Plugins-compatible client (ChatGPT, Codex, Cursor, GitHub Copilot, VS Code, Kiro) discovers it automatically.

For opencode, merge the `cheat-engine` entry into `~/.config/opencode/opencode.json` → `mcp`:

```json
{
  "cheat-engine": {
    "type": "local",
    "command": ["<PLUGIN_ROOT>/bin/ce-mcp.cmd"],
    "enabled": true
  }
}
```

Then **restart opencode** (config is not hot-reloaded).

The launcher `bin/ce-mcp.cmd` resolves the python in this order:
1. `$CE_MCP_PYTHON` (client sets `${PLUGIN_DATA}/.venv/Scripts/python.exe`)
2. plugin-local `.venv\Scripts\python.exe`
3. `python` / `python3` on PATH

### 2. Verify the MCP server

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test-mcp.ps1
```

Expect: initialize handshake OK, a list of ~26 tools, and a non-error `list_processes` call.

### 3. Smoke-test key tools

| Tool | Command | Expected |
|---|---|---|
| YARA | `yara --version` | 4.5.5 |
| GDB | `gdb --version` | GNU gdb 17.1 |
| TShark | `tshark --version` | 4.6.x |
| DynamoRIO | `bin64\drrun.exe -c samples\bin64\bbcount.dll -- bin64\dummy.exe` | "Client bbcount is running" |
| RenderDoc | `renderdoccmd.exe --version` | v1.45 |
| Ghidra | `support\analyzeHeadless.bat <proj> demo -import <exe> -overwrite` | creates `.gpr` project |
| Prometheus | `prometheus.exe --config.file=...prometheus.yml` then GET `/-/healthy` | "Prometheus Server is Healthy" |

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `externally-managed-environment` | used uv-managed system python | use anaconda3 python: `D:\app\scoop\apps\anaconda3\current\App\python.exe` |
| `No module named 'mcp.server.fastmcp'` | mcp 2.0 removed fastmcp | pin `mcp>=1.0.0,<2.0.0` |
| `unable to find python311.dll` | lldb-mcp missing Python DLL | copy `python311.dll` into LLVM bin; use socket mode `lldb-mcp -p <port>` |
| `unable to load Npcap (wpcap.dll)` | no Npcap driver | install Npcap from npcap.com; scoop has no manifest |
| `flag provided but not defined: -http-port` | Grafana arg format | use `--configOverrides=cfg:server.http_port=<port>` with `--homepath` |
| `scoop search` rate-limited | GitHub API limit | `Get-ChildItem D:\app\scoop\buckets\*\bucket\*<name>*` or `scoop config gh_token <token>` |

See [the pitfalls guide](references/AI_GUIDE.md) for the full walkthrough with pass/fail criteria.

## Do not

- Do not target online games operated by others; this toolchain is for research/own-private-server only.
- Do not disable the MCP server's `--read-only` flag.
