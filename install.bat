@echo off
REM install.bat
REM Simple Windows batch entry point for Augment VIP
REM Fallback entry point with minimal dependencies

setlocal

REM Get script directory
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM Default operation
set "OPERATION=help"
set "DRY_RUN="
set "VERBOSE="

REM Parse simple arguments
:parse_args
if "%~1"=="" goto :done_parsing
if /i "%~1"=="--help" set "OPERATION=help" & goto :execute
if /i "%~1"=="-h" set "OPERATION=help" & goto :execute
if /i "%~1"=="clean" set "OPERATION=clean"
if /i "%~1"=="modify-ids" set "OPERATION=modify-ids"
if /i "%~1"=="all" set "OPERATION=all"
if /i "%~1"=="help" set "OPERATION=help"
if /i "%~1"=="--dry-run" set "DRY_RUN=-DryRun"
if /i "%~1"=="-d" set "DRY_RUN=-DryRun"
if /i "%~1"=="--verbose" set "VERBOSE=-Verbose"
if /i "%~1"=="-v" set "VERBOSE=-Verbose"
shift
goto :parse_args

:done_parsing

:execute
echo [INFO] Augment VIP Windows Entry Point
echo [INFO] Operation: %OPERATION%

REM Find PowerShell implementation
set "PS_SCRIPT=%SCRIPT_DIR%\install.ps1"
if not exist "%PS_SCRIPT%" (
    set "PS_SCRIPT=%SCRIPT_DIR%\src\platforms\windows.ps1"
)
if not exist "%PS_SCRIPT%" (
    set "PS_SCRIPT=%SCRIPT_DIR%\platforms\windows.ps1"
)

if not exist "%PS_SCRIPT%" (
    echo [ERROR] PowerShell implementation not found
    echo [ERROR] Expected: install.ps1 or src\platforms\windows.ps1 or platforms\windows.ps1
    exit /b 1
)

echo [INFO] Using PowerShell implementation: %PS_SCRIPT%

REM Execute PowerShell script
powershell.exe -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Operation "%OPERATION%" %DRY_RUN% %VERBOSE%
exit /b %errorlevel%
