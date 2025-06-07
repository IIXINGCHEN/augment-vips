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
    
.EXAMPLE
    irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex
    
.EXAMPLE
    irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex -Operation All
    
.EXAMPLE
    irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex -Operation Preview
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
    [switch]$Help
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
  -Operation <string>     Operation to perform (Clean, ModifyTelemetry, All, Preview)
  -NoBackup              Skip creating backups (not recommended)
  -UsePython             Force use of Python cross-platform implementation
  -UseWindows            Force use of Windows PowerShell implementation
  -SkipInstall           Skip installation and only run operations
  -Help                  Show this help information

Examples:
  # Remote installation with all operations
  irm $script:RawUrl/install.ps1 | iex -Operation All
  
  # Remote preview without changes
  irm $script:RawUrl/install.ps1 | iex -Operation Preview
  
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
            "scripts/windows/modules/SystemDetection.psm1",
            "scripts/windows/modules/VSCodeDiscovery.psm1",
            "scripts/windows/modules/BackupManager.psm1",
            "scripts/windows/modules/DatabaseCleaner.psm1",
            "scripts/windows/modules/TelemetryModifier.psm1",
            "config/config.json"
        )
        
        foreach ($file in $filesToDownload) {
            $url = "$script:RawUrl/$file"
            $localPath = Join-Path $script:InstallDir $file
            $localDir = Split-Path $localPath -Parent
            
            if (-not (Test-Path $localDir)) {
                New-Item -ItemType Directory -Path $localDir -Force | Out-Null
            }
            
            Write-Info "Downloading: $file"
            Invoke-WebRequest -Uri $url -OutFile $localPath -UseBasicParsing
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
        [bool]$UseWindows
    )
    
    Write-Info "Running Augment VIP operation: $Operation"
    
    Push-Location $script:InstallDir
    
    try {
        $launcherScript = "scripts\augment-vip-launcher.ps1"
        
        if (-not (Test-Path $launcherScript)) {
            Write-Error "Launcher script not found: $launcherScript"
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
    
    Write-Info "Augment VIP Remote Installer v1.0.0"
    Write-Info "======================================"
    Write-Info "Repository: $script:RepoUrl"
    Write-Info "Install Directory: $script:InstallDir"
    
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
    Write-Info "  Force Python: $UsePython"
    Write-Info "  Force Windows: $UseWindows"
    
    $success = Invoke-AugmentVIP -Operation $Operation -CreateBackup $createBackup -UsePython $UsePython -UseWindows $UseWindows
    
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
