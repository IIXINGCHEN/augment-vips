# Unit-Tests.ps1
#
# Description: Comprehensive unit tests for all PowerShell modules
# Tests individual module functions in isolation
#
# Author: Augment VIP Project
# Version: 2.0.0

param(
    [string]$LogLevel = 'Normal',
    [string]$OutputPath = ".\test-results"
)

# Test framework initialization
$script:TestResults = @{
    ModuleTests = @{}
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    SkippedTests = 0
}

# Test configuration
$script:TestConfig = @{
    ProjectRoot = Split-Path -Parent $PSScriptRoot
    ModulesPath = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\windows\modules"
    TestDataPath = Join-Path $PSScriptRoot "test-data"
    TempPath = Join-Path $env:TEMP "augment-vip-unit-tests"
}

# Required modules list
$script:RequiredModules = @(
    'Logger',
    'CommonUtils', 
    'SystemDetection',
    'DependencyManager',
    'VSCodeDiscovery',
    'BackupManager',
    'DatabaseCleaner',
    'TelemetryModifier',
    'UnifiedServices'
)

<#
.SYNOPSIS
    Main unit test execution function
#>
function Start-UnitTests {
    [CmdletBinding()]
    param()
    
    Write-Host "Starting Unit Tests for Augment VIP Cleaner" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    # Create temp directory
    if (-not (Test-Path $script:TestConfig.TempPath)) {
        New-Item -ItemType Directory -Path $script:TestConfig.TempPath -Force | Out-Null
    }
    
    try {
        # Test each module
        foreach ($moduleName in $script:RequiredModules) {
            Test-Module -ModuleName $moduleName
        }
        
        # Generate unit test report
        New-UnitTestReport
        
        # Show summary
        Show-UnitTestSummary
        
    } finally {
        # Cleanup
        if (Test-Path $script:TestConfig.TempPath) {
            Remove-Item -Path $script:TestConfig.TempPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

<#
.SYNOPSIS
    Tests a specific module
#>
function Test-Module {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )
    
    Write-Host "`nTesting Module: $ModuleName" -ForegroundColor Yellow
    Write-Host "-" * 40 -ForegroundColor Yellow
    
    $moduleResults = @{
        ModuleName = $ModuleName
        Tests = @()
        Passed = 0
        Failed = 0
        Skipped = 0
    }
    
    $modulePath = Join-Path $script:TestConfig.ModulesPath "$ModuleName.psm1"
    
    # Check if module file exists
    if (-not (Test-Path $modulePath)) {
        $testResult = New-TestResult -TestName "Module File Exists" -Status "Failed" -Message "Module file not found: $modulePath"
        $moduleResults.Tests += $testResult
        $moduleResults.Failed++
        $script:TestResults.ModuleTests[$ModuleName] = $moduleResults
        return
    }
    
    try {
        # Import module
        Import-Module $modulePath -Force -ErrorAction Stop
        $testResult = New-TestResult -TestName "Module Import" -Status "Passed" -Message "Module imported successfully"
        $moduleResults.Tests += $testResult
        $moduleResults.Passed++
        
        # Test module-specific functions
        switch ($ModuleName) {
            'Logger' { Test-LoggerModule -ModuleResults $moduleResults }
            'CommonUtils' { Test-CommonUtilsModule -ModuleResults $moduleResults }
            'SystemDetection' { Test-SystemDetectionModule -ModuleResults $moduleResults }
            'DependencyManager' { Test-DependencyManagerModule -ModuleResults $moduleResults }
            'VSCodeDiscovery' { Test-VSCodeDiscoveryModule -ModuleResults $moduleResults }
            'BackupManager' { Test-BackupManagerModule -ModuleResults $moduleResults }
            'DatabaseCleaner' { Test-DatabaseCleanerModule -ModuleResults $moduleResults }
            'TelemetryModifier' { Test-TelemetryModifierModule -ModuleResults $moduleResults }
            'UnifiedServices' { Test-UnifiedServicesModule -ModuleResults $moduleResults }
            default {
                $testResult = New-TestResult -TestName "Module Functions" -Status "Skipped" -Message "No specific tests defined for this module"
                $moduleResults.Tests += $testResult
                $moduleResults.Skipped++
            }
        }
        
    } catch {
        $testResult = New-TestResult -TestName "Module Import" -Status "Failed" -Message "Failed to import module: $($_.Exception.Message)"
        $moduleResults.Tests += $testResult
        $moduleResults.Failed++
    }
    
    $script:TestResults.ModuleTests[$ModuleName] = $moduleResults
    $script:TestResults.TotalTests += $moduleResults.Tests.Count
    $script:TestResults.PassedTests += $moduleResults.Passed
    $script:TestResults.FailedTests += $moduleResults.Failed
    $script:TestResults.SkippedTests += $moduleResults.Skipped
}

<#
.SYNOPSIS
    Creates a new test result object
#>
function New-TestResult {
    [CmdletBinding()]
    param(
        [string]$TestName,
        [ValidateSet('Passed', 'Failed', 'Skipped')]
        [string]$Status,
        [string]$Message = "",
        [string]$Details = "",
        [timespan]$Duration = [timespan]::Zero
    )
    
    return @{
        TestName = $TestName
        Status = $Status
        Message = $Message
        Details = $Details
        Duration = $Duration
        Timestamp = Get-Date
    }
}

<#
.SYNOPSIS
    Tests Logger module functions
#>
function Test-LoggerModule {
    param($ModuleResults)
    
    # Test Initialize-Logger
    try {
        Initialize-Logger -Level "Info" -EnableConsole $true
        $testResult = New-TestResult -TestName "Initialize-Logger" -Status "Passed" -Message "Logger initialized successfully"
        $ModuleResults.Tests += $testResult
        $ModuleResults.Passed++
    } catch {
        $testResult = New-TestResult -TestName "Initialize-Logger" -Status "Failed" -Message $_.Exception.Message
        $ModuleResults.Tests += $testResult
        $ModuleResults.Failed++
    }
    
    # Test logging functions
    $logFunctions = @('Write-LogInfo', 'Write-LogWarning', 'Write-LogError', 'Write-LogDebug')
    foreach ($func in $logFunctions) {
        try {
            & $func "Test message for $func"
            $testResult = New-TestResult -TestName $func -Status "Passed" -Message "Function executed successfully"
            $ModuleResults.Tests += $testResult
            $ModuleResults.Passed++
        } catch {
            $testResult = New-TestResult -TestName $func -Status "Failed" -Message $_.Exception.Message
            $ModuleResults.Tests += $testResult
            $ModuleResults.Failed++
        }
    }
    
    # Test Show functions
    $showFunctions = @('Show-SuccessMessage', 'Show-ErrorMessage', 'Show-WarningMessage', 'Show-InfoMessage')
    foreach ($func in $showFunctions) {
        try {
            & $func "Test message for $func"
            $testResult = New-TestResult -TestName $func -Status "Passed" -Message "Function executed successfully"
            $ModuleResults.Tests += $testResult
            $ModuleResults.Passed++
        } catch {
            $testResult = New-TestResult -TestName $func -Status "Failed" -Message $_.Exception.Message
            $ModuleResults.Tests += $testResult
            $ModuleResults.Failed++
        }
    }
}

<#
.SYNOPSIS
    Tests CommonUtils module functions
#>
function Test-CommonUtilsModule {
    param($ModuleResults)
    
    # Test New-SecureUUID
    try {
        $uuid = New-SecureUUID
        if ($uuid -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
            $testResult = New-TestResult -TestName "New-SecureUUID" -Status "Passed" -Message "Valid UUID generated: $uuid"
        } else {
            $testResult = New-TestResult -TestName "New-SecureUUID" -Status "Failed" -Message "Invalid UUID format: $uuid"
        }
        $ModuleResults.Tests += $testResult
        if ($testResult.Status -eq "Passed") { $ModuleResults.Passed++ } else { $ModuleResults.Failed++ }
    } catch {
        $testResult = New-TestResult -TestName "New-SecureUUID" -Status "Failed" -Message $_.Exception.Message
        $ModuleResults.Tests += $testResult
        $ModuleResults.Failed++
    }
    
    # Test New-SecureHexString
    try {
        $hexString = New-SecureHexString -Length 16
        if ($hexString -match '^[0-9a-f]{16}$') {
            $testResult = New-TestResult -TestName "New-SecureHexString" -Status "Passed" -Message "Valid hex string generated: $hexString"
        } else {
            $testResult = New-TestResult -TestName "New-SecureHexString" -Status "Failed" -Message "Invalid hex string format: $hexString"
        }
        $ModuleResults.Tests += $testResult
        if ($testResult.Status -eq "Passed") { $ModuleResults.Passed++ } else { $ModuleResults.Failed++ }
    } catch {
        $testResult = New-TestResult -TestName "New-SecureHexString" -Status "Failed" -Message $_.Exception.Message
        $ModuleResults.Tests += $testResult
        $ModuleResults.Failed++
    }
    
    # Test Test-SafePath
    $testPaths = @(
        @{ Path = "test.txt"; Expected = $true; Description = "Valid relative path" }
        @{ Path = "../test.txt"; Expected = $false; Description = "Parent directory traversal" }
        @{ Path = "C:\Windows\test.txt"; Expected = $false; Description = "Absolute path" }
        @{ Path = ""; Expected = $false; Description = "Empty path" }
    )
    
    foreach ($testPath in $testPaths) {
        try {
            $result = Test-SafePath -Path $testPath.Path
            if ($result -eq $testPath.Expected) {
                $testResult = New-TestResult -TestName "Test-SafePath ($($testPath.Description))" -Status "Passed" -Message "Path validation correct"
            } else {
                $testResult = New-TestResult -TestName "Test-SafePath ($($testPath.Description))" -Status "Failed" -Message "Expected $($testPath.Expected), got $result"
            }
            $ModuleResults.Tests += $testResult
            if ($testResult.Status -eq "Passed") { $ModuleResults.Passed++ } else { $ModuleResults.Failed++ }
        } catch {
            $testResult = New-TestResult -TestName "Test-SafePath ($($testPath.Description))" -Status "Failed" -Message $_.Exception.Message
            $ModuleResults.Tests += $testResult
            $ModuleResults.Failed++
        }
    }
}

<#
.SYNOPSIS
    Tests SystemDetection module functions
#>
function Test-SystemDetectionModule {
    param($ModuleResults)

    # Test Test-SystemCompatibility
    try {
        $compatibility = Test-SystemCompatibility
        $testResult = New-TestResult -TestName "Test-SystemCompatibility" -Status "Passed" -Message "System compatibility check completed"
        $ModuleResults.Tests += $testResult
        $ModuleResults.Passed++
    } catch {
        $testResult = New-TestResult -TestName "Test-SystemCompatibility" -Status "Failed" -Message $_.Exception.Message
        $ModuleResults.Tests += $testResult
        $ModuleResults.Failed++
    }

    # Test Get-SystemInformation
    try {
        $sysInfo = Get-SystemInformation
        if ($sysInfo -and $sysInfo.OSVersion) {
            $testResult = New-TestResult -TestName "Get-SystemInformation" -Status "Passed" -Message "System information retrieved"
        } else {
            $testResult = New-TestResult -TestName "Get-SystemInformation" -Status "Failed" -Message "Invalid system information returned"
        }
        $ModuleResults.Tests += $testResult
        if ($testResult.Status -eq "Passed") { $ModuleResults.Passed++ } else { $ModuleResults.Failed++ }
    } catch {
        $testResult = New-TestResult -TestName "Get-SystemInformation" -Status "Failed" -Message $_.Exception.Message
        $ModuleResults.Tests += $testResult
        $ModuleResults.Failed++
    }
}

<#
.SYNOPSIS
    Tests DependencyManager module functions
#>
function Test-DependencyManagerModule {
    param($ModuleResults)

    # Test Get-DependencyStatus
    try {
        $depStatus = Get-DependencyStatus
        $testResult = New-TestResult -TestName "Get-DependencyStatus" -Status "Passed" -Message "Dependency status retrieved"
        $ModuleResults.Tests += $testResult
        $ModuleResults.Passed++
    } catch {
        $testResult = New-TestResult -TestName "Get-DependencyStatus" -Status "Failed" -Message $_.Exception.Message
        $ModuleResults.Tests += $testResult
        $ModuleResults.Failed++
    }

    # Test Test-Dependency for known tools
    $dependencies = @('powershell', 'cmd')
    foreach ($dep in $dependencies) {
        try {
            $result = Test-Dependency -Name $dep
            $testResult = New-TestResult -TestName "Test-Dependency ($dep)" -Status "Passed" -Message "Dependency test completed"
            $ModuleResults.Tests += $testResult
            $ModuleResults.Passed++
        } catch {
            $testResult = New-TestResult -TestName "Test-Dependency ($dep)" -Status "Failed" -Message $_.Exception.Message
            $ModuleResults.Tests += $testResult
            $ModuleResults.Failed++
        }
    }
}

<#
.SYNOPSIS
    Tests VSCodeDiscovery module functions
#>
function Test-VSCodeDiscoveryModule {
    param($ModuleResults)

    # Test Find-VSCodeInstallations
    try {
        $installations = Find-VSCodeInstallations
        $testResult = New-TestResult -TestName "Find-VSCodeInstallations" -Status "Passed" -Message "VS Code discovery completed"
        $ModuleResults.Tests += $testResult
        $ModuleResults.Passed++
    } catch {
        $testResult = New-TestResult -TestName "Find-VSCodeInstallations" -Status "Failed" -Message $_.Exception.Message
        $ModuleResults.Tests += $testResult
        $ModuleResults.Failed++
    }

    # Test Get-VSCodeInstallation
    try {
        $installation = Get-VSCodeInstallation -InstallationType "Standard"
        $testResult = New-TestResult -TestName "Get-VSCodeInstallation" -Status "Passed" -Message "VS Code installation retrieval completed"
        $ModuleResults.Tests += $testResult
        $ModuleResults.Passed++
    } catch {
        $testResult = New-TestResult -TestName "Get-VSCodeInstallation" -Status "Failed" -Message $_.Exception.Message
        $ModuleResults.Tests += $testResult
        $ModuleResults.Failed++
    }
}

<#
.SYNOPSIS
    Tests BackupManager module functions
#>
function Test-BackupManagerModule {
    param($ModuleResults)

    # Create test file for backup testing
    $testFile = Join-Path $script:TestConfig.TempPath "test-backup-file.txt"
    "Test content for backup" | Out-File -FilePath $testFile -Encoding UTF8

    # Test New-FileBackup
    try {
        $backup = New-FileBackup -FilePath $testFile -BackupDirectory $script:TestConfig.TempPath
        if ($backup -and (Test-Path $backup.BackupPath)) {
            $testResult = New-TestResult -TestName "New-FileBackup" -Status "Passed" -Message "Backup created successfully"
        } else {
            $testResult = New-TestResult -TestName "New-FileBackup" -Status "Failed" -Message "Backup file not created"
        }
        $ModuleResults.Tests += $testResult
        if ($testResult.Status -eq "Passed") { $ModuleResults.Passed++ } else { $ModuleResults.Failed++ }
    } catch {
        $testResult = New-TestResult -TestName "New-FileBackup" -Status "Failed" -Message $_.Exception.Message
        $ModuleResults.Tests += $testResult
        $ModuleResults.Failed++
    }

    # Test Get-BackupFiles
    try {
        $backups = Get-BackupFiles -BackupDirectory $script:TestConfig.TempPath
        $testResult = New-TestResult -TestName "Get-BackupFiles" -Status "Passed" -Message "Backup files retrieved"
        $ModuleResults.Tests += $testResult
        $ModuleResults.Passed++
    } catch {
        $testResult = New-TestResult -TestName "Get-BackupFiles" -Status "Failed" -Message $_.Exception.Message
        $ModuleResults.Tests += $testResult
        $ModuleResults.Failed++
    }
}

<#
.SYNOPSIS
    Tests DatabaseCleaner module functions
#>
function Test-DatabaseCleanerModule {
    param($ModuleResults)

    # Test Show-CleaningPreview (safe operation)
    try {
        $preview = Show-CleaningPreview -DatabasePaths @()
        $testResult = New-TestResult -TestName "Show-CleaningPreview" -Status "Passed" -Message "Cleaning preview completed"
        $ModuleResults.Tests += $testResult
        $ModuleResults.Passed++
    } catch {
        $testResult = New-TestResult -TestName "Show-CleaningPreview" -Status "Failed" -Message $_.Exception.Message
        $ModuleResults.Tests += $testResult
        $ModuleResults.Failed++
    }

    # Test Get-CleaningPatterns
    try {
        $patterns = Get-CleaningPatterns
        if ($patterns -and $patterns.Count -gt 0) {
            $testResult = New-TestResult -TestName "Get-CleaningPatterns" -Status "Passed" -Message "Cleaning patterns retrieved"
        } else {
            $testResult = New-TestResult -TestName "Get-CleaningPatterns" -Status "Failed" -Message "No cleaning patterns found"
        }
        $ModuleResults.Tests += $testResult
        if ($testResult.Status -eq "Passed") { $ModuleResults.Passed++ } else { $ModuleResults.Failed++ }
    } catch {
        $testResult = New-TestResult -TestName "Get-CleaningPatterns" -Status "Failed" -Message $_.Exception.Message
        $ModuleResults.Tests += $testResult
        $ModuleResults.Failed++
    }
}

<#
.SYNOPSIS
    Tests TelemetryModifier module functions
#>
function Test-TelemetryModifierModule {
    param($ModuleResults)

    # Test New-SecureUUID (if available in this module)
    try {
        if (Get-Command "New-SecureUUID" -ErrorAction SilentlyContinue) {
            $uuid = New-SecureUUID
            if ($uuid -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
                $testResult = New-TestResult -TestName "New-SecureUUID (TelemetryModifier)" -Status "Passed" -Message "Valid UUID generated"
            } else {
                $testResult = New-TestResult -TestName "New-SecureUUID (TelemetryModifier)" -Status "Failed" -Message "Invalid UUID format"
            }
        } else {
            $testResult = New-TestResult -TestName "New-SecureUUID (TelemetryModifier)" -Status "Skipped" -Message "Function not available in this module"
        }
        $ModuleResults.Tests += $testResult
        if ($testResult.Status -eq "Passed") { $ModuleResults.Passed++ }
        elseif ($testResult.Status -eq "Failed") { $ModuleResults.Failed++ }
        else { $ModuleResults.Skipped++ }
    } catch {
        $testResult = New-TestResult -TestName "New-SecureUUID (TelemetryModifier)" -Status "Failed" -Message $_.Exception.Message
        $ModuleResults.Tests += $testResult
        $ModuleResults.Failed++
    }
}

<#
.SYNOPSIS
    Tests UnifiedServices module functions
#>
function Test-UnifiedServicesModule {
    param($ModuleResults)

    # Test module structure and exports
    try {
        $moduleInfo = Get-Module "UnifiedServices"
        if ($moduleInfo -and $moduleInfo.ExportedFunctions.Count -gt 0) {
            $testResult = New-TestResult -TestName "UnifiedServices Module Structure" -Status "Passed" -Message "Module has exported functions"
        } else {
            $testResult = New-TestResult -TestName "UnifiedServices Module Structure" -Status "Failed" -Message "Module has no exported functions"
        }
        $ModuleResults.Tests += $testResult
        if ($testResult.Status -eq "Passed") { $ModuleResults.Passed++ } else { $ModuleResults.Failed++ }
    } catch {
        $testResult = New-TestResult -TestName "UnifiedServices Module Structure" -Status "Failed" -Message $_.Exception.Message
        $ModuleResults.Tests += $testResult
        $ModuleResults.Failed++
    }
}

<#
.SYNOPSIS
    Generates unit test report
#>
function New-UnitTestReport {
    $reportPath = Join-Path $OutputPath "unit-test-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $script:TestResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "Unit test report saved: $reportPath" -ForegroundColor Green
}

<#
.SYNOPSIS
    Shows unit test summary
#>
function Show-UnitTestSummary {
    Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
    Write-Host "UNIT TEST SUMMARY" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan

    Write-Host "Total Tests: $($script:TestResults.TotalTests)" -ForegroundColor White
    Write-Host "Passed: $($script:TestResults.PassedTests)" -ForegroundColor Green
    Write-Host "Failed: $($script:TestResults.FailedTests)" -ForegroundColor Red
    Write-Host "Skipped: $($script:TestResults.SkippedTests)" -ForegroundColor Yellow

    $successRate = if ($script:TestResults.TotalTests -gt 0) {
        [Math]::Round(($script:TestResults.PassedTests / $script:TestResults.TotalTests) * 100, 2)
    } else { 0 }
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })

    # Show module-specific results
    Write-Host "`nModule Results:" -ForegroundColor White
    foreach ($moduleName in $script:TestResults.ModuleTests.Keys) {
        $moduleResult = $script:TestResults.ModuleTests[$moduleName]
        $moduleSuccessRate = if ($moduleResult.Tests.Count -gt 0) {
            [Math]::Round(($moduleResult.Passed / $moduleResult.Tests.Count) * 100, 2)
        } else { 0 }

        $color = if ($moduleSuccessRate -ge 90) { "Green" } elseif ($moduleSuccessRate -ge 70) { "Yellow" } else { "Red" }
        Write-Host "  $moduleName`: $($moduleResult.Passed)/$($moduleResult.Tests.Count) ($moduleSuccessRate%)" -ForegroundColor $color
    }

    if ($script:TestResults.FailedTests -eq 0) {
        Write-Host "`nALL UNIT TESTS PASSED!" -ForegroundColor Green
    } else {
        Write-Host "`n$($script:TestResults.FailedTests) TESTS FAILED - Review results for details" -ForegroundColor Red
    }
}

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    Start-UnitTests
}
