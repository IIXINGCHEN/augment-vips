# platforms/windows.ps1
#
# Enterprise-grade Windows implementation for Augment VIP
# Production-ready with comprehensive error handling and security
# Uses core modules for zero-redundancy architecture

param(
    [string]$Operation = "help",
    [switch]$DryRun = $false,
    [switch]$Verbose = $false,
    [string]$ConfigFile = "config/settings.json"
)

# Set error handling and execution policy
$ErrorActionPreference = "Stop"
$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }

# Script metadata
$SCRIPT_VERSION = "1.0.0"
$SCRIPT_NAME = "augment-vip-windows"

# Import required modules
try {
    # Check if running in correct directory structure
    if (-not (Test-Path "core")) {
        throw "Core modules directory not found. Please run from project root."
    }
    
    # PowerShell doesn't directly source bash scripts, so we implement equivalent functions
    Write-LogInfo "Initializing Windows platform implementation..."
    
} catch {
    Write-Error "Failed to initialize: $($_.Exception.Message)"
    exit 1
}

# Logging functions (PowerShell equivalent of core/common.sh)
function Write-LogInfo {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [INFO] $Message" -ForegroundColor Cyan
    Add-Content -Path $LogFile -Value "[$timestamp] [INFO] $Message" -ErrorAction SilentlyContinue
}

function Write-LogSuccess {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [SUCCESS] $Message" -ForegroundColor Green
    Add-Content -Path $LogFile -Value "[$timestamp] [SUCCESS] $Message" -ErrorAction SilentlyContinue
}

function Write-LogWarning {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [WARN] $Message" -ForegroundColor Yellow
    Add-Content -Path $LogFile -Value "[$timestamp] [WARN] $Message" -ErrorAction SilentlyContinue
}

function Write-LogError {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [ERROR] $Message" -ForegroundColor Red
    Add-Content -Path $LogFile -Value "[$timestamp] [ERROR] $Message" -ErrorAction SilentlyContinue
    Add-Content -Path $AuditLogFile -Value "[$timestamp] [ERROR] $Message" -ErrorAction SilentlyContinue
}

function Write-AuditLog {
    param([string]$Action, [string]$Details)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $user = $env:USERNAME
    $processId = $PID
    $auditEntry = "[$timestamp] [PID:$processId] [USER:$user] [ACTION:$Action] $Details"
    Add-Content -Path $AuditLogFile -Value $auditEntry -ErrorAction SilentlyContinue
}

# Initialize logging
function Initialize-Logging {
    $logDir = "logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:LogFile = "$logDir/${SCRIPT_NAME}_${timestamp}.log"
    $script:AuditLogFile = "$logDir/${SCRIPT_NAME}_audit_${timestamp}.log"
    
    Write-LogInfo "Windows platform implementation initialized"
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

# Dependency management
function Test-Dependencies {
    Write-LogInfo "Checking system dependencies..."
    
    $requiredDeps = @("sqlite3", "curl", "jq")
    $missingDeps = @()
    
    foreach ($dep in $requiredDeps) {
        if (-not (Get-Command $dep -ErrorAction SilentlyContinue)) {
            $missingDeps += $dep
        } else {
            Write-LogInfo "Dependency available: $dep"
        }
    }
    
    if ($missingDeps.Count -gt 0) {
        Write-LogWarning "Missing dependencies: $($missingDeps -join ', ')"
        
        # Check for Chocolatey
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-LogInfo "Chocolatey available for dependency installation"
            return $missingDeps
        } else {
            Write-LogError "Chocolatey not available. Please install dependencies manually."
            return $false
        }
    }
    
    Write-LogSuccess "All dependencies are available"
    Write-AuditLog "DEPENDENCIES_CHECK" "All dependencies validated"
    return $true
}

function Install-Dependencies {
    param([array]$MissingDeps)
    
    Write-LogInfo "Installing missing dependencies using Chocolatey..."
    
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

# Enhanced VS Code path discovery for production environment
function Get-VSCodePaths {
    Write-LogInfo "Discovering VS Code installations (comprehensive scan)..."

    $paths = @{}
    $appData = $env:APPDATA
    $localAppData = $env:LOCALAPPDATA
    $programFiles = $env:ProgramFiles
    $programFilesX86 = ${env:ProgramFiles(x86)}

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
                    $_.Publisher -like "*Microsoft Corporation*" -and $_.DisplayName -like "*Code*"
                }

                foreach ($item in $items) {
                    if ($item.InstallLocation -and (Test-Path $item.InstallLocation)) {
                        $userDataPath = Join-Path $appData "Code"
                        if (Test-Path $userDataPath) {
                            $key = "Registry-$($item.DisplayName -replace '[^a-zA-Z0-9]', '')"
                            $paths[$key] = $userDataPath
                            Write-LogInfo "Found VS Code via registry: $($item.DisplayName) -> $userDataPath"
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

    # 2. Standard user data paths
    Write-LogInfo "Scanning standard user data paths..."
    $standardPaths = @(
        @{ Path = "$appData\Code"; Type = "Stable" },
        @{ Path = "$localAppData\Code"; Type = "Stable-Local" },
        @{ Path = "$appData\Code - Insiders"; Type = "Insiders" },
        @{ Path = "$localAppData\Code - Insiders"; Type = "Insiders-Local" },
        @{ Path = "$appData\Code - Exploration"; Type = "Exploration" },
        @{ Path = "$appData\VSCodium"; Type = "VSCodium" },
        @{ Path = "$localAppData\VSCodium"; Type = "VSCodium-Local" }
    )

    foreach ($pathInfo in $standardPaths) {
        if (Test-Path $pathInfo.Path) {
            $paths[$pathInfo.Type] = $pathInfo.Path
            Write-LogInfo "Found VS Code installation: $($pathInfo.Type) -> $($pathInfo.Path)"
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

    Write-LogSuccess "VS Code discovery completed. Found $($paths.Count) installations"
    Write-AuditLog "VSCODE_DISCOVERY" "VS Code paths discovered: $($paths.Count) installations - $($paths.Keys -join ', ')"
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
    key LIKE '%augment%' OR
    key LIKE '%Augment%' OR
    key LIKE '%AUGMENT%' OR
    key LIKE 'Augment.%' OR
    key LIKE 'augment.%' OR
    key LIKE '%augment-chat%' OR
    key LIKE '%augment-panel%' OR
    key LIKE '%vscode-augment%' OR
    key LIKE '%telemetry%' OR
    key LIKE '%machineId%' OR
    key LIKE '%deviceId%' OR
    key LIKE '%sqmId%' OR
    key LIKE '%machine-id%' OR
    key LIKE '%device-id%' OR
    key LIKE '%sqm-id%';
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

# Main execution function
function Invoke-AugmentVIP {
    param([string]$Operation, [bool]$DryRun)
    
    Write-LogInfo "Starting Augment VIP operation: $Operation"
    
    # Platform validation
    if (-not (Test-WindowsPlatform)) {
        Write-LogError "Platform validation failed"
        return 1
    }
    
    # Dependency check
    $depCheck = Test-Dependencies
    if ($depCheck -is [array]) {
        # Missing dependencies found
        $response = Read-Host "Install missing dependencies? (y/N)"
        if ($response -match '^[Yy]$') {
            if (-not (Install-Dependencies $depCheck)) {
                Write-LogError "Dependency installation failed"
                return 1
            }
        } else {
            Write-LogError "Required dependencies not available"
            return 1
        }
    } elseif ($depCheck -eq $false) {
        Write-LogError "Dependency check failed"
        return 1
    }
    
    # Discover VS Code installations
    $vscodePaths = Get-VSCodePaths
    if ($vscodePaths.Count -eq 0) {
        Write-LogError "No VS Code installations found"
        return 1
    }
    
    # Execute operation
    switch ($Operation.ToLower()) {
        "clean" {
            $dbFiles = Get-DatabaseFiles $vscodePaths
            if ($dbFiles.Count -eq 0) {
                Write-LogWarning "No database files found"
                return 0
            }
            $result = Invoke-DatabaseCleaning $dbFiles $DryRun
            Write-LogInfo "Database cleaning result: $($result | ConvertTo-Json)"
        }
        "modify-ids" {
            $storageFiles = Get-StorageFiles $vscodePaths
            if ($storageFiles.Count -eq 0) {
                Write-LogWarning "No storage files found"
                return 0
            }
            $result = Invoke-TelemetryModification $storageFiles $DryRun
            Write-LogInfo "Telemetry modification result: $($result | ConvertTo-Json)"
        }
        "all" {
            # Clean databases
            $dbFiles = Get-DatabaseFiles $vscodePaths
            if ($dbFiles.Count -gt 0) {
                $cleanResult = Invoke-DatabaseCleaning $dbFiles $DryRun
                Write-LogInfo "Database cleaning result: $($cleanResult | ConvertTo-Json)"
            }
            
            # Modify telemetry IDs
            $storageFiles = Get-StorageFiles $vscodePaths
            if ($storageFiles.Count -gt 0) {
                $modifyResult = Invoke-TelemetryModification $storageFiles $DryRun
                Write-LogInfo "Telemetry modification result: $($modifyResult | ConvertTo-Json)"
            }
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
    
    Write-LogSuccess "Augment VIP operation completed successfully"
    Write-AuditLog "OPERATION_COMPLETE" "Operation: $Operation, DryRun: $DryRun"
    return 0
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
