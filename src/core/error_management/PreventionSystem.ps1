# PreventionSystem.ps1
# Error Prevention and Monitoring System
# Version: 1.0.0 - Proactive error prevention and system monitoring

# Prevent multiple inclusions
if ($Global:PreventionSystemLoaded) {
    return
}
$Global:PreventionSystemLoaded = $true

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

$Global:PreventionConfig = @{
    MonitoringEnabled = $true
    MonitoringInterval = 300  # 5 minutes
    PreventiveChecksEnabled = $true
    AutoMaintenanceEnabled = $true
    RiskThresholds = @{
        Critical = 1
        High = 3
        Medium = 10
        Low = 20
    }
    MaintenanceSchedule = @{
        DatabaseOptimization = 86400  # 24 hours
        ConfigValidation = 3600       # 1 hour
        ConsistencyCheck = 7200       # 2 hours
    }
}

#endregion

#region Core Prevention Functions

function Start-PreventionSystem {
    <#
    .SYNOPSIS
        Start the error prevention system
    .DESCRIPTION
        Initializes and starts the comprehensive error prevention system
    .PARAMETER Installations
        Array of VS Code/Cursor installations to monitor
    .PARAMETER EnableRealTimeMonitoring
        Enable real-time monitoring
    .PARAMETER EnableAutoMaintenance
        Enable automatic maintenance tasks
    .OUTPUTS
        [hashtable] Prevention system status
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Installations,
        
        [Parameter(Mandatory = $false)]
        [switch]$EnableRealTimeMonitoring = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$EnableAutoMaintenance = $true
    )
    
    Write-LogInfo "Starting Error Prevention System" "PREVENTION_SYSTEM"
    
    $preventionStatus = @{
        SystemId = [System.Guid]::NewGuid().ToString()
        StartTime = Get-Date
        Installations = $Installations
        MonitoringEnabled = $EnableRealTimeMonitoring
        MaintenanceEnabled = $EnableAutoMaintenance
        PreventiveChecks = @()
        MaintenanceTasks = @()
        RiskAssessments = @()
        Status = "INITIALIZING"
    }
    
    try {
        # Initialize preventive checks
        Write-LogInfo "Initializing preventive checks..." "PREVENTION_SYSTEM"
        $preventionStatus.PreventiveChecks = Initialize-PreventiveChecks -Installations $Installations
        
        # Initialize maintenance tasks
        if ($EnableAutoMaintenance) {
            Write-LogInfo "Initializing maintenance tasks..." "PREVENTION_SYSTEM"
            $preventionStatus.MaintenanceTasks = Initialize-MaintenanceTasks -Installations $Installations
        }
        
        # Perform initial risk assessment
        Write-LogInfo "Performing initial risk assessment..." "PREVENTION_SYSTEM"
        $preventionStatus.RiskAssessments = Invoke-RiskAssessment -Installations $Installations
        
        # Start monitoring if enabled
        if ($EnableRealTimeMonitoring) {
            Write-LogInfo "Starting real-time monitoring..." "PREVENTION_SYSTEM"
            Start-RealTimeMonitoring -Installations $Installations
        }
        
        $preventionStatus.Status = "ACTIVE"
        Write-LogSuccess "Error Prevention System started successfully" "PREVENTION_SYSTEM"
        
        return $preventionStatus
        
    } catch {
        Write-LogError "Failed to start Prevention System: $($_.Exception.Message)" "PREVENTION_SYSTEM"
        $preventionStatus.Status = "FAILED"
        $preventionStatus.Error = $_.Exception.Message
        return $preventionStatus
    }
}

function Initialize-PreventiveChecks {
    <#
    .SYNOPSIS
        Initialize preventive check routines
    .DESCRIPTION
        Sets up preventive checks to catch issues before they become errors
    .PARAMETER Installations
        Array of installations to monitor
    .OUTPUTS
        [array] Array of preventive check definitions
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Installations
    )
    
    $preventiveChecks = @()
    
    # Database integrity checks
    $preventiveChecks += @{
        Id = [System.Guid]::NewGuid().ToString()
        Name = "Database Integrity Check"
        Description = "Verify SQLite database integrity and structure"
        Frequency = 3600  # 1 hour
        LastRun = $null
        NextRun = (Get-Date).AddHours(1)
        CheckFunction = "Test-DatabaseIntegrity"
        Priority = "HIGH"
        Enabled = $true
    }
    
    # Configuration validation checks
    $preventiveChecks += @{
        Id = [System.Guid]::NewGuid().ToString()
        Name = "Configuration Validation"
        Description = "Validate JSON configuration files"
        Frequency = 1800  # 30 minutes
        LastRun = $null
        NextRun = (Get-Date).AddMinutes(30)
        CheckFunction = "Test-ConfigurationValidity"
        Priority = "MEDIUM"
        Enabled = $true
    }
    
    # Telemetry consistency checks
    $preventiveChecks += @{
        Id = [System.Guid]::NewGuid().ToString()
        Name = "Telemetry Consistency Check"
        Description = "Verify telemetry data consistency"
        Frequency = 7200  # 2 hours
        LastRun = $null
        NextRun = (Get-Date).AddHours(2)
        CheckFunction = "Test-TelemetryConsistency"
        Priority = "HIGH"
        Enabled = $true
    }
    
    # File permission checks
    $preventiveChecks += @{
        Id = [System.Guid]::NewGuid().ToString()
        Name = "File Permission Check"
        Description = "Verify file and directory permissions"
        Frequency = 14400  # 4 hours
        LastRun = $null
        NextRun = (Get-Date).AddHours(4)
        CheckFunction = "Test-FilePermissions"
        Priority = "MEDIUM"
        Enabled = $true
    }
    
    Write-LogInfo "Initialized $($preventiveChecks.Count) preventive checks" "PREVENTION_SYSTEM"
    return $preventiveChecks
}

function Initialize-MaintenanceTasks {
    <#
    .SYNOPSIS
        Initialize automatic maintenance tasks
    .DESCRIPTION
        Sets up automatic maintenance routines to prevent issues
    .PARAMETER Installations
        Array of installations to maintain
    .OUTPUTS
        [array] Array of maintenance task definitions
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Installations
    )
    
    $maintenanceTasks = @()
    
    # Database optimization
    $maintenanceTasks += @{
        Id = [System.Guid]::NewGuid().ToString()
        Name = "Database Optimization"
        Description = "Optimize SQLite databases for performance"
        Frequency = 86400  # 24 hours
        LastRun = $null
        NextRun = (Get-Date).AddHours(24)
        TaskFunction = "Invoke-DatabaseOptimization"
        Priority = "LOW"
        Enabled = $true
    }
    
    # Configuration cleanup
    $maintenanceTasks += @{
        Id = [System.Guid]::NewGuid().ToString()
        Name = "Configuration Cleanup"
        Description = "Clean up obsolete configuration entries"
        Frequency = 604800  # 7 days
        LastRun = $null
        NextRun = (Get-Date).AddDays(7)
        TaskFunction = "Invoke-ConfigurationCleanup"
        Priority = "LOW"
        Enabled = $true
    }
    
    # Backup management
    $maintenanceTasks += @{
        Id = [System.Guid]::NewGuid().ToString()
        Name = "Backup Management"
        Description = "Manage and rotate backup files"
        Frequency = 259200  # 3 days
        LastRun = $null
        NextRun = (Get-Date).AddDays(3)
        TaskFunction = "Invoke-BackupManagement"
        Priority = "MEDIUM"
        Enabled = $true
    }
    
    Write-LogInfo "Initialized $($maintenanceTasks.Count) maintenance tasks" "PREVENTION_SYSTEM"
    return $maintenanceTasks
}

function Invoke-RiskAssessment {
    <#
    .SYNOPSIS
        Perform comprehensive risk assessment
    .DESCRIPTION
        Analyzes system state and identifies potential risk factors
    .PARAMETER Installations
        Array of installations to assess
    .OUTPUTS
        [array] Array of risk assessment results
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Installations
    )
    
    $riskAssessments = @()
    
    foreach ($installation in $Installations) {
        Write-LogInfo "Performing risk assessment for: $($installation.Type)" "PREVENTION_SYSTEM"
        
        $assessment = @{
            InstallationId = $installation.Path
            InstallationType = $installation.Type
            AssessmentTime = Get-Date
            RiskFactors = @()
            OverallRisk = "LOW"
            Recommendations = @()
        }
        
        # Assess database risks
        foreach ($dbFile in $installation.DatabaseFiles) {
            $dbRisk = Assess-DatabaseRisk -DatabasePath $dbFile
            if ($dbRisk.RiskLevel -ne "NONE") {
                $assessment.RiskFactors += $dbRisk
            }
        }
        
        # Assess configuration risks
        foreach ($configFile in $installation.StorageFiles) {
            $configRisk = Assess-ConfigurationRisk -ConfigPath $configFile
            if ($configRisk.RiskLevel -ne "NONE") {
                $assessment.RiskFactors += $configRisk
            }
        }
        
        # Calculate overall risk
        $assessment.OverallRisk = Calculate-OverallRisk -RiskFactors $assessment.RiskFactors
        
        # Generate recommendations
        $assessment.Recommendations = Generate-RiskRecommendations -RiskFactors $assessment.RiskFactors
        
        $riskAssessments += $assessment
    }
    
    Write-LogInfo "Completed risk assessment for $($Installations.Count) installations" "PREVENTION_SYSTEM"
    return $riskAssessments
}

#endregion

#region Risk Assessment Functions

function Assess-DatabaseRisk {
    <#
    .SYNOPSIS
        Assess database-specific risks
    .DESCRIPTION
        Evaluates potential risks in SQLite database files
    .PARAMETER DatabasePath
        Path to database file
    .OUTPUTS
        [hashtable] Database risk assessment
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath
    )

    $risk = @{
        Source = $DatabasePath
        Type = "DATABASE"
        RiskLevel = "NONE"
        Issues = @()
        Recommendations = @()
    }

    try {
        if (-not (Test-PathSafely $DatabasePath -PathType "File")) {
            $risk.RiskLevel = "CRITICAL"
            $risk.Issues += "Database file missing or inaccessible"
            $risk.Recommendations += "Recreate database file"
            return $risk
        }

        # Check file size
        $fileInfo = Get-Item $DatabasePath
        if ($fileInfo.Length -eq 0) {
            $risk.RiskLevel = "HIGH"
            $risk.Issues += "Database file is empty"
            $risk.Recommendations += "Restore from backup or recreate"
        }

        # Check database integrity
        $integrityResult = Invoke-SQLiteQuerySafely -DatabasePath $DatabasePath -Query "PRAGMA integrity_check;" -QueryType "Pragma"
        if ($integrityResult -ne "ok") {
            $risk.RiskLevel = "HIGH"
            $risk.Issues += "Database integrity check failed"
            $risk.Recommendations += "Repair or restore database"
        }

        # Check for required telemetry keys
        $requiredKeys = @('telemetry.machineId', 'telemetry.devDeviceId', 'telemetry.sqmId')
        foreach ($key in $requiredKeys) {
            $value = Invoke-SQLiteQuerySafely -DatabasePath $DatabasePath -Query "SELECT value FROM ItemTable WHERE key = '$key';" -QueryType "Select"
            if (-not $value) {
                if ($risk.RiskLevel -eq "NONE") { $risk.RiskLevel = "MEDIUM" }
                $risk.Issues += "Missing telemetry key: $key"
                $risk.Recommendations += "Generate and insert missing telemetry data"
            }
        }

    } catch {
        $risk.RiskLevel = "HIGH"
        $risk.Issues += "Database access error: $($_.Exception.Message)"
        $risk.Recommendations += "Check file permissions and database integrity"
    }

    return $risk
}

function Assess-ConfigurationRisk {
    <#
    .SYNOPSIS
        Assess configuration file risks
    .DESCRIPTION
        Evaluates potential risks in JSON configuration files
    .PARAMETER ConfigPath
        Path to configuration file
    .OUTPUTS
        [hashtable] Configuration risk assessment
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    $risk = @{
        Source = $ConfigPath
        Type = "CONFIGURATION"
        RiskLevel = "NONE"
        Issues = @()
        Recommendations = @()
    }

    try {
        if (-not (Test-PathSafely $ConfigPath -PathType "File")) {
            $risk.RiskLevel = "MEDIUM"
            $risk.Issues += "Configuration file missing"
            $risk.Recommendations += "Create default configuration file"
            return $risk
        }

        # Check file size
        $fileInfo = Get-Item $ConfigPath
        if ($fileInfo.Length -le 2) {
            $risk.RiskLevel = "MEDIUM"
            $risk.Issues += "Configuration file is empty or too small"
            $risk.Recommendations += "Restore or recreate configuration"
        }

        # Validate JSON format
        try {
            $content = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            $risk.RiskLevel = "HIGH"
            $risk.Issues += "Invalid JSON format"
            $risk.Recommendations += "Repair JSON syntax or restore from backup"
            return $risk
        }

        # Check for required telemetry properties
        $requiredProps = @('telemetry.machineId', 'telemetry.devDeviceId', 'telemetry.sqmId')
        foreach ($prop in $requiredProps) {
            if (-not ($content.PSObject.Properties.Name -contains $prop) -or -not $content.$prop) {
                if ($risk.RiskLevel -eq "NONE") { $risk.RiskLevel = "MEDIUM" }
                $risk.Issues += "Missing or empty telemetry property: $prop"
                $risk.Recommendations += "Generate and add missing telemetry data"
            }
        }

    } catch {
        $risk.RiskLevel = "HIGH"
        $risk.Issues += "Configuration access error: $($_.Exception.Message)"
        $risk.Recommendations += "Check file permissions and format"
    }

    return $risk
}

function Calculate-OverallRisk {
    <#
    .SYNOPSIS
        Calculate overall risk level
    .DESCRIPTION
        Determines overall risk based on individual risk factors
    .PARAMETER RiskFactors
        Array of individual risk assessments
    .OUTPUTS
        [string] Overall risk level
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$RiskFactors
    )

    if ($RiskFactors.Count -eq 0) {
        return "NONE"
    }

    $riskCounts = @{
        CRITICAL = ($RiskFactors | Where-Object { $_.RiskLevel -eq "CRITICAL" }).Count
        HIGH = ($RiskFactors | Where-Object { $_.RiskLevel -eq "HIGH" }).Count
        MEDIUM = ($RiskFactors | Where-Object { $_.RiskLevel -eq "MEDIUM" }).Count
        LOW = ($RiskFactors | Where-Object { $_.RiskLevel -eq "LOW" }).Count
    }

    if ($riskCounts.CRITICAL -gt 0) {
        return "CRITICAL"
    } elseif ($riskCounts.HIGH -gt 0) {
        return "HIGH"
    } elseif ($riskCounts.MEDIUM -gt 2) {
        return "HIGH"
    } elseif ($riskCounts.MEDIUM -gt 0) {
        return "MEDIUM"
    } elseif ($riskCounts.LOW -gt 5) {
        return "MEDIUM"
    } elseif ($riskCounts.LOW -gt 0) {
        return "LOW"
    } else {
        return "NONE"
    }
}

function Generate-RiskRecommendations {
    <#
    .SYNOPSIS
        Generate recommendations based on risk factors
    .DESCRIPTION
        Creates actionable recommendations to mitigate identified risks
    .PARAMETER RiskFactors
        Array of risk factors
    .OUTPUTS
        [array] Array of recommendations
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$RiskFactors
    )

    $recommendations = @()

    # Group recommendations by type
    $allRecommendations = $RiskFactors | ForEach-Object { $_.Recommendations } | Sort-Object -Unique

    foreach ($recommendation in $allRecommendations) {
        $affectedSources = ($RiskFactors | Where-Object { $_.Recommendations -contains $recommendation }).Source

        $recommendations += @{
            Action = $recommendation
            Priority = "MEDIUM"  # Default priority
            AffectedSources = $affectedSources
            EstimatedTime = 10   # Default time in minutes
        }
    }

    return $recommendations
}

#endregion

# Export functions when loaded as module
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    Write-Verbose "Prevention System loaded via dot-sourcing"
} else {
    Export-ModuleMember -Function @(
        'Start-PreventionSystem',
        'Initialize-PreventiveChecks',
        'Initialize-MaintenanceTasks',
        'Invoke-RiskAssessment',
        'Assess-DatabaseRisk',
        'Assess-ConfigurationRisk'
    )
}

Write-LogInfo "Prevention System initialized successfully" "PREVENTION_SYSTEM"
