# 通过 stdio JSON-RPC 验证 MCP 服务器连通与工具列表
# 用法: powershell -ExecutionPolicy Bypass -File test-mcp.ps1 [-Server cheat-engine]
param(
    [string]$Server = "cheat-engine",
    [string]$McpDir = "D:\app\scoop\apps\ce-mcp-server"
)

$configs = @{
    "cheat-engine" = @{
        cmd = "$McpDir\.venv\Scripts\python.exe"
        args = @("$McpDir\server\main.py", "--read-only")
    }
}

$entry = $configs[$Server]
if (-not $entry) { Write-Error "未知服务器: $Server"; exit 1 }
if (-not (Test-Path $entry.cmd)) { Write-Error "找不到解释器: $($entry.cmd)"; exit 1 }

# 1. initialize
$init = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"mcp-test","version":"1.0"}}}'
# 2. initialized 通知
$notif = '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
# 3. tools/list
$list = '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
# 4. list_processes 真实调用
$call = '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_processes","arguments":{}}}'

$payload = "$init`n$notif`n$list`n$call"
Write-Host "==> 测试 $Server MCP 服务器 ..." -ForegroundColor Cyan
$out = $payload | & $entry.cmd @($entry.args) 2>$null

# 提取 JSON-RPC 结果
$results = $out | Where-Object { $_ -match '"jsonrpc"' }
if (-not $results) { Write-Error "无响应，服务器可能未启动。加 2>&1 查看 stderr。"; exit 1 }

$initOk = $results | Select-String -Pattern '"id":1.*serverInfo|serverInfo.*"id":1' -Quiet
$listLine = $results | Select-String -Pattern '"id":2' | Select-Object -First 1
$callLine = $results | Select-String -Pattern '"id":3' | Select-Object -First 1

Write-Host "初始化握手: $(if($initOk){'OK'}else{'FAIL'})"
Write-Host "tools/list: $(if($listLine){'OK'}else{'FAIL'})"
if ($callLine) {
    $toolNames = ([regex]::Matches($listLine.Line, '"name":"[a-z_]+"') | ForEach-Object { $_.Value.Trim('"').Substring(7) }) -join ", "
    Write-Host "工具数: $(($toolNames -split ', ').Count)"
    Write-Host "工具: $toolNames"
    Write-Host "list_processes 调用:"
    $callLine.Line | ConvertFrom-Json | ForEach-Object { $_.result.content | ForEach-Object { Write-Host "    $($_.text)" } }
} else {
    Write-Error "tools/call 失败"
}
