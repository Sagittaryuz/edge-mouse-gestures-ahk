@echo off
setlocal
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Atualizar-EdgeMouseGestures.ps1" -Launch
if errorlevel 1 pause
endlocal
