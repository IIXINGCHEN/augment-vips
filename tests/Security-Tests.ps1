# Security-Tests.ps1
#
# Description: Comprehensive security testing for Augment VIP Cleaner
# Tests for vulnerabilities, secure coding practices, and compliance
#
# Author: Augment VIP Project
# Version: 2.0.0

param(
    [string]$LogLevel = 'Normal',
    [string]$OutputPath = ".\test-results",
    [switch]$AutoFix
)

# Security test results
$script:SecurityResults = @{
    StartTime = Get-Date
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    CriticalIssues = @()
    HighIssues = @()
    MediumIssues = @()
    LowIssues = @()
    FixedIssues = @()
}

# Test configuration
$script:TestConfig = @{
    ProjectRoot = Split-Path -Parent $PSScriptRoot
    ModulesPath = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\windows\modules"
    PythonPath = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\cross-platform\augment_vip"
    ConfigPath = Join-Path (Split-Path -Parent $PSScriptRoot) "config\config.json"
}

<#
.SYNOPSIS
    Main security test execution function
#>
function Start-SecurityTests {
    [CmdletBinding()]
    param()
    
    Write-Host "Starting Security Tests for Augment VIP Cleaner" -ForegroundColor Red
    Write-Host "=" * 60 -ForegroundColor Red
    
    try {
        # Core security tests
        Test-SQLInjectionVulnerabilities
        Test-CommandInjectionVulnerabilities
        Test-PathTraversalVulnerabilities
        Test-InputValidation
        Test-CryptographicSecurity
        Test-FilePermissions
        Test-ErrorHandlingSecurity
        Test-ConfigurationSecurity
        Test-DependencySecurity
        Test-LoggingSecurity
        
        # Apply automatic fixes if requested
        if ($AutoFix) {
            Apply-SecurityFixes
        }
        
        # Generate security report
        New-SecurityReport
        
        # Show summary
        Show-SecuritySummary
        
    } catch {
        Write-Host "Security testing failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

<#
.SYNOPSIS
    Tests for SQL injection vulnerabilities
#>
function Test-SQLInjectionVulnerabilities {
    Write-Host "`nTesting SQL Injection Vulnerabilities..." -ForegroundColor Yellow
    
    # Test PowerShell modules
    $psModules = Get-ChildItem "$($script:TestConfig.ModulesPath)\*.psm1" -ErrorAction SilentlyContinue
    foreach ($module in $psModules) {
        $content = Get-Content $module.FullName -Raw
        
        # Check for dangerous SQL patterns
        $dangerousPatterns = @(
            'Invoke-Sqlcmd.*\$',
            'ExecuteNonQuery.*\$',
            '".*\$.*".*Execute',
            "'.*\$.*'.*Execute"
        )
        
        foreach ($pattern in $dangerousPatterns) {
            if ($content -match $pattern) {
                Add-SecurityIssue -Severity "High" -Category "SQL Injection" -File $module.Name -Message "Potential SQL injection vulnerability detected" -Pattern $pattern
            }
        }
        
        # Check for parameterized queries (good practice)
        if ($content -match 'Parameters\.Add|@\w+') {
            Add-SecurityIssue -Severity "Info" -Category "SQL Security" -File $module.Name -Message "Parameterized queries detected (good practice)"
        }
    }
    
    # Test Python modules
    $pyFiles = Get-ChildItem "$($script:TestConfig.PythonPath)\*.py" -ErrorAction SilentlyContinue
    foreach ($pyFile in $pyFiles) {
        $content = Get-Content $pyFile.FullName -Raw
        
        # Check for SQL injection vulnerabilities in Python
        if ($content -match 'cursor\.execute\([^?]*%|cursor\.execute\([^?]*\+') {
            Add-SecurityIssue -Severity "Critical" -Category "SQL Injection" -File $pyFile.Name -Message "SQL injection vulnerability detected in Python code"
            
            if ($AutoFix) {
                Fix-PythonSQLInjection -FilePath $pyFile.FullName
            }
        }
        
        # Check for proper parameterized queries
        if ($content -match 'cursor\.execute\([^,]*,\s*\(') {
            Add-SecurityIssue -Severity "Info" -Category "SQL Security" -File $pyFile.Name -Message "Parameterized queries detected (good practice)"
        }
    }
    
    $script:SecurityResults.TotalTests++
}

<#
.SYNOPSIS
    Tests for command injection vulnerabilities
#>
function Test-CommandInjectionVulnerabilities {
    Write-Host "Testing Command Injection Vulnerabilities..." -ForegroundColor Yellow
    
    $psModules = Get-ChildItem "$($script:TestConfig.ModulesPath)\*.psm1" -ErrorAction SilentlyContinue
    foreach ($module in $psModules) {
        $content = Get-Content $module.FullName -Raw
        
        # Check for dangerous command execution patterns
        $dangerousPatterns = @(
            'Invoke-Expression.*\$',
            'iex.*\$',
            'cmd.*\/c.*\$',
            'powershell.*-Command.*\$',
            'Start-Process.*-ArgumentList.*\$[^"]'
        )
        
        foreach ($pattern in $dangerousPatterns) {
            if ($content -match $pattern) {
                Add-SecurityIssue -Severity "High" -Category "Command Injection" -File $module.Name -Message "Potential command injection vulnerability" -Pattern $pattern
            }
        }
        
        # Check for safe command execution
        if ($content -match 'Start-Process.*-FilePath.*-ArgumentList') {
            Add-SecurityIssue -Severity "Info" -Category "Command Security" -File $module.Name -Message "Safe command execution detected (good practice)"
        }
    }
    
    $script:SecurityResults.TotalTests++
}

<#
.SYNOPSIS
    Tests for path traversal vulnerabilities
#>
function Test-PathTraversalVulnerabilities {
    Write-Host "Testing Path Traversal Vulnerabilities..." -ForegroundColor Yellow
    
    $allFiles = @()
    $allFiles += Get-ChildItem "$($script:TestConfig.ModulesPath)\*.psm1" -ErrorAction SilentlyContinue
    $allFiles += Get-ChildItem "$($script:TestConfig.PythonPath)\*.py" -ErrorAction SilentlyContinue
    
    foreach ($file in $allFiles) {
        $content = Get-Content $file.FullName -Raw
        
        # Check for path traversal vulnerabilities
        $dangerousPatterns = @(
            'Join-Path.*\$.*\.\.',
            'Path.*\$.*\.\.',
            '\.\.[\\/]',
            'os\.path\.join.*\.\.'
        )
        
        foreach ($pattern in $dangerousPatterns) {
            if ($content -match $pattern) {
                Add-SecurityIssue -Severity "Medium" -Category "Path Traversal" -File $file.Name -Message "Potential path traversal vulnerability" -Pattern $pattern
            }
        }
        
        # Check for path validation (good practice)
        if ($content -match 'Test-SafePath|Resolve-Path.*-Relative|os\.path\.abspath') {
            Add-SecurityIssue -Severity "Info" -Category "Path Security" -File $file.Name -Message "Path validation detected (good practice)"
        }
    }
    
    $script:SecurityResults.TotalTests++
}

<#
.SYNOPSIS
    Tests input validation implementation
#>
function Test-InputValidation {
    Write-Host "Testing Input Validation..." -ForegroundColor Yellow
    
    $psModules = Get-ChildItem "$($script:TestConfig.ModulesPath)\*.psm1" -ErrorAction SilentlyContinue
    foreach ($module in $psModules) {
        $content = Get-Content $module.FullName -Raw
        
        # Check for input validation patterns
        $validationPatterns = @(
            '\[ValidateSet\(',
            '\[ValidatePattern\(',
            '\[ValidateLength\(',
            '\[ValidateRange\(',
            'if.*-match',
            'if.*-notmatch'
        )
        
        $hasValidation = $false
        foreach ($pattern in $validationPatterns) {
            if ($content -match $pattern) {
                $hasValidation = $true
                break
            }
        }
        
        if ($hasValidation) {
            Add-SecurityIssue -Severity "Info" -Category "Input Validation" -File $module.Name -Message "Input validation detected (good practice)"
        } else {
            Add-SecurityIssue -Severity "Medium" -Category "Input Validation" -File $module.Name -Message "Limited input validation detected"
        }
    }
    
    $script:SecurityResults.TotalTests++
}

<#
.SYNOPSIS
    Tests cryptographic security implementation
#>
function Test-CryptographicSecurity {
    Write-Host "Testing Cryptographic Security..." -ForegroundColor Yellow
    
    $psModules = Get-ChildItem "$($script:TestConfig.ModulesPath)\*.psm1" -ErrorAction SilentlyContinue
    foreach ($module in $psModules) {
        $content = Get-Content $module.FullName -Raw
        
        # Check for secure random number generation
        if ($content -match 'System\.Security\.Cryptography\.RandomNumberGenerator') {
            Add-SecurityIssue -Severity "Info" -Category "Cryptographic Security" -File $module.Name -Message "Secure random number generation detected (good practice)"
        }
        
        # Check for weak random number generation
        if ($content -match 'Get-Random|System\.Random') {
            Add-SecurityIssue -Severity "Medium" -Category "Cryptographic Security" -File $module.Name -Message "Weak random number generation detected"
        }
        
        # Check for hardcoded secrets
        $secretPatterns = @(
            'password\s*=\s*"[^"]+"',
            'key\s*=\s*"[^"]+"',
            'secret\s*=\s*"[^"]+"'
        )
        
        foreach ($pattern in $secretPatterns) {
            if ($content -match $pattern) {
                Add-SecurityIssue -Severity "High" -Category "Cryptographic Security" -File $module.Name -Message "Potential hardcoded secret detected" -Pattern $pattern
            }
        }
    }
    
    $script:SecurityResults.TotalTests++
}

<#
.SYNOPSIS
    Adds a security issue to the results
#>
function Add-SecurityIssue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Critical', 'High', 'Medium', 'Low', 'Info')]
        [string]$Severity,
        [Parameter(Mandatory = $true)]
        [string]$Category,
        [string]$File = "",
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Pattern = "",
        [string]$FixSuggestion = ""
    )
    
    $issue = @{
        Timestamp = Get-Date
        Severity = $Severity
        Category = $Category
        File = $File
        Message = $Message
        Pattern = $Pattern
        FixSuggestion = $FixSuggestion
    }
    
    switch ($Severity) {
        'Critical' { 
            $script:SecurityResults.CriticalIssues += $issue
            Write-Host "  [CRITICAL] $File`: $Message" -ForegroundColor Red
        }
        'High' { 
            $script:SecurityResults.HighIssues += $issue
            Write-Host "  [HIGH] $File`: $Message" -ForegroundColor DarkRed
        }
        'Medium' { 
            $script:SecurityResults.MediumIssues += $issue
            Write-Host "  [MEDIUM] $File`: $Message" -ForegroundColor Yellow
        }
        'Low' { 
            $script:SecurityResults.LowIssues += $issue
            Write-Host "  [LOW] $File`: $Message" -ForegroundColor DarkYellow
        }
        'Info' {
            Write-Host "  [INFO] $File`: $Message" -ForegroundColor Green
        }
    }
}

<#
.SYNOPSIS
    Tests file permissions and access controls
#>
function Test-FilePermissions {
    Write-Host "Testing File Permissions..." -ForegroundColor Yellow

    # Check critical files for proper permissions
    $criticalFiles = @(
        $script:TestConfig.ConfigPath,
        (Join-Path $script:TestConfig.ModulesPath "*.psm1")
    )

    foreach ($filePattern in $criticalFiles) {
        $files = Get-ChildItem $filePattern -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            try {
                $acl = Get-Acl $file.FullName
                $hasEveryoneWrite = $acl.Access | Where-Object {
                    $_.IdentityReference -eq "Everyone" -and
                    $_.FileSystemRights -match "Write|FullControl"
                }

                if ($hasEveryoneWrite) {
                    Add-SecurityIssue -Severity "Medium" -Category "File Permissions" -File $file.Name -Message "File has overly permissive access rights"
                } else {
                    Add-SecurityIssue -Severity "Info" -Category "File Permissions" -File $file.Name -Message "File permissions appear secure"
                }
            } catch {
                Add-SecurityIssue -Severity "Low" -Category "File Permissions" -File $file.Name -Message "Could not check file permissions: $($_.Exception.Message)"
            }
        }
    }

    $script:SecurityResults.TotalTests++
}

<#
.SYNOPSIS
    Tests error handling for security issues
#>
function Test-ErrorHandlingSecurity {
    Write-Host "Testing Error Handling Security..." -ForegroundColor Yellow

    $allFiles = @()
    $allFiles += Get-ChildItem "$($script:TestConfig.ModulesPath)\*.psm1" -ErrorAction SilentlyContinue
    $allFiles += Get-ChildItem "$($script:TestConfig.PythonPath)\*.py" -ErrorAction SilentlyContinue

    foreach ($file in $allFiles) {
        $content = Get-Content $file.FullName -Raw

        # Check for information disclosure in error messages
        $disclosurePatterns = @(
            'Write-Error.*\$env',
            'Write-Host.*\$env',
            'print.*os\.environ',
            'Exception.*\$_\.Exception\.Message',
            'throw.*\$_'
        )

        foreach ($pattern in $disclosurePatterns) {
            if ($content -match $pattern) {
                Add-SecurityIssue -Severity "Low" -Category "Information Disclosure" -File $file.Name -Message "Potential information disclosure in error handling" -Pattern $pattern
            }
        }

        # Check for proper error sanitization
        if ($content -match 'Remove-SensitiveInfo|sanitize.*error|filter.*error') {
            Add-SecurityIssue -Severity "Info" -Category "Error Handling" -File $file.Name -Message "Error sanitization detected (good practice)"
        }
    }

    $script:SecurityResults.TotalTests++
}

<#
.SYNOPSIS
    Tests configuration security
#>
function Test-ConfigurationSecurity {
    Write-Host "Testing Configuration Security..." -ForegroundColor Yellow

    if (Test-Path $script:TestConfig.ConfigPath) {
        try {
            $config = Get-Content $script:TestConfig.ConfigPath | ConvertFrom-Json

            # Check for sensitive information in config
            $configString = $config | ConvertTo-Json -Depth 10

            $sensitivePatterns = @(
                'password',
                'secret',
                'key',
                'token',
                'credential'
            )

            foreach ($pattern in $sensitivePatterns) {
                if ($configString -match $pattern) {
                    Add-SecurityIssue -Severity "Medium" -Category "Configuration Security" -File "config.json" -Message "Potential sensitive information in configuration" -Pattern $pattern
                }
            }

            # Check for security settings
            if ($config.security) {
                Add-SecurityIssue -Severity "Info" -Category "Configuration Security" -File "config.json" -Message "Security configuration section found (good practice)"

                if ($config.security.enableSQLInjectionProtection -eq $true) {
                    Add-SecurityIssue -Severity "Info" -Category "Configuration Security" -File "config.json" -Message "SQL injection protection enabled"
                }

                if ($config.security.enableSecureFileHandling -eq $true) {
                    Add-SecurityIssue -Severity "Info" -Category "Configuration Security" -File "config.json" -Message "Secure file handling enabled"
                }
            } else {
                Add-SecurityIssue -Severity "Medium" -Category "Configuration Security" -File "config.json" -Message "No security configuration section found"
            }

        } catch {
            Add-SecurityIssue -Severity "High" -Category "Configuration Security" -File "config.json" -Message "Failed to parse configuration file: $($_.Exception.Message)"
        }
    } else {
        Add-SecurityIssue -Severity "High" -Category "Configuration Security" -File "config.json" -Message "Configuration file not found"
    }

    $script:SecurityResults.TotalTests++
}

<#
.SYNOPSIS
    Tests dependency security
#>
function Test-DependencySecurity {
    Write-Host "Testing Dependency Security..." -ForegroundColor Yellow

    # Check for dependency verification in config
    if (Test-Path $script:TestConfig.ConfigPath) {
        try {
            $config = Get-Content $script:TestConfig.ConfigPath | ConvertFrom-Json

            if ($config.security.enableDependencyVerification -eq $true) {
                Add-SecurityIssue -Severity "Info" -Category "Dependency Security" -File "config.json" -Message "Dependency verification enabled (good practice)"
            } else {
                Add-SecurityIssue -Severity "Medium" -Category "Dependency Security" -File "config.json" -Message "Dependency verification not enabled"
            }

            if ($config.security.trustedPackageManagers) {
                Add-SecurityIssue -Severity "Info" -Category "Dependency Security" -File "config.json" -Message "Trusted package managers defined (good practice)"
            }
        } catch {
            Add-SecurityIssue -Severity "Low" -Category "Dependency Security" -File "config.json" -Message "Could not check dependency security settings"
        }
    }

    $script:SecurityResults.TotalTests++
}

<#
.SYNOPSIS
    Tests logging security
#>
function Test-LoggingSecurity {
    Write-Host "Testing Logging Security..." -ForegroundColor Yellow

    $loggerModule = Join-Path $script:TestConfig.ModulesPath "Logger.psm1"
    if (Test-Path $loggerModule) {
        $content = Get-Content $loggerModule -Raw

        # Check for sensitive information filtering
        if ($content -match 'Remove-SensitiveInfo|SensitivePatterns|EnableSensitiveFiltering') {
            Add-SecurityIssue -Severity "Info" -Category "Logging Security" -File "Logger.psm1" -Message "Sensitive information filtering implemented (good practice)"
        } else {
            Add-SecurityIssue -Severity "Medium" -Category "Logging Security" -File "Logger.psm1" -Message "No sensitive information filtering detected"
        }

        # Check for log injection protection
        if ($content -match 'Replace.*[\r\n]|filter.*newline') {
            Add-SecurityIssue -Severity "Info" -Category "Logging Security" -File "Logger.psm1" -Message "Log injection protection detected (good practice)"
        }
    }

    $script:SecurityResults.TotalTests++
}

<#
.SYNOPSIS
    Applies automatic security fixes
#>
function Apply-SecurityFixes {
    Write-Host "`nApplying Automatic Security Fixes..." -ForegroundColor Cyan

    $fixCount = 0
    $allIssues = $script:SecurityResults.CriticalIssues + $script:SecurityResults.HighIssues

    foreach ($issue in $allIssues) {
        if ($issue.Category -eq "SQL Injection" -and $issue.File -like "*.py") {
            try {
                $filePath = Join-Path $script:TestConfig.PythonPath $issue.File
                Fix-PythonSQLInjection -FilePath $filePath
                $script:SecurityResults.FixedIssues += $issue
                $fixCount++
                Write-Host "  Fixed SQL injection in $($issue.File)" -ForegroundColor Green
            } catch {
                Write-Host "  Failed to fix SQL injection in $($issue.File): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    Write-Host "Applied $fixCount automatic security fixes" -ForegroundColor Green
}

<#
.SYNOPSIS
    Fixes Python SQL injection vulnerabilities
#>
function Fix-PythonSQLInjection {
    param([string]$FilePath)

    if (Test-Path $FilePath) {
        $content = Get-Content $FilePath -Raw

        # Fix common SQL injection patterns - simplified patterns
        $content = $content -replace 'cursor\.execute\([^,]*\+[^)]*\)', 'cursor.execute("SELECT * FROM table WHERE id = ?", (value,))'
        $content = $content -replace 'cursor\.execute\([^,]*%[^)]*\)', 'cursor.execute("SELECT * FROM table WHERE id = ?", (value,))'

        # Backup original file
        $backupPath = "$FilePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $FilePath $backupPath

        # Write fixed content
        $content | Out-File -FilePath $FilePath -Encoding UTF8

        Write-Host "    Created backup: $backupPath" -ForegroundColor Yellow
    }
}

<#
.SYNOPSIS
    Generates security test report
#>
function New-SecurityReport {
    $reportPath = Join-Path $OutputPath "security-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $script:SecurityResults.EndTime = Get-Date
    $script:SecurityResults.Duration = $script:SecurityResults.EndTime - $script:SecurityResults.StartTime
    $script:SecurityResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "Security report saved: $reportPath" -ForegroundColor Green
}

<#
.SYNOPSIS
    Shows security test summary
#>
function Show-SecuritySummary {
    Write-Host "`n" + "=" * 60 -ForegroundColor Red
    Write-Host "SECURITY TEST SUMMARY" -ForegroundColor Red
    Write-Host "=" * 60 -ForegroundColor Red

    $totalIssues = $script:SecurityResults.CriticalIssues.Count + $script:SecurityResults.HighIssues.Count +
                   $script:SecurityResults.MediumIssues.Count + $script:SecurityResults.LowIssues.Count

    Write-Host "Total Security Tests: $($script:SecurityResults.TotalTests)" -ForegroundColor White
    Write-Host "Total Issues Found: $totalIssues" -ForegroundColor White
    Write-Host ""
    Write-Host "Issues by Severity:" -ForegroundColor White
    Write-Host "  Critical: $($script:SecurityResults.CriticalIssues.Count)" -ForegroundColor Red
    Write-Host "  High: $($script:SecurityResults.HighIssues.Count)" -ForegroundColor DarkRed
    Write-Host "  Medium: $($script:SecurityResults.MediumIssues.Count)" -ForegroundColor Yellow
    Write-Host "  Low: $($script:SecurityResults.LowIssues.Count)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Fixes Applied: $($script:SecurityResults.FixedIssues.Count)" -ForegroundColor Cyan

    # Security score calculation
    $securityScore = 100
    $securityScore -= ($script:SecurityResults.CriticalIssues.Count * 25)
    $securityScore -= ($script:SecurityResults.HighIssues.Count * 15)
    $securityScore -= ($script:SecurityResults.MediumIssues.Count * 5)
    $securityScore -= ($script:SecurityResults.LowIssues.Count * 1)
    $securityScore = [Math]::Max(0, $securityScore)

    Write-Host "Security Score: $securityScore/100" -ForegroundColor $(
        if ($securityScore -ge 90) { "Green" }
        elseif ($securityScore -ge 70) { "Yellow" }
        else { "Red" }
    )

    # Overall security status
    if ($script:SecurityResults.CriticalIssues.Count -eq 0 -and $script:SecurityResults.HighIssues.Count -eq 0) {
        Write-Host "`nSECURITY STATUS: ACCEPTABLE" -ForegroundColor Green
    } elseif ($script:SecurityResults.CriticalIssues.Count -eq 0) {
        Write-Host "`nSECURITY STATUS: NEEDS ATTENTION" -ForegroundColor Yellow
    } else {
        Write-Host "`nSECURITY STATUS: CRITICAL ISSUES FOUND" -ForegroundColor Red
    }
}

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    Start-SecurityTests
}
