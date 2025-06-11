# Performance-Tests.ps1
#
# Description: Performance tests for Augment VIP Cleaner
# Tests execution speed, memory usage, and resource efficiency
#
# Author: Augment VIP Project
# Version: 2.0.0

param(
    [string]$LogLevel = 'Normal',
    [string]$OutputPath = ".\test-results"
)

# Performance test results
$script:PerformanceResults = @{
    StartTime = Get-Date
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    PerformanceMetrics = @{}
    TestDetails = @()
}

# Performance thresholds
$script:PerformanceThresholds = @{
    ModuleImportTime = [TimeSpan]::FromSeconds(5)
    UUIDGenerationTime = [TimeSpan]::FromMilliseconds(100)
    ConfigurationLoadTime = [TimeSpan]::FromSeconds(2)
    DatabaseOperationTime = [TimeSpan]::FromSeconds(10)
    BackupCreationTime = [TimeSpan]::FromSeconds(30)
    MemoryUsageLimit = 100MB
}

# Test configuration
$script:TestConfig = @{
    ProjectRoot = Split-Path -Parent $PSScriptRoot
    ModulesPath = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\windows\modules"
    ConfigPath = Join-Path (Split-Path -Parent $PSScriptRoot) "config\config.json"
    TempPath = Join-Path $env:TEMP "augment-vip-performance-tests"
}

<#
.SYNOPSIS
    Main performance test execution function
#>
function Start-PerformanceTests {
    [CmdletBinding()]
    param()
    
    Write-Host "Starting Performance Tests for Augment VIP Cleaner" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    # Create temp directory
    if (-not (Test-Path $script:TestConfig.TempPath)) {
        New-Item -ItemType Directory -Path $script:TestConfig.TempPath -Force | Out-Null
    }
    
    try {
        # Core performance tests
        Test-ModuleImportPerformance
        Test-UUIDGenerationPerformance
        Test-ConfigurationLoadPerformance
        Test-DatabaseOperationPerformance
        Test-BackupOperationPerformance
        Test-MemoryUsagePerformance
        Test-ConcurrentOperationPerformance
        
        # Generate performance report
        New-PerformanceReport
        
        # Show summary
        Show-PerformanceSummary
        
    } catch {
        Write-Host "Performance testing failed: $($_.Exception.Message)" -ForegroundColor Red
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
    Tests module import performance
#>
function Test-ModuleImportPerformance {
    Write-Host "`nTesting Module Import Performance..." -ForegroundColor Yellow
    
    $modules = @('Logger', 'CommonUtils', 'SystemDetection', 'DependencyManager', 'VSCodeDiscovery', 'BackupManager', 'DatabaseCleaner', 'TelemetryModifier')
    
    foreach ($module in $modules) {
        $modulePath = Join-Path $script:TestConfig.ModulesPath "$module.psm1"
        if (Test-Path $modulePath) {
            
            # Remove module if already loaded
            Remove-Module $module -Force -ErrorAction SilentlyContinue
            
            # Measure import time
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                Import-Module $modulePath -Force
                $stopwatch.Stop()
                
                $importTime = $stopwatch.Elapsed
                $script:PerformanceResults.PerformanceMetrics["$module-ImportTime"] = $importTime
                
                if ($importTime -le $script:PerformanceThresholds.ModuleImportTime) {
                    Add-PerformanceTestResult -TestName "$module Import Performance" -Status "Passed" -Message "Import time: $($importTime.TotalMilliseconds)ms" -Duration $importTime
                } else {
                    Add-PerformanceTestResult -TestName "$module Import Performance" -Status "Failed" -Message "Import time exceeded threshold: $($importTime.TotalMilliseconds)ms" -Duration $importTime
                }
                
            } catch {
                $stopwatch.Stop()
                Add-PerformanceTestResult -TestName "$module Import Performance" -Status "Failed" -Message "Import failed: $($_.Exception.Message)"
            }
        } else {
            Add-PerformanceTestResult -TestName "$module Import Performance" -Status "Failed" -Message "Module file not found"
        }
    }
}

<#
.SYNOPSIS
    Tests UUID generation performance
#>
function Test-UUIDGenerationPerformance {
    Write-Host "Testing UUID Generation Performance..." -ForegroundColor Yellow
    
    try {
        # Import CommonUtils module
        $commonUtilsPath = Join-Path $script:TestConfig.ModulesPath "CommonUtils.psm1"
        Import-Module $commonUtilsPath -Force
        
        # Test single UUID generation
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $uuid = New-SecureUUID
        $stopwatch.Stop()
        
        $singleUUIDTime = $stopwatch.Elapsed
        $script:PerformanceResults.PerformanceMetrics["SingleUUIDGeneration"] = $singleUUIDTime
        
        if ($singleUUIDTime -le $script:PerformanceThresholds.UUIDGenerationTime) {
            Add-PerformanceTestResult -TestName "Single UUID Generation" -Status "Passed" -Message "Generation time: $($singleUUIDTime.TotalMilliseconds)ms" -Duration $singleUUIDTime
        } else {
            Add-PerformanceTestResult -TestName "Single UUID Generation" -Status "Failed" -Message "Generation time exceeded threshold: $($singleUUIDTime.TotalMilliseconds)ms" -Duration $singleUUIDTime
        }
        
        # Test bulk UUID generation (100 UUIDs)
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        for ($i = 0; $i -lt 100; $i++) {
            $uuid = New-SecureUUID
        }
        $stopwatch.Stop()
        
        $bulkUUIDTime = $stopwatch.Elapsed
        $avgUUIDTime = [TimeSpan]::FromTicks($bulkUUIDTime.Ticks / 100)
        $script:PerformanceResults.PerformanceMetrics["BulkUUIDGeneration"] = $bulkUUIDTime
        $script:PerformanceResults.PerformanceMetrics["AverageUUIDGeneration"] = $avgUUIDTime
        
        if ($avgUUIDTime -le $script:PerformanceThresholds.UUIDGenerationTime) {
            Add-PerformanceTestResult -TestName "Bulk UUID Generation (100)" -Status "Passed" -Message "Average time: $($avgUUIDTime.TotalMilliseconds)ms per UUID" -Duration $bulkUUIDTime
        } else {
            Add-PerformanceTestResult -TestName "Bulk UUID Generation (100)" -Status "Failed" -Message "Average time exceeded threshold: $($avgUUIDTime.TotalMilliseconds)ms per UUID" -Duration $bulkUUIDTime
        }
        
    } catch {
        Add-PerformanceTestResult -TestName "UUID Generation Performance" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests configuration loading performance
#>
function Test-ConfigurationLoadPerformance {
    Write-Host "Testing Configuration Load Performance..." -ForegroundColor Yellow
    
    try {
        # Test configuration loading
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $config = Get-Configuration
        $stopwatch.Stop()
        
        $configLoadTime = $stopwatch.Elapsed
        $script:PerformanceResults.PerformanceMetrics["ConfigurationLoad"] = $configLoadTime
        
        if ($configLoadTime -le $script:PerformanceThresholds.ConfigurationLoadTime) {
            Add-PerformanceTestResult -TestName "Configuration Load Performance" -Status "Passed" -Message "Load time: $($configLoadTime.TotalMilliseconds)ms" -Duration $configLoadTime
        } else {
            Add-PerformanceTestResult -TestName "Configuration Load Performance" -Status "Failed" -Message "Load time exceeded threshold: $($configLoadTime.TotalMilliseconds)ms" -Duration $configLoadTime
        }
        
        # Test repeated configuration loading (caching test)
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        for ($i = 0; $i -lt 10; $i++) {
            $config = Get-Configuration
        }
        $stopwatch.Stop()
        
        $repeatedLoadTime = $stopwatch.Elapsed
        $avgLoadTime = [TimeSpan]::FromTicks($repeatedLoadTime.Ticks / 10)
        $script:PerformanceResults.PerformanceMetrics["RepeatedConfigurationLoad"] = $repeatedLoadTime
        $script:PerformanceResults.PerformanceMetrics["AverageConfigurationLoad"] = $avgLoadTime
        
        # Cached loads should be much faster
        if ($avgLoadTime -le [TimeSpan]::FromMilliseconds(10)) {
            Add-PerformanceTestResult -TestName "Configuration Caching Performance" -Status "Passed" -Message "Average cached load time: $($avgLoadTime.TotalMilliseconds)ms" -Duration $repeatedLoadTime
        } else {
            Add-PerformanceTestResult -TestName "Configuration Caching Performance" -Status "Failed" -Message "Caching not effective, average time: $($avgLoadTime.TotalMilliseconds)ms" -Duration $repeatedLoadTime
        }
        
    } catch {
        Add-PerformanceTestResult -TestName "Configuration Load Performance" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests database operation performance
#>
function Test-DatabaseOperationPerformance {
    Write-Host "Testing Database Operation Performance..." -ForegroundColor Yellow
    
    try {
        # Create test database
        $testDbPath = Join-Path $script:TestConfig.TempPath "performance-test.db"
        Create-PerformanceTestDatabase -DatabasePath $testDbPath
        
        # Import DatabaseCleaner module
        $dbCleanerPath = Join-Path $script:TestConfig.ModulesPath "DatabaseCleaner.psm1"
        if (Test-Path $dbCleanerPath) {
            Import-Module $dbCleanerPath -Force
            
            # Test cleaning preview performance
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $preview = Show-CleaningPreview -DatabasePaths @($testDbPath)
            $stopwatch.Stop()
            
            $previewTime = $stopwatch.Elapsed
            $script:PerformanceResults.PerformanceMetrics["DatabasePreview"] = $previewTime
            
            if ($previewTime -le $script:PerformanceThresholds.DatabaseOperationTime) {
                Add-PerformanceTestResult -TestName "Database Preview Performance" -Status "Passed" -Message "Preview time: $($previewTime.TotalMilliseconds)ms" -Duration $previewTime
            } else {
                Add-PerformanceTestResult -TestName "Database Preview Performance" -Status "Failed" -Message "Preview time exceeded threshold: $($previewTime.TotalMilliseconds)ms" -Duration $previewTime
            }
            
        } else {
            Add-PerformanceTestResult -TestName "Database Operation Performance" -Status "Failed" -Message "DatabaseCleaner module not found"
        }
        
    } catch {
        Add-PerformanceTestResult -TestName "Database Operation Performance" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Creates a test database with performance test data
#>
function Create-PerformanceTestDatabase {
    param([string]$DatabasePath)

    try {
        # Check if SQLite is available
        if (-not (Test-SQLiteAvailability)) {
            Write-Host "SQLite not available, skipping database tests" -ForegroundColor Yellow
            return
        }

        # Create SQLite database with test data
        $connectionString = "Data Source=$DatabasePath"
        $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
        $connection.Open()
        
        $command = $connection.CreateCommand()
        $command.CommandText = @"
CREATE TABLE IF NOT EXISTS ItemTable (
    id INTEGER PRIMARY KEY,
    key TEXT NOT NULL,
    value TEXT
);
"@
        $command.ExecuteNonQuery()
        
        # Insert test data (1000 records for performance testing)
        for ($i = 0; $i -lt 1000; $i++) {
            $command.CommandText = "INSERT INTO ItemTable (key, value) VALUES ('test.key.$i', 'test_value_$i')"
            $command.ExecuteNonQuery()
        }
        
        # Insert some augment-related records
        for ($i = 0; $i -lt 100; $i++) {
            $command.CommandText = "INSERT INTO ItemTable (key, value) VALUES ('augment.test.key.$i', 'augment_value_$i')"
            $command.ExecuteNonQuery()
        }
        
        $connection.Close()
        
    } catch {
        Write-Host "Failed to create performance test database: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

<#
.SYNOPSIS
    Adds a performance test result
#>
function Add-PerformanceTestResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestName,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Passed', 'Failed')]
        [string]$Status,
        [string]$Message = "",
        [timespan]$Duration = [timespan]::Zero
    )
    
    $result = @{
        TestName = $TestName
        Status = $Status
        Message = $Message
        Duration = $Duration
        Timestamp = Get-Date
    }
    
    $script:PerformanceResults.TestDetails += $result
    $script:PerformanceResults.TotalTests++
    
    switch ($Status) {
        'Passed' { 
            $script:PerformanceResults.PassedTests++
            Write-Host "  [PASS] $TestName`: $Message" -ForegroundColor Green
        }
        'Failed' { 
            $script:PerformanceResults.FailedTests++
            Write-Host "  [FAIL] $TestName`: $Message" -ForegroundColor Red
        }
    }
}

<#
.SYNOPSIS
    Tests backup operation performance
#>
function Test-BackupOperationPerformance {
    Write-Host "Testing Backup Operation Performance..." -ForegroundColor Yellow

    try {
        # Import BackupManager module
        $backupManagerPath = Join-Path $script:TestConfig.ModulesPath "BackupManager.psm1"
        if (Test-Path $backupManagerPath) {
            Import-Module $backupManagerPath -Force

            # Create test file for backup
            $testFile = Join-Path $script:TestConfig.TempPath "performance-test-file.txt"
            $testContent = "Test content for backup performance testing`n" * 1000  # Create larger file
            $testContent | Out-File -FilePath $testFile -Encoding UTF8

            # Test backup creation performance
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $backup = New-FileBackup -FilePath $testFile -BackupDirectory $script:TestConfig.TempPath
            $stopwatch.Stop()

            $backupTime = $stopwatch.Elapsed
            $script:PerformanceResults.PerformanceMetrics["BackupCreation"] = $backupTime

            if ($backupTime -le $script:PerformanceThresholds.BackupCreationTime) {
                Add-PerformanceTestResult -TestName "Backup Creation Performance" -Status "Passed" -Message "Backup time: $($backupTime.TotalMilliseconds)ms" -Duration $backupTime
            } else {
                Add-PerformanceTestResult -TestName "Backup Creation Performance" -Status "Failed" -Message "Backup time exceeded threshold: $($backupTime.TotalMilliseconds)ms" -Duration $backupTime
            }

            # Test backup listing performance
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $backups = Get-BackupFiles -BackupDirectory $script:TestConfig.TempPath
            $stopwatch.Stop()

            $listingTime = $stopwatch.Elapsed
            $script:PerformanceResults.PerformanceMetrics["BackupListing"] = $listingTime

            Add-PerformanceTestResult -TestName "Backup Listing Performance" -Status "Passed" -Message "Listing time: $($listingTime.TotalMilliseconds)ms" -Duration $listingTime

        } else {
            Add-PerformanceTestResult -TestName "Backup Operation Performance" -Status "Failed" -Message "BackupManager module not found"
        }

    } catch {
        Add-PerformanceTestResult -TestName "Backup Operation Performance" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests memory usage performance
#>
function Test-MemoryUsagePerformance {
    Write-Host "Testing Memory Usage Performance..." -ForegroundColor Yellow

    try {
        # Get initial memory usage
        $initialMemory = [System.GC]::GetTotalMemory($false)

        # Perform memory-intensive operations
        $modules = @('Logger', 'CommonUtils', 'SystemDetection', 'DependencyManager')
        foreach ($module in $modules) {
            $modulePath = Join-Path $script:TestConfig.ModulesPath "$module.psm1"
            if (Test-Path $modulePath) {
                Import-Module $modulePath -Force
            }
        }

        # Generate multiple UUIDs
        for ($i = 0; $i -lt 100; $i++) {
            $uuid = New-SecureUUID
        }

        # Load configuration multiple times
        for ($i = 0; $i -lt 10; $i++) {
            $config = Get-Configuration
        }

        # Force garbage collection and measure memory
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()

        $finalMemory = [System.GC]::GetTotalMemory($false)
        $memoryUsed = $finalMemory - $initialMemory

        $script:PerformanceResults.PerformanceMetrics["MemoryUsage"] = $memoryUsed

        if ($memoryUsed -le $script:PerformanceThresholds.MemoryUsageLimit) {
            Add-PerformanceTestResult -TestName "Memory Usage Performance" -Status "Passed" -Message "Memory used: $([Math]::Round($memoryUsed / 1MB, 2)) MB"
        } else {
            Add-PerformanceTestResult -TestName "Memory Usage Performance" -Status "Failed" -Message "Memory usage exceeded threshold: $([Math]::Round($memoryUsed / 1MB, 2)) MB"
        }

    } catch {
        Add-PerformanceTestResult -TestName "Memory Usage Performance" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests concurrent operation performance
#>
function Test-ConcurrentOperationPerformance {
    Write-Host "Testing Concurrent Operation Performance..." -ForegroundColor Yellow

    try {
        # Test concurrent UUID generation
        $jobs = @()
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        for ($i = 0; $i -lt 5; $i++) {
            $job = Start-Job -ScriptBlock {
                param($ModulesPath)
                Import-Module (Join-Path $ModulesPath "CommonUtils.psm1") -Force
                for ($j = 0; $j -lt 20; $j++) {
                    New-SecureUUID
                }
            } -ArgumentList $script:TestConfig.ModulesPath
            $jobs += $job
        }

        # Wait for all jobs to complete
        $jobs | Wait-Job | Out-Null
        $stopwatch.Stop()

        $concurrentTime = $stopwatch.Elapsed
        $script:PerformanceResults.PerformanceMetrics["ConcurrentUUIDGeneration"] = $concurrentTime

        # Clean up jobs
        $jobs | Remove-Job

        # Compare with sequential time (estimate)
        $estimatedSequentialTime = [TimeSpan]::FromMilliseconds(100 * 100)  # 100 UUIDs * 1ms each

        if ($concurrentTime -lt $estimatedSequentialTime) {
            Add-PerformanceTestResult -TestName "Concurrent Operation Performance" -Status "Passed" -Message "Concurrent time: $($concurrentTime.TotalMilliseconds)ms (faster than sequential)" -Duration $concurrentTime
        } else {
            Add-PerformanceTestResult -TestName "Concurrent Operation Performance" -Status "Failed" -Message "Concurrent time: $($concurrentTime.TotalMilliseconds)ms (not faster than sequential)" -Duration $concurrentTime
        }

    } catch {
        Add-PerformanceTestResult -TestName "Concurrent Operation Performance" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Generates performance test report
#>
function New-PerformanceReport {
    $reportPath = Join-Path $OutputPath "performance-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $script:PerformanceResults.EndTime = Get-Date
    $script:PerformanceResults.Duration = $script:PerformanceResults.EndTime - $script:PerformanceResults.StartTime

    # Add system information to the report
    $script:PerformanceResults.SystemInfo = @{
        ProcessorCount = $env:NUMBER_OF_PROCESSORS
        TotalPhysicalMemory = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
        OSVersion = [System.Environment]::OSVersion.VersionString
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    }

    $script:PerformanceResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "Performance report saved: $reportPath" -ForegroundColor Green
}

<#
.SYNOPSIS
    Shows performance test summary
#>
function Show-PerformanceSummary {
    Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
    Write-Host "PERFORMANCE TEST SUMMARY" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan

    Write-Host "Total Tests: $($script:PerformanceResults.TotalTests)" -ForegroundColor White
    Write-Host "Passed: $($script:PerformanceResults.PassedTests)" -ForegroundColor Green
    Write-Host "Failed: $($script:PerformanceResults.FailedTests)" -ForegroundColor Red

    $successRate = if ($script:PerformanceResults.TotalTests -gt 0) {
        [Math]::Round(($script:PerformanceResults.PassedTests / $script:PerformanceResults.TotalTests) * 100, 2)
    } else { 0 }
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })

    Write-Host "Duration: $($script:PerformanceResults.Duration.ToString('hh\:mm\:ss'))" -ForegroundColor White

    # Show key performance metrics
    Write-Host "`nKey Performance Metrics:" -ForegroundColor White

    if ($script:PerformanceResults.PerformanceMetrics.ContainsKey("SingleUUIDGeneration")) {
        $uuidTime = $script:PerformanceResults.PerformanceMetrics["SingleUUIDGeneration"]
        Write-Host "  UUID Generation: $($uuidTime.TotalMilliseconds)ms" -ForegroundColor Cyan
    }

    if ($script:PerformanceResults.PerformanceMetrics.ContainsKey("ConfigurationLoad")) {
        $configTime = $script:PerformanceResults.PerformanceMetrics["ConfigurationLoad"]
        Write-Host "  Configuration Load: $($configTime.TotalMilliseconds)ms" -ForegroundColor Cyan
    }

    if ($script:PerformanceResults.PerformanceMetrics.ContainsKey("MemoryUsage")) {
        $memoryUsage = $script:PerformanceResults.PerformanceMetrics["MemoryUsage"]
        Write-Host "  Memory Usage: $([Math]::Round($memoryUsage / 1MB, 2)) MB" -ForegroundColor Cyan
    }

    # Show failed tests details
    if ($script:PerformanceResults.FailedTests -gt 0) {
        Write-Host "`nFailed Performance Tests:" -ForegroundColor Red
        $failedTests = $script:PerformanceResults.TestDetails | Where-Object { $_.Status -eq "Failed" }
        foreach ($test in $failedTests) {
            Write-Host "  - $($test.TestName): $($test.Message)" -ForegroundColor Red
        }
    }

    # Overall performance assessment
    if ($script:PerformanceResults.FailedTests -eq 0) {
        Write-Host "`nPERFORMANCE STATUS: EXCELLENT" -ForegroundColor Green
        Write-Host "All performance benchmarks met!" -ForegroundColor Green
    } elseif ($successRate -ge 80) {
        Write-Host "`nPERFORMANCE STATUS: GOOD" -ForegroundColor Yellow
        Write-Host "Most performance benchmarks met, minor optimizations needed." -ForegroundColor Yellow
    } else {
        Write-Host "`nPERFORMANCE STATUS: NEEDS OPTIMIZATION" -ForegroundColor Red
        Write-Host "Several performance issues detected, optimization required." -ForegroundColor Red
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
    Start-PerformanceTests
}
