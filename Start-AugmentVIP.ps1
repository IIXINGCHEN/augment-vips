# Start-AugmentVIP.ps1
# Augment VIP - Main Entry Point
# Simple, user-friendly interface for Augment VIP operations
# Version: 3.0.0 - Simplified and optimized

[CmdletBinding()]
param(
    [Parameter(Position = 0, HelpMessage = "Operation to perform")]
    [ValidateSet("quick", "clean", "reset", "verify", "install", "help")]
    [string]$Operation = "help",
    
    [Parameter(HelpMessage = "Cleanup intensity level")]
    [ValidateSet("safe", "standard", "aggressive")]
    [string]$Level = "standard",
    
    [Parameter(HelpMessage = "Preview changes without executing")]
    [switch]$Preview = $false,
    
    [Parameter(HelpMessage = "Enable detailed output")]
    [switch]$VerboseOutput = $false,
    
    [Parameter(HelpMessage = "Skip confirmations (use with caution)")]
    [switch]$Force = $false,
    
    [Parameter(HelpMessage = "Show detailed help")]
    [switch]$Help = $false
)

# Script metadata
$script:Version = "3.0.0"
$script:Name = "Augment VIP"

# Initialize script environment
$script:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ProjectRoot = $script:ScriptRoot

# Import core modules
$coreModulesPath = Join-Path $script:ProjectRoot "src\core"
$loggerPath = Join-Path $coreModulesPath "AugmentLogger.ps1"
$configPath = Join-Path $coreModulesPath "ConfigurationManager.ps1"

# 导入统一核心模块
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
    function Write-LogDebug { param([string]$Message) if ($VerboseOutput) { Write-Host "[DEBUG] $Message" -ForegroundColor Gray } }
    Write-LogWarning "StandardImports不可用，使用回退日志系统"
}

# Initialize configuration
if (Test-Path $configPath) {
    . $configPath
    Initialize-Configuration -ProjectRoot $script:ProjectRoot
}

#region Helper Functions

function Show-Welcome {
    <#
    .SYNOPSIS
        Shows welcome message and basic information
    #>
    Write-Host ""
    Write-Host "🚀 " -NoNewline -ForegroundColor Blue
    Write-Host "$script:Name v$script:Version" -ForegroundColor Cyan
    Write-Host "   Advanced VS Code Trial Account Reset Tool" -ForegroundColor Gray
    Write-Host ""
}

function Show-Help {
    <#
    .SYNOPSIS
        Shows comprehensive help information
    #>
    Show-Welcome
    
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\Start-AugmentVIP.ps1 [operation] [options]" -ForegroundColor White
    Write-Host ""
    
    Write-Host "OPERATIONS:" -ForegroundColor Yellow
    Write-Host "  quick      🎯 Quick reset (recommended for most users)" -ForegroundColor Green
    Write-Host "  clean      🧹 Clean Augment data from VS Code" -ForegroundColor Cyan
    Write-Host "  reset      🔄 Reset device fingerprint and telemetry" -ForegroundColor Cyan
    Write-Host "  verify     ✅ Verify cleanup effectiveness" -ForegroundColor Cyan
    Write-Host "  install    📦 Install required dependencies" -ForegroundColor Cyan
    Write-Host "  help       ❓ Show this help message" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "  -Level <level>    Cleanup intensity: safe, standard, aggressive" -ForegroundColor White
    Write-Host "  -Preview          Preview changes without executing" -ForegroundColor White
    Write-Host "  -Verbose          Enable detailed output" -ForegroundColor White
    Write-Host "  -Force            Skip confirmations (use with caution)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  .\Start-AugmentVIP.ps1 quick" -ForegroundColor Green
    Write-Host "  .\Start-AugmentVIP.ps1 clean -Level safe -Preview" -ForegroundColor White
    Write-Host "  .\Start-AugmentVIP.ps1 reset -Level aggressive -Verbose" -ForegroundColor White
    Write-Host "  .\Start-AugmentVIP.ps1 verify" -ForegroundColor White
    Write-Host ""
    
    Write-Host "CLEANUP LEVELS:" -ForegroundColor Yellow
    Write-Host "  safe         🟢 Minimal risk, basic trial data cleanup" -ForegroundColor Green
    Write-Host "  standard     🟡 Balanced effectiveness and safety (default)" -ForegroundColor Yellow
    Write-Host "  aggressive   🔴 Maximum effectiveness, higher risk" -ForegroundColor Red
    Write-Host ""
    
    Write-Host "For more information, visit: https://github.com/IIXINGCHEN/augment-vips" -ForegroundColor Blue
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Checks if required tools and dependencies are available
    #>
    Write-LogInfo "Checking prerequisites..."
    
    $issues = @()
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $issues += "PowerShell 5.1 or higher required"
    }
    
    # Check for SQLite3
    try {
        $null = & sqlite3 -version 2>$null
        Write-LogDebug "SQLite3 is available"
    } catch {
        $issues += "SQLite3 not found in PATH"
    }
    
    # Check for required scripts
    $toolsPath = Join-Path $script:ProjectRoot "src\tools"
    $requiredTools = @(
        "Reset-DeviceFingerprint.ps1",
        "Clean-SessionData.ps1",
        "Reset-AuthState.ps1"
    )
    
    foreach ($tool in $requiredTools) {
        $toolPath = Join-Path $toolsPath $tool
        if (-not (Test-Path $toolPath)) {
            $issues += "Required tool not found: $tool"
        }
    }
    
    if ($issues.Count -gt 0) {
        Write-LogError "Prerequisites check failed:"
        foreach ($issue in $issues) {
            Write-LogError "  - $issue"
        }
        Write-LogInfo "Run: .\Start-AugmentVIP.ps1 install"
        return $false
    }
    
    Write-LogSuccess "Prerequisites check passed"
    return $true
}

function Invoke-QuickReset {
    <#
    .SYNOPSIS
        Performs quick reset operation (recommended for most users)
    #>
    Write-LogInfo "Starting quick reset operation..."
    
    if (-not $Force) {
        Write-Host ""
        Write-Host "🎯 " -NoNewline -ForegroundColor Blue
        Write-Host "Quick Reset Operation" -ForegroundColor Cyan
        Write-Host "This will reset your VS Code trial account data using safe methods." -ForegroundColor Gray
        Write-Host ""
        
        $confirm = Read-Host "Continue? (y/N)"
        if ($confirm -ne 'y' -and $confirm -ne 'Y') {
            Write-LogInfo "Operation cancelled by user"
            return $false
        }
    }
    
    # Execute quick reset sequence
    $operations = @(
        @{ Name = "Device Fingerprint Reset"; Script = "Reset-DeviceFingerprint.ps1" },
        @{ Name = "Session Data Cleanup"; Script = "Clean-SessionData.ps1" },
        @{ Name = "Auth State Reset"; Script = "Reset-AuthState.ps1" }
    )
    
    $success = $true
    foreach ($op in $operations) {
        Write-LogInfo "Executing: $($op.Name)"
        
        $toolPath = Join-Path $script:ProjectRoot "src\tools\$($op.Script)"
        if (Test-Path $toolPath) {
            try {
                $params = @{}
                if ($Preview) { $params.DryRun = $true }
                if ($VerboseOutput) { $params.Verbose = $true }
                
                & $toolPath @params
                if ($LASTEXITCODE -eq 0) {
                    Write-LogSuccess "$($op.Name) completed successfully"
                } else {
                    Write-LogError "$($op.Name) failed with exit code $LASTEXITCODE"
                    $success = $false
                }
            } catch {
                Write-LogError "$($op.Name) failed: $($_.Exception.Message)"
                $success = $false
            }
        } else {
            Write-LogError "Tool not found: $($op.Script)"
            $success = $false
        }
    }
    
    if ($success) {
        Write-Host ""
        Write-Host "✅ " -NoNewline -ForegroundColor Green
        Write-Host "Quick reset completed successfully!" -ForegroundColor Green
        Write-Host "Please restart VS Code to apply changes." -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "❌ " -NoNewline -ForegroundColor Red
        Write-Host "Quick reset completed with errors." -ForegroundColor Red
        Write-Host "Check the logs for details." -ForegroundColor Yellow
    }
    
    return $success
}

function Invoke-CleanOperation {
    <#
    .SYNOPSIS
        Performs clean operation
    #>
    Write-LogInfo "Starting clean operation with level: $Level"
    
    $toolPath = Join-Path $script:ProjectRoot "src\tools\Clean-SessionData.ps1"
    if (-not (Test-Path $toolPath)) {
        Write-LogError "Clean tool not found: $toolPath"
        return $false
    }
    
    try {
        $params = @{}
        if ($Preview) { $params.DryRun = $true }
        if ($Verbose) { $params.Verbose = $true }
        if ($Force) { $params.Force = $true }
        
        & $toolPath @params
        return $LASTEXITCODE -eq 0
    } catch {
        Write-LogError "Clean operation failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-ResetOperation {
    <#
    .SYNOPSIS
        Performs reset operation
    #>
    Write-LogInfo "Starting reset operation with level: $Level"
    
    $toolPath = Join-Path $script:ProjectRoot "src\tools\Reset-DeviceFingerprint.ps1"
    if (-not (Test-Path $toolPath)) {
        Write-LogError "Reset tool not found: $toolPath"
        return $false
    }
    
    try {
        $params = @{}
        if ($Preview) { $params.DryRun = $true }
        if ($Verbose) { $params.Verbose = $true }
        if ($Force) { $params.Force = $true }
        
        & $toolPath @params
        return $LASTEXITCODE -eq 0
    } catch {
        Write-LogError "Reset operation failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-VerifyOperation {
    <#
    .SYNOPSIS
        Performs verification operation
    #>
    Write-LogInfo "Starting verification operation..."
    
    $testPath = Join-Path $script:ProjectRoot "test\Test-AugmentCleanupVerification.ps1"
    if (-not (Test-Path $testPath)) {
        Write-LogError "Verification test not found: $testPath"
        return $false
    }
    
    try {
        $params = @{}
        if ($VerboseOutput) { $params.Verbose = $true }
        $params.DetailedReport = $true
        
        & $testPath @params
        return $LASTEXITCODE -eq 0
    } catch {
        Write-LogError "Verification failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-InstallOperation {
    <#
    .SYNOPSIS
        Performs installation of dependencies
    #>
    Write-LogInfo "Starting dependency installation..."
    
    $installPath = Join-Path $script:ProjectRoot "install.ps1"
    if (-not (Test-Path $installPath)) {
        Write-LogError "Install script not found: $installPath"
        return $false
    }
    
    try {
        & $installPath -AutoInstallDeps -VerboseOutput:$Verbose
        return $LASTEXITCODE -eq 0
    } catch {
        Write-LogError "Installation failed: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Main Execution

function Start-AugmentVIPMain {
    <#
    .SYNOPSIS
        Main execution function
    #>
    # Show help if requested
    if ($Help -or $Operation -eq "help") {
        Show-Help
        return 0
    }
    
    # Show welcome message
    if ($Operation -ne "help") {
        Show-Welcome
    }
    
    # Check prerequisites for operations that need them
    if ($Operation -in @("quick", "clean", "reset", "verify")) {
        if (-not (Test-Prerequisites)) {
            return 1
        }
    }
    
    # Execute requested operation
    $success = switch ($Operation) {
        "quick" { Invoke-QuickReset }
        "clean" { Invoke-CleanOperation }
        "reset" { Invoke-ResetOperation }
        "verify" { Invoke-VerifyOperation }
        "install" { Invoke-InstallOperation }
        default {
            Write-LogError "Unknown operation: $Operation"
            Show-Help
            $false
        }
    }
    
    return if ($success) { 0 } else { 1 }
}

#endregion

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = Start-AugmentVIPMain
    exit $exitCode
}
