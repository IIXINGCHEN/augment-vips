#Requires -Version 5.1

<#
.SYNOPSIS
    Augment VIP Cross-Platform Launcher
    
.DESCRIPTION
    Universal launcher script that automatically detects the platform and runs
    the appropriate Augment VIP implementation (Windows PowerShell or Cross-Platform Python).
    
.PARAMETER Operation
    The operation to perform: Clean, ModifyTelemetry, All, Preview
    
.PARAMETER NoBackup
    Skip creating backups (not recommended)
    
.PARAMETER Help
    Show help information
    
.PARAMETER UsePython
    Force use of Python cross-platform implementation
    
.PARAMETER UseWindows
    Force use of Windows PowerShell implementation
    
.EXAMPLE
    .\scripts\augment-vip-launcher.ps1 -Operation All
    
.EXAMPLE
    .\scripts\augment-vip-launcher.ps1 -Operation Preview
    
.EXAMPLE
    .\scripts\augment-vip-launcher.ps1 -Operation Clean -UsePython
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Clean", "ModifyTelemetry", "All", "Preview")]
    [string]$Operation = "All",
    
    [Parameter(Mandatory = $false)]
    [switch]$NoBackup,
    
    [Parameter(Mandatory = $false)]
    [switch]$Help,
    
    [Parameter(Mandatory = $false)]
    [switch]$UsePython,
    
    [Parameter(Mandatory = $false)]
    [switch]$UseWindows,
    
    [Parameter(Mandatory = $false)]
    [switch]$VerboseOutput
)

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

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
    }
    
    if ($colorMap.ContainsKey($Color)) {
        Write-Host $Message -ForegroundColor $colorMap[$Color]
    } else {
        Write-Host $Message
    }
}

function Write-Info { param([string]$Message) Write-ColoredOutput "[INFO] $Message" "Blue" }
function Write-Success { param([string]$Message) Write-ColoredOutput "[SUCCESS] $Message" "Green" }
function Write-Warning { param([string]$Message) Write-ColoredOutput "[WARNING] $Message" "Yellow" }
function Write-Error { param([string]$Message) Write-ColoredOutput "[ERROR] $Message" "Red" }

function Show-Help {
    Write-Host @"
Augment VIP Cross-Platform Launcher
===================================

Description:
  Universal launcher that automatically detects the platform and runs
  the appropriate Augment VIP implementation.

Usage:
  .\scripts\augment-vip-launcher.ps1 [options]

Parameters:
  -Operation <string>     Operation to perform (Clean, ModifyTelemetry, All, Preview)
  -NoBackup              Skip creating backups (not recommended)
  -UsePython             Force use of Python cross-platform implementation
  -UseWindows            Force use of Windows PowerShell implementation
  -VerboseOutput         Enable verbose output
  -Help                  Show this help information

Examples:
  .\scripts\augment-vip-launcher.ps1 -Operation All
  .\scripts\augment-vip-launcher.ps1 -Operation Preview
  .\scripts\augment-vip-launcher.ps1 -Operation Clean -UsePython

Platform Detection:
  - Windows: Uses PowerShell implementation by default
  - Linux/macOS: Uses Python cross-platform implementation
  - Override with -UsePython or -UseWindows flags

"@ -ForegroundColor Cyan
}

function Test-PythonAvailable {
    try {
        $pythonVersion = python --version 2>&1
        if ($pythonVersion -match "Python 3\.") {
            return $true
        }
        
        $python3Version = python3 --version 2>&1
        if ($python3Version -match "Python 3\.") {
            return $true
        }
        
        return $false
    }
    catch {
        return $false
    }
}

function Test-WindowsImplementationAvailable {
    $windowsScript = Join-Path $ProjectRoot "scripts\windows\vscode-cleanup-master.ps1"
    return Test-Path $windowsScript
}

function Test-PythonImplementationAvailable {
    $pythonScript = Join-Path $ProjectRoot "scripts\cross-platform\augment_vip\cli.py"
    return Test-Path $pythonScript
}

function Invoke-WindowsImplementation {
    param(
        [string]$Operation,
        [bool]$CreateBackup
    )
    
    $windowsScript = Join-Path $ProjectRoot "scripts\windows\vscode-cleanup-master.ps1"
    
    if (-not (Test-Path $windowsScript)) {
        Write-Error "Windows implementation not found at: $windowsScript"
        return $false
    }
    
    Write-Info "Using Windows PowerShell implementation"
    
    # Map operations to Windows script parameters
    $scriptArgs = @{}

    switch ($Operation) {
        "Clean" { $scriptArgs["Clean"] = $true }
        "ModifyTelemetry" { $scriptArgs["ModifyTelemetry"] = $true }
        "All" { $scriptArgs["All"] = $true }
        "Preview" {
            $scriptArgs["Preview"] = $true
            $scriptArgs["All"] = $true  # Preview needs a target operation
        }
    }

    if (-not $CreateBackup) {
        $scriptArgs["NoBackup"] = $true
    }

    # Note: Verbose is handled by PowerShell's built-in mechanism via [CmdletBinding()]
    # We don't need to explicitly pass -Verbose parameter

    try {
        $paramString = ($scriptArgs.GetEnumerator() | ForEach-Object { "-$($_.Key)" }) -join ' '
        Write-Debug "Executing: $windowsScript $paramString"
        & $windowsScript @scriptArgs
        return $LASTEXITCODE -eq 0
    }
    catch {
        Write-Error "Failed to execute Windows implementation: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-PythonImplementation {
    param(
        [string]$Operation,
        [bool]$CreateBackup
    )
    
    $crossPlatformDir = Join-Path $ProjectRoot "scripts\cross-platform"
    $venvPath = Join-Path $crossPlatformDir ".venv"
    
    # Determine Python executable path
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        $pythonExe = Join-Path $venvPath "Scripts\augment-vip.exe"
        if (-not (Test-Path $pythonExe)) {
            $pythonExe = Join-Path $venvPath "Scripts\python.exe"
        }
    } else {
        $pythonExe = Join-Path $venvPath "bin\augment-vip"
        if (-not (Test-Path $pythonExe)) {
            $pythonExe = Join-Path $venvPath "bin\python"
        }
    }
    
    if (-not (Test-Path $pythonExe)) {
        Write-Error "Python implementation not installed. Please run the installation script first."
        Write-Info "To install: cd scripts/cross-platform && python install.py"
        return $false
    }
    
    Write-Info "Using Python cross-platform implementation"
    
    # Map operations to Python script commands
    $command = switch ($Operation) {
        "Clean" { "clean" }
        "ModifyTelemetry" { "modify-ids" }
        "All" { "all" }
        "Preview" { "preview" }
    }
    
    $params = @($command)
    
    if (-not $CreateBackup) {
        $params += "--no-backup"
    }
    
    try {
        Push-Location $crossPlatformDir
        & $pythonExe @params
        $exitCode = $LASTEXITCODE
        Pop-Location
        return $exitCode -eq 0
    }
    catch {
        Pop-Location
        Write-Error "Failed to execute Python implementation: $($_.Exception.Message)"
        return $false
    }
}

function Select-Implementation {
    # If user explicitly requested an implementation, use it
    if ($UsePython) {
        if (Test-PythonImplementationAvailable) {
            return "Python"
        } else {
            Write-Error "Python implementation not available"
            return $null
        }
    }
    
    if ($UseWindows) {
        if (Test-WindowsImplementationAvailable) {
            return "Windows"
        } else {
            Write-Error "Windows implementation not available"
            return $null
        }
    }
    
    # Auto-detect based on platform and availability
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        # On Windows, prefer PowerShell implementation
        if (Test-WindowsImplementationAvailable) {
            return "Windows"
        } elseif (Test-PythonImplementationAvailable -and Test-PythonAvailable) {
            Write-Warning "Windows implementation not available, falling back to Python"
            return "Python"
        }
    } else {
        # On Linux/macOS, prefer Python implementation
        if (Test-PythonImplementationAvailable -and Test-PythonAvailable) {
            return "Python"
        } elseif (Test-WindowsImplementationAvailable) {
            Write-Warning "Python implementation not available, falling back to Windows (PowerShell Core required)"
            return "Windows"
        }
    }
    
    Write-Error "No suitable implementation available"
    return $null
}

# Main execution
function Main {
    if ($Help) {
        Show-Help
        return 0
    }
    
    Write-Info "Augment VIP Cross-Platform Launcher v1.0.0"
    Write-Info "Project root: $ProjectRoot"
    
    # Select implementation
    $implementation = Select-Implementation
    
    if (-not $implementation) {
        Write-Error "Cannot determine which implementation to use"
        Write-Info "Available options:"
        Write-Info "  - Install Python implementation: cd scripts/cross-platform && python install.py"
        Write-Info "  - Use Windows implementation: -UseWindows flag"
        return 1
    }
    
    $createBackup = -not $NoBackup
    
    Write-Info "Selected implementation: $implementation"
    Write-Info "Operation: $Operation"
    Write-Info "Create backup: $createBackup"
    
    # Execute the selected implementation
    $success = switch ($implementation) {
        "Windows" { Invoke-WindowsImplementation -Operation $Operation -CreateBackup $createBackup }
        "Python" { Invoke-PythonImplementation -Operation $Operation -CreateBackup $createBackup }
        default { 
            Write-Error "Unknown implementation: $implementation"
            $false
        }
    }
    
    if ($success) {
        Write-Success "Operation completed successfully!"
        return 0
    } else {
        Write-Error "Operation failed"
        return 1
    }
}

# Execute main function
exit (Main)
