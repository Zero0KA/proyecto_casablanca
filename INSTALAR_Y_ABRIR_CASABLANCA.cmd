@echo off
setlocal
cd /d "%~dp0"
title CASABLANCA - INSTALACION LOCAL
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar-casablanca.ps1"
if errorlevel 1 (
  echo.
  echo La instalacion no se completo. Revisa el mensaje de arriba.
  pause
)
endlocal
