# quick-start.ps1
# Augment VIP - One-Click Quick Start
# Ultra-simple entry point for immediate use
# Version: 3.0.0

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Skip all confirmations")]
    [switch]$Auto = $false,
    
    [Parameter(HelpMessage = "Show what would be done without executing")]
    [switch]$Preview = $false
)

# Simple logging for quick start
function Write-QuickLog {
    param([string]$Message, [string]$Type = "INFO")
    
    $color = switch ($Type) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

# Welcome message
function Show-QuickWelcome {
    Clear-Host
    Write-Host ""
    Write-Host "🚀 " -NoNewline -ForegroundColor Blue
    Write-Host "Augment VIP - Quick Start" -ForegroundColor Cyan
    Write-Host "   One-click VS Code trial account reset" -ForegroundColor Gray
    Write-Host ""
}

# Main quick start function
function Start-QuickReset {
    Show-QuickWelcome
    
    if (-not $Auto -and -not $Preview) {
        Write-Host "This will reset your VS Code trial account data safely." -ForegroundColor Yellow
        Write-Host "Your VS Code settings and extensions will NOT be affected." -ForegroundColor Green
        Write-Host ""
        
        $choice = Read-Host "Continue? (Y/n)"
        if ($choice -eq 'n' -or $choice -eq 'N') {
            Write-QuickLog "Operation cancelled by user" "WARNING"
            return
        }
    }
    
    Write-QuickLog "Starting quick reset operation..."
    
    # Check if main script exists
    $mainScript = Join-Path $PSScriptRoot "Start-AugmentVIP.ps1"
    if (-not (Test-Path $mainScript)) {
        Write-QuickLog "Main script not found: $mainScript" "ERROR"
        Write-QuickLog "Please ensure you're running from the correct directory" "ERROR"
        return
    }
    
    # Prepare parameters
    $params = @("quick")
    if ($Preview) { $params += "-Preview" }
    if ($Auto) { $params += "-Force" }
    
    try {
        # Execute main script
        Write-QuickLog "Executing Augment VIP reset..."
        & $mainScript @params
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "✅ " -NoNewline -ForegroundColor Green
            Write-Host "Quick reset completed successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "🔄 Please restart VS Code to apply changes." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "💡 Tip: If you still see trial limitations, try:" -ForegroundColor Cyan
            Write-Host "   1. Completely close VS Code" -ForegroundColor Gray
            Write-Host "   2. Wait 10 seconds" -ForegroundColor Gray
            Write-Host "   3. Restart VS Code" -ForegroundColor Gray
        } else {
            Write-QuickLog "Reset operation completed with errors" "ERROR"
            Write-QuickLog "Check the detailed logs for more information" "WARNING"
        }
    } catch {
        Write-QuickLog "Failed to execute reset: $($_.Exception.Message)" "ERROR"
    }
}

# Execute quick start
Start-QuickReset
