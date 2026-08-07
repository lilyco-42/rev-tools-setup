@echo off
rem Agent Plugin launcher for the Cheat Engine MCP server.
rem Resolves a python that has the mcp SDK (1.x, fastmcp), then starts server/main.py in read-only mode.
rem Candidate order: $CE_MCP_PYTHON (client-injected, usually ${PLUGIN_DATA}/.venv) > plugin .venv > PATH python.

set "PLUGIN_ROOT=%~dp0.."

set "SERVER=%PLUGIN_ROOT%\server\server\main.py"
if not exist "%SERVER%" set "SERVER=%PLUGIN_ROOT%\server\main.py"

set "CHECK=import mcp,mcp.server.fastmcp"

call :try_python "%CE_MCP_PYTHON%" && exit /b 0
call :try_python "%PLUGIN_ROOT%\.venv\Scripts\python.exe" && exit /b 0
for %%p in (python.exe python3.exe) do (
    where %%p >nul 2>nul
    if not errorlevel 1 call :try_path_python %%p && exit /b 0
)

echo [ce-mcp] ERROR: no python with mcp>=1.0,<2.0 found. Run the setup-re-toolchain skill (setup.ps1) first. 1>&2
exit /b 1

:try_path_python
"%~1" -c "%CHECK%" >nul 2>nul
if errorlevel 1 exit /b 1
"%~1" "%SERVER%" --read-only
exit /b 0

:try_python
if "%~1"=="" exit /b 1
if not exist "%~1" exit /b 1
"%~1" -c "%CHECK%" >nul 2>nul
if errorlevel 1 exit /b 1
"%~1" "%SERVER%" --read-only
exit /b 0
