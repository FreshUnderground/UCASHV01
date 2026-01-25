@echo off
echo ================================================
echo  DEBUG: Verification des assignations shop
echo ================================================
echo.

cd /d "%~dp0"

echo Execution du script de debug...
echo.

dart run debug_agent_shop_assignment.dart

echo.
echo ================================================
echo  Script termine
echo ================================================
echo.
pause
