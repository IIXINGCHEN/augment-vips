# Start-MasterCleanup.ps1
# Master Cleanup Script - Complete Trial Account Bypass
# Orchestrates all cleanup modules to completely reset Augment trial tracking
# Version: 3.0.0 - Standardized and optimized

[CmdletBinding()]
param(
    [switch]$DryRun = $false,
    [switch]$Verbose = $false,
    [switch]$SkipBackup = $false,
    [ValidateSet("complete", "conservative", "aggressive", "strict", "plugin-safe")]
    [string]$Mode = "complete",
    [switch]$Force = $false,
    [switch]$PreservePlugin = $false
)

# Import dependencies
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreModulesPath = Split-Path $scriptPath -Parent | Join-Path -ChildPath "core"
$loggerPath = Join-Path $coreModulesPath "AugmentLogger.ps1"

if (Test-Path $loggerPath) {
    . $loggerPath
    Initialize-AugmentLogger -LogDirectory "logs" -LogFileName "master_cleanup.log" -LogLevel "INFO"
} else {
    # Fallback logging if main logger not available
    function Write-LogInfo { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor White }
    function Write-LogSuccess { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
    function Write-LogWarning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    function Write-LogError { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
    function Write-LogDebug { param([string]$Message) if ($Verbose) { Write-Host "[DEBUG] $Message" -ForegroundColor Gray } }
    function Write-LogCritical { param([string]$Message) Write-Host "[CRITICAL] $Message" -ForegroundColor Magenta }
}

# Set error handling
$ErrorActionPreference = "Stop"

#region Display Functions

function Show-Banner {
    <#
    .SYNOPSIS
        Displays the application banner
    .DESCRIPTION
        Shows a formatted banner with application information
    #>
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    AUGMENT VIP MASTER CLEANUP                ║" -ForegroundColor Cyan
    Write-Host "║                Complete Trial Account Bypass                 ║" -ForegroundColor Cyan
    Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║  This script will completely reset all Augment trial data   ║" -ForegroundColor White
    Write-Host "║  and create a fresh device identity to bypass restrictions  ║" -ForegroundColor White
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Summary {
    <#
    .SYNOPSIS
        Displays cleanup operation summary
    .DESCRIPTION
        Shows results of all cleanup modules and overall status
    .PARAMETER Results
        Array of module execution results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results
    )
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                      CLEANUP SUMMARY                        ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    $successCount = ($Results | Where-Object { $_.Success }).Count
    $totalCount = $Results.Count
    
    Write-LogInfo "Modules executed: $totalCount"
    Write-LogInfo "Successful: $successCount"
    Write-LogInfo "Failed: $($totalCount - $successCount)"
    
    foreach ($result in $Results) {
        $status = if ($result.Success) { "SUCCESS" } else { "FAILED" }
        $color = if ($result.Success) { "Green" } else { "Red" }
        Write-Host "  [$status] $($result.ModuleName)" -ForegroundColor $color
    }
    
    if ($successCount -eq $totalCount) {
        Write-Host ""
        Write-LogSuccess "🎉 ALL MODULES COMPLETED SUCCESSFULLY!"
        Write-LogSuccess "🔓 Trial account restrictions should now be bypassed"
        Write-LogInfo "💡 Restart VS Code/Cursor to see the effect"
        
        if (-not $DryRun) {
            Write-Host ""
            Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
            Write-Host "║                    BYPASS SUCCESSFUL!                       ║" -ForegroundColor Green
            Write-Host "║                                                              ║" -ForegroundColor Green
            Write-Host "║  Your device now has a completely new identity:             ║" -ForegroundColor White
            Write-Host "║  ✓ New device fingerprint generated                         ║" -ForegroundColor White
            Write-Host "║  ✓ All encrypted session data removed                       ║" -ForegroundColor White
            Write-Host "║  ✓ Authentication states reset                              ║" -ForegroundColor White
            Write-Host "║  ✓ Workspace tracking data cleared                          ║" -ForegroundColor White
            Write-Host "║                                                              ║" -ForegroundColor White
            Write-Host "║  Augment should now see this as a fresh installation!       ║" -ForegroundColor Green
            Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
        }
    } else {
        Write-Host ""
        Write-LogError " SOME MODULES FAILED!"
        Write-LogWarning "Trial bypass may be incomplete"
        Write-LogInfo "Check the logs above for details"
    }
}

#endregion

#region Prerequisites and Validation

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Checks system prerequisites for cleanup operation
    .DESCRIPTION
        Validates that required tools and scripts are available
    .EXAMPLE
        Test-Prerequisites
    #>
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Checking prerequisites..."
    
    $issues = @()
    
    # Check for SQLite3
    try {
        $null = & sqlite3 -version
        Write-LogSuccess "SQLite3 is available"
    } catch {
        $issues += "SQLite3 not found in PATH"
    }
    
    # Check for required scripts (updated names)
    $requiredScripts = @(
        "Reset-DeviceFingerprint.ps1",
        "Clean-SessionData.ps1", 
        "Reset-AuthState.ps1",
        "Clean-WorkspaceBinding.ps1"
    )
    
    foreach ($script in $requiredScripts) {
        $scriptPath = Join-Path $scriptPath $script
        if (-not (Test-Path $scriptPath)) {
            $issues += "Required script not found: $scriptPath"
        } else {
            Write-LogSuccess "Found script: $script"
        }
    }
    
    if ($issues.Count -gt 0) {
        Write-LogError "Prerequisites check failed:"
        foreach ($issue in $issues) {
            Write-LogError "  - $issue"
        }
        return $false
    }
    
    Write-LogSuccess "All prerequisites satisfied"
    return $true
}

#endregion

#region Module Management

function Get-CleanupModules {
    <#
    .SYNOPSIS
        Gets the list of cleanup modules to execute
    .DESCRIPTION
        Returns array of cleanup modules with their configuration
    .PARAMETER Mode
        Cleanup mode to determine which modules to include
    .EXAMPLE
        Get-CleanupModules -Mode "plugin-safe"
    #>
    [CmdletBinding()]
    param(
        [string]$CleanupMode = "complete"
    )

    $allModules = @(
        @{
            Name = "Device Fingerprint Reset"
            Script = "Reset-DeviceFingerprint.ps1"
            Description = "Resets all device telemetry IDs and session timestamps"
            Critical = $true
            PluginSafe = $true
        },
        @{
            Name = "Encrypted Session Cleaner"
            Script = "Clean-SessionData.ps1"
            Description = "Removes all encrypted session data and authentication tokens"
            Critical = $true
            PluginSafe = $false
        },
        @{
            Name = "Authentication State Reset"
            Script = "Reset-AuthState.ps1"
            Description = "Clears all Augment authentication states and user session data"
            Critical = $true
            PluginSafe = $false
        },
        @{
            Name = "Workspace Binding Cleaner"
            Script = "Clean-WorkspaceBinding.ps1"
            Description = "Removes project-specific tracking and workspace associations"
            Critical = $false
            PluginSafe = $true
        }
    )

    # Filter modules based on mode
    if ($CleanupMode -eq "plugin-safe" -or $PreservePlugin) {
        return $allModules | Where-Object { $_.PluginSafe -eq $true }
    } else {
        return $allModules
    }
}

function Invoke-CleanupModule {
    <#
    .SYNOPSIS
        Executes a cleanup module
    .DESCRIPTION
        Runs a specific cleanup script with appropriate parameters
    .PARAMETER ModuleName
        Name of the module for logging
    .PARAMETER ScriptPath
        Path to the script file
    .PARAMETER Description
        Description of what the module does
    .EXAMPLE
        Invoke-CleanupModule -ModuleName "Test Module" -ScriptPath "test.ps1" -Description "Test description"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )
    
    Write-LogInfo "Starting module: $ModuleName"
    Write-LogInfo "Description: $Description"
    
    try {
        $params = @()
        if ($DryRun) { $params += "-DryRun" }
        if ($Verbose) { $params += "-Verbose" }
        if ($Force) { $params += "-Force" }
        if ($PreservePlugin -or $Mode -eq "plugin-safe") { $params += "-PreservePlugin" }

        $startTime = Get-Date

        # Execute the module script
        $fullScriptPath = Join-Path $scriptPath $ScriptPath
        & powershell -ExecutionPolicy Bypass -File $fullScriptPath @params
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "Module '$ModuleName' completed successfully (${duration}s)"
            return $true
        } else {
            Write-LogError "Module '$ModuleName' failed with exit code: $LASTEXITCODE"
            return $false
        }
        
    } catch {
        Write-LogError "Exception in module '$ModuleName': $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Verification Functions

function Invoke-PreCleanupAnalysis {
    <#
    .SYNOPSIS
        Performs pre-cleanup analysis
    .DESCRIPTION
        Runs verification script to analyze current state before cleanup
    #>
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Performing pre-cleanup analysis..."
    
    # Look for verification script in root directory
    $rootDir = Split-Path -Parent (Split-Path -Parent $scriptPath)
    $verifyScript = Join-Path $rootDir "verify_fix_en.ps1"
    
    if (Test-Path $verifyScript) {
        Write-LogInfo "Running pre-cleanup verification..."
        try {
            & powershell -ExecutionPolicy Bypass -File $verifyScript -DetailedReport
            Write-LogInfo "Pre-cleanup analysis completed"
        } catch {
            Write-LogWarning "Pre-cleanup analysis failed: $($_.Exception.Message)"
        }
    } else {
        Write-LogWarning "Verification script not found: $verifyScript"
    }
}

function Invoke-PostCleanupVerification {
    <#
    .SYNOPSIS
        Performs post-cleanup verification
    .DESCRIPTION
        Runs verification script to confirm cleanup was successful
    .EXAMPLE
        Invoke-PostCleanupVerification
    #>
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Performing post-cleanup verification..."
    
    # Look for verification script in root directory
    $rootDir = Split-Path -Parent (Split-Path -Parent $scriptPath)
    $verifyScript = Join-Path $rootDir "verify_fix_en.ps1"
    
    if (Test-Path $verifyScript) {
        Write-LogInfo "Running post-cleanup verification..."
        try {
            & powershell -ExecutionPolicy Bypass -File $verifyScript -DetailedReport
            
            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "Post-cleanup verification PASSED - No critical issues found!"
                return $true
            } elseif ($LASTEXITCODE -eq 2) {
                Write-LogWarning "Post-cleanup verification passed with warnings"
                return $true
            } else {
                Write-LogError "Post-cleanup verification FAILED - Critical issues remain!"
                return $false
            }
        } catch {
            Write-LogWarning "Post-cleanup verification failed: $($_.Exception.Message)"
            return $false
        }
    } else {
        Write-LogWarning "Verification script not found: $verifyScript"
        return $true
    }
}

#endregion

#region Main Function

function Start-MasterCleanupProcess {
    <#
    .SYNOPSIS
        Main function to orchestrate the cleanup process
    .DESCRIPTION
        Coordinates all cleanup modules and verification steps
    .EXAMPLE
        Start-MasterCleanupProcess
    #>
    [CmdletBinding()]
    param()
    
    Show-Banner
    
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        Write-LogCritical "Prerequisites check failed. Aborting."
        return $false
    }
    
    # Show mode information
    if ($DryRun) {
        Write-LogWarning "DRY RUN MODE - No actual changes will be made"
    } else {
        Write-LogInfo "LIVE MODE - Changes will be applied"
    }
    
    Write-LogInfo "Cleanup mode: $Mode"
    
    # Pre-cleanup analysis
    if (-not $DryRun) {
        Invoke-PreCleanupAnalysis
    }
    
    # Get cleanup modules based on mode
    $modules = Get-CleanupModules -CleanupMode $Mode
    $results = @()

    if ($PreservePlugin -or $Mode -eq "plugin-safe") {
        Write-LogInfo "PLUGIN-SAFE MODE: Only executing plugin-safe cleanup modules"
        Write-LogWarning "Some modules will be skipped to preserve Augment plugin functionality"
    }

    Write-LogInfo "Starting cleanup sequence with $($modules.Count) modules..."
    
    # Execute each module
    foreach ($module in $modules) {
        $success = Invoke-CleanupModule -ModuleName $module.Name -ScriptPath $module.Script -Description $module.Description
        
        $results += @{
            ModuleName = $module.Name
            Success = $success
            Critical = $module.Critical
        }
        
        # If a critical module fails, consider stopping
        if (-not $success -and $module.Critical -and $Mode -eq "strict") {
            Write-LogCritical "Critical module failed in strict mode. Aborting."
            break
        }
        
        # Small delay between modules
        Start-Sleep -Seconds 1
    }
    
    # Post-cleanup verification
    if (-not $DryRun) {
        $verificationPassed = Invoke-PostCleanupVerification
        if (-not $verificationPassed) {
            Write-LogWarning "Post-cleanup verification indicates issues may remain"
        }
    }
    
    # Show summary
    Show-Summary -Results $results
    
    # Return success status
    $criticalFailures = ($results | Where-Object { -not $_.Success -and $_.Critical }).Count
    return ($criticalFailures -eq 0)
}

#endregion

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    $success = Start-MasterCleanupProcess
    exit $(if ($success) { 0 } else { 1 })
}
