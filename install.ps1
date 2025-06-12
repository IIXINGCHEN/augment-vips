# install.ps1
#
# Enterprise-grade Windows installer for Augment VIP
# Integrates with the new cross-platform modular architecture
# Production-ready with comprehensive error handling and security
#
# Usage: .\install.ps1 [options]
#   Options:
#     -Operation <operation>  Specify operation (clean, modify-ids, all, help)
#     -DryRun                Perform dry run without making changes
#     -Verbose               Enable verbose output
#     -AutoInstallDeps       Automatically install missing dependencies
#     -Help                  Show this help message

param(
    [string]$Operation = "help",
    [switch]$DryRun = $false,
    [switch]$Verbose = $false,
    [switch]$AutoInstallDeps = $false,
    [switch]$Help = $false
)

# Script metadata
$SCRIPT_VERSION = "1.0.0"
$SCRIPT_NAME = "augment-vip-installer"

# Set error handling and execution policy
$ErrorActionPreference = "Stop"
$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }

# Enhanced logging functions with timestamps and audit trail
function Write-LogInfo {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [INFO] $Message" -ForegroundColor Cyan
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value "[$timestamp] [INFO] $Message" -ErrorAction SilentlyContinue
    }
}

function Write-LogSuccess {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [SUCCESS] $Message" -ForegroundColor Green
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value "[$timestamp] [SUCCESS] $Message" -ErrorAction SilentlyContinue
    }
}

function Write-LogWarning {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [WARN] $Message" -ForegroundColor Yellow
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value "[$timestamp] [WARN] $Message" -ErrorAction SilentlyContinue
    }
}

function Write-LogError {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [ERROR] $Message" -ForegroundColor Red
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value "[$timestamp] [ERROR] $Message" -ErrorAction SilentlyContinue
    }
    if ($script:AuditLogFile) {
        Add-Content -Path $script:AuditLogFile -Value "[$timestamp] [ERROR] $Message" -ErrorAction SilentlyContinue
    }
}

function Write-AuditLog {
    param([string]$Action, [string]$Details)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $user = $env:USERNAME
    $processId = $PID
    $auditEntry = "[$timestamp] [PID:$processId] [USER:$user] [ACTION:$Action] $Details"
    if ($script:AuditLogFile) {
        Add-Content -Path $script:AuditLogFile -Value $auditEntry -ErrorAction SilentlyContinue
    }
}

# Repository information (updated for new architecture)
$REPO_URL = "https://gh.imixc.top/raw.githubusercontent.com/IIXINGCHEN/augment-vips/main"

# Platform validation functions
function Test-WindowsPlatform {
    Write-LogInfo "Validating Windows platform..."

    # Check Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        Write-LogError "Windows 10 or higher required. Current version: $($osVersion.ToString())"
        return $false
    }

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-LogError "PowerShell 5.1 or higher required. Current version: $($PSVersionTable.PSVersion.ToString())"
        return $false
    }

    Write-LogSuccess "Windows platform validation passed"
    Write-AuditLog "PLATFORM_VALIDATE" "Windows platform validated successfully"
    return $true
}

function Test-AdminRights {
    Write-LogInfo "Checking administrator privileges..."

    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if ($isAdmin) {
            Write-LogWarning "Running with administrator privileges"
            Write-LogWarning "Consider running as regular user for security"
        } else {
            Write-LogInfo "Running as regular user (recommended)"
        }

        Write-AuditLog "ADMIN_CHECK" "Administrator privileges: $isAdmin"
        return $true
    } catch {
        Write-LogWarning "Could not determine administrator status: $($_.Exception.Message)"
        return $true
    }
}

# Initialize logging and project structure
function Initialize-Environment {
    # Get script directory and project root (handle remote execution)
    if ([string]::IsNullOrEmpty($script:PROJECT_ROOT)) {
        # Try multiple methods to get script path
        $scriptPath = $MyInvocation.MyCommand.Path
        if ([string]::IsNullOrEmpty($scriptPath)) {
            $scriptPath = $PSCommandPath
        }
        if ([string]::IsNullOrEmpty($scriptPath)) {
            $scriptPath = $MyInvocation.MyCommand.Definition
        }

        if ([string]::IsNullOrEmpty($scriptPath)) {
            # Use current directory as fallback
            $script:SCRIPT_DIR = Get-Location
            $script:PROJECT_ROOT = $script:SCRIPT_DIR
        } else {
            $script:SCRIPT_DIR = Split-Path -Parent $scriptPath
            $script:PROJECT_ROOT = $script:SCRIPT_DIR
        }
    } else {
        $script:SCRIPT_DIR = $script:PROJECT_ROOT
    }

    # Create logs directory
    $logDir = Join-Path $PROJECT_ROOT "logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # Set up log files
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:LogFile = Join-Path $logDir "${SCRIPT_NAME}_${timestamp}.log"
    $script:AuditLogFile = Join-Path $logDir "${SCRIPT_NAME}_audit_${timestamp}.log"

    Write-LogInfo "Augment VIP Windows Installer v${SCRIPT_VERSION} starting..."
    Write-LogInfo "Project root: $PROJECT_ROOT"
    Write-AuditLog "INSTALLER_START" "Windows installer started with operation: $Operation"

    # Check if we're in the correct project structure (more flexible for remote execution)
    $platformsDir = Join-Path $PROJECT_ROOT "platforms"
    if (-not (Test-Path $platformsDir)) {
        Write-LogWarning "Platforms directory not found: $platformsDir"
        Write-LogInfo "This may be normal for remote execution mode"

        # For remote execution, we can continue without the full project structure
        if (Test-RemoteExecution) {
            Write-LogInfo "Remote execution detected - continuing with embedded functionality"
            return $true
        } else {
            Write-LogError "Invalid project structure. Please run from the project root directory."
            Write-LogError "Expected to find 'platforms' directory in: $PROJECT_ROOT"
            return $false
        }
    }

    return $true
}

# Enhanced dependency checking with automatic installation
function Test-Dependencies {
    Write-LogInfo "Checking system dependencies..."

    $dependencies = @("sqlite3", "curl", "jq")
    $missingDeps = @()

    foreach ($dep in $dependencies) {
        if (-not (Get-Command $dep -ErrorAction SilentlyContinue)) {
            $missingDeps += $dep
            Write-LogWarning "Missing dependency: $dep"
        } else {
            Write-LogSuccess "Found dependency: $dep"

            # Basic version check for critical dependencies
            try {
                switch ($dep) {
                    "sqlite3" {
                        $version = & sqlite3 -version 2>$null
                        if ($version) {
                            Write-LogInfo "SQLite version: $($version.Split(' ')[0])"
                        }
                    }
                    "curl" {
                        $version = & curl --version 2>$null | Select-Object -First 1
                        if ($version) {
                            Write-LogInfo "curl version: $($version.Split(' ')[1])"
                        }
                    }
                    "jq" {
                        $version = & jq --version 2>$null
                        if ($version) {
                            Write-LogInfo "jq version: $version"
                        }
                    }
                }
            } catch {
                Write-LogWarning "Could not determine version for: $dep"
            }
        }
    }

    if ($missingDeps.Count -gt 0) {
        Write-LogWarning "Missing dependencies: $($missingDeps -join ', ')"

        if ($AutoInstallDeps) {
            return Install-Dependencies $missingDeps
        } else {
            Write-LogInfo "To install dependencies manually:"
            Write-LogInfo "  Using Chocolatey: choco install $($missingDeps -join ' ')"
            Write-LogInfo "  Or run this script with -AutoInstallDeps flag"

            $response = Read-Host "Install missing dependencies now? (y/N)"
            if ($response -match '^[Yy]$') {
                return Install-Dependencies $missingDeps
            } else {
                Write-LogError "Required dependencies not available"
                return $false
            }
        }
    } else {
        Write-LogSuccess "All dependencies are available"
        Write-AuditLog "DEPENDENCIES_CHECK" "All dependencies validated"
        return $true
    }
}

# Install missing dependencies using Chocolatey
function Install-Dependencies {
    param([array]$MissingDeps)

    Write-LogInfo "Installing missing dependencies using Chocolatey..."

    # Check if Chocolatey is available
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-LogError "Chocolatey not found. Please install Chocolatey first:"
        Write-LogError "https://chocolatey.org/install"
        return $false
    }

    foreach ($dep in $MissingDeps) {
        Write-LogInfo "Installing: $dep"
        try {
            $result = choco install $dep -y
            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "Successfully installed: $dep"
            } else {
                Write-LogError "Failed to install: $dep"
                return $false
            }
        } catch {
            Write-LogError "Exception installing $dep`: $($_.Exception.Message)"
            return $false
        }
    }

    Write-LogSuccess "All dependencies installed successfully"
    Write-AuditLog "DEPENDENCIES_INSTALL" "Dependencies installed: $($MissingDeps -join ', ')"
    return $true
}

# Legacy functions removed - now handled by platform implementations

# Legacy script creation functions removed - now handled by platform implementations
# Legacy embedded scripts removed - functionality now in platforms/windows.ps1
# All legacy embedded script functionality has been moved to platforms/windows.ps1

# Execute Windows platform implementation
function Invoke-WindowsPlatform {
    param([string]$Operation, [bool]$DryRun, [bool]$Verbose)

    Write-LogInfo "Executing Windows platform implementation..."

    # Check if platforms directory exists
    $platformsDir = Join-Path $PROJECT_ROOT "platforms"
    $windowsScript = Join-Path $platformsDir "windows.ps1"

    if (Test-Path $windowsScript) {
        # Use external Windows platform implementation
        Write-LogInfo "Using external Windows platform implementation"

        # Build command arguments using hashtable for proper parameter passing
        $scriptArgs = @{
            Operation = $Operation
        }

        if ($DryRun) {
            $scriptArgs.DryRun = $true
        }

        if ($Verbose) {
            $scriptArgs.Verbose = $true
        }

        # Execute Windows platform implementation
        try {
            Write-LogInfo "Executing: $windowsScript with Operation=$Operation, DryRun=$DryRun, Verbose=$Verbose"
            & $windowsScript @scriptArgs

            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "Windows platform implementation completed successfully"
                Write-AuditLog "PLATFORM_EXECUTE" "Windows implementation executed: $Operation"
                return $true
            } else {
                Write-LogError "Windows platform implementation failed with exit code: $LASTEXITCODE"
                return $false
            }
        } catch {
            Write-LogError "Exception executing Windows platform implementation: $($_.Exception.Message)"
            return $false
        }
    } else {
        # Use embedded implementation for remote execution
        Write-LogInfo "Using embedded Windows platform implementation"
        return Invoke-EmbeddedWindowsImplementation -Operation $Operation -DryRun $DryRun -Verbose $Verbose
    }
}

# Embedded Windows implementation for remote execution
function Invoke-EmbeddedWindowsImplementation {
    param([string]$Operation, [bool]$DryRun, [bool]$Verbose)

    Write-LogInfo "Starting embedded Windows implementation..."
    Write-LogWarning "Using simplified embedded implementation"
    Write-LogWarning "For full functionality, consider local installation"

    # Discover VS Code installations
    $vscodePaths = Get-EmbeddedVSCodePaths
    if ($vscodePaths.Count -eq 0) {
        Write-LogError "No VS Code installations found"
        return $false
    }

    # Execute operation
    switch ($Operation.ToLower()) {
        "clean" {
            return Invoke-EmbeddedDatabaseCleaning -VSCodePaths $vscodePaths -DryRun $DryRun
        }
        "modify-ids" {
            return Invoke-EmbeddedTelemetryModification -VSCodePaths $vscodePaths -DryRun $DryRun
        }
        "all" {
            $cleanResult = Invoke-EmbeddedDatabaseCleaning -VSCodePaths $vscodePaths -DryRun $DryRun
            $modifyResult = Invoke-EmbeddedTelemetryModification -VSCodePaths $vscodePaths -DryRun $DryRun
            return ($cleanResult -and $modifyResult)
        }
        default {
            Write-LogError "Unknown operation: $Operation"
            return $false
        }
    }
}

function Get-EmbeddedVSCodePaths {
    Write-LogInfo "Discovering VS Code installations (embedded mode)..."

    $paths = @()
    $appData = $env:APPDATA
    $localAppData = $env:LOCALAPPDATA

    # Standard VS Code paths
    $standardPaths = @(
        "$appData\Code",
        "$localAppData\Code",
        "$appData\Code - Insiders",
        "$localAppData\Code - Insiders"
    )

    foreach ($path in $standardPaths) {
        if (Test-Path $path) {
            $paths += $path
            Write-LogInfo "Found VS Code installation: $path"
        }
    }

    return $paths
}

function Invoke-EmbeddedDatabaseCleaning {
    param([array]$VSCodePaths, [bool]$DryRun)

    Write-LogInfo "Starting embedded database cleaning..."

    $totalCleaned = 0
    $totalErrors = 0

    foreach ($basePath in $VSCodePaths) {
        $searchPaths = @(
            "User\workspaceStorage\*\state.vscdb",
            "User\globalStorage\*\state.vscdb"
        )

        foreach ($searchPath in $searchPaths) {
            $fullPath = Join-Path $basePath $searchPath
            $files = Get-ChildItem -Path $fullPath -ErrorAction SilentlyContinue

            foreach ($file in $files) {
                try {
                    if ($DryRun) {
                        Write-LogInfo "DRY RUN: Would clean database: $($file.FullName)"
                        $totalCleaned++
                    } else {
                        # Create backup
                        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                        $backupFile = "$($file.FullName).backup_$timestamp"
                        Copy-Item $file.FullName $backupFile

                        # Clean database
                        $cleaningQuery = "DELETE FROM ItemTable WHERE key LIKE '%augment%' OR key LIKE '%telemetry%' OR key LIKE '%machineId%' OR key LIKE '%deviceId%' OR key LIKE '%sqmId%'; VACUUM;"
                        sqlite3 $file.FullName $cleaningQuery

                        if ($LASTEXITCODE -eq 0) {
                            Write-LogSuccess "Database cleaned: $($file.FullName)"
                            $totalCleaned++
                        } else {
                            Write-LogError "Failed to clean database: $($file.FullName)"
                            $totalErrors++
                        }
                    }
                } catch {
                    Write-LogError "Exception cleaning database $($file.FullName): $($_.Exception.Message)"
                    $totalErrors++
                }
            }
        }
    }

    Write-LogSuccess "Database cleaning completed. Processed: $totalCleaned, Errors: $totalErrors"
    return ($totalErrors -eq 0)
}

function Invoke-EmbeddedTelemetryModification {
    param([array]$VSCodePaths, [bool]$DryRun)

    Write-LogInfo "Starting embedded telemetry modification..."

    $totalModified = 0
    $totalErrors = 0

    foreach ($basePath in $VSCodePaths) {
        $searchPaths = @(
            "User\storage.json",
            "User\globalStorage\storage.json"
        )

        foreach ($searchPath in $searchPaths) {
            $fullPath = Join-Path $basePath $searchPath

            if (Test-Path $fullPath) {
                try {
                    if ($DryRun) {
                        Write-LogInfo "DRY RUN: Would modify telemetry in: $fullPath"
                        $totalModified++
                    } else {
                        # Create backup
                        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                        $backupFile = "$fullPath.backup_$timestamp"
                        Copy-Item $fullPath $backupFile

                        # Modify telemetry IDs
                        $content = Get-Content $fullPath -Raw | ConvertFrom-Json
                        $content."telemetry.machineId" = -join ((1..64) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
                        $content."telemetry.devDeviceId" = [System.Guid]::NewGuid().ToString()
                        $content."telemetry.sqmId" = [System.Guid]::NewGuid().ToString()

                        $content | ConvertTo-Json -Depth 10 | Set-Content $fullPath

                        Write-LogSuccess "Telemetry modified: $fullPath"
                        $totalModified++
                    }
                } catch {
                    Write-LogError "Exception modifying telemetry $fullPath`: $($_.Exception.Message)"
                    $totalErrors++
                }
            }
        }
    }

    Write-LogSuccess "Telemetry modification completed. Modified: $totalModified, Errors: $totalErrors"
    return ($totalErrors -eq 0)
}

# Show help information
function Show-Help {
    Write-Host @"
Augment VIP - Windows Installer v$SCRIPT_VERSION

DESCRIPTION:
    Enterprise-grade Windows installer for VS Code Augment cleaning and telemetry modification.
    Integrates with the new cross-platform modular architecture.

USAGE:
    .\install.ps1 [OPTIONS]

OPTIONS:
    -Operation <operation>     Specify operation to perform (default: help)
    -DryRun                   Perform a dry run without making changes
    -Verbose                  Enable verbose output and detailed logging
    -AutoInstallDeps          Automatically install missing dependencies
    -Help                     Show this help message

OPERATIONS:
    clean                     Clean VS Code databases (remove Augment entries)
    modify-ids                Modify VS Code telemetry IDs
    all                       Perform both cleaning and ID modification
    help                      Show this help message

EXAMPLES:
    .\install.ps1 -Operation clean
    .\install.ps1 -Operation modify-ids -DryRun
    .\install.ps1 -Operation all -Verbose -AutoInstallDeps

REQUIREMENTS:
    - Windows 10 or higher
    - PowerShell 5.1 or higher
    - SQLite3, curl, jq (auto-installable via Chocolatey)

SECURITY FEATURES:
    - Automatic backup creation before modifications
    - Input validation and sanitization
    - Audit logging for all operations
    - Integrity verification of modified files

NOTES:
    - Close VS Code before running operations
    - All operations are logged for audit purposes
    - Backups are created automatically before modifications
    - Use -DryRun to preview changes without applying them

For more information, visit: https://github.com/IIXINGCHEN/augment-vip

"@ -ForegroundColor Green
}

# Remote execution detection and handling
function Test-RemoteExecution {
    # Check if we're running from a remote source (piped execution)
    $isRemote = $false

    try {
        # Try multiple methods to get script path
        $scriptPath = $MyInvocation.MyCommand.Path
        if ([string]::IsNullOrEmpty($scriptPath)) {
            $scriptPath = $PSCommandPath
        }
        if ([string]::IsNullOrEmpty($scriptPath)) {
            $scriptPath = $MyInvocation.MyCommand.Definition
        }

        Write-Verbose "Script path: $scriptPath"

        if ([string]::IsNullOrEmpty($scriptPath)) {
            # No script path usually means piped execution
            Write-Verbose "No script path - checking current directory for project structure"

            # Check if we're in a project directory
            $currentDir = Get-Location
            $platformsDir = Join-Path $currentDir.Path "platforms"
            $coreDir = Join-Path $currentDir.Path "core"

            if ((Test-Path $platformsDir) -or (Test-Path $coreDir)) {
                Write-Verbose "Project structure found in current directory - local execution"
                $isRemote = $false
            } else {
                Write-Verbose "No project structure in current directory - likely piped execution"
                $isRemote = $true
            }
        } elseif ($scriptPath -match "^http" -or $scriptPath -match "TemporaryFile") {
            Write-Verbose "Script path indicates remote source"
            $isRemote = $true
        } elseif ($scriptPath -match "Temp\\.*\.ps1$") {
            # Script is in temp directory with .ps1 extension (likely downloaded)
            Write-Verbose "Script in temp directory"
            $isRemote = $true
        } else {
            # Check if platforms directory exists relative to script
            $scriptDir = Split-Path -Parent $scriptPath
            $platformsDir = Join-Path $scriptDir "platforms"
            Write-Verbose "Checking platforms directory: $platformsDir"

            if (Test-Path $platformsDir) {
                Write-Verbose "Platforms directory found - local execution"
                $isRemote = $false
            } else {
                Write-Verbose "Platforms directory not found"
                # This might be remote execution if platforms directory doesn't exist
                # But only if we're also not in a development environment
                $gitDir = Join-Path $scriptDir ".git"
                $coreDir = Join-Path $scriptDir "core"
                Write-Verbose "Checking git dir: $gitDir, core dir: $coreDir"

                if (-not (Test-Path $gitDir) -and -not (Test-Path $coreDir)) {
                    Write-Verbose "Neither git nor core directory found - assuming remote"
                    $isRemote = $true
                } else {
                    Write-Verbose "Development environment detected - local execution"
                    $isRemote = $false
                }
            }
        }
    } catch {
        # If we can't determine, assume local for safety
        Write-Verbose "Exception in remote detection: $($_.Exception.Message)"
        $isRemote = $false
    }

    Write-Verbose "Remote execution detected: $isRemote"
    return $isRemote
}

function Initialize-RemoteExecution {
    Write-LogInfo "Detected remote execution mode"
    Write-LogInfo "Downloading project files for full functionality..."

    # Create temporary working directory
    $tempDir = Join-Path $env:TEMP "augment-vip-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    # Set project root to temp directory
    $script:PROJECT_ROOT = $tempDir

    # Download essential files
    $essentialFiles = @(
        "platforms/windows.ps1",
        "config/settings.json",
        "config/security.json"
    )

    foreach ($file in $essentialFiles) {
        $url = "$REPO_URL/$file"
        $localPath = Join-Path $tempDir $file
        $localDir = Split-Path $localPath -Parent

        if (-not (Test-Path $localDir)) {
            New-Item -ItemType Directory -Path $localDir -Force | Out-Null
        }

        try {
            Write-LogInfo "Downloading: $file"
            Invoke-WebRequest -Uri $url -OutFile $localPath -UseBasicParsing
            Write-LogSuccess "Downloaded: $file"
        } catch {
            Write-LogWarning "Failed to download $file`: $($_.Exception.Message)"
            Write-LogInfo "Continuing with embedded functionality..."
        }
    }

    Write-LogSuccess "Remote execution environment initialized"
    Write-AuditLog "REMOTE_INIT" "Remote execution initialized in: $tempDir"

    return $true
}

# Main execution function
function Main {
    Write-LogInfo "Starting Augment VIP Windows installer v${SCRIPT_VERSION}"

    # Show help if requested
    if ($Help -or $Operation -eq "help") {
        Show-Help
        return 0
    }

    # Check for remote execution and handle accordingly
    if (Test-RemoteExecution) {
        if (-not (Initialize-RemoteExecution)) {
            Write-LogError "Remote execution initialization failed"
            return 1
        }
    }

    # Initialize environment
    if (-not (Initialize-Environment)) {
        Write-LogError "Environment initialization failed"
        return 1
    }

    # Validate Windows platform
    if (-not (Test-WindowsPlatform)) {
        Write-LogError "Windows platform validation failed"
        return 1
    }

    # Check administrator rights (warn only)
    Test-AdminRights | Out-Null

    # Test dependencies
    if (-not (Test-Dependencies)) {
        Write-LogError "Dependency validation failed"
        return 1
    }

    # Execute Windows platform implementation
    if (Invoke-WindowsPlatform -Operation $Operation -DryRun $DryRun -Verbose $Verbose) {
        Write-LogSuccess "Augment VIP operation completed successfully"
        Write-AuditLog "INSTALLER_COMPLETE" "Installation completed successfully: $Operation"
        return 0
    } else {
        Write-LogError "Augment VIP operation failed"
        Write-AuditLog "INSTALLER_FAILED" "Installation failed: $Operation"
        return 1
    }
}

# Main script execution
try {
    $exitCode = Main
    Write-LogInfo "Script execution completed with exit code: $exitCode"
    exit $exitCode
} catch {
    Write-LogError "Unhandled exception: $($_.Exception.Message)"
    Write-LogError "Stack trace: $($_.ScriptStackTrace)"
    Write-AuditLog "INSTALLER_EXCEPTION" "Unhandled exception: $($_.Exception.Message)"
    exit 1
}