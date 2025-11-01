@echo off
REM ========================================
REM VS Code Settings Sync Launcher (Windows)
REM ========================================

REM Get the directory of this batch file
set SCRIPT_DIR=%~dp0

REM Run the PowerShell settings_sync.ps1 script with bypass execution policy
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%settings_sync.ps1"

pause
