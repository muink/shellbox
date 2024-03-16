@echo off
@chcp 65001 >nul
for /f "tokens=6 delims= " %%i in ('netsh interface ipv4 show route ^| findstr "%~1"') do echo %%~i
