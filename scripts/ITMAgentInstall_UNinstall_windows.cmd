set CURDIR=%~dp0
set PortablePython=%CURDIR%PortablePython/
set PATH=%PortablePython%;%CURDIR%;%PATH%
set PYFILE=%CURDIR%ITMAgentInstall_UNinstall_windows.py
set PYEXE=%PortablePython%python.exe
set PYEXE=python.exe
%PYEXE% --version
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
echo %Parm1%
echo %Parm2%
echo %Parm3%
echo %Parm4%
echo %Parm5%
echo %Parm6%
echo %Parm7%
echo %Parm8%
echo %Parm9%
echo %Parm10%
%PYEXE% %PYFILE% %Parm1% %Parm2% %Parm3% %Parm4% %Parm5% %Parm6% %Parm7% %Parm8% %Parm9% %Parm10%