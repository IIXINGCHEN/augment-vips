# vscode-cleanup-master.ps1
#
# Description: Master VS Code cleanup script with comprehensive functionality
# Integrates database cleaning, telemetry modification, and backup management
#
# Based on: https://github.com/azrilaiman2003/augment-vip
# Enhanced for Windows systems with enterprise-grade features
# Author: Augment VIP Project (Windows Enhancement)
# Version: 1.0.0
#
# Usage: .\vscode-cleanup-master.ps1 [options]
#   Options:
#     -Clean              Clean Augment-related database entries
#     -ModifyTelemetry    Modify VS Code telemetry IDs
#     -All                Perform all operations
#     -Preview            Show preview without making changes
#     -Backup             Create backups (default: true)
#     -NoBackup           Skip backup creation
#     -IncludePortable    Include portable VS Code installations
#     -LogFile            Path to log file
#     -Verbose            Enable verbose logging
#     -WhatIf             Show what would be done without executing
#     -Help               Show help information

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Clean,
    [switch]$ModifyTelemetry,
    [switch]$All,
    [switch]$Preview,
    [switch]$NoBackup,
    [switch]$IncludePortable = $true,
    [string]$LogFile,
    [switch]$Help
)

# Set error handling
$ErrorActionPreference = "Stop"

# Get script directory and module path
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesDir = Join-Path $ScriptDir "modules"
$ProjectRoot = Split-Path -Parent $ScriptDir

# Import all required modules
$requiredModules = @(
    "Logger.psm1",
    "SystemDetection.psm1",
    "VSCodeDiscovery.psm1",
    "BackupManager.psm1",
    "DatabaseCleaner.psm1",
    "TelemetryModifier.psm1"
)

foreach ($module in $requiredModules) {
    $modulePath = Join-Path $ModulesDir $module
    if (-not (Test-Path $modulePath)) {
        Write-Host "Module not found: $modulePath" -ForegroundColor Red
        exit 1
    }

    try {
        Import-Module $modulePath -Force -ErrorAction Stop -Global
        Write-Host "Successfully imported: $module" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to import module $module`: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Global variables
$script:BackupDirectory = Join-Path $ProjectRoot "data\backups"
$script:LogDirectory = Join-Path $ProjectRoot "logs"

# Fallback functions in case module import fails
if (-not (Get-Command Write-LogInfo -ErrorAction SilentlyContinue)) {
    function Write-LogInfo { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
    function Write-LogSuccess { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
    function Write-LogWarning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    function Write-LogError { param([string]$Message, [System.Exception]$Exception)
        Write-Host "[ERROR] $Message" -ForegroundColor Red
        if ($Exception) { Write-Host "Exception: $($Exception.Message)" -ForegroundColor Red }
    }
    function Write-LogCritical { param([string]$Message, [System.Exception]$Exception)
        Write-Host "[CRITICAL] $Message" -ForegroundColor Red
        if ($Exception) { Write-Host "Exception: $($Exception.Message)" -ForegroundColor Red }
    }
    function Write-LogDebug { param([string]$Message) Write-Host "[DEBUG] $Message" -ForegroundColor Cyan }
    function Initialize-Logger { param($LogFilePath, $EnableConsole, $EnableFile) Write-Host "[INFO] Logger initialized (fallback mode)" -ForegroundColor Blue }
    function Initialize-BackupManager { param($BackupDirectory, $MaxAge, $MaxCount) Write-Host "[INFO] Backup manager initialized (fallback mode)" -ForegroundColor Blue }
    function Test-SystemCompatibility { Write-Host "[INFO] System compatibility check (fallback mode)" -ForegroundColor Blue; return $true }
    function Test-VSCodeOperationRequirements { Write-Host "[INFO] VS Code requirements check (fallback mode)" -ForegroundColor Blue; return $true }
    function Find-VSCodeInstallations { param($IncludePortable) Write-Host "[WARNING] No VS Code installations found (fallback mode)" -ForegroundColor Yellow; return @() }
    function Show-CleaningPreview { param($DatabasePaths) Write-Host "[INFO] Database cleaning preview (fallback mode)" -ForegroundColor Blue }
    function Show-TelemetryModificationPreview { param($StorageJsonPaths) Write-Host "[INFO] Telemetry modification preview (fallback mode)" -ForegroundColor Blue }
    function Show-BackupStatistics { Write-Host "[INFO] Backup statistics (fallback mode)" -ForegroundColor Blue }
    function Show-SystemInformation { Write-Host "[INFO] System information (fallback mode)" -ForegroundColor Blue }
}

<#
.SYNOPSIS
    Shows help information
#>
function Show-Help {
    Write-Host @"
VS Code Cleanup Master Script
============================

Based on: https://github.com/azrilaiman2003/augment-vip
Enhanced for Windows systems with enterprise-grade features

Description:
  Comprehensive VS Code cleanup tool that removes Augment-related entries
  from databases and modifies telemetry identifiers with backup support.

Usage:
  .\vscode-cleanup-master.ps1 [options]

Options:
  -Clean              Clean Augment-related database entries
  -ModifyTelemetry    Modify VS Code telemetry IDs
  -All                Perform all operations (clean + modify telemetry)
  -Preview            Show preview without making changes
  -NoBackup           Skip backup creation (backups enabled by default)
  -IncludePortable    Include portable VS Code installations (default: true)
  -LogFile <path>     Path to log file (optional)
  -Verbose            Enable verbose logging
  -WhatIf             Show what would be done without executing
  -Help               Show this help information

Examples:
  .\vscode-cleanup-master.ps1 -All
  .\vscode-cleanup-master.ps1 -Clean -Verbose
  .\vscode-cleanup-master.ps1 -ModifyTelemetry -NoBackup
  .\vscode-cleanup-master.ps1 -Preview -All

System Requirements:
  - Windows 10 or higher
  - PowerShell 5.1 or higher
  - SQLite3 (for database operations)
  - Administrator privileges (recommended)

"@ -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Initializes the script environment
#>
function Initialize-Environment {
    Write-LogInfo "Initializing VS Code Cleanup Master Script v1.0.0"
    
    # Create necessary directories
    $directories = @($script:BackupDirectory, $script:LogDirectory)
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-LogDebug "Created directory: $dir"
        }
    }
    
    # Initialize logger
    if ($LogFile) {
        Initialize-Logger -LogFilePath $LogFile -EnableConsole $true -EnableFile $true
    } else {
        $defaultLogFile = Join-Path $script:LogDirectory "vscode-cleanup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        Initialize-Logger -LogFilePath $defaultLogFile -EnableConsole $true -EnableFile $true
    }
    
    # Initialize backup manager
    Initialize-BackupManager -BackupDirectory $script:BackupDirectory -MaxAge 30 -MaxCount 10
    
    Write-LogSuccess "Environment initialized successfully"
}

<#
.SYNOPSIS
    Performs system compatibility check
#>
function Test-Prerequisites {
    Write-LogInfo "Checking system prerequisites..."
    
    # System compatibility check
    if (-not (Test-SystemCompatibility)) {
        Write-LogError "System compatibility check failed"
        return $false
    }
    
    # VS Code operation requirements
    if (-not (Test-VSCodeOperationRequirements)) {
        Write-LogError "VS Code operation requirements not met"
        return $false
    }
    
    Write-LogSuccess "All prerequisites met"
    return $true
}

<#
.SYNOPSIS
    Discovers VS Code installations and prepares data
#>
function Get-VSCodeData {
    Write-LogInfo "Discovering VS Code installations..."

    # Use production-verified method to get database paths
    $databasePathPatterns = Get-VSCodeDatabasePaths
    $allDatabasePaths = @()

    # Expand patterns to actual files
    foreach ($pattern in $databasePathPatterns) {
        $files = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $allDatabasePaths += $file.FullName
        }
    }

    # Use production-verified method to get storage.json path
    $storagePath = Get-VSCodeStoragePath
    $allStorageJsonPaths = @()
    if ($storagePath) {
        $allStorageJsonPaths += $storagePath
    }

    # Also try to find installations using the original method for compatibility
    $installations = Find-VSCodeInstallations -IncludePortable:$IncludePortable

    if ($installations.Count -eq 0 -and $allDatabasePaths.Count -eq 0) {
        Write-LogWarning "No VS Code installations found"
        return @{
            Installations = @()
            DatabasePaths = @()
            StorageJsonPaths = @()
        }
    }

    # Report findings
    foreach ($installation in $installations) {
        Write-LogInfo "Found: $($installation.Name) at $($installation.Path)"
    }

    Write-LogInfo "Total database files found: $($allDatabasePaths.Count)"
    Write-LogInfo "Total storage.json files found: $($allStorageJsonPaths.Count)"

    return @{
        Installations = $installations
        DatabasePaths = $allDatabasePaths
        StorageJsonPaths = $allStorageJsonPaths
    }
}

<#
.SYNOPSIS
    Performs database cleaning operation
#>
function Invoke-DatabaseCleaning {
    param(
        [string[]]$DatabasePaths,
        [bool]$CreateBackup = $true,
        [bool]$WhatIf = $false,
        [bool]$Preview = $false
    )

    if ($DatabasePaths.Count -eq 0) {
        Write-LogWarning "No database files to clean"
        return
    }

    Write-LogInfo "Starting database cleaning operation..."

    if ($Preview -or $WhatIf) {
        Show-CleaningPreview -DatabasePaths $DatabasePaths
        return
    }
    
    if ($PSCmdlet.ShouldProcess("$($DatabasePaths.Count) database files", "Clean Augment entries")) {
        # Use production-verified method for cleaning
        $successCount = 0
        $failCount = 0

        foreach ($dbPath in $DatabasePaths) {
            if (Clear-DatabaseProductionMethod -DatabasePath $dbPath -CreateBackup $CreateBackup) {
                $successCount++
            } else {
                $failCount++
            }
        }

        Write-LogSuccess "Database cleaning completed"
        Write-LogInfo "Successfully cleaned: $successCount/$($DatabasePaths.Count) databases"
        if ($failCount -gt 0) {
            Write-LogWarning "Failed to clean: $failCount databases"
        }
    }
}

<#
.SYNOPSIS
    Performs telemetry ID modification operation
#>
function Invoke-TelemetryModification {
    param(
        [string[]]$StorageJsonPaths,
        [bool]$CreateBackup = $true,
        [bool]$WhatIf = $false,
        [bool]$Preview = $false
    )

    if ($StorageJsonPaths.Count -eq 0) {
        Write-LogWarning "No storage.json files to modify"
        return
    }

    Write-LogInfo "Starting telemetry ID modification operation..."

    if ($Preview -or $WhatIf) {
        Show-TelemetryModificationPreview -StorageJsonPaths $StorageJsonPaths
        return
    }
    
    if ($PSCmdlet.ShouldProcess("$($StorageJsonPaths.Count) storage.json files", "Modify telemetry IDs")) {
        # Use production-verified method for telemetry modification
        $successCount = 0
        $failCount = 0

        foreach ($storagePath in $StorageJsonPaths) {
            if (Set-TelemetryIdsProductionMethod -StoragePath $storagePath -CreateBackup $CreateBackup) {
                $successCount++
            } else {
                $failCount++
            }
        }

        Write-LogSuccess "Telemetry ID modification completed"
        Write-LogInfo "Successfully modified: $successCount/$($StorageJsonPaths.Count) files"
        if ($failCount -gt 0) {
            Write-LogWarning "Failed to modify: $failCount files"
        }
    }
}

<#
.SYNOPSIS
    Main execution function
#>
function Invoke-Main {
    try {
        # Show help if requested
        if ($Help) {
            Show-Help
            return
        }
        
        # Validate parameters
        if (-not ($Clean -or $ModifyTelemetry -or $All -or $Preview)) {
            Write-LogError "No operation specified. Use -Clean, -ModifyTelemetry, -All, or -Preview"
            Write-LogInfo "Use -Help for usage information"
            return
        }
        
        # Set backup preference (default is true unless NoBackup is specified)
        $CreateBackup = -not $NoBackup
        
        # Initialize environment
        Initialize-Environment
        
        # Show system information if verbose
        if ($VerbosePreference -eq 'Continue') {
            Show-SystemInformation
        }
        
        # Check prerequisites
        if (-not (Test-Prerequisites)) {
            Write-LogError "Prerequisites not met. Aborting operation."
            return
        }
        
        # Get VS Code data
        $vscodeData = Get-VSCodeData

        if ($vscodeData.Installations.Count -eq 0 -and $vscodeData.DatabasePaths.Count -eq 0 -and $vscodeData.StorageJsonPaths.Count -eq 0) {
            Write-LogError "No VS Code installations or data found. Nothing to do."
            return
        }

        if ($vscodeData.DatabasePaths.Count -eq 0 -and $vscodeData.StorageJsonPaths.Count -eq 0) {
            Write-LogError "No VS Code database files or storage.json files found. Nothing to do."
            return
        }
        
        # Perform operations based on parameters
        if ($All -or $Clean) {
            Invoke-DatabaseCleaning -DatabasePaths $vscodeData.DatabasePaths -CreateBackup $CreateBackup -WhatIf:$WhatIfPreference -Preview:$Preview
        }

        if ($All -or $ModifyTelemetry) {
            Invoke-TelemetryModification -StorageJsonPaths $vscodeData.StorageJsonPaths -CreateBackup $CreateBackup -WhatIf:$WhatIfPreference -Preview:$Preview
        }

        # Show backup statistics
        if ($CreateBackup -and -not ($Preview -or $WhatIfPreference)) {
            Show-BackupStatistics
        }
        
        Write-LogSuccess "VS Code cleanup operation completed successfully"
        
    }
    catch {
        Write-LogCritical "Critical error during execution" -Exception $_.Exception
        throw
    }
}

# Execute main function
Invoke-Main
