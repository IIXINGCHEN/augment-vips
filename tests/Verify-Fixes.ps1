# Verify-Fixes.ps1
# PowerShell script to verify all implemented fixes

param(
    [switch]$Verbose
)

Write-Host "=" -ForegroundColor Green -NoNewline
Write-Host ("=" * 59) -ForegroundColor Green
Write-Host "AUGMENT VIP CLEANER - FIX VERIFICATION" -ForegroundColor Green
Write-Host "=" -ForegroundColor Green -NoNewline
Write-Host ("=" * 59) -ForegroundColor Green

$ErrorCount = 0
$SuccessCount = 0

function Test-FileExists {
    param([string]$FilePath, [string]$Description)
    
    if (Test-Path $FilePath) {
        Write-Host "✓ $Description" -ForegroundColor Green
        $script:SuccessCount++
        return $true
    } else {
        Write-Host "✗ $Description - File not found: $FilePath" -ForegroundColor Red
        $script:ErrorCount++
        return $false
    }
}

function Test-ConfigurationStructure {
    Write-Host "`n--- Testing Configuration Structure ---" -ForegroundColor Yellow
    
    $configPath = "../config/config.json"
    if (Test-FileExists $configPath "Configuration file exists") {
        try {
            $config = Get-Content $configPath | ConvertFrom-Json
            
            # Test new structure
            if ($config.cleaning.patterns) {
                Write-Host "✓ New configuration structure implemented" -ForegroundColor Green
                $script:SuccessCount++
                
                # Test pattern categories
                $categories = @("augment", "telemetry", "extensions", "custom")
                foreach ($category in $categories) {
                    if ($config.cleaning.patterns.PSObject.Properties.Name -contains $category) {
                        Write-Host "✓ Pattern category '$category' exists" -ForegroundColor Green
                        $script:SuccessCount++
                    } else {
                        Write-Host "✗ Pattern category '$category' missing" -ForegroundColor Red
                        $script:ErrorCount++
                    }
                }
            } else {
                Write-Host "✗ New configuration structure not implemented" -ForegroundColor Red
                $script:ErrorCount++
            }
        } catch {
            Write-Host "✗ Configuration file is invalid JSON" -ForegroundColor Red
            $script:ErrorCount++
        }
    }
}

function Test-SecurityFixes {
    Write-Host "`n--- Testing Security Fixes ---" -ForegroundColor Yellow
    
    # Test SQL injection fix in db_cleaner.py
    $dbCleanerPath = "../scripts/cross-platform/augment_vip/db_cleaner.py"
    if (Test-FileExists $dbCleanerPath "Database cleaner file exists") {
        $content = Get-Content $dbCleanerPath -Raw
        
        # Check for parameterized query fix
        if ($content -match 'cursor\.execute\("SELECT COUNT\(\*\) FROM ItemTable WHERE key LIKE \?", \(') {
            Write-Host "✓ SQL injection fix implemented (parameterized queries)" -ForegroundColor Green
            $script:SuccessCount++
        } else {
            Write-Host "✗ SQL injection fix not found" -ForegroundColor Red
            $script:ErrorCount++
        }
        
        # Check for config loader import
        if ($content -match 'from config_loader import') {
            Write-Host "✓ Configuration-driven patterns implemented" -ForegroundColor Green
            $script:SuccessCount++
        } else {
            Write-Host "✗ Configuration-driven patterns not implemented" -ForegroundColor Red
            $script:ErrorCount++
        }
    }
    
    # Test input validation in utils.py
    $utilsPath = "../scripts/cross-platform/augment_vip/utils.py"
    if (Test-FileExists $utilsPath "Utils file exists") {
        $content = Get-Content $utilsPath -Raw
        
        if ($content -match 'def validate_file_path') {
            Write-Host "✓ Input validation functions implemented" -ForegroundColor Green
            $script:SuccessCount++
        } else {
            Write-Host "✗ Input validation functions not found" -ForegroundColor Red
            $script:ErrorCount++
        }
        
        if ($content -match 'def sanitize_input') {
            Write-Host "✓ Input sanitization functions implemented" -ForegroundColor Green
            $script:SuccessCount++
        } else {
            Write-Host "✗ Input sanitization functions not found" -ForegroundColor Red
            $script:ErrorCount++
        }
        
        if ($content -match 'def sanitize_error_message') {
            Write-Host "✓ Error message sanitization implemented" -ForegroundColor Green
            $script:SuccessCount++
        } else {
            Write-Host "✗ Error message sanitization not found" -ForegroundColor Red
            $script:ErrorCount++
        }
    }
}

function Test-CodeConsolidation {
    Write-Host "`n--- Testing Code Consolidation ---" -ForegroundColor Yellow
    
    # Test unified config loader
    Test-FileExists "../scripts/common/config_loader.py" "Unified configuration loader created"
    
    # Test unified ID generator
    Test-FileExists "../scripts/common/id_generator.py" "Unified ID generator created"
    
    # Test transaction manager
    Test-FileExists "../scripts/common/transaction_manager.py" "Transaction manager created"
    
    # Test schema validation
    Test-FileExists "../config/schema.json" "Configuration schema created"
}

function Test-TestingFramework {
    Write-Host "`n--- Testing Framework Implementation ---" -ForegroundColor Yellow
    
    Test-FileExists "../tests/test_security.py" "Security tests created"
    Test-FileExists "../tests/test_integration.py" "Integration tests created"
    Test-FileExists "../tests/run_tests.py" "Test runner created"
}

function Test-DocumentationUpdates {
    Write-Host "`n--- Testing Documentation ---" -ForegroundColor Yellow
    
    Test-FileExists "../AUDIT_REPORT.md" "Audit report created"
    
    # Check if audit report contains key sections
    $auditPath = "../AUDIT_REPORT.md"
    if (Test-Path $auditPath) {
        $content = Get-Content $auditPath -Raw
        
        if ($content -match "Security Vulnerabilities") {
            Write-Host "✓ Security vulnerabilities section exists" -ForegroundColor Green
            $script:SuccessCount++
        } else {
            Write-Host "✗ Security vulnerabilities section missing" -ForegroundColor Red
            $script:ErrorCount++
        }
        
        if ($content -match "Code Redundancy") {
            Write-Host "✓ Code redundancy section exists" -ForegroundColor Green
            $script:SuccessCount++
        } else {
            Write-Host "✗ Code redundancy section missing" -ForegroundColor Red
            $script:ErrorCount++
        }
        
        if ($content -match "Remediation Plan") {
            Write-Host "✓ Remediation plan section exists" -ForegroundColor Green
            $script:SuccessCount++
        } else {
            Write-Host "✗ Remediation plan section missing" -ForegroundColor Red
            $script:ErrorCount++
        }
    }
}

function Show-Summary {
    Write-Host "`n" -NoNewline
    Write-Host "=" -ForegroundColor Blue -NoNewline
    Write-Host ("=" * 59) -ForegroundColor Blue
    Write-Host "VERIFICATION SUMMARY" -ForegroundColor Blue
    Write-Host "=" -ForegroundColor Blue -NoNewline
    Write-Host ("=" * 59) -ForegroundColor Blue
    
    $total = $script:SuccessCount + $script:ErrorCount
    $successRate = if ($total -gt 0) { [math]::Round(($script:SuccessCount / $total) * 100, 1) } else { 0 }
    
    Write-Host "Total Checks: $total" -ForegroundColor White
    Write-Host "Passed: $script:SuccessCount" -ForegroundColor Green
    Write-Host "Failed: $script:ErrorCount" -ForegroundColor Red
    Write-Host "Success Rate: $successRate%" -ForegroundColor White
    
    if ($script:ErrorCount -eq 0) {
        Write-Host "`n✅ ALL FIXES VERIFIED SUCCESSFULLY!" -ForegroundColor Green
        Write-Host "The remediation plan has been fully implemented." -ForegroundColor Green
    } else {
        Write-Host "`n❌ SOME FIXES NEED ATTENTION" -ForegroundColor Red
        Write-Host "Please review the failed checks above." -ForegroundColor Red
    }
    
    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    Write-Host "1. Run the test suite: python tests/run_tests.py" -ForegroundColor White
    Write-Host "2. Test the application with real VS Code data" -ForegroundColor White
    Write-Host "3. Review the audit report for additional recommendations" -ForegroundColor White
}

# Run all tests
try {
    Test-ConfigurationStructure
    Test-SecurityFixes
    Test-CodeConsolidation
    Test-TestingFramework
    Test-DocumentationUpdates
    Show-Summary
    
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
