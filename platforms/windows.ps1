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
    Write-Verbose "Initializing Windows platform implementation..."
    
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

# VS Code path discovery
function Get-VSCodePaths {
    Write-LogInfo "Discovering VS Code installations..."
    
    $paths = @{}
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
            $pathType = Split-Path $path -Leaf
            $paths[$pathType] = $path
            Write-LogInfo "Found VS Code installation: $pathType -> $path"
        }
    }
    
    # Check for portable installations
    $portablePaths = @(".\data\user-data", ".\user-data")
    foreach ($path in $portablePaths) {
        if (Test-Path $path) {
            $paths["portable"] = $path
            Write-LogInfo "Found portable VS Code: $path"
        }
    }
    
    Write-AuditLog "VSCODE_DISCOVERY" "VS Code paths discovered: $($paths.Count) installations"
    return $paths
}

# Database file discovery
function Get-DatabaseFiles {
    param([hashtable]$VSCodePaths)
    
    Write-LogInfo "Discovering VS Code database files..."
    
    $dbFiles = @()
    $searchPaths = @(
        "User\workspaceStorage\*\state.vscdb",
        "User\globalStorage\*\state.vscdb",
        "Cache\*\*.vscdb",
        "CachedData\*\*.vscdb",
        "logs\*\*.vscdb"
    )
    
    foreach ($basePath in $VSCodePaths.Values) {
        foreach ($searchPath in $searchPaths) {
            $fullPath = Join-Path $basePath $searchPath
            $files = Get-ChildItem -Path $fullPath -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                if (Test-Path $file.FullName -PathType Leaf) {
                    $dbFiles += $file.FullName
                    Write-LogInfo "Found database file: $($file.FullName)"
                }
            }
        }
    }
    
    Write-LogSuccess "Discovered $($dbFiles.Count) database files"
    Write-AuditLog "DATABASE_DISCOVERY" "Database files discovered: $($dbFiles.Count) files"
    return $dbFiles
}

# Storage file discovery
function Get-StorageFiles {
    param([hashtable]$VSCodePaths)
    
    Write-LogInfo "Discovering VS Code storage files..."
    
    $storageFiles = @()
    $searchPaths = @(
        "User\storage.json",
        "User\globalStorage\storage.json",
        "User\workspaceStorage\*\storage.json"
    )
    
    foreach ($basePath in $VSCodePaths.Values) {
        foreach ($searchPath in $searchPaths) {
            $fullPath = Join-Path $basePath $searchPath
            $files = Get-ChildItem -Path $fullPath -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                if (Test-Path $file.FullName -PathType Leaf) {
                    $storageFiles += $file.FullName
                    Write-LogInfo "Found storage file: $($file.FullName)"
                }
            }
        }
    }
    
    Write-LogSuccess "Discovered $($storageFiles.Count) storage files"
    Write-AuditLog "STORAGE_DISCOVERY" "Storage files discovered: $($storageFiles.Count) files"
    return $storageFiles
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
            
            # Clean database
            $cleaningQuery = @"
DELETE FROM ItemTable WHERE key LIKE '%augment%';
DELETE FROM ItemTable WHERE key LIKE '%telemetry%';
DELETE FROM ItemTable WHERE key LIKE '%machineId%';
DELETE FROM ItemTable WHERE key LIKE '%deviceId%';
DELETE FROM ItemTable WHERE key LIKE '%sqmId%';
VACUUM;
"@
            
            if ($DryRun) {
                $countQuery = "SELECT COUNT(*) FROM ItemTable WHERE key LIKE '%augment%' OR key LIKE '%telemetry%' OR key LIKE '%machineId%' OR key LIKE '%deviceId%' OR key LIKE '%sqmId%';"
                $count = sqlite3 $dbFile $countQuery
                Write-LogInfo "DRY RUN: Would remove $count entries from $dbFile"
                $totalCleaned += [int]$count
            } else {
                sqlite3 $dbFile $cleaningQuery
                if ($LASTEXITCODE -eq 0) {
                    Write-LogSuccess "Database cleaned successfully: $dbFile"
                    $totalCleaned++
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

# Telemetry ID modification
function Invoke-TelemetryModification {
    param([array]$StorageFiles, [bool]$DryRun = $false)
    
    Write-LogInfo "Starting telemetry ID modification (DryRun: $DryRun)..."
    
    $totalModified = 0
    $totalErrors = 0
    
    foreach ($storageFile in $StorageFiles) {
        Write-LogInfo "Processing storage file: $storageFile"
        
        try {
            # Validate storage file
            if (-not (Test-Path $storageFile)) {
                Write-LogWarning "Storage file not found: $storageFile"
                continue
            }
            
            # Create backup
            if (-not $DryRun) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $backupFile = "$storageFile.backup_$timestamp"
                Copy-Item $storageFile $backupFile
                Write-LogInfo "Backup created: $backupFile"
            }
            
            if ($DryRun) {
                Write-LogInfo "DRY RUN: Would modify telemetry IDs in $storageFile"
                $totalModified++
            } else {
                # Read and modify JSON
                $content = Get-Content $storageFile -Raw | ConvertFrom-Json
                
                # Generate new IDs
                $newMachineId = -join ((1..64) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
                $newDeviceId = [System.Guid]::NewGuid().ToString()
                $newSqmId = [System.Guid]::NewGuid().ToString()
                
                # Update telemetry IDs
                $content."telemetry.machineId" = $newMachineId
                $content."telemetry.devDeviceId" = $newDeviceId
                $content."telemetry.sqmId" = $newSqmId
                
                # Save modified content
                $content | ConvertTo-Json -Depth 10 | Set-Content $storageFile
                
                Write-LogSuccess "Telemetry IDs modified: $storageFile"
                Write-LogInfo "New machineId: $newMachineId"
                Write-LogInfo "New devDeviceId: $newDeviceId"
                Write-LogInfo "New sqmId: $newSqmId"
                
                $totalModified++
            }
            
        } catch {
            Write-LogError "Exception processing storage file $storageFile`: $($_.Exception.Message)"
            $totalErrors++
        }
    }
    
    Write-LogSuccess "Telemetry modification completed. Modified: $totalModified, Errors: $totalErrors"
    Write-AuditLog "TELEMETRY_MODIFY" "Files modified: $totalModified, Errors: $totalErrors, DryRun: $DryRun"
    
    return @{
        Modified = $totalModified
        Errors = $totalErrors
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
