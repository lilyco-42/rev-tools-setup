# RE 工具链一键安装 + MCP 接入
# 用法（管理员 PowerShell）: powershell -ExecutionPolicy Bypass -File setup.ps1
# 本脚本位于 plugin: skills/setup-re-toolchain/scripts/，服务器源码在 plugin 根 server/
$ErrorActionPreference = "Continue"
$PLUGIN_ROOT = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$APP_SCOOP = "$env:USERPROFILE\scoop"
if (Test-Path "D:\app\scoop") { $APP_SCOOP = "D:\app\scoop" }
$LOG = Join-Path $PSScriptRoot "setup.log"
function Log($msg) { $t = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg; Write-Host $t -ForegroundColor Cyan; Add-Content $LOG $t }

# 需要管理员权限（内存工具 + 写 MCP 配置）
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Log "WARN: 未以管理员运行，部分工具（Npcap 等）可能受限" }

# ---------- 0. scoop 检查 ----------
Log "==> 检查 scoop"
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Log "未检测到 scoop，正在安装..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
} else { Log "scoop 已安装: $(scoop --version 2>&1 | Select-Object -First 1)" }

# ---------- 1. scoop 包批量安装 ----------
$scoopPackages = @("7zip","cheat-engine","x64dbg","gdb","llvm","dynamorio","sysinternals","vmmap","procmon","ghidra","yara","wireshark","mitmproxy","renderdoc","prometheus","grafana","elasticsearch","anaconda3")
foreach ($p in $scoopPackages) {
    $installed = scoop list 2>$null | Select-String -Pattern "^$p\s"
    if ($installed) { Log "SKIP $p (已安装)" } else {
        Log "安装 $p ..."
        scoop install $p 2>&1 | Select-String -Pattern "installed successfully|already installed|ERROR" | Select-Object -Last 1 | ForEach-Object { Log "    $_" }
    }
}

# ---------- 2. ReClass.NET（手动部署，无 scoop 包） ----------
Log "==> ReClass.NET"
$reclassDir = "$APP_SCOOP\apps\reclass-net\current"
if (Test-Path "$reclassDir\x64\ReClass.NET.exe") { Log "SKIP ReClass.NET (已存在)" }
else {
    try {
        $rar = "$env:TEMP\ReClass.NET.rar"
        Invoke-WebRequest -Uri "https://github.com/ReClassNET/ReClass.NET/releases/download/v1.2/ReClass.NET.rar" -OutFile $rar -UserAgent "opencode"
        New-Item -ItemType Directory -Force -Path $reclassDir | Out-Null
        & "$APP_SCOOP\apps\7zip\current\7z.exe" x $rar "-o$reclassDir" -y | Out-Null
        Log "ReClass.NET 部署完成"
    } catch { Log "ERROR ReClass.NET: $($_.Exception.Message)" }
}

# ---------- 3. Python 生态（anaconda python） ----------
Log "==> Python 生态"
$pyExe = "$APP_SCOOP\apps\anaconda3\current\App\python.exe"
if (Test-Path $pyExe) {
    & $pyExe -m pip install --upgrade pip 2>&1 | Out-Null
    & $pyExe -m pip install scapy frida-tools opencv-python-headless 2>&1 | Select-String -Pattern "Successfully installed|error" | ForEach-Object { Log "    $_" }
    & $pyExe -m pip install torch --index-url https://download.pytorch.org/whl/cpu 2>&1 | Select-String -Pattern "Successfully installed|error" | ForEach-Object { Log "    $_" }
} else { Log "WARN 未找到 anaconda python, 跳过 pip 安装" }

# ---------- 4. Cheat Engine MCP 服务器（插件内已 vendor，无需克隆） ----------
Log "==> Cheat Engine MCP 服务器"
$ceMcpDir = Join-Path $PLUGIN_ROOT "server"
$ceVenv = Join-Path $PLUGIN_ROOT ".venv"
if (-not (Test-Path "$ceVenv\Scripts\python.exe")) {
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { Log "WARN 未找到 uv，尝试用 python -m venv 代替"; & "$pyExe" -m venv $ceVenv 2>&1 | Out-Null }
    else { uv venv $ceVenv 2>&1 | Out-Null }
    # 重要：mcp 2.0 移除了 fastmcp，必须锁定 1.x
    if (Test-Path "$ceVenv\Scripts\python.exe") {
        & "$ceVenv\Scripts\python.exe" -m pip install --upgrade pip 2>&1 | Out-Null
        & "$ceVenv\Scripts\python.exe" -m pip install "mcp>=1.0.0,<2.0.0" trio psutil capstone 2>&1 | Select-String -Pattern "Successfully installed|error" | ForEach-Object { Log "    $_" }
        Log "CE MCP venv 就绪: $ceVenv（服务器源码: $ceMcpDir）"
    } else { Log "ERROR CE MCP venv 创建失败" }
} else { Log "SKIP CE MCP venv (已存在)" }

# ---------- 5. Npcap（Wireshark 抓包依赖，可选） ----------
Log "==> Npcap"
if (-not (Get-Service -Name npcap -ErrorAction SilentlyContinue)) {
    Log "提示: 抓包需要 Npcap。请在 Wireshark 安装器勾选，或从 https://npcap.com 单独安装。scoop 无此包。"
} else { Log "SKIP Npcap (服务已存在)" }

# ---------- 6. MCP 配置写入 ----------
Log "==> 写入 MCP 配置"
$launcher = "$($PLUGIN_ROOT -replace '\\','/')/bin/ce-mcp.cmd"
$ceCmd = @"
{
  "cheat-engine": {
    "type": "local",
    "command": ["$launcher"],
    "enabled": true
  }
}
"@
$oc = "$env:USERPROFILE\.config\opencode\opencode.json"
if (Test-Path $oc) {
    $cfg = Get-Content $oc -Raw | ConvertFrom-Json
    if (-not $cfg.mcp."cheat-engine") {
        $cfg.mcp | Add-Member -NotePropertyName "cheat-engine" -NotePropertyValue @{ type="local"; command=@($launcher); enabled=$true }
        $cfg | ConvertTo-Json -Depth 10 | Set-Content $oc -Encoding UTF8
        Log "已写入 opencode.json (需重启 opencode 生效)"
    } else { Log "SKIP opencode.json (cheat-engine 已配置)" }
} else { Log "WARN 未找到 opencode.json，跳过（插件 mcp.json 会被 Agent Plugins 客户端自动发现）" }

# ---------- 7. 验证 ----------
Log "==> 验证工具版本"
foreach ($v in @(@("yara","--version"), @("gdb","--version"), @("tshark","--version"))) {
    $cmd = $v[0]; try { $o = & $cmd @($v[1]) 2>&1 | Select-Object -First 1; Log "    $cmd : $o" } catch { Log "    $cmd : FAIL" }
}
if ($pyExe -and (Test-Path $pyExe)) { & $pyExe -c "import scapy, frida, cv2, torch; print('scapy',scapy.__version__,'| frida',frida.__version__,'| cv2',cv2.__version__,'| torch',torch.__version__)" 2>&1 | ForEach-Object { Log "    python: $_" } } else { Log "    跳过 python 版本检查（无 anaconda python）" }

Log "==> 完成。下一步: 重启 opencode，运行 scripts\test-mcp.ps1 验证 MCP 连通"
