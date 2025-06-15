# AutoErrorDetector.ps1
# Intelligent Error Detection Engine
# Version: 1.0.0 - Comprehensive automatic error detection system

# Prevent multiple inclusions
if ($Global:AutoErrorDetectorLoaded) {
    return
}
$Global:AutoErrorDetectorLoaded = $true

# Error handling
$ErrorActionPreference = "Stop"

# Load required modules
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreRoot = Split-Path -Parent $scriptRoot

# Load dependencies
. (Join-Path $coreRoot "AugmentLogger.ps1")
. (Join-Path $coreRoot "utilities\common_utilities.ps1")
. (Join-Path $scriptRoot "ErrorTypes.ps1")

#region Configuration

$Global:DetectorConfig = @{
    ScanDepth = "DEEP"
    TimeoutSeconds = 300
    MaxConcurrentScans = 4
    EnableRealTimeMonitoring = $false
    DetectionThresholds = @{
        CriticalErrors = 1
        HighPriorityErrors = 3
        MediumPriorityErrors = 10
    }
    ScanPatterns = @{
        DatabaseFiles = @("*.vscdb", "*.db", "*.sqlite")
        ConfigFiles = @("storage.json", "*.json")
        LogFiles = @("*.log", "*.txt")
    }
}

#endregion

#region Core Detection Functions

function Start-AutoErrorDetection {
    <#
    .SYNOPSIS
        Start comprehensive error detection scan
    .DESCRIPTION
        Performs deep scan of VS Code/Cursor installations to detect all types of errors
    .PARAMETER Installations
        Array of installation objects to scan
    .PARAMETER ScanType
        Type of scan: QUICK, STANDARD, DEEP, COMPREHENSIVE
    .PARAMETER OutputPath
        Path to save detection results
    .OUTPUTS
        [hashtable] Detection results with error details
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Installations,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("QUICK", "STANDARD", "DEEP", "COMPREHENSIVE")]
        [string]$ScanType = "DEEP",
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = ""
    )
    
    Write-LogInfo "Starting Auto Error Detection - Scan Type: $ScanType" "AUTO_DETECTOR"
    
    $detectionResults = @{
        ScanId = [System.Guid]::NewGuid().ToString()
        StartTime = Get-Date
        ScanType = $ScanType
        Installations = @()
        ErrorsSummary = @{
            Critical = 0
            High = 0
            Medium = 0
            Low = 0
            Total = 0
        }
        DetectedErrors = @()
        Recommendations = @()
        ScanDuration = 0
        Status = "RUNNING"
    }
    
    try {
        foreach ($installation in $Installations) {
            Write-LogInfo "Scanning installation: $($installation.Type) at $($installation.Path)" "AUTO_DETECTOR"
            
            $installationScan = Invoke-InstallationScan -Installation $installation -ScanType $ScanType
            $detectionResults.Installations += $installationScan
            
            # Aggregate errors
            foreach ($error in $installationScan.Errors) {
                $detectionResults.DetectedErrors += $error
                
                switch ($error.Priority) {
                    "CRITICAL" { $detectionResults.ErrorsSummary.Critical++ }
                    "HIGH" { $detectionResults.ErrorsSummary.High++ }
                    "MEDIUM" { $detectionResults.ErrorsSummary.Medium++ }
                    "LOW" { $detectionResults.ErrorsSummary.Low++ }
                }
                $detectionResults.ErrorsSummary.Total++
            }
        }
        
        # Generate recommendations
        $detectionResults.Recommendations = New-ErrorRecommendations -DetectedErrors $detectionResults.DetectedErrors
        
        $detectionResults.Status = "COMPLETED"
        $detectionResults.ScanDuration = ((Get-Date) - $detectionResults.StartTime).TotalSeconds
        
        Write-LogSuccess "Error detection completed. Found $($detectionResults.ErrorsSummary.Total) errors" "AUTO_DETECTOR"
        
        # Save results if output path specified
        if ($OutputPath) {
            Export-DetectionResults -Results $detectionResults -OutputPath $OutputPath
        }
        
        return $detectionResults
        
    } catch {
        Write-LogError "Error detection failed: $($_.Exception.Message)" "AUTO_DETECTOR"
        $detectionResults.Status = "FAILED"
        $detectionResults.Error = $_.Exception.Message
        return $detectionResults
    }
}

function Invoke-InstallationScan {
    <#
    .SYNOPSIS
        Scan individual installation for errors
    .DESCRIPTION
        Performs detailed scan of single VS Code/Cursor installation
    .PARAMETER Installation
        Installation object to scan
    .PARAMETER ScanType
        Type of scan to perform
    .OUTPUTS
        [hashtable] Installation scan results
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Installation,
        
        [Parameter(Mandatory = $false)]
        [string]$ScanType = "DEEP"
    )
    
    $scanResult = @{
        Installation = $Installation
        ScanTime = Get-Date
        DatabaseScans = @()
        ConfigScans = @()
        Errors = @()
        Warnings = @()
        Status = "SCANNING"
    }
    
    try {
        # Scan database files
        foreach ($dbFile in $Installation.DatabaseFiles) {
            if (Test-PathSafely $dbFile -PathType "File") {
                $dbScan = Invoke-DatabaseScan -DatabasePath $dbFile -ScanType $ScanType
                $scanResult.DatabaseScans += $dbScan
                $scanResult.Errors += $dbScan.Errors
                $scanResult.Warnings += $dbScan.Warnings
            } else {
                $missingDbError = New-ErrorObject -Type "DB_CONNECTION_FAILED" -Source $dbFile -Message "Database file missing: $dbFile"
                $scanResult.Errors += $missingDbError
            }
        }
        
        # Scan configuration files
        foreach ($configFile in $Installation.StorageFiles) {
            if (Test-PathSafely $configFile -PathType "File") {
                $configScan = Invoke-ConfigScan -ConfigPath $configFile -ScanType $ScanType
                $scanResult.ConfigScans += $configScan
                $scanResult.Errors += $configScan.Errors
                $scanResult.Warnings += $configScan.Warnings
            } else {
                $missingConfigError = New-ErrorObject -Type "CFG_MISSING_FILE" -Source $configFile -Message "Configuration file missing: $configFile"
                $scanResult.Errors += $missingConfigError
            }
        }
        
        # Perform consistency checks
        $consistencyCheck = Invoke-ConsistencyCheck -Installation $Installation -DatabaseScans $scanResult.DatabaseScans -ConfigScans $scanResult.ConfigScans
        $scanResult.Errors += $consistencyCheck.Errors
        $scanResult.Warnings += $consistencyCheck.Warnings
        
        $scanResult.Status = "COMPLETED"
        
    } catch {
        Write-LogError "Installation scan failed for $($Installation.Path): $($_.Exception.Message)" "AUTO_DETECTOR"
        $scanResult.Status = "FAILED"
        $scanResult.Error = $_.Exception.Message
    }
    
    return $scanResult
}

function Invoke-DatabaseScan {
    <#
    .SYNOPSIS
        Scan database file for errors
    .DESCRIPTION
        Performs comprehensive scan of SQLite database file
    .PARAMETER DatabasePath
        Path to database file
    .PARAMETER ScanType
        Type of scan to perform
    .OUTPUTS
        [hashtable] Database scan results
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,
        
        [Parameter(Mandatory = $false)]
        [string]$ScanType = "DEEP"
    )
    
    $scanResult = @{
        DatabasePath = $DatabasePath
        ScanTime = Get-Date
        Errors = @()
        Warnings = @()
        TelemetryData = @{}
        RecordCount = 0
        Status = "SCANNING"
    }
    
    try {
        # Test database connectivity
        $testQuery = "SELECT COUNT(*) FROM ItemTable;"
        $result = Invoke-SQLiteQuerySafely -DatabasePath $DatabasePath -Query $testQuery -QueryType "Select" -TimeoutSeconds 10
        
        if ($result) {
            $scanResult.RecordCount = [int]$result
        } else {
            $dbError = New-ErrorObject -Type "DB_NULL_RESULT" -Source $DatabasePath -Message "Database query returned null result"
            $scanResult.Errors += $dbError
        }
        
        # Scan telemetry data
        $telemetryKeys = @('telemetry.machineId', 'telemetry.devDeviceId', 'telemetry.sqmId', 'storage.serviceMachineId')
        
        foreach ($key in $telemetryKeys) {
            try {
                $value = Invoke-SQLiteQuerySafely -DatabasePath $DatabasePath -Query "SELECT value FROM ItemTable WHERE key = '$key';" -QueryType "Select"
                
                if ($value) {
                    $scanResult.TelemetryData[$key] = $value.Trim()
                } else {
                    $nullError = New-ErrorObject -Type "NULL_MACHINE_ID" -Source $DatabasePath -Message "Null value for key: $key"
                    $scanResult.Errors += $nullError
                }
            } catch {
                $queryError = New-ErrorObject -Type "DB_NULL_RESULT" -Source $DatabasePath -Message "Failed to query key $key : $($_.Exception.Message)"
                $scanResult.Errors += $queryError
            }
        }
        
        $scanResult.Status = "COMPLETED"
        
    } catch {
        Write-LogError "Database scan failed for $DatabasePath : $($_.Exception.Message)" "AUTO_DETECTOR"
        $dbError = New-ErrorObject -Type "DB_CONNECTION_FAILED" -Source $DatabasePath -Message $_.Exception.Message
        $scanResult.Errors += $dbError
        $scanResult.Status = "FAILED"
    }
    
    return $scanResult
}

function Invoke-ConfigScan {
    <#
    .SYNOPSIS
        Scan configuration file for errors
    .DESCRIPTION
        Performs comprehensive scan of JSON configuration file
    .PARAMETER ConfigPath
        Path to configuration file
    .PARAMETER ScanType
        Type of scan to perform
    .OUTPUTS
        [hashtable] Configuration scan results
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $false)]
        [string]$ScanType = "DEEP"
    )
    
    $scanResult = @{
        ConfigPath = $ConfigPath
        ScanTime = Get-Date
        Errors = @()
        Warnings = @()
        TelemetryData = @{}
        Status = "SCANNING"
    }
    
    try {
        # Test file accessibility
        if (-not (Test-PathSafely $ConfigPath -PathType "File")) {
            $fileError = New-ErrorObject -Type "CFG_MISSING_FILE" -Source $ConfigPath -Message "Configuration file not accessible"
            $scanResult.Errors += $fileError
            $scanResult.Status = "FAILED"
            return $scanResult
        }
        
        # Test JSON validity
        try {
            $content = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            $jsonError = New-ErrorObject -Type "CFG_INVALID_JSON" -Source $ConfigPath -Message "Invalid JSON format: $($_.Exception.Message)"
            $scanResult.Errors += $jsonError
            $scanResult.Status = "FAILED"
            return $scanResult
        }
        
        # Scan telemetry data
        $telemetryKeys = @('telemetry.machineId', 'telemetry.devDeviceId', 'telemetry.sqmId')
        
        foreach ($key in $telemetryKeys) {
            if ($content.PSObject.Properties.Name -contains $key) {
                $value = $content.$key
                if ($value) {
                    $scanResult.TelemetryData[$key] = $value
                } else {
                    $nullError = New-ErrorObject -Type "NULL_DEVICE_ID" -Source $ConfigPath -Message "Null value for key: $key"
                    $scanResult.Errors += $nullError
                }
            }
        }
        
        $scanResult.Status = "COMPLETED"
        
    } catch {
        Write-LogError "Config scan failed for $ConfigPath : $($_.Exception.Message)" "AUTO_DETECTOR"
        $configError = New-ErrorObject -Type "CFG_MISSING_FILE" -Source $ConfigPath -Message $_.Exception.Message
        $scanResult.Errors += $configError
        $scanResult.Status = "FAILED"
    }
    
    return $scanResult
}

#endregion

#region Helper Functions

function Invoke-ConsistencyCheck {
    <#
    .SYNOPSIS
        Check data consistency between database and config files
    .DESCRIPTION
        Compares telemetry data between database and configuration files
    .PARAMETER Installation
        Installation object
    .PARAMETER DatabaseScans
        Database scan results
    .PARAMETER ConfigScans
        Configuration scan results
    .OUTPUTS
        [hashtable] Consistency check results
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Installation,

        [Parameter(Mandatory = $true)]
        [array]$DatabaseScans,

        [Parameter(Mandatory = $true)]
        [array]$ConfigScans
    )

    $consistencyResult = @{
        Errors = @()
        Warnings = @()
        Comparisons = @()
    }

    try {
        # Compare telemetry data between database and config files
        foreach ($dbScan in $DatabaseScans) {
            foreach ($configScan in $ConfigScans) {
                $comparison = Compare-TelemetryData -DatabaseData $dbScan.TelemetryData -ConfigData $configScan.TelemetryData -DatabasePath $dbScan.DatabasePath -ConfigPath $configScan.ConfigPath
                $consistencyResult.Comparisons += $comparison
                $consistencyResult.Errors += $comparison.Errors
                $consistencyResult.Warnings += $comparison.Warnings
            }
        }

    } catch {
        Write-LogError "Consistency check failed: $($_.Exception.Message)" "AUTO_DETECTOR"
        $consistencyError = New-ErrorObject -Type "CONS_TELEMETRY_MISMATCH" -Source $Installation.Path -Message $_.Exception.Message
        $consistencyResult.Errors += $consistencyError
    }

    return $consistencyResult
}

function Compare-TelemetryData {
    <#
    .SYNOPSIS
        Compare telemetry data between database and config
    .DESCRIPTION
        Detailed comparison of telemetry identifiers
    .PARAMETER DatabaseData
        Telemetry data from database
    .PARAMETER ConfigData
        Telemetry data from config
    .PARAMETER DatabasePath
        Database file path
    .PARAMETER ConfigPath
        Config file path
    .OUTPUTS
        [hashtable] Comparison results
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$DatabaseData,

        [Parameter(Mandatory = $true)]
        [hashtable]$ConfigData,

        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,

        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    $comparison = @{
        DatabasePath = $DatabasePath
        ConfigPath = $ConfigPath
        Errors = @()
        Warnings = @()
        Mismatches = @()
    }

    $keysToCompare = @('telemetry.machineId', 'telemetry.devDeviceId', 'telemetry.sqmId')

    foreach ($key in $keysToCompare) {
        $dbValue = $DatabaseData[$key]
        $configValue = $ConfigData[$key]

        if ($dbValue -and $configValue) {
            if ($dbValue -ne $configValue) {
                $mismatchError = New-ErrorObject -Type "CONS_TELEMETRY_MISMATCH" -Source "$DatabasePath vs $ConfigPath" -Message "Mismatch for $key : DB=$dbValue, Config=$configValue"
                $comparison.Errors += $mismatchError
                $comparison.Mismatches += @{
                    Key = $key
                    DatabaseValue = $dbValue
                    ConfigValue = $configValue
                }
            }
        } elseif (-not $dbValue -and $configValue) {
            $warning = New-WarningObject -Source $DatabasePath -Message "$key missing in database but present in config"
            $comparison.Warnings += $warning
        } elseif ($dbValue -and -not $configValue) {
            $warning = New-WarningObject -Source $ConfigPath -Message "$key missing in config but present in database"
            $comparison.Warnings += $warning
        }
    }

    return $comparison
}

function New-ErrorObject {
    <#
    .SYNOPSIS
        Create standardized error object
    .DESCRIPTION
        Creates error object with standard structure
    .PARAMETER Type
        Error type from ErrorTypes.ps1
    .PARAMETER Source
        Source file or location of error
    .PARAMETER Message
        Error message
    .OUTPUTS
        [hashtable] Standardized error object
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $errorType = $Global:ErrorTypes[$Type]
    if (-not $errorType) {
        $errorType = @{
            Category = "SYSTEM_ERROR"
            Code = "SYS999"
            Name = "Unknown Error"
            Priority = "MEDIUM"
            FixStrategy = "MANUAL_REVIEW"
        }
    }

    return @{
        Id = [System.Guid]::NewGuid().ToString()
        Type = $Type
        Category = $errorType.Category
        Code = $errorType.Code
        Name = $errorType.Name
        Priority = $errorType.Priority
        Source = $Source
        Message = $Message
        DetectedAt = Get-Date
        FixStrategy = $errorType.FixStrategy
        AutoFixable = (Test-ErrorAutoFixable -ErrorType $errorType)
    }
}

function New-WarningObject {
    <#
    .SYNOPSIS
        Create standardized warning object
    .DESCRIPTION
        Creates warning object with standard structure
    .PARAMETER Source
        Source file or location of warning
    .PARAMETER Message
        Warning message
    .OUTPUTS
        [hashtable] Standardized warning object
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    return @{
        Id = [System.Guid]::NewGuid().ToString()
        Type = "WARNING"
        Source = $Source
        Message = $Message
        DetectedAt = Get-Date
    }
}

function New-ErrorRecommendations {
    <#
    .SYNOPSIS
        Generate error fix recommendations
    .DESCRIPTION
        Analyzes detected errors and generates fix recommendations
    .PARAMETER DetectedErrors
        Array of detected error objects
    .OUTPUTS
        [array] Array of recommendation objects
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$DetectedErrors
    )

    $recommendations = @()

    # Group errors by fix strategy
    $errorGroups = $DetectedErrors | Group-Object -Property FixStrategy

    foreach ($group in $errorGroups) {
        $strategy = Get-FixStrategy -ErrorType @{ FixStrategy = $group.Name }
        if ($strategy) {
            $recommendation = @{
                Id = [System.Guid]::NewGuid().ToString()
                FixStrategy = $group.Name
                StrategyName = $strategy.Name
                Description = $strategy.Description
                AffectedErrors = $group.Group
                EstimatedTime = $strategy.EstimatedTime
                Priority = ($group.Group | Measure-Object -Property Priority -Maximum).Maximum
                RequiredModules = $strategy.RequiredModules
                Steps = $strategy.Steps
            }
            $recommendations += $recommendation
        }
    }

    # Sort by priority
    $priorityOrder = @{ "CRITICAL" = 4; "HIGH" = 3; "MEDIUM" = 2; "LOW" = 1 }
    $recommendations = $recommendations | Sort-Object { $priorityOrder[$_.Priority] } -Descending

    return $recommendations
}

function Export-DetectionResults {
    <#
    .SYNOPSIS
        Export detection results to file
    .DESCRIPTION
        Saves detection results in JSON format
    .PARAMETER Results
        Detection results object
    .PARAMETER OutputPath
        Output file path
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Results,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    try {
        $Results | ConvertTo-Json -Depth 10 | Set-Content $OutputPath -Encoding UTF8
        Write-LogSuccess "Detection results exported to: $OutputPath" "AUTO_DETECTOR"
    } catch {
        Write-LogError "Failed to export detection results: $($_.Exception.Message)" "AUTO_DETECTOR"
    }
}

#endregion

# Export functions when loaded as module
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    Write-Verbose "Auto Error Detector loaded via dot-sourcing"
} else {
    Export-ModuleMember -Function @(
        'Start-AutoErrorDetection',
        'Invoke-InstallationScan',
        'Invoke-DatabaseScan',
        'Invoke-ConfigScan',
        'New-ErrorObject',
        'Export-DetectionResults'
    )
}

Write-LogInfo "Auto Error Detector initialized successfully" "AUTO_DETECTOR"
