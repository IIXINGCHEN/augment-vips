@echo off
chcp 65001 >nul 2>&1
title Augment Anti-Detection Tools - Quick Launcher
setlocal enabledelayedexpansion

:MENU
cls
echo ================================================================
echo                Augment Anti-Detection Tools
echo                      Quick Launcher
echo ================================================================
echo  [Quick Operations]
echo  1. Complete Fix (Recommended for beginners)
echo  2. Smart Anti-Detection (Recommended for advanced users)
echo  3. Reset Trial Account
echo.
echo  [Professional Tools]
echo  4. Session ID Isolation
echo  5. Cross-Account Delinking
echo  6. Device Fingerprint Reset
echo  7. Session Data Cleaning
echo  8. Network Fingerprint Spoofing
echo  9. System Environment Reset
echo.
echo  [Other Options]
echo  A. Analyze Detection Risks
echo  H. Show Usage Guide
echo  0. Exit
echo ================================================================
echo.
set /p choice="Please select an option (0-9, A, H): "

if "%choice%"=="1" goto COMPLETE_FIX
if "%choice%"=="2" goto SMART_ANTI_DETECTION
if "%choice%"=="3" goto RESET_TRIAL
if "%choice%"=="4" goto SESSION_ISOLATION
if "%choice%"=="5" goto CROSS_ACCOUNT_DELINK
if "%choice%"=="6" goto DEVICE_FINGERPRINT
if "%choice%"=="7" goto SESSION_CLEANING
if "%choice%"=="8" goto NETWORK_SPOOF
if "%choice%"=="9" goto SYSTEM_RESET
if /i "%choice%"=="A" goto ANALYZE_RISKS
if /i "%choice%"=="H" goto USAGE_GUIDE
if "%choice%"=="0" goto EXIT

echo Invalid choice. Please try again.
pause
goto MENU

:COMPLETE_FIX
cls
echo ================================================================
echo                    Complete Fix Operation
echo ================================================================
echo This will perform a comprehensive fix including:
echo - Trial account reset
echo - Device fingerprint reset
echo - Session data cleaning
echo - Telemetry modification
echo.
echo Choose operation mode:
echo 1. Preview operations first (recommended)
echo 2. Execute directly
echo 3. Back to main menu
echo.
set /p subchoice="Enter your choice (1-3): "

if "%subchoice%"=="1" (
    echo.
    echo Previewing operations...
    if not exist "src\tools\Complete-Augment-Fix.ps1" (
        echo Error: Complete-Augment-Fix.ps1 not found!
        pause
        goto COMPLETE_FIX
    )
    powershell -ExecutionPolicy Bypass -File "src\tools\Complete-Augment-Fix.ps1" -DryRun
    echo.
    echo Preview completed! If confirmed, you can choose direct execution.
    pause
    goto COMPLETE_FIX
)
if "%subchoice%"=="2" (
    echo.
    echo Executing complete fix...
    if not exist "src\tools\Complete-Augment-Fix.ps1" (
        echo Error: Complete-Augment-Fix.ps1 not found!
        pause
        goto MENU
    )
    powershell -ExecutionPolicy Bypass -File "src\tools\Complete-Augment-Fix.ps1"
    echo.
    echo Fix completed! Please restart VS Code/Cursor to apply changes.
    pause
    goto MENU
)
if "%subchoice%"=="3" goto MENU

echo Invalid choice. Please try again.
pause
goto COMPLETE_FIX

:SMART_ANTI_DETECTION
cls
echo ================================================================
echo                Smart Anti-Detection Operation
echo ================================================================
echo Choose threat level:
echo 1. CONSERVATIVE - Basic protection
echo 2. STANDARD - Balanced protection (recommended)
echo 3. AGGRESSIVE - Maximum protection
echo 4. Back to main menu
echo.
set /p level="Enter your choice (1-4): "

if "%level%"=="1" set THREAT_LEVEL=CONSERVATIVE
if "%level%"=="2" set THREAT_LEVEL=STANDARD
if "%level%"=="3" set THREAT_LEVEL=AGGRESSIVE
if "%level%"=="4" goto MENU

if not defined THREAT_LEVEL (
    echo Invalid choice. Please try again.
    pause
    goto SMART_ANTI_DETECTION
)

echo.
echo Executing %THREAT_LEVEL% level smart anti-detection...
if not exist "src\tools\Advanced-Anti-Detection.ps1" (
    echo Error: Advanced-Anti-Detection.ps1 not found!
    pause
    goto MENU
)
powershell -ExecutionPolicy Bypass -File "src\tools\Advanced-Anti-Detection.ps1" -Operation complete -ThreatLevel %THREAT_LEVEL%
echo.
echo Anti-detection completed!
pause
goto MENU

:RESET_TRIAL
cls
echo ================================================================
echo                  Reset Trial Account
echo ================================================================
echo This will reset your trial account status.
echo.
echo Choose operation:
echo 1. Preview operations first
echo 2. Execute directly
echo 3. Back to main menu
echo.
set /p subchoice="Enter your choice (1-3): "

if "%subchoice%"=="1" (
    echo.
    echo Previewing trial reset...
    powershell -ExecutionPolicy Bypass -File "src\tools\Reset-TrialAccount.ps1" -DryRun
    echo.
    echo Preview completed!
    pause
    goto RESET_TRIAL
)
if "%subchoice%"=="2" (
    echo.
    echo Executing trial reset...
    powershell -ExecutionPolicy Bypass -File "src\tools\Reset-TrialAccount.ps1"
    echo.
    echo Trial reset completed!
    pause
    goto MENU
)
if "%subchoice%"=="3" goto MENU

echo Invalid choice. Please try again.
pause
goto RESET_TRIAL

:SESSION_ISOLATION
echo.
echo Executing session ID isolation...
powershell -ExecutionPolicy Bypass -File "src\tools\Isolate-SessionID.ps1"
echo.
echo Session isolation completed!
pause
goto MENU

:CROSS_ACCOUNT_DELINK
echo.
echo Executing cross-account delinking...
powershell -ExecutionPolicy Bypass -File "src\tools\Delink-CrossAccount.ps1"
echo.
echo Cross-account delinking completed!
pause
goto MENU

:DEVICE_FINGERPRINT
echo.
echo Resetting device fingerprint...
powershell -ExecutionPolicy Bypass -File "src\tools\Reset-DeviceFingerprint.ps1"
echo.
echo Device fingerprint reset completed!
pause
goto MENU

:SESSION_CLEANING
echo.
echo Cleaning session data...
powershell -ExecutionPolicy Bypass -File "src\tools\Clean-SessionData.ps1"
echo.
echo Session data cleaning completed!
pause
goto MENU

:NETWORK_SPOOF
echo.
echo Executing network fingerprint spoofing...
powershell -ExecutionPolicy Bypass -File "src\tools\Network-Spoof.ps1" -Operation spoof -SpoofLevel ADVANCED
echo.
echo Network spoofing completed!
pause
goto MENU

:SYSTEM_RESET
echo.
echo Resetting system environment...
powershell -ExecutionPolicy Bypass -File "src\tools\Reset-SystemEnvironment.ps1"
echo.
echo System environment reset completed!
pause
goto MENU

:ANALYZE_RISKS
echo.
echo Analyzing detection risks...
powershell -ExecutionPolicy Bypass -File "src\tools\Analyze-DetectionRisks.ps1"
echo.
echo Risk analysis completed!
pause
goto MENU

:USAGE_GUIDE
echo.
echo Opening usage guide...
if exist "docs\usage-guide.txt" (
    type "docs\usage-guide.txt"
) else (
    echo Usage guide file not found!
)
pause
goto MENU

:EXIT
echo.
echo Thank you for using Augment Anti-Detection Tools!
echo.
pause
exit /b 0
