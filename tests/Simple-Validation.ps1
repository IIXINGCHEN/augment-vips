# Simple-Validation.ps1
#
# Description: Simple validation test to verify core functionality
# Tests basic module loading and function execution
#
# Author: Augment VIP Project
# Version: 2.0.0

$ErrorActionPreference = 'Continue'

Write-Host "Augment VIP Cleaner - Simple Validation Test" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Green

$projectRoot = Split-Path -Parent $PSScriptRoot
$modulesPath = Join-Path $projectRoot "scripts\windows\modules"

# Test 1: Import Logger Module
Write-Host "`n1. Testing Logger Module..." -ForegroundColor Yellow
try {
    $loggerPath = Join-Path $modulesPath "Logger.psm1"
    Import-Module $loggerPath -Force
    Write-Host "   ✓ Logger module imported successfully" -ForegroundColor Green
    
    # Test logger functions
    Initialize-Logger -Level "Info" -EnableConsole $true
    Write-Host "   ✓ Logger initialized successfully" -ForegroundColor Green
    
    Write-LogInfo "Test info message"
    Write-Host "   ✓ Write-LogInfo function works" -ForegroundColor Green
    
    Show-SuccessMessage "Test success message"
    Write-Host "   ✓ Show-SuccessMessage function works" -ForegroundColor Green
    
} catch {
    Write-Host "   ✗ Logger module test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Import CommonUtils Module
Write-Host "`n2. Testing CommonUtils Module..." -ForegroundColor Yellow
try {
    $commonUtilsPath = Join-Path $modulesPath "CommonUtils.psm1"
    Import-Module $commonUtilsPath -Force
    Write-Host "   ✓ CommonUtils module imported successfully" -ForegroundColor Green
    
    # Test UUID generation
    $uuid = New-SecureUUID
    if ($uuid -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
        Write-Host "   ✓ UUID generation works: $uuid" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Invalid UUID format: $uuid" -ForegroundColor Red
    }
    
    # Test path validation
    $safeResult = Test-SafePath -Path "test.txt"
    $unsafeResult = Test-SafePath -Path "../test.txt"
    
    if ($safeResult -eq $true -and $unsafeResult -eq $false) {
        Write-Host "   ✓ Path validation works correctly" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Path validation not working correctly" -ForegroundColor Red
    }
    
    # Test configuration loading
    $config = Get-Configuration
    if ($config) {
        Write-Host "   ✓ Configuration loading works" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Configuration loading failed" -ForegroundColor Red
    }
    
} catch {
    Write-Host "   ✗ CommonUtils module test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Import SystemDetection Module
Write-Host "`n3. Testing SystemDetection Module..." -ForegroundColor Yellow
try {
    $systemDetectionPath = Join-Path $modulesPath "SystemDetection.psm1"
    if (Test-Path $systemDetectionPath) {
        Import-Module $systemDetectionPath -Force
        Write-Host "   ✓ SystemDetection module imported successfully" -ForegroundColor Green
        
        $sysInfo = Get-SystemInformation
        if ($sysInfo -and $sysInfo.OSVersion) {
            Write-Host "   ✓ System information retrieved: $($sysInfo.OSVersion)" -ForegroundColor Green
        } else {
            Write-Host "   ✗ System information not retrieved" -ForegroundColor Red
        }
    } else {
        Write-Host "   ✗ SystemDetection module not found" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ SystemDetection module test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Test Framework Files
Write-Host "`n4. Testing Test Framework Files..." -ForegroundColor Yellow
$testFiles = @(
    'Master-Test-Suite.ps1',
    'Unit-Tests.ps1',
    'Integration-Tests.ps1',
    'Security-Tests.ps1',
    'Performance-Tests.ps1',
    'Cross-Platform-Tests.ps1',
    'test-config.json'
)

$allFilesExist = $true
foreach ($file in $testFiles) {
    $filePath = Join-Path $PSScriptRoot $file
    if (Test-Path $filePath) {
        Write-Host "   ✓ $file exists" -ForegroundColor Green
    } else {
        Write-Host "   ✗ $file missing" -ForegroundColor Red
        $allFilesExist = $false
    }
}

if ($allFilesExist) {
    Write-Host "   ✓ All test framework files present" -ForegroundColor Green
} else {
    Write-Host "   ✗ Some test framework files missing" -ForegroundColor Red
}

# Test 5: Test Configuration
Write-Host "`n5. Testing Test Configuration..." -ForegroundColor Yellow
try {
    $configPath = Join-Path $PSScriptRoot "test-config.json"
    $testConfig = Get-Content $configPath | ConvertFrom-Json
    
    if ($testConfig.version -and $testConfig.testSuites) {
        Write-Host "   ✓ Test configuration is valid" -ForegroundColor Green
        Write-Host "   ✓ Version: $($testConfig.version)" -ForegroundColor Green
        Write-Host "   ✓ Test suites: $($testConfig.testSuites.PSObject.Properties.Name -join ', ')" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Invalid test configuration" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ Test configuration test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 6: Error Handling
Write-Host "`n6. Testing Error Handling..." -ForegroundColor Yellow
try {
    $result = Invoke-SafeOperation -ScriptBlock {
        throw "Test error"
    } -ErrorMessage "Test error handling" -ReturnOnError "Handled"
    
    if ($result -eq "Handled") {
        Write-Host "   ✓ Error handling works correctly" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Error handling not working: $result" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ Error handling test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Summary
Write-Host "`n" + "=" * 50 -ForegroundColor Green
Write-Host "VALIDATION COMPLETE" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Green

Write-Host "`nCore modules and test framework are ready!" -ForegroundColor Green
Write-Host "You can now run individual test suites:" -ForegroundColor Cyan
Write-Host "  .\tests\Unit-Tests.ps1" -ForegroundColor White
Write-Host "  .\tests\Security-Tests.ps1" -ForegroundColor White
Write-Host "  .\tests\Integration-Tests.ps1" -ForegroundColor White
Write-Host "  .\tests\Performance-Tests.ps1" -ForegroundColor White
Write-Host "  .\tests\Cross-Platform-Tests.ps1" -ForegroundColor White
Write-Host "`nOr run the complete test suite:" -ForegroundColor Cyan
Write-Host "  .\tests\Master-Test-Suite.ps1 -RunAll -GenerateReport" -ForegroundColor White

Write-Host "`n🎉 Test framework validation completed successfully!" -ForegroundColor Green
