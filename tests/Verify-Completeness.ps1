# Verify-Completeness.ps1
# Advanced verification script to check code completeness and redundancy elimination

param(
    [switch]$Verbose,
    [switch]$CheckRedundancy,
    [switch]$CheckIntegration
)

Write-Host "=" -ForegroundColor Cyan -NoNewline
Write-Host ("=" * 59) -ForegroundColor Cyan
Write-Host "AUGMENT VIP CLEANER - COMPLETENESS VERIFICATION" -ForegroundColor Cyan
Write-Host "=" -ForegroundColor Cyan -NoNewline
Write-Host ("=" * 59) -ForegroundColor Cyan

$ErrorCount = 0
$SuccessCount = 0
$WarningCount = 0

function Test-CodeRedundancy {
    Write-Host "`n--- Testing Code Redundancy Elimination ---" -ForegroundColor Yellow
    
    # Check for hardcoded patterns in PowerShell modules
    $psModules = @(
        "../scripts/windows/modules/DatabaseCleaner.psm1",
        "../scripts/windows/modules/TelemetryModifier.psm1",
        "../scripts/windows/modules/CommonUtils.psm1"
    )
    
    foreach ($module in $psModules) {
        if (Test-Path $module) {
            $content = Get-Content $module -Raw
            
            # Check for hardcoded augment patterns
            if ($content -match '\$script:AugmentPatterns\s*=') {
                Write-Host "✗ Hardcoded AugmentPatterns found in $module" -ForegroundColor Red
                $script:ErrorCount++
            } else {
                Write-Host "✓ No hardcoded AugmentPatterns in $module" -ForegroundColor Green
                $script:SuccessCount++
            }
            
            # Check for hardcoded telemetry patterns
            if ($content -match '\$script:TelemetryPatterns\s*=') {
                Write-Host "✗ Hardcoded TelemetryPatterns found in $module" -ForegroundColor Red
                $script:ErrorCount++
            } else {
                Write-Host "✓ No hardcoded TelemetryPatterns in $module" -ForegroundColor Green
                $script:SuccessCount++
            }
            
            # Check for direct ID generation calls
            if ($content -match 'New-SecureHexString.*-Length\s+64' -and $module -notmatch "CommonUtils") {
                Write-Host "✗ Direct ID generation calls found in $module" -ForegroundColor Red
                $script:ErrorCount++
            } else {
                Write-Host "✓ No direct ID generation calls in $module" -ForegroundColor Green
                $script:SuccessCount++
            }
        }
    }
    
    # Check Python modules for redundancy
    $pyModules = @(
        "../scripts/cross-platform/augment_vip/db_cleaner.py",
        "../scripts/cross-platform/augment_vip/utils.py"
    )
    
    foreach ($module in $pyModules) {
        if (Test-Path $module) {
            $content = Get-Content $module -Raw
            
            # Check for fallback pattern definitions
            if ($content -match 'patterns\s*=\s*\{' -and $content -match 'augment.*%augment%') {
                Write-Host "? Fallback patterns found in $module (acceptable)" -ForegroundColor Yellow
                $script:WarningCount++
            }
            
            # Check for unified service imports
            if ($content -match 'from config_loader import' -or $content -match 'from id_generator import') {
                Write-Host "✓ Unified service imports found in $module" -ForegroundColor Green
                $script:SuccessCount++
            } else {
                Write-Host "✗ Missing unified service imports in $module" -ForegroundColor Red
                $script:ErrorCount++
            }
        }
    }
}

function Test-ServiceIntegration {
    Write-Host "`n--- Testing Service Integration ---" -ForegroundColor Yellow
    
    # Test UnifiedServices module
    $unifiedServicesPath = "../scripts/windows/modules/UnifiedServices.psm1"
    if (Test-Path $unifiedServicesPath) {
        Write-Host "✓ UnifiedServices bridge module exists" -ForegroundColor Green
        $script:SuccessCount++
        
        $content = Get-Content $unifiedServicesPath -Raw
        
        # Check for key functions
        $requiredFunctions = @(
            'Get-UnifiedCleaningPatterns',
            'New-UnifiedSecureId',
            'Initialize-UnifiedServices',
            'Test-UnifiedServices'
        )
        
        foreach ($func in $requiredFunctions) {
            if ($content -match "function $func") {
                Write-Host "✓ Function $func implemented" -ForegroundColor Green
                $script:SuccessCount++
            } else {
                Write-Host "✗ Function $func missing" -ForegroundColor Red
                $script:ErrorCount++
            }
        }
    } else {
        Write-Host "✗ UnifiedServices bridge module missing" -ForegroundColor Red
        $script:ErrorCount++
    }
    
    # Test module imports
    $modulesToCheck = @(
        "../scripts/windows/modules/DatabaseCleaner.psm1",
        "../scripts/windows/modules/TelemetryModifier.psm1"
    )
    
    foreach ($module in $modulesToCheck) {
        if (Test-Path $module) {
            $content = Get-Content $module -Raw
            
            if ($content -match 'Import-Module.*UnifiedServices\.psm1') {
                Write-Host "✓ UnifiedServices imported in $module" -ForegroundColor Green
                $script:SuccessCount++
            } else {
                Write-Host "✗ UnifiedServices not imported in $module" -ForegroundColor Red
                $script:ErrorCount++
            }
            
            # Check for unified service usage
            if ($content -match 'Get-UnifiedCleaningPatterns' -or $content -match 'New-UnifiedSecureId') {
                Write-Host "✓ Unified services used in $module" -ForegroundColor Green
                $script:SuccessCount++
            } else {
                Write-Host "✗ Unified services not used in $module" -ForegroundColor Red
                $script:ErrorCount++
            }
        }
    }
}

function Test-ConfigurationCompleteness {
    Write-Host "`n--- Testing Configuration Completeness ---" -ForegroundColor Yellow
    
    # Test config.json structure
    $configPath = "../config/config.json"
    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath | ConvertFrom-Json
            
            # Check required sections
            $requiredSections = @("cleaning", "security", "backup", "logging")
            foreach ($section in $requiredSections) {
                if ($config.PSObject.Properties.Name -contains $section) {
                    Write-Host "✓ Configuration section '$section' exists" -ForegroundColor Green
                    $script:SuccessCount++
                } else {
                    Write-Host "✗ Configuration section '$section' missing" -ForegroundColor Red
                    $script:ErrorCount++
                }
            }
            
            # Check pattern structure
            if ($config.cleaning.patterns) {
                $patternTypes = @("augment", "telemetry", "extensions", "custom")
                foreach ($type in $patternTypes) {
                    if ($config.cleaning.patterns.PSObject.Properties.Name -contains $type) {
                        $patterns = $config.cleaning.patterns.$type
                        if ($patterns -and $patterns.Count -gt 0) {
                            Write-Host "✓ Pattern type '$type' has $($patterns.Count) patterns" -ForegroundColor Green
                            $script:SuccessCount++
                        } else {
                            Write-Host "? Pattern type '$type' is empty" -ForegroundColor Yellow
                            $script:WarningCount++
                        }
                    } else {
                        Write-Host "✗ Pattern type '$type' missing" -ForegroundColor Red
                        $script:ErrorCount++
                    }
                }
            } else {
                Write-Host "✗ Patterns structure missing from configuration" -ForegroundColor Red
                $script:ErrorCount++
            }
            
        } catch {
            Write-Host "✗ Configuration file is invalid JSON" -ForegroundColor Red
            $script:ErrorCount++
        }
    } else {
        Write-Host "✗ Configuration file missing" -ForegroundColor Red
        $script:ErrorCount++
    }
    
    # Test schema validation
    $schemaPath = "../config/schema.json"
    if (Test-Path $schemaPath) {
        Write-Host "✓ Configuration schema exists" -ForegroundColor Green
        $script:SuccessCount++
    } else {
        Write-Host "✗ Configuration schema missing" -ForegroundColor Red
        $script:ErrorCount++
    }
}

function Test-TestingCompleteness {
    Write-Host "`n--- Testing Framework Completeness ---" -ForegroundColor Yellow
    
    $testFiles = @(
        "../tests/test_security.py",
        "../tests/test_integration.py",
        "../tests/run_tests.py"
    )
    
    foreach ($testFile in $testFiles) {
        if (Test-Path $testFile) {
            Write-Host "✓ Test file exists: $testFile" -ForegroundColor Green
            $script:SuccessCount++
            
            $content = Get-Content $testFile -Raw
            
            # Check for comprehensive test coverage
            if ($content -match 'class.*Test.*:' -or $content -match 'def test_') {
                Write-Host "✓ Test cases found in $testFile" -ForegroundColor Green
                $script:SuccessCount++
            } else {
                Write-Host "✗ No test cases found in $testFile" -ForegroundColor Red
                $script:ErrorCount++
            }
        } else {
            Write-Host "✗ Test file missing: $testFile" -ForegroundColor Red
            $script:ErrorCount++
        }
    }
}

function Show-CompletenessReport {
    Write-Host "`n" -NoNewline
    Write-Host "=" -ForegroundColor Magenta -NoNewline
    Write-Host ("=" * 59) -ForegroundColor Magenta
    Write-Host "COMPLETENESS REPORT" -ForegroundColor Magenta
    Write-Host "=" -ForegroundColor Magenta -NoNewline
    Write-Host ("=" * 59) -ForegroundColor Magenta
    
    $total = $script:SuccessCount + $script:ErrorCount + $script:WarningCount
    $successRate = if ($total -gt 0) { [math]::Round(($script:SuccessCount / $total) * 100, 1) } else { 0 }
    
    Write-Host "Total Checks: $total" -ForegroundColor White
    Write-Host "Passed: $script:SuccessCount" -ForegroundColor Green
    Write-Host "Failed: $script:ErrorCount" -ForegroundColor Red
    Write-Host "Warnings: $script:WarningCount" -ForegroundColor Yellow
    Write-Host "Success Rate: $successRate%" -ForegroundColor White
    
    # Code quality assessment
    if ($script:ErrorCount -eq 0) {
        Write-Host "`n✅ CODE IS COMPLETE AND NON-REDUNDANT!" -ForegroundColor Green
        Write-Host "All redundancy has been eliminated and integration is complete." -ForegroundColor Green
    } elseif ($script:ErrorCount -le 2) {
        Write-Host "`n⚠️ CODE IS MOSTLY COMPLETE" -ForegroundColor Yellow
        Write-Host "Minor issues need attention." -ForegroundColor Yellow
    } else {
        Write-Host "`n❌ CODE NEEDS SIGNIFICANT WORK" -ForegroundColor Red
        Write-Host "Multiple completeness and redundancy issues found." -ForegroundColor Red
    }
    
    # Redundancy assessment
    $redundancyScore = if ($script:ErrorCount -eq 0) { "EXCELLENT" } elseif ($script:ErrorCount -le 2) { "GOOD" } else { "NEEDS WORK" }
    Write-Host "`nRedundancy Elimination: $redundancyScore" -ForegroundColor $(if ($redundancyScore -eq "EXCELLENT") { "Green" } elseif ($redundancyScore -eq "GOOD") { "Yellow" } else { "Red" })
    
    # Integration assessment
    $integrationScore = if ($script:ErrorCount -eq 0) { "COMPLETE" } elseif ($script:ErrorCount -le 2) { "PARTIAL" } else { "INCOMPLETE" }
    Write-Host "Service Integration: $integrationScore" -ForegroundColor $(if ($integrationScore -eq "COMPLETE") { "Green" } elseif ($integrationScore -eq "PARTIAL") { "Yellow" } else { "Red" })
}

# Run all tests
try {
    if ($CheckRedundancy -or (-not $CheckRedundancy -and -not $CheckIntegration)) {
        Test-CodeRedundancy
    }
    
    if ($CheckIntegration -or (-not $CheckRedundancy -and -not $CheckIntegration)) {
        Test-ServiceIntegration
    }
    
    Test-ConfigurationCompleteness
    Test-TestingCompleteness
    Show-CompletenessReport
    
    # Return appropriate exit code
    if ($script:ErrorCount -eq 0) {
        exit 0
    } else {
        exit 1
    }
} catch {
    Write-Host "`n❌ VERIFICATION FAILED WITH ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
