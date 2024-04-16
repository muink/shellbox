@echo off
@chcp 65001 >nul
for /f "delims=" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles"') do (
	reg query "%%~i" /v ProfileName | findstr "shellbox-tun" >nul && (
		reg query "%%~i" /v Category | findstr "Category" | findstr "0x0" >nul && reg add "%%~i" /v Category /t REG_DWORD /d 1 /f
	)
)
:: Or powershell
:: powershell -c 'Get-NetConnectionProfile'
:: powershell -c 'Set-NetConnectionProfile -Name "shellbox-tun" -NetworkCategory Private'
