"""通过 mcp Python SDK 验证 Cheat Engine MCP 服务器连通与工具列表。

用法: test-mcp.py [--python PATH] [--main PATH]
不带参数时自动探测：bin/ce-mcp.cmd 启动器 > 插件 .venv > CE_MCP_PYTHON 环境变量。
"""
import asyncio, argparse, os, sys

try:
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client
except ImportError:
    sys.exit("mcp SDK 未安装。请先运行 setup.ps1 创建 venv 并安装 'mcp>=1.0.0,<2.0.0'")

PLUGIN_ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))

def resolve_params(args):
    if args.python and os.path.exists(args.python):
        main = args.main or os.path.join(PLUGIN_ROOT, "server", "server", "main.py")
        if not os.path.exists(main):
            main = os.path.join(PLUGIN_ROOT, "server", "main.py")
        return StdioServerParameters(command=args.python, args=[main, "--read-only"])
    launcher = os.path.join(PLUGIN_ROOT, "bin", "ce-mcp.cmd")
    if os.path.exists(launcher):
        return StdioServerParameters(command=launcher, args=[], cwd=PLUGIN_ROOT)
    main = os.path.join(PLUGIN_ROOT, "server", "server", "main.py")
    if not os.path.exists(main):
        main = os.path.join(PLUGIN_ROOT, "server", "main.py")
    venv_py = os.path.join(PLUGIN_ROOT, ".venv", "Scripts", "python.exe")
    if os.path.exists(venv_py):
        return StdioServerParameters(command=venv_py, args=[main, "--read-only"])
    py = os.environ.get("CE_MCP_PYTHON")
    if py and os.path.exists(py):
        return StdioServerParameters(command=py, args=[main, "--read-only"])
    sys.exit("找不到 MCP 启动器或 venv。请先运行 setup.ps1（或设置 CE_MCP_PYTHON）。")

async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--python")
    ap.add_argument("--main")
    args = ap.parse_args()
    params = resolve_params(args)
    ok = {"init": False, "list": False, "call": False}
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            ok["init"] = True
            print("初始化握手: OK")
            tools = await session.list_tools()
            names = sorted(t.name for t in tools.tools)
            ok["list"] = True
            print(f"tools/list: OK ({len(names)} 个工具)")
            print("工具:", ", ".join(names))
            res = await session.call_tool("list_processes", {})
            ok["call"] = True
            print("list_processes 调用: OK")
            for c in res.content:
                print("    ", c.text)
    print("RESULT:", "ALL OK" if all(ok.values()) else "PARTIAL")

if __name__ == "__main__":
    asyncio.run(main())
