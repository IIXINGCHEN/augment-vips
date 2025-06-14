# platforms/windows.ps1
#
# Enterprise-grade Windows implementation for Augment VIP
# Production-ready with comprehensive error handling and security
# Uses core modules for zero-redundancy architecture

param(
    [string]$Operation = "help",
    [switch]$DryRun = $false,
    [string]$ConfigFile = ""
)

# Set error handling and execution policy
$ErrorActionPreference = "Stop"
$VerbosePreference = if ($VerbosePreference -eq 'Continue') { "Continue" } else { "SilentlyContinue" }

# Load unified logging module
$script:UnifiedLoggerLoaded = $false
try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
    $unifiedLoggerPath = Join-Path $projectRoot "src\core\AugmentLogger.ps1"

    if (Test-Path $unifiedLoggerPath) {
        . $unifiedLoggerPath
        $script:UnifiedLoggerLoaded = $true
        Write-Host "✅ Unified logging module loaded successfully" -ForegroundColor Green
    } else {
        Write-Host "Unified logging module not found, using fallback" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Failed to load unified logging module: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Load unified logging bootstrap
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$loggingBootstrapPath = Join-Path $scriptDir "..\core\logging\logging_bootstrap.ps1"
if (Test-Path $loggingBootstrapPath) {
    . $loggingBootstrapPath
    Ensure-LoggingAvailable -ScriptName "WindowsPlatform"
}

# Script metadata
$SCRIPT_VERSION = "1.0.0"
$SCRIPT_NAME = "augment-vip-windows"

# Import required modules
try {
    # Check if running in correct directory structure (support both src and legacy structure)
    $coreDir = ""
    if (Test-Path "src\core") {
        $coreDir = "src\core"
        $script:USE_SRC_STRUCTURE = $true
    } elseif (Test-Path "core") {
        $coreDir = "core"
        $script:USE_SRC_STRUCTURE = $false
    } else {
        throw "Core modules directory not found. Expected 'src\core' or 'core' directory."
    }

    # Set up configuration file path
    if ([string]::IsNullOrEmpty($ConfigFile)) {
        if ($script:USE_SRC_STRUCTURE) {
            $ConfigFile = "src\config\config.json"
        } else {
            $ConfigFile = "config\config.json"
        }
    }

    # PowerShell doesn't directly source bash scripts, so we implement equivalent functions
    Write-LogInfo "Initializing Windows platform implementation..."
    Write-LogInfo "Using core directory: $coreDir"
    Write-LogInfo "Using config file: $ConfigFile"

} catch {
    Write-Error "Failed to initialize: $($_.Exception.Message)"
    exit 1
}

# Compatibility wrapper for audit logging to bridge old and new interfaces
function Write-AuditLog {
    param([string]$Action, [string]$Details)

    if ($script:UnifiedLoggerLoaded) {
        # Use unified logger's Write-AugmentLog function directly to avoid recursion
        Write-AugmentLog -Message "$Action - $Details" -Level "INFO" -Category "AUDIT"
    } else {
        # Fallback for when unified logger not available
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [AUDIT] $Action - $Details" -ForegroundColor Magenta
    }
}

# Initialize logging
function Initialize-Logging {
    $logDir = "logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # Initialize unified logging system if available
    if ($script:UnifiedLoggerLoaded) {
        try {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $logFileName = "${SCRIPT_NAME}_${timestamp}.log"

            if (Initialize-AugmentLogger -LogDirectory $logDir -LogFileName $logFileName) {
                Write-LogInfo "Unified logging system initialized for Windows platform"
                $script:LogFile = Join-Path $logDir $logFileName
                $script:AuditLogFile = Join-Path $logDir "${SCRIPT_NAME}_audit_${timestamp}.log"
            } else {
                # Fallback to simple logging
                $script:LogFile = "$logDir/${SCRIPT_NAME}_${timestamp}.log"
                $script:AuditLogFile = "$logDir/${SCRIPT_NAME}_audit_${timestamp}.log"
            }
        } catch {
            Write-Host "Exception initializing unified logger: $($_.Exception.Message)" -ForegroundColor Yellow
            # Fallback to simple logging
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $script:LogFile = "$logDir/${SCRIPT_NAME}_${timestamp}.log"
            $script:AuditLogFile = "$logDir/${SCRIPT_NAME}_audit_${timestamp}.log"
        }
    } else {
        # Fallback logging setup
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $script:LogFile = "$logDir/${SCRIPT_NAME}_${timestamp}.log"
        $script:AuditLogFile = "$logDir/${SCRIPT_NAME}_audit_${timestamp}.log"
    }

    Write-LogInfo "Windows platform implementation initialized"
    Write-LogInfo "Unified logger loaded: $script:UnifiedLoggerLoaded"
    Write-AuditLog "INIT" "Windows platform implementation started"
}

# Platform detection and validation
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

# Enhanced dependency management with better detection
function Test-Dependencies {
    Write-LogInfo "Checking system dependencies..."

    $requiredDeps = @("sqlite3", "curl", "jq")
    $chocoPackageMap = @{
        "sqlite3" = "SQLite"
        "curl" = "curl"
        "jq" = "jq"
    }
    $missingDeps = @()

    # First, ensure Chocolatey is in PATH if installed
    if (-not (Get-Command choco -ErrorAction SilentlyContinue) -and (Test-Path "C:\ProgramData\chocolatey\bin\choco.exe")) {
        $env:Path += ";C:\ProgramData\chocolatey\bin"
        Write-LogInfo "Chocolatey found and added to PATH"
    }

    foreach ($dep in $requiredDeps) {
        $found = $false

        # Method 1: Check if command is available in PATH
        if (Get-Command $dep -ErrorAction SilentlyContinue) {
            $found = $true
            Write-LogInfo "Dependency available: $dep"
        }

        # Method 2: Check Chocolatey installation specifically
        if (-not $found -and (Get-Command choco -ErrorAction SilentlyContinue)) {
            try {
                $chocoList = & choco list --local-only $chocoPackageMap[$dep] 2>$null
                if ($chocoList -and ($chocoList | Where-Object { $_ -like "*$($chocoPackageMap[$dep])*" -and $_ -notlike "*0 packages*" })) {
                    # Package is installed via Chocolatey, try to refresh PATH
                    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

                    # Check again after PATH refresh
                    if (Get-Command $dep -ErrorAction SilentlyContinue) {
                        $found = $true
                        Write-LogInfo "Dependency available: $dep (found via Chocolatey)"
                    } else {
                        Write-LogWarning "Dependency $dep installed via Chocolatey but not in PATH"
                    }
                }
            } catch {
                Write-LogWarning "Failed to check Chocolatey for $dep`: $($_.Exception.Message)"
            }
        }

        # Method 3: Check common installation paths
        if (-not $found) {
            $commonPaths = @()
            switch ($dep) {
                "sqlite3" {
                    $commonPaths = @(
                        "C:\sqlite\sqlite3.exe",
                        "C:\Program Files\SQLite\sqlite3.exe",
                        "C:\ProgramData\chocolatey\lib\SQLite\tools\sqlite3.exe",
                        "$env:USERPROFILE\sqlite3.exe"
                    )
                }
                "jq" {
                    $commonPaths = @(
                        "C:\jq\jq.exe",
                        "C:\Program Files\jq\jq.exe",
                        "C:\ProgramData\chocolatey\lib\jq\tools\jq.exe",
                        "$env:USERPROFILE\jq.exe"
                    )
                }
                "curl" {
                    $commonPaths = @(
                        "C:\Windows\System32\curl.exe",
                        "C:\Program Files\curl\bin\curl.exe",
                        "C:\ProgramData\chocolatey\lib\curl\tools\curl.exe"
                    )
                }
            }

            foreach ($path in $commonPaths) {
                if (Test-Path $path) {
                    $pathDir = Split-Path $path -Parent
                    if ($env:Path -notlike "*$pathDir*") {
                        $env:Path += ";$pathDir"
                    }
                    if (Get-Command $dep -ErrorAction SilentlyContinue) {
                        $found = $true
                        Write-LogInfo "Dependency available: $dep (found at $path)"
                        break
                    }
                }
            }
        }

        if (-not $found) {
            $missingDeps += $dep
        }
    }
    
    if ($missingDeps.Count -gt 0) {
        Write-LogWarning "Missing dependencies: $($missingDeps -join ', ')"
        
        # Check for Chocolatey, install if not available
        $chocoAvailable = $false
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            $chocoAvailable = $true
        } elseif (Test-Path "C:\ProgramData\chocolatey\bin\choco.exe") {
            $env:Path += ";C:\ProgramData\chocolatey\bin"
            $chocoAvailable = $true
            Write-LogInfo "Chocolatey found and added to PATH"
        }

        if ($chocoAvailable) {
            Write-LogInfo "Chocolatey available for dependency installation"
            return $missingDeps
        } else {
            Write-LogWarning "Chocolatey not found. Installing Chocolatey automatically..."
            if (Install-Chocolatey) {
                Write-LogSuccess "Chocolatey installed successfully"
                return $missingDeps
            } else {
                Write-LogError "Failed to install Chocolatey. Please install dependencies manually."
                return $false
            }
        }
    }
    
    Write-LogSuccess "All dependencies are available"
    Write-AuditLog "DEPENDENCIES_CHECK" "All dependencies validated"
    return $true
}

function Install-Dependencies {
    param([array]$MissingDeps)

    Write-LogInfo "Installing missing dependencies using Chocolatey..."

    # Package name mapping with CDN sources
    $chocoPackageMap = @{
        "sqlite3" = "SQLite"
        "curl" = "curl"
        "jq" = "jq"
    }

    # Direct download URLs for fallback (China CDN friendly)
    $directDownloads = @{
        "sqlite3" = @{
            "url" = "https://www.sqlite.org/2024/sqlite-tools-win-x64-3460000.zip"
            "exe" = "sqlite3.exe"
            "installDir" = "C:\sqlite"
        }
        "jq" = @{
            "url" = "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-windows-amd64.exe"
            "exe" = "jq.exe"
            "installDir" = "C:\jq"
        }
    }

    foreach ($dep in $MissingDeps) {
        $chocoPackage = if ($chocoPackageMap.ContainsKey($dep)) { $chocoPackageMap[$dep] } else { $dep }
        Write-LogInfo "Installing: $dep (package: $chocoPackage)"

        $installed = $false

        # Method 1: Try Chocolatey installation
        try {
            Write-LogInfo "Attempting Chocolatey installation for: $dep"
            $result = & choco install $chocoPackage -y --no-progress --limit-output
            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "Successfully installed: $dep"
                $installed = $true
            } else {
                Write-LogWarning "Chocolatey installation failed for: $dep (exit code: $LASTEXITCODE)"
            }
        } catch {
            Write-LogWarning "Chocolatey installation exception for $dep`: $($_.Exception.Message)"
        }

        # Method 2: Try direct download if Chocolatey failed
        if (-not $installed -and $directDownloads.ContainsKey($dep)) {
            Write-LogInfo "Attempting direct download for: $dep"
            try {
                $downloadInfo = $directDownloads[$dep]
                $tempFile = Join-Path $env:TEMP "$dep-download"
                $installDir = $downloadInfo.installDir

                # Create installation directory
                if (-not (Test-Path $installDir)) {
                    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
                }

                Write-LogInfo "Downloading $dep from: $($downloadInfo.url)"

                # Download with retry logic
                $maxRetries = 3
                $downloaded = $false
                for ($i = 1; $i -le $maxRetries; $i++) {
                    try {
                        (New-Object System.Net.WebClient).DownloadFile($downloadInfo.url, $tempFile)
                        $downloaded = $true
                        break
                    } catch {
                        Write-LogWarning "Download attempt $i failed: $($_.Exception.Message)"
                        if ($i -eq $maxRetries) {
                            throw "All download attempts failed"
                        }
                        Start-Sleep -Seconds 2
                    }
                }

                if ($downloaded) {
                    # Handle different file types
                    if ($downloadInfo.url.EndsWith('.zip')) {
                        # Extract ZIP file
                        Expand-Archive -Path $tempFile -DestinationPath $installDir -Force
                        # Find the executable
                        $exePath = Get-ChildItem -Path $installDir -Name $downloadInfo.exe -Recurse | Select-Object -First 1
                        if ($exePath) {
                            $fullExePath = Join-Path $installDir $exePath
                            # Move to root of install dir if needed
                            if ($exePath -ne $downloadInfo.exe) {
                                Move-Item $fullExePath (Join-Path $installDir $downloadInfo.exe) -Force
                            }
                        }
                    } else {
                        # Direct executable download
                        $exePath = Join-Path $installDir $downloadInfo.exe
                        Move-Item $tempFile $exePath -Force
                    }

                    # Add to PATH
                    if ($env:Path -notlike "*$installDir*") {
                        $env:Path += ";$installDir"
                        # Also update machine PATH for persistence
                        try {
                            $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
                            if ($machinePath -notlike "*$installDir*") {
                                [Environment]::SetEnvironmentVariable("Path", "$machinePath;$installDir", "Machine")
                            }
                        } catch {
                            Write-LogWarning "Failed to update machine PATH: $($_.Exception.Message)"
                        }
                    }

                    # Verify installation
                    if (Get-Command $dep -ErrorAction SilentlyContinue) {
                        Write-LogSuccess "Successfully installed: $dep (direct download)"
                        $installed = $true
                    } else {
                        Write-LogError "Direct download completed but $dep not found in PATH"
                    }
                }

                # Cleanup
                if (Test-Path $tempFile) {
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }

            } catch {
                Write-LogError "Direct download failed for $dep`: $($_.Exception.Message)"
            }
        }

        if (-not $installed) {
            Write-LogError "All installation methods failed for: $dep"
            return $false
        }
    }

    # Final verification
    Write-LogInfo "Verifying dependency installation..."
    $verificationFailed = $false
    foreach ($dep in $MissingDeps) {
        if (-not (Get-Command $dep -ErrorAction SilentlyContinue)) {
            Write-LogError "Verification failed for: $dep"
            $verificationFailed = $true
        }
    }

    if ($verificationFailed) {
        Write-LogError "Some dependencies failed verification"
        return $false
    }

    Write-LogSuccess "All dependencies installed successfully"
    Write-AuditLog "DEPENDENCIES_INSTALL" "Dependencies installed: $($MissingDeps -join ', ')"
    return $true
}

# Install Chocolatey package manager
function Install-Chocolatey {
    Write-LogInfo "Installing Chocolatey package manager..."

    try {
        # First check if Chocolatey is already installed but not in PATH
        if (Test-Path "C:\ProgramData\chocolatey\bin\choco.exe") {
            Write-LogInfo "Chocolatey already installed, adding to PATH"
            $env:Path += ";C:\ProgramData\chocolatey\bin"
            return $true
        }

        # Check if running as administrator
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-not $isAdmin) {
            Write-LogWarning "Administrator privileges recommended for Chocolatey installation"
            Write-LogInfo "Attempting installation with current privileges..."
        }

        # Set execution policy temporarily
        $originalPolicy = Get-ExecutionPolicy
        Set-ExecutionPolicy Bypass -Scope Process -Force

        # Download and install Chocolatey using China CDN
        Write-LogInfo "Downloading Chocolatey installer from China CDN..."
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

        # Try China CDN first, fallback to official
        $installUrls = @(
            'https://chocolatey.org/install.ps1',
            'https://community.chocolatey.org/install.ps1'
        )

        $installScript = $null
        foreach ($url in $installUrls) {
            try {
                Write-LogInfo "Trying download from: $url"
                $installScript = (New-Object System.Net.WebClient).DownloadString($url)
                if ($installScript) {
                    Write-LogInfo "Successfully downloaded from: $url"
                    break
                }
            } catch {
                Write-LogWarning "Failed to download from $url`: $($_.Exception.Message)"
            }
        }

        if (-not $installScript) {
            throw "Failed to download Chocolatey installer from all sources"
        }

        Write-LogInfo "Executing Chocolatey installer..."
        Invoke-Expression $installScript

        # Restore execution policy
        Set-ExecutionPolicy $originalPolicy -Scope Process -Force

        # Refresh environment variables multiple ways
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        # Wait for installation to complete
        Write-LogInfo "Waiting for Chocolatey installation to complete..."
        Start-Sleep -Seconds 10

        # Try multiple verification methods
        $chocoFound = $false

        # Method 1: Check command availability
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            $chocoFound = $true
        }

        # Method 2: Check standard installation path
        if (-not $chocoFound -and (Test-Path "C:\ProgramData\chocolatey\bin\choco.exe")) {
            $env:Path += ";C:\ProgramData\chocolatey\bin"
            $chocoFound = $true
        }

        # Method 3: Check user profile path
        if (-not $chocoFound -and (Test-Path "$env:USERPROFILE\chocolatey\bin\choco.exe")) {
            $env:Path += ";$env:USERPROFILE\chocolatey\bin"
            $chocoFound = $true
        }

        if ($chocoFound) {
            Write-LogSuccess "Chocolatey installed successfully"
            Write-AuditLog "CHOCOLATEY_INSTALL" "Chocolatey package manager installed"

            # Configure China mirror sources for faster downloads
            try {
                Write-LogInfo "Configuring China mirror sources..."
                & choco source add -n=china -s="https://chocolatey.org/api/v2/" --priority=1 2>$null
                & choco feature enable -n=usePackageRepositoryOptimizations 2>$null
                Write-LogInfo "China mirror sources configured"
            } catch {
                Write-LogWarning "Failed to configure mirror sources, using default"
            }

            # Get Chocolatey version
            try {
                $chocoVersion = & choco --version 2>$null
                Write-LogInfo "Chocolatey version: $chocoVersion"
            } catch {
                Write-LogInfo "Chocolatey installed but version check failed"
            }

            return $true
        } else {
            Write-LogError "Chocolatey installation verification failed"
            Write-LogError "Please install Chocolatey manually from: https://chocolatey.org/install"
            return $false
        }

    } catch {
        Write-LogError "Exception during Chocolatey installation: $($_.Exception.Message)"
        Write-LogError "Please install Chocolatey manually from: https://chocolatey.org/install"
        return $false
    }
}

# Enhanced VS Code and Cursor path discovery for real environment detection
function Get-VSCodePaths {
    Write-LogInfo "Discovering VS Code and Cursor installations (real environment detection)..."

    $paths = @{}

    # Get current user information for real environment detection
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $currentUserName = $env:USERNAME
    $currentUserProfile = $env:USERPROFILE
    $appData = $env:APPDATA
    $localAppData = $env:LOCALAPPDATA
    $programFiles = $env:ProgramFiles
    $programFilesX86 = ${env:ProgramFiles(x86)}

    Write-LogInfo "Real environment detection:"
    Write-LogInfo "  Current user: $currentUser"
    Write-LogInfo "  Username: $currentUserName"
    Write-LogInfo "  Profile: $currentUserProfile"
    Write-LogInfo "  AppData: $appData"
    Write-LogInfo "  LocalAppData: $localAppData"

    # 1. Registry-based discovery (most reliable)
    Write-LogInfo "Scanning registry for VS Code installations..."
    try {
        $registryPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )

        foreach ($regPath in $registryPaths) {
            try {
                $items = Get-ItemProperty $regPath -ErrorAction SilentlyContinue | Where-Object {
                    $_.DisplayName -like "*Visual Studio Code*" -or
                    $_.DisplayName -like "*VS Code*" -or
                    $_.DisplayName -like "*Cursor*" -or
                    $_.Publisher -like "*Microsoft Corporation*" -and $_.DisplayName -like "*Code*"
                }

                foreach ($item in $items) {
                    if ($item.InstallLocation -and (Test-Path $item.InstallLocation)) {
                        # Determine user data path based on application type
                        $userDataPath = if ($item.DisplayName -like "*Cursor*") {
                            Join-Path $appData "Cursor"
                        } else {
                            Join-Path $appData "Code"
                        }

                        if (Test-Path $userDataPath) {
                            $key = "Registry-$($item.DisplayName -replace '[^a-zA-Z0-9]', '')"
                            $paths[$key] = $userDataPath
                            Write-LogInfo "Found installation via registry: $($item.DisplayName) -> $userDataPath"
                        }
                    }
                }
            } catch {
                Write-LogWarning "Registry scan failed for $regPath`: $($_.Exception.Message)"
            }
        }
    } catch {
        Write-LogWarning "Registry discovery failed: $($_.Exception.Message)"
    }

    # 2. Standard user data paths (with deduplication) - including Cursor
    Write-LogInfo "Scanning standard user data paths..."
    $standardPaths = @(
        @{ Path = "$appData\Code"; Type = "Stable" },
        @{ Path = "$localAppData\Code"; Type = "Stable-Local" },
        @{ Path = "$appData\Code - Insiders"; Type = "Insiders" },
        @{ Path = "$localAppData\Code - Insiders"; Type = "Insiders-Local" },
        @{ Path = "$appData\Code - Exploration"; Type = "Exploration" },
        @{ Path = "$appData\VSCodium"; Type = "VSCodium" },
        @{ Path = "$localAppData\VSCodium"; Type = "VSCodium-Local" },
        @{ Path = "$appData\Cursor"; Type = "Cursor" },
        @{ Path = "$localAppData\Cursor"; Type = "Cursor-Local" }
    )

    foreach ($pathInfo in $standardPaths) {
        if (Test-Path $pathInfo.Path) {
            # Check if this path is already discovered (prevent duplicates)
            $normalizedPath = $pathInfo.Path.ToLower()
            $isDuplicate = $false

            foreach ($existingPath in $paths.Values) {
                if ($existingPath.ToLower() -eq $normalizedPath) {
                    $isDuplicate = $true
                    Write-LogInfo "Skipping duplicate path: $($pathInfo.Path) (already found as $existingPath)"
                    break
                }
            }

            if (-not $isDuplicate) {
                $paths[$pathInfo.Type] = $pathInfo.Path
                Write-LogInfo "Found installation: $($pathInfo.Type) -> $($pathInfo.Path)"
            }
        }
    }

    # 3. Program Files discovery
    Write-LogInfo "Scanning Program Files directories..."
    $programDirs = @($programFiles, $programFilesX86) | Where-Object { $_ -and (Test-Path $_) }
    foreach ($progDir in $programDirs) {
        $vscodeExes = Get-ChildItem -Path $progDir -Recurse -Name "Code.exe" -ErrorAction SilentlyContinue
        foreach ($exe in $vscodeExes) {
            $installPath = Split-Path (Join-Path $progDir $exe) -Parent
            # Map to user data directory
            $userDataPath = Join-Path $appData "Code"
            if (Test-Path $userDataPath) {
                $key = "ProgramFiles-$(Split-Path $installPath -Leaf)"
                $paths[$key] = $userDataPath
                Write-LogInfo "Found VS Code via Program Files: $installPath -> $userDataPath"
            }
        }
    }

    # 4. Portable installations discovery
    Write-LogInfo "Scanning for portable installations..."
    $portableSearchPaths = @(
        ".\data\user-data",
        ".\user-data",
        "$env:USERPROFILE\Desktop\VSCode-Portable\data\user-data",
        "$env:USERPROFILE\Documents\VSCode-Portable\data\user-data",
        "C:\PortableApps\VSCodePortable\data\user-data"
    )

    foreach ($path in $portableSearchPaths) {
        if (Test-Path $path) {
            $paths["Portable-$(Split-Path $path -Leaf)"] = $path
            Write-LogInfo "Found portable VS Code: $path"
        }
    }

    # 5. Environment variable based discovery
    if ($env:VSCODE_PORTABLE) {
        $portablePath = Join-Path $env:VSCODE_PORTABLE "user-data"
        if (Test-Path $portablePath) {
            $paths["EnvVar-Portable"] = $portablePath
            Write-LogInfo "Found VS Code via VSCODE_PORTABLE env var: $portablePath"
        }
    }

    Write-LogSuccess "VS Code and Cursor discovery completed. Found $($paths.Count) installations"
    Write-AuditLog "VSCODE_DISCOVERY" "VS Code and Cursor paths discovered: $($paths.Count) installations - $($paths.Keys -join ', ')"
    return $paths
}

# Enhanced database file discovery for production environment
function Get-DatabaseFiles {
    param([hashtable]$VSCodePaths)

    Write-LogInfo "Discovering VS Code database files (comprehensive scan)..."

    $dbFiles = @()

    # Optimized database file patterns (production-focused)
    $searchPaths = @(
        # Primary workspace storage databases
        "User\workspaceStorage\*\state.vscdb",

        # Global storage databases (limited scope)
        "User\globalStorage\*\state.vscdb",

        # Cache databases (essential only)
        "CachedData\*\*.vscdb"
    )

    foreach ($basePath in $VSCodePaths.Values) {
        Write-LogInfo "Scanning database files in: $basePath"

        foreach ($searchPath in $searchPaths) {
            try {
                $fullPath = Join-Path $basePath $searchPath
                $files = Get-ChildItem -Path $fullPath -ErrorAction SilentlyContinue

                foreach ($file in $files) {
                    if (Test-Path $file.FullName -PathType Leaf) {
                        # Verify it's actually a database file
                        if (Test-DatabaseFile $file.FullName) {
                            $dbFiles += $file.FullName
                            Write-LogInfo "Found database file: $($file.FullName)"
                        }
                    }
                }
            } catch {
                Write-LogWarning "Failed to scan path $fullPath`: $($_.Exception.Message)"
            }
        }
    }

    # Remove duplicates and sort
    $dbFiles = $dbFiles | Sort-Object | Get-Unique

    Write-LogSuccess "Discovered $($dbFiles.Count) database files"
    Write-AuditLog "DATABASE_DISCOVERY" "Database files discovered: $($dbFiles.Count) files"
    return $dbFiles
}

# Verify if a file is actually a database file
function Test-DatabaseFile {
    param([string]$FilePath)

    try {
        # Check file extension
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
        if ($extension -notin @('.vscdb', '.db', '.sqlite', '.sqlite3')) {
            return $false
        }

        # Check file size (empty files are not valid databases)
        $fileInfo = Get-Item $FilePath
        if ($fileInfo.Length -eq 0) {
            return $false
        }

        # Try to open with SQLite to verify it's a valid database
        try {
            $result = sqlite3 $FilePath ".tables" 2>$null
            return $LASTEXITCODE -eq 0
        } catch {
            return $false
        }
    } catch {
        return $false
    }
}

# Enhanced storage file discovery for production environment
function Get-StorageFiles {
    param([hashtable]$VSCodePaths)

    Write-LogInfo "Discovering VS Code storage files (comprehensive scan)..."

    $storageFiles = @()

    # Optimized storage file patterns (production-focused)
    $searchPaths = @(
        # Main storage files (highest priority)
        "User\storage.json",
        "User\globalStorage\storage.json",

        # Core configuration files only
        "User\settings.json",
        "User\machineId",

        # Workspace storage (limited scope)
        "User\workspaceStorage\*\workspace.json",

        # Extension global storage (limited to known patterns)
        "User\globalStorage\augment.vscode-augment\*\*.json",
        "User\globalStorage\*\telemetry*.json"
    )

    foreach ($basePath in $VSCodePaths.Values) {
        Write-LogInfo "Scanning storage files in: $basePath"

        foreach ($searchPath in $searchPaths) {
            try {
                $fullPath = Join-Path $basePath $searchPath
                $files = Get-ChildItem -Path $fullPath -ErrorAction SilentlyContinue

                foreach ($file in $files) {
                    if (Test-Path $file.FullName -PathType Leaf) {
                        # Verify it's a valid storage file
                        if (Test-StorageFile $file.FullName) {
                            $storageFiles += $file.FullName
                            Write-LogInfo "Found storage file: $($file.FullName)"
                        }
                    }
                }
            } catch {
                Write-LogWarning "Failed to scan path $fullPath`: $($_.Exception.Message)"
            }
        }
    }

    # Remove duplicates and sort
    $storageFiles = $storageFiles | Sort-Object | Get-Unique

    Write-LogSuccess "Discovered $($storageFiles.Count) storage files"
    Write-AuditLog "STORAGE_DISCOVERY" "Storage files discovered: $($storageFiles.Count) files"
    return $storageFiles
}

# Verify if a file is a valid storage file
function Test-StorageFile {
    param([string]$FilePath)

    try {
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
        $fileName = [System.IO.Path]::GetFileName($FilePath).ToLower()

        # Check if it's a JSON file or known storage file
        if ($extension -eq '.json' -or $fileName -in @('machineid', 'telemetry')) {
            # Check file size
            $fileInfo = Get-Item $FilePath
            if ($fileInfo.Length -eq 0) {
                return $false
            }

            # For JSON files, try to parse
            if ($extension -eq '.json') {
                try {
                    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
                    if ($content) {
                        $null = $content | ConvertFrom-Json
                        return $true
                    }
                } catch {
                    return $false
                }
            } else {
                return $true
            }
        }

        return $false
    } catch {
        return $false
    }
}

# Database cleaning operation
function Invoke-DatabaseCleaning {
    param([array]$DatabaseFiles, [bool]$DryRun = $false)
    
    Write-LogInfo "Starting database cleaning operation (DryRun: $DryRun)..."
    
    $totalCleaned = 0
    $totalErrors = 0
    
    foreach ($dbFile in $DatabaseFiles) {
        Write-LogInfo "Processing database: $dbFile"
        
        try {
            # Validate database file
            if (-not (Test-Path $dbFile)) {
                Write-LogWarning "Database file not found: $dbFile"
                continue
            }
            
            # Create backup
            if (-not $DryRun) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $backupFile = "$dbFile.backup_$timestamp"
                Copy-Item $dbFile $backupFile
                Write-LogInfo "Backup created: $backupFile"
            }
            
            # Production-grade comprehensive database cleaning
            $cleaningQuery = @"
DELETE FROM ItemTable WHERE
    -- Augment-related entries (case-insensitive)
    LOWER(key) LIKE '%augment%' OR
    key LIKE 'Augment.%' OR
    key LIKE 'augment.%' OR
    key LIKE '%augment-chat%' OR
    key LIKE '%augment-panel%' OR
    key LIKE '%augment-view%' OR
    key LIKE '%augment-extension%' OR
    key LIKE '%vscode-augment%' OR
    key LIKE '%augmentcode%' OR
    key LIKE '%augment.code%' OR
    key LIKE '%memento/webviewView.augment%' OR
    key LIKE '%workbench.view.extension.augment%' OR
    key LIKE '%workbench.panel.augment%' OR
    key LIKE '%extensionHost.augment%' OR

    -- Telemetry and tracking entries
    LOWER(key) LIKE '%telemetry%' OR
    key LIKE '%machineId%' OR
    key LIKE '%deviceId%' OR
    key LIKE '%sqmId%' OR
    key LIKE '%machine-id%' OR
    key LIKE '%device-id%' OR
    key LIKE '%sqm-id%' OR
    key LIKE '%sessionId%' OR
    key LIKE '%session-id%' OR
    key LIKE '%userId%' OR
    key LIKE '%user-id%' OR
    key LIKE '%installationId%' OR
    key LIKE '%installation-id%' OR

    -- Context7 and trial-related entries
    LOWER(key) LIKE '%context7%' OR
    LOWER(key) LIKE '%trial%' OR
    key LIKE '%trialPrompt%' OR
    key LIKE '%trial-prompt%' OR
    key LIKE '%licenseCheck%' OR
    key LIKE '%license-check%' OR

    -- Extension tracking and analytics
    key LIKE '%extensionTelemetry%' OR
    key LIKE '%extension-telemetry%' OR
    key LIKE '%analytics%' OR
    key LIKE '%tracking%' OR
    key LIKE '%metrics%' OR
    key LIKE '%usage%' OR
    key LIKE '%statistics%' OR

    -- AI and ML service identifiers
    key LIKE '%aiService%' OR
    key LIKE '%ai-service%' OR
    key LIKE '%mlService%' OR
    key LIKE '%ml-service%' OR
    key LIKE '%copilot%' OR
    key LIKE '%github.copilot%' OR

    -- Authentication and session tokens
    key LIKE '%authToken%' OR
    key LIKE '%auth-token%' OR
    key LIKE '%accessToken%' OR
    key LIKE '%access-token%' OR
    key LIKE '%refreshToken%' OR
    key LIKE '%refresh-token%';
"@
            
            if ($DryRun) {
                $countQuery = @"
SELECT COUNT(*) FROM ItemTable WHERE
    /* Enhanced Augment-related entries */
    key LIKE '%augment%' OR
    key LIKE '%Augment%' OR
    key LIKE '%AUGMENT%' OR
    key LIKE 'Augment.%' OR
    key LIKE 'augment.%' OR
    key LIKE '%augment-chat%' OR
    key LIKE '%augment-panel%' OR
    key LIKE '%vscode-augment%' OR
    key = 'Augment.vscode-augment' OR
    key LIKE '%actionSystemStates%' OR
    key LIKE '%workspaceMessageStates%' OR
    key LIKE '%sidecar.agent.%' OR
    key LIKE '%agentAutoModeApproved%' OR
    key LIKE '%lastEnabledExtensionVersion%' OR

    /* CRITICAL: Encrypted session data */
    key LIKE 'secret://%augment%' OR
    key LIKE 'secret://%vscode-augment%' OR
    key LIKE 'secret://%sessions%' OR
    key LIKE '%augment.sessions%' OR
    key LIKE '%extensionId%augment%' OR

    /* Enhanced telemetry entries */
    key LIKE '%telemetry%' OR
    key LIKE '%machineId%' OR
    key LIKE '%deviceId%' OR
    key LIKE '%sqmId%' OR
    key LIKE '%machine-id%' OR
    key LIKE '%device-id%' OR
    key LIKE '%sqm-id%' OR
    key = 'telemetry.firstSessionDate' OR
    key = 'telemetry.lastSessionDate' OR
    key = 'telemetry.currentSessionDate' OR
    key LIKE '%firstSessionDate%' OR
    key LIKE '%lastSessionDate%' OR
    key LIKE '%currentSessionDate%' OR
    key = 'storage.serviceMachineId' OR
    key LIKE '%serviceMachineId%' OR
    key = 'workbench.telemetryOptOutShown';
"@
                $count = sqlite3 $dbFile $countQuery
                Write-LogInfo "DRY RUN: Would remove $count entries from $dbFile"
                $totalCleaned += [int]$count
            } else {
                # Execute cleaning query
                $result = sqlite3 $dbFile $cleaningQuery

                # Get count of changes
                $changesQuery = "SELECT changes();"
                $changesCount = sqlite3 $dbFile $changesQuery

                # Run VACUUM to reclaim space
                sqlite3 $dbFile "VACUUM;"

                if ($LASTEXITCODE -eq 0) {
                    if ([int]$changesCount -gt 0) {
                        Write-LogSuccess "Database cleaned: $dbFile (removed $changesCount entries)"
                        $totalCleaned += [int]$changesCount
                    } else {
                        Write-LogInfo "Database processed: $dbFile (no matching entries found)"
                    }
                } else {
                    Write-LogError "Database cleaning failed: $dbFile"
                    $totalErrors++
                }
            }
            
        } catch {
            Write-LogError "Exception processing database $dbFile`: $($_.Exception.Message)"
            $totalErrors++
        }
    }
    
    Write-LogSuccess "Database cleaning completed. Processed: $totalCleaned, Errors: $totalErrors"
    Write-AuditLog "DATABASE_CLEAN" "Databases processed: $totalCleaned, Errors: $totalErrors, DryRun: $DryRun"
    
    return @{
        Processed = $totalCleaned
        Errors = $totalErrors
    }
}

# Production-grade telemetry ID modification
function Invoke-TelemetryModification {
    param([array]$StorageFiles, [bool]$DryRun = $false)

    Write-LogInfo "Starting comprehensive telemetry ID modification (DryRun: $DryRun)..."

    $totalModified = 0
    $totalErrors = 0
    $modificationLog = @()

    # Generate secure new IDs once for consistency
    $newIds = Generate-SecureIdentifiers

    foreach ($storageFile in $StorageFiles) {
        Write-LogInfo "Processing storage file: $storageFile"

        try {
            # Validate storage file
            if (-not (Test-Path $storageFile)) {
                Write-LogWarning "Storage file not found: $storageFile"
                continue
            }

            # Check if file is locked (VS Code running)
            if (Test-FileLocked $storageFile) {
                Write-LogWarning "File is locked (VS Code may be running): $storageFile"
                Write-LogWarning "Please close VS Code and try again"
                continue
            }

            # Create backup
            if (-not $DryRun) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $backupFile = "$storageFile.backup_$timestamp"
                Copy-Item $storageFile $backupFile -Force
                Write-LogInfo "Backup created: $backupFile"
            }

            if ($DryRun) {
                # Analyze what would be modified
                $analysisResult = Analyze-StorageFile $storageFile
                Write-LogInfo "DRY RUN: Would modify $($analysisResult.IdentifierCount) identifiers in $storageFile"
                Write-LogInfo "DRY RUN: Identifiers found: $($analysisResult.Identifiers -join ', ')"
                $totalModified++
            } else {
                # Perform actual modification
                $modificationResult = Modify-StorageFile $storageFile $newIds

                if ($modificationResult.Success) {
                    Write-LogSuccess "Storage file modified: $storageFile"
                    Write-LogInfo "Modified identifiers: $($modificationResult.ModifiedIdentifiers -join ', ')"
                    $modificationLog += @{
                        File = $storageFile
                        ModifiedIdentifiers = $modificationResult.ModifiedIdentifiers
                        Timestamp = Get-Date
                    }
                    $totalModified++
                } else {
                    Write-LogError "Failed to modify storage file: $storageFile - $($modificationResult.Error)"
                    $totalErrors++
                }
            }

        } catch {
            Write-LogError "Exception processing storage file $storageFile`: $($_.Exception.Message)"
            $totalErrors++
        }
    }

    # Log summary of all modifications
    if (-not $DryRun -and $modificationLog.Count -gt 0) {
        Write-LogSuccess "=== TELEMETRY MODIFICATION SUMMARY ==="
        Write-LogInfo "New Machine ID: $($newIds.MachineId)"
        Write-LogInfo "New Device ID: $($newIds.DeviceId)"
        Write-LogInfo "New SQM ID: $($newIds.SqmId)"
        Write-LogInfo "New Session ID: $($newIds.SessionId)"
        Write-LogInfo "New Installation ID: $($newIds.InstallationId)"
        Write-LogSuccess "=== END SUMMARY ==="
    }

    Write-LogSuccess "Telemetry modification completed. Modified: $totalModified, Errors: $totalErrors"
    Write-AuditLog "TELEMETRY_MODIFY" "Files modified: $totalModified, Errors: $totalErrors, DryRun: $DryRun"

    return @{
        Modified = $totalModified
        Errors = $totalErrors
        ModificationLog = $modificationLog
        NewIdentifiers = $newIds
    }
}

# Generate secure identifiers for production environment
function Generate-SecureIdentifiers {
    # Use cryptographically secure random number generator
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()

    # Generate machine ID (64 hex characters)
    $machineIdBytes = New-Object byte[] 32
    $rng.GetBytes($machineIdBytes)
    $machineId = [System.BitConverter]::ToString($machineIdBytes) -replace '-', '' | ForEach-Object { $_.ToLower() }

    # Generate other IDs using secure GUIDs
    $deviceId = [System.Guid]::NewGuid().ToString()
    $sqmId = [System.Guid]::NewGuid().ToString()
    $sessionId = [System.Guid]::NewGuid().ToString()
    $installationId = [System.Guid]::NewGuid().ToString()
    $userId = [System.Guid]::NewGuid().ToString()

    $rng.Dispose()

    return @{
        MachineId = $machineId
        DeviceId = $deviceId
        SqmId = $sqmId
        SessionId = $sessionId
        InstallationId = $installationId
        UserId = $userId
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")
    }
}

# Test if a file is locked by another process
function Test-FileLocked {
    param([string]$FilePath)

    try {
        $fileStream = [System.IO.File]::Open($FilePath, 'Open', 'ReadWrite', 'None')
        $fileStream.Close()
        return $false
    } catch {
        return $true
    }
}

# Analyze storage file to see what would be modified
function Analyze-StorageFile {
    param([string]$FilePath)

    try {
        $content = Get-Content $FilePath -Raw
        $identifiers = @()

        # Check for JSON files
        if ([System.IO.Path]::GetExtension($FilePath) -eq '.json') {
            $jsonContent = $content | ConvertFrom-Json

            # Check for various identifier patterns
            $identifierPatterns = @(
                'telemetry.machineId',
                'telemetry.devDeviceId',
                'telemetry.sqmId',
                'telemetry.sessionId',
                'telemetry.installationId',
                'telemetry.userId',
                'machineId',
                'deviceId',
                'sqmId',
                'sessionId',
                'installationId',
                'userId'
            )

            foreach ($pattern in $identifierPatterns) {
                if ($jsonContent.PSObject.Properties.Name -contains $pattern) {
                    $identifiers += $pattern
                }
            }
        } else {
            # For non-JSON files, check content patterns
            $patterns = @('machineId', 'deviceId', 'sqmId', 'sessionId', 'installationId', 'userId')
            foreach ($pattern in $patterns) {
                if ($content -match $pattern) {
                    $identifiers += $pattern
                }
            }
        }

        return @{
            IdentifierCount = $identifiers.Count
            Identifiers = $identifiers
        }
    } catch {
        return @{
            IdentifierCount = 0
            Identifiers = @()
            Error = $_.Exception.Message
        }
    }
}

# Modify storage file with new identifiers
function Modify-StorageFile {
    param([string]$FilePath, [hashtable]$NewIds)

    try {
        $modifiedIdentifiers = @()
        $extension = [System.IO.Path]::GetExtension($FilePath)

        if ($extension -eq '.json') {
            # Handle JSON files
            $content = Get-Content $FilePath -Raw | ConvertFrom-Json

            # Update all possible identifier fields
            $identifierMappings = @{
                'telemetry.machineId' = $NewIds.MachineId
                'telemetry.devDeviceId' = $NewIds.DeviceId
                'telemetry.sqmId' = $NewIds.SqmId
                'telemetry.sessionId' = $NewIds.SessionId
                'telemetry.installationId' = $NewIds.InstallationId
                'telemetry.userId' = $NewIds.UserId
                'machineId' = $NewIds.MachineId
                'deviceId' = $NewIds.DeviceId
                'sqmId' = $NewIds.SqmId
                'sessionId' = $NewIds.SessionId
                'installationId' = $NewIds.InstallationId
                'userId' = $NewIds.UserId
            }

            foreach ($key in $identifierMappings.Keys) {
                if ($content.PSObject.Properties.Name -contains $key) {
                    $content.$key = $identifierMappings[$key]
                    $modifiedIdentifiers += $key
                }
            }

            # Special handling for Augment-specific files
            $fileName = [System.IO.Path]::GetFileName($FilePath)
            if ($fileName -match "augment|context7") {
                # Clear Augment-specific authentication data
                $augmentKeys = @('authToken', 'accessToken', 'refreshToken', 'sessionToken', 'userToken', 'apiKey')
                foreach ($augmentKey in $augmentKeys) {
                    if ($content.PSObject.Properties.Name -contains $augmentKey) {
                        $content.$augmentKey = $null
                        $modifiedIdentifiers += $augmentKey
                        Write-LogInfo "Cleared Augment auth key: $augmentKey"
                    }
                }

                # Clear user identification data
                $userKeys = @('userId', 'username', 'email', 'accountId', 'profileId')
                foreach ($userKey in $userKeys) {
                    if ($content.PSObject.Properties.Name -contains $userKey) {
                        $content.$userKey = $null
                        $modifiedIdentifiers += $userKey
                        Write-LogInfo "Cleared user identification: $userKey"
                    }
                }
            }

            # Save modified JSON
            $content | ConvertTo-Json -Depth 10 -Compress | Set-Content $FilePath -Encoding UTF8

        } else {
            # Handle non-JSON files (plain text, etc.)
            $content = Get-Content $FilePath -Raw
            $originalContent = $content

            # Replace identifier patterns
            $replacements = @{
                'machineId' = $NewIds.MachineId
                'deviceId' = $NewIds.DeviceId
                'sqmId' = $NewIds.SqmId
                'sessionId' = $NewIds.SessionId
                'installationId' = $NewIds.InstallationId
                'userId' = $NewIds.UserId
            }

            foreach ($pattern in $replacements.Keys) {
                if ($content -match $pattern) {
                    $content = $content -replace $pattern, $replacements[$pattern]
                    $modifiedIdentifiers += $pattern
                }
            }

            # Only save if content changed
            if ($content -ne $originalContent) {
                Set-Content $FilePath $content -Encoding UTF8
            }
        }

        return @{
            Success = $true
            ModifiedIdentifiers = $modifiedIdentifiers
        }

    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            ModifiedIdentifiers = @()
        }
    }
}

# Account logout and cleanup function with infinite loop prevention
function Invoke-AccountLogoutCleanup {
    param([hashtable]$VSCodePaths, [bool]$DryRun)

    Write-LogInfo "Executing comprehensive account logout and cleanup..."

    $result = @{
        Success = $true
        AugmentTokensCleared = 0
        AugmentFilesDeleted = 0
        AuthenticationCleared = $false
        SessionsCleared = 0
        Errors = @()
        Details = ""
    }

    # Enhanced loop prevention and progress tracking
    $processedItems = @{}
    $maxIterations = 500  # Reduced for safety
    $currentIteration = 0
    $progressTracker = @{
        TotalItemsFound = 0
        ItemsProcessed = 0
        LastProgressTime = Get-Date
        StallDetectionThreshold = 30  # seconds
    }

    try {
        # Enhanced Augment file patterns for real environment cleanup
        $augmentPatterns = @(
            "User\globalStorage\augment.*",
            "User\globalStorage\*augment*",
            "User\globalStorage\augment.vscode-augment*",
            "User\globalStorage\*augment.vscode-augment*",
            "User\workspaceStorage\*\augment.*",
            "User\workspaceStorage\*\Augment.*",
            "User\workspaceStorage\*\*augment*",
            "User\workspaceStorage\*\*Augment*",
            "User\globalStorage\context7.*",
            "User\globalStorage\*context7*",
            "User\workspaceStorage\*\context7.*",
            "User\globalStorage\vscode-augment*",
            "User\globalStorage\*vscode-augment*"
        )

        Write-LogInfo "Using enhanced Augment detection patterns:"
        foreach ($pattern in $augmentPatterns) {
            Write-LogInfo "  Pattern: $pattern"
        }

        # First pass: Collect all items to process (prevents infinite loop)
        $allItemsToProcess = @()

        foreach ($basePath in $VSCodePaths.Values) {
            Write-LogInfo "Scanning Augment data in: $basePath"

            foreach ($pattern in $augmentPatterns) {
                $fullPath = Join-Path $basePath $pattern
                try {
                    $items = Get-ChildItem -Path $fullPath -Recurse -ErrorAction SilentlyContinue

                    foreach ($item in $items) {
                        $itemKey = $item.FullName.ToLower()
                        if (-not $processedItems.ContainsKey($itemKey)) {
                            $allItemsToProcess += $item
                            $processedItems[$itemKey] = $true
                        }
                    }
                } catch {
                    Write-LogWarning "Failed to scan pattern $pattern in $basePath`: $($_.Exception.Message)"
                }
            }
        }

        Write-LogInfo "Found $($allItemsToProcess.Count) unique items to process"

        # Second pass: Process collected items safely
        foreach ($item in $allItemsToProcess) {
            $currentIteration++

            # Safety check to prevent infinite loops
            if ($currentIteration -gt $maxIterations) {
                Write-LogWarning "Maximum iteration limit reached ($maxIterations). Stopping to prevent infinite loop."
                $result.Errors += "Maximum iteration limit reached"
                break
            }

            # Verify item still exists (may have been deleted as part of parent directory)
            if (-not (Test-Path $item.FullName)) {
                Write-LogInfo "Item already deleted: $($item.FullName)"
                continue
            }

            if (-not $DryRun) {
                try {
                    if ($item.PSIsContainer) {
                        Remove-Item $item.FullName -Force -Recurse -ErrorAction Stop
                        Write-LogInfo "Deleted Augment directory: $($item.FullName)"
                    } else {
                        Remove-Item $item.FullName -Force -ErrorAction Stop
                        Write-LogInfo "Deleted Augment file: $($item.FullName)"
                    }
                    $result.AugmentFilesDeleted++
                } catch {
                    Write-LogWarning "Failed to delete: $($item.FullName) - $($_.Exception.Message)"
                    $result.Errors += "Failed to delete: $($item.FullName)"
                }
            } else {
                Write-LogInfo "DRY RUN: Would delete $($item.FullName)"
                $result.AugmentFilesDeleted++
            }
        }

        # Clean up empty Augment directories after processing
        if (-not $DryRun) {
            Write-LogInfo "Cleaning up empty Augment directories..."
            foreach ($basePath in $VSCodePaths.Values) {
                $emptyDirPatterns = @(
                    "User\globalStorage\augment.*",
                    "User\globalStorage\*augment*",
                    "User\workspaceStorage\*\augment.*",
                    "User\workspaceStorage\*\Augment.*"
                )

                foreach ($pattern in $emptyDirPatterns) {
                    $fullPath = Join-Path $basePath $pattern
                    try {
                        $emptyDirs = Get-ChildItem -Path $fullPath -Directory -ErrorAction SilentlyContinue |
                                   Where-Object { (Get-ChildItem $_.FullName -ErrorAction SilentlyContinue).Count -eq 0 }

                        foreach ($emptyDir in $emptyDirs) {
                            try {
                                Remove-Item $emptyDir.FullName -Force -ErrorAction Stop
                                Write-LogInfo "Removed empty Augment directory: $($emptyDir.FullName)"
                                $result.AugmentFilesDeleted++
                            } catch {
                                Write-LogWarning "Failed to remove empty directory: $($emptyDir.FullName)"
                            }
                        }
                    } catch {
                        # Ignore errors when scanning for empty directories
                    }
                }
            }
        }

        # Clear authentication tokens specifically (separate process)
        Write-LogInfo "Processing authentication tokens..."
        $authTokensProcessed = 0

        foreach ($basePath in $VSCodePaths.Values) {
            $authPaths = @(
                "User\globalStorage\vscode.authentication",
                "User\globalStorage\ms-vscode.vscode-account"
            )

            foreach ($authPath in $authPaths) {
                $fullAuthPath = Join-Path $basePath $authPath
                if (Test-Path $fullAuthPath) {
                    try {
                        $authFiles = Get-ChildItem -Path $fullAuthPath -Recurse -ErrorAction SilentlyContinue |
                                   Where-Object { $_.Name -match "augment|context7" }

                        foreach ($authFile in $authFiles) {
                            $authTokensProcessed++

                            # Safety check for auth tokens too
                            if ($authTokensProcessed -gt 100) {
                                Write-LogWarning "Maximum auth token limit reached (100). Stopping to prevent issues."
                                break
                            }

                            if (-not $DryRun) {
                                try {
                                    Remove-Item $authFile.FullName -Force -ErrorAction Stop
                                    Write-LogInfo "Cleared authentication token: $($authFile.FullName)"
                                    $result.AugmentTokensCleared++
                                } catch {
                                    Write-LogWarning "Failed to clear auth token: $($authFile.FullName) - $($_.Exception.Message)"
                                    $result.Errors += "Failed to clear auth token: $($authFile.FullName)"
                                }
                            } else {
                                Write-LogInfo "DRY RUN: Would clear auth token $($authFile.FullName)"
                                $result.AugmentTokensCleared++
                            }
                        }
                    } catch {
                        Write-LogWarning "Failed to process auth path $fullAuthPath`: $($_.Exception.Message)"
                    }
                }
            }
        }

        $result.AuthenticationCleared = $true
        $result.Details = "Cleared $($result.AugmentTokensCleared) tokens and deleted $($result.AugmentFilesDeleted) files"
        Write-LogSuccess "Account logout cleanup completed: $($result.Details)"

    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        $result.Details = "Account logout cleanup failed: $($_.Exception.Message)"
        Write-LogError $result.Details
    }

    Write-LogInfo "Cleanup completed after $currentIteration iterations"
    return $result
}

# Main execution function with enhanced error handling and timeout
function Invoke-AugmentVIP {
    param([string]$Operation, [bool]$DryRun)

    Write-LogInfo "Starting Augment VIP operation: $Operation"

    # Set operation timeout (30 minutes for safety)
    $operationTimeout = 1800
    $operationStartTime = Get-Date

    try {
        # Platform validation
        Write-LogInfo "Validating Windows platform..."
        if (-not (Test-WindowsPlatform)) {
            Write-LogError "Platform validation failed"
            return 1
        }

        # Check operation timeout
        if (((Get-Date) - $operationStartTime).TotalSeconds -gt $operationTimeout) {
            Write-LogError "Operation timeout exceeded during platform validation"
            return 1
        }

        # Dependency check with automatic installation
        Write-LogInfo "Checking system dependencies..."
        $depCheck = Test-Dependencies
        if ($depCheck -is [array]) {
            # Missing dependencies found - auto install
            Write-LogInfo "Auto-installing missing dependencies: $($depCheck -join ', ')"
            if (-not (Install-Dependencies $depCheck)) {
                Write-LogError "Dependency installation failed"
                return 1
            }

            # Verify installation
            Write-LogInfo "Verifying dependency installation..."
            $verifyCheck = Test-Dependencies
            if ($verifyCheck -is [array]) {
                Write-LogError "Some dependencies still missing after installation: $($verifyCheck -join ', ')"
                return 1
            } elseif ($verifyCheck -eq $false) {
                Write-LogError "Dependency verification failed"
                return 1
            }
        } elseif ($depCheck -eq $false) {
            Write-LogError "Dependency check failed"
            return 1
        }

        # Check operation timeout
        if (((Get-Date) - $operationStartTime).TotalSeconds -gt $operationTimeout) {
            Write-LogError "Operation timeout exceeded during dependency check"
            return 1
        }

        # Process detection and handling (Windows platform specific)
        Write-LogInfo "Performing VS Code process detection..."
        try {
            # Try to load process manager if available
            $processManagerPath = Join-Path $PSScriptRoot "..\core\ProcessManager.ps1"
            if (Test-Path $processManagerPath) {
                . $processManagerPath

                # Load process configuration
                if (-not (Load-ProcessConfig)) {
                    Write-LogWarning "Process configuration loading failed, using default behavior"
                }

                # Perform process detection and handling
                $processResult = Invoke-ProcessDetectionAndHandling -AutoClose $false -Interactive $true
                if (-not $processResult) {
                    Write-LogError "Process detection was cancelled by user"
                    return 1
                }

                Write-LogSuccess "Process detection completed successfully"
            } else {
                Write-LogWarning "Process management module not found, skipping process detection"
            }
        } catch {
            Write-LogWarning "Process detection failed: $($_.Exception.Message)"
            Write-LogWarning "Continuing with execution (may encounter file lock issues)"
        }

        # Check operation timeout after process detection
        if (((Get-Date) - $operationStartTime).TotalSeconds -gt $operationTimeout) {
            Write-LogError "Operation timeout exceeded during process detection"
            return 1
        }

        # Discover VS Code installations
        Write-LogInfo "Discovering VS Code installations..."
        $vscodePaths = Get-VSCodePaths
        if ($vscodePaths.Count -eq 0) {
            Write-LogError "No VS Code installations found"
            return 1
        }

        # Check operation timeout
        if (((Get-Date) - $operationStartTime).TotalSeconds -gt $operationTimeout) {
            Write-LogError "Operation timeout exceeded during VS Code discovery"
            return 1
        }

    } catch {
        Write-LogError "Critical error during initialization: $($_.Exception.Message)"
        Write-LogError "Stack trace: $($_.ScriptStackTrace)"
        return 1
    }

    # Execute operation with timeout monitoring
    try {
        Write-LogInfo "Executing operation: $($Operation.ToLower())"

        switch ($Operation.ToLower()) {
            "clean" {
                Write-LogInfo "Starting database cleaning operation..."
                $dbFiles = Get-DatabaseFiles $vscodePaths
                if ($dbFiles.Count -eq 0) {
                    Write-LogWarning "No database files found"
                    return 0
                }

                # Check timeout before operation
                if (((Get-Date) - $operationStartTime).TotalSeconds -gt $operationTimeout) {
                    Write-LogError "Operation timeout exceeded before database cleaning"
                    return 1
                }

                $result = Invoke-DatabaseCleaning $dbFiles $DryRun
                Write-LogInfo "Database cleaning result: $($result | ConvertTo-Json)"
            }
            "modify-ids" {
                Write-LogInfo "Starting telemetry modification operation..."
                $storageFiles = Get-StorageFiles $vscodePaths
                if ($storageFiles.Count -eq 0) {
                    Write-LogWarning "No storage files found"
                    return 0
                }

                # Check timeout before operation
                if (((Get-Date) - $operationStartTime).TotalSeconds -gt $operationTimeout) {
                    Write-LogError "Operation timeout exceeded before telemetry modification"
                    return 1
                }

                $result = Invoke-TelemetryModification $storageFiles $DryRun
                Write-LogInfo "Telemetry modification result: $($result | ConvertTo-Json)"
            }
            "migrate" {
                Write-LogInfo "Starting complete migration workflow..."

                # Check timeout before operation
                if (((Get-Date) - $operationStartTime).TotalSeconds -gt $operationTimeout) {
                    Write-LogError "Operation timeout exceeded before migration workflow"
                    return 1
                }

                # Execute complete 6-step migration workflow
                $result = Invoke-CompleteMigrationWorkflow $vscodePaths $DryRun
                Write-LogInfo "Complete migration workflow result: $($result | ConvertTo-Json)"
            }
            "all" {
                Write-LogInfo "Starting comprehensive cleanup operation..."

                # Clean databases
                $dbFiles = Get-DatabaseFiles $vscodePaths
                if ($dbFiles.Count -gt 0) {
                    # Check timeout before database cleaning
                    if (((Get-Date) - $operationStartTime).TotalSeconds -gt $operationTimeout) {
                        Write-LogError "Operation timeout exceeded before database cleaning"
                        return 1
                    }

                    Write-LogInfo "Phase 1/3: Database cleaning..."
                    $cleanResult = Invoke-DatabaseCleaning $dbFiles $DryRun
                    Write-LogInfo "Database cleaning result: $($cleanResult | ConvertTo-Json)"
                }

                # Modify telemetry IDs
                $storageFiles = Get-StorageFiles $vscodePaths
                if ($storageFiles.Count -gt 0) {
                    # Check timeout before telemetry modification
                    if (((Get-Date) - $operationStartTime).TotalSeconds -gt $operationTimeout) {
                        Write-LogError "Operation timeout exceeded before telemetry modification"
                        return 1
                    }

                    Write-LogInfo "Phase 2/3: Telemetry modification..."
                    $modifyResult = Invoke-TelemetryModification $storageFiles $DryRun
                    Write-LogInfo "Telemetry modification result: $($modifyResult | ConvertTo-Json)"
                }

                # Execute account logout and cleanup
                # Check timeout before account cleanup
                if (((Get-Date) - $operationStartTime).TotalSeconds -gt $operationTimeout) {
                    Write-LogError "Operation timeout exceeded before account cleanup"
                    return 1
                }

                Write-LogInfo "Phase 3/3: Account logout and cleanup..."
                $accountResult = Invoke-AccountLogoutCleanup $vscodePaths $DryRun
                Write-LogInfo "Account logout result: $($accountResult | ConvertTo-Json)"
            }
            "help" {
                Show-Help
                return 0
            }
            default {
                Write-LogError "Unknown operation: $Operation"
                Show-Help
                return 1
            }
        }

        $operationDuration = ((Get-Date) - $operationStartTime).TotalSeconds
        Write-LogSuccess "Augment VIP operation completed successfully in $([math]::Round($operationDuration, 2)) seconds"
        Write-AuditLog "OPERATION_COMPLETE" "Operation: $Operation, DryRun: $DryRun, Duration: $operationDuration seconds"
        return 0

    } catch {
        Write-LogError "Critical error during operation execution: $($_.Exception.Message)"
        Write-LogError "Stack trace: $($_.ScriptStackTrace)"
        Write-AuditLog "OPERATION_ERROR" "Operation: $Operation, Error: $($_.Exception.Message)"
        return 1
    }
}

# Complete 6-step migration workflow
function Invoke-CompleteMigrationWorkflow {
    param(
        [array]$VSCodePaths,
        [bool]$DryRun
    )

    Write-LogInfo "Starting complete 6-step migration workflow"

    if ($DryRun) {
        Write-LogInfo "DRY RUN MODE: Preview only, no actual modifications"
    }

    # Call master migration controller
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
    if (-not $scriptDir) {
        $scriptDir = Get-Location
    }

    Write-LogInfo "Script directory: $scriptDir"
    $controllerPath = Join-Path $scriptDir "..\controllers\master_migration_controller.sh"
    $controllerPath = $controllerPath -replace '\\', '/'

    if (-not (Test-Path $controllerPath)) {
        Write-LogError "Master migration controller not found: $controllerPath"
        # Try alternative path
        $altPath = "src/controllers/master_migration_controller.sh"
        if (Test-Path $altPath) {
            $controllerPath = $altPath
            Write-LogInfo "Using alternative controller path: $controllerPath"
        } else {
            # Try absolute path from current directory
            $currentDir = Get-Location
            $absolutePath = Join-Path $currentDir "src\controllers\master_migration_controller.sh"
            if (Test-Path $absolutePath) {
                $controllerPath = $absolutePath -replace '\\', '/'
                Write-LogInfo "Using absolute controller path: $controllerPath"
            } else {
                return @{ Success = $false; Error = "Controller not found in any location" }
            }
        }
    }

    try {
        $bashArgs = @()
        if ($DryRun) {
            $bashArgs += "--dry-run"
        }

        Write-LogInfo "Executing master migration controller..."
        $result = & bash $controllerPath @bashArgs
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-LogSuccess "Complete migration workflow completed successfully"
            return @{ Success = $true; ExitCode = $exitCode }
        } else {
            Write-LogError "Complete migration workflow failed with exit code: $exitCode"
            return @{ Success = $false; ExitCode = $exitCode }
        }

    } catch {
        Write-LogError "Exception during migration workflow: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# Help function
function Show-Help {
    Write-Host @"
Augment VIP - Windows Platform Implementation v$SCRIPT_VERSION

USAGE:
    .\platforms\windows.ps1 -Operation <operation> [options]

OPERATIONS:
    clean       Clean VS Code databases (remove Augment entries)
    modify-ids  Modify VS Code telemetry IDs
    migrate     Complete 6-step migration workflow
    all         Perform both cleaning and ID modification
    help        Show this help message

OPTIONS:
    -DryRun     Perform a dry run without making changes
    -Verbose    Enable verbose output
    -ConfigFile Specify configuration file (default: config/settings.json)

EXAMPLES:
    .\platforms\windows.ps1 -Operation clean
    .\platforms\windows.ps1 -Operation modify-ids -DryRun
    .\platforms\windows.ps1 -Operation all -Verbose

REQUIREMENTS:
    - Windows 10 or higher
    - PowerShell 5.1 or higher
    - SQLite3, curl, jq (auto-installable via Chocolatey)

"@ -ForegroundColor Green
}

# Main execution
try {
    Initialize-Logging
    
    $exitCode = Invoke-AugmentVIP -Operation $Operation -DryRun $DryRun
    
    Write-LogInfo "Script execution completed with exit code: $exitCode"
    exit $exitCode
    
} catch {
    Write-LogError "Unhandled exception: $($_.Exception.Message)"
    Write-LogError "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
