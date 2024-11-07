@echo off
@REM use refresh yes, for clean start
set Parm1=%1
shift
set Parm2=%1
set WORKDIR="C:/Windows/Temp/servercheck/"
CD /D %WORKDIR%
set PSFILE="servercheck.ps1"
REM echo %Parm1%
REM echo %Parm2%
PowerShell -NonInteractive -ExecutionPolicy Unrestricted -InputFormat none -file %PSFILE% %Parm1% %Parm2% 2>&1