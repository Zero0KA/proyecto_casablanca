@echo off
setlocal
title CASABLANCA - COMPROBACION
cd /d "%~dp0"
call npm.cmd run lint
if errorlevel 1 goto fallo
node --test tests/*.test.mjs
if errorlevel 1 goto fallo
call npm.cmd run build
if errorlevel 1 goto fallo
echo.
echo COMPROBACION CORRECTA. No se modifico la base de datos.
pause
exit /b 0
:fallo
echo.
echo La comprobacion fallo. Revisa el primer error antes de publicar.
pause
exit /b 1
