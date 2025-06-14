# Augment VIP Test Suite

This directory contains comprehensive test scripts for the Augment VIP project. All testing functionality has been consolidated here for better organization and maintainability.

## 📁 Test Structure

```
test/
├── README.md                           # This file
├── Start-TestSuite.ps1                 # Main test suite runner
├── Test-AugmentCleanupVerification.ps1 # Cleanup verification tests
├── Test-ToolsFunctionality.ps1         # Tools functionality tests
└── logs/                               # Test execution logs (auto-created)
```

## 🚀 Quick Start

### Run All Tests
```powershell
# Run complete test suite
.\test\Start-TestSuite.ps1

# Run with verbose output
.\test\Start-TestSuite.ps1 -Verbose

# Run with detailed reporting
.\test\Start-TestSuite.ps1 -DetailedReport
```

### Run Specific Test Categories
```powershell
# Run only verification tests
.\test\Start-TestSuite.ps1 -TestCategory Verification

# Run only tools tests
.\test\Start-TestSuite.ps1 -TestCategory Tools

# Run only core module tests
.\test\Start-TestSuite.ps1 -TestCategory Core
```

### Run Individual Tests
```powershell
# Test cleanup verification
.\test\Test-AugmentCleanupVerification.ps1

# Test tools functionality
.\test\Test-ToolsFunctionality.ps1

# Run with detailed output
.\test\Test-AugmentCleanupVerification.ps1 -Verbose -DetailedReport
```

## 📋 Test Categories

### Verification Tests
- **Test-AugmentCleanupVerification.ps1**: Verifies that cleanup operations have been successful
- Checks for remaining Augment data in databases
- Validates telemetry ID resets
- Confirms trial account bypass effectiveness

### Tools Tests
- **Test-ToolsFunctionality.ps1**: Tests all individual tools for proper functionality
- Validates tool dependencies
- Tests core modules loading
- Executes tools in dry-run mode to verify functionality

### Core Tests
- Tests core module functionality
- Validates configuration loading
- Checks logging system operation

### Integration Tests
- End-to-end workflow testing
- Cross-component interaction validation
- Complete cleanup process verification

## 🔧 Test Parameters

### Common Parameters
- `-Verbose`: Enable detailed output during test execution
- `-DetailedReport`: Generate comprehensive test reports
- `-ContinueOnFailure`: Continue running tests even if some fail

### Test Suite Specific
- `-TestCategory`: Specify which category of tests to run (All, Verification, Tools, Core, Integration)

## 📊 Test Reports

Test results are displayed in the console with color-coded status indicators:
- 🟢 **Green**: Passed tests
- 🔴 **Red**: Failed tests  
- 🟡 **Yellow**: Warnings or skipped tests

### Report Sections
1. **Execution Summary**: Total tests, pass/fail counts, success rate
2. **Category Breakdown**: Results by test category
3. **Detailed Results**: Individual test outcomes (with -DetailedReport)
4. **Error Details**: Specific failure information

## 🔍 Troubleshooting

### Common Issues

**SQLite3 Not Found**
```powershell
# Install SQLite3 via Chocolatey
choco install sqlite

# Or download from https://sqlite.org/download.html
```

**PowerShell Execution Policy**
```powershell
# Set execution policy for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Missing Dependencies**
```powershell
# Run dependency test
.\test\Test-ToolsFunctionality.ps1 -Verbose
```

### Debug Mode
```powershell
# Run with maximum verbosity
.\test\Start-TestSuite.ps1 -Verbose -DetailedReport

# Check specific test logs
Get-Content "test\logs\test_suite.log" -Tail 50
```

## 📝 Adding New Tests

### Test Naming Convention
- All test scripts must start with `Test-`
- Use PascalCase for script names
- Example: `Test-NewFeatureFunctionality.ps1`

### Test Categories
Tests are automatically categorized based on naming patterns:
- `*Verification*`, `*Verify*`, `*Check*` → Verification
- `*Tool*`, `*Clean*`, `*Reset*`, `*Fix*` → Tools  
- `*Integration*`, `*End2End*`, `*E2E*` → Integration
- Everything else → Core

### Test Template
```powershell
# Test-YourNewTest.ps1
[CmdletBinding()]
param(
    [switch]$Verbose = $false,
    [switch]$DetailedReport = $false
)

# Import logging
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path $scriptPath -Parent
$loggerPath = Join-Path $rootPath "src\core\AugmentLogger.ps1"

if (Test-Path $loggerPath) {
    . $loggerPath
    Initialize-AugmentLogger -LogDirectory "logs" -LogFileName "your_test.log" -LogLevel "INFO"
}

# Your test logic here
function Start-YourTest {
    Write-LogInfo "Starting your test..."
    
    # Test implementation
    
    return $success
}

# Execute if run directly
if ($MyInvocation.InvocationName -ne '.') {
    $success = Start-YourTest
    exit $(if ($success) { 0 } else { 1 })
}
```

## 🎯 Best Practices

1. **Always use dry-run mode** when testing tools to avoid actual changes
2. **Include proper error handling** in test scripts
3. **Use descriptive test names** and log messages
4. **Test both success and failure scenarios**
5. **Clean up any test artifacts** after test completion
6. **Document test requirements** and expected outcomes

## 📈 Continuous Integration

These tests are designed to be run in CI/CD pipelines:

```yaml
# Example GitHub Actions step
- name: Run Augment VIP Tests
  run: |
    .\test\Start-TestSuite.ps1 -TestCategory All -ContinueOnFailure
  shell: powershell
```

## 🔗 Related Documentation

- [Main README](../README.md) - Project overview and setup
- [User Guide](../docs/User_Guide.md) - Usage instructions
- [Tools Documentation](../src/tools/README.md) - Individual tool documentation

---

**Note**: All tests are designed to be non-destructive and use dry-run modes where possible. However, always ensure you have backups before running any cleanup operations in production environments.
