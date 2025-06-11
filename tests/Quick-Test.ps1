# Quick-Test.ps1
#
# Description: Quick validation test for the test framework
# Validates that all test components are working correctly
#
# Author: Augment VIP Project
# Version: 2.0.0

param(
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

# Test configuration
$script:TestConfig = @{
    ProjectRoot = Split-Path -Parent $PSScriptRoot
    ModulesPath = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\windows\modules"
    TestsPath = $PSScriptRoot
}

Write-Host "Augment VIP Cleaner - Quick Test Validation" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

$testResults = @{
    Total = 0
    Passed = 0
    Failed = 0
    Details = @()
}

function Test-Component {
    param(
        [string]$Name,
        [scriptblock]$TestBlock
    )
    
    $testResults.Total++
    
    try {
        $result = & $TestBlock
        if ($result -ne $false) {
            $testResults.Passed++
            Write-Host "✓ $Name" -ForegroundColor Green
            $testResults.Details += @{ Name = $Name; Status = "Passed"; Message = "" }
        } else {
            $testResults.Failed++
            Write-Host "✗ $Name" -ForegroundColor Red
            $testResults.Details += @{ Name = $Name; Status = "Failed"; Message = "Test returned false" }
        }
    } catch {
        $testResults.Failed++
        Write-Host "✗ $Name`: $($_.Exception.Message)" -ForegroundColor Red
        $testResults.Details += @{ Name = $Name; Status = "Failed"; Message = $_.Exception.Message }
    }
}

# Test 1: Module Files Exist
Test-Component "Module Files Exist" {
    $requiredModules = @('Logger', 'CommonUtils', 'SystemDetection', 'DependencyManager', 'VSCodeDiscovery', 'BackupManager', 'DatabaseCleaner', 'TelemetryModifier', 'UnifiedServices')
    $missingModules = @()
    
    foreach ($module in $requiredModules) {
        $modulePath = Join-Path $script:TestConfig.ModulesPath "$module.psm1"
        if (-not (Test-Path $modulePath)) {
            $missingModules += $module
        }
    }
    
    if ($missingModules.Count -eq 0) {
        return $true
    } else {
        throw "Missing modules: $($missingModules -join ', ')"
    }
}

# Test 2: Logger Module Import
Test-Component "Logger Module Import" {
    $loggerPath = Join-Path $script:TestConfig.ModulesPath "Logger.psm1"
    Import-Module $loggerPath -Force -Global
    return $true
}

# Test 3: CommonUtils Module Import
Test-Component "CommonUtils Module Import" {
    $commonUtilsPath = Join-Path $script:TestConfig.ModulesPath "CommonUtils.psm1"
    Import-Module $commonUtilsPath -Force -Global
    return $true
}

# Test 4: Logger Initialization
Test-Component "Logger Initialization" {
    Initialize-Logger -Level "Info" -EnableConsole $false
    return $true
}

# Test 5: UUID Generation
Test-Component "UUID Generation" {
    $uuid = New-SecureUUID
    if ($uuid -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
        return $true
    } else {
        throw "Invalid UUID format: $uuid"
    }
}

# Test 6: Configuration Loading
Test-Component "Configuration Loading" {
    $config = Get-Configuration
    if ($config) {
        return $true
    } else {
        throw "Configuration loading failed"
    }
}

# Test 7: Path Validation
Test-Component "Path Validation" {
    $safeResult = Test-SafePath -Path "test.txt"
    $unsafeResult = Test-SafePath -Path "../test.txt"
    
    if ($safeResult -eq $true -and $unsafeResult -eq $false) {
        return $true
    } else {
        throw "Path validation not working correctly"
    }
}

# Test 8: Test Framework Files Exist
Test-Component "Test Framework Files Exist" {
    $testFiles = @(
        'Master-Test-Suite.ps1',
        'Unit-Tests.ps1',
        'Integration-Tests.ps1',
        'Security-Tests.ps1',
        'Performance-Tests.ps1',
        'Cross-Platform-Tests.ps1',
        'test-config.json'
    )
    
    $missingFiles = @()
    foreach ($file in $testFiles) {
        $filePath = Join-Path $script:TestConfig.TestsPath $file
        if (-not (Test-Path $filePath)) {
            $missingFiles += $file
        }
    }
    
    if ($missingFiles.Count -eq 0) {
        return $true
    } else {
        throw "Missing test files: $($missingFiles -join ', ')"
    }
}

# Test 9: Test Configuration Valid
Test-Component "Test Configuration Valid" {
    $configPath = Join-Path $script:TestConfig.TestsPath "test-config.json"
    $testConfig = Get-Content $configPath | ConvertFrom-Json
    
    if ($testConfig.version -and $testConfig.testSuites) {
        return $true
    } else {
        throw "Invalid test configuration"
    }
}

# Test 10: Logging Functions
Test-Component "Logging Functions" {
    Write-LogInfo "Test info message"
    Write-LogWarning "Test warning message"
    Show-SuccessMessage "Test success message"
    return $true
}

# Test 11: Error Handling
Test-Component "Error Handling" {
    $result = Invoke-SafeOperation -ScriptBlock {
        throw "Test error"
    } -ErrorMessage "Test error handling" -ReturnOnError "Handled"
    
    if ($result -eq "Handled") {
        return $true
    } else {
        throw "Error handling not working"
    }
}

# Test 12: System Detection
Test-Component "System Detection" {
    $systemDetectionPath = Join-Path $script:TestConfig.ModulesPath "SystemDetection.psm1"
    if (Test-Path $systemDetectionPath) {
        Import-Module $systemDetectionPath -Force -Global
        $sysInfo = Get-SystemInformation
        if ($sysInfo -and $sysInfo.OSVersion) {
            return $true
        } else {
            throw "System information not retrieved"
        }
    } else {
        throw "SystemDetection module not found"
    }
}

# Show Results
Write-Host "`n" + "=" * 50 -ForegroundColor Cyan
Write-Host "QUICK TEST RESULTS" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

Write-Host "Total Tests: $($testResults.Total)" -ForegroundColor White
Write-Host "Passed: $($testResults.Passed)" -ForegroundColor Green
Write-Host "Failed: $($testResults.Failed)" -ForegroundColor Red

$successRate = if ($testResults.Total -gt 0) { 
    [Math]::Round(($testResults.Passed / $testResults.Total) * 100, 2) 
} else { 0 }

Write-Host "Success Rate: $successRate%" -ForegroundColor $(
    if ($successRate -eq 100) { "Green" } 
    elseif ($successRate -ge 80) { "Yellow" } 
    else { "Red" }
)

if ($Verbose -and $testResults.Failed -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    $failedTests = $testResults.Details | Where-Object { $_.Status -eq "Failed" }
    foreach ($test in $failedTests) {
        Write-Host "  - $($test.Name): $($test.Message)" -ForegroundColor Red
    }
}

if ($testResults.Failed -eq 0) {
    Write-Host "`n🎉 ALL TESTS PASSED! Test framework is ready for production use." -ForegroundColor Green
    Write-Host "You can now run the full test suite with:" -ForegroundColor Cyan
    Write-Host "  .\tests\Master-Test-Suite.ps1 -RunAll -GenerateReport" -ForegroundColor White
    exit 0
} else {
    Write-Host "`n❌ Some tests failed. Please review and fix issues before proceeding." -ForegroundColor Red
    exit 1
}
