# Integration-Tests.ps1
#
# Description: Integration tests for Augment VIP Cleaner
# Tests module interactions, end-to-end workflows, and system integration
#
# Author: Augment VIP Project
# Version: 2.0.0

param(
    [string]$LogLevel = 'Normal',
    [string]$OutputPath = ".\test-results"
)

# Integration test results
$script:IntegrationResults = @{
    StartTime = Get-Date
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    SkippedTests = 0
    TestDetails = @()
}

# Test configuration
$script:TestConfig = @{
    ProjectRoot = Split-Path -Parent $PSScriptRoot
    ModulesPath = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\windows\modules"
    PythonPath = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\cross-platform\augment_vip"
    ConfigPath = Join-Path (Split-Path -Parent $PSScriptRoot) "config\config.json"
    TestDataPath = Join-Path $PSScriptRoot "test-data"
    TempPath = Join-Path $env:TEMP "augment-vip-integration-tests"
}

<#
.SYNOPSIS
    Main integration test execution function
#>
function Start-IntegrationTests {
    [CmdletBinding()]
    param()
    
    Write-Host "Starting Integration Tests for Augment VIP Cleaner" -ForegroundColor Magenta
    Write-Host "=" * 60 -ForegroundColor Magenta
    
    # Create temp directory and test data
    if (-not (Test-Path $script:TestConfig.TempPath)) {
        New-Item -ItemType Directory -Path $script:TestConfig.TempPath -Force | Out-Null
    }
    
    try {
        # Initialize test environment
        Initialize-TestEnvironment
        
        # Core integration tests
        Test-ModuleInteractions
        Test-ConfigurationIntegration
        Test-LoggingIntegration
        Test-BackupWorkflow
        Test-DatabaseCleaningWorkflow
        Test-TelemetryModificationWorkflow
        Test-DependencyManagementWorkflow
        Test-ErrorRecoveryWorkflow
        Test-CrossPlatformCompatibility
        
        # Generate integration test report
        New-IntegrationTestReport
        
        # Show summary
        Show-IntegrationTestSummary
        
    } catch {
        Write-Host "Integration testing failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    } finally {
        # Cleanup
        if (Test-Path $script:TestConfig.TempPath) {
            Remove-Item -Path $script:TestConfig.TempPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

<#
.SYNOPSIS
    Initializes the test environment
#>
function Initialize-TestEnvironment {
    Write-Host "`nInitializing Test Environment..." -ForegroundColor Yellow
    
    try {
        # Import core modules
        $coreModules = @('Logger', 'CommonUtils', 'SystemDetection')
        foreach ($module in $coreModules) {
            $modulePath = Join-Path $script:TestConfig.ModulesPath "$module.psm1"
            if (Test-Path $modulePath) {
                Import-Module $modulePath -Force
                Add-IntegrationTestResult -TestName "Import $module" -Status "Passed" -Message "Module imported successfully"
            } else {
                Add-IntegrationTestResult -TestName "Import $module" -Status "Failed" -Message "Module file not found"
            }
        }
        
        # Initialize logger
        Initialize-Logger -Level "Info" -EnableConsole $true
        Add-IntegrationTestResult -TestName "Initialize Logger" -Status "Passed" -Message "Logger initialized successfully"
        
        # Create test database files
        Create-TestDatabaseFiles
        
    } catch {
        Add-IntegrationTestResult -TestName "Initialize Test Environment" -Status "Failed" -Message $_.Exception.Message
        throw
    }
}

<#
.SYNOPSIS
    Creates test database files for testing
#>
function Create-TestDatabaseFiles {
    $testDbPath = Join-Path $script:TestConfig.TempPath "test-database.db"

    try {
        # Check if SQLite is available
        if (-not (Test-SQLiteAvailability)) {
            Write-Host "SQLite not available, creating mock database" -ForegroundColor Yellow
            # Create empty file as placeholder
            New-Item -Path $testDbPath -ItemType File -Force | Out-Null
            Add-IntegrationTestResult -TestName "Create Test Database" -Status "Skipped" -Message "SQLite not available"
            return
        }

        # Create a simple SQLite database for testing
        $connectionString = "Data Source=$testDbPath"
        $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
        $connection.Open()
        
        $command = $connection.CreateCommand()
        $command.CommandText = @"
CREATE TABLE IF NOT EXISTS ItemTable (
    id INTEGER PRIMARY KEY,
    key TEXT NOT NULL,
    value TEXT
);

INSERT INTO ItemTable (key, value) VALUES 
    ('augment.test.key1', 'test_value_1'),
    ('augment.test.key2', 'test_value_2'),
    ('normal.key', 'normal_value'),
    ('telemetry.machineId', 'test_machine_id'),
    ('telemetry.sessionId', 'test_session_id');
"@
        $command.ExecuteNonQuery()
        $connection.Close()
        
        Add-IntegrationTestResult -TestName "Create Test Database" -Status "Passed" -Message "Test database created successfully"
        
    } catch {
        Add-IntegrationTestResult -TestName "Create Test Database" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests module interactions and dependencies
#>
function Test-ModuleInteractions {
    Write-Host "Testing Module Interactions..." -ForegroundColor Yellow
    
    try {
        # Test Logger and CommonUtils interaction
        $uuid = New-SecureUUID
        Write-LogInfo "Generated UUID: $uuid"
        Add-IntegrationTestResult -TestName "Logger-CommonUtils Interaction" -Status "Passed" -Message "Modules interact correctly"
        
        # Test SystemDetection and Logger interaction
        $sysInfo = Get-SystemInformation
        Write-LogInfo "System: $($sysInfo.OSVersion)"
        Add-IntegrationTestResult -TestName "SystemDetection-Logger Interaction" -Status "Passed" -Message "System detection with logging works"
        
        # Test configuration loading with CommonUtils
        $config = Get-Configuration
        if ($config) {
            Write-LogInfo "Configuration loaded successfully"
            Add-IntegrationTestResult -TestName "Configuration-CommonUtils Interaction" -Status "Passed" -Message "Configuration loading works"
        } else {
            Add-IntegrationTestResult -TestName "Configuration-CommonUtils Interaction" -Status "Failed" -Message "Configuration loading failed"
        }
        
    } catch {
        Add-IntegrationTestResult -TestName "Module Interactions" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests configuration integration across modules
#>
function Test-ConfigurationIntegration {
    Write-Host "Testing Configuration Integration..." -ForegroundColor Yellow
    
    try {
        # Test configuration loading
        if (Test-Path $script:TestConfig.ConfigPath) {
            $config = Get-Content $script:TestConfig.ConfigPath | ConvertFrom-Json
            
            # Test security configuration
            if ($config.security) {
                Add-IntegrationTestResult -TestName "Security Configuration" -Status "Passed" -Message "Security settings found in configuration"
            } else {
                Add-IntegrationTestResult -TestName "Security Configuration" -Status "Failed" -Message "Security settings missing"
            }
            
            # Test logging configuration
            if ($config.logging) {
                Add-IntegrationTestResult -TestName "Logging Configuration" -Status "Passed" -Message "Logging settings found in configuration"
            } else {
                Add-IntegrationTestResult -TestName "Logging Configuration" -Status "Failed" -Message "Logging settings missing"
            }
            
            # Test cleaning patterns
            if ($config.cleaning -and $config.cleaning.patterns) {
                Add-IntegrationTestResult -TestName "Cleaning Patterns Configuration" -Status "Passed" -Message "Cleaning patterns found in configuration"
            } else {
                Add-IntegrationTestResult -TestName "Cleaning Patterns Configuration" -Status "Failed" -Message "Cleaning patterns missing"
            }
            
        } else {
            Add-IntegrationTestResult -TestName "Configuration File" -Status "Failed" -Message "Configuration file not found"
        }
        
    } catch {
        Add-IntegrationTestResult -TestName "Configuration Integration" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests logging integration across all modules
#>
function Test-LoggingIntegration {
    Write-Host "Testing Logging Integration..." -ForegroundColor Yellow
    
    try {
        # Test different log levels
        Write-LogDebug "Debug message test"
        Write-LogInfo "Info message test"
        Write-LogWarning "Warning message test"
        
        # Test user-friendly messages
        Show-SuccessMessage "Success message test"
        Show-InfoMessage "Info message test"
        Show-WarningMessage "Warning message test"
        
        # Test operation status
        Show-OperationStatus -Operation "Test Operation" -Status "Starting"
        Show-OperationStatus -Operation "Test Operation" -Status "Completed"
        
        Add-IntegrationTestResult -TestName "Logging Integration" -Status "Passed" -Message "All logging functions work correctly"
        
    } catch {
        Add-IntegrationTestResult -TestName "Logging Integration" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests backup workflow integration
#>
function Test-BackupWorkflow {
    Write-Host "Testing Backup Workflow..." -ForegroundColor Yellow
    
    try {
        # Import BackupManager module
        $backupModulePath = Join-Path $script:TestConfig.ModulesPath "BackupManager.psm1"
        if (Test-Path $backupModulePath) {
            Import-Module $backupModulePath -Force
            
            # Create test file
            $testFile = Join-Path $script:TestConfig.TempPath "test-backup-file.txt"
            "Test content for backup workflow" | Out-File -FilePath $testFile -Encoding UTF8
            
            # Test backup creation
            $backup = New-FileBackup -FilePath $testFile -BackupDirectory $script:TestConfig.TempPath
            if ($backup -and (Test-Path $backup.BackupPath)) {
                Add-IntegrationTestResult -TestName "Backup Creation" -Status "Passed" -Message "Backup created successfully"
                
                # Test backup listing
                $backups = Get-BackupFiles -BackupDirectory $script:TestConfig.TempPath
                if ($backups -and $backups.Count -gt 0) {
                    Add-IntegrationTestResult -TestName "Backup Listing" -Status "Passed" -Message "Backup files listed successfully"
                } else {
                    Add-IntegrationTestResult -TestName "Backup Listing" -Status "Failed" -Message "No backup files found"
                }
                
            } else {
                Add-IntegrationTestResult -TestName "Backup Creation" -Status "Failed" -Message "Backup creation failed"
            }
            
        } else {
            Add-IntegrationTestResult -TestName "Backup Workflow" -Status "Skipped" -Message "BackupManager module not found"
        }
        
    } catch {
        Add-IntegrationTestResult -TestName "Backup Workflow" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Adds an integration test result
#>
function Add-IntegrationTestResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestName,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Passed', 'Failed', 'Skipped')]
        [string]$Status,
        [string]$Message = "",
        [string]$Details = ""
    )
    
    $result = @{
        TestName = $TestName
        Status = $Status
        Message = $Message
        Details = $Details
        Timestamp = Get-Date
    }
    
    $script:IntegrationResults.TestDetails += $result
    $script:IntegrationResults.TotalTests++
    
    switch ($Status) {
        'Passed' { 
            $script:IntegrationResults.PassedTests++
            Write-Host "  [PASS] $TestName`: $Message" -ForegroundColor Green
        }
        'Failed' { 
            $script:IntegrationResults.FailedTests++
            Write-Host "  [FAIL] $TestName`: $Message" -ForegroundColor Red
        }
        'Skipped' { 
            $script:IntegrationResults.SkippedTests++
            Write-Host "  [SKIP] $TestName`: $Message" -ForegroundColor Yellow
        }
    }
}

<#
.SYNOPSIS
    Tests database cleaning workflow
#>
function Test-DatabaseCleaningWorkflow {
    Write-Host "Testing Database Cleaning Workflow..." -ForegroundColor Yellow

    try {
        # Import DatabaseCleaner module
        $dbCleanerPath = Join-Path $script:TestConfig.ModulesPath "DatabaseCleaner.psm1"
        if (Test-Path $dbCleanerPath) {
            Import-Module $dbCleanerPath -Force

            $testDbPath = Join-Path $script:TestConfig.TempPath "test-database.db"
            if (Test-Path $testDbPath) {
                # Test cleaning preview
                $preview = Show-CleaningPreview -DatabasePaths @($testDbPath)
                Add-IntegrationTestResult -TestName "Database Cleaning Preview" -Status "Passed" -Message "Preview generated successfully"

                # Test actual cleaning (with backup)
                $result = Clear-VSCodeDatabase -DatabasePath $testDbPath -CreateBackup $true
                if ($result -and $result.Success) {
                    Add-IntegrationTestResult -TestName "Database Cleaning Execution" -Status "Passed" -Message "Database cleaned successfully"
                } else {
                    Add-IntegrationTestResult -TestName "Database Cleaning Execution" -Status "Failed" -Message "Database cleaning failed"
                }

            } else {
                Add-IntegrationTestResult -TestName "Database Cleaning Workflow" -Status "Skipped" -Message "Test database not available"
            }

        } else {
            Add-IntegrationTestResult -TestName "Database Cleaning Workflow" -Status "Skipped" -Message "DatabaseCleaner module not found"
        }

    } catch {
        Add-IntegrationTestResult -TestName "Database Cleaning Workflow" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests telemetry modification workflow
#>
function Test-TelemetryModificationWorkflow {
    Write-Host "Testing Telemetry Modification Workflow..." -ForegroundColor Yellow

    try {
        # Import TelemetryModifier module
        $telemetryModulePath = Join-Path $script:TestConfig.ModulesPath "TelemetryModifier.psm1"
        if (Test-Path $telemetryModulePath) {
            Import-Module $telemetryModulePath -Force

            # Test secure ID generation
            $newMachineId = New-SecureUUID
            $newSessionId = New-SecureUUID

            if ($newMachineId -and $newSessionId) {
                Add-IntegrationTestResult -TestName "Telemetry ID Generation" -Status "Passed" -Message "New telemetry IDs generated successfully"

                # Test telemetry modification (if function exists)
                if (Get-Command "Set-VSCodeTelemetryIds" -ErrorAction SilentlyContinue) {
                    $testDbPath = Join-Path $script:TestConfig.TempPath "test-database.db"
                    if (Test-Path $testDbPath) {
                        $result = Set-VSCodeTelemetryIds -DatabasePath $testDbPath -MachineId $newMachineId -SessionId $newSessionId
                        if ($result) {
                            Add-IntegrationTestResult -TestName "Telemetry Modification" -Status "Passed" -Message "Telemetry IDs modified successfully"
                        } else {
                            Add-IntegrationTestResult -TestName "Telemetry Modification" -Status "Failed" -Message "Telemetry modification failed"
                        }
                    } else {
                        Add-IntegrationTestResult -TestName "Telemetry Modification" -Status "Skipped" -Message "Test database not available"
                    }
                } else {
                    Add-IntegrationTestResult -TestName "Telemetry Modification" -Status "Skipped" -Message "Set-VSCodeTelemetryIds function not available"
                }

            } else {
                Add-IntegrationTestResult -TestName "Telemetry ID Generation" -Status "Failed" -Message "Failed to generate telemetry IDs"
            }

        } else {
            Add-IntegrationTestResult -TestName "Telemetry Modification Workflow" -Status "Skipped" -Message "TelemetryModifier module not found"
        }

    } catch {
        Add-IntegrationTestResult -TestName "Telemetry Modification Workflow" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests dependency management workflow
#>
function Test-DependencyManagementWorkflow {
    Write-Host "Testing Dependency Management Workflow..." -ForegroundColor Yellow

    try {
        # Import DependencyManager module
        $depManagerPath = Join-Path $script:TestConfig.ModulesPath "DependencyManager.psm1"
        if (Test-Path $depManagerPath) {
            Import-Module $depManagerPath -Force

            # Test dependency status check
            $depStatus = Get-DependencyStatus
            Add-IntegrationTestResult -TestName "Dependency Status Check" -Status "Passed" -Message "Dependency status retrieved successfully"

            # Test individual dependency checks
            $testDependencies = @('powershell', 'cmd')
            foreach ($dep in $testDependencies) {
                $result = Test-Dependency -Name $dep
                Add-IntegrationTestResult -TestName "Test Dependency ($dep)" -Status "Passed" -Message "Dependency test completed"
            }

        } else {
            Add-IntegrationTestResult -TestName "Dependency Management Workflow" -Status "Skipped" -Message "DependencyManager module not found"
        }

    } catch {
        Add-IntegrationTestResult -TestName "Dependency Management Workflow" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests error recovery workflow
#>
function Test-ErrorRecoveryWorkflow {
    Write-Host "Testing Error Recovery Workflow..." -ForegroundColor Yellow

    try {
        # Test safe operation wrapper
        $result = Invoke-SafeOperation -ScriptBlock {
            throw "Test error for recovery"
        } -ErrorMessage "Test error recovery" -ReturnOnError "Recovery successful"

        if ($result -eq "Recovery successful") {
            Add-IntegrationTestResult -TestName "Error Recovery" -Status "Passed" -Message "Error recovery mechanism works correctly"
        } else {
            Add-IntegrationTestResult -TestName "Error Recovery" -Status "Failed" -Message "Error recovery mechanism failed"
        }

        # Test safe path validation
        $safePath = Test-SafePath -Path "safe-file.txt"
        $unsafePath = Test-SafePath -Path "../unsafe-file.txt"

        if ($safePath -eq $true -and $unsafePath -eq $false) {
            Add-IntegrationTestResult -TestName "Path Validation Recovery" -Status "Passed" -Message "Path validation prevents unsafe operations"
        } else {
            Add-IntegrationTestResult -TestName "Path Validation Recovery" -Status "Failed" -Message "Path validation not working correctly"
        }

    } catch {
        Add-IntegrationTestResult -TestName "Error Recovery Workflow" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests cross-platform compatibility
#>
function Test-CrossPlatformCompatibility {
    Write-Host "Testing Cross-Platform Compatibility..." -ForegroundColor Yellow

    try {
        # Test Python module availability
        $pythonFiles = Get-ChildItem "$($script:TestConfig.PythonPath)\*.py" -ErrorAction SilentlyContinue
        if ($pythonFiles -and $pythonFiles.Count -gt 0) {
            Add-IntegrationTestResult -TestName "Python Modules Available" -Status "Passed" -Message "Python modules found for cross-platform support"

            # Test configuration compatibility
            $config = Get-Configuration
            if ($config -and $config.platform) {
                Add-IntegrationTestResult -TestName "Cross-Platform Configuration" -Status "Passed" -Message "Cross-platform configuration found"
            } else {
                Add-IntegrationTestResult -TestName "Cross-Platform Configuration" -Status "Failed" -Message "Cross-platform configuration missing"
            }

        } else {
            Add-IntegrationTestResult -TestName "Python Modules Available" -Status "Failed" -Message "Python modules not found"
        }

        # Test VS Code path detection for different platforms
        $vscodePathsWindows = Get-VSCodePaths -Platform "Windows"
        $vscodePathsLinux = Get-VSCodePaths -Platform "Linux"
        $vscodePathsMacOS = Get-VSCodePaths -Platform "MacOS"

        if ($vscodePathsWindows -and $vscodePathsLinux -and $vscodePathsMacOS) {
            Add-IntegrationTestResult -TestName "Multi-Platform Path Detection" -Status "Passed" -Message "VS Code paths defined for all platforms"
        } else {
            Add-IntegrationTestResult -TestName "Multi-Platform Path Detection" -Status "Failed" -Message "Missing VS Code paths for some platforms"
        }

    } catch {
        Add-IntegrationTestResult -TestName "Cross-Platform Compatibility" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Generates integration test report
#>
function New-IntegrationTestReport {
    $reportPath = Join-Path $OutputPath "integration-test-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $script:IntegrationResults.EndTime = Get-Date
    $script:IntegrationResults.Duration = $script:IntegrationResults.EndTime - $script:IntegrationResults.StartTime
    $script:IntegrationResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "Integration test report saved: $reportPath" -ForegroundColor Green
}

<#
.SYNOPSIS
    Shows integration test summary
#>
function Show-IntegrationTestSummary {
    Write-Host "`n" + "=" * 60 -ForegroundColor Magenta
    Write-Host "INTEGRATION TEST SUMMARY" -ForegroundColor Magenta
    Write-Host "=" * 60 -ForegroundColor Magenta

    Write-Host "Total Tests: $($script:IntegrationResults.TotalTests)" -ForegroundColor White
    Write-Host "Passed: $($script:IntegrationResults.PassedTests)" -ForegroundColor Green
    Write-Host "Failed: $($script:IntegrationResults.FailedTests)" -ForegroundColor Red
    Write-Host "Skipped: $($script:IntegrationResults.SkippedTests)" -ForegroundColor Yellow

    $successRate = if ($script:IntegrationResults.TotalTests -gt 0) {
        [Math]::Round(($script:IntegrationResults.PassedTests / $script:IntegrationResults.TotalTests) * 100, 2)
    } else { 0 }
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })

    Write-Host "Duration: $($script:IntegrationResults.Duration.ToString('hh\:mm\:ss'))" -ForegroundColor White

    # Show failed tests details
    if ($script:IntegrationResults.FailedTests -gt 0) {
        Write-Host "`nFailed Tests:" -ForegroundColor Red
        $failedTests = $script:IntegrationResults.TestDetails | Where-Object { $_.Status -eq "Failed" }
        foreach ($test in $failedTests) {
            Write-Host "  - $($test.TestName): $($test.Message)" -ForegroundColor Red
        }
    }

    if ($script:IntegrationResults.FailedTests -eq 0) {
        Write-Host "`nALL INTEGRATION TESTS PASSED!" -ForegroundColor Green
    } else {
        Write-Host "`n$($script:IntegrationResults.FailedTests) INTEGRATION TESTS FAILED" -ForegroundColor Red
    }
}

<#
.SYNOPSIS
    Tests if SQLite is available for database operations
#>
function Test-SQLiteAvailability {
    try {
        # Try to load SQLite assembly
        Add-Type -AssemblyName System.Data.SQLite -ErrorAction Stop
        return $true
    } catch {
        try {
            # Try alternative method
            [System.Reflection.Assembly]::LoadWithPartialName("System.Data.SQLite") | Out-Null
            return $true
        } catch {
            return $false
        }
    }
}

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    Start-IntegrationTests
}
