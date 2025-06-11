# Deep-Security-Audit.ps1
# Comprehensive security audit for PowerShell modules
# Checks for command injection, privilege escalation, and other security vulnerabilities

param(
    [switch]$Verbose,
    [switch]$FixIssues
)

Write-Host "=" -ForegroundColor Red -NoNewline
Write-Host ("=" * 59) -ForegroundColor Red
Write-Host "DEEP SECURITY AUDIT - AUGMENT VIP CLEANER" -ForegroundColor Red
Write-Host "=" -ForegroundColor Red -NoNewline
Write-Host ("=" * 59) -ForegroundColor Red

$CriticalCount = 0
$HighCount = 0
$MediumCount = 0
$LowCount = 0
$InfoCount = 0

function Test-CommandInjectionVulnerabilities {
    Write-Host "`n--- Command Injection Vulnerability Scan ---" -ForegroundColor Red
    
    $vulnerablePatterns = @(
        @{
            Pattern = 'Invoke-Expression\s+\$[^;#\r\n]+(?<!#.*)'
            Severity = "CRITICAL"
            Description = "Unsafe Invoke-Expression usage without proper sanitization"
        },
        @{
            Pattern = 'Invoke-Expression\s+"[^"]*\$[^"]*"'
            Severity = "HIGH"
            Description = "String interpolation in Invoke-Expression"
        },
        @{
            Pattern = 'Start-Process.*-ArgumentList.*\$'
            Severity = "HIGH"
            Description = "Potential command injection in Start-Process"
        },
        @{
            Pattern = '&\s+\$[^;]+\s'
            Severity = "MEDIUM"
            Description = "Direct command execution with variables"
        },
        @{
            Pattern = 'cmd\s*/c.*\$'
            Severity = "HIGH"
            Description = "Command injection via cmd.exe"
        }
    )
    
    $psModules = Get-ChildItem "../scripts/windows/modules/*.psm1"
    
    foreach ($module in $psModules) {
        $content = Get-Content $module.FullName -Raw
        $moduleName = $module.Name
        
        foreach ($vuln in $vulnerablePatterns) {
            if ($content -match $vuln.Pattern) {
                $matches = [regex]::Matches($content, $vuln.Pattern)
                foreach ($match in $matches) {
                    $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                    
                    switch ($vuln.Severity) {
                        "CRITICAL" {
                            Write-Host "CRITICAL: ${moduleName}:${lineNumber} - $($vuln.Description)" -ForegroundColor Red
                            $script:CriticalCount++
                        }
                        "HIGH" {
                            Write-Host "HIGH: ${moduleName}:${lineNumber} - $($vuln.Description)" -ForegroundColor DarkRed
                            $script:HighCount++
                        }
                        "MEDIUM" {
                            Write-Host "MEDIUM: ${moduleName}:${lineNumber} - $($vuln.Description)" -ForegroundColor Yellow
                            $script:MediumCount++
                        }
                    }
                    
                    if ($Verbose) {
                        Write-Host "    Code: $($match.Value)" -ForegroundColor Gray
                    }
                }
            }
        }
    }
}

function Test-PrivilegeEscalationRisks {
    Write-Host "`n--- Privilege Escalation Risk Assessment ---" -ForegroundColor Red
    
    $privilegePatterns = @(
        @{
            Pattern = 'Start-Process.*-Verb\s+RunAs'
            Severity = "HIGH"
            Description = "Explicit privilege escalation attempt"
        },
        @{
            Pattern = 'New-Object.*System\.Diagnostics\.Process.*UseShellExecute.*true'
            Severity = "MEDIUM"
            Description = "Process creation with shell execute"
        },
        @{
            Pattern = 'Set-ExecutionPolicy.*Unrestricted'
            Severity = "MEDIUM"
            Description = "Execution policy modification"
        },
        @{
            Pattern = 'Add-Type.*DllImport'
            Severity = "HIGH"
            Description = "Native code execution via P/Invoke"
        }
    )
    
    $psModules = Get-ChildItem "../scripts/windows/modules/*.psm1"
    
    foreach ($module in $psModules) {
        $content = Get-Content $module.FullName -Raw
        $moduleName = $module.Name
        
        foreach ($risk in $privilegePatterns) {
            if ($content -match $risk.Pattern) {
                $matches = [regex]::Matches($content, $risk.Pattern)
                foreach ($match in $matches) {
                    $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                    
                    switch ($risk.Severity) {
                        "HIGH" {
                            Write-Host "HIGH: ${moduleName}:${lineNumber} - $($risk.Description)" -ForegroundColor DarkRed
                            $script:HighCount++
                        }
                        "MEDIUM" {
                            Write-Host "MEDIUM: ${moduleName}:${lineNumber} - $($risk.Description)" -ForegroundColor Yellow
                            $script:MediumCount++
                        }
                    }
                }
            }
        }
    }
}

function Test-UnsafeFileOperations {
    Write-Host "`n--- Unsafe File Operation Analysis ---" -ForegroundColor Red
    
    $filePatterns = @(
        @{
            Pattern = 'Remove-Item.*-Recurse.*-Force.*\$'
            Severity = "HIGH"
            Description = "Recursive file deletion with variable path"
        },
        @{
            Pattern = 'Copy-Item.*\$.*\$'
            Severity = "MEDIUM"
            Description = "File copy with variable paths (potential path traversal)"
        },
        @{
            Pattern = 'Move-Item.*\$.*\$'
            Severity = "MEDIUM"
            Description = "File move with variable paths"
        },
        @{
            Pattern = 'New-Item.*-ItemType.*File.*\$'
            Severity = "LOW"
            Description = "File creation with variable path"
        },
        @{
            Pattern = '\.\.[/\\]'
            Severity = "HIGH"
            Description = "Potential path traversal pattern"
        }
    )
    
    $psModules = Get-ChildItem "../scripts/windows/modules/*.psm1"
    
    foreach ($module in $psModules) {
        $content = Get-Content $module.FullName -Raw
        $moduleName = $module.Name
        
        foreach ($pattern in $filePatterns) {
            if ($content -match $pattern.Pattern) {
                $matches = [regex]::Matches($content, $pattern.Pattern)
                foreach ($match in $matches) {
                    $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                    
                    switch ($pattern.Severity) {
                        "HIGH" {
                            Write-Host "HIGH: ${moduleName}:${lineNumber} - $($pattern.Description)" -ForegroundColor DarkRed
                            $script:HighCount++
                        }
                        "MEDIUM" {
                            Write-Host "MEDIUM: ${moduleName}:${lineNumber} - $($pattern.Description)" -ForegroundColor Yellow
                            $script:MediumCount++
                        }
                        "LOW" {
                            Write-Host "LOW: ${moduleName}:${lineNumber} - $($pattern.Description)" -ForegroundColor Blue
                            $script:LowCount++
                        }
                    }
                }
            }
        }
    }
}

function Test-SensitiveInformationExposure {
    Write-Host "`n--- Sensitive Information Exposure Check ---" -ForegroundColor Red
    
    $sensitivePatterns = @(
        @{
            Pattern = 'password\s*=\s*["''][^"'']+["'']'
            Severity = "CRITICAL"
            Description = "Hardcoded password"
        },
        @{
            Pattern = 'apikey\s*=\s*["''][^"'']+["'']'
            Severity = "CRITICAL"
            Description = "Hardcoded API key"
        },
        @{
            Pattern = 'secret\s*=\s*["''][^"'']+["'']'
            Severity = "HIGH"
            Description = "Hardcoded secret"
        },
        @{
            Pattern = 'Write-Host.*\$env:USERNAME'
            Severity = "LOW"
            Description = "Username exposure in logs"
        },
        @{
            Pattern = 'Write-.*\$env:COMPUTERNAME'
            Severity = "LOW"
            Description = "Computer name exposure"
        }
    )
    
    $allFiles = Get-ChildItem "../scripts" -Recurse -Include "*.ps1", "*.psm1"
    
    foreach ($file in $allFiles) {
        $content = Get-Content $file.FullName -Raw
        $fileName = $file.Name
        
        foreach ($pattern in $sensitivePatterns) {
            if ($content -match $pattern.Pattern) {
                $matches = [regex]::Matches($content, $pattern.Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                foreach ($match in $matches) {
                    $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                    
                    switch ($pattern.Severity) {
                        "CRITICAL" {
                            Write-Host "CRITICAL: ${fileName}:${lineNumber} - $($pattern.Description)" -ForegroundColor Red
                            $script:CriticalCount++
                        }
                        "HIGH" {
                            Write-Host "HIGH: ${fileName}:${lineNumber} - $($pattern.Description)" -ForegroundColor DarkRed
                            $script:HighCount++
                        }
                        "LOW" {
                            Write-Host "LOW: ${fileName}:${lineNumber} - $($pattern.Description)" -ForegroundColor Blue
                            $script:LowCount++
                        }
                    }
                }
            }
        }
    }
}

function Test-SpecificVulnerabilities {
    Write-Host "`n--- Specific Known Vulnerability Checks ---" -ForegroundColor Red
    
    # Check DependencyManager.psm1 for command injection
    $depManagerPath = "../scripts/windows/modules/DependencyManager.psm1"
    if (Test-Path $depManagerPath) {
        $content = Get-Content $depManagerPath -Raw
        
        # Check for unsafe Invoke-Expression usage
        if ($content -match 'Invoke-Expression\s+\$testCommand') {
            Write-Host "CRITICAL: DependencyManager.psm1 - Unsafe Invoke-Expression with user-controlled input" -ForegroundColor Red
            Write-Host "    Line ~206: Invoke-Expression testCommand without proper sanitization" -ForegroundColor Gray
            $script:CriticalCount++
        }

        if ($content -match 'Invoke-Expression\s+\$installCommand') {
            Write-Host "CRITICAL: DependencyManager.psm1 - Command injection in package installation" -ForegroundColor Red
            Write-Host "    Line ~287: Invoke-Expression installCommand with format string vulnerability" -ForegroundColor Gray
            $script:CriticalCount++
        }
    }
    
    # Check for SQL injection in DatabaseCleaner
    $dbCleanerPath = "../scripts/windows/modules/DatabaseCleaner.psm1"
    if (Test-Path $dbCleanerPath) {
        $content = Get-Content $dbCleanerPath -Raw
        
        if ($content -match "sqlite3.*`".*\$.*`"") {
            Write-Host "MEDIUM: DatabaseCleaner.psm1 - Potential SQL injection in sqlite3 command" -ForegroundColor Yellow
            $script:MediumCount++
        }
    }
}

function Show-SecurityReport {
    Write-Host "`n" -NoNewline
    Write-Host "=" -ForegroundColor Red -NoNewline
    Write-Host ("=" * 59) -ForegroundColor Red
    Write-Host "SECURITY AUDIT REPORT" -ForegroundColor Red
    Write-Host "=" -ForegroundColor Red -NoNewline
    Write-Host ("=" * 59) -ForegroundColor Red
    
    $total = $script:CriticalCount + $script:HighCount + $script:MediumCount + $script:LowCount
    
    Write-Host "Total Issues Found: $total" -ForegroundColor White
    Write-Host "Critical: $script:CriticalCount" -ForegroundColor Red
    Write-Host "High: $script:HighCount" -ForegroundColor DarkRed
    Write-Host "Medium: $script:MediumCount" -ForegroundColor Yellow
    Write-Host "Low: $script:LowCount" -ForegroundColor Blue
    
    # Security assessment
    if ($script:CriticalCount -gt 0) {
        Write-Host "`nCRITICAL SECURITY ISSUES FOUND!" -ForegroundColor Red
        Write-Host "Immediate action required. Do not use in production." -ForegroundColor Red
    } elseif ($script:HighCount -gt 0) {
        Write-Host "`nHIGH RISK SECURITY ISSUES FOUND" -ForegroundColor DarkRed
        Write-Host "Address these issues before production deployment." -ForegroundColor DarkRed
    } elseif ($script:MediumCount -gt 0) {
        Write-Host "`nMEDIUM RISK ISSUES FOUND" -ForegroundColor Yellow
        Write-Host "Consider addressing these issues for better security." -ForegroundColor Yellow
    } else {
        Write-Host "`nNO CRITICAL OR HIGH RISK ISSUES FOUND" -ForegroundColor Green
        Write-Host "Security posture is acceptable for production use." -ForegroundColor Green
    }
    
    Write-Host "`nRecommendations:" -ForegroundColor Yellow
    Write-Host "1. Replace all Invoke-Expression calls with safer alternatives" -ForegroundColor White
    Write-Host "2. Implement input validation for all user-controlled data" -ForegroundColor White
    Write-Host "3. Use parameterized commands instead of string concatenation" -ForegroundColor White
    Write-Host "4. Add path validation to prevent directory traversal" -ForegroundColor White
    Write-Host "5. Remove or sanitize sensitive information from logs" -ForegroundColor White
}

# Run all security tests
try {
    Test-CommandInjectionVulnerabilities
    Test-PrivilegeEscalationRisks
    Test-UnsafeFileOperations
    Test-SensitiveInformationExposure
    Test-SpecificVulnerabilities
    Show-SecurityReport
    
    # Return appropriate exit code
    if ($script:CriticalCount -gt 0 -or $script:HighCount -gt 0) {
        exit 1
    } else {
        exit 0
    }
} catch {
    Write-Host "`nSECURITY AUDIT FAILED WITH ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
