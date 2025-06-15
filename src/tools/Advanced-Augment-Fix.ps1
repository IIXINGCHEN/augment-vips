# Advanced-Augment-Fix.ps1
# Advanced Error Management and Fixing Tool
# Version: 2.0.0 - Next-generation error detection, fixing, and prevention system

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("detect", "fix", "complete", "prevent", "verify", "help")]
    [string]$Operation = "complete",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$VerboseOutput = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnablePrevention = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateBackups = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportReport = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("QUICK", "STANDARD", "DEEP", "COMPREHENSIVE")]
    [string]$ScanDepth = "COMPREHENSIVE"
)

# Error handling
$ErrorActionPreference = "Stop"

# Get script directory
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot

# Load core modules
$coreModules = @(
    (Join-Path $projectRoot "src\core\AugmentLogger.ps1"),
    (Join-Path $projectRoot "src\core\utilities\common_utilities.ps1"),
    (Join-Path $projectRoot "src\core\error_management\ErrorTypes.ps1"),
    (Join-Path $projectRoot "src\core\error_management\AutoErrorDetector.ps1"),
    (Join-Path $projectRoot "src\core\error_management\ErrorFixEngine.ps1"),
    (Join-Path $projectRoot "src\core\error_management\PreventionSystem.ps1"),
    (Join-Path $projectRoot "src\core\error_management\UnifiedFixOrchestrator.ps1")
)

# Load modules with error handling
foreach ($module in $coreModules) {
    if (Test-Path $module) {
        try {
            . $module
            Write-Verbose "Loaded module: $module"
        } catch {
            Write-Error "Failed to load module $module : $($_.Exception.Message)"
            exit 1
        }
    } else {
        Write-Error "Required module not found: $module"
        exit 1
    }
}

# Initialize logging
try {
    Initialize-AugmentLogger -LogDirectory "logs" -LogFileName "advanced_augment_fix.log" -LogLevel "INFO" -EnableColors:$true
    Write-LogInfo "Advanced Augment Fix Tool v2.0 initialized" "ADVANCED_FIX"
} catch {
    Write-Host "Failed to initialize logging: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

#region Helper Functions

function Show-Header {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "    Advanced Augment Fix Tool v2.0" -ForegroundColor Cyan
    Write-Host "    Next-Generation Error Management System" -ForegroundColor Cyan
    Write-Host "    Detection + Fixing + Prevention + Verification" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Help {
    Show-Header
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "    Advanced error management tool with intelligent detection, automated fixing,"
    Write-Host "    proactive prevention, and comprehensive verification capabilities."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "    .\Advanced-Augment-Fix.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "OPERATIONS:" -ForegroundColor Yellow
    Write-Host "    detect      Error detection only (no fixing)"
    Write-Host "    fix         Error fixing only (quick detection + fix)"
    Write-Host "    complete    Complete workflow (detect + fix + prevent + verify)"
    Write-Host "    prevent     Prevention system only"
    Write-Host "    verify      Verification only"
    Write-Host "    help        Show this help message"
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "    -DryRun             Run without making changes"
    Write-Host "    -VerboseOutput      Enable detailed output"
    Write-Host "    -EnablePrevention   Enable prevention system (default: true)"
    Write-Host "    -CreateBackups      Create backups before changes (default: true)"
    Write-Host "    -ExportReport       Export detailed report"
    Write-Host "    -ReportPath         Custom report file path"
    Write-Host "    -ScanDepth          Scan depth: QUICK, STANDARD, DEEP, COMPREHENSIVE"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "    .\Advanced-Augment-Fix.ps1 -Operation complete"
    Write-Host "    .\Advanced-Augment-Fix.ps1 -Operation detect -ScanDepth DEEP -ExportReport"
    Write-Host "    .\Advanced-Augment-Fix.ps1 -Operation fix -DryRun -VerboseOutput"
    Write-Host ""
    Write-Host "FEATURES:" -ForegroundColor Yellow
    Write-Host "    • Intelligent error detection with pattern recognition"
    Write-Host "    • Automated fixing with multiple strategies"
    Write-Host "    • Proactive prevention and monitoring"
    Write-Host "    • Comprehensive verification and validation"
    Write-Host "    • Safe operations with automatic backups"
    Write-Host "    • Detailed reporting and logging"
    Write-Host ""
}

function Get-VSCodeInstallations {
    <#
    .SYNOPSIS
        Discover VS Code and Cursor installations
    .DESCRIPTION
        Uses enhanced discovery to find all VS Code and Cursor installations
    .OUTPUTS
        [array] Array of installation objects
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param()
    
    Write-LogInfo "Discovering VS Code and Cursor installations..." "ADVANCED_FIX"
    
    $installations = @()
    
    # Standard VS Code paths
    $vscodeBasePaths = @(
        "$env:APPDATA\Code",
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code"
    )
    
    # Cursor paths
    $cursorBasePaths = @(
        "$env:APPDATA\Cursor",
        "$env:LOCALAPPDATA\Programs\Cursor"
    )
    
    # Process VS Code installations
    foreach ($basePath in $vscodeBasePaths) {
        if (Test-PathSafely $basePath -PathType "Directory") {
            $installation = @{
                Type = "Code"
                Name = "Visual Studio Code"
                Path = $basePath
                DatabaseFiles = @()
                StorageFiles = @()
            }
            
            # Find database files
            $dbPaths = @(
                (Join-Path $basePath "User\globalStorage\state.vscdb"),
                (Join-Path $basePath "User\workspaceStorage\*\state.vscdb")
            )
            
            foreach ($dbPath in $dbPaths) {
                $foundFiles = Get-ChildItem $dbPath -ErrorAction SilentlyContinue
                foreach ($file in $foundFiles) {
                    $installation.DatabaseFiles += $file.FullName
                }
            }
            
            # Find storage files
            $storagePaths = @(
                (Join-Path $basePath "User\globalStorage\storage.json"),
                (Join-Path $basePath "User\storage.json")
            )
            
            foreach ($storagePath in $storagePaths) {
                if (Test-PathSafely $storagePath -PathType "File") {
                    $installation.StorageFiles += $storagePath
                }
            }
            
            if ($installation.DatabaseFiles.Count -gt 0 -or $installation.StorageFiles.Count -gt 0) {
                $installations += $installation
                Write-LogInfo "Found VS Code installation: $basePath" "ADVANCED_FIX"
            }
        }
    }
    
    # Process Cursor installations
    foreach ($basePath in $cursorBasePaths) {
        if (Test-PathSafely $basePath -PathType "Directory") {
            $installation = @{
                Type = "Cursor"
                Name = "Cursor"
                Path = $basePath
                DatabaseFiles = @()
                StorageFiles = @()
            }
            
            # Find database files
            $dbPaths = @(
                (Join-Path $basePath "User\globalStorage\state.vscdb"),
                (Join-Path $basePath "User\workspaceStorage\*\state.vscdb")
            )
            
            foreach ($dbPath in $dbPaths) {
                $foundFiles = Get-ChildItem $dbPath -ErrorAction SilentlyContinue
                foreach ($file in $foundFiles) {
                    $installation.DatabaseFiles += $file.FullName
                }
            }
            
            # Find storage files
            $storagePaths = @(
                (Join-Path $basePath "User\globalStorage\storage.json"),
                (Join-Path $basePath "User\storage.json")
            )
            
            foreach ($storagePath in $storagePaths) {
                if (Test-PathSafely $storagePath -PathType "File") {
                    $installation.StorageFiles += $storagePath
                }
            }
            
            if ($installation.DatabaseFiles.Count -gt 0 -or $installation.StorageFiles.Count -gt 0) {
                $installations += $installation
                Write-LogInfo "Found Cursor installation: $basePath" "ADVANCED_FIX"
            }
        }
    }
    
    Write-LogInfo "Total installations found: $($installations.Count)" "ADVANCED_FIX"
    return $installations
}

#endregion

#region Main Execution Logic

# Show header
Show-Header

# Handle help operation
if ($Operation -eq "help") {
    Show-Help
    exit 0
}

# Validate parameters
if ($ExportReport -and -not $ReportPath) {
    $ReportPath = "reports\advanced_fix_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
}

Write-LogInfo "Advanced Augment Fix Tool - Operation: $Operation" "ADVANCED_FIX"
Write-LogInfo "Parameters: DryRun=$DryRun, ScanDepth=$ScanDepth, EnablePrevention=$EnablePrevention" "ADVANCED_FIX"

if ($DryRun) {
    Write-LogInfo "DRY RUN MODE - No changes will be applied" "ADVANCED_FIX"
}

# Initialize operation tracking
$operationStart = Get-Date
$overallSuccess = $true

try {
    # Discover installations
    Write-LogInfo "Discovering VS Code and Cursor installations..." "ADVANCED_FIX"
    $installations = Get-VSCodeInstallations

    if ($installations.Count -eq 0) {
        Write-LogWarning "No VS Code or Cursor installations found" "ADVANCED_FIX"
        exit 0
    }

    # Execute operation based on type
    $orchestrationResult = $null

    switch ($Operation) {
        "detect" {
            Write-LogInfo "Starting error detection operation..." "ADVANCED_FIX"
            $orchestrationResult = Start-UnifiedErrorFix -Installations $installations -Operation "DETECT_ONLY" -DryRun:$DryRun -EnablePrevention:$false
        }

        "fix" {
            Write-LogInfo "Starting error fixing operation..." "ADVANCED_FIX"
            $orchestrationResult = Start-UnifiedErrorFix -Installations $installations -Operation "FIX_ONLY" -DryRun:$DryRun -EnablePrevention:$false
        }

        "complete" {
            Write-LogInfo "Starting complete error management operation..." "ADVANCED_FIX"
            $orchestrationResult = Start-UnifiedErrorFix -Installations $installations -Operation "COMPLETE" -DryRun:$DryRun -EnablePrevention:$EnablePrevention
        }

        "prevent" {
            Write-LogInfo "Starting prevention system operation..." "ADVANCED_FIX"
            $orchestrationResult = Start-UnifiedErrorFix -Installations $installations -Operation "PREVENT_ONLY" -DryRun:$DryRun -EnablePrevention:$true
        }

        "verify" {
            Write-LogInfo "Starting verification operation..." "ADVANCED_FIX"
            $verificationResult = Invoke-FinalVerification -Installations $installations

            # Convert verification result to orchestration format for consistency
            $orchestrationResult = @{
                OrchestrationId = [System.Guid]::NewGuid().ToString()
                StartTime = $verificationResult.StartTime
                Operation = "VERIFY"
                DryRun = $false
                Installations = $installations
                DetectionResults = $null
                FixResults = $null
                PreventionResults = $null
                VerificationResults = $verificationResult
                Summary = @{
                    TotalErrors = $verificationResult.RemainingIssues.Count
                    ErrorsFixed = 0
                    ErrorsFailed = 0
                    SuccessRate = if ($verificationResult.RemainingIssues.Count -eq 0) { 100 } else { 0 }
                    Duration = $verificationResult.Duration
                }
                Status = $verificationResult.OverallStatus
            }
        }

        default {
            Write-LogError "Unknown operation: $Operation" "ADVANCED_FIX"
            Show-Help
            exit 1
        }
    }

    # Check operation result
    if ($orchestrationResult.Status -eq "COMPLETED" -or $orchestrationResult.Status -eq "SUCCESS") {
        Write-LogSuccess "Operation completed successfully" "ADVANCED_FIX"
        $overallSuccess = $true
    } else {
        Write-LogError "Operation failed or completed with issues" "ADVANCED_FIX"
        $overallSuccess = $false
    }

    # Export report if requested
    if ($ExportReport) {
        Write-LogInfo "Exporting detailed report..." "ADVANCED_FIX"
        Export-OperationReport -Results $orchestrationResult -ReportPath $ReportPath
    }

    # Display final summary
    $operationDuration = ((Get-Date) - $operationStart).TotalSeconds
    Write-FinalSummary -Results $orchestrationResult -Duration $operationDuration -Success $overallSuccess

} catch {
    Write-LogError "Advanced Augment Fix failed: $($_.Exception.Message)" "ADVANCED_FIX"
    Write-LogError "Stack trace: $($_.ScriptStackTrace)" "ADVANCED_FIX"
    $overallSuccess = $false
}

# Exit with appropriate code
if ($overallSuccess) {
    Write-LogInfo "Advanced Augment Fix Tool execution completed successfully" "ADVANCED_FIX"
    exit 0
} else {
    Write-LogError "Advanced Augment Fix Tool execution failed" "ADVANCED_FIX"
    exit 1
}

#endregion

#region Report and Summary Functions

function Export-OperationReport {
    <#
    .SYNOPSIS
        Export detailed operation report
    .DESCRIPTION
        Creates comprehensive report of operation results
    .PARAMETER Results
        Operation results object
    .PARAMETER ReportPath
        Path to save report file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Results,

        [Parameter(Mandatory = $true)]
        [string]$ReportPath
    )

    try {
        # Ensure report directory exists
        $reportDir = Split-Path $ReportPath -Parent
        if ($reportDir -and -not (Test-Path $reportDir)) {
            New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
        }

        # Create comprehensive report
        $report = @{
            ReportMetadata = @{
                GeneratedAt = Get-Date
                ToolVersion = "Advanced-Augment-Fix v2.0"
                ReportFormat = "JSON"
                ReportId = [System.Guid]::NewGuid().ToString()
            }
            OperationResults = $Results
            SystemInformation = @{
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                OperatingSystem = [System.Environment]::OSVersion.ToString()
                MachineName = $env:COMPUTERNAME
                UserName = $env:USERNAME
            }
            InstallationSummary = @{
                TotalInstallations = $Results.Installations.Count
                InstallationTypes = ($Results.Installations | Group-Object -Property Type | ForEach-Object { @{ Type = $_.Name; Count = $_.Count } })
            }
        }

        # Add error details if available
        if ($Results.DetectionResults -and $Results.DetectionResults.DetectedErrors) {
            $report.ErrorAnalysis = @{
                ErrorsByCategory = ($Results.DetectionResults.DetectedErrors | Group-Object -Property Category | ForEach-Object { @{ Category = $_.Name; Count = $_.Count } })
                ErrorsByPriority = ($Results.DetectionResults.DetectedErrors | Group-Object -Property Priority | ForEach-Object { @{ Priority = $_.Name; Count = $_.Count } })
                ErrorsBySource = ($Results.DetectionResults.DetectedErrors | Group-Object -Property Source | ForEach-Object { @{ Source = $_.Name; Count = $_.Count } })
            }
        }

        # Save report
        $report | ConvertTo-Json -Depth 10 | Set-Content $ReportPath -Encoding UTF8
        Write-LogSuccess "Report exported to: $ReportPath" "ADVANCED_FIX"

    } catch {
        Write-LogError "Failed to export report: $($_.Exception.Message)" "ADVANCED_FIX"
    }
}

function Write-FinalSummary {
    <#
    .SYNOPSIS
        Write final operation summary
    .DESCRIPTION
        Displays comprehensive summary of operation results
    .PARAMETER Results
        Operation results object
    .PARAMETER Duration
        Total operation duration in seconds
    .PARAMETER Success
        Overall success status
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Results,

        [Parameter(Mandatory = $true)]
        [double]$Duration,

        [Parameter(Mandatory = $true)]
        [bool]$Success
    )

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "    ADVANCED AUGMENT FIX TOOL - FINAL SUMMARY" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Operation: $($Results.Operation)" -ForegroundColor White
    Write-Host "Total Duration: $([math]::Round($Duration, 2)) seconds" -ForegroundColor White
    Write-Host "Overall Status: " -NoNewline
    Write-Host $(if ($Success) { "SUCCESS" } else { "FAILED" }) -ForegroundColor $(if ($Success) { "Green" } else { "Red" })
    Write-Host ""

    if ($Results.DetectionResults) {
        Write-Host "DETECTION SUMMARY:" -ForegroundColor Yellow
        Write-Host "  Installations Scanned: $($Results.Installations.Count)" -ForegroundColor White
        Write-Host "  Total Errors Found: $($Results.DetectionResults.ErrorsSummary.Total)" -ForegroundColor White
        Write-Host "  Scan Duration: $([math]::Round($Results.DetectionResults.ScanDuration, 2)) seconds" -ForegroundColor White
        Write-Host ""
    }

    if ($Results.FixResults) {
        Write-Host "FIX SUMMARY:" -ForegroundColor Yellow
        Write-Host "  Errors Fixed: $($Results.Summary.ErrorsFixed)" -ForegroundColor Green
        Write-Host "  Errors Failed: $($Results.Summary.ErrorsFailed)" -ForegroundColor Red
        Write-Host "  Success Rate: $($Results.Summary.SuccessRate)%" -ForegroundColor $(if ($Results.Summary.SuccessRate -ge 80) { "Green" } elseif ($Results.Summary.SuccessRate -ge 50) { "Yellow" } else { "Red" })
        Write-Host ""
    }

    if ($Results.PreventionResults) {
        Write-Host "PREVENTION SUMMARY:" -ForegroundColor Yellow
        Write-Host "  Prevention Status: $($Results.PreventionResults.Status)" -ForegroundColor $(if ($Results.PreventionResults.Status -eq "ACTIVE") { "Green" } else { "Yellow" })
        Write-Host "  Preventive Checks: $($Results.PreventionResults.PreventiveChecks.Count)" -ForegroundColor White
        Write-Host "  Maintenance Tasks: $($Results.PreventionResults.MaintenanceTasks.Count)" -ForegroundColor White
        Write-Host ""
    }

    if ($Results.VerificationResults) {
        Write-Host "VERIFICATION SUMMARY:" -ForegroundColor Yellow
        Write-Host "  Verification Status: $($Results.VerificationResults.OverallStatus)" -ForegroundColor $(if ($Results.VerificationResults.OverallStatus -eq "SUCCESS") { "Green" } else { "Red" })
        Write-Host "  Remaining Issues: $($Results.VerificationResults.RemainingIssues.Count)" -ForegroundColor $(if ($Results.VerificationResults.RemainingIssues.Count -eq 0) { "Green" } else { "Red" })
        Write-Host ""
    }

    # Recommendations
    if (-not $Success -or ($Results.DetectionResults -and $Results.DetectionResults.ErrorsSummary.Total -gt 0)) {
        Write-Host "RECOMMENDATIONS:" -ForegroundColor Yellow
        if ($Results.DetectionResults -and $Results.DetectionResults.ErrorsSummary.Critical -gt 0) {
            Write-Host "  • Address critical errors immediately" -ForegroundColor Red
        }
        if ($Results.Summary.SuccessRate -lt 100 -and $Results.Summary.SuccessRate -gt 0) {
            Write-Host "  • Review failed fixes and retry with different strategies" -ForegroundColor Yellow
        }
        if ($Results.DetectionResults -and $Results.DetectionResults.ErrorsSummary.Total -gt 0) {
            Write-Host "  • Enable prevention system to avoid future issues" -ForegroundColor Cyan
        }
        Write-Host "  • Run verification to confirm system integrity" -ForegroundColor Cyan
        Write-Host ""
    }

    Write-Host "================================================================" -ForegroundColor Cyan

    if ($Success) {
        Write-LogSuccess "All operations completed successfully!" "ADVANCED_FIX"
    } else {
        Write-LogError "Some operations failed. Please review the logs for details." "ADVANCED_FIX"
    }
}

#endregion
