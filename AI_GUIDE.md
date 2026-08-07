# AI_GUIDE：给其他 AI 的逐步操作指引

> 你是一个 AI Agent，被要求在 Windows 上搭建逆向工程工具链并接入 MCP。
> 按本指南逐步执行。每条命令执行后按「判断标准」核对结果，失败则按「避坑」处理。

## 阶段 0：环境检查（必须先做）

```powershell
scoop --version
# 判断标准: 输出版本号。若报 command not found → 需先安装 scoop
where.exe python; where.exe pip
# 判断标准: 确认 python/pip 指向同一解释器（看第一条路径）
# ⚠️ 坑: PATH 里可能有多个 python（uv/anaconda/scoop）。用 `python -c "import sys;print(sys.executable)"` 确认
```

## 阶段 1：scoop 批量安装

```powershell
scoop install 7zip cheat-engine x64dbg gdb llvm dynamorio sysinternals vmmap procmon ghidra yara wireshark mitmproxy renderdoc prometheus grafana elasticsearch
```

判断标准：每包出现 `'xxx' (版本) was installed successfully!`。个别失败可单独重装：
`scoop install <包名>`
避坑：wireshark 安装后可验证 `tshark --version`；若抓包失败看 Npcap。

## 阶段 2：ReClass.NET（无 scoop 包）

```powershell
# 需先装 7zip
Invoke-WebRequest -Uri "https://github.com/ReClassNET/ReClass.NET/releases/download/v1.2/ReClass.NET.rar" -OutFile "$env:TEMP\ReClass.NET.rar"
New-Item -ItemType Directory -Force -Path "D:\app\scoop\apps\reclass-net\current" | Out-Null
& "D:\app\scoop\apps\7zip\current\7z.exe" x "$env:TEMP\ReClass.NET.rar" "-oD:\app\scoop\apps\reclass-net\current" -y
```

判断标准：`Test-Path "D:\app\scoop\apps\reclass-net\current\x64\ReClass.NET.exe"` 为 True

## 阶段 3：Python 生态（用 anaconda python，不要用 uv python！）

```powershell
$py = "D:\app\scoop\apps\anaconda3\current\App\python.exe"
& $py -m pip install scapy frida-tools opencv-python-headless
& $py -m pip install torch --index-url https://download.pytorch.org/whl/cpu
```

判断标准：`& $py -c "import scapy,frida,cv2,torch;print('OK')"` 无报错
避坑：若用系统 `python`（uv 托管）会报 `externally-managed-environment`。**一定用 anaconda3 的解释器，或先 `uv venv` 再装。**

## 阶段 4：Cheat Engine MCP 服务器

```powershell
git clone --depth 1 https://github.com/bethington/cheat-engine-server-python D:\app\scoop\apps\ce-mcp-server
cd D:\app\scoop\apps\ce-mcp-server
uv venv .venv
uv pip install --python .venv\Scripts\python.exe "mcp>=1.0.0,<2.0.0" trio psutil capstone
```

**避坑（关键）**：
- `mcp>=1.0.0` 会装成 2.0，但 2.0 移除了 `mcp.server.fastmcp`，启动必崩。**必须锁定 `<2.0.0`**。
- 该项目 CLI 没有 `--test` 参数（README 有误）。验证用 `test-mcp.ps1`。
- 该实现只有进程管理 + Cheat Table 解析（约 26 个工具），**无内存读写**。

## 阶段 5：MCP 配置

将 `opencode.mcp.json` 的 `cheat-engine` 段合并进 `~/.config/opencode/opencode.json` 的 `mcp` 对象（若该文件存在 idalib/burp，保留它们）。

```powershell
# 改完必须重启 opencode，配置不热加载
```

其他客户端参考：
- Claude Desktop: `%APPDATA%\Claude\claude_desktop_config.json`（`mcpServers`）
- Codex: `~/.codex/config.toml`

## 阶段 6：测试每个工具

| 工具 | 命令 | 预期 |
|---|---|---|
| Cheat Engine | `.\test-mcp.ps1` | 26 个工具列表 + list_processes 有响应 |
| YARA | 写规则扫 notepad.exe | 命中 MZ_Header |
| Ghidra | `support\analyzeHeadless.bat` 导入 exe | 生成 .gpr 项目 |
| DynamoRIO | `bin64\drrun.exe -c samples\bin64\bbcount.dll -- bin64\dummy.exe` | 输出 "Client bbcount is running" |
| GDB | `gdb --version` | 17.x |
| RenderDoc | `renderdoccmd.exe --version` | v1.45 |
| Prometheus | 启动后 GET `/-/healthy` | "Prometheus Server is Healthy" |

## 常见失败诊断表

| 症状 | 原因 | 处理 |
|---|---|---|
| `externally-managed-environment` | 用了 uv 托管 python | 换 anaconda3 python 或 `uv venv` |
| `No module named 'mcp.server.fastmcp'` | mcp 2.0 | 锁定 `mcp<2.0.0` |
| `unable to find python311.dll` | lldb-mcp 缺 Python 动态库 | 复制 `python311.dll` 到 LLVM bin，socket 模式接入 |
| `unable to load Npcap (wpcap.dll)` | 缺 Npcap | 装 Npcap（官网） |
| `flag provided but not defined: -http-port` | Grafana 参数格式 | 用 `--configOverrides` / `--homepath` |
| `scoop search` 报 GitHub rate limit | API 限流 | `Get-ChildItem D:\app\scoop\buckets\*\bucket\*<名>*` 或 `scoop config gh_token` |

## 研究边界（务必遵守）

- 本工具链用于安全研究、单机调试、自有私有服务器
- 遵守软件许可与游戏服务条款；不对他人运营的在线游戏实施外挂
- CE MCP 保持 `--read-only` 模式
