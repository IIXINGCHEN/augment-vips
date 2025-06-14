# Start-TestSuite.ps1
# Augment VIP Test Suite Runner
# Comprehensive testing framework for all Augment VIP functionality
# Version: 3.0.0 - Standardized and optimized

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Test category to run")]
    [ValidateSet("All", "Verification", "Tools", "Core", "Integration")]
    [string]$TestCategory = "All",
    
    [Parameter(HelpMessage = "Enable verbose output")]
    [switch]$VerboseOutput = $false,
    
    [Parameter(HelpMessage = "Generate detailed reports")]
    [switch]$DetailedReport = $false,
    
    [Parameter(HelpMessage = "Continue on test failures")]
    [switch]$ContinueOnFailure = $false
)

# Import dependencies
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path $scriptPath -Parent
$coreModulesPath = Join-Path $rootPath "src\core"
$loggerPath = Join-Path $coreModulesPath "AugmentLogger.ps1"

if (Test-Path $loggerPath) {
    . $loggerPath
    Initialize-AugmentLogger -LogDirectory "logs" -LogFileName "test_suite.log" -LogLevel "INFO"
} else {
    # Fallback logging if main logger not available
    function Write-LogInfo { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor White }
    function Write-LogSuccess { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
    function Write-LogWarning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    function Write-LogError { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
    function Write-LogDebug { param([string]$Message) if ($Verbose) { Write-Host "[DEBUG] $Message" -ForegroundColor Gray } }
}

# Set error handling
$ErrorActionPreference = "Stop"

# Test suite configuration
$script:TestSuiteConfig = @{
    TestDirectory = $scriptPath
    RootDirectory = $rootPath
    StartTime = Get-Date
    Results = @{
        TotalTests = 0
        PassedTests = 0
        FailedTests = 0
        SkippedTests = 0
        TestDetails = @()
    }
}

#region Test Discovery

function Get-AvailableTests {
    <#
    .SYNOPSIS
        Discovers all available test scripts
    .DESCRIPTION
        Scans the test directory for test scripts and categorizes them
    .EXAMPLE
        Get-AvailableTests
    #>
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Discovering available test scripts..."
    
    $testFiles = Get-ChildItem -Path $script:TestSuiteConfig.TestDirectory -Filter "Test-*.ps1" -ErrorAction SilentlyContinue
    
    $tests = @{
        Verification = @()
        Tools = @()
        Core = @()
        Integration = @()
    }
    
    foreach ($testFile in $testFiles) {
        $testName = $testFile.BaseName
        $category = "Core"  # Default category
        
        # Categorize tests based on naming patterns
        if ($testName -match "Verification|Verify|Check") {
            $category = "Verification"
        } elseif ($testName -match "Tool|Clean|Reset|Fix") {
            $category = "Tools"
        } elseif ($testName -match "Integration|End2End|E2E") {
            $category = "Integration"
        }
        
        $testInfo = @{
            Name = $testName
            Path = $testFile.FullName
            Category = $category
            LastModified = $testFile.LastWriteTime
        }
        
        $tests[$category] += $testInfo
        Write-LogDebug "Found test: $testName (Category: $category)"
    }
    
    $totalTests = ($tests.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
    Write-LogInfo "Discovered $totalTests test scripts across $($tests.Keys.Count) categories"
    
    return $tests
}

#endregion

#region Test Execution

function Invoke-TestScript {
    <#
    .SYNOPSIS
        Executes a single test script
    .DESCRIPTION
        Runs a test script and captures its results
    .PARAMETER TestInfo
        Test information object
    .EXAMPLE
        Invoke-TestScript -TestInfo $testInfo
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$TestInfo
    )
    
    Write-LogInfo "Running test: $($TestInfo.Name)"
    
    $testResult = @{
        Name = $TestInfo.Name
        Category = $TestInfo.Category
        StartTime = Get-Date
        EndTime = $null
        Duration = $null
        Status = "Unknown"
        Output = ""
        ErrorMessage = ""
        ExitCode = -1
    }
    
    try {
        # Execute the test script
        $output = & PowerShell.exe -File $TestInfo.Path -Verbose:$Verbose -DetailedReport:$DetailedReport 2>&1
        $exitCode = $LASTEXITCODE
        
        $testResult.EndTime = Get-Date
        $testResult.Duration = $testResult.EndTime - $testResult.StartTime
        $testResult.Output = $output -join "`n"
        $testResult.ExitCode = $exitCode
        
        if ($exitCode -eq 0) {
            $testResult.Status = "Passed"
            Write-LogSuccess "Test passed: $($TestInfo.Name) (Duration: $($testResult.Duration.TotalSeconds)s)"
        } else {
            $testResult.Status = "Failed"
            $testResult.ErrorMessage = "Test exited with code $exitCode"
            Write-LogError "Test failed: $($TestInfo.Name) - Exit code: $exitCode"
        }
        
    } catch {
        $testResult.EndTime = Get-Date
        $testResult.Duration = $testResult.EndTime - $testResult.StartTime
        $testResult.Status = "Failed"
        $testResult.ErrorMessage = $_.Exception.Message
        Write-LogError "Test failed with exception: $($TestInfo.Name) - $($_.Exception.Message)"
    }
    
    return $testResult
}

function Invoke-TestCategory {
    <#
    .SYNOPSIS
        Executes all tests in a category
    .DESCRIPTION
        Runs all test scripts in the specified category
    .PARAMETER CategoryName
        Name of the test category
    .PARAMETER Tests
        Array of test information objects
    .EXAMPLE
        Invoke-TestCategory -CategoryName "Verification" -Tests $verificationTests
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CategoryName,
        
        [Parameter(Mandatory = $true)]
        [array]$Tests
    )
    
    Write-LogInfo "Running $($Tests.Count) tests in category: $CategoryName"
    
    $categoryResults = @()
    
    foreach ($test in $Tests) {
        $script:TestSuiteConfig.Results.TotalTests++
        
        $result = Invoke-TestScript -TestInfo $test
        $categoryResults += $result
        $script:TestSuiteConfig.Results.TestDetails += $result
        
        switch ($result.Status) {
            "Passed" { $script:TestSuiteConfig.Results.PassedTests++ }
            "Failed" { 
                $script:TestSuiteConfig.Results.FailedTests++
                if (-not $ContinueOnFailure) {
                    Write-LogError "Stopping test execution due to failure (use -ContinueOnFailure to continue)"
                    break
                }
            }
            "Skipped" { $script:TestSuiteConfig.Results.SkippedTests++ }
        }
    }
    
    return $categoryResults
}

#endregion

#region Reporting

function Generate-TestReport {
    <#
    .SYNOPSIS
        Generates comprehensive test report
    .DESCRIPTION
        Creates a detailed report of all test results
    .EXAMPLE
        Generate-TestReport
    #>
    [CmdletBinding()]
    param()
    
    $results = $script:TestSuiteConfig.Results
    $duration = (Get-Date) - $script:TestSuiteConfig.StartTime
    
    Write-Host "`n" -NoNewline
    Write-Host "=== AUGMENT VIP TEST SUITE REPORT ===" -ForegroundColor Cyan
    Write-Host "Execution Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
    Write-Host "Total Duration: $($duration.TotalSeconds) seconds" -ForegroundColor White
    Write-Host "Test Category: $TestCategory" -ForegroundColor White
    Write-Host ""
    Write-Host "Test Results Summary:" -ForegroundColor Yellow
    Write-Host "  Total Tests: $($results.TotalTests)" -ForegroundColor White
    Write-Host "  Passed: $($results.PassedTests)" -ForegroundColor Green
    Write-Host "  Failed: $($results.FailedTests)" -ForegroundColor Red
    Write-Host "  Skipped: $($results.SkippedTests)" -ForegroundColor Yellow
    
    $successRate = if ($results.TotalTests -gt 0) { 
        [Math]::Round(($results.PassedTests / $results.TotalTests) * 100, 2) 
    } else { 0 }
    Write-Host "  Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })
    
    if ($DetailedReport -and $results.TestDetails.Count -gt 0) {
        Write-Host "`nDetailed Test Results:" -ForegroundColor Yellow
        foreach ($test in $results.TestDetails) {
            $statusColor = switch ($test.Status) {
                "Passed" { "Green" }
                "Failed" { "Red" }
                "Skipped" { "Yellow" }
                default { "Gray" }
            }
            Write-Host "  [$($test.Status)] $($test.Name) - $($test.Duration.TotalSeconds)s" -ForegroundColor $statusColor
            if ($test.Status -eq "Failed" -and $test.ErrorMessage) {
                Write-Host "    Error: $($test.ErrorMessage)" -ForegroundColor Red
            }
        }
    }
    
    # Overall result
    if ($results.FailedTests -eq 0) {
        Write-Host "`nOVERALL RESULT: SUCCESS" -ForegroundColor Green
        return $true
    } else {
        Write-Host "`nOVERALL RESULT: FAILURE" -ForegroundColor Red
        return $false
    }
}

#endregion

#region Main Function

function Start-TestSuiteExecution {
    <#
    .SYNOPSIS
        Main function to execute the test suite
    .DESCRIPTION
        Orchestrates the complete test suite execution
    .EXAMPLE
        Start-TestSuiteExecution
    #>
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Starting Augment VIP Test Suite..."
    Write-LogInfo "Test Category: $TestCategory"
    Write-LogInfo "Verbose Mode: $Verbose"
    Write-LogInfo "Detailed Report: $DetailedReport"
    Write-LogInfo "Continue on Failure: $ContinueOnFailure"
    
    # Discover available tests
    $availableTests = Get-AvailableTests
    
    # Determine which tests to run
    $testsToRun = @()
    if ($TestCategory -eq "All") {
        $testsToRun = $availableTests.Values | ForEach-Object { $_ }
    } else {
        $testsToRun = $availableTests[$TestCategory]
    }
    
    if ($testsToRun.Count -eq 0) {
        Write-LogWarning "No tests found for category: $TestCategory"
        return $false
    }
    
    Write-LogInfo "Found $($testsToRun.Count) tests to execute"
    
    # Execute tests by category
    if ($TestCategory -eq "All") {
        foreach ($category in $availableTests.Keys) {
            if ($availableTests[$category].Count -gt 0) {
                Invoke-TestCategory -CategoryName $category -Tests $availableTests[$category]
            }
        }
    } else {
        Invoke-TestCategory -CategoryName $TestCategory -Tests $testsToRun
    }
    
    # Generate final report
    $success = Generate-TestReport
    
    Write-LogInfo "Test suite execution completed"
    return $success
}

#endregion

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    $success = Start-TestSuiteExecution
    exit $(if ($success) { 0 } else { 1 })
}
