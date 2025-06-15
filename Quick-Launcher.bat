@echo off
chcp 65001 >nul
title Augment Anti-Detection Tools - Quick Launcher

:MENU
cls
echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║                Augment Anti-Detection Tools                  ║
echo ║                      Quick Launcher                          ║
echo ╠══════════════════════════════════════════════════════════════╣
echo ║                                                              ║
echo ║  【Quick Operations】                                        ║
echo ║  1. Complete Fix (Recommended for beginners)                ║
echo ║  2. Smart Anti-Detection (Recommended for advanced users)   ║
echo ║  3. Reset Trial Account                                      ║
echo ║                                                              ║
echo ║  【Professional Tools】                                     ║
echo ║  4. Session ID Isolation                                     ║
echo ║  5. Cross-Account Delinking                                  ║
echo ║  6. Device Fingerprint Reset                                 ║
echo ║  7. Session Data Cleaning                                    ║
echo ║  8. Network Fingerprint Spoofing                             ║
echo ║  9. System Environment Reset                                 ║
echo ║                                                              ║
echo ║  【Other Options】                                           ║
echo ║  A. Analyze Detection Risks                                  ║
echo ║  H. Show Usage Guide                                         ║
echo ║  0. Exit                                                     ║
echo ║                                                              ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
set /p choice=Please select operation (1-9, A, H, 0): 

if "%choice%"=="1" goto COMPLETE_FIX
if "%choice%"=="2" goto SMART_ANTI_DETECTION
if "%choice%"=="3" goto RESET_TRIAL
if "%choice%"=="4" goto SESSION_ISOLATOR
if "%choice%"=="5" goto CROSS_ACCOUNT_DELINK
if "%choice%"=="6" goto RESET_DEVICE
if "%choice%"=="7" goto CLEAN_SESSION
if "%choice%"=="8" goto NETWORK_SPOOF
if "%choice%"=="9" goto SYSTEM_RESET
if /i "%choice%"=="A" goto ANALYZE_RISKS
if /i "%choice%"=="H" goto SHOW_GUIDE
if "%choice%"=="0" goto EXIT

echo Invalid selection, please try again...
pause
goto MENU

:COMPLETE_FIX
cls
echo ╔══════════════════════════════════════════════════════════════╗
echo ║                      Complete Fix                            ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo This will execute complete anti-detection fix process, including:
echo - Trial account reset
echo - Device fingerprint reset  
echo - Session data cleaning
echo - System environment reset
echo.
echo 1. Preview mode (Recommended)
echo 2. Direct execution
echo 3. Return to main menu
echo.
set /p subchoice=Please select: 

if "%subchoice%"=="1" (
    echo.
    echo Previewing operations...
    powershell -ExecutionPolicy Bypass -File "src\tools\Complete-Augment-Fix.ps1" -DryRun
    echo.
    echo Preview completed! If confirmed, you can choose direct execution.
    pause
    goto COMPLETE_FIX
)
if "%subchoice%"=="2" (
    echo.
    echo Executing complete fix...
    powershell -ExecutionPolicy Bypass -File "src\tools\Complete-Augment-Fix.ps1"
    echo.
    echo Fix completed! Please restart VS Code/Cursor to apply changes.
    pause
    goto MENU
)
if "%subchoice%"=="3" goto MENU

echo Invalid selection...
pause
goto COMPLETE_FIX

:SMART_ANTI_DETECTION
cls
echo ╔══════════════════════════════════════════════════════════════╗
echo ║                   Smart Anti-Detection                       ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo Select threat level:
echo 1. Conservative mode (CONSERVATIVE) - Minimal impact
echo 2. Standard mode (STANDARD) - Balanced effect
echo 3. Aggressive mode (AGGRESSIVE) - Strong anti-detection (Recommended)
echo 4. Nuclear mode (NUCLEAR) - Maximum intensity
echo 5. Return to main menu
echo.
set /p level=Please select threat level: 

if "%level%"=="1" set THREAT_LEVEL=CONSERVATIVE
if "%level%"=="2" set THREAT_LEVEL=STANDARD  
if "%level%"=="3" set THREAT_LEVEL=AGGRESSIVE
if "%level%"=="4" set THREAT_LEVEL=NUCLEAR
if "%level%"=="5" goto MENU

if not defined THREAT_LEVEL (
    echo Invalid selection...
    pause
    goto SMART_ANTI_DETECTION
)

echo.
echo Executing %THREAT_LEVEL% level smart anti-detection...
powershell -ExecutionPolicy Bypass -File "src\tools\Advanced-Anti-Detection.ps1" -Operation complete -ThreatLevel %THREAT_LEVEL%
echo.
echo Anti-detection completed!
pause
goto MENU

:RESET_TRIAL
cls
echo ╔══════════════════════════════════════════════════════════════╗
echo ║                    Reset Trial Account                       ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo 1. Preview reset operation
echo 2. Execute reset
echo 3. Return to main menu
echo.
set /p subchoice=Please select: 

if "%subchoice%"=="1" (
    echo.
    echo Previewing reset operation...
    powershell -ExecutionPolicy Bypass -File "src\tools\Reset-TrialAccount.ps1" -DryRun
    pause
    goto RESET_TRIAL
)
if "%subchoice%"=="2" (
    echo.
    echo Resetting trial account...
    powershell -ExecutionPolicy Bypass -File "src\tools\Reset-TrialAccount.ps1"
    echo.
    echo Reset completed!
    pause
    goto MENU
)
if "%subchoice%"=="3" goto MENU

echo Invalid selection...
pause
goto RESET_TRIAL

:SESSION_ISOLATOR
cls
echo ╔══════════════════════════════════════════════════════════════╗
echo ║                    Session ID Isolation                      ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo 1. Analyze session correlation risks
echo 2. Execute session isolation (HIGH level)
echo 3. Execute session isolation (CRITICAL level)
echo 4. Return to main menu
echo.
set /p subchoice=Please select: 

if "%subchoice%"=="1" (
    powershell -ExecutionPolicy Bypass -File "src\tools\Session-ID-Isolator.ps1" -Operation analyze
    pause
    goto SESSION_ISOLATOR
)
if "%subchoice%"=="2" (
    powershell -ExecutionPolicy Bypass -File "src\tools\Session-ID-Isolator.ps1" -Operation isolate -IsolationLevel HIGH
    pause
    goto MENU
)
if "%subchoice%"=="3" (
    powershell -ExecutionPolicy Bypass -File "src\tools\Session-ID-Isolator.ps1" -Operation isolate -IsolationLevel CRITICAL
    pause
    goto MENU
)
if "%subchoice%"=="4" goto MENU

echo Invalid selection...
pause
goto SESSION_ISOLATOR

:CROSS_ACCOUNT_DELINK
cls
echo ╔══════════════════════════════════════════════════════════════╗
echo ║                  Cross-Account Delinking                     ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo 1. Analyze correlation risks
echo 2. Execute delinking (AGGRESSIVE level)
echo 3. Execute delinking (NUCLEAR level)
echo 4. Return to main menu
echo.
set /p subchoice=Please select: 

if "%subchoice%"=="1" (
    powershell -ExecutionPolicy Bypass -File "src\tools\Cross-Account-Delinker.ps1" -Operation analyze
    pause
    goto CROSS_ACCOUNT_DELINK
)
if "%subchoice%"=="2" (
    powershell -ExecutionPolicy Bypass -File "src\tools\Cross-Account-Delinker.ps1" -Operation delink -DelinkLevel AGGRESSIVE
    pause
    goto MENU
)
if "%subchoice%"=="3" (
    powershell -ExecutionPolicy Bypass -File "src\tools\Cross-Account-Delinker.ps1" -Operation delink -DelinkLevel NUCLEAR
    pause
    goto MENU
)
if "%subchoice%"=="4" goto MENU

echo Invalid selection...
pause
goto CROSS_ACCOUNT_DELINK

:RESET_DEVICE
cls
echo ╔══════════════════════════════════════════════════════════════╗
echo ║                 Device Fingerprint Reset                     ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo Resetting device fingerprint...
powershell -ExecutionPolicy Bypass -File "src\tools\Reset-DeviceFingerprint.ps1"
echo.
echo Device fingerprint reset completed!
pause
goto MENU

:CLEAN_SESSION
cls
echo ╔══════════════════════════════════════════════════════════════╗
echo ║                   Session Data Cleaning                      ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo Cleaning session data...
powershell -ExecutionPolicy Bypass -File "src\tools\Clean-SessionData.ps1"
echo.
echo Session data cleaning completed!
pause
goto MENU

:NETWORK_SPOOF
cls
echo ╔══════════════════════════════════════════════════════════════╗
echo ║                Network Fingerprint Spoofing                  ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo Executing network fingerprint spoofing...
powershell -ExecutionPolicy Bypass -File "src\tools\Network-Fingerprint-Spoof.ps1" -Operation spoof -SpoofLevel ADVANCED
echo.
echo Network fingerprint spoofing completed!
pause
goto MENU

:SYSTEM_RESET
cls
echo ╔══════════════════════════════════════════════════════════════╗
echo ║                  System Environment Reset                    ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo Warning: System environment reset will perform deep cleanup and may require administrator privileges.
echo.
echo 1. Preview reset operation
echo 2. Execute reset (DEEP level)
echo 3. Return to main menu
echo.
set /p subchoice=Please select: 

if "%subchoice%"=="1" (
    powershell -ExecutionPolicy Bypass -File "src\tools\System-Environment-Reset.ps1" -Operation complete -ResetLevel DEEP -DryRun
    pause
    goto SYSTEM_RESET
)
if "%subchoice%"=="2" (
    powershell -ExecutionPolicy Bypass -File "src\tools\System-Environment-Reset.ps1" -Operation complete -ResetLevel DEEP
    pause
    goto MENU
)
if "%subchoice%"=="3" goto MENU

echo Invalid selection...
pause
goto SYSTEM_RESET

:ANALYZE_RISKS
cls
echo ╔══════════════════════════════════════════════════════════════╗
echo ║                   Analyze Detection Risks                    ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo Analyzing current detection risks...
powershell -ExecutionPolicy Bypass -File "src\tools\Advanced-Anti-Detection.ps1" -Operation analyze -VerboseOutput
echo.
pause
goto MENU

:SHOW_GUIDE
cls
echo ╔══════════════════════════════════════════════════════════════╗
echo ║                       Usage Guide                            ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo Opening usage guide...
if exist "Anti-Detection-Tools-Guide.md" (
    start "" "Anti-Detection-Tools-Guide.md"
) else (
    echo Usage guide file not found!
)
pause
goto MENU

:EXIT
cls
echo.
echo Thank you for using Augment Anti-Detection Tools!
echo.
echo Important reminders:
echo - Please restart VS Code/Cursor after operations
echo - Recommend running regularly for best results
echo - Check usage guide if you encounter issues
echo.
pause
exit
