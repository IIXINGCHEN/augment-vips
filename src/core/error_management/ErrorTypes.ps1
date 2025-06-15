# ErrorTypes.ps1
# Standardized Error Type Definitions and Handling Strategies
# Version: 1.0.0 - Complete error classification system

# Prevent multiple inclusions
if ($Global:ErrorTypesLoaded) {
    return
}
$Global:ErrorTypesLoaded = $true

# Error handling
$ErrorActionPreference = "Stop"

#region Error Type Definitions

# Core error categories
$Global:ErrorCategories = @{
    DATABASE_ERROR = @{
        Code = "DB"
        Name = "Database Error"
        Description = "SQLite database operation failures"
        Severity = "HIGH"
        AutoFixable = $true
    }
    CONFIG_ERROR = @{
        Code = "CFG"
        Name = "Configuration Error"
        Description = "JSON configuration file issues"
        Severity = "MEDIUM"
        AutoFixable = $true
    }
    CONSISTENCY_ERROR = @{
        Code = "CONS"
        Name = "Data Consistency Error"
        Description = "Telemetry data inconsistencies"
        Severity = "HIGH"
        AutoFixable = $true
    }
    NULL_VALUE_ERROR = @{
        Code = "NULL"
        Name = "Null Value Error"
        Description = "Null or empty value handling failures"
        Severity = "MEDIUM"
        AutoFixable = $true
    }
    PERMISSION_ERROR = @{
        Code = "PERM"
        Name = "Permission Error"
        Description = "File or directory access permission issues"
        Severity = "HIGH"
        AutoFixable = $false
    }
    VALIDATION_ERROR = @{
        Code = "VAL"
        Name = "Validation Error"
        Description = "Data format or structure validation failures"
        Severity = "MEDIUM"
        AutoFixable = $true
    }
    SYSTEM_ERROR = @{
        Code = "SYS"
        Name = "System Error"
        Description = "Operating system or environment issues"
        Severity = "CRITICAL"
        AutoFixable = $false
    }
}

# Specific error types with detailed definitions
$Global:ErrorTypes = @{
    # Database Errors
    DB_NULL_RESULT = @{
        Category = "DATABASE_ERROR"
        Code = "DB001"
        Name = "Database Query Null Result"
        Description = "SQLite query returned null or empty result"
        Symptoms = @("不能对 Null 值表达式调用方法", "Null reference exception")
        FixStrategy = "NULL_SAFE_QUERY"
        Priority = "HIGH"
    }
    DB_CONNECTION_FAILED = @{
        Category = "DATABASE_ERROR"
        Code = "DB002"
        Name = "Database Connection Failed"
        Description = "Unable to connect to SQLite database"
        Symptoms = @("Failed to query database", "Database file missing")
        FixStrategy = "RECREATE_DATABASE"
        Priority = "CRITICAL"
    }
    DB_CORRUPTION = @{
        Category = "DATABASE_ERROR"
        Code = "DB003"
        Name = "Database Corruption"
        Description = "SQLite database file is corrupted"
        Symptoms = @("Database disk image is malformed", "SQL error")
        FixStrategy = "REPAIR_DATABASE"
        Priority = "CRITICAL"
    }
    
    # Configuration Errors
    CFG_MISSING_FILE = @{
        Category = "CONFIG_ERROR"
        Code = "CFG001"
        Name = "Configuration File Missing"
        Description = "Required configuration file does not exist"
        Symptoms = @("No main config found", "Config file is empty")
        FixStrategy = "CREATE_DEFAULT_CONFIG"
        Priority = "HIGH"
    }
    CFG_INVALID_JSON = @{
        Category = "CONFIG_ERROR"
        Code = "CFG002"
        Name = "Invalid JSON Format"
        Description = "Configuration file contains invalid JSON"
        Symptoms = @("JSON parsing error", "Invalid character")
        FixStrategy = "REPAIR_JSON"
        Priority = "MEDIUM"
    }
    
    # Consistency Errors
    CONS_TELEMETRY_MISMATCH = @{
        Category = "CONSISTENCY_ERROR"
        Code = "CONS001"
        Name = "Telemetry ID Mismatch"
        Description = "Telemetry IDs inconsistent between database and config"
        Symptoms = @("INCONSISTENT", "Database:", "Config:")
        FixStrategy = "SYNC_TELEMETRY_IDS"
        Priority = "HIGH"
    }
    CONS_TIMESTAMP_MISMATCH = @{
        Category = "CONSISTENCY_ERROR"
        Code = "CONS002"
        Name = "Timestamp Inconsistency"
        Description = "Timestamp formats or values are inconsistent"
        Symptoms = @("TIME INCONSISTENT", "timestamp format")
        FixStrategy = "NORMALIZE_TIMESTAMPS"
        Priority = "MEDIUM"
    }
    
    # Null Value Errors
    NULL_MACHINE_ID = @{
        Category = "NULL_VALUE_ERROR"
        Code = "NULL001"
        Name = "Null Machine ID"
        Description = "Machine ID is null or empty"
        Symptoms = @("machineId is null", "empty machine identifier")
        FixStrategy = "GENERATE_NEW_ID"
        Priority = "HIGH"
    }
    NULL_DEVICE_ID = @{
        Category = "NULL_VALUE_ERROR"
        Code = "NULL002"
        Name = "Null Device ID"
        Description = "Device ID is null or empty"
        Symptoms = @("deviceId is null", "empty device identifier")
        FixStrategy = "GENERATE_NEW_ID"
        Priority = "HIGH"
    }
}

#endregion

#region Fix Strategies

$Global:FixStrategies = @{
    NULL_SAFE_QUERY = @{
        Name = "Null-Safe Query Execution"
        Description = "Execute SQLite queries with null value protection"
        Steps = @(
            "Validate database file existence",
            "Execute query with error handling",
            "Check for null results before processing",
            "Apply default values for null results"
        )
        RequiredModules = @("common_utilities")
        EstimatedTime = 5
    }
    RECREATE_DATABASE = @{
        Name = "Database Recreation"
        Description = "Recreate corrupted or missing database files"
        Steps = @(
            "Backup existing database if possible",
            "Create new database structure",
            "Restore data from backups",
            "Verify database integrity"
        )
        RequiredModules = @("secure_file_ops", "common_utilities")
        EstimatedTime = 30
    }
    CREATE_DEFAULT_CONFIG = @{
        Name = "Default Configuration Creation"
        Description = "Create missing configuration files with default values"
        Steps = @(
            "Generate default configuration structure",
            "Create new telemetry IDs",
            "Write configuration file",
            "Validate configuration format"
        )
        RequiredModules = @("secure_file_ops")
        EstimatedTime = 10
    }
    SYNC_TELEMETRY_IDS = @{
        Name = "Telemetry ID Synchronization"
        Description = "Synchronize telemetry IDs across all files"
        Steps = @(
            "Generate unified telemetry IDs",
            "Update all configuration files",
            "Update all database files",
            "Verify synchronization"
        )
        RequiredModules = @("common_utilities", "secure_file_ops")
        EstimatedTime = 20
    }
    NORMALIZE_TIMESTAMPS = @{
        Name = "Timestamp Normalization"
        Description = "Normalize timestamp formats across all files"
        Steps = @(
            "Identify current timestamp formats",
            "Convert to standard format",
            "Update all affected files",
            "Verify timestamp consistency"
        )
        RequiredModules = @("common_utilities")
        EstimatedTime = 15
    }
    GENERATE_NEW_ID = @{
        Name = "New ID Generation"
        Description = "Generate new unique identifiers"
        Steps = @(
            "Generate cryptographically secure ID",
            "Validate ID uniqueness",
            "Update all references",
            "Verify ID consistency"
        )
        RequiredModules = @("common_utilities")
        EstimatedTime = 5
    }
}

#endregion

#region Error Detection Functions

function Get-ErrorTypeBySymptom {
    <#
    .SYNOPSIS
        Identify error type based on symptoms
    .DESCRIPTION
        Analyzes error symptoms and returns matching error type definition
    .PARAMETER Symptom
        Error symptom or message to analyze
    .OUTPUTS
        [hashtable] Error type definition or $null if not found
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Symptom
    )
    
    foreach ($errorType in $Global:ErrorTypes.GetEnumerator()) {
        foreach ($symptomPattern in $errorType.Value.Symptoms) {
            if ($Symptom -like "*$symptomPattern*") {
                return $errorType.Value
            }
        }
    }
    
    return $null
}

function Get-FixStrategy {
    <#
    .SYNOPSIS
        Get fix strategy for error type
    .DESCRIPTION
        Returns detailed fix strategy for specified error type
    .PARAMETER ErrorType
        Error type definition
    .OUTPUTS
        [hashtable] Fix strategy definition
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ErrorType
    )
    
    if ($Global:FixStrategies.ContainsKey($ErrorType.FixStrategy)) {
        return $Global:FixStrategies[$ErrorType.FixStrategy]
    }
    
    return $null
}

function Test-ErrorAutoFixable {
    <#
    .SYNOPSIS
        Check if error type is auto-fixable
    .DESCRIPTION
        Determines if the error can be automatically fixed
    .PARAMETER ErrorType
        Error type definition
    .OUTPUTS
        [bool] True if auto-fixable, false otherwise
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ErrorType
    )
    
    $category = $Global:ErrorCategories[$ErrorType.Category]
    return $category.AutoFixable
}

#endregion

# Export functions when loaded as module
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    Write-Verbose "Error Types system loaded via dot-sourcing"
} else {
    Export-ModuleMember -Function @(
        'Get-ErrorTypeBySymptom',
        'Get-FixStrategy', 
        'Test-ErrorAutoFixable'
    )
}

Write-Verbose "Error Types system initialized successfully"
