@echo off
REM Launch PowerShell link updater
set SCRIPT_DIR=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%linkupdater.ps1"
pause
