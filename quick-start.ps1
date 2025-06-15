# quick-start.ps1
# Augment VIP - One-Click Quick Start
# Ultra-simple entry point for immediate use
# Version: 3.1.0 - 统一日志重构版本

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Skip all confirmations")]
    [switch]$Auto = $false,

    [Parameter(HelpMessage = "Show what would be done without executing")]
    [switch]$Preview = $false
)

# 导入统一核心模块
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreModulesPath = Join-Path $scriptPath "src\core"
$standardImportsPath = Join-Path $coreModulesPath "StandardImports.ps1"

if (Test-Path $standardImportsPath) {
    . $standardImportsPath
    Write-LogInfo "已加载统一核心模块"
} else {
    # 紧急回退日志（仅在StandardImports不可用时使用）
    function Write-LogInfo { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor White }
    function Write-LogSuccess { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
    function Write-LogWarning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    function Write-LogError { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
    function Write-LogDebug { param([string]$Message) Write-Host "[DEBUG] $Message" -ForegroundColor Gray }
    Write-LogWarning "StandardImports不可用，使用回退日志系统"
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
    $params = @()
    $params += "-Operation"
    $params += "all"
    if ($Preview) {
        $params += "-DryRun"
    }
    $params += "-VerboseOutput"
    if ($Auto) {
        $params += "-Interactive"
        $params += $false
    }

    try {
        # Execute main script
        Write-LogInfo "Executing Augment VIP reset..."
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
            Write-LogError "Reset operation completed with errors"
            Write-LogWarning "Check the detailed logs for more information"
        }
    } catch {
        Write-LogError "Failed to execute reset: $($_.Exception.Message)"
    }
}

# Execute quick start
Start-QuickReset
