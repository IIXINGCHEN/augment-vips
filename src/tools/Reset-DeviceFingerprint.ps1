# Reset-DeviceFingerprint.ps1
# Device Fingerprint Complete Reset Tool
# Completely resets all device fingerprint data to break trial account tracking
# Version: 3.0.0 - Standardized and optimized

[CmdletBinding()]
param(
    [switch]$DryRun = $false,
    [switch]$Verbose = $false,
    [switch]$Force = $false
)

# Import dependencies
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreModulesPath = Split-Path $scriptPath -Parent | Join-Path -ChildPath "core"
$loggerPath = Join-Path $coreModulesPath "AugmentLogger.ps1"

if (Test-Path $loggerPath) {
    . $loggerPath
    Initialize-AugmentLogger -LogDirectory "logs" -LogFileName "device_fingerprint_reset.log" -LogLevel "INFO"
} else {
    # Fallback logging if main logger not available
    function Write-LogInfo { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor White }
    function Write-LogSuccess { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
    function Write-LogWarning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    function Write-LogError { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
    function Write-LogDebug { param([string]$Message) if ($Verbose) { Write-Host "[DEBUG] $Message" -ForegroundColor Gray } }
}

# Set error handling
$ErrorActionPreference = "Stop"

#region Fingerprint Generation

function New-DeviceFingerprint {
    <#
    .SYNOPSIS
        Generates a new device fingerprint
    .DESCRIPTION
        Creates new machine ID, device ID, SQM ID, and session timestamps
    .EXAMPLE
        New-DeviceFingerprint
    #>
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Generating new device fingerprint..."
    
    # Generate new machine ID (64-character hex string)
    $newMachineId = -join ((1..64) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
    
    # Generate new device ID (GUID format)
    $newDeviceId = [System.Guid]::NewGuid().ToString()
    
    # Generate new SQM ID (GUID format with braces)
    $newSqmId = "{$([System.Guid]::NewGuid().ToString().ToUpper())}"
    
    # Generate new session timestamps
    $currentTime = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $firstSessionTime = $currentTime - (Get-Random -Minimum 86400000 -Maximum 2592000000) # 1-30 days ago
    
    $fingerprint = @{
        MachineId = $newMachineId
        DeviceId = $newDeviceId
        SqmId = $newSqmId
        FirstSessionDate = $firstSessionTime
        LastSessionDate = $currentTime
        CurrentSessionDate = $currentTime
    }
    
    Write-LogSuccess "Generated new device fingerprint:"
    Write-LogInfo "  Machine ID: $($fingerprint.MachineId)"
    Write-LogInfo "  Device ID: $($fingerprint.DeviceId)"
    Write-LogInfo "  SQM ID: $($fingerprint.SqmId)"
    
    return $fingerprint
}

#endregion

#region Storage File Updates

function Update-StorageJsonFingerprint {
    <#
    .SYNOPSIS
        Updates device fingerprint in storage.json files
    .DESCRIPTION
        Modifies telemetry and session data in VS Code storage files
    .PARAMETER StoragePath
        Path to the storage.json file
    .PARAMETER Fingerprint
        New fingerprint data to apply
    .EXAMPLE
        Update-StorageJsonFingerprint -StoragePath "C:\path\to\storage.json" -Fingerprint $fingerprint
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StoragePath,
        [Parameter(Mandatory = $true)]
        [hashtable]$Fingerprint
    )
    
    if (-not (Test-Path $StoragePath)) {
        Write-LogWarning "Storage file not found: $StoragePath"
        return $false
    }
    
    try {
        Write-LogInfo "Updating fingerprint in: $StoragePath"
        
        # Read and parse JSON
        $content = Get-Content $StoragePath -Raw | ConvertFrom-Json
        
        # Update telemetry fields
        $content."telemetry.machineId" = $Fingerprint.MachineId
        $content."telemetry.devDeviceId" = $Fingerprint.DeviceId
        $content."telemetry.sqmId" = $Fingerprint.SqmId
        
        # Update session timestamps
        $content."telemetry.firstSessionDate" = $Fingerprint.FirstSessionDate
        $content."telemetry.lastSessionDate" = $Fingerprint.LastSessionDate
        $content."telemetry.currentSessionDate" = $Fingerprint.CurrentSessionDate
        
        # Remove any existing Augment-related workspace associations
        if ($content.PSObject.Properties.Name -contains "profileAssociations") {
            if ($content.profileAssociations.PSObject.Properties.Name -contains "workspaces") {
                $workspaces = $content.profileAssociations.workspaces
                $workspaceKeys = $workspaces.PSObject.Properties.Name | Where-Object { $_ -match "augment" }
                foreach ($key in $workspaceKeys) {
                    $workspaces.PSObject.Properties.Remove($key)
                }
            }
        }
        
        # Remove backup workspace references to current project
        if ($content.PSObject.Properties.Name -contains "backupWorkspaces") {
            if ($content.backupWorkspaces.PSObject.Properties.Name -contains "folders") {
                $content.backupWorkspaces.folders = @($content.backupWorkspaces.folders | Where-Object { 
                    $_.folderUri -notmatch "augment" 
                })
            }
        }
        
        if ($DryRun) {
            Write-LogInfo "DRY RUN: Would update $StoragePath"
            return $true
        }
        
        # Write back to file
        $content | ConvertTo-Json -Depth 10 | Set-Content $StoragePath -Encoding UTF8
        
        Write-LogSuccess "Updated fingerprint in: $StoragePath"
        return $true
        
    } catch {
        Write-LogError "Failed to update $StoragePath`: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Database Updates

function Update-DatabaseFingerprint {
    <#
    .SYNOPSIS
        Updates device fingerprint in SQLite database files
    .DESCRIPTION
        Modifies telemetry data in VS Code database files
    .PARAMETER DatabasePath
        Path to the SQLite database file
    .PARAMETER Fingerprint
        New fingerprint data to apply
    .EXAMPLE
        Update-DatabaseFingerprint -DatabasePath "C:\path\to\state.vscdb" -Fingerprint $fingerprint
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,
        [Parameter(Mandatory = $true)]
        [hashtable]$Fingerprint
    )
    
    if (-not (Test-Path $DatabasePath)) {
        Write-LogWarning "Database not found: $DatabasePath"
        return $false
    }
    
    try {
        Write-LogInfo "Updating fingerprint in database: $DatabasePath"
        
        if ($DryRun) {
            Write-LogInfo "DRY RUN: Would update database $DatabasePath"
            return $true
        }
        
        # Update telemetry fields in database
        $updateQueries = @(
            "UPDATE ItemTable SET value = '$($Fingerprint.MachineId)' WHERE key = 'telemetry.machineId';",
            "UPDATE ItemTable SET value = '$($Fingerprint.DeviceId)' WHERE key = 'telemetry.devDeviceId';",
            "UPDATE ItemTable SET value = '$($Fingerprint.SqmId)' WHERE key = 'telemetry.sqmId';",
            "UPDATE ItemTable SET value = '$($Fingerprint.FirstSessionDate)' WHERE key = 'telemetry.firstSessionDate';",
            "UPDATE ItemTable SET value = '$($Fingerprint.LastSessionDate)' WHERE key = 'telemetry.lastSessionDate';",
            "UPDATE ItemTable SET value = '$($Fingerprint.CurrentSessionDate)' WHERE key = 'telemetry.currentSessionDate';"
        )
        
        foreach ($query in $updateQueries) {
            & sqlite3 $DatabasePath $query
        }
        
        # Insert new telemetry fields if they don't exist
        $insertQueries = @(
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.machineId', '$($Fingerprint.MachineId)');",
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.devDeviceId', '$($Fingerprint.DeviceId)');",
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.sqmId', '$($Fingerprint.SqmId)');",
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.firstSessionDate', '$($Fingerprint.FirstSessionDate)');",
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.lastSessionDate', '$($Fingerprint.LastSessionDate)');",
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.currentSessionDate', '$($Fingerprint.CurrentSessionDate)');"
        )
        
        foreach ($query in $insertQueries) {
            & sqlite3 $DatabasePath $query
        }
        
        Write-LogSuccess "Updated fingerprint in database: $DatabasePath"
        return $true
        
    } catch {
        Write-LogError "Failed to update database $DatabasePath`: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Installation Discovery

function Get-VSCodeInstallations {
    <#
    .SYNOPSIS
        Discovers VS Code and related editor installations
    .DESCRIPTION
        Scans common installation paths for VS Code, Cursor, and other editors
    .EXAMPLE
        Get-VSCodeInstallations
    #>
    [CmdletBinding()]
    param()
    
    $installations = @()
    $appData = $env:APPDATA
    $localAppData = $env:LOCALAPPDATA
    
    $searchPaths = @(
        "$appData\Code",
        "$appData\Cursor", 
        "$appData\Code - Insiders",
        "$appData\Code - Exploration",
        "$localAppData\Code",
        "$localAppData\Cursor",
        "$localAppData\Code - Insiders",
        "$localAppData\VSCodium"
    )
    
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $installations += @{
                Path = $path
                Type = Split-Path $path -Leaf
                StorageFiles = @(
                    (Join-Path $path "User\storage.json"),
                    (Join-Path $path "User\globalStorage\storage.json")
                )
                DatabasePaths = @(
                    "$path\User\workspaceStorage\*\state.vscdb",
                    "$path\User\globalStorage\*\state.vscdb"
                )
            }
        }
    }
    
    return $installations
}

#endregion

#region Main Function

function Start-DeviceFingerprintReset {
    <#
    .SYNOPSIS
        Main function to reset device fingerprints
    .DESCRIPTION
        Orchestrates the complete device fingerprint reset process
    .EXAMPLE
        Start-DeviceFingerprintReset
    #>
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Starting Device Fingerprint Reset..."
    
    # Check for SQLite3
    try {
        $null = & sqlite3 -version
    } catch {
        Write-LogError "SQLite3 is required but not found in PATH. Please install SQLite3."
        return $false
    }
    
    # Generate new fingerprint
    $newFingerprint = New-DeviceFingerprint
    
    # Get VS Code installations
    $installations = Get-VSCodeInstallations
    if ($installations.Count -eq 0) {
        Write-LogWarning "No VS Code installations found"
        return $false
    }
    
    $totalUpdated = 0
    $totalErrors = 0
    
    foreach ($installation in $installations) {
        Write-LogInfo "Processing installation: $($installation.Type)"
        
        # Update storage files
        foreach ($storageFile in $installation.StorageFiles) {
            if (Update-StorageJsonFingerprint -StoragePath $storageFile -Fingerprint $newFingerprint) {
                $totalUpdated++
            } else {
                $totalErrors++
            }
        }
        
        # Update database files
        foreach ($dbPath in $installation.DatabasePaths) {
            $dbFiles = Get-ChildItem -Path $dbPath -ErrorAction SilentlyContinue
            foreach ($dbFile in $dbFiles) {
                if (Update-DatabaseFingerprint -DatabasePath $dbFile.FullName -Fingerprint $newFingerprint) {
                    $totalUpdated++
                } else {
                    $totalErrors++
                }
            }
        }
    }
    
    Write-LogSuccess "Device fingerprint reset completed."
    Write-LogInfo "Updated: $totalUpdated files, Errors: $totalErrors"
    
    if ($totalErrors -eq 0) {
        Write-LogSuccess "All device fingerprints successfully reset!"
        Write-LogInfo "New device identity created - trial tracking should be broken."
        return $true
    } else {
        Write-LogWarning "Some errors occurred during fingerprint reset."
        return $false
    }
}

#endregion

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    Start-DeviceFingerprintReset
}
