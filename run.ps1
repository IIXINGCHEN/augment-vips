#Requires -Version 5.1

<#
.SYNOPSIS
    Augment VIP Quick Launcher

.DESCRIPTION
    Quick launcher script for Augment VIP operations.
    Automatically uses the cross-platform launcher for best compatibility.

.PARAMETER Operation
    The operation to perform: Clean, ModifyTelemetry, All, Preview

.PARAMETER NoBackup
    Skip creating backups (not recommended)

.PARAMETER UsePython
    Force use of Python cross-platform implementation

.PARAMETER UseWindows
    Force use of Windows PowerShell implementation

.PARAMETER Verbose
    Enable verbose output

.PARAMETER Help
    Show help information

.EXAMPLE
    .\run.ps1 -Operation All

.EXAMPLE
    .\run.ps1 -Operation Preview

.EXAMPLE
    .\run.ps1 -Operation Clean -UsePython

.EXAMPLE
    .\run.ps1 -Operation ModifyTelemetry -UseWindows -Verbose
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Clean", "ModifyTelemetry", "All", "Preview")]
    [string]$Operation = "All",

    [Parameter(Mandatory = $false)]
    [switch]$NoBackup,

    [Parameter(Mandatory = $false)]
    [switch]$UsePython,

    [Parameter(Mandatory = $false)]
    [switch]$UseWindows,

    [Parameter(Mandatory = $false)]
    [switch]$VerboseOutput,

    [Parameter(Mandatory = $false)]
    [switch]$Help
)

# Set error handling
$ErrorActionPreference = "Stop"

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LauncherScript = Join-Path $ScriptDir "scripts\augment-vip-launcher.ps1"

# Console colors
function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )

    $colorMap = @{
        "Red" = "Red"
        "Green" = "Green"
        "Yellow" = "Yellow"
        "Blue" = "Blue"
        "Cyan" = "Cyan"
        "White" = "White"
        "Magenta" = "Magenta"
    }

    if ($colorMap.ContainsKey($Color)) {
        Write-Host $Message -ForegroundColor $colorMap[$Color]
    } else {
        Write-Host $Message
    }
}

function Write-Info {
    param([string]$Message)
    Write-ColoredOutput "[INFO] $Message" "Blue"
}

function Write-Success {
    param([string]$Message)
    Write-ColoredOutput "[SUCCESS] $Message" "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColoredOutput "[WARNING] $Message" "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColoredOutput "[ERROR] $Message" "Red"
}

function Write-Debug {
    param([string]$Message)
    if ($VerboseOutput) {
        Write-ColoredOutput "[DEBUG] $Message" "Cyan"
    }
}

function Show-Help {
    Write-Host @"
Augment VIP Quick Launcher
=========================

Description:
  Quick launcher script for Augment VIP operations.
  Automatically uses the cross-platform launcher for best compatibility.

Usage:
  .\run.ps1 [options]

Parameters:
  -Operation <string>     Operation to perform (Clean, ModifyTelemetry, All, Preview)
  -NoBackup              Skip creating backups (not recommended)
  -UsePython             Force use of Python cross-platform implementation
  -UseWindows            Force use of Windows PowerShell implementation
  -VerboseOutput         Enable verbose output
  -Help                  Show this help information

Operations:
  Clean                  Clean VS Code databases by removing Augment-related entries
  ModifyTelemetry        Modify VS Code telemetry IDs to random values
  All                    Perform both clean and modify telemetry operations
  Preview                Show what would be done without making changes

Examples:
  .\run.ps1 -Operation All
  .\run.ps1 -Operation Preview
  .\run.ps1 -Operation Clean -UsePython
  .\run.ps1 -Operation ModifyTelemetry -UseWindows -VerboseOutput

Remote Installation:
  irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex

Platform Support:
  - Windows: PowerShell implementation (default) or Python fallback
  - Linux/macOS: Python cross-platform implementation (via PowerShell Core)

System Requirements:
  - Windows 10 or higher
  - PowerShell 5.1 or higher
  - For Python mode: Python 3.6+ with required packages

"@ -ForegroundColor Cyan
}

function Test-LauncherAvailable {
    if (-not (Test-Path $LauncherScript)) {
        Write-Error "Launcher script not found: $LauncherScript"
        Write-Info "Please ensure you're running this script from the project root directory"
        Write-Info "Expected project structure:"
        Write-Info "  .\run.ps1                              (this script)"
        Write-Info "  .\scripts\augment-vip-launcher.ps1     (launcher script)"
        Write-Info "  .\scripts\windows\                     (Windows implementation)"
        Write-Info "  .\scripts\cross-platform\              (Python implementation)"
        return $false
    }

    Write-Debug "Launcher script found: $LauncherScript"
    return $true
}

function Test-ProjectStructure {
    Write-Debug "Validating project structure..."

    $requiredPaths = @(
        "scripts",
        "scripts\augment-vip-launcher.ps1",
        "config",
        "config\config.json"
    )

    $missingPaths = @()

    foreach ($path in $requiredPaths) {
        $fullPath = Join-Path $ScriptDir $path
        if (-not (Test-Path $fullPath)) {
            $missingPaths += $path
        } else {
            Write-Debug "Found: $path"
        }
    }

    if ($missingPaths.Count -gt 0) {
        Write-Warning "Some project components are missing:"
        foreach ($missing in $missingPaths) {
            Write-Warning "  Missing: $missing"
        }
        Write-Info "This may affect functionality, but attempting to continue..."
        return $false
    }

    Write-Debug "Project structure validation completed successfully"
    return $true
}

function Invoke-AugmentVIPLauncher {
    param(
        [hashtable]$Parameters
    )

    Write-Info "Executing Augment VIP launcher with the following configuration:"
    Write-Info "  Operation: $($Parameters.Operation)"
    Write-Info "  Create Backup: $(-not $Parameters.ContainsKey('NoBackup'))"
    Write-Info "  Force Python: $($Parameters.ContainsKey('UsePython'))"
    Write-Info "  Force Windows: $($Parameters.ContainsKey('UseWindows'))"
    Write-Info "  Verbose Mode: $($Parameters.ContainsKey('Verbose'))"

    try {
        Write-Debug "Launching: $LauncherScript"
        Write-Debug "Parameters: $($Parameters | ConvertTo-Json -Compress)"

        & $LauncherScript @Parameters
        $exitCode = $LASTEXITCODE

        Write-Debug "Launcher completed with exit code: $exitCode"

        if ($exitCode -eq 0) {
            Write-Success "Operation completed successfully!"
            Write-Info "All Augment VIP operations have been executed successfully."
        } else {
            Write-Error "Operation failed with exit code: $exitCode"
            Write-Info "Please check the output above for error details."
            Write-Info "Common issues:"
            Write-Info "  - VS Code is currently running (close it and try again)"
            Write-Info "  - Insufficient permissions (run as administrator)"
            Write-Info "  - Missing dependencies (check system requirements)"
        }

        return $exitCode
    }
    catch {
        Write-Error "Failed to execute launcher: $($_.Exception.Message)"
        Write-Debug "Exception details: $($_.Exception | Format-List * | Out-String)"
        Write-Info "Troubleshooting steps:"
        Write-Info "  1. Ensure PowerShell execution policy allows script execution"
        Write-Info "  2. Verify all project files are present and accessible"
        Write-Info "  3. Check if antivirus software is blocking the script"
        Write-Info "  4. Try running PowerShell as administrator"
        return 1
    }
}

function Main {
    Write-Info "Augment VIP Quick Launcher v1.0.0"
    Write-Info "=================================="
    Write-Info "Project Directory: $ScriptDir"

    if ($Help) {
        Show-Help
        return 0
    }

    # Validate project structure
    Test-ProjectStructure | Out-Null

    # Check if launcher script exists
    if (-not (Test-LauncherAvailable)) {
        return 1
    }

    # Prepare parameters for the launcher
    $launcherParams = @{
        "Operation" = $Operation
    }

    if ($NoBackup) {
        $launcherParams["NoBackup"] = $true
        Write-Debug "Backup creation disabled"
    }

    if ($UsePython) {
        $launcherParams["UsePython"] = $true
        Write-Debug "Forcing Python implementation"
    }

    if ($UseWindows) {
        $launcherParams["UseWindows"] = $true
        Write-Debug "Forcing Windows implementation"
    }

    if ($VerboseOutput) {
        $launcherParams["VerboseOutput"] = $true
        Write-Debug "Verbose mode enabled"
    }

    # Validate parameter combinations
    if ($UsePython -and $UseWindows) {
        Write-Error "Cannot specify both -UsePython and -UseWindows flags"
        Write-Info "Please choose one implementation or let the system auto-detect"
        return 1
    }

    Write-Info "Starting Augment VIP operation: $Operation"

    # Execute the launcher
    $exitCode = Invoke-AugmentVIPLauncher -Parameters $launcherParams

    if ($exitCode -eq 0) {
        Write-Info ""
        Write-Success "Augment VIP Cleaner completed successfully!"
        Write-Info "You can run this script again anytime with different operations:"
        Write-Info "  .\run.ps1 -Operation Preview    # Preview changes"
        Write-Info "  .\run.ps1 -Operation Clean      # Clean databases only"
        Write-Info "  .\run.ps1 -Operation All        # Full cleanup"
    } else {
        Write-Info ""
        Write-Error "Augment VIP Cleaner failed"
        Write-Info "For help and troubleshooting, run: .\run.ps1 -Help"
    }

    return $exitCode
}

# Execute main function with proper error handling
try {
    exit (Main)
}
catch {
    Write-Error "Unexpected error in Quick Launcher: $($_.Exception.Message)"
    Write-Debug "Full exception: $($_.Exception | Format-List * | Out-String)"
    exit 1
}
