#Requires -Version 5.1

<#
.SYNOPSIS
    Augment VIP Remote Installation Script
    
.DESCRIPTION
    Universal PowerShell installation script that supports remote execution via:
    irm https://gh.imixc.top/raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex
    
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
    irm https://gh.imixc.top/raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex

.EXAMPLE
    irm https://gh.imixc.top/raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex -Operation All

.EXAMPLE
    irm https://gh.imixc.top/raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex -Operation Preview

.EXAMPLE
    irm https://gh.imixc.top/raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex -Operation All -AutoInstallDependencies

.EXAMPLE
    $env:AUGMENT_AUTO_INSTALL_DEPS = "true"
    irm https://gh.imixc.top/raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex

.EXAMPLE
    $env:AUGMENT_OPERATION = "All"; $env:AUGMENT_AUTO_INSTALL_DEPS = "true"
    irm https://gh.imixc.top/raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex
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
    [switch]$DetailedOutput,

    [Parameter(Mandatory = $false)]
    [switch]$Interactive
)

# Global variables
$script:RepoUrl = "https://github.com/IIXINGCHEN/augment-vip"
$script:RawUrl = "https://gh.imixc.top/raw.githubusercontent.com/IIXINGCHEN/augment-vip/main"
$script:InstallDir = Join-Path $env:TEMP "augment-vip-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Environment variable detection function
function Get-EnvironmentParameters {
    <#
    .SYNOPSIS
        Detects and converts environment variables to script parameters
    .DESCRIPTION
        Checks for predefined environment variables and converts them to script parameters.
        Environment variables have lower priority than explicit parameters.
    #>

    $envParams = @{}

    # Map environment variables to parameters
    $envMapping = @{
        'AUGMENT_OPERATION' = 'Operation'
        'AUGMENT_NO_BACKUP' = 'NoBackup'
        'AUGMENT_AUTO_INSTALL_DEPS' = 'AutoInstallDependencies'
        'AUGMENT_SKIP_DEPENDENCY_INSTALL' = 'SkipDependencyInstall'
        'AUGMENT_USE_PYTHON' = 'UsePython'
        'AUGMENT_USE_WINDOWS' = 'UseWindows'
        'AUGMENT_SKIP_INSTALL' = 'SkipInstall'
        'AUGMENT_DETAILED_OUTPUT' = 'DetailedOutput'
        'AUGMENT_INTERACTIVE' = 'Interactive'
    }

    foreach ($envVar in $envMapping.Keys) {
        $envValue = [Environment]::GetEnvironmentVariable($envVar)
        if ($envValue) {
            $paramName = $envMapping[$envVar]

            # Handle different parameter types
            switch ($paramName) {
                'Operation' {
                    # Validate operation value
                    if ($envValue -in @("Clean", "ModifyTelemetry", "All", "Preview")) {
                        $envParams[$paramName] = $envValue
                    } else {
                        Write-Warning "Invalid AUGMENT_OPERATION value: $envValue. Using default 'All'"
                        $envParams[$paramName] = "All"
                    }
                }
                default {
                    # Handle switch parameters (convert string to boolean)
                    if ($envValue -in @("true", "1", "yes", "on")) {
                        $envParams[$paramName] = $true
                    } elseif ($envValue -in @("false", "0", "no", "off")) {
                        $envParams[$paramName] = $false
                    } else {
                        # Default to true for any other non-empty value
                        $envParams[$paramName] = $true
                    }
                }
            }
        }
    }

    return $envParams
}

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
  irm https://gh.imixc.top/raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex
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
  -Interactive                 Show interactive menu after completion (auto-detected for remote execution)
  -Help                        Show this help information

Environment Variables (for remote execution):
  AUGMENT_OPERATION            Same as -Operation parameter
  AUGMENT_NO_BACKUP            Same as -NoBackup (true/false, 1/0, yes/no, on/off)
  AUGMENT_AUTO_INSTALL_DEPS    Same as -AutoInstallDependencies (true/false, 1/0, yes/no, on/off)
  AUGMENT_SKIP_DEPENDENCY_INSTALL  Same as -SkipDependencyInstall (true/false, 1/0, yes/no, on/off)
  AUGMENT_USE_PYTHON           Same as -UsePython (true/false, 1/0, yes/no, on/off)
  AUGMENT_USE_WINDOWS          Same as -UseWindows (true/false, 1/0, yes/no, on/off)
  AUGMENT_SKIP_INSTALL         Same as -SkipInstall (true/false, 1/0, yes/no, on/off)
  AUGMENT_DETAILED_OUTPUT      Same as -DetailedOutput (true/false, 1/0, yes/no, on/off)
  AUGMENT_INTERACTIVE          Same as -Interactive (true/false, 1/0, yes/no, on/off)

Examples:
  # Remote installation with all operations
  irm $script:RawUrl/install.ps1 | iex -Operation All

  # Remote preview without changes
  irm $script:RawUrl/install.ps1 | iex -Operation Preview

  # Smart dependency management (auto-install missing, skip installed)
  irm $script:RawUrl/install.ps1 | iex -Operation All -AutoInstallDependencies

  # Force Python implementation
  irm $script:RawUrl/install.ps1 | iex -UsePython -Operation All

  # Using environment variables for remote execution
  `$env:AUGMENT_AUTO_INSTALL_DEPS = "true"
  irm $script:RawUrl/install.ps1 | iex

  # Multiple environment variables
  `$env:AUGMENT_OPERATION = "All"; `$env:AUGMENT_AUTO_INSTALL_DEPS = "true"
  irm $script:RawUrl/install.ps1 | iex

  # Environment variables with detailed output
  `$env:AUGMENT_DETAILED_OUTPUT = "true"; `$env:AUGMENT_AUTO_INSTALL_DEPS = "true"
  irm $script:RawUrl/install.ps1 | iex

Platform Support:
  - Windows: PowerShell implementation (default) or Python fallback
  - Linux/macOS: Python cross-platform implementation (via PowerShell Core)

Note: Environment variables have lower priority than explicit parameters.
      Explicit parameters will override environment variable settings.

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

function Test-InteractiveSession {
    <#
    .SYNOPSIS
        Detects if the current session supports interactive input
    .DESCRIPTION
        Checks various indicators to determine if the session can handle user interaction
    #>

    # Check if we're in an interactive PowerShell session
    if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
        return $true
    }

    # Check if we have a console window
    try {
        $null = [Console]::WindowWidth
        return $true
    }
    catch {
        return $false
    }
}

function Show-PostInstallMenu {
    <#
    .SYNOPSIS
        Shows an interactive menu after installation completion
    .DESCRIPTION
        Provides user-friendly options to continue working with Augment VIP
    #>
    param(
        [string]$InstallDirectory,
        [bool]$LastOperationSuccess = $true
    )

    Write-Host ""
    Write-ColoredOutput "╔══════════════════════════════════════════════════════════════╗" "Cyan"
    Write-ColoredOutput "║                    Augment VIP - 操作完成                     ║" "Cyan"
    Write-ColoredOutput "╚══════════════════════════════════════════════════════════════╝" "Cyan"
    Write-Host ""

    if ($LastOperationSuccess) {
        Write-Success "✓ 操作已成功完成！"
    } else {
        Write-Warning "⚠ 操作完成，但可能存在一些问题"
    }

    Write-Host ""
    Write-Info "安装目录: $InstallDirectory"
    Write-Host ""

    do {
        Write-ColoredOutput "请选择下一步操作:" "Yellow"
        Write-Host "  [1] 重新运行清理操作 (All)"
        Write-Host "  [2] 仅清理数据库 (Clean)"
        Write-Host "  [3] 仅修改遥测ID (ModifyTelemetry)"
        Write-Host "  [4] 预览模式 (Preview)"
        Write-Host "  [5] 打开安装目录"
        Write-Host "  [6] 显示帮助信息"
        Write-Host "  [0] 退出"
        Write-Host ""

        $choice = Read-Host "请输入选择 (0-6)"

        switch ($choice) {
            "1" {
                Write-Info "重新运行完整清理操作..."
                Push-Location $InstallDirectory
                try {
                    & ".\scripts\augment-vip-launcher.ps1" -Operation "All"
                    Write-Success "操作完成！"
                } catch {
                    Write-Error "操作失败: $($_.Exception.Message)"
                } finally {
                    Pop-Location
                }
                Write-Host ""
            }
            "2" {
                Write-Info "运行数据库清理操作..."
                Push-Location $InstallDirectory
                try {
                    & ".\scripts\augment-vip-launcher.ps1" -Operation "Clean"
                    Write-Success "数据库清理完成！"
                } catch {
                    Write-Error "操作失败: $($_.Exception.Message)"
                } finally {
                    Pop-Location
                }
                Write-Host ""
            }
            "3" {
                Write-Info "运行遥测ID修改操作..."
                Push-Location $InstallDirectory
                try {
                    & ".\scripts\augment-vip-launcher.ps1" -Operation "ModifyTelemetry"
                    Write-Success "遥测ID修改完成！"
                } catch {
                    Write-Error "操作失败: $($_.Exception.Message)"
                } finally {
                    Pop-Location
                }
                Write-Host ""
            }
            "4" {
                Write-Info "运行预览模式..."
                Push-Location $InstallDirectory
                try {
                    & ".\scripts\augment-vip-launcher.ps1" -Operation "Preview"
                    Write-Success "预览完成！"
                } catch {
                    Write-Error "操作失败: $($_.Exception.Message)"
                } finally {
                    Pop-Location
                }
                Write-Host ""
            }
            "5" {
                Write-Info "打开安装目录: $InstallDirectory"
                try {
                    if ($IsWindows -or $PSVersionTable.PSEdition -eq "Desktop") {
                        Start-Process "explorer.exe" -ArgumentList $InstallDirectory
                    } else {
                        Write-Info "请手动导航到: $InstallDirectory"
                    }
                } catch {
                    Write-Warning "无法自动打开目录，请手动导航到: $InstallDirectory"
                }
                Write-Host ""
            }
            "6" {
                Show-Help
                Write-Host ""
            }
            "0" {
                Write-Info "感谢使用 Augment VIP！"
                return
            }
            default {
                Write-Warning "无效选择，请输入 0-6 之间的数字"
                Write-Host ""
            }
        }
    } while ($choice -ne "0")
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
            Write-Info "Cloning from: $script:RepoUrl"
            Write-Info "Target directory: $script:InstallDir"

            $gitOutput = git clone $script:RepoUrl . 2>&1
            $gitExitCode = $LASTEXITCODE

            Pop-Location

            if ($gitExitCode -eq 0) {
                Write-Success "Repository cloned successfully"

                # Verify critical files exist
                $criticalFiles = @("scripts\augment-vip-launcher.ps1", "config\config.json")
                $missingFiles = @()

                foreach ($file in $criticalFiles) {
                    $fullPath = Join-Path $script:InstallDir $file
                    if (-not (Test-Path $fullPath)) {
                        $missingFiles += $file
                    }
                }

                if ($missingFiles.Count -gt 0) {
                    Write-Warning "Git clone completed but some critical files are missing:"
                    foreach ($missing in $missingFiles) {
                        Write-Warning "  - $missing"
                    }
                    Write-Warning "Falling back to download method"
                } else {
                    return $true
                }
            } else {
                Write-Warning "Git clone failed with exit code: $gitExitCode"
                Write-Warning "Git output: $($gitOutput -join "`n")"
                Write-Warning "Falling back to download method"
            }
        }
        catch {
            Pop-Location
            Write-Warning "Git clone failed with exception: $($_.Exception.Message)"
            Write-Warning "Falling back to download method"
        }
    }
    
    # Fallback: Download individual files
    Write-Info "Downloading repository files..."
    try {
        $filesToDownload = @(
            # Main launcher and scripts
            "scripts/augment-vip-launcher.ps1",
            "scripts/windows/vscode-cleanup-master.ps1",

            # Windows PowerShell modules
            "scripts/windows/modules/Logger.psm1",
            "scripts/windows/modules/DependencyManager.psm1",
            "scripts/windows/modules/SystemDetection.psm1",
            "scripts/windows/modules/VSCodeDiscovery.psm1",
            "scripts/windows/modules/BackupManager.psm1",
            "scripts/windows/modules/DatabaseCleaner.psm1",
            "scripts/windows/modules/TelemetryModifier.psm1",
            "scripts/windows/modules/CommonUtils.psm1",
            "scripts/windows/modules/UnifiedServices.psm1",

            # Cross-platform Python scripts
            "scripts/cross-platform/install.py",
            "scripts/cross-platform/augment_vip/__init__.py",
            "scripts/cross-platform/augment_vip/cli.py",
            "scripts/cross-platform/augment_vip/db_cleaner.py",
            "scripts/cross-platform/augment_vip/id_modifier.py",
            "scripts/cross-platform/augment_vip/utils.py",

            # Common utilities
            "scripts/common/config_loader.py",
            "scripts/common/id_generator.py",
            "scripts/common/transaction_manager.py",

            # Linux scripts
            "scripts/linux/install.sh",

            # Configuration files
            "config/config.json",
            "config/schema.json"
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
    # Detect environment variables and merge with explicit parameters
    $envParams = Get-EnvironmentParameters

    # Merge environment parameters with explicit parameters (explicit takes precedence)
    foreach ($envParam in $envParams.Keys) {
        $currentValue = Get-Variable -Name $envParam -ValueOnly -ErrorAction SilentlyContinue

        # Only use environment variable if explicit parameter wasn't provided
        switch ($envParam) {
            'Operation' {
                if ($Operation -eq "All" -and $envParams[$envParam] -ne "All") {
                    # Default value wasn't changed, use environment variable
                    $script:Operation = $envParams[$envParam]
                }
            }
            'NoBackup' {
                if (-not $NoBackup -and $envParams[$envParam]) {
                    $script:NoBackup = $envParams[$envParam]
                }
            }
            'AutoInstallDependencies' {
                if (-not $AutoInstallDependencies -and $envParams[$envParam]) {
                    $script:AutoInstallDependencies = $envParams[$envParam]
                }
            }
            'SkipDependencyInstall' {
                if (-not $SkipDependencyInstall -and $envParams[$envParam]) {
                    $script:SkipDependencyInstall = $envParams[$envParam]
                }
            }
            'UsePython' {
                if (-not $UsePython -and $envParams[$envParam]) {
                    $script:UsePython = $envParams[$envParam]
                }
            }
            'UseWindows' {
                if (-not $UseWindows -and $envParams[$envParam]) {
                    $script:UseWindows = $envParams[$envParam]
                }
            }
            'SkipInstall' {
                if (-not $SkipInstall -and $envParams[$envParam]) {
                    $script:SkipInstall = $envParams[$envParam]
                }
            }
            'DetailedOutput' {
                if (-not $DetailedOutput -and $envParams[$envParam]) {
                    $script:DetailedOutput = $envParams[$envParam]
                }
            }
            'Interactive' {
                if (-not $Interactive -and $envParams[$envParam]) {
                    $script:Interactive = $envParams[$envParam]
                }
            }
        }
    }

    if ($Help) {
        Show-Help
        return 0
    }

    # Enable detailed output if requested (after environment variable processing)
    if ($DetailedOutput) {
        $VerbosePreference = "Continue"
        Write-Info "Detailed output mode enabled"

        # Show parameter sources when detailed output is enabled
        if ($envParams.Count -gt 0) {
            Write-Info "Environment variables detected:"
            foreach ($envParam in $envParams.Keys) {
                Write-Info "  $envParam = $($envParams[$envParam])"
            }
        }
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

    # Determine if we should show interactive menu
    $shouldShowMenu = $false

    if ($Interactive) {
        # Explicitly requested interactive mode
        $shouldShowMenu = $true
    } elseif (-not $Interactive -and (Test-InteractiveSession)) {
        # Auto-detect: show menu for interactive sessions unless explicitly disabled
        $shouldShowMenu = $true
    }

    if ($success) {
        Write-Success "Operation completed successfully!"

        if ($shouldShowMenu) {
            # Show interactive menu
            Show-PostInstallMenu -InstallDirectory $script:InstallDir -LastOperationSuccess $true
        } else {
            # Traditional output for non-interactive sessions
            Write-Info ""
            Write-Info "Installation directory: $script:InstallDir"
            Write-Info "You can run operations again with:"
            Write-Info "  cd '$script:InstallDir'"
            Write-Info "  .\scripts\augment-vip-launcher.ps1 -Operation <operation>"
        }
        return 0
    } else {
        Write-Error "Operation failed"

        if ($shouldShowMenu) {
            # Show interactive menu even on failure for troubleshooting
            Show-PostInstallMenu -InstallDirectory $script:InstallDir -LastOperationSuccess $false
        } else {
            Write-Info ""
            Write-Info "Installation directory: $script:InstallDir"
            Write-Info "You can try running operations manually with:"
            Write-Info "  cd '$script:InstallDir'"
            Write-Info "  .\scripts\augment-vip-launcher.ps1 -Operation <operation>"
        }
        return 1
    }
}

# Execute main function
exit (Main)
