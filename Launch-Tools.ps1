# Augment Anti-Detection Tools - PowerShell Launcher
# Usage: powershell -ExecutionPolicy Bypass -File "Launch-Tools.ps1"

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("menu", "quick", "trial", "device", "session", "analyze", "help")]
    [string]$Action = "menu"
)

function Show-Banner {
    Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                Augment Anti-Detection Tools                  ║
║                   PowerShell Launcher                        ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
}

function Show-Menu {
    Clear-Host
    Show-Banner
    Write-Host ""
    Write-Host "【Quick Operations】" -ForegroundColor Yellow
    Write-Host "  1. Complete Fix (Recommended)" -ForegroundColor Green
    Write-Host "  2. Smart Anti-Detection (Aggressive Mode)" -ForegroundColor Green
    Write-Host "  3. Reset Trial Account" -ForegroundColor Green
    Write-Host ""
    Write-Host "【Professional Tools】" -ForegroundColor Yellow
    Write-Host "  4. Device Fingerprint Reset" -ForegroundColor White
    Write-Host "  5. Session Data Cleaning" -ForegroundColor White
    Write-Host "  6. Session ID Isolation" -ForegroundColor White
    Write-Host "  7. Cross-Account Delinking" -ForegroundColor White
    Write-Host ""
    Write-Host "【Analysis Tools】" -ForegroundColor Yellow
    Write-Host "  A. Analyze Detection Risks" -ForegroundColor Magenta
    Write-Host "  H. Show Help" -ForegroundColor Magenta
    Write-Host "  0. Exit" -ForegroundColor Red
    Write-Host ""
    
    $choice = Read-Host "Please select operation"
    
    switch ($choice) {
        "1" { Invoke-CompleteFix }
        "2" { Invoke-SmartAntiDetection }
        "3" { Invoke-TrialReset }
        "4" { Invoke-DeviceReset }
        "5" { Invoke-SessionClean }
        "6" { Invoke-SessionIsolator }
        "7" { Invoke-CrossAccountDelink }
        "A" { Invoke-AnalyzeRisks }
        "a" { Invoke-AnalyzeRisks }
        "H" { Show-Help }
        "h" { Show-Help }
        "0" { exit 0 }
        default { 
            Write-Host "Invalid selection, please try again..." -ForegroundColor Red
            Start-Sleep 2
            Show-Menu 
        }
    }
}

function Invoke-CompleteFix {
    Write-Host "`nExecuting complete fix..." -ForegroundColor Green
    Write-Host "This includes: trial account reset, device fingerprint reset, session data cleaning, etc." -ForegroundColor Yellow
    
    $confirm = Read-Host "`nPreview operations first? (Y/n)"
    if ($confirm -ne "n" -and $confirm -ne "N") {
        Write-Host "`n=== Preview Mode ===" -ForegroundColor Cyan
        & "src\tools\Complete-Augment-Fix.ps1" -DryRun
        
        $proceed = Read-Host "`nPreview completed, continue execution? (Y/n)"
        if ($proceed -eq "n" -or $proceed -eq "N") {
            Write-Host "Operation cancelled" -ForegroundColor Yellow
            Pause-AndReturn
            return
        }
    }
    
    Write-Host "`n=== Executing Fix ===" -ForegroundColor Green
    & "src\tools\Complete-Augment-Fix.ps1"
    Write-Host "`nFix completed! Please restart VS Code/Cursor to apply changes." -ForegroundColor Green
    Pause-AndReturn
}

function Invoke-SmartAntiDetection {
    Write-Host "`nExecuting smart anti-detection (aggressive mode)..." -ForegroundColor Green
    & "src\tools\Advanced-Anti-Detection.ps1" -Operation complete -ThreatLevel AGGRESSIVE
    Write-Host "`nAnti-detection completed!" -ForegroundColor Green
    Pause-AndReturn
}

function Invoke-TrialReset {
    Write-Host "`nResetting trial account..." -ForegroundColor Green
    
    $preview = Read-Host "Preview operations first? (Y/n)"
    if ($preview -ne "n" -and $preview -ne "N") {
        & "src\tools\Reset-TrialAccount.ps1" -DryRun
        $proceed = Read-Host "`nContinue execution? (Y/n)"
        if ($proceed -eq "n" -or $proceed -eq "N") {
            Pause-AndReturn
            return
        }
    }
    
    & "src\tools\Reset-TrialAccount.ps1"
    Write-Host "`nTrial account reset completed!" -ForegroundColor Green
    Pause-AndReturn
}

function Invoke-DeviceReset {
    Write-Host "`nResetting device fingerprint..." -ForegroundColor Green
    & "src\tools\Reset-DeviceFingerprint.ps1"
    Write-Host "`nDevice fingerprint reset completed!" -ForegroundColor Green
    Pause-AndReturn
}

function Invoke-SessionClean {
    Write-Host "`nCleaning session data..." -ForegroundColor Green
    & "src\tools\Clean-SessionData.ps1"
    Write-Host "`nSession data cleaning completed!" -ForegroundColor Green
    Pause-AndReturn
}

function Invoke-SessionIsolator {
    Write-Host "`nExecuting session ID isolation..." -ForegroundColor Green
    & "src\tools\Session-ID-Isolator.ps1" -Operation isolate -IsolationLevel HIGH
    Write-Host "`nSession ID isolation completed!" -ForegroundColor Green
    Pause-AndReturn
}

function Invoke-CrossAccountDelink {
    Write-Host "`nExecuting cross-account delinking..." -ForegroundColor Green
    & "src\tools\Cross-Account-Delinker.ps1" -Operation delink -DelinkLevel AGGRESSIVE
    Write-Host "`nCross-account delinking completed!" -ForegroundColor Green
    Pause-AndReturn
}

function Invoke-AnalyzeRisks {
    Write-Host "`nAnalyzing detection risks..." -ForegroundColor Magenta
    & "src\tools\Advanced-Anti-Detection.ps1" -Operation analyze -VerboseOutput
    Pause-AndReturn
}

function Show-Help {
    Clear-Host
    Show-Banner
    Write-Host ""
    Write-Host "【Usage Instructions】" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Quick Commands:" -ForegroundColor Cyan
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"Launch-Tools.ps1`" -Action quick     # Complete fix" -ForegroundColor White
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"Launch-Tools.ps1`" -Action trial     # Trial reset" -ForegroundColor White
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"Launch-Tools.ps1`" -Action device    # Device reset" -ForegroundColor White
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"Launch-Tools.ps1`" -Action session   # Session clean" -ForegroundColor White
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"Launch-Tools.ps1`" -Action analyze   # Risk analysis" -ForegroundColor White
    Write-Host ""
    Write-Host "Recommended Workflow:" -ForegroundColor Cyan
    Write-Host "  1. First use: Select `"Complete Fix`"" -ForegroundColor White
    Write-Host "  2. Trial expired: Select `"Reset Trial Account`"" -ForegroundColor White
    Write-Host "  3. Detection issues: Select `"Smart Anti-Detection`"" -ForegroundColor White
    Write-Host "  4. Regular maintenance: Select `"Analyze Detection Risks`"" -ForegroundColor White
    Write-Host ""
    Write-Host "Important Reminders:" -ForegroundColor Cyan
    Write-Host "  - Close all VS Code/Cursor instances before operations" -ForegroundColor White
    Write-Host "  - Restart applications after operations to apply changes" -ForegroundColor White
    Write-Host "  - Recommend using preview mode first to check operations" -ForegroundColor White
    Write-Host "  - Some operations may require administrator privileges" -ForegroundColor White
    Write-Host ""
    Pause-AndReturn
}

function Pause-AndReturn {
    Write-Host "`nPress any key to return to main menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Show-Menu
}

# Main program entry
switch ($Action) {
    "menu" { Show-Menu }
    "quick" {
        Write-Host "Executing complete fix..." -ForegroundColor Green
        & "src\tools\Complete-Augment-Fix.ps1"
        Write-Host "Complete fix finished!" -ForegroundColor Green
    }
    "trial" {
        Write-Host "Resetting trial account..." -ForegroundColor Green
        & "src\tools\Reset-TrialAccount.ps1"
        Write-Host "Trial reset finished!" -ForegroundColor Green
    }
    "device" {
        Write-Host "Resetting device fingerprint..." -ForegroundColor Green
        & "src\tools\Reset-DeviceFingerprint.ps1"
        Write-Host "Device reset finished!" -ForegroundColor Green
    }
    "session" {
        Write-Host "Cleaning session data..." -ForegroundColor Green
        & "src\tools\Clean-SessionData.ps1"
        Write-Host "Session cleaning finished!" -ForegroundColor Green
    }
    "analyze" {
        Write-Host "Analyzing detection risks..." -ForegroundColor Magenta
        & "src\tools\Advanced-Anti-Detection.ps1" -Operation analyze -VerboseOutput
        Write-Host "Risk analysis finished!" -ForegroundColor Magenta
    }
    "help" {
        Write-Host "Opening usage guide..." -ForegroundColor Cyan
        if (Test-Path "Anti-Detection-Tools-Guide.md") {
            Start-Process "Anti-Detection-Tools-Guide.md"
        } else {
            Write-Host "Usage guide not found!" -ForegroundColor Red
        }
    }
    default { Show-Menu }
}
