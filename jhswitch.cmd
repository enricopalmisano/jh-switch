@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0jhswitch.ps1" %*
endlocal
