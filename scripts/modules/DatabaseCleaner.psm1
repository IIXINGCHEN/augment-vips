# DatabaseCleaner.psm1
#
# Description: Enhanced database cleaning module for VS Code
# Removes Augment-related entries and Context7 framework data from SQLite databases
#
# Author: Augment VIP Project
# Version: 1.0.0

# Import required modules
Import-Module (Join-Path $PSScriptRoot "Logger.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "BackupManager.psm1") -Force

# Cleaning patterns for different data types
$script:AugmentPatterns = @(
    '%augment%',
    '%Augment%',
    '%AUGMENT%',
    '%augment-code%',
    '%augmentcode%',
    '%context7%',
    '%Context7%',
    '%CONTEXT7%'
)

<#
.SYNOPSIS
    Sanitizes SQL LIKE patterns to prevent injection attacks
.PARAMETER Pattern
    The pattern to sanitize
.OUTPUTS
    string - Sanitized pattern
#>
function Get-SafeSQLPattern {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    # Remove or escape dangerous characters
    $sanitized = $Pattern.Replace("'", "''")  # Escape single quotes
    $sanitized = $sanitized.Replace(";", "")   # Remove semicolons
    $sanitized = $sanitized.Replace("--", "")  # Remove SQL comments
    $sanitized = $sanitized.Replace("/*", "")  # Remove block comments
    $sanitized = $sanitized.Replace("*/", "")  # Remove block comments
    $sanitized = $sanitized.Replace("xp_", "")  # Remove extended procedures
    $sanitized = $sanitized.Replace("sp_", "")  # Remove stored procedures

    return $sanitized
}

$script:TelemetryPatterns = @(
    '%telemetry%',
    '%machineId%',
    '%deviceId%',
    '%sqmId%',
    '%uuid%',
    '%session%',
    '%lastSessionDate%',
    '%lastSyncDate%',
    '%lastSyncMachineId%',
    '%lastSyncDeviceId%',
    '%lastSyncSqmId%',
    '%lastSyncUuid%',
    '%lastSyncSession%',
    '%lastSyncLastSessionDate%',
    '%lastSyncLastSyncDate%'
)

$script:ExtensionPatterns = @(
    '%augment.%',
    '%context7.%',
    '%augment-vip%',
    '%augment_vip%'
)

# Database cleaning result class
class CleaningResult {
    [string]$DatabasePath
    [bool]$Success
    [int]$AugmentEntriesRemoved
    [int]$TelemetryEntriesRemoved
    [int]$ExtensionEntriesRemoved
    [int]$TotalEntriesRemoved
    [string]$ErrorMessage
    [string]$BackupPath
    
    CleaningResult([string]$databasePath) {
        $this.DatabasePath = $databasePath
        $this.Success = $false
        $this.AugmentEntriesRemoved = 0
        $this.TelemetryEntriesRemoved = 0
        $this.ExtensionEntriesRemoved = 0
        $this.TotalEntriesRemoved = 0
    }
}

<#
.SYNOPSIS
    Cleans a single SQLite database file
.PARAMETER DatabasePath
    Path to the SQLite database file
.PARAMETER CreateBackup
    Create backup before cleaning
.PARAMETER CleanAugment
    Remove Augment-related entries
.PARAMETER CleanTelemetry
    Remove telemetry entries
.PARAMETER CleanExtensions
    Remove extension-related entries
.OUTPUTS
    CleaningResult - Result of the cleaning operation
#>
function Clear-VSCodeDatabase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,
        [bool]$CreateBackup = $true,
        [bool]$CleanAugment = $true,
        [bool]$CleanTelemetry = $true,
        [bool]$CleanExtensions = $true
    )
    
    $result = [CleaningResult]::new($DatabasePath)
    
    try {
        # Check if database file exists
        if (-not (Test-Path $DatabasePath)) {
            $result.ErrorMessage = "Database file not found"
            Write-LogWarning "Database file not found: $DatabasePath"
            return $result
        }
        
        # Check if SQLite3 is available
        if (-not (Get-Command sqlite3 -ErrorAction SilentlyContinue)) {
            $result.ErrorMessage = "SQLite3 command not found"
            Write-LogError "SQLite3 command not found. Please install SQLite3."
            return $result
        }
        
        Write-LogInfo "Cleaning database: $DatabasePath"
        
        # Create backup if requested
        if ($CreateBackup) {
            $backupInfo = New-FileBackup -FilePath $DatabasePath -Description "Pre-cleaning backup"
            if ($backupInfo) {
                $result.BackupPath = $backupInfo.BackupPath
                Write-LogSuccess "Created backup: $($backupInfo.BackupPath)"
            } else {
                $result.ErrorMessage = "Failed to create backup"
                Write-LogError "Failed to create backup for: $DatabasePath"
                return $result
            }
        }
        
        # Test database connectivity
        if (-not (Test-DatabaseConnectivity -DatabasePath $DatabasePath)) {
            $result.ErrorMessage = "Cannot connect to database"
            return $result
        }
        
        # Clean different types of entries
        if ($CleanAugment) {
            $result.AugmentEntriesRemoved = Remove-DatabaseEntries -DatabasePath $DatabasePath -Patterns $script:AugmentPatterns -Category "Augment"
        }
        
        if ($CleanTelemetry) {
            $result.TelemetryEntriesRemoved = Remove-DatabaseEntries -DatabasePath $DatabasePath -Patterns $script:TelemetryPatterns -Category "Telemetry"
        }
        
        if ($CleanExtensions) {
            $result.ExtensionEntriesRemoved = Remove-DatabaseEntries -DatabasePath $DatabasePath -Patterns $script:ExtensionPatterns -Category "Extensions"
        }
        
        # Calculate total entries removed
        $result.TotalEntriesRemoved = $result.AugmentEntriesRemoved + $result.TelemetryEntriesRemoved + $result.ExtensionEntriesRemoved
        
        # Vacuum database to reclaim space
        if ($result.TotalEntriesRemoved -gt 0) {
            Optimize-Database -DatabasePath $DatabasePath
        }
        
        $result.Success = $true
        Write-LogSuccess "Database cleaning completed: $DatabasePath"
        Write-LogInfo "Total entries removed: $($result.TotalEntriesRemoved)"
        
    }
    catch {
        $result.ErrorMessage = $_.Exception.Message
        Write-LogError "Failed to clean database: $DatabasePath" -Exception $_.Exception
    }
    
    return $result
}

<#
.SYNOPSIS
    Removes database entries matching specified patterns
.PARAMETER DatabasePath
    Path to the SQLite database
.PARAMETER Patterns
    Array of LIKE patterns to match
.PARAMETER Category
    Category name for logging
.OUTPUTS
    int - Number of entries removed
#>
function Remove-DatabaseEntries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,
        [Parameter(Mandatory = $true)]
        [string[]]$Patterns,
        [Parameter(Mandatory = $true)]
        [string]$Category
    )
    
    $totalRemoved = 0
    
    try {
        foreach ($pattern in $Patterns) {
            # Sanitize pattern to prevent SQL injection
            $sanitizedPattern = Get-SafeSQLPattern -Pattern $pattern

            # Count entries before deletion
            $countQuery = "SELECT COUNT(*) FROM ItemTable WHERE key LIKE '$sanitizedPattern';"
            $countResult = & sqlite3 $DatabasePath $countQuery

            if ($countResult -and $countResult -gt 0) {
                # Delete entries
                $deleteQuery = "DELETE FROM ItemTable WHERE key LIKE '$sanitizedPattern';"
                & sqlite3 $DatabasePath $deleteQuery

                $totalRemoved += [int]$countResult
                Write-LogDebug "Removed $countResult $Category entries matching: $sanitizedPattern"
            }
        }
        
        if ($totalRemoved -gt 0) {
            Write-LogInfo "Removed $totalRemoved $Category entries"
        }
    }
    catch {
        Write-LogError "Failed to remove $Category entries" -Exception $_.Exception
    }
    
    return $totalRemoved
}

<#
.SYNOPSIS
    Tests database connectivity and structure
.PARAMETER DatabasePath
    Path to the SQLite database
.OUTPUTS
    bool - True if database is accessible
#>
function Test-DatabaseConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath
    )
    
    try {
        # Test basic connectivity
        $testQuery = "SELECT name FROM sqlite_master WHERE type='table';"
        $tables = & sqlite3 $DatabasePath $testQuery
        
        # Check if ItemTable exists (common VS Code database table)
        if ($tables -contains "ItemTable") {
            Write-LogDebug "Database connectivity test passed: $DatabasePath"
            return $true
        } else {
            Write-LogDebug "ItemTable not found in database: $DatabasePath"
            # Still return true as some databases might not have ItemTable
            return $true
        }
    }
    catch {
        Write-LogError "Database connectivity test failed: $DatabasePath" -Exception $_.Exception
        return $false
    }
}

<#
.SYNOPSIS
    Optimizes database by running VACUUM
.PARAMETER DatabasePath
    Path to the SQLite database
#>
function Optimize-Database {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath
    )
    
    try {
        Write-LogInfo "Optimizing database: $DatabasePath"
        
        # Get database size before optimization
        $sizeBefore = (Get-Item $DatabasePath).Length
        
        # Run VACUUM to reclaim space
        & sqlite3 $DatabasePath "VACUUM;"
        
        # Get database size after optimization
        $sizeAfter = (Get-Item $DatabasePath).Length
        $spaceSaved = $sizeBefore - $sizeAfter
        
        if ($spaceSaved -gt 0) {
            $spaceSavedMB = [Math]::Round($spaceSaved / 1MB, 2)
            Write-LogSuccess "Database optimized. Space saved: $spaceSavedMB MB"
        } else {
            Write-LogInfo "Database optimization completed"
        }
    }
    catch {
        Write-LogWarning "Database optimization failed: $DatabasePath" -Exception $_.Exception
    }
}

<#
.SYNOPSIS
    Cleans multiple database files
.PARAMETER DatabasePaths
    Array of database file paths
.PARAMETER CreateBackup
    Create backups before cleaning
.PARAMETER CleanAugment
    Remove Augment-related entries
.PARAMETER CleanTelemetry
    Remove telemetry entries
.PARAMETER CleanExtensions
    Remove extension-related entries
.OUTPUTS
    CleaningResult[] - Array of cleaning results
#>
function Clear-VSCodeDatabases {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$DatabasePaths,
        [bool]$CreateBackup = $true,
        [bool]$CleanAugment = $true,
        [bool]$CleanTelemetry = $true,
        [bool]$CleanExtensions = $true
    )
    
    $results = @()
    $totalDatabases = $DatabasePaths.Count
    $currentIndex = 0
    
    Write-LogInfo "Starting database cleaning for $totalDatabases database(s)"
    
    foreach ($dbPath in $DatabasePaths) {
        $currentIndex++
        $percentComplete = [Math]::Round(($currentIndex / $totalDatabases) * 100)
        
        Write-LogProgress -Activity "Cleaning VS Code Databases" -Status "Processing $currentIndex of $totalDatabases" -PercentComplete $percentComplete
        
        $result = Clear-VSCodeDatabase -DatabasePath $dbPath -CreateBackup $CreateBackup -CleanAugment $CleanAugment -CleanTelemetry $CleanTelemetry -CleanExtensions $CleanExtensions
        $results += $result
    }
    
    Complete-LogProgress
    
    # Summary
    $successCount = ($results | Where-Object { $_.Success }).Count
    $totalEntriesRemoved = ($results | Measure-Object -Property TotalEntriesRemoved -Sum).Sum
    
    Write-LogInfo "Database cleaning summary:"
    Write-LogInfo "  Databases processed: $totalDatabases"
    Write-LogInfo "  Successful: $successCount"
    Write-LogInfo "  Failed: $($totalDatabases - $successCount)"
    Write-LogInfo "  Total entries removed: $totalEntriesRemoved"
    
    return $results
}

<#
.SYNOPSIS
    Analyzes database content before cleaning
.PARAMETER DatabasePath
    Path to the SQLite database
.OUTPUTS
    hashtable - Analysis results
#>
function Get-DatabaseAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath
    )
    
    $analysis = @{
        DatabasePath = $DatabasePath
        TotalEntries = 0
        AugmentEntries = 0
        TelemetryEntries = 0
        ExtensionEntries = 0
        DatabaseSize = 0
        IsAccessible = $false
    }
    
    try {
        if (-not (Test-Path $DatabasePath)) {
            return $analysis
        }
        
        $analysis.DatabaseSize = (Get-Item $DatabasePath).Length
        
        if (-not (Test-DatabaseConnectivity -DatabasePath $DatabasePath)) {
            return $analysis
        }
        
        $analysis.IsAccessible = $true
        
        # Count total entries
        $totalQuery = "SELECT COUNT(*) FROM ItemTable;"
        $totalResult = & sqlite3 $DatabasePath $totalQuery
        if ($totalResult) {
            $analysis.TotalEntries = [int]$totalResult
        }
        
        # Count Augment entries
        foreach ($pattern in $script:AugmentPatterns) {
            $sanitizedPattern = Get-SafeSQLPattern -Pattern $pattern
            $countQuery = "SELECT COUNT(*) FROM ItemTable WHERE key LIKE '$sanitizedPattern';"
            $countResult = & sqlite3 $DatabasePath $countQuery
            if ($countResult) {
                $analysis.AugmentEntries += [int]$countResult
            }
        }

        # Count telemetry entries
        foreach ($pattern in $script:TelemetryPatterns) {
            $sanitizedPattern = Get-SafeSQLPattern -Pattern $pattern
            $countQuery = "SELECT COUNT(*) FROM ItemTable WHERE key LIKE '$sanitizedPattern';"
            $countResult = & sqlite3 $DatabasePath $countQuery
            if ($countResult) {
                $analysis.TelemetryEntries += [int]$countResult
            }
        }

        # Count extension entries
        foreach ($pattern in $script:ExtensionPatterns) {
            $sanitizedPattern = Get-SafeSQLPattern -Pattern $pattern
            $countQuery = "SELECT COUNT(*) FROM ItemTable WHERE key LIKE '$sanitizedPattern';"
            $countResult = & sqlite3 $DatabasePath $countQuery
            if ($countResult) {
                $analysis.ExtensionEntries += [int]$countResult
            }
        }
    }
    catch {
        Write-LogError "Failed to analyze database: $DatabasePath" -Exception $_.Exception
    }
    
    return $analysis
}

<#
.SYNOPSIS
    Shows database cleaning preview
.PARAMETER DatabasePaths
    Array of database file paths
#>
function Show-CleaningPreview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$DatabasePaths
    )
    
    Write-LogInfo "=== Database Cleaning Preview ==="
    
    $totalAugment = 0
    $totalTelemetry = 0
    $totalExtensions = 0
    $totalSize = 0
    
    foreach ($dbPath in $DatabasePaths) {
        $analysis = Get-DatabaseAnalysis -DatabasePath $dbPath
        
        if ($analysis.IsAccessible) {
            Write-LogInfo "Database: $($analysis.DatabasePath)"
            Write-LogInfo "  Size: $([Math]::Round($analysis.DatabaseSize / 1KB, 2)) KB"
            Write-LogInfo "  Total entries: $($analysis.TotalEntries)"
            Write-LogInfo "  Augment entries: $($analysis.AugmentEntries)"
            Write-LogInfo "  Telemetry entries: $($analysis.TelemetryEntries)"
            Write-LogInfo "  Extension entries: $($analysis.ExtensionEntries)"
            
            $totalAugment += $analysis.AugmentEntries
            $totalTelemetry += $analysis.TelemetryEntries
            $totalExtensions += $analysis.ExtensionEntries
            $totalSize += $analysis.DatabaseSize
        } else {
            Write-LogWarning "Database not accessible: $dbPath"
        }
    }
    
    Write-LogInfo "=== Summary ==="
    Write-LogInfo "Total databases: $($DatabasePaths.Count)"
    Write-LogInfo "Total size: $([Math]::Round($totalSize / 1MB, 2)) MB"
    Write-LogInfo "Total Augment entries to remove: $totalAugment"
    Write-LogInfo "Total telemetry entries to remove: $totalTelemetry"
    Write-LogInfo "Total extension entries to remove: $totalExtensions"
    Write-LogInfo "==============="
}

# Export module functions
Export-ModuleMember -Function @(
    'Clear-VSCodeDatabase',
    'Clear-VSCodeDatabases',
    'Get-DatabaseAnalysis',
    'Show-CleaningPreview',
    'Test-DatabaseConnectivity',
    'Optimize-Database'
)
