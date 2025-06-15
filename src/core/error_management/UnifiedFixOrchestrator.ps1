# UnifiedFixOrchestrator.ps1
# Unified Error Fix Orchestration System
# Version: 1.0.0 - Central coordination of all error management components

# Prevent multiple inclusions
if ($Global:UnifiedFixOrchestratorLoaded) {
    return
}
$Global:UnifiedFixOrchestratorLoaded = $true

# Error handling
$ErrorActionPreference = "Stop"

# Load required modules
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreRoot = Split-Path -Parent $scriptRoot

# Load dependencies
. (Join-Path $coreRoot "AugmentLogger.ps1")
. (Join-Path $coreRoot "utilities\common_utilities.ps1")
. (Join-Path $scriptRoot "ErrorTypes.ps1")
. (Join-Path $scriptRoot "AutoErrorDetector.ps1")
. (Join-Path $scriptRoot "ErrorFixEngine.ps1")
. (Join-Path $scriptRoot "PreventionSystem.ps1")

#region Configuration

$Global:OrchestratorConfig = @{
    MaxRetryAttempts = 3
    RetryDelaySeconds = 5
    EnableDetailedLogging = $true
    EnableProgressReporting = $true
    AutoBackupEnabled = $true
    SafetyChecksEnabled = $true
    ParallelProcessing = $false
    MaxParallelJobs = 4
}

#endregion

#region Core Orchestration Functions

function Start-UnifiedErrorFix {
    <#
    .SYNOPSIS
        Start unified error detection and fixing process
    .DESCRIPTION
        Orchestrates complete error management workflow: detection, analysis, fixing, and prevention
    .PARAMETER Installations
        Array of VS Code/Cursor installations to process
    .PARAMETER Operation
        Operation mode: DETECT_ONLY, FIX_ONLY, COMPLETE, PREVENT_ONLY
    .PARAMETER DryRun
        Run in dry-run mode without making changes
    .PARAMETER EnablePrevention
        Enable prevention system after fixing
    .OUTPUTS
        [hashtable] Complete operation results
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Installations,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("DETECT_ONLY", "FIX_ONLY", "COMPLETE", "PREVENT_ONLY")]
        [string]$Operation = "COMPLETE",
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$EnablePrevention = $true
    )
    
    Write-LogInfo "Starting Unified Error Fix - Operation: $Operation, DryRun: $DryRun" "ORCHESTRATOR"
    
    $orchestrationResult = @{
        OrchestrationId = [System.Guid]::NewGuid().ToString()
        StartTime = Get-Date
        Operation = $Operation
        DryRun = $DryRun
        Installations = $Installations
        DetectionResults = $null
        FixResults = $null
        PreventionResults = $null
        Summary = @{
            TotalErrors = 0
            ErrorsFixed = 0
            ErrorsFailed = 0
            SuccessRate = 0
            Duration = 0
        }
        Status = "RUNNING"
    }
    
    try {
        # Phase 1: Error Detection (unless FIX_ONLY mode)
        if ($Operation -ne "FIX_ONLY") {
            Write-LogInfo "Phase 1: Starting error detection..." "ORCHESTRATOR"
            $orchestrationResult.DetectionResults = Start-AutoErrorDetection -Installations $Installations -ScanType "COMPREHENSIVE"
            
            if ($orchestrationResult.DetectionResults.Status -ne "COMPLETED") {
                throw "Error detection phase failed: $($orchestrationResult.DetectionResults.Error)"
            }
            
            $orchestrationResult.Summary.TotalErrors = $orchestrationResult.DetectionResults.ErrorsSummary.Total
            Write-LogInfo "Detection completed: Found $($orchestrationResult.Summary.TotalErrors) errors" "ORCHESTRATOR"
            
            if ($Operation -eq "DETECT_ONLY") {
                $orchestrationResult.Status = "COMPLETED"
                $orchestrationResult.Summary.Duration = ((Get-Date) - $orchestrationResult.StartTime).TotalSeconds
                return $orchestrationResult
            }
        }
        
        # Phase 2: Error Fixing (unless DETECT_ONLY or PREVENT_ONLY)
        if ($Operation -ne "DETECT_ONLY" -and $Operation -ne "PREVENT_ONLY") {
            Write-LogInfo "Phase 2: Starting error fixing..." "ORCHESTRATOR"
            
            $errorsToFix = if ($orchestrationResult.DetectionResults) {
                $orchestrationResult.DetectionResults.DetectedErrors
            } else {
                # For FIX_ONLY mode, need to detect errors first
                $quickDetection = Start-AutoErrorDetection -Installations $Installations -ScanType "QUICK"
                $quickDetection.DetectedErrors
            }
            
            if ($errorsToFix.Count -gt 0) {
                $orchestrationResult.FixResults = Start-AutoErrorFix -DetectedErrors $errorsToFix -DryRun $DryRun
                
                if ($orchestrationResult.FixResults.Status -eq "COMPLETED") {
                    $orchestrationResult.Summary.ErrorsFixed = $orchestrationResult.FixResults.Summary.Fixed
                    $orchestrationResult.Summary.ErrorsFailed = $orchestrationResult.FixResults.Summary.Failed
                    $orchestrationResult.Summary.SuccessRate = $orchestrationResult.FixResults.Summary.SuccessRate
                    Write-LogSuccess "Fixing completed: Fixed $($orchestrationResult.Summary.ErrorsFixed) errors" "ORCHESTRATOR"
                } else {
                    Write-LogWarning "Error fixing completed with issues" "ORCHESTRATOR"
                }
            } else {
                Write-LogInfo "No errors found to fix" "ORCHESTRATOR"
                $orchestrationResult.Summary.SuccessRate = 100
            }
        }
        
        # Phase 3: Prevention System (if enabled and not DETECT_ONLY or FIX_ONLY)
        if ($EnablePrevention -and ($Operation -eq "COMPLETE" -or $Operation -eq "PREVENT_ONLY")) {
            Write-LogInfo "Phase 3: Starting prevention system..." "ORCHESTRATOR"
            $orchestrationResult.PreventionResults = Start-PreventionSystem -Installations $Installations -EnableRealTimeMonitoring:$false -EnableAutoMaintenance:$true
            
            if ($orchestrationResult.PreventionResults.Status -eq "ACTIVE") {
                Write-LogSuccess "Prevention system activated successfully" "ORCHESTRATOR"
            } else {
                Write-LogWarning "Prevention system activation had issues" "ORCHESTRATOR"
            }
        }
        
        # Final verification (for COMPLETE operations)
        if ($Operation -eq "COMPLETE" -and -not $DryRun) {
            Write-LogInfo "Phase 4: Final verification..." "ORCHESTRATOR"
            $verificationResult = Invoke-FinalVerification -Installations $Installations
            
            if ($verificationResult.OverallStatus -eq "SUCCESS") {
                Write-LogSuccess "Final verification passed" "ORCHESTRATOR"
            } else {
                Write-LogWarning "Final verification found remaining issues" "ORCHESTRATOR"
            }
        }
        
        $orchestrationResult.Status = "COMPLETED"
        $orchestrationResult.Summary.Duration = ((Get-Date) - $orchestrationResult.StartTime).TotalSeconds
        
        # Generate summary report
        Write-OrchestrationSummary -Results $orchestrationResult
        
        return $orchestrationResult
        
    } catch {
        Write-LogError "Unified error fix failed: $($_.Exception.Message)" "ORCHESTRATOR"
        $orchestrationResult.Status = "FAILED"
        $orchestrationResult.Error = $_.Exception.Message
        $orchestrationResult.Summary.Duration = ((Get-Date) - $orchestrationResult.StartTime).TotalSeconds
        return $orchestrationResult
    }
}

function Invoke-FinalVerification {
    <#
    .SYNOPSIS
        Perform final verification of fixes
    .DESCRIPTION
        Verifies that all fixes were applied correctly and no new issues exist
    .PARAMETER Installations
        Array of installations to verify
    .OUTPUTS
        [hashtable] Verification results
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Installations
    )
    
    Write-LogInfo "Starting final verification..." "ORCHESTRATOR"
    
    $verificationResult = @{
        VerificationId = [System.Guid]::NewGuid().ToString()
        StartTime = Get-Date
        Installations = @()
        RemainingIssues = @()
        OverallStatus = "SUCCESS"
        Duration = 0
    }
    
    try {
        foreach ($installation in $Installations) {
            Write-LogInfo "Verifying installation: $($installation.Type)" "ORCHESTRATOR"
            
            $installationVerification = @{
                Installation = $installation
                DatabaseVerifications = @()
                ConfigVerifications = @()
                ConsistencyCheck = $null
                Status = "VERIFYING"
            }
            
            # Verify databases
            foreach ($dbFile in $installation.DatabaseFiles) {
                if (Test-PathSafely $dbFile -PathType "File") {
                    $dbVerification = Test-DatabaseIntegrity -DatabasePath $dbFile
                    $installationVerification.DatabaseVerifications += $dbVerification
                    
                    if ($dbVerification.HasIssues) {
                        $verificationResult.RemainingIssues += $dbVerification.Issues
                    }
                }
            }
            
            # Verify configurations
            foreach ($configFile in $installation.StorageFiles) {
                if (Test-PathSafely $configFile -PathType "File") {
                    $configVerification = Test-ConfigurationIntegrity -ConfigPath $configFile
                    $installationVerification.ConfigVerifications += $configVerification
                    
                    if ($configVerification.HasIssues) {
                        $verificationResult.RemainingIssues += $configVerification.Issues
                    }
                }
            }
            
            # Verify consistency
            $consistencyCheck = Test-InstallationConsistency -Installation $installation
            $installationVerification.ConsistencyCheck = $consistencyCheck
            
            if ($consistencyCheck.HasIssues) {
                $verificationResult.RemainingIssues += $consistencyCheck.Issues
            }
            
            $installationVerification.Status = "COMPLETED"
            $verificationResult.Installations += $installationVerification
        }
        
        # Determine overall status
        if ($verificationResult.RemainingIssues.Count -gt 0) {
            $verificationResult.OverallStatus = "ISSUES_FOUND"
            Write-LogWarning "Final verification found $($verificationResult.RemainingIssues.Count) remaining issues" "ORCHESTRATOR"
        } else {
            $verificationResult.OverallStatus = "SUCCESS"
            Write-LogSuccess "Final verification passed - no issues found" "ORCHESTRATOR"
        }
        
        $verificationResult.Duration = ((Get-Date) - $verificationResult.StartTime).TotalSeconds
        
    } catch {
        Write-LogError "Final verification failed: $($_.Exception.Message)" "ORCHESTRATOR"
        $verificationResult.OverallStatus = "FAILED"
        $verificationResult.Error = $_.Exception.Message
    }
    
    return $verificationResult
}

#endregion

#region Verification Functions

function Test-DatabaseIntegrity {
    <#
    .SYNOPSIS
        Test database integrity
    .DESCRIPTION
        Performs comprehensive database integrity verification
    .PARAMETER DatabasePath
        Path to database file
    .OUTPUTS
        [hashtable] Database integrity results
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath
    )

    $verification = @{
        DatabasePath = $DatabasePath
        HasIssues = $false
        Issues = @()
        Checks = @()
    }

    try {
        # Check file existence and accessibility
        if (-not (Test-PathSafely $DatabasePath -PathType "File")) {
            $verification.HasIssues = $true
            $verification.Issues += "Database file not accessible: $DatabasePath"
            return $verification
        }

        # SQLite integrity check
        $integrityResult = Invoke-SQLiteQuerySafely -DatabasePath $DatabasePath -Query "PRAGMA integrity_check;" -QueryType "Pragma"
        $verification.Checks += @{
            Name = "SQLite Integrity Check"
            Result = $integrityResult
            Status = if ($integrityResult -eq "ok") { "PASS" } else { "FAIL" }
        }

        if ($integrityResult -ne "ok") {
            $verification.HasIssues = $true
            $verification.Issues += "Database integrity check failed: $integrityResult"
        }

        # Check for required telemetry keys
        $requiredKeys = @('telemetry.machineId', 'telemetry.devDeviceId', 'telemetry.sqmId')
        foreach ($key in $requiredKeys) {
            $value = Invoke-SQLiteQuerySafely -DatabasePath $DatabasePath -Query "SELECT value FROM ItemTable WHERE key = '$key';" -QueryType "Select"
            $verification.Checks += @{
                Name = "Telemetry Key: $key"
                Result = if ($value) { "Present" } else { "Missing" }
                Status = if ($value) { "PASS" } else { "FAIL" }
            }

            if (-not $value) {
                $verification.HasIssues = $true
                $verification.Issues += "Missing required telemetry key: $key"
            }
        }

    } catch {
        $verification.HasIssues = $true
        $verification.Issues += "Database verification error: $($_.Exception.Message)"
    }

    return $verification
}

function Test-ConfigurationIntegrity {
    <#
    .SYNOPSIS
        Test configuration file integrity
    .DESCRIPTION
        Performs comprehensive configuration file verification
    .PARAMETER ConfigPath
        Path to configuration file
    .OUTPUTS
        [hashtable] Configuration integrity results
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    $verification = @{
        ConfigPath = $ConfigPath
        HasIssues = $false
        Issues = @()
        Checks = @()
    }

    try {
        # Check file existence and accessibility
        if (-not (Test-PathSafely $ConfigPath -PathType "File")) {
            $verification.HasIssues = $true
            $verification.Issues += "Configuration file not accessible: $ConfigPath"
            return $verification
        }

        # JSON format validation
        try {
            $content = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $verification.Checks += @{
                Name = "JSON Format Validation"
                Result = "Valid JSON"
                Status = "PASS"
            }
        } catch {
            $verification.HasIssues = $true
            $verification.Issues += "Invalid JSON format: $($_.Exception.Message)"
            $verification.Checks += @{
                Name = "JSON Format Validation"
                Result = "Invalid JSON"
                Status = "FAIL"
            }
            return $verification
        }

        # Check for required telemetry properties
        $requiredProps = @('telemetry.machineId', 'telemetry.devDeviceId', 'telemetry.sqmId')
        foreach ($prop in $requiredProps) {
            $hasProperty = ($content.PSObject.Properties.Name -contains $prop) -and $content.$prop
            $verification.Checks += @{
                Name = "Telemetry Property: $prop"
                Result = if ($hasProperty) { "Present" } else { "Missing" }
                Status = if ($hasProperty) { "PASS" } else { "FAIL" }
            }

            if (-not $hasProperty) {
                $verification.HasIssues = $true
                $verification.Issues += "Missing required telemetry property: $prop"
            }
        }

    } catch {
        $verification.HasIssues = $true
        $verification.Issues += "Configuration verification error: $($_.Exception.Message)"
    }

    return $verification
}

function Test-InstallationConsistency {
    <#
    .SYNOPSIS
        Test consistency across installation files
    .DESCRIPTION
        Verifies telemetry data consistency between database and config files
    .PARAMETER Installation
        Installation object to test
    .OUTPUTS
        [hashtable] Consistency test results
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Installation
    )

    $consistency = @{
        Installation = $Installation
        HasIssues = $false
        Issues = @()
        Comparisons = @()
    }

    try {
        # Collect telemetry data from all files
        $telemetryData = @{
            Databases = @()
            Configs = @()
        }

        # Get data from databases
        foreach ($dbFile in $Installation.DatabaseFiles) {
            if (Test-PathSafely $dbFile -PathType "File") {
                $dbData = @{
                    FilePath = $dbFile
                    Data = @{}
                }

                $keys = @('telemetry.machineId', 'telemetry.devDeviceId', 'telemetry.sqmId')
                foreach ($key in $keys) {
                    $value = Invoke-SQLiteQuerySafely -DatabasePath $dbFile -Query "SELECT value FROM ItemTable WHERE key = '$key';" -QueryType "Select"
                    if ($value) {
                        $dbData.Data[$key] = $value.Trim()
                    }
                }

                $telemetryData.Databases += $dbData
            }
        }

        # Get data from configs
        foreach ($configFile in $Installation.StorageFiles) {
            if (Test-PathSafely $configFile -PathType "File") {
                try {
                    $content = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
                    $configData = @{
                        FilePath = $configFile
                        Data = @{}
                    }

                    $props = @('telemetry.machineId', 'telemetry.devDeviceId', 'telemetry.sqmId')
                    foreach ($prop in $props) {
                        if (($content.PSObject.Properties.Name -contains $prop) -and $content.$prop) {
                            $configData.Data[$prop] = $content.$prop
                        }
                    }

                    $telemetryData.Configs += $configData
                } catch {
                    # Skip invalid config files
                }
            }
        }

        # Compare data for consistency
        $allKeys = @('telemetry.machineId', 'telemetry.devDeviceId', 'telemetry.sqmId')
        foreach ($key in $allKeys) {
            $values = @()

            # Collect all values for this key
            foreach ($db in $telemetryData.Databases) {
                if ($db.Data[$key]) {
                    $values += $db.Data[$key]
                }
            }

            foreach ($config in $telemetryData.Configs) {
                if ($config.Data[$key]) {
                    $values += $config.Data[$key]
                }
            }

            # Check for consistency
            $uniqueValues = $values | Sort-Object -Unique
            $comparison = @{
                Key = $key
                UniqueValues = $uniqueValues
                IsConsistent = ($uniqueValues.Count -le 1)
                Status = if ($uniqueValues.Count -le 1) { "CONSISTENT" } else { "INCONSISTENT" }
            }

            $consistency.Comparisons += $comparison

            if (-not $comparison.IsConsistent) {
                $consistency.HasIssues = $true
                $consistency.Issues += "Inconsistent values for $key : $($uniqueValues -join ', ')"
            }
        }

    } catch {
        $consistency.HasIssues = $true
        $consistency.Issues += "Consistency check error: $($_.Exception.Message)"
    }

    return $consistency
}

function Write-OrchestrationSummary {
    <#
    .SYNOPSIS
        Write orchestration summary report
    .DESCRIPTION
        Generates and displays comprehensive summary of orchestration results
    .PARAMETER Results
        Orchestration results object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Results
    )

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "    UNIFIED ERROR FIX ORCHESTRATOR - SUMMARY REPORT" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Operation: $($Results.Operation)" -ForegroundColor White
    Write-Host "Duration: $([math]::Round($Results.Summary.Duration, 2)) seconds" -ForegroundColor White
    Write-Host "Status: $($Results.Status)" -ForegroundColor $(if ($Results.Status -eq "COMPLETED") { "Green" } else { "Red" })
    Write-Host ""

    if ($Results.DetectionResults) {
        Write-Host "DETECTION RESULTS:" -ForegroundColor Yellow
        Write-Host "  Total Errors Found: $($Results.DetectionResults.ErrorsSummary.Total)" -ForegroundColor White
        Write-Host "  Critical: $($Results.DetectionResults.ErrorsSummary.Critical)" -ForegroundColor Red
        Write-Host "  High: $($Results.DetectionResults.ErrorsSummary.High)" -ForegroundColor Magenta
        Write-Host "  Medium: $($Results.DetectionResults.ErrorsSummary.Medium)" -ForegroundColor Yellow
        Write-Host "  Low: $($Results.DetectionResults.ErrorsSummary.Low)" -ForegroundColor Gray
        Write-Host ""
    }

    if ($Results.FixResults) {
        Write-Host "FIX RESULTS:" -ForegroundColor Yellow
        Write-Host "  Errors Fixed: $($Results.Summary.ErrorsFixed)" -ForegroundColor Green
        Write-Host "  Errors Failed: $($Results.Summary.ErrorsFailed)" -ForegroundColor Red
        Write-Host "  Success Rate: $($Results.Summary.SuccessRate)%" -ForegroundColor $(if ($Results.Summary.SuccessRate -ge 80) { "Green" } else { "Yellow" })
        Write-Host ""
    }

    if ($Results.PreventionResults) {
        Write-Host "PREVENTION SYSTEM:" -ForegroundColor Yellow
        Write-Host "  Status: $($Results.PreventionResults.Status)" -ForegroundColor $(if ($Results.PreventionResults.Status -eq "ACTIVE") { "Green" } else { "Yellow" })
        Write-Host "  Preventive Checks: $($Results.PreventionResults.PreventiveChecks.Count)" -ForegroundColor White
        Write-Host "  Maintenance Tasks: $($Results.PreventionResults.MaintenanceTasks.Count)" -ForegroundColor White
        Write-Host ""
    }

    Write-Host "================================================================" -ForegroundColor Cyan
}

#endregion

# Export functions when loaded as module
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    Write-Verbose "Unified Fix Orchestrator loaded via dot-sourcing"
} else {
    Export-ModuleMember -Function @(
        'Start-UnifiedErrorFix',
        'Invoke-FinalVerification',
        'Test-DatabaseIntegrity',
        'Test-ConfigurationIntegrity',
        'Test-InstallationConsistency'
    )
}

Write-LogInfo "Unified Fix Orchestrator initialized successfully" "ORCHESTRATOR"
