@echo off
REM ============================================
REM  VS Code Portable Updater Launcher (Windows)
REM ============================================

REM Get the current script directory
set SCRIPT_DIR=%~dp0

REM Run the PowerShell updater script
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%update_vscode.ps1"

REM Pause at the end so users can see log messages
echo.
pause
