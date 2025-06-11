# Final-Security-Check.ps1
# Precise security check for remaining vulnerabilities

param([switch]$Verbose)

Write-Host "============================================================" -ForegroundColor Green
Write-Host "FINAL SECURITY CHECK - AUGMENT VIP CLEANER" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

$CriticalCount = 0
$HighCount = 0
$MediumCount = 0
$PassedCount = 0

function Test-InvokeExpressionUsage {
    Write-Host "`n--- Checking for Invoke-Expression Vulnerabilities ---" -ForegroundColor Yellow
    
    $psModules = Get-ChildItem "../scripts/windows/modules/*.psm1"
    
    foreach ($module in $psModules) {
        $content = Get-Content $module.FullName -Raw
        $moduleName = $module.Name
        
        # Look for actual Invoke-Expression usage (not comments)
        $lines = Get-Content $module.FullName
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $lineNumber = $i + 1
            
            # Skip comments
            if ($line -match '^\s*#') { continue }
            
            # Check for dangerous Invoke-Expression patterns
            if ($line -match 'Invoke-Expression\s+\$\w+' -and $line -notmatch '#.*Invoke-Expression') {
                Write-Host "CRITICAL: ${moduleName}:${lineNumber} - Active Invoke-Expression found" -ForegroundColor Red
                Write-Host "    Code: $($line.Trim())" -ForegroundColor Gray
                $script:CriticalCount++
            }
            elseif ($line -match 'Invoke-Expression.*\$' -and $line -notmatch '#.*Invoke-Expression') {
                Write-Host "HIGH: ${moduleName}:${lineNumber} - Potential Invoke-Expression usage" -ForegroundColor DarkRed
                Write-Host "    Code: $($line.Trim())" -ForegroundColor Gray
                $script:HighCount++
            }
        }
    }
    
    if ($script:CriticalCount -eq 0) {
        Write-Host "PASSED: No critical Invoke-Expression vulnerabilities found" -ForegroundColor Green
        $script:PassedCount++
    }
}

function Test-CommandInjectionMitigation {
    Write-Host "`n--- Checking Command Injection Mitigation ---" -ForegroundColor Yellow
    
    $depManagerPath = "../scripts/windows/modules/DependencyManager.psm1"
    if (Test-Path $depManagerPath) {
        $content = Get-Content $depManagerPath -Raw
        
        # Check if Start-Process is used instead of Invoke-Expression
        if ($content -match 'Start-Process.*-FilePath.*-ArgumentList') {
            Write-Host "PASSED: Safe command execution using Start-Process found" -ForegroundColor Green
            $script:PassedCount++
        } else {
            Write-Host "HIGH: No safe command execution patterns found" -ForegroundColor DarkRed
            $script:HighCount++
        }
        
        # Check for remaining Invoke-Expression
        $lines = Get-Content $depManagerPath
        $invokeExpressionFound = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match 'Invoke-Expression' -and $line -notmatch '#.*Invoke-Expression') {
                $invokeExpressionFound = $true
                Write-Host "CRITICAL: DependencyManager.psm1:$($i+1) - Active Invoke-Expression found" -ForegroundColor Red
                $script:CriticalCount++
            }
        }
        
        if (-not $invokeExpressionFound) {
            Write-Host "PASSED: No active Invoke-Expression found in DependencyManager" -ForegroundColor Green
            $script:PassedCount++
        }
    }
}

function Test-InputValidationImplementation {
    Write-Host "`n--- Checking Input Validation Implementation ---" -ForegroundColor Yellow
    
    $utilsPath = "../scripts/cross-platform/augment_vip/utils.py"
    if (Test-Path $utilsPath) {
        $content = Get-Content $utilsPath -Raw
        
        if ($content -match 'def validate_file_path') {
            Write-Host "PASSED: File path validation function implemented" -ForegroundColor Green
            $script:PassedCount++
        } else {
            Write-Host "HIGH: File path validation function missing" -ForegroundColor DarkRed
            $script:HighCount++
        }
        
        if ($content -match 'def sanitize_input') {
            Write-Host "PASSED: Input sanitization function implemented" -ForegroundColor Green
            $script:PassedCount++
        } else {
            Write-Host "HIGH: Input sanitization function missing" -ForegroundColor DarkRed
            $script:HighCount++
        }
    }
    
    # Check PowerShell utils
    $psUtilsPath = "../scripts/windows/modules/CommonUtils.psm1"
    if (Test-Path $psUtilsPath) {
        $content = Get-Content $psUtilsPath -Raw
        
        if ($content -match 'function Test-SafePath') {
            Write-Host "PASSED: PowerShell safe path validation implemented" -ForegroundColor Green
            $script:PassedCount++
        } else {
            Write-Host "HIGH: PowerShell safe path validation missing" -ForegroundColor DarkRed
            $script:HighCount++
        }
    }
}

function Test-SQLInjectionFixes {
    Write-Host "`n--- Checking SQL Injection Fixes ---" -ForegroundColor Yellow
    
    $dbCleanerPath = "../scripts/cross-platform/augment_vip/db_cleaner.py"
    if (Test-Path $dbCleanerPath) {
        $content = Get-Content $dbCleanerPath -Raw
        
        # Check for parameterized queries
        if ($content -match 'cursor\.execute\("SELECT COUNT\(\*\) FROM ItemTable WHERE key LIKE \?", \(') {
            Write-Host "PASSED: SQL injection fix implemented (parameterized queries)" -ForegroundColor Green
            $script:PassedCount++
        } else {
            Write-Host "CRITICAL: SQL injection vulnerability still present" -ForegroundColor Red
            $script:CriticalCount++
        }
    }
}

function Test-UnifiedServicesIntegration {
    Write-Host "`n--- Checking Unified Services Integration ---" -ForegroundColor Yellow
    
    $unifiedServicesPath = "../scripts/windows/modules/UnifiedServices.psm1"
    if (Test-Path $unifiedServicesPath) {
        Write-Host "PASSED: UnifiedServices bridge module exists" -ForegroundColor Green
        $script:PassedCount++
        
        $content = Get-Content $unifiedServicesPath -Raw
        
        # Check for key functions
        $requiredFunctions = @(
            'Get-UnifiedCleaningPatterns',
            'New-UnifiedSecureId',
            'Initialize-UnifiedServices'
        )
        
        foreach ($func in $requiredFunctions) {
            if ($content -match "function $func") {
                Write-Host "PASSED: Function $func implemented" -ForegroundColor Green
                $script:PassedCount++
            } else {
                Write-Host "MEDIUM: Function $func missing" -ForegroundColor Yellow
                $script:MediumCount++
            }
        }
    } else {
        Write-Host "HIGH: UnifiedServices bridge module missing" -ForegroundColor DarkRed
        $script:HighCount++
    }
}

function Test-ConfigurationSecurity {
    Write-Host "`n--- Checking Configuration Security ---" -ForegroundColor Yellow
    
    $configPath = "../config/config.json"
    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath | ConvertFrom-Json
            
            # Check for centralized patterns
            if ($config.cleaning.patterns) {
                Write-Host "PASSED: Centralized pattern configuration implemented" -ForegroundColor Green
                $script:PassedCount++
            } else {
                Write-Host "MEDIUM: Pattern centralization incomplete" -ForegroundColor Yellow
                $script:MediumCount++
            }
            
            # Check security settings
            if ($config.security) {
                Write-Host "PASSED: Security configuration section exists" -ForegroundColor Green
                $script:PassedCount++
            } else {
                Write-Host "MEDIUM: Security configuration missing" -ForegroundColor Yellow
                $script:MediumCount++
            }
            
        } catch {
            Write-Host "HIGH: Configuration file is invalid JSON" -ForegroundColor DarkRed
            $script:HighCount++
        }
    } else {
        Write-Host "HIGH: Configuration file missing" -ForegroundColor DarkRed
        $script:HighCount++
    }
}

function Show-FinalSecurityReport {
    Write-Host "`n============================================================" -ForegroundColor Blue
    Write-Host "FINAL SECURITY REPORT" -ForegroundColor Blue
    Write-Host "============================================================" -ForegroundColor Blue
    
    $total = $script:CriticalCount + $script:HighCount + $script:MediumCount + $script:PassedCount
    $riskScore = ($script:CriticalCount * 10) + ($script:HighCount * 5) + ($script:MediumCount * 2)
    
    Write-Host "Total Checks: $total" -ForegroundColor White
    Write-Host "Passed: $script:PassedCount" -ForegroundColor Green
    Write-Host "Critical: $script:CriticalCount" -ForegroundColor Red
    Write-Host "High: $script:HighCount" -ForegroundColor DarkRed
    Write-Host "Medium: $script:MediumCount" -ForegroundColor Yellow
    Write-Host "Risk Score: $riskScore" -ForegroundColor White
    
    # Security assessment
    if ($script:CriticalCount -eq 0 -and $script:HighCount -eq 0) {
        Write-Host "`nSECURITY STATUS: SECURE" -ForegroundColor Green
        Write-Host "No critical or high-risk vulnerabilities found." -ForegroundColor Green
        Write-Host "The application is ready for production use." -ForegroundColor Green
    } elseif ($script:CriticalCount -eq 0 -and $script:HighCount -le 2) {
        Write-Host "`nSECURITY STATUS: ACCEPTABLE" -ForegroundColor Yellow
        Write-Host "Minor high-risk issues found. Address before production." -ForegroundColor Yellow
    } else {
        Write-Host "`nSECURITY STATUS: VULNERABLE" -ForegroundColor Red
        Write-Host "Critical or multiple high-risk issues found." -ForegroundColor Red
        Write-Host "DO NOT USE IN PRODUCTION until issues are resolved." -ForegroundColor Red
    }
    
    # Success rate
    $successRate = if ($total -gt 0) { [math]::Round(($script:PassedCount / $total) * 100, 1) } else { 0 }
    Write-Host "`nSecurity Success Rate: $successRate%" -ForegroundColor White
    
    if ($successRate -ge 90) {
        Write-Host "EXCELLENT security posture" -ForegroundColor Green
    } elseif ($successRate -ge 80) {
        Write-Host "GOOD security posture" -ForegroundColor Yellow
    } elseif ($successRate -ge 70) {
        Write-Host "ACCEPTABLE security posture" -ForegroundColor Yellow
    } else {
        Write-Host "POOR security posture - immediate action required" -ForegroundColor Red
    }
}

# Run all security checks
try {
    Test-InvokeExpressionUsage
    Test-CommandInjectionMitigation
    Test-InputValidationImplementation
    Test-SQLInjectionFixes
    Test-UnifiedServicesIntegration
    Test-ConfigurationSecurity
    Show-FinalSecurityReport
    
    # Return appropriate exit code
    if ($script:CriticalCount -eq 0 -and $script:HighCount -eq 0) {
        exit 0
    } else {
        exit 1
    }
} catch {
    Write-Host "`nSECURITY CHECK FAILED WITH ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
