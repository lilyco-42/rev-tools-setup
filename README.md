# RE 工具链一键安装 + MCP 接入（面向 AI Agent）
>
> 给其他 AI 的完整操作指引：用 scoop 安装逆向工程工具链、接入 MCP、逐个测试。
> 本仓库包含一个**一键脚本**和一份**避坑清单**，AI 可直接执行 `setup.ps1` 复现全部操作。

## 适用场景

Windows 10/11 上搭建「MMO 反作弊实验室 / 逆向工程工作台」工具链，供 AI（Claude / Codex / opencode / Cursor 等）通过 **MCP** 直接调用 Cheat Engine 等工具做进程分析、内存研究、Cheat Table 解析。

> ⚠️ 仅限安全研究 / 单机 / 自有私有服务器环境，遵守软件许可与游戏服务条款。

---

## 快速开始（AI 一键执行）

```powershell
# 以管理员运行 PowerShell
powershell -ExecutionPolicy Bypass -File setup.ps1
```

脚本会自动：

1. 检查 scoop（无则自动安装）
2. 批量安装工具（见下方清单）
3. 拉取并配置 Cheat Engine MCP 服务器（`cheat-engine`）
4. 写入 `opencode.json` / `claude_desktop_config.json` 的 MCP 配置段
5. 输出每个工具的验证命令与结果

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
**验证方式**：用 JSON-RPC stdio 握手测试（见 `test-mcp.ps1`）。

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
| `setup.ps1` | 一键安装 + 配置 + 验证 |
| `test-mcp.ps1` | 通过 stdio JSON-RPC 验证 MCP 服务器连通与工具列表 |
| `opencode.mcp.json` | 可直接合并进 `~/.config/opencode/opencode.json` 的 MCP 段 |
| `AI_GUIDE.md` | 给其他 AI 的逐步操作指引（含命令与判断标准） |

## License
MIT
