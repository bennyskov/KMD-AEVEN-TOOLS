@echo off
set CURDIR=%~dp0
set PortablePythonPath=%CURDIR%PortablePython

echo Setting up direct access to PortablePython for VS Code...

REM Create a .vscode directory in the project root if it doesn't exist
if not exist "%CURDIR%..\.vscode" mkdir "%CURDIR%..\.vscode"

REM Create settings.json to point directly to the portable Python
echo {
echo     "python.defaultInterpreterPath": "%PortablePythonPath:\=\\%\\python.exe",
echo     "python.terminal.activateEnvironment": false,
echo     "python.linting.enabled": true,
echo     "terminal.integrated.env.windows": {
echo         "PYTHONPATH": "${workspaceFolder}"
echo     },
echo     "python.analysis.extraPaths": [
echo         "%PortablePythonPath:\=\\%\\Lib",
echo         "%PortablePythonPath:\=\\%\\Lib\\site-packages"
echo     ]
echo } > "%CURDIR%..\.vscode\settings.json"

echo Installing required packages directly to PortablePython...
"%PortablePythonPath%\python.exe" -m pip install --upgrade pip
"%PortablePythonPath%\python.exe" -m pip install humanize psutil requests PyYAML colorama

echo PortablePython setup complete!
echo.
echo To use this environment in VS Code:
echo 1. Open VS Code
echo 2. Press Ctrl+Shift+P
echo 3. Type "Python: Select Interpreter"
echo 4. Choose the interpreter at %PortablePythonPath%\python.exe
echo.
echo Press any key to exit...
pause > nul