# DatabaseOperations.ps1
# Unified Database Operations for Anti-Detection
# Version: 1.0.0
# Features: Standardized database operations, SQL injection protection, transaction support

# Prevent multiple inclusions
if ($Global:DatabaseOperationsLoaded) {
    return
}
$Global:DatabaseOperationsLoaded = $true

# Error handling
$ErrorActionPreference = "Stop"

#region Database Configuration

$Global:DatabaseConfig = @{
    DefaultTimeout = 30
    MaxRetries = 3
    EnableTransactions = $true
    EnableBackups = $true
    BackupDirectory = "backups"
}

#endregion

#region Core Database Functions

function Invoke-SafeDatabaseQuery {
    <#
    .SYNOPSIS
        Executes database queries with enhanced safety and anti-detection features
    .DESCRIPTION
        Provides secure database operations with automatic backup, transaction support, and error handling
    .PARAMETER DatabasePath
        Path to the database file
    .PARAMETER Query
        SQL query to execute
    .PARAMETER QueryType
        Type of query (Select, Insert, Update, Delete)
    .PARAMETER CreateBackup
        Create backup before modification
    .PARAMETER UseTransaction
        Execute within a transaction
    .OUTPUTS
        [object] Query results or operation status
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,
        
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Select', 'Insert', 'Update', 'Delete', 'Pragma')]
        [string]$QueryType = 'Select',
        
        [switch]$CreateBackup = $true,
        [switch]$UseTransaction = $false,
        [int]$TimeoutSeconds = 30
    )
    
    try {
        # Validate database path
        if (-not (Test-Path $DatabasePath)) {
            throw "Database file not found: $DatabasePath"
        }
        
        # Validate query safety
        if (-not (Test-QuerySafety $Query $QueryType)) {
            throw "Query failed security validation"
        }
        
        # Create backup if requested and query modifies data
        if ($CreateBackup -and $QueryType -in @('Insert', 'Update', 'Delete')) {
            $backupPath = New-DatabaseBackup -DatabasePath $DatabasePath
            Write-LogInfo "Database backup created: $backupPath" "DATABASE"
        }
        
        # Execute query with optional transaction
        if ($UseTransaction -and $QueryType -in @('Insert', 'Update', 'Delete')) {
            $result = Invoke-DatabaseTransaction -DatabasePath $DatabasePath -Query $Query -TimeoutSeconds $TimeoutSeconds
        } else {
            $result = Invoke-DatabaseQueryDirect -DatabasePath $DatabasePath -Query $Query -TimeoutSeconds $TimeoutSeconds
        }
        
        Write-LogDebug "Database query executed successfully: $QueryType" "DATABASE"
        return $result
        
    } catch {
        Write-LogError "Database query failed: $($_.Exception.Message)" "DATABASE"
        throw
    }
}

function New-DatabaseBackup {
    <#
    .SYNOPSIS
        Creates a backup of the database file
    .DESCRIPTION
        Creates a timestamped backup copy of the database
    .PARAMETER DatabasePath
        Path to the database file to backup
    .OUTPUTS
        [string] Path to the backup file
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath
    )
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupDir = Join-Path (Split-Path $DatabasePath -Parent) $Global:DatabaseConfig.BackupDirectory
        
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }
        
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($DatabasePath)
        $extension = [System.IO.Path]::GetExtension($DatabasePath)
        $backupPath = Join-Path $backupDir "$fileName.backup.$timestamp$extension"
        
        Copy-Item $DatabasePath $backupPath -Force
        return $backupPath
        
    } catch {
        Write-LogError "Failed to create database backup: $($_.Exception.Message)" "DATABASE"
        throw
    }
}

function Invoke-DatabaseTransaction {
    <#
    .SYNOPSIS
        Executes database query within a transaction
    .DESCRIPTION
        Provides transaction support for database operations
    .PARAMETER DatabasePath
        Path to the database file
    .PARAMETER Query
        SQL query to execute
    .PARAMETER TimeoutSeconds
        Query timeout in seconds
    .OUTPUTS
        [object] Query results
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,
        
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [int]$TimeoutSeconds = 30
    )
    
    try {
        $transactionQueries = @(
            "BEGIN TRANSACTION;",
            $Query,
            "COMMIT;"
        )
        
        $results = @()
        foreach ($tQuery in $transactionQueries) {
            $result = Invoke-DatabaseQueryDirect -DatabasePath $DatabasePath -Query $tQuery -TimeoutSeconds $TimeoutSeconds
            if ($tQuery -eq $Query) {
                $results += $result
            }
        }
        
        return $results
        
    } catch {
        # Attempt rollback
        try {
            Invoke-DatabaseQueryDirect -DatabasePath $DatabasePath -Query "ROLLBACK;" -TimeoutSeconds 5
            Write-LogWarning "Transaction rolled back due to error" "DATABASE"
        } catch {
            Write-LogError "Failed to rollback transaction" "DATABASE"
        }
        throw
    }
}

function Invoke-DatabaseQueryDirect {
    <#
    .SYNOPSIS
        Executes database query directly
    .DESCRIPTION
        Direct database query execution with timeout and error handling
    .PARAMETER DatabasePath
        Path to the database file
    .PARAMETER Query
        SQL query to execute
    .PARAMETER TimeoutSeconds
        Query timeout in seconds
    .OUTPUTS
        [object] Query results
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,
        
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [int]$TimeoutSeconds = 30
    )
    
    try {
        $timeoutArg = ".timeout $TimeoutSeconds"
        $result = sqlite3 -cmd $timeoutArg $DatabasePath $Query 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "SQLite execution failed: $result"
        }
        
        return $result
        
    } catch {
        Write-LogError "Direct database query failed: $($_.Exception.Message)" "DATABASE"
        throw
    }
}

function Test-QuerySafety {
    <#
    .SYNOPSIS
        Validates SQL query for security issues
    .DESCRIPTION
        Checks queries for potential SQL injection and other security issues
    .PARAMETER Query
        SQL query to validate
    .PARAMETER QueryType
        Expected query type
    .OUTPUTS
        [bool] True if query is safe
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [Parameter(Mandatory = $true)]
        [string]$QueryType
    )
    
    try {
        # Basic SQL injection patterns
        $dangerousPatterns = @(
            ";\s*(DROP|DELETE|INSERT|UPDATE|CREATE|ALTER)\s+",
            "--",
            "/\*.*\*/",
            "UNION\s+SELECT",
            "OR\s+1\s*=\s*1",
            "AND\s+1\s*=\s*1"
        )
        
        foreach ($pattern in $dangerousPatterns) {
            if ($Query -match $pattern) {
                Write-LogWarning "Potentially dangerous SQL pattern detected: $pattern" "DATABASE"
                return $false
            }
        }
        
        # Validate query type matches expected operation
        $queryUpper = $Query.ToUpper().Trim()
        switch ($QueryType) {
            'Select' { if (-not $queryUpper.StartsWith('SELECT') -and -not $queryUpper.StartsWith('PRAGMA')) { return $false } }
            'Insert' { if (-not $queryUpper.StartsWith('INSERT')) { return $false } }
            'Update' { if (-not $queryUpper.StartsWith('UPDATE')) { return $false } }
            'Delete' { if (-not $queryUpper.StartsWith('DELETE')) { return $false } }
            'Pragma' { if (-not $queryUpper.StartsWith('PRAGMA')) { return $false } }
        }
        
        return $true
        
    } catch {
        Write-LogError "Query safety validation failed: $($_.Exception.Message)" "DATABASE"
        return $false
    }
}

#endregion

#region Anti-Detection Database Operations

function Clear-AugmentDatabaseTraces {
    <#
    .SYNOPSIS
        Removes Augment-related traces from database
    .DESCRIPTION
        Safely removes Augment data while preserving database integrity
    .PARAMETER DatabasePath
        Path to the database file
    .PARAMETER PreservePlugin
        Preserve plugin functionality data
    .OUTPUTS
        [hashtable] Cleanup results
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,
        
        [switch]$PreservePlugin = $false
    )
    
    try {
        $cleanupResults = @{
            RemovedRecords = 0
            PreservedRecords = 0
            Errors = @()
        }
        
        # Define cleanup queries based on preservation mode
        if ($PreservePlugin) {
            $cleanupQueries = @(
                "DELETE FROM ItemTable WHERE key LIKE '%augment%' AND key NOT LIKE '%augment.vscode-augment%';",
                "DELETE FROM ItemTable WHERE key LIKE '%trial%';",
                "DELETE FROM ItemTable WHERE key LIKE 'secret://%augment%';"
            )
        } else {
            $cleanupQueries = @(
                "DELETE FROM ItemTable WHERE key LIKE '%augment%';",
                "DELETE FROM ItemTable WHERE key LIKE '%trial%';",
                "DELETE FROM ItemTable WHERE key LIKE 'secret://%augment%';",
                "DELETE FROM ItemTable WHERE key LIKE 'Augment.%';",
                "DELETE FROM ItemTable WHERE key LIKE 'workbench.view.extension.augment%';"
            )
        }
        
        foreach ($query in $cleanupQueries) {
            try {
                $result = Invoke-SafeDatabaseQuery -DatabasePath $DatabasePath -Query $query -QueryType "Delete" -CreateBackup:$false
                $cleanupResults.RemovedRecords++
            } catch {
                $cleanupResults.Errors += "Query failed: $query - $($_.Exception.Message)"
            }
        }
        
        Write-LogSuccess "Database cleanup completed: $($cleanupResults.RemovedRecords) operations" "DATABASE"
        return $cleanupResults
        
    } catch {
        Write-LogError "Database cleanup failed: $($_.Exception.Message)" "DATABASE"
        throw
    }
}

#endregion

# Export functions when dot-sourced
Write-LogInfo "Database Operations Module v1.0.0 loaded successfully" "DATABASE"
