# RE 工具链一键安装 + MCP 接入（Agent Plugin · 面向 AI Agent）
>
> 一个标准的 **Agent Plugins 1.0.0** 插件：把「逆向工程工具链一键安装 + Cheat Engine MCP 接入」打包成任意 AI 客户端（ChatGPT / Claude / Codex / Cursor / GitHub Copilot / VS Code / Kiro / opencode 等）都能发现、加载、执行的插件。
> 包含 `plugin.json` 清单、`skills/` Agent Skill（安装+避坑指引）、`mcp.json` 可移植 MCP 服务器（CE MCP 已 vendor 在插件内）。

## 适用场景

Windows 10/11 上搭建「MMO 反作弊实验室 / 逆向工程工作台」工具链，供 AI 通过 **MCP** 直接调用 Cheat Engine 等工具做进程分析、内存研究、Cheat Table 解析。

> ⚠️ 仅限安全研究 / 单机 / 自有私有服务器环境，遵守软件许可与游戏服务条款。

---

## 快速开始（AI 一键执行）

```powershell
# 以管理员运行 PowerShell
powershell -ExecutionPolicy Bypass -File skills\setup-re-toolchain\scripts\setup.ps1
```

脚本会自动：

1. 检查 scoop（无则自动安装）
2. 批量安装工具（见下方清单）
3. 为插件内 vendor 的 Cheat Engine MCP 服务器创建 venv（锁定 `mcp>=1.0.0,<2.0.0`）
4. 写入 `opencode.json` 的 MCP 配置段（指向可移植启动器 `bin/ce-mcp.cmd`）
5. 输出每个工具的验证命令与结果

### 作为 Agent Plugin 安装

把本仓库放进你的 AI 客户端的插件目录即可（各客户端约定不同）：

| 客户端 | 插件目录 |
|---|---|
| opencode | `~/.config/opencode/plugin/` |
| Claude Code | `~/.claude/plugins/` |
| VS Code / Copilot | VS Code 扩展目录 |
| Cursor | `~/.cursor/plugin/` |
| Kiro | Kiro 市场导入 |

客户端发现 `plugin.json` 后自动加载 `setup-re-toolchain` skill 与 `cheat-engine` MCP 服务器（stdio，`bin/ce-mcp.cmd`）。之后只需对 AI 说：**"运行 setup-re-toolchain skill 并安装 RE 工具链"**。

> 💡 插件用 `${PLUGIN_ROOT}`（插件根）与 `${PLUGIN_DATA}`（插件数据/venv 目录）占位符定位路径，无需改动即可跨客户端/跨机器运行。

---

## 插件结构

```
rev-tools-setup/                        # Agent Plugin 根
├── plugin.json                         # 插件清单（Agent Plugins 1.0.0 schema）
├── mcp.json                            # MCP 服务器定义（stdio, bin/ce-mcp.cmd）
├── bin/
│   └── ce-mcp.cmd                      # 可移植启动器（找 venv → plugin .venv → PATH）
├── server/                             # vendor 的 Cheat Engine MCP 服务器源码
│   └── server/main.py
└── skills/
    └── setup-re-toolchain/             # Agent Skill（skills-ref 校验通过）
        ├── SKILL.md                    # 安装+验证指引
        ├── scripts/                    # setup.ps1 / test-mcp.ps1 / test-mcp.py
        └── references/                 # AI_GUIDE.md 避坑清单
```

### MCP 配置

客户端可通过 `mcp.json`（Agent Plugins 标准）自动发现 `cheat-engine` 服务器。手动配置同样可用：

```json
{
  "cheat-engine": {
    "type": "local",
    "command": ["<插件根>/bin/ce-mcp.cmd"],
    "enabled": true
  }
}
```

`bin/ce-mcp.cmd` 按顺序解析 Python：`$CE_MCP_PYTHON`（客户端注入，通常为 `${PLUGIN_DATA}/.venv/Scripts/python.exe`）→ 插件根 `.venv` → PATH 上的 `python`/`python3`。改完 MCP 配置需重启客户端生效。

---

## 安装的工具清单

| 类别 | 工具 | scoop 包 |
|---|---|---|
| 内存分析 | Cheat Engine | `cheat-engine` |
| 结构还原 | ReClass.NET | 手动部署（GitHub release） |
| 调试器 | x64dbg / GDB / LLVM(LLDB) | `x64dbg` `gdb` `llvm` |
| 动态插桩 | DynamoRIO / Frida | `dynamorio` / pip |
| 系统分析 | Sysinternals / VMMap / Procmon | `sysinternals` `vmmap` `procmon` |
| 二进制分析 | Ghidra / YARA | `ghidra` `yara` |
| 网络分析 | Wireshark / mitmproxy / Scapy | `wireshark` `mitmproxy` / pip |
| 图形分析 | RenderDoc | `renderdoc` |
| 服务端遥测 | Prometheus / Grafana / Elasticsearch | `prometheus` `grafana` `elasticsearch` |
| AI 检测 | Python / PyTorch / OpenCV | `anaconda3` / pip |

---

## 避坑清单（实测踩坑记录）

### 1. scoop 的 `main` bucket 可能是国内镜像
`main` 可能指向 `ScoopInstaller/scoop-cn`（GitHub 代理）。`gh-proxy.org` 前缀出现即说明在用镜像，安装速度更快但要注意 hash 校验依然生效。

### 2. ReClass.NET 无 scoop 包
- 从 GitHub releases 下载 `ReClass.NET.rar`
- 需要 `7zip` 解压：`scoop install 7zip`
- 部署到 `D:\app\scoop\apps\reclass-net\current`
- x64/x86 两个 `ReClass.NET.exe`

### 3. Python 环境陷阱（最重要的坑）
系统 `python` 可能是 **uv 托管的 3.11（externally-managed-environment）**，直接 `pip install` 会报错：

```
error: externally-managed-environment
```

**解决**：
- 查 `where.exe python` / `where.exe pip`，确认是哪个解释器
- 用 `python -m pip` 对齐版本，或直接使用 anaconda3 的 Python：`D:\app\scoop\apps\anaconda3\current\App\python.exe`
- 独立服务用 `uv venv` 建隔离环境

### 4. CE MCP 必须锁定 mcp <2.0
`bethington/cheat-engine-server-python` 依赖 `mcp.server.fastmcp`，而 **mcp 2.0 移除了该模块**，启动即崩：
```
ModuleNotFoundError: No module named 'mcp.server.fastmcp'
```
**解决**：`uv pip install "mcp>=1.0.0,<2.0.0"`

### 5. CE MCP 的 `--test` 参数不存在
该项目 CLI 只支持 `--config/--debug/--read-only`，README 里的 `--test` 会报 `unrecognized arguments`。
**验证方式**：`scripts\test-mcp.ps1` / `scripts\test-mcp.py`（mcp SDK 握手测试）。

### 6. 这个 CE MCP 是「精简版」
它只有进程管理 + Cheat Table 解析（26 个工具），**没有内存读写工具**。需要内存读写请找 `tonytranrp/cheat-engine-mcp`（210 工具）或 `sudohakan/cheatengine-mcp-bridge`（Lua 桥接）。

### 7. LLDB MCP 需要 python311.dll
`lldb-mcp.exe` 报 `unable to find 'python311.dll'`：
- 从 `D:\app\scoop\apps\python311\3.11.9\python311.dll` 复制到 LLVM bin 目录
- 但 lldb-mcp 默认走 **socket 模式**（stdio 握手不通），需 `-p <port>` 启动后配成 remote MCP

### 8. Wireshark 抓包需要 Npcap 驱动
`scoop` 无 npcap 包，安装 Wireshark 安装器时勾选 Npcap，否则 tshark 报：
```
unable to load Npcap (wpcap.dll)
```

### 9. Grafana 直接启动即退出 (exit 1)
- 参数是 `--configOverrides`（单横杠 `-http-port` 会报 flag not defined）
- 需要 `--homepath=D:\app\scoop\apps\grafana\current`
- 实测仍退出，需用 `--config=conf\defaults.ini` + persist 数据目录再查日志

### 10. Elasticsearch 启动后端口无响应
自带 bundled JDK，需 `-Ehttp.port=<port> -Ediscovery.type=single-node`，仍失败时看 `logs/` 下 Java 日志定位安全初始化问题。

### 11. ClickHouse 无法从 GitHub releases 装
Windows 二进制在独立 artifacts 服务器，`builds.clickhouse.com` 当前 AccessDenied，GitHub API 限流也阻止版本探测。需官网安装器或等网络恢复。

### 12. GitHub API 限流会干扰 scoop search / 版本探测
`scoop search` 与 `gh api releases` 会被 rate limit。应对：直接 `Get-ChildItem D:\app\scoop\buckets\*\bucket\*click*` 查本地清单，或配置 `scoop config gh_token <token>`。

### 13. opencode MCP 配置改动需重启
`opencode.json` 不热加载。改完 `mcp` 段必须重启 opencode 才生效。

---

## 文件说明

| 文件 | 用途 |
|---|---|
| `plugin.json` | Agent Plugins 1.0.0 插件清单 |
| `mcp.json` | MCP 服务器定义（stdio, `bin/ce-mcp.cmd`） |
| `bin/ce-mcp.cmd` | 可移植 MCP 启动器 |
| `server/` | vendor 的 Cheat Engine MCP 服务器源码 |
| `skills/setup-re-toolchain/SKILL.md` | Agent Skill：安装 + 验证指引 |
| `skills/setup-re-toolchain/scripts/setup.ps1` | 一键安装 + 配置 + 验证 |
| `skills/setup-re-toolchain/scripts/test-mcp.ps1` | 验证 MCP 服务器连通（代理到 test-mcp.py） |
| `skills/setup-re-toolchain/scripts/test-mcp.py` | 通过 mcp SDK 验证：初始化 + 工具列表 + list_processes |
| `skills/setup-re-toolchain/references/AI_GUIDE.md` | 给其他 AI 的逐步操作指引（含命令与判断标准） |

## License
MIT
