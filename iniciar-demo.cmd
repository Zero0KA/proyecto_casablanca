@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0iniciar-demo.ps1"
if errorlevel 1 (
    echo.
    echo No se pudo completar el inicio. Consulta el mensaje anterior.
    pause
)
endlocal
