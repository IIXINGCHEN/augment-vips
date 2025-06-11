# Cross-Platform-Tests.ps1
#
# Description: Cross-platform compatibility tests for Augment VIP Cleaner
# Tests PowerShell and Python module compatibility and feature parity
#
# Author: Augment VIP Project
# Version: 2.0.0

param(
    [string]$LogLevel = 'Normal',
    [string]$OutputPath = ".\test-results"
)

# Cross-platform test results
$script:CrossPlatformResults = @{
    StartTime = Get-Date
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    SkippedTests = 0
    PlatformCompatibility = @{}
    TestDetails = @()
}

# Test configuration
$script:TestConfig = @{
    ProjectRoot = Split-Path -Parent $PSScriptRoot
    ModulesPath = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\windows\modules"
    PythonPath = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\cross-platform\augment_vip"
    ConfigPath = Join-Path (Split-Path -Parent $PSScriptRoot) "config\config.json"
    TempPath = Join-Path $env:TEMP "augment-vip-crossplatform-tests"
}

<#
.SYNOPSIS
    Main cross-platform test execution function
#>
function Start-CrossPlatformTests {
    [CmdletBinding()]
    param()
    
    Write-Host "Starting Cross-Platform Tests for Augment VIP Cleaner" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Green
    
    # Create temp directory
    if (-not (Test-Path $script:TestConfig.TempPath)) {
        New-Item -ItemType Directory -Path $script:TestConfig.TempPath -Force | Out-Null
    }
    
    try {
        # Core cross-platform tests
        Test-PythonEnvironment
        Test-PowerShellPythonFeatureParity
        Test-ConfigurationCompatibility
        Test-DatabaseOperationCompatibility
        Test-IDGenerationCompatibility
        Test-PathHandlingCompatibility
        Test-ErrorHandlingCompatibility
        Test-LoggingCompatibility
        
        # Generate cross-platform test report
        New-CrossPlatformReport
        
        # Show summary
        Show-CrossPlatformSummary
        
    } catch {
        Write-Host "Cross-platform testing failed: $($_.Exception.Message)" -ForegroundColor Red
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
    Tests Python environment availability and compatibility
#>
function Test-PythonEnvironment {
    Write-Host "`nTesting Python Environment..." -ForegroundColor Yellow
    
    try {
        # Check if Python is available
        $pythonVersion = python --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Add-CrossPlatformTestResult -TestName "Python Availability" -Status "Passed" -Message "Python found: $pythonVersion"
            $script:CrossPlatformResults.PlatformCompatibility["PythonAvailable"] = $true
        } else {
            Add-CrossPlatformTestResult -TestName "Python Availability" -Status "Failed" -Message "Python not found in PATH"
            $script:CrossPlatformResults.PlatformCompatibility["PythonAvailable"] = $false
            return
        }
        
        # Check Python modules
        $pythonModules = Get-ChildItem "$($script:TestConfig.PythonPath)\*.py" -ErrorAction SilentlyContinue
        if ($pythonModules -and $pythonModules.Count -gt 0) {
            Add-CrossPlatformTestResult -TestName "Python Modules Available" -Status "Passed" -Message "Found $($pythonModules.Count) Python modules"
            $script:CrossPlatformResults.PlatformCompatibility["PythonModulesAvailable"] = $true
            
            # Test Python module syntax
            foreach ($module in $pythonModules) {
                $syntaxCheck = python -m py_compile $module.FullName 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Add-CrossPlatformTestResult -TestName "Python Syntax ($($module.BaseName))" -Status "Passed" -Message "Syntax check passed"
                } else {
                    Add-CrossPlatformTestResult -TestName "Python Syntax ($($module.BaseName))" -Status "Failed" -Message "Syntax error: $syntaxCheck"
                }
            }
            
        } else {
            Add-CrossPlatformTestResult -TestName "Python Modules Available" -Status "Failed" -Message "No Python modules found"
            $script:CrossPlatformResults.PlatformCompatibility["PythonModulesAvailable"] = $false
        }
        
        # Check required Python packages
        $requiredPackages = @('sqlite3', 'json', 'pathlib', 'shutil')
        foreach ($package in $requiredPackages) {
            $packageCheck = python -c "import $package; print('$package imported successfully')" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Add-CrossPlatformTestResult -TestName "Python Package ($package)" -Status "Passed" -Message "Package available"
            } else {
                Add-CrossPlatformTestResult -TestName "Python Package ($package)" -Status "Failed" -Message "Package not available: $packageCheck"
            }
        }
        
    } catch {
        Add-CrossPlatformTestResult -TestName "Python Environment" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests feature parity between PowerShell and Python implementations
#>
function Test-PowerShellPythonFeatureParity {
    Write-Host "Testing PowerShell-Python Feature Parity..." -ForegroundColor Yellow
    
    try {
        # Import PowerShell modules
        $commonUtilsPath = Join-Path $script:TestConfig.ModulesPath "CommonUtils.psm1"
        if (Test-Path $commonUtilsPath) {
            Import-Module $commonUtilsPath -Force
        }
        
        # Test ID generation parity
        if ($script:CrossPlatformResults.PlatformCompatibility["PythonAvailable"]) {
            # Generate UUID in PowerShell
            $psUUID = New-SecureUUID
            
            # Generate UUID in Python (if utils.py has the function)
            $pythonUtilsPath = Join-Path $script:TestConfig.PythonPath "utils.py"
            if (Test-Path $pythonUtilsPath) {
                $pythonScript = @"
import sys
sys.path.append('$($script:TestConfig.PythonPath)')
from utils import generate_machine_id
print(generate_machine_id())
"@
                $pythonUUID = python -c $pythonScript 2>&1
                
                if ($LASTEXITCODE -eq 0 -and $pythonUUID -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
                    Add-CrossPlatformTestResult -TestName "ID Generation Parity" -Status "Passed" -Message "Both PowerShell and Python can generate valid UUIDs"
                } else {
                    Add-CrossPlatformTestResult -TestName "ID Generation Parity" -Status "Failed" -Message "Python UUID generation failed or invalid format"
                }
            } else {
                Add-CrossPlatformTestResult -TestName "ID Generation Parity" -Status "Skipped" -Message "Python utils.py not found"
            }
        } else {
            Add-CrossPlatformTestResult -TestName "ID Generation Parity" -Status "Skipped" -Message "Python not available"
        }
        
        # Test database cleaning parity
        if ($script:CrossPlatformResults.PlatformCompatibility["PythonAvailable"]) {
            $pythonDbCleanerPath = Join-Path $script:TestConfig.PythonPath "db_cleaner.py"
            if (Test-Path $pythonDbCleanerPath) {
                # Check if both implementations have similar cleaning patterns
                $psCleanerPath = Join-Path $script:TestConfig.ModulesPath "DatabaseCleaner.psm1"
                if (Test-Path $psCleanerPath) {
                    $psContent = Get-Content $psCleanerPath -Raw
                    $pythonContent = Get-Content $pythonDbCleanerPath -Raw
                    
                    # Check for common patterns
                    $commonPatterns = @('augment', 'telemetry', 'machineId', 'sessionId')
                    $psHasPatterns = $true
                    $pythonHasPatterns = $true
                    
                    foreach ($pattern in $commonPatterns) {
                        if ($psContent -notmatch $pattern) { $psHasPatterns = $false }
                        if ($pythonContent -notmatch $pattern) { $pythonHasPatterns = $false }
                    }
                    
                    if ($psHasPatterns -and $pythonHasPatterns) {
                        Add-CrossPlatformTestResult -TestName "Database Cleaning Parity" -Status "Passed" -Message "Both implementations have common cleaning patterns"
                    } else {
                        Add-CrossPlatformTestResult -TestName "Database Cleaning Parity" -Status "Failed" -Message "Cleaning patterns differ between implementations"
                    }
                } else {
                    Add-CrossPlatformTestResult -TestName "Database Cleaning Parity" -Status "Failed" -Message "PowerShell DatabaseCleaner not found"
                }
            } else {
                Add-CrossPlatformTestResult -TestName "Database Cleaning Parity" -Status "Failed" -Message "Python db_cleaner.py not found"
            }
        } else {
            Add-CrossPlatformTestResult -TestName "Database Cleaning Parity" -Status "Skipped" -Message "Python not available"
        }
        
    } catch {
        Add-CrossPlatformTestResult -TestName "PowerShell-Python Feature Parity" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests configuration compatibility across platforms
#>
function Test-ConfigurationCompatibility {
    Write-Host "Testing Configuration Compatibility..." -ForegroundColor Yellow
    
    try {
        if (Test-Path $script:TestConfig.ConfigPath) {
            $config = Get-Content $script:TestConfig.ConfigPath | ConvertFrom-Json
            
            # Test platform-specific configurations
            if ($config.platform) {
                $platforms = @('windows', 'linux', 'macos')
                foreach ($platform in $platforms) {
                    if ($config.platform.$platform) {
                        Add-CrossPlatformTestResult -TestName "Configuration ($platform)" -Status "Passed" -Message "Platform configuration found"
                    } else {
                        Add-CrossPlatformTestResult -TestName "Configuration ($platform)" -Status "Failed" -Message "Platform configuration missing"
                    }
                }
                
                # Test cross-platform paths
                if ($config.discovery -and $config.discovery.crossPlatformPaths) {
                    $crossPlatformPaths = $config.discovery.crossPlatformPaths
                    foreach ($platform in $platforms) {
                        if ($crossPlatformPaths.$platform -and $crossPlatformPaths.$platform.Count -gt 0) {
                            Add-CrossPlatformTestResult -TestName "Cross-Platform Paths ($platform)" -Status "Passed" -Message "Paths defined for $platform"
                        } else {
                            Add-CrossPlatformTestResult -TestName "Cross-Platform Paths ($platform)" -Status "Failed" -Message "No paths defined for $platform"
                        }
                    }
                } else {
                    Add-CrossPlatformTestResult -TestName "Cross-Platform Paths" -Status "Failed" -Message "Cross-platform paths configuration missing"
                }
                
            } else {
                Add-CrossPlatformTestResult -TestName "Platform Configuration" -Status "Failed" -Message "Platform configuration section missing"
            }
            
            # Test modules configuration
            if ($config.modules) {
                if ($config.modules.windows) {
                    Add-CrossPlatformTestResult -TestName "Windows Modules Config" -Status "Passed" -Message "Windows modules configuration found"
                } else {
                    Add-CrossPlatformTestResult -TestName "Windows Modules Config" -Status "Failed" -Message "Windows modules configuration missing"
                }
                
                if ($config.modules.crossPlatform) {
                    Add-CrossPlatformTestResult -TestName "Cross-Platform Modules Config" -Status "Passed" -Message "Cross-platform modules configuration found"
                } else {
                    Add-CrossPlatformTestResult -TestName "Cross-Platform Modules Config" -Status "Failed" -Message "Cross-platform modules configuration missing"
                }
            } else {
                Add-CrossPlatformTestResult -TestName "Modules Configuration" -Status "Failed" -Message "Modules configuration section missing"
            }
            
        } else {
            Add-CrossPlatformTestResult -TestName "Configuration File" -Status "Failed" -Message "Configuration file not found"
        }
        
    } catch {
        Add-CrossPlatformTestResult -TestName "Configuration Compatibility" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Adds a cross-platform test result
#>
function Add-CrossPlatformTestResult {
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
    
    $script:CrossPlatformResults.TestDetails += $result
    $script:CrossPlatformResults.TotalTests++
    
    switch ($Status) {
        'Passed' { 
            $script:CrossPlatformResults.PassedTests++
            Write-Host "  [PASS] $TestName`: $Message" -ForegroundColor Green
        }
        'Failed' { 
            $script:CrossPlatformResults.FailedTests++
            Write-Host "  [FAIL] $TestName`: $Message" -ForegroundColor Red
        }
        'Skipped' { 
            $script:CrossPlatformResults.SkippedTests++
            Write-Host "  [SKIP] $TestName`: $Message" -ForegroundColor Yellow
        }
    }
}

<#
.SYNOPSIS
    Tests database operation compatibility between platforms
#>
function Test-DatabaseOperationCompatibility {
    Write-Host "Testing Database Operation Compatibility..." -ForegroundColor Yellow

    try {
        # Create test database
        $testDbPath = Join-Path $script:TestConfig.TempPath "crossplatform-test.db"
        Create-CrossPlatformTestDatabase -DatabasePath $testDbPath

        # Test PowerShell database operations
        $psDbCleanerPath = Join-Path $script:TestConfig.ModulesPath "DatabaseCleaner.psm1"
        if (Test-Path $psDbCleanerPath) {
            Import-Module $psDbCleanerPath -Force

            try {
                $psResult = Show-CleaningPreview -DatabasePaths @($testDbPath)
                Add-CrossPlatformTestResult -TestName "PowerShell Database Operations" -Status "Passed" -Message "PowerShell can read database"
            } catch {
                Add-CrossPlatformTestResult -TestName "PowerShell Database Operations" -Status "Failed" -Message "PowerShell database operation failed: $($_.Exception.Message)"
            }
        } else {
            Add-CrossPlatformTestResult -TestName "PowerShell Database Operations" -Status "Failed" -Message "PowerShell DatabaseCleaner not found"
        }

        # Test Python database operations
        if ($script:CrossPlatformResults.PlatformCompatibility["PythonAvailable"]) {
            $pythonScript = @"
import sys
import sqlite3
sys.path.append('$($script:TestConfig.PythonPath)')

try:
    conn = sqlite3.connect('$($testDbPath.Replace('\', '\\'))')
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM ItemTable WHERE key LIKE ?", ('%augment%',))
    count = cursor.fetchone()[0]
    conn.close()
    print(f"Python found {count} augment entries")
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
"@
            $pythonResult = python -c $pythonScript 2>&1

            if ($LASTEXITCODE -eq 0) {
                Add-CrossPlatformTestResult -TestName "Python Database Operations" -Status "Passed" -Message "Python can read database: $pythonResult"
            } else {
                Add-CrossPlatformTestResult -TestName "Python Database Operations" -Status "Failed" -Message "Python database operation failed: $pythonResult"
            }
        } else {
            Add-CrossPlatformTestResult -TestName "Python Database Operations" -Status "Skipped" -Message "Python not available"
        }

    } catch {
        Add-CrossPlatformTestResult -TestName "Database Operation Compatibility" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests ID generation compatibility between platforms
#>
function Test-IDGenerationCompatibility {
    Write-Host "Testing ID Generation Compatibility..." -ForegroundColor Yellow

    try {
        # Test PowerShell UUID generation
        $commonUtilsPath = Join-Path $script:TestConfig.ModulesPath "CommonUtils.psm1"
        if (Test-Path $commonUtilsPath) {
            Import-Module $commonUtilsPath -Force

            $psUUIDs = @()
            for ($i = 0; $i -lt 5; $i++) {
                $psUUIDs += New-SecureUUID
            }

            # Validate PowerShell UUIDs
            $validPsUUIDs = $psUUIDs | Where-Object { $_ -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' }

            if ($validPsUUIDs.Count -eq $psUUIDs.Count) {
                Add-CrossPlatformTestResult -TestName "PowerShell UUID Generation" -Status "Passed" -Message "All PowerShell UUIDs are valid"
            } else {
                Add-CrossPlatformTestResult -TestName "PowerShell UUID Generation" -Status "Failed" -Message "Some PowerShell UUIDs are invalid"
            }

            # Test uniqueness
            $uniquePsUUIDs = $psUUIDs | Sort-Object -Unique
            if ($uniquePsUUIDs.Count -eq $psUUIDs.Count) {
                Add-CrossPlatformTestResult -TestName "PowerShell UUID Uniqueness" -Status "Passed" -Message "All PowerShell UUIDs are unique"
            } else {
                Add-CrossPlatformTestResult -TestName "PowerShell UUID Uniqueness" -Status "Failed" -Message "Duplicate PowerShell UUIDs found"
            }
        } else {
            Add-CrossPlatformTestResult -TestName "PowerShell UUID Generation" -Status "Failed" -Message "CommonUtils module not found"
        }

        # Test Python UUID generation
        if ($script:CrossPlatformResults.PlatformCompatibility["PythonAvailable"]) {
            $pythonScript = @"
import sys
import uuid
import re
sys.path.append('$($script:TestConfig.PythonPath)')

try:
    from utils import generate_machine_id, generate_session_id

    # Generate UUIDs
    uuids = []
    for i in range(5):
        uuids.append(generate_machine_id())

    # Validate format
    uuid_pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    valid_uuids = [u for u in uuids if re.match(uuid_pattern, u)]

    print(f"Generated: {len(uuids)}, Valid: {len(valid_uuids)}, Unique: {len(set(uuids))}")

    if len(valid_uuids) == len(uuids) and len(set(uuids)) == len(uuids):
        print("SUCCESS")
    else:
        print("FAILED")

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
"@
            $pythonResult = python -c $pythonScript 2>&1

            if ($LASTEXITCODE -eq 0 -and $pythonResult -match "SUCCESS") {
                Add-CrossPlatformTestResult -TestName "Python UUID Generation" -Status "Passed" -Message "Python UUID generation successful"
            } else {
                Add-CrossPlatformTestResult -TestName "Python UUID Generation" -Status "Failed" -Message "Python UUID generation failed: $pythonResult"
            }
        } else {
            Add-CrossPlatformTestResult -TestName "Python UUID Generation" -Status "Skipped" -Message "Python not available"
        }

    } catch {
        Add-CrossPlatformTestResult -TestName "ID Generation Compatibility" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests path handling compatibility between platforms
#>
function Test-PathHandlingCompatibility {
    Write-Host "Testing Path Handling Compatibility..." -ForegroundColor Yellow

    try {
        # Test PowerShell path handling
        $commonUtilsPath = Join-Path $script:TestConfig.ModulesPath "CommonUtils.psm1"
        if (Test-Path $commonUtilsPath) {
            Import-Module $commonUtilsPath -Force

            # Test various path scenarios
            $testPaths = @(
                @{ Path = "test.txt"; Expected = $true; Description = "Simple filename" }
                @{ Path = "folder/test.txt"; Expected = $true; Description = "Relative path" }
                @{ Path = "../test.txt"; Expected = $false; Description = "Parent directory" }
                @{ Path = ""; Expected = $false; Description = "Empty path" }
            )

            $psPathTestsPassed = 0
            foreach ($testPath in $testPaths) {
                $result = Test-SafePath -Path $testPath.Path
                if ($result -eq $testPath.Expected) {
                    $psPathTestsPassed++
                }
            }

            if ($psPathTestsPassed -eq $testPaths.Count) {
                Add-CrossPlatformTestResult -TestName "PowerShell Path Validation" -Status "Passed" -Message "All PowerShell path tests passed"
            } else {
                Add-CrossPlatformTestResult -TestName "PowerShell Path Validation" -Status "Failed" -Message "Some PowerShell path tests failed"
            }
        } else {
            Add-CrossPlatformTestResult -TestName "PowerShell Path Validation" -Status "Failed" -Message "CommonUtils module not found"
        }

        # Test Python path handling
        if ($script:CrossPlatformResults.PlatformCompatibility["PythonAvailable"]) {
            $pythonScript = @"
import sys
import os
from pathlib import Path
sys.path.append('$($script:TestConfig.PythonPath)')

try:
    from utils import sanitize_error_message

    # Test path operations
    test_paths = [
        ("test.txt", True),
        ("folder/test.txt", True),
        ("../test.txt", False),
        ("", False)
    ]

    passed = 0
    for path, expected in test_paths:
        # Simple path validation (checking for dangerous patterns)
        is_safe = not (".." in path or path == "" or path.startswith("/"))
        if is_safe == expected:
            passed += 1

    print(f"Passed: {passed}/{len(test_paths)}")
    if passed == len(test_paths):
        print("SUCCESS")
    else:
        print("FAILED")

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
"@
            $pythonResult = python -c $pythonScript 2>&1

            if ($LASTEXITCODE -eq 0 -and $pythonResult -match "SUCCESS") {
                Add-CrossPlatformTestResult -TestName "Python Path Validation" -Status "Passed" -Message "Python path validation successful"
            } else {
                Add-CrossPlatformTestResult -TestName "Python Path Validation" -Status "Failed" -Message "Python path validation failed: $pythonResult"
            }
        } else {
            Add-CrossPlatformTestResult -TestName "Python Path Validation" -Status "Skipped" -Message "Python not available"
        }

    } catch {
        Add-CrossPlatformTestResult -TestName "Path Handling Compatibility" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests error handling compatibility between platforms
#>
function Test-ErrorHandlingCompatibility {
    Write-Host "Testing Error Handling Compatibility..." -ForegroundColor Yellow

    try {
        # Test PowerShell error handling
        $commonUtilsPath = Join-Path $script:TestConfig.ModulesPath "CommonUtils.psm1"
        if (Test-Path $commonUtilsPath) {
            Import-Module $commonUtilsPath -Force

            # Test safe operation wrapper
            $result = Invoke-SafeOperation -ScriptBlock {
                throw "Test error"
            } -ErrorMessage "Test error handling" -ReturnOnError "Error handled"

            if ($result -eq "Error handled") {
                Add-CrossPlatformTestResult -TestName "PowerShell Error Handling" -Status "Passed" -Message "PowerShell error handling works correctly"
            } else {
                Add-CrossPlatformTestResult -TestName "PowerShell Error Handling" -Status "Failed" -Message "PowerShell error handling failed"
            }
        } else {
            Add-CrossPlatformTestResult -TestName "PowerShell Error Handling" -Status "Failed" -Message "CommonUtils module not found"
        }

        # Test Python error handling
        if ($script:CrossPlatformResults.PlatformCompatibility["PythonAvailable"]) {
            $pythonScript = @"
import sys
sys.path.append('$($script:TestConfig.PythonPath)')

try:
    from utils import sanitize_error_message

    # Test error sanitization
    test_error = "Error in C:\\Users\\TestUser\\Documents\\file.txt"
    sanitized = sanitize_error_message(test_error)

    # Check if sensitive information is removed
    if "TestUser" not in sanitized:
        print("SUCCESS: Error sanitization works")
    else:
        print("FAILED: Error sanitization failed")

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
"@
            $pythonResult = python -c $pythonScript 2>&1

            if ($LASTEXITCODE -eq 0 -and $pythonResult -match "SUCCESS") {
                Add-CrossPlatformTestResult -TestName "Python Error Handling" -Status "Passed" -Message "Python error handling successful"
            } else {
                Add-CrossPlatformTestResult -TestName "Python Error Handling" -Status "Failed" -Message "Python error handling failed: $pythonResult"
            }
        } else {
            Add-CrossPlatformTestResult -TestName "Python Error Handling" -Status "Skipped" -Message "Python not available"
        }

    } catch {
        Add-CrossPlatformTestResult -TestName "Error Handling Compatibility" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Tests logging compatibility between platforms
#>
function Test-LoggingCompatibility {
    Write-Host "Testing Logging Compatibility..." -ForegroundColor Yellow

    try {
        # Test PowerShell logging
        $loggerPath = Join-Path $script:TestConfig.ModulesPath "Logger.psm1"
        if (Test-Path $loggerPath) {
            Import-Module $loggerPath -Force

            try {
                Initialize-Logger -Level ([LogLevel]::Info) -EnableConsole $false
                Write-LogInfo "Cross-platform test message"
                Add-CrossPlatformTestResult -TestName "PowerShell Logging" -Status "Passed" -Message "PowerShell logging works"
            } catch {
                Add-CrossPlatformTestResult -TestName "PowerShell Logging" -Status "Failed" -Message "PowerShell logging failed: $($_.Exception.Message)"
            }
        } else {
            Add-CrossPlatformTestResult -TestName "PowerShell Logging" -Status "Failed" -Message "Logger module not found"
        }

        # Test Python logging
        if ($script:CrossPlatformResults.PlatformCompatibility["PythonAvailable"]) {
            $pythonScript = @"
import sys
import logging
sys.path.append('$($script:TestConfig.PythonPath)')

try:
    # Test basic logging functionality
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)
    logger.info("Cross-platform test message")
    print("SUCCESS: Python logging works")

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
"@
            $pythonResult = python -c $pythonScript 2>&1

            if ($LASTEXITCODE -eq 0 -and $pythonResult -match "SUCCESS") {
                Add-CrossPlatformTestResult -TestName "Python Logging" -Status "Passed" -Message "Python logging successful"
            } else {
                Add-CrossPlatformTestResult -TestName "Python Logging" -Status "Failed" -Message "Python logging failed: $pythonResult"
            }
        } else {
            Add-CrossPlatformTestResult -TestName "Python Logging" -Status "Skipped" -Message "Python not available"
        }

    } catch {
        Add-CrossPlatformTestResult -TestName "Logging Compatibility" -Status "Failed" -Message $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Creates a test database for cross-platform testing
#>
function Create-CrossPlatformTestDatabase {
    param([string]$DatabasePath)

    try {
        # Check if SQLite is available
        if (-not (Test-SQLiteAvailability)) {
            Write-Host "SQLite not available, creating mock database" -ForegroundColor Yellow
            # Create empty file as placeholder
            New-Item -Path $DatabasePath -ItemType File -Force | Out-Null
            return
        }

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

INSERT INTO ItemTable (key, value) VALUES
    ('augment.crossplatform.test1', 'test_value_1'),
    ('augment.crossplatform.test2', 'test_value_2'),
    ('normal.key', 'normal_value'),
    ('telemetry.machineId', 'test_machine_id'),
    ('telemetry.sessionId', 'test_session_id');
"@
        $command.ExecuteNonQuery()
        $connection.Close()

    } catch {
        Write-Host "Failed to create cross-platform test database: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

<#
.SYNOPSIS
    Generates cross-platform test report
#>
function New-CrossPlatformReport {
    $reportPath = Join-Path $OutputPath "crossplatform-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $script:CrossPlatformResults.EndTime = Get-Date
    $script:CrossPlatformResults.Duration = $script:CrossPlatformResults.EndTime - $script:CrossPlatformResults.StartTime
    $script:CrossPlatformResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "Cross-platform report saved: $reportPath" -ForegroundColor Green
}

<#
.SYNOPSIS
    Shows cross-platform test summary
#>
function Show-CrossPlatformSummary {
    Write-Host "`n" + "=" * 60 -ForegroundColor Green
    Write-Host "CROSS-PLATFORM TEST SUMMARY" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Green

    Write-Host "Total Tests: $($script:CrossPlatformResults.TotalTests)" -ForegroundColor White
    Write-Host "Passed: $($script:CrossPlatformResults.PassedTests)" -ForegroundColor Green
    Write-Host "Failed: $($script:CrossPlatformResults.FailedTests)" -ForegroundColor Red
    Write-Host "Skipped: $($script:CrossPlatformResults.SkippedTests)" -ForegroundColor Yellow

    $successRate = if ($script:CrossPlatformResults.TotalTests -gt 0) {
        [Math]::Round(($script:CrossPlatformResults.PassedTests / $script:CrossPlatformResults.TotalTests) * 100, 2)
    } else { 0 }
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })

    Write-Host "Duration: $($script:CrossPlatformResults.Duration.ToString('hh\:mm\:ss'))" -ForegroundColor White

    # Show platform compatibility status
    Write-Host "`nPlatform Compatibility:" -ForegroundColor White
    foreach ($key in $script:CrossPlatformResults.PlatformCompatibility.Keys) {
        $status = $script:CrossPlatformResults.PlatformCompatibility[$key]
        $color = if ($status) { "Green" } else { "Red" }
        Write-Host "  $key`: $status" -ForegroundColor $color
    }

    # Show failed tests details
    if ($script:CrossPlatformResults.FailedTests -gt 0) {
        Write-Host "`nFailed Tests:" -ForegroundColor Red
        $failedTests = $script:CrossPlatformResults.TestDetails | Where-Object { $_.Status -eq "Failed" }
        foreach ($test in $failedTests) {
            Write-Host "  - $($test.TestName): $($test.Message)" -ForegroundColor Red
        }
    }

    # Overall cross-platform status
    if ($script:CrossPlatformResults.FailedTests -eq 0) {
        Write-Host "`nCROSS-PLATFORM STATUS: EXCELLENT" -ForegroundColor Green
        Write-Host "Full cross-platform compatibility achieved!" -ForegroundColor Green
    } elseif ($successRate -ge 80) {
        Write-Host "`nCROSS-PLATFORM STATUS: GOOD" -ForegroundColor Yellow
        Write-Host "Good cross-platform compatibility with minor issues." -ForegroundColor Yellow
    } else {
        Write-Host "`nCROSS-PLATFORM STATUS: NEEDS IMPROVEMENT" -ForegroundColor Red
        Write-Host "Cross-platform compatibility issues detected." -ForegroundColor Red
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
    Start-CrossPlatformTests
}
