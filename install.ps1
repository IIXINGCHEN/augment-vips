#Requires -Version 5.1

<#
.SYNOPSIS
    Augment VIP Remote Installation Script
    
.DESCRIPTION
    Universal PowerShell installation script that supports remote execution via:
    irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex
    
    Automatically detects platform and downloads/installs the appropriate implementation.
    
.PARAMETER Operation
    The operation to perform after installation: Clean, ModifyTelemetry, All, Preview
    
.PARAMETER NoBackup
    Skip creating backups (not recommended)
    
.PARAMETER UsePython
    Force use of Python cross-platform implementation
    
.PARAMETER UseWindows
    Force use of Windows PowerShell implementation
    
.PARAMETER SkipInstall
    Skip installation and only run operations (for existing installations)

.PARAMETER AutoInstallDependencies
    Automatically install missing dependencies (sqlite3, curl, jq) - smart skip for already installed

.PARAMETER SkipDependencyInstall
    Skip dependency installation check

.EXAMPLE
    irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex

.EXAMPLE
    irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex -Operation All

.EXAMPLE
    irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex -Operation Preview

.EXAMPLE
    irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex -Operation All -AutoInstallDependencies
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
    [switch]$SkipInstall,

    [Parameter(Mandatory = $false)]
    [switch]$AutoInstallDependencies,

    [Parameter(Mandatory = $false)]
    [switch]$SkipDependencyInstall,

    [Parameter(Mandatory = $false)]
    [switch]$Help,

    [Parameter(Mandatory = $false)]
    [switch]$DetailedOutput
)

# Global variables
$script:RepoUrl = "https://github.com/IIXINGCHEN/augment-vip"
$script:RawUrl = "https://raw.githubusercontent.com/IIXINGCHEN/augment-vip/main"
$script:InstallDir = Join-Path $env:TEMP "augment-vip-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

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
Augment VIP Remote Installation Script
=====================================

Description:
  Universal PowerShell installation script that supports remote execution.
  Automatically detects platform and installs the appropriate implementation.

Remote Usage:
  irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex
  irm $script:RawUrl/install.ps1 | iex -Operation All
  irm $script:RawUrl/install.ps1 | iex -Operation Preview

Local Usage:
  .\install.ps1 [options]

Parameters:
  -Operation <string>           Operation to perform (Clean, ModifyTelemetry, All, Preview)
  -NoBackup                    Skip creating backups (not recommended)
  -AutoInstallDependencies     Automatically install missing dependencies (smart skip for installed)
  -SkipDependencyInstall       Skip dependency installation check
  -UsePython                   Force use of Python cross-platform implementation
  -UseWindows                  Force use of Windows PowerShell implementation
  -SkipInstall                 Skip installation and only run operations
  -DetailedOutput              Enable detailed debugging output for troubleshooting
  -Help                        Show this help information

Examples:
  # Remote installation with all operations
  irm $script:RawUrl/install.ps1 | iex -Operation All

  # Remote preview without changes
  irm $script:RawUrl/install.ps1 | iex -Operation Preview

  # Smart dependency management (auto-install missing, skip installed)
  irm $script:RawUrl/install.ps1 | iex -Operation All -AutoInstallDependencies

  # Force Python implementation
  irm $script:RawUrl/install.ps1 | iex -UsePython -Operation All

Platform Support:
  - Windows: PowerShell implementation (default) or Python fallback
  - Linux/macOS: Python cross-platform implementation (via PowerShell Core)

"@ -ForegroundColor Cyan
}

function Test-GitAvailable {
    try {
        $null = Get-Command git -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
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

function Install-Repository {
    Write-Info "Installing Augment VIP repository..."
    
    if (Test-Path $script:InstallDir) {
        Remove-Item $script:InstallDir -Recurse -Force
    }
    
    New-Item -ItemType Directory -Path $script:InstallDir -Force | Out-Null
    
    if (Test-GitAvailable) {
        Write-Info "Using git to clone repository..."
        try {
            Push-Location $script:InstallDir
            git clone $script:RepoUrl . 2>&1 | Out-Null
            Pop-Location
            Write-Success "Repository cloned successfully"
            return $true
        }
        catch {
            Pop-Location
            Write-Warning "Git clone failed, falling back to download method"
        }
    }
    
    # Fallback: Download individual files
    Write-Info "Downloading repository files..."
    try {
        $filesToDownload = @(
            "scripts/augment-vip-launcher.ps1",
            "scripts/windows/vscode-cleanup-master.ps1",
            "scripts/windows/modules/Logger.psm1",
            "scripts/windows/modules/DependencyManager.psm1",
            "scripts/windows/modules/SystemDetection.psm1",
            "scripts/windows/modules/VSCodeDiscovery.psm1",
            "scripts/windows/modules/BackupManager.psm1",
            "scripts/windows/modules/DatabaseCleaner.psm1",
            "scripts/windows/modules/TelemetryModifier.psm1",
            "config/config.json"
        )

        $downloadedFiles = @()
        $failedFiles = @()

        foreach ($file in $filesToDownload) {
            $url = "$script:RawUrl/$file"
            $localPath = Join-Path $script:InstallDir $file
            $localDir = Split-Path $localPath -Parent

            if (-not (Test-Path $localDir)) {
                New-Item -ItemType Directory -Path $localDir -Force | Out-Null
            }

            Write-Info "Downloading: $file"
            try {
                Invoke-WebRequest -Uri $url -OutFile $localPath -UseBasicParsing

                # Verify file was downloaded and has content
                if ((Test-Path $localPath) -and (Get-Item $localPath).Length -gt 0) {
                    $downloadedFiles += $file
                    Write-Info "  ✓ Downloaded successfully"
                } else {
                    $failedFiles += $file
                    Write-Warning "  ✗ Downloaded but file is empty or missing"
                }
            }
            catch {
                $failedFiles += $file
                Write-Warning "  ✗ Failed to download: $($_.Exception.Message)"
            }
        }

        Write-Info "Download summary:"
        Write-Info "  Successfully downloaded: $($downloadedFiles.Count) files"
        if ($failedFiles.Count -gt 0) {
            Write-Warning "  Failed to download: $($failedFiles.Count) files"
            foreach ($failed in $failedFiles) {
                Write-Warning "    - $failed"
            }
        }

        # Check if critical files are present
        $criticalFiles = @("scripts/augment-vip-launcher.ps1")
        $missingCritical = @()

        foreach ($critical in $criticalFiles) {
            $criticalPath = Join-Path $script:InstallDir $critical
            if (-not (Test-Path $criticalPath)) {
                $missingCritical += $critical
            }
        }

        if ($missingCritical.Count -gt 0) {
            Write-Error "Critical files missing after download:"
            foreach ($missing in $missingCritical) {
                Write-Error "  - $missing"
            }
            return $false
        }

        Write-Success "Repository files downloaded successfully"
        return $true
    }
    catch {
        Write-Error "Failed to download repository: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-AugmentVIP {
    param(
        [string]$Operation,
        [bool]$CreateBackup,
        [bool]$UsePython,
        [bool]$UseWindows,
        [bool]$AutoInstallDependencies = $false,
        [bool]$SkipDependencyInstall = $false
    )

    Write-Info "Running Augment VIP Cleaner operation: $Operation"

    Push-Location $script:InstallDir

    try {
        # Use Join-Path for cross-platform compatibility
        $launcherScript = Join-Path "scripts" "augment-vip-launcher.ps1"
        $fullLauncherPath = Join-Path $script:InstallDir $launcherScript

        Write-Info "Current directory: $(Get-Location)"
        Write-Info "Looking for launcher script at: $launcherScript"
        Write-Info "Full launcher path: $fullLauncherPath"

        if (-not (Test-Path $launcherScript)) {
            Write-Error "Launcher script not found: $launcherScript"
            Write-Info "Listing contents of current directory:"
            Get-ChildItem -Path . -Recurse -Name | ForEach-Object { Write-Info "  $_" }

            Write-Info "Checking if scripts directory exists:"
            if (Test-Path "scripts") {
                Write-Info "Scripts directory found. Contents:"
                Get-ChildItem -Path "scripts" -Recurse -Name | ForEach-Object { Write-Info "  scripts\$_" }
            } else {
                Write-Warning "Scripts directory not found"
            }

            return $false
        }

        $params = @{
            "Operation" = $Operation
        }

        if (-not $CreateBackup) {
            $params["NoBackup"] = $true
        }

        if ($UsePython) {
            $params["UsePython"] = $true
        }

        if ($UseWindows) {
            $params["UseWindows"] = $true
        }

        if ($AutoInstallDependencies) {
            $params["AutoInstallDependencies"] = $true
        }

        if ($SkipDependencyInstall) {
            $params["SkipDependencyInstall"] = $true
        }

        Write-Info "Executing launcher script with parameters: $($params.Keys -join ', ')"
        & $launcherScript @params
        $success = $LASTEXITCODE -eq 0

        Pop-Location
        return $success
    }
    catch {
        Pop-Location
        Write-Error "Failed to execute Augment VIP: $($_.Exception.Message)"
        return $false
    }
}

function Main {
    if ($Help) {
        Show-Help
        return 0
    }

    # Enable detailed output if requested
    if ($DetailedOutput) {
        $VerbosePreference = "Continue"
        Write-Info "Detailed output mode enabled"
    }

    Write-Info "Augment VIP Cleaner Remote Installer v1.0.0"
    Write-Info "======================================"
    Write-Info "Repository: $script:RepoUrl"
    Write-Info "Install Directory: $script:InstallDir"

    if ($DetailedOutput) {
        Write-Info "System Information:"
        Write-Info "  PowerShell Version: $($PSVersionTable.PSVersion)"
        Write-Info "  OS: $($PSVersionTable.OS)"
        Write-Info "  Platform: $($PSVersionTable.Platform)"
        Write-Info "  Current User: $($env:USERNAME)"
        Write-Info "  Temp Directory: $($env:TEMP)"
    }
    
    if (-not $SkipInstall) {
        # Install repository
        if (-not (Install-Repository)) {
            Write-Error "Installation failed"
            return 1
        }
    }
    
    # Run operations
    $createBackup = -not $NoBackup
    
    Write-Info "Configuration:"
    Write-Info "  Operation: $Operation"
    Write-Info "  Create Backup: $createBackup"
    Write-Info "  Auto Install Dependencies: $AutoInstallDependencies"
    Write-Info "  Skip Dependency Install: $SkipDependencyInstall"
    Write-Info "  Force Python: $UsePython"
    Write-Info "  Force Windows: $UseWindows"

    $success = Invoke-AugmentVIP -Operation $Operation -CreateBackup $createBackup -UsePython $UsePython -UseWindows $UseWindows -AutoInstallDependencies $AutoInstallDependencies -SkipDependencyInstall $SkipDependencyInstall
    
    if ($success) {
        Write-Success "Operation completed successfully!"
        Write-Info ""
        Write-Info "Installation directory: $script:InstallDir"
        Write-Info "You can run operations again with:"
        Write-Info "  cd '$script:InstallDir'"
        Write-Info "  .\scripts\augment-vip-launcher.ps1 -Operation <operation>"
        return 0
    } else {
        Write-Error "Operation failed"
        return 1
    }
}

# Execute main function
exit (Main)
