# quick-start.ps1
# Augment VIP - One-Click Quick Start
# Ultra-simple entry point for immediate use
# Version: 3.1.0 - Unified logging refactored version

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Skip all confirmations")]
    [switch]$Auto = $false,

    [Parameter(HelpMessage = "Show what would be done without executing")]
    [switch]$Preview = $false
)

# Import unified core modules
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreModulesPath = Join-Path (Join-Path $scriptPath "src") "core"
$standardImportsPath = Join-Path $coreModulesPath "StandardImports.ps1"

if (Test-Path $standardImportsPath) {
    . $standardImportsPath
    Write-LogInfo "Unified core modules loaded successfully"
} else {
    # Emergency fallback logging (only used when StandardImports is unavailable)
    function Write-LogInfo { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor White }
    function Write-LogSuccess { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
    function Write-LogWarning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    function Write-LogError { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
    function Write-LogDebug { param([string]$Message) Write-Host "[DEBUG] $Message" -ForegroundColor Gray }
    Write-LogWarning "StandardImports unavailable, using fallback logging system"
}

# Welcome message
function Show-QuickWelcome {
    Clear-Host
    Write-Host ""
    Write-Host ">> " -NoNewline -ForegroundColor Blue
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
            Write-LogWarning "Operation cancelled by user"
            return
        }
    }

    Write-LogInfo "Starting quick reset operation..."

    # Check if main script exists
    $mainScript = Join-Path $PSScriptRoot "install.ps1"
    if (-not (Test-Path $mainScript)) {
        Write-LogError "Main script not found: $mainScript"
        Write-LogError "Please ensure you're running from the correct directory"
        return
    }

    # Prepare parameters for install.ps1
    $params = @{
        Operation = "all"
        VerboseOutput = $true
    }
    if ($Preview) {
        $params.DryRun = $true
    }
    if ($Auto) {
        $params.Interactive = $false
    }

    try {
        # Execute main script
        Write-LogInfo "Executing Augment VIP reset..."
        & $mainScript @params

        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "[SUCCESS] " -NoNewline -ForegroundColor Green
            Write-Host "Quick reset completed successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "[INFO] Please restart VS Code to apply changes." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "[TIP] If you still see trial limitations, try:" -ForegroundColor Cyan
            Write-Host "   1. Completely close VS Code" -ForegroundColor Gray
            Write-Host "   2. Wait 10 seconds" -ForegroundColor Gray
            Write-Host "   3. Restart VS Code" -ForegroundColor Gray
        } else {
            Write-LogError "Reset operation completed with errors"
            Write-LogWarning "Check the detailed logs for more information"
        }
    } catch {
        Write-LogError "Failed to execute reset: $($_.Exception.Message)"
    }
}

# Execute quick start
Start-QuickReset
