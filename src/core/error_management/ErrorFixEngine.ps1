# ErrorFixEngine.ps1
# Intelligent Error Fixing Engine
# Version: 1.0.0 - Comprehensive automatic error fixing system

# Prevent multiple inclusions
if ($Global:ErrorFixEngineLoaded) {
    return
}
$Global:ErrorFixEngineLoaded = $true

# Error handling
$ErrorActionPreference = "Stop"

# Load required modules
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreRoot = Split-Path -Parent $scriptRoot

# Load dependencies
. (Join-Path $coreRoot "AugmentLogger.ps1")
. (Join-Path $coreRoot "utilities\common_utilities.ps1")
. (Join-Path $coreRoot "security\secure_file_ops.ps1")
. (Join-Path $scriptRoot "ErrorTypes.ps1")

#region Configuration

$Global:FixEngineConfig = @{
    MaxRetryAttempts = 3
    BackupEnabled = $true
    DryRunMode = $false
    ParallelExecution = $false
    MaxParallelJobs = 4
    TimeoutSeconds = 300
    SafetyChecks = $true
    AutoRollback = $true
}

#endregion

#region Core Fix Functions

function Start-AutoErrorFix {
    <#
    .SYNOPSIS
        Start automatic error fixing process
    .DESCRIPTION
        Automatically fixes detected errors using intelligent strategies
    .PARAMETER DetectedErrors
        Array of error objects to fix
    .PARAMETER FixStrategy
        Specific fix strategy to use, or AUTO for automatic selection
    .PARAMETER DryRun
        Run in dry-run mode without making changes
    .OUTPUTS
        [hashtable] Fix results with success/failure details
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$DetectedErrors,
        
        [Parameter(Mandatory = $false)]
        [string]$FixStrategy = "AUTO",
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun = $false
    )
    
    Write-LogInfo "Starting Auto Error Fix - Strategy: $FixStrategy, DryRun: $DryRun" "ERROR_FIX_ENGINE"
    
    $fixResults = @{
        FixId = [System.Guid]::NewGuid().ToString()
        StartTime = Get-Date
        Strategy = $FixStrategy
        DryRun = $DryRun
        TotalErrors = $DetectedErrors.Count
        FixedErrors = @()
        FailedErrors = @()
        SkippedErrors = @()
        Summary = @{
            Fixed = 0
            Failed = 0
            Skipped = 0
            SuccessRate = 0
        }
        Duration = 0
        Status = "RUNNING"
    }
    
    try {
        # Group errors by fix strategy for efficient processing
        $errorGroups = Group-ErrorsByStrategy -DetectedErrors $DetectedErrors
        
        foreach ($group in $errorGroups) {
            Write-LogInfo "Processing error group: $($group.Strategy) ($($group.Errors.Count) errors)" "ERROR_FIX_ENGINE"
            
            $groupResult = Invoke-StrategyFix -ErrorGroup $group -DryRun $DryRun
            
            $fixResults.FixedErrors += $groupResult.FixedErrors
            $fixResults.FailedErrors += $groupResult.FailedErrors
            $fixResults.SkippedErrors += $groupResult.SkippedErrors
        }
        
        # Calculate summary
        $fixResults.Summary.Fixed = $fixResults.FixedErrors.Count
        $fixResults.Summary.Failed = $fixResults.FailedErrors.Count
        $fixResults.Summary.Skipped = $fixResults.SkippedErrors.Count
        $fixResults.Summary.SuccessRate = if ($fixResults.TotalErrors -gt 0) { 
            [math]::Round(($fixResults.Summary.Fixed / $fixResults.TotalErrors) * 100, 2) 
        } else { 0 }
        
        $fixResults.Status = "COMPLETED"
        $fixResults.Duration = ((Get-Date) - $fixResults.StartTime).TotalSeconds
        
        Write-LogSuccess "Error fixing completed. Fixed: $($fixResults.Summary.Fixed), Failed: $($fixResults.Summary.Failed), Success Rate: $($fixResults.Summary.SuccessRate)%" "ERROR_FIX_ENGINE"
        
        return $fixResults
        
    } catch {
        Write-LogError "Error fixing failed: $($_.Exception.Message)" "ERROR_FIX_ENGINE"
        $fixResults.Status = "FAILED"
        $fixResults.Error = $_.Exception.Message
        return $fixResults
    }
}

function Group-ErrorsByStrategy {
    <#
    .SYNOPSIS
        Group errors by their fix strategies
    .DESCRIPTION
        Groups detected errors by fix strategy for efficient batch processing
    .PARAMETER DetectedErrors
        Array of detected error objects
    .OUTPUTS
        [array] Array of error groups
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$DetectedErrors
    )
    
    $groups = @()
    $strategyGroups = $DetectedErrors | Group-Object -Property FixStrategy
    
    foreach ($strategyGroup in $strategyGroups) {
        $strategy = Get-FixStrategy -ErrorType @{ FixStrategy = $strategyGroup.Name }
        
        $group = @{
            Strategy = $strategyGroup.Name
            StrategyDetails = $strategy
            Errors = $strategyGroup.Group
            Priority = ($strategyGroup.Group | Measure-Object -Property Priority -Maximum).Maximum
        }
        
        $groups += $group
    }
    
    # Sort by priority
    $priorityOrder = @{ "CRITICAL" = 4; "HIGH" = 3; "MEDIUM" = 2; "LOW" = 1 }
    $groups = $groups | Sort-Object { $priorityOrder[$_.Priority] } -Descending
    
    return $groups
}

function Invoke-StrategyFix {
    <#
    .SYNOPSIS
        Execute fix strategy for error group
    .DESCRIPTION
        Applies specific fix strategy to group of related errors
    .PARAMETER ErrorGroup
        Error group object with strategy details
    .PARAMETER DryRun
        Run in dry-run mode
    .OUTPUTS
        [hashtable] Strategy fix results
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ErrorGroup,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun = $false
    )
    
    $strategyResult = @{
        Strategy = $ErrorGroup.Strategy
        FixedErrors = @()
        FailedErrors = @()
        SkippedErrors = @()
        StartTime = Get-Date
        Duration = 0
    }
    
    try {
        Write-LogInfo "Executing fix strategy: $($ErrorGroup.Strategy)" "ERROR_FIX_ENGINE"
        
        switch ($ErrorGroup.Strategy) {
            "NULL_SAFE_QUERY" {
                $strategyResult = Invoke-NullSafeQueryFix -Errors $ErrorGroup.Errors -DryRun $DryRun
            }
            "RECREATE_DATABASE" {
                $strategyResult = Invoke-RecreateDatabase -Errors $ErrorGroup.Errors -DryRun $DryRun
            }
            "CREATE_DEFAULT_CONFIG" {
                $strategyResult = Invoke-CreateDefaultConfig -Errors $ErrorGroup.Errors -DryRun $DryRun
            }
            "SYNC_TELEMETRY_IDS" {
                $strategyResult = Invoke-SyncTelemetryIds -Errors $ErrorGroup.Errors -DryRun $DryRun
            }
            "NORMALIZE_TIMESTAMPS" {
                $strategyResult = Invoke-NormalizeTimestamps -Errors $ErrorGroup.Errors -DryRun $DryRun
            }
            "GENERATE_NEW_ID" {
                $strategyResult = Invoke-GenerateNewId -Errors $ErrorGroup.Errors -DryRun $DryRun
            }
            default {
                Write-LogWarning "Unknown fix strategy: $($ErrorGroup.Strategy)" "ERROR_FIX_ENGINE"
                foreach ($error in $ErrorGroup.Errors) {
                    $strategyResult.SkippedErrors += $error
                }
            }
        }
        
        $strategyResult.Duration = ((Get-Date) - $strategyResult.StartTime).TotalSeconds
        
    } catch {
        Write-LogError "Strategy execution failed for $($ErrorGroup.Strategy): $($_.Exception.Message)" "ERROR_FIX_ENGINE"
        foreach ($error in $ErrorGroup.Errors) {
            $error.FixError = $_.Exception.Message
            $strategyResult.FailedErrors += $error
        }
    }
    
    return $strategyResult
}

#endregion

#region Specific Fix Implementations

function Invoke-NullSafeQueryFix {
    <#
    .SYNOPSIS
        Fix null value query errors
    .DESCRIPTION
        Implements null-safe database query operations
    .PARAMETER Errors
        Array of null value errors
    .PARAMETER DryRun
        Run in dry-run mode
    .OUTPUTS
        [hashtable] Fix results
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Errors,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun = $false
    )
    
    $result = @{
        Strategy = "NULL_SAFE_QUERY"
        FixedErrors = @()
        FailedErrors = @()
        SkippedErrors = @()
        StartTime = Get-Date
        Duration = 0
    }
    
    foreach ($error in $Errors) {
        try {
            Write-LogInfo "Fixing null query error in: $($error.Source)" "ERROR_FIX_ENGINE"
            
            if ($DryRun) {
                Write-LogInfo "[DRY RUN] Would implement null-safe query for: $($error.Source)" "ERROR_FIX_ENGINE"
                $error.FixAction = "NULL_SAFE_QUERY_DRY_RUN"
                $result.FixedErrors += $error
                continue
            }
            
            # Implement null-safe query logic
            $fixSuccess = Repair-NullQueryIssue -DatabasePath $error.Source
            
            if ($fixSuccess) {
                $error.FixAction = "NULL_SAFE_QUERY_APPLIED"
                $error.FixedAt = Get-Date
                $result.FixedErrors += $error
                Write-LogSuccess "Fixed null query error in: $($error.Source)" "ERROR_FIX_ENGINE"
            } else {
                $error.FixError = "Failed to apply null-safe query fix"
                $result.FailedErrors += $error
            }
            
        } catch {
            Write-LogError "Failed to fix null query error in $($error.Source): $($_.Exception.Message)" "ERROR_FIX_ENGINE"
            $error.FixError = $_.Exception.Message
            $result.FailedErrors += $error
        }
    }
    
    $result.Duration = ((Get-Date) - $result.StartTime).TotalSeconds
    return $result
}

function Repair-NullQueryIssue {
    <#
    .SYNOPSIS
        Repair null query issues in database
    .DESCRIPTION
        Implements safe database query operations with null checking
    .PARAMETER DatabasePath
        Path to database file
    .OUTPUTS
        [bool] Success status
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath
    )
    
    try {
        # Validate database file exists and is accessible
        if (-not (Test-PathSafely $DatabasePath -PathType "File")) {
            Write-LogError "Database file not accessible: $DatabasePath" "ERROR_FIX_ENGINE"
            return $false
        }
        
        # Test database integrity
        $integrityCheck = Invoke-SQLiteQuerySafely -DatabasePath $DatabasePath -Query "PRAGMA integrity_check;" -QueryType "Pragma"
        
        if ($integrityCheck -ne "ok") {
            Write-LogWarning "Database integrity issues detected in: $DatabasePath" "ERROR_FIX_ENGINE"
        }
        
        # Ensure required telemetry keys exist with default values
        $telemetryKeys = @{
            'telemetry.machineId' = (New-Guid).ToString().Replace('-', '')
            'telemetry.devDeviceId' = (New-Guid).ToString()
            'telemetry.sqmId' = (New-Guid).ToString().ToUpper()
        }
        
        foreach ($key in $telemetryKeys.GetEnumerator()) {
            $existingValue = Invoke-SQLiteQuerySafely -DatabasePath $DatabasePath -Query "SELECT value FROM ItemTable WHERE key = '$($key.Key)';" -QueryType "Select"
            
            if (-not $existingValue) {
                # Insert default value
                $insertQuery = "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('$($key.Key)', '$($key.Value)');"
                $insertResult = Invoke-SQLiteQuerySafely -DatabasePath $DatabasePath -Query $insertQuery -QueryType "Insert"
                Write-LogInfo "Inserted default value for $($key.Key) in $DatabasePath" "ERROR_FIX_ENGINE"
            }
        }
        
        return $true
        
    } catch {
        Write-LogError "Failed to repair null query issue in $DatabasePath : $($_.Exception.Message)" "ERROR_FIX_ENGINE"
        return $false
    }
}

function Invoke-CreateDefaultConfig {
    <#
    .SYNOPSIS
        Create missing configuration files
    .DESCRIPTION
        Creates default configuration files with proper telemetry data
    .PARAMETER Errors
        Array of configuration errors
    .PARAMETER DryRun
        Run in dry-run mode
    .OUTPUTS
        [hashtable] Fix results
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Errors,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun = $false
    )

    $result = @{
        Strategy = "CREATE_DEFAULT_CONFIG"
        FixedErrors = @()
        FailedErrors = @()
        SkippedErrors = @()
        StartTime = Get-Date
        Duration = 0
    }

    foreach ($error in $Errors) {
        try {
            Write-LogInfo "Creating default config for: $($error.Source)" "ERROR_FIX_ENGINE"

            if ($DryRun) {
                Write-LogInfo "[DRY RUN] Would create default config: $($error.Source)" "ERROR_FIX_ENGINE"
                $error.FixAction = "CREATE_DEFAULT_CONFIG_DRY_RUN"
                $result.FixedErrors += $error
                continue
            }

            $fixSuccess = New-DefaultConfigFile -ConfigPath $error.Source

            if ($fixSuccess) {
                $error.FixAction = "DEFAULT_CONFIG_CREATED"
                $error.FixedAt = Get-Date
                $result.FixedErrors += $error
                Write-LogSuccess "Created default config: $($error.Source)" "ERROR_FIX_ENGINE"
            } else {
                $error.FixError = "Failed to create default configuration"
                $result.FailedErrors += $error
            }

        } catch {
            Write-LogError "Failed to create default config $($error.Source): $($_.Exception.Message)" "ERROR_FIX_ENGINE"
            $error.FixError = $_.Exception.Message
            $result.FailedErrors += $error
        }
    }

    $result.Duration = ((Get-Date) - $result.StartTime).TotalSeconds
    return $result
}

function New-DefaultConfigFile {
    <#
    .SYNOPSIS
        Create new default configuration file
    .DESCRIPTION
        Creates configuration file with default telemetry values
    .PARAMETER ConfigPath
        Path where config file should be created
    .OUTPUTS
        [bool] Success status
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    try {
        # Ensure directory exists
        $configDir = Split-Path $ConfigPath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }

        # Generate new telemetry IDs
        $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

        $defaultConfig = @{
            "telemetry.machineId" = (New-Guid).ToString().Replace('-', '')
            "telemetry.devDeviceId" = (New-Guid).ToString()
            "telemetry.sqmId" = (New-Guid).ToString().ToUpper()
            "telemetry.firstSessionDate" = $timestamp
            "telemetry.lastSessionDate" = $timestamp
            "telemetry.currentSessionDate" = $timestamp
        }

        # Save configuration file
        $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8

        Write-LogInfo "Created default configuration file: $ConfigPath" "ERROR_FIX_ENGINE"
        return $true

    } catch {
        Write-LogError "Failed to create default config file $ConfigPath : $($_.Exception.Message)" "ERROR_FIX_ENGINE"
        return $false
    }
}

function Invoke-SyncTelemetryIds {
    <#
    .SYNOPSIS
        Synchronize telemetry IDs across files
    .DESCRIPTION
        Ensures all telemetry IDs are consistent across database and config files
    .PARAMETER Errors
        Array of consistency errors
    .PARAMETER DryRun
        Run in dry-run mode
    .OUTPUTS
        [hashtable] Fix results
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Errors,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun = $false
    )

    $result = @{
        Strategy = "SYNC_TELEMETRY_IDS"
        FixedErrors = @()
        FailedErrors = @()
        SkippedErrors = @()
        StartTime = Get-Date
        Duration = 0
    }

    try {
        # Generate unified telemetry IDs
        $unifiedIds = @{
            MachineId = (New-Guid).ToString().Replace('-', '')
            DeviceId = (New-Guid).ToString()
            SqmId = (New-Guid).ToString().ToUpper()
            Timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        }

        Write-LogInfo "Generated unified telemetry IDs for synchronization" "ERROR_FIX_ENGINE"

        foreach ($error in $Errors) {
            try {
                if ($DryRun) {
                    Write-LogInfo "[DRY RUN] Would sync telemetry IDs for: $($error.Source)" "ERROR_FIX_ENGINE"
                    $error.FixAction = "SYNC_TELEMETRY_IDS_DRY_RUN"
                    $result.FixedErrors += $error
                    continue
                }

                $fixSuccess = Sync-FileWithUnifiedIds -FilePath $error.Source -UnifiedIds $unifiedIds

                if ($fixSuccess) {
                    $error.FixAction = "TELEMETRY_IDS_SYNCED"
                    $error.FixedAt = Get-Date
                    $result.FixedErrors += $error
                    Write-LogSuccess "Synced telemetry IDs for: $($error.Source)" "ERROR_FIX_ENGINE"
                } else {
                    $error.FixError = "Failed to sync telemetry IDs"
                    $result.FailedErrors += $error
                }

            } catch {
                Write-LogError "Failed to sync telemetry IDs for $($error.Source): $($_.Exception.Message)" "ERROR_FIX_ENGINE"
                $error.FixError = $_.Exception.Message
                $result.FailedErrors += $error
            }
        }

    } catch {
        Write-LogError "Telemetry ID sync failed: $($_.Exception.Message)" "ERROR_FIX_ENGINE"
        foreach ($error in $Errors) {
            $error.FixError = $_.Exception.Message
            $result.FailedErrors += $error
        }
    }

    $result.Duration = ((Get-Date) - $result.StartTime).TotalSeconds
    return $result
}

function Sync-FileWithUnifiedIds {
    <#
    .SYNOPSIS
        Synchronize file with unified telemetry IDs
    .DESCRIPTION
        Updates database or config file with unified telemetry identifiers
    .PARAMETER FilePath
        Path to file to synchronize
    .PARAMETER UnifiedIds
        Unified telemetry IDs to apply
    .OUTPUTS
        [bool] Success status
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [hashtable]$UnifiedIds
    )

    try {
        if (-not (Test-PathSafely $FilePath -PathType "File")) {
            Write-LogError "File not accessible for sync: $FilePath" "ERROR_FIX_ENGINE"
            return $false
        }

        # Create backup
        $backupPath = "$FilePath.fix_backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $FilePath $backupPath -Force
        Write-LogInfo "Created backup: $backupPath" "ERROR_FIX_ENGINE"

        # Determine file type and apply appropriate sync
        if ($FilePath -like "*.json") {
            return Sync-ConfigFileIds -ConfigPath $FilePath -UnifiedIds $UnifiedIds
        } elseif ($FilePath -like "*.vscdb" -or $FilePath -like "*.db") {
            return Sync-DatabaseFileIds -DatabasePath $FilePath -UnifiedIds $UnifiedIds
        } else {
            Write-LogWarning "Unknown file type for sync: $FilePath" "ERROR_FIX_ENGINE"
            return $false
        }

    } catch {
        Write-LogError "Failed to sync file $FilePath : $($_.Exception.Message)" "ERROR_FIX_ENGINE"
        return $false
    }
}

function Sync-ConfigFileIds {
    <#
    .SYNOPSIS
        Sync configuration file with unified IDs
    .DESCRIPTION
        Updates JSON configuration file with unified telemetry IDs
    .PARAMETER ConfigPath
        Path to configuration file
    .PARAMETER UnifiedIds
        Unified telemetry IDs
    .OUTPUTS
        [bool] Success status
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $true)]
        [hashtable]$UnifiedIds
    )

    try {
        $content = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

        # Update telemetry IDs
        $content.'telemetry.machineId' = $UnifiedIds.MachineId
        $content.'telemetry.devDeviceId' = $UnifiedIds.DeviceId
        $content.'telemetry.sqmId' = $UnifiedIds.SqmId
        $content.'telemetry.firstSessionDate' = $UnifiedIds.Timestamp
        $content.'telemetry.lastSessionDate' = $UnifiedIds.Timestamp
        $content.'telemetry.currentSessionDate' = $UnifiedIds.Timestamp

        # Save updated content
        $content | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8

        Write-LogInfo "Synced configuration file: $ConfigPath" "ERROR_FIX_ENGINE"
        return $true

    } catch {
        Write-LogError "Failed to sync config file $ConfigPath : $($_.Exception.Message)" "ERROR_FIX_ENGINE"
        return $false
    }
}

function Sync-DatabaseFileIds {
    <#
    .SYNOPSIS
        Sync database file with unified IDs
    .DESCRIPTION
        Updates SQLite database with unified telemetry IDs
    .PARAMETER DatabasePath
        Path to database file
    .PARAMETER UnifiedIds
        Unified telemetry IDs
    .OUTPUTS
        [bool] Success status
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,

        [Parameter(Mandatory = $true)]
        [hashtable]$UnifiedIds
    )

    try {
        # Update telemetry IDs in database
        $updateQueries = @(
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.machineId', '$($UnifiedIds.MachineId)');"
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.devDeviceId', '$($UnifiedIds.DeviceId)');"
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.sqmId', '$($UnifiedIds.SqmId)');"
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('storage.serviceMachineId', '$($UnifiedIds.DeviceId)');"
        )

        foreach ($query in $updateQueries) {
            $result = Invoke-SQLiteQuerySafely -DatabasePath $DatabasePath -Query $query -QueryType "Insert"
            if (-not $result) {
                Write-LogWarning "Failed to execute query: $query" "ERROR_FIX_ENGINE"
            }
        }

        Write-LogInfo "Synced database file: $DatabasePath" "ERROR_FIX_ENGINE"
        return $true

    } catch {
        Write-LogError "Failed to sync database file $DatabasePath : $($_.Exception.Message)" "ERROR_FIX_ENGINE"
        return $false
    }
}

#endregion

# Export functions when loaded as module
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    Write-Verbose "Error Fix Engine loaded via dot-sourcing"
} else {
    Export-ModuleMember -Function @(
        'Start-AutoErrorFix',
        'Group-ErrorsByStrategy',
        'Invoke-StrategyFix',
        'Invoke-NullSafeQueryFix',
        'Invoke-CreateDefaultConfig',
        'Invoke-SyncTelemetryIds'
    )
}

Write-LogInfo "Error Fix Engine initialized successfully" "ERROR_FIX_ENGINE"
