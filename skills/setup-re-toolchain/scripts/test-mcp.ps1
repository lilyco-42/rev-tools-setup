# 通过 mcp SDK 验证 Cheat Engine MCP 服务器连通与工具列表
# 用法: powershell -ExecutionPolicy Bypass -File test-mcp.ps1
# 说明: 代理到 test-mcp.py（更稳定），并显式传入解释器路径，避免启动器 env 透传问题。
param()

$PLUGIN_ROOT = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$pyScript = Join-Path $PSScriptRoot "test-mcp.py"

# 解释器优先级：CE_MCP_PYTHON > 插件 .venv > PATH python（要求已装 mcp SDK）
$py = $null
if ($env:CE_MCP_PYTHON -and (Test-Path $env:CE_MCP_PYTHON)) { $py = $env:CE_MCP_PYTHON }
elseif (Test-Path (Join-Path $PLUGIN_ROOT ".venv\Scripts\python.exe")) { $py = Join-Path $PLUGIN_ROOT ".venv\Scripts\python.exe" }
elseif (Get-Command python -ErrorAction SilentlyContinue) { $py = (Get-Command python).Source }

if (-not $py) { Write-Error "找不到 python。请先运行 setup.ps1（或设置 CE_MCP_PYTHON）。"; exit 1 }

& $py $pyScript --python $py
exit $LASTEXITCODE
