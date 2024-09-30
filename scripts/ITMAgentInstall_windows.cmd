@echo off
set CURDIR=%~dp0
set PortablePython=%CURDIR%PortablePython/
set PATH=%PortablePython%;%CURDIR%;%PATH%
set PYFILE=%CURDIR%ITMAgentInstall_windows.py
set PYEXE=%PortablePython%python.exe
set Parm1=%1
shift
set Parm2=%1
shift
set Parm3=%1
shift
set Parm4=%1
shift
set Parm5=%1
shift
set Parm6=%1
shift
set Parm7=%1
shift
set Parm8=%1
shift
set Parm9=%1
shift
set Parm10=%1
@REM echo %Parm1%
@REM echo %Parm2%
@REM echo %Parm3%
@REM echo %Parm4%
@REM echo %Parm5%
@REM echo %Parm6%
@REM echo %Parm7%
@REM echo %Parm8%
@REM echo %Parm9%
@REM echo %Parm10%
%PYEXE% %PYFILE% %Parm1% %Parm2% %Parm3% %Parm4% %Parm5% %Parm6% %Parm7% %Parm8% %Parm9% %Parm10% 2>&1