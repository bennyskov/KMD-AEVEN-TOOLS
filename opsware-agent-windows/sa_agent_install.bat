@echo off
setlocal EnableDelayedExpansion

Rem   Name: sa_agent_install.sh
Rem   Author: XHMA
Rem   Date: 2024-09-04
Rem   Description: script to install SA agent.
Rem
Rem   Changes:
Rem
Rem   Date        By      Review          Vers.   Change
Rem   ==========  ====    ======          =====   ==================================================
Rem   2024-09-04  XHMA    XXXX            1.0     Intial for SA agent installation
Rem   2024-10-02  JAF     YYYY            1.1     Changed install to KMD 
Rem
Rem

set VERSION=1.0

Rem ************************************************************
Rem for Shared customer_id enabel below 
Rem ************************************************************
Rem set OPSW_GW_ADDR=152.73.224.35:3001,152.73.224.36:3001 
Rem ************************************************************

Rem ************************************************************
Rem for KMD use below gateway and cusomer 
Rem ************************************************************
set OPSW_GW_ADDR=84.255.75.1:3001,84.255.75.2:3001 
Rem ************************************************************
 

set INSTALL_LOG=C:\Windows\Temp\opsware-agent-windows\sa-agent_install.log
set INSTALL_PATH=C:\Windows\Temp\opsware-agent-windows
set INSTALL_PARAMETERS= -f -r --force_new_device --force_full_hw_reg --crypto_dir %INSTALL_PATH% --logfile %INSTALL_LOG% --loglevel info --opsw_gw_addr 
CD /D %WORKDIR%

cls
echo.
echo SA Agent install on Winodows servers.
echo HOSTNAME: %COMPUTERNAME%
echo DATETIME: %DATE% %TIME:~0,8%
echo USER: %USERNAME%
echo SCRIPT VERSION: %VERSION%
echo.
wmic os get Caption /value |findstr 2022  
if %ERRORLEVEL% == 0 goto win2022
wmic os get Caption /value |findstr 2019 
if %ERRORLEVEL% == 0 goto win2019
wmic os get Caption /value |findstr 2016 
if %ERRORLEVEL% == 0 goto win2016
wmic os get Caption /value |findstr "2012 R2"
if %ERRORLEVEL% == 0 goto win2012R2
wmic os get Caption /value |findstr "2012"
if %ERRORLEVEL% == 0 goto UnsupportedOS
wmic os get Caption /value |findstr "2008 R2"
if %ERRORLEVEL% == 0 goto UnsupportedOS
wmic os get Caption /value |findstr "2008"
if %ERRORLEVEL% == 0 goto UnsupportedOS
wmic os get Caption /value |findstr "2003"
if %ERRORLEVEL% == 0 goto UnsupportedOS 

goto end

echo.
echo.


:win2022
set AGENT_INSTALLER=%INSTALL_PATH%\2022\opsware-agent-90.0.96031.0-win32-10.0.2009-X64.exe
echo %AGENT_INSTALLER%
if not exist %AGENT_INSTALLER% (
	echo Couldn't find the the opsware-agent installer.
	goto end
	) else goto install_agent

:win2019
set AGENT_INSTALLER=%INSTALL_PATH%\2019\opsware-agent-90.0.96031.0-win32-10.0.1809-X64.exe
echo %AGENT_INSTALLER%
if not exist %AGENT_INSTALLER% (
	echo Couldn't find the the opsware-agent installer.
	goto end
	) else goto install_agent

:win2016
set AGENT_INSTALLER=%INSTALL_PATH%\2016\opsware-agent-90.0.96031.0-win32-10.0-X64.exe
echo %AGENT_INSTALLER%
if not exist %AGENT_INSTALLER% (
	echo Couldn't find the the opsware-agent installer.
	goto end
	) else goto install_agent

:win2012R2
echo from Win 2012R2
set AGENT_INSTALLER=%INSTALL_PATH%\2012R2\opsware-agent-90.0.96031.0-win32-6.3-X64.exe
echo %AGENT_INSTALLER%
if not exist %AGENT_INSTALLER% (
	echo Couldn't find the the opsware-agent installer.
	goto end
	) else goto install_agent

:UnsupportedOS
echo Not supported Operating System.
goto end

:install_agent

REM check if SA agent is already installed
set CHECK_MID=C:\"Program Files"\"Common Files"\Opsware\etc\agent\mid
if exist %CHECK_MID%  (
	echo SA agent is already installed, Fix agent's reachability or uninstall SA agent.
	echo To uninstall SA agent execute the script at path:
	echo C:\"Program Files"\Opsware\agent\pylibs3\cog\uninstall\agent_uninstall.bat --force
	goto end
	)
	

echo INFO: Installing SA Agent ...

echo.
echo.
echo "************************************** Install command **************************************  "
echo %AGENT_INSTALLER%%INSTALL_PARAMETERS%%OPSW_GW_ADDR%
echo.
echo.
 %AGENT_INSTALLER%%INSTALL_PARAMETERS%%OPSW_GW_ADDR%

:end 