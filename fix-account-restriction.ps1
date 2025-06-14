# fix-account-restriction.ps1
# Quick Fix for "Your account has been restricted. To continue, purchase a subscription." Error
# Version: 1.0.0 - Specialized tool for resolving Augment account restrictions
# Usage: .\fix-account-restriction.ps1 [-DryRun] [-Verbose]

param(
    [Parameter(HelpMessage = "Perform dry run without making actual changes")]
    [switch]$DryRun = $false,

    [Parameter(HelpMessage = "Enable verbose logging output")]
    [switch]$VerboseOutput = $false,

    [Parameter(HelpMessage = "Force operation without user confirmation")]
    [switch]$Force = $false
)

# Set error handling
$ErrorActionPreference = "Stop"
$VerbosePreference = if ($VerboseOutput) { "Continue" } else { "SilentlyContinue" }

# Script metadata
$SCRIPT_VERSION = "1.0.0"
$SCRIPT_NAME = "Augment Account Restriction Fix"

# Logging functions
function Write-LogInfo { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor White }
function Write-LogSuccess { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-LogWarning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-LogError { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-LogDebug { param([string]$Message) if ($VerboseOutput) { Write-Host "[DEBUG] $Message" -ForegroundColor Gray } }

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Checks if SQLite3 is available for database operations
    #>
    Write-LogInfo "Checking prerequisites..."
    
    try {
        $null = & sqlite3 -version 2>$null
        Write-LogSuccess "SQLite3 is available"
        return $true
    } catch {
        Write-LogError "SQLite3 is required but not found in PATH"
        Write-LogError "Please install SQLite3 or ensure it's in your PATH"
        return $false
    }
}

function Find-AugmentRestrictionData {
    <#
    .SYNOPSIS
        Scans for Augment data that may cause account restrictions
    #>
    Write-LogInfo "Scanning for Augment restriction data..."
    
    $foundData = @{
        VSCodeDatabases = @()
        VSCodeDirectories = @()
        CursorDatabases = @()
        CursorDirectories = @()
        TotalIssues = 0
    }
    
    # Check VS Code installations
    $vsCodePaths = @(
        "$env:APPDATA\Code\User\globalStorage",
        "$env:LOCALAPPDATA\Code\User\globalStorage"
    )
    
    foreach ($basePath in $vsCodePaths) {
        if (Test-Path $basePath) {
            Write-LogDebug "Checking VS Code path: $basePath"
            
            # Check database for Augment data
            $dbPath = Join-Path $basePath "state.vscdb"
            if (Test-Path $dbPath) {
                try {
                    $augmentKeys = & sqlite3 $dbPath "SELECT key FROM ItemTable WHERE key = 'Augment.vscode-augment' OR key LIKE 'secret://%augment%' OR key LIKE 'workbench.view.extension.augment%';" 2>$null
                    if ($augmentKeys) {
                        $foundData.VSCodeDatabases += @{
                            Path = $dbPath
                            Keys = $augmentKeys -split "`n" | Where-Object { $_ }
                        }
                        $foundData.TotalIssues++
                        Write-LogWarning "Found Augment data in VS Code database: $dbPath"
                    }
                } catch {
                    Write-LogDebug "Could not check database: $dbPath"
                }
            }
            
            # Check for Augment globalStorage directory
            $augmentDir = Join-Path $basePath "augment.vscode-augment"
            if (Test-Path $augmentDir) {
                $foundData.VSCodeDirectories += $augmentDir
                $foundData.TotalIssues++
                Write-LogWarning "Found Augment directory: $augmentDir"
            }
        }
    }
    
    # Check Cursor installations
    $cursorPaths = @(
        "$env:APPDATA\Cursor\User\globalStorage",
        "$env:LOCALAPPDATA\Cursor\User\globalStorage"
    )
    
    foreach ($basePath in $cursorPaths) {
        if (Test-Path $basePath) {
            Write-LogDebug "Checking Cursor path: $basePath"
            
            $dbPath = Join-Path $basePath "state.vscdb"
            if (Test-Path $dbPath) {
                try {
                    $augmentKeys = & sqlite3 $dbPath "SELECT key FROM ItemTable WHERE key LIKE '%augment%' OR key LIKE '%Augment%';" 2>$null
                    if ($augmentKeys) {
                        $foundData.CursorDatabases += @{
                            Path = $dbPath
                            Keys = $augmentKeys -split "`n" | Where-Object { $_ }
                        }
                        $foundData.TotalIssues++
                        Write-LogWarning "Found Augment data in Cursor database: $dbPath"
                    }
                } catch {
                    Write-LogDebug "Could not check Cursor database: $dbPath"
                }
            }
        }
    }
    
    return $foundData
}

function Remove-AugmentRestrictionData {
    <#
    .SYNOPSIS
        Removes Augment data that causes account restrictions
    #>
    param([hashtable]$FoundData)
    
    Write-LogInfo "Removing Augment restriction data..."
    
    $removalResult = @{
        Success = $true
        ItemsRemoved = 0
        ErrorsEncountered = 0
        Details = @()
    }
    
    try {
        # Process VS Code databases
        foreach ($dbInfo in $FoundData.VSCodeDatabases) {
            $dbPath = $dbInfo.Path
            Write-LogInfo "Processing VS Code database: $dbPath"
            
            if (-not $DryRun) {
                # Create backup
                $backupPath = "$dbPath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Copy-Item $dbPath $backupPath
                Write-LogInfo "Backup created: $backupPath"
            }
            
            $cleanupQueries = @(
                "DELETE FROM ItemTable WHERE key = 'Augment.vscode-augment';",
                "DELETE FROM ItemTable WHERE key LIKE 'secret://%augment%';",
                "DELETE FROM ItemTable WHERE key LIKE 'workbench.view.extension.augment%';"
            )
            
            foreach ($query in $cleanupQueries) {
                if ($DryRun) {
                    Write-LogInfo "[DRY RUN] Would execute: $query"
                } else {
                    try {
                        & sqlite3 $dbPath $query 2>$null
                        $removalResult.ItemsRemoved++
                        Write-LogDebug "Executed: $query"
                    } catch {
                        $removalResult.ErrorsEncountered++
                        Write-LogWarning "Failed to execute: $query - $($_.Exception.Message)"
                    }
                }
            }
        }
        
        # Process VS Code directories
        foreach ($dirPath in $FoundData.VSCodeDirectories) {
            Write-LogInfo "Processing VS Code directory: $dirPath"
            
            if ($DryRun) {
                Write-LogInfo "[DRY RUN] Would remove directory: $dirPath"
            } else {
                try {
                    Remove-Item $dirPath -Recurse -Force
                    $removalResult.ItemsRemoved++
                    $removalResult.Details += "Removed directory: $dirPath"
                    Write-LogSuccess "Removed: $dirPath"
                } catch {
                    $removalResult.ErrorsEncountered++
                    Write-LogError "Failed to remove: $dirPath - $($_.Exception.Message)"
                }
            }
        }
        
        # Process Cursor databases
        foreach ($dbInfo in $FoundData.CursorDatabases) {
            $dbPath = $dbInfo.Path
            Write-LogInfo "Processing Cursor database: $dbPath"
            
            if (-not $DryRun) {
                $backupPath = "$dbPath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Copy-Item $dbPath $backupPath
                Write-LogInfo "Cursor backup created: $backupPath"
            }
            
            $cleanupQueries = @(
                "DELETE FROM ItemTable WHERE key LIKE '%augment%';",
                "DELETE FROM ItemTable WHERE key LIKE '%Augment%';"
            )
            
            foreach ($query in $cleanupQueries) {
                if ($DryRun) {
                    Write-LogInfo "[DRY RUN] Would execute: $query"
                } else {
                    try {
                        & sqlite3 $dbPath $query 2>$null
                        $removalResult.ItemsRemoved++
                        Write-LogDebug "Executed Cursor query: $query"
                    } catch {
                        $removalResult.ErrorsEncountered++
                        Write-LogWarning "Failed to execute Cursor query: $query - $($_.Exception.Message)"
                    }
                }
            }
        }
        
        if ($removalResult.ErrorsEncountered -gt 0) {
            $removalResult.Success = $false
        }
        
    } catch {
        $removalResult.Success = $false
        $removalResult.Details += "Critical error: $($_.Exception.Message)"
        Write-LogError "Critical error during removal: $($_.Exception.Message)"
    }
    
    return $removalResult
}

function Show-Summary {
    param([hashtable]$FoundData, [hashtable]$RemovalResult)
    
    Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
    Write-Host "$SCRIPT_NAME v$SCRIPT_VERSION - SUMMARY" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    Write-Host "`nSCAN RESULTS:" -ForegroundColor Yellow
    Write-Host "  VS Code databases with issues: $($FoundData.VSCodeDatabases.Count)" -ForegroundColor White
    Write-Host "  VS Code directories found: $($FoundData.VSCodeDirectories.Count)" -ForegroundColor White
    Write-Host "  Cursor databases with issues: $($FoundData.CursorDatabases.Count)" -ForegroundColor White
    Write-Host "  Total issues found: $($FoundData.TotalIssues)" -ForegroundColor White
    
    if ($FoundData.TotalIssues -gt 0) {
        Write-Host "`nREMOVAL RESULTS:" -ForegroundColor Yellow
        $statusColor = if ($RemovalResult.Success) { "Green" } else { "Red" }
        $statusText = if ($RemovalResult.Success) { "SUCCESS" } else { "PARTIAL SUCCESS" }
        Write-Host "  Status: $statusText" -ForegroundColor $statusColor
        Write-Host "  Items processed: $($RemovalResult.ItemsRemoved)" -ForegroundColor White
        Write-Host "  Errors encountered: $($RemovalResult.ErrorsEncountered)" -ForegroundColor White
        
        if ($RemovalResult.Details.Count -gt 0) {
            Write-Host "`nDETAILS:" -ForegroundColor Yellow
            foreach ($detail in $RemovalResult.Details) {
                Write-Host "  - $detail" -ForegroundColor White
            }
        }
        
        if ($RemovalResult.Success -and -not $DryRun) {
            Write-Host "`n[SUCCESS] Account restriction fix completed!" -ForegroundColor Green
            Write-Host "Please restart VS Code/Cursor to apply changes." -ForegroundColor Green
            Write-Host "The 'Your account has been restricted' error should now be resolved." -ForegroundColor Green
        } elseif ($DryRun) {
            Write-Host "`n[DRY RUN] No actual changes were made." -ForegroundColor Yellow
            Write-Host "Run without -DryRun to apply the fixes." -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n[INFO] No Augment restriction data found." -ForegroundColor Green
        Write-Host "Your system appears to be clean already." -ForegroundColor Green
    }
    
    Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
}

# Main execution
function Main {
    Write-LogInfo "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    Write-LogInfo "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE EXECUTION' })"
    Write-LogInfo "Verbose: $VerboseOutput"
    
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        return 1
    }
    
    # Show warning and get confirmation
    if (-not $Force -and -not $DryRun) {
        Write-Host "`n[WARNING] This tool will modify VS Code/Cursor databases and remove directories." -ForegroundColor Yellow
        Write-Host "Backups will be created automatically." -ForegroundColor Yellow
        $confirm = Read-Host "`nContinue? (y/N)"
        if ($confirm -ne 'y' -and $confirm -ne 'Y') {
            Write-LogInfo "Operation cancelled by user"
            return 0
        }
    }
    
    # Scan for restriction data
    $foundData = Find-AugmentRestrictionData
    
    # Remove restriction data if found
    $removalResult = @{ Success = $true; ItemsRemoved = 0; ErrorsEncountered = 0; Details = @() }
    if ($foundData.TotalIssues -gt 0) {
        $removalResult = Remove-AugmentRestrictionData -FoundData $foundData
    }
    
    # Show summary
    Show-Summary -FoundData $foundData -RemovalResult $removalResult
    
    if ($removalResult.Success) {
        return 0
    } else {
        return 1
    }
}

# Execute main function
try {
    $exitCode = Main
    exit $exitCode
} catch {
    Write-LogError "Unhandled exception: $($_.Exception.Message)"
    Write-LogError "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
