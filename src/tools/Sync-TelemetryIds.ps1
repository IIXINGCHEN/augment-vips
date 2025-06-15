# Sync-TelemetryIds.ps1
# Comprehensive Telemetry ID Synchronization Tool
# Ensures consistency between database and configuration files
# Version: 1.0.0 - Complete telemetry ID synchronization

[CmdletBinding()]
param(
    [switch]$DryRun = $false,
    [switch]$Verbose = $false,
    [switch]$Force = $false,
    [string]$TargetPath = "",
    [switch]$GenerateNew = $false
)

# Import dependencies
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreModulesPath = Split-Path $scriptPath -Parent | Join-Path -ChildPath "core"
$loggerPath = Join-Path $coreModulesPath "AugmentLogger.ps1"

if (Test-Path $loggerPath) {
    . $loggerPath
    Initialize-AugmentLogger -LogDirectory "logs" -LogFileName "telemetry_sync.log" -LogLevel "INFO"
} else {
    # Fallback logging
    function Write-LogInfo { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor White }
    function Write-LogSuccess { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
    function Write-LogWarning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    function Write-LogError { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
    function Write-LogDebug { param([string]$Message) if ($Verbose) { Write-Host "[DEBUG] $Message" -ForegroundColor Gray } }
}

# Set error handling
$ErrorActionPreference = "Stop"

#region Core Data Structures

class TelemetryData {
    [string]$MachineId
    [string]$DeviceId
    [string]$SqmId
    [string]$ServiceMachineId
    [long]$FirstSessionDate
    [long]$LastSessionDate
    [long]$CurrentSessionDate
    [string]$Source
    [string]$FilePath
    
    TelemetryData([string]$source, [string]$filePath) {
        $this.Source = $source
        $this.FilePath = $filePath
        $this.FirstSessionDate = 0
        $this.LastSessionDate = 0
        $this.CurrentSessionDate = 0
    }
}

class SyncResult {
    [bool]$Success
    [string]$Message
    [int]$FilesProcessed
    [int]$DatabasesProcessed
    [int]$ErrorsCount
    [array]$Details
    
    SyncResult() {
        $this.Success = $false
        $this.FilesProcessed = 0
        $this.DatabasesProcessed = 0
        $this.ErrorsCount = 0
        $this.Details = @()
    }
}

#endregion

#region ID Generation

function New-SecureTelemetryIds {
    <#
    .SYNOPSIS
        Generates new secure telemetry IDs
    .DESCRIPTION
        Creates cryptographically secure machine ID, device ID, and SQM ID
    .EXAMPLE
        New-SecureTelemetryIds
    #>
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Generating new secure telemetry IDs..."
    
    try {
        # Generate secure machine ID (64-character hex string)
        $machineIdBytes = New-Object byte[] 32
        [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($machineIdBytes)
        $machineId = [System.BitConverter]::ToString($machineIdBytes).Replace("-", "").ToLower()
        
        # Generate device ID (standard GUID)
        $deviceId = [System.Guid]::NewGuid().ToString()
        
        # Generate SQM ID (GUID with braces, uppercase)
        $sqmId = "{$([System.Guid]::NewGuid().ToString().ToUpper())}"
        
        # Generate session timestamps
        $currentTime = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $firstSessionTime = $currentTime - (Get-Random -Minimum 86400000 -Maximum 2592000000) # 1-30 days ago
        
        $telemetryIds = @{
            MachineId = $machineId
            DeviceId = $deviceId
            SqmId = $sqmId
            ServiceMachineId = [System.Guid]::NewGuid().ToString()
            FirstSessionDate = $firstSessionTime
            LastSessionDate = $currentTime
            CurrentSessionDate = $currentTime
        }
        
        Write-LogSuccess "Generated new telemetry IDs:"
        Write-LogInfo "  Machine ID: $($telemetryIds.MachineId)"
        Write-LogInfo "  Device ID: $($telemetryIds.DeviceId)"
        Write-LogInfo "  SQM ID: $($telemetryIds.SqmId)"
        Write-LogInfo "  Service Machine ID: $($telemetryIds.ServiceMachineId)"
        
        return $telemetryIds
        
    } catch {
        Write-LogError "Failed to generate secure telemetry IDs: $($_.Exception.Message)"
        throw
    }
}

#endregion

#region Data Detection

function Get-DatabaseTelemetryData {
    <#
    .SYNOPSIS
        Extracts telemetry data from SQLite database
    .DESCRIPTION
        Reads telemetry-related entries from VS Code database files
    .PARAMETER DatabasePath
        Path to the SQLite database file
    .EXAMPLE
        Get-DatabaseTelemetryData -DatabasePath "C:\path\to\state.vscdb"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath
    )

    if (-not (Test-Path $DatabasePath)) {
        Write-LogWarning "Database not found: $DatabasePath"
        return $null
    }

    try {
        Write-LogDebug "Reading telemetry data from database: $DatabasePath"

        $telemetryData = [TelemetryData]::new("Database", $DatabasePath)

        # Query for all telemetry-related entries
        $telemetryQuery = @"
SELECT key, value FROM ItemTable WHERE
    key = 'telemetry.machineId' OR
    key = 'telemetry.devDeviceId' OR
    key = 'telemetry.sqmId' OR
    key = 'storage.serviceMachineId' OR
    key = 'telemetry.firstSessionDate' OR
    key = 'telemetry.lastSessionDate' OR
    key = 'telemetry.currentSessionDate';
"@

        $result = & sqlite3 $DatabasePath $telemetryQuery 2>$null

        if ($LASTEXITCODE -eq 0 -and $result) {
            foreach ($line in $result) {
                if ($line -and $line.Contains("|")) {
                    $parts = $line.Split("|", 2)
                    $key = $parts[0]
                    $value = if ($parts.Length -gt 1) { $parts[1] } else { "" }

                    switch ($key) {
                        "telemetry.machineId" { $telemetryData.MachineId = $value }
                        "telemetry.devDeviceId" { $telemetryData.DeviceId = $value }
                        "telemetry.sqmId" { $telemetryData.SqmId = $value }
                        "storage.serviceMachineId" { $telemetryData.ServiceMachineId = $value }
                        "telemetry.firstSessionDate" {
                            if ($value -match '^\d+$') { $telemetryData.FirstSessionDate = [long]$value }
                        }
                        "telemetry.lastSessionDate" {
                            if ($value -match '^\d+$') { $telemetryData.LastSessionDate = [long]$value }
                        }
                        "telemetry.currentSessionDate" {
                            if ($value -match '^\d+$') { $telemetryData.CurrentSessionDate = [long]$value }
                        }
                    }
                }
            }
        }

        Write-LogDebug "Database telemetry data extracted successfully"
        return $telemetryData

    } catch {
        Write-LogError "Failed to read telemetry data from database $DatabasePath`: $($_.Exception.Message)"
        return $null
    }
}

function Get-StorageTelemetryData {
    <#
    .SYNOPSIS
        Extracts telemetry data from storage.json file
    .DESCRIPTION
        Reads telemetry-related entries from VS Code storage files
    .PARAMETER StoragePath
        Path to the storage.json file
    .EXAMPLE
        Get-StorageTelemetryData -StoragePath "C:\path\to\storage.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StoragePath
    )

    if (-not (Test-Path $StoragePath)) {
        Write-LogWarning "Storage file not found: $StoragePath"
        return $null
    }

    try {
        Write-LogDebug "Reading telemetry data from storage: $StoragePath"

        $telemetryData = [TelemetryData]::new("Storage", $StoragePath)

        # Read and parse JSON
        $content = Get-Content $StoragePath -Raw | ConvertFrom-Json

        # Extract telemetry fields
        if ($content.PSObject.Properties.Name -contains "telemetry.machineId") {
            $telemetryData.MachineId = $content."telemetry.machineId"
        }
        if ($content.PSObject.Properties.Name -contains "telemetry.devDeviceId") {
            $telemetryData.DeviceId = $content."telemetry.devDeviceId"
        }
        if ($content.PSObject.Properties.Name -contains "telemetry.sqmId") {
            $telemetryData.SqmId = $content."telemetry.sqmId"
        }
        if ($content.PSObject.Properties.Name -contains "telemetry.firstSessionDate") {
            $value = $content."telemetry.firstSessionDate"
            if ($value -match '^\d+$') { $telemetryData.FirstSessionDate = [long]$value }
        }
        if ($content.PSObject.Properties.Name -contains "telemetry.lastSessionDate") {
            $value = $content."telemetry.lastSessionDate"
            if ($value -match '^\d+$') { $telemetryData.LastSessionDate = [long]$value }
        }
        if ($content.PSObject.Properties.Name -contains "telemetry.currentSessionDate") {
            $value = $content."telemetry.currentSessionDate"
            if ($value -match '^\d+$') { $telemetryData.CurrentSessionDate = [long]$value }
        }

        Write-LogDebug "Storage telemetry data extracted successfully"
        return $telemetryData

    } catch {
        Write-LogError "Failed to read telemetry data from storage $StoragePath`: $($_.Exception.Message)"
        return $null
    }
}

#endregion

#region Synchronization Functions

function Update-DatabaseTelemetry {
    <#
    .SYNOPSIS
        Updates telemetry data in SQLite database
    .DESCRIPTION
        Synchronizes telemetry IDs in VS Code database files
    .PARAMETER DatabasePath
        Path to the SQLite database file
    .PARAMETER TelemetryIds
        Hashtable containing new telemetry IDs
    .EXAMPLE
        Update-DatabaseTelemetry -DatabasePath "C:\path\to\state.vscdb" -TelemetryIds $ids
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,
        [Parameter(Mandatory = $true)]
        [hashtable]$TelemetryIds
    )

    if (-not (Test-Path $DatabasePath)) {
        Write-LogWarning "Database not found: $DatabasePath"
        return $false
    }

    try {
        Write-LogInfo "Updating telemetry data in database: $DatabasePath"

        if ($DryRun) {
            Write-LogInfo "DRY RUN: Would update database $DatabasePath"
            return $true
        }

        # Create backup
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = "$DatabasePath.telemetry_backup_$timestamp"
        Copy-Item $DatabasePath $backupPath
        Write-LogDebug "Database backup created: $backupPath"

        # Update/Insert telemetry fields
        $updateQueries = @(
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.machineId', '$($TelemetryIds.MachineId)');",
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.devDeviceId', '$($TelemetryIds.DeviceId)');",
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.sqmId', '$($TelemetryIds.SqmId)');",
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('storage.serviceMachineId', '$($TelemetryIds.ServiceMachineId)');",
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.firstSessionDate', '$($TelemetryIds.FirstSessionDate)');",
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.lastSessionDate', '$($TelemetryIds.LastSessionDate)');",
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.currentSessionDate', '$($TelemetryIds.CurrentSessionDate)');"
        )

        foreach ($query in $updateQueries) {
            $result = & sqlite3 $DatabasePath $query 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-LogError "Failed to execute query: $query"
                Write-LogError "SQLite error: $result"
                return $false
            }
        }

        Write-LogSuccess "Database telemetry data updated successfully"
        return $true

    } catch {
        Write-LogError "Failed to update database $DatabasePath`: $($_.Exception.Message)"
        return $false
    }
}

function Update-StorageTelemetry {
    <#
    .SYNOPSIS
        Updates telemetry data in storage.json file
    .DESCRIPTION
        Synchronizes telemetry IDs in VS Code storage files
    .PARAMETER StoragePath
        Path to the storage.json file
    .PARAMETER TelemetryIds
        Hashtable containing new telemetry IDs
    .EXAMPLE
        Update-StorageTelemetry -StoragePath "C:\path\to\storage.json" -TelemetryIds $ids
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StoragePath,
        [Parameter(Mandatory = $true)]
        [hashtable]$TelemetryIds
    )

    if (-not (Test-Path $StoragePath)) {
        Write-LogWarning "Storage file not found: $StoragePath"
        return $false
    }

    try {
        Write-LogInfo "Updating telemetry data in storage: $StoragePath"

        if ($DryRun) {
            Write-LogInfo "DRY RUN: Would update storage $StoragePath"
            return $true
        }

        # Create backup
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = "$StoragePath.telemetry_backup_$timestamp"
        Copy-Item $StoragePath $backupPath
        Write-LogDebug "Storage backup created: $backupPath"

        # Read and parse JSON
        $content = Get-Content $StoragePath -Raw | ConvertFrom-Json

        # Update telemetry fields
        $content | Add-Member -MemberType NoteProperty -Name "telemetry.machineId" -Value $TelemetryIds.MachineId -Force
        $content | Add-Member -MemberType NoteProperty -Name "telemetry.devDeviceId" -Value $TelemetryIds.DeviceId -Force
        $content | Add-Member -MemberType NoteProperty -Name "telemetry.sqmId" -Value $TelemetryIds.SqmId -Force
        $content | Add-Member -MemberType NoteProperty -Name "telemetry.firstSessionDate" -Value $TelemetryIds.FirstSessionDate -Force
        $content | Add-Member -MemberType NoteProperty -Name "telemetry.lastSessionDate" -Value $TelemetryIds.LastSessionDate -Force
        $content | Add-Member -MemberType NoteProperty -Name "telemetry.currentSessionDate" -Value $TelemetryIds.CurrentSessionDate -Force

        # Write back to file
        $content | ConvertTo-Json -Depth 10 | Set-Content $StoragePath -Encoding UTF8

        Write-LogSuccess "Storage telemetry data updated successfully"
        return $true

    } catch {
        Write-LogError "Failed to update storage $StoragePath`: $($_.Exception.Message)"
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
            Write-LogDebug "Found installation: $path"

            $installation = @{
                Path = $path
                Type = Split-Path $path -Leaf
                StorageFiles = @()
                DatabaseFiles = @()
            }

            # Find storage files
            $storageFiles = @(
                (Join-Path $path "User\storage.json"),
                (Join-Path $path "User\globalStorage\storage.json")
            )

            foreach ($storageFile in $storageFiles) {
                if (Test-Path $storageFile) {
                    $installation.StorageFiles += $storageFile
                }
            }

            # Find database files
            $dbPaths = @(
                "$path\User\workspaceStorage\*\state.vscdb",
                "$path\User\globalStorage\*\state.vscdb"
            )

            foreach ($dbPath in $dbPaths) {
                $dbFiles = Get-ChildItem -Path $dbPath -ErrorAction SilentlyContinue
                foreach ($dbFile in $dbFiles) {
                    $installation.DatabaseFiles += $dbFile.FullName
                }
            }

            if ($installation.StorageFiles.Count -gt 0 -or $installation.DatabaseFiles.Count -gt 0) {
                $installations += $installation
            }
        }
    }

    Write-LogInfo "Found $($installations.Count) VS Code installations"
    return $installations
}

#endregion

#region Consistency Testing

function Test-TelemetryConsistency {
    <#
    .SYNOPSIS
        Tests telemetry data for consistency across files
    .PARAMETER TelemetryDataArray
        Array of TelemetryData objects to check
    .EXAMPLE
        Test-TelemetryConsistency -TelemetryDataArray $dataArray
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$TelemetryDataArray
    )

    if ($TelemetryDataArray.Count -eq 0) {
        return $false
    }

    $inconsistenciesFound = $false
    $reference = $TelemetryDataArray[0]

    foreach ($data in $TelemetryDataArray) {
        if ($data.MachineId -and $reference.MachineId -and $data.MachineId -ne $reference.MachineId) {
            Write-LogWarning "Machine ID inconsistency: $($data.FilePath) has $($data.MachineId), reference has $($reference.MachineId)"
            $inconsistenciesFound = $true
        }
        if ($data.DeviceId -and $reference.DeviceId -and $data.DeviceId -ne $reference.DeviceId) {
            Write-LogWarning "Device ID inconsistency: $($data.FilePath) has $($data.DeviceId), reference has $($reference.DeviceId)"
            $inconsistenciesFound = $true
        }
        if ($data.SqmId -and $reference.SqmId -and $data.SqmId -ne $reference.SqmId) {
            Write-LogWarning "SQM ID inconsistency: $($data.FilePath) has $($data.SqmId), reference has $($reference.SqmId)"
            $inconsistenciesFound = $true
        }
        if ($data.ServiceMachineId -and $reference.ServiceMachineId -and $data.ServiceMachineId -ne $reference.ServiceMachineId) {
            Write-LogWarning "Service Machine ID inconsistency: $($data.FilePath) has $($data.ServiceMachineId), reference has $($reference.ServiceMachineId)"
            $inconsistenciesFound = $true
        }
    }

    return $inconsistenciesFound
}

#endregion

#region Main Synchronization Function

function Start-TelemetrySync {
    <#
    .SYNOPSIS
        Main function to synchronize telemetry IDs
    .DESCRIPTION
        Orchestrates the complete telemetry ID synchronization process
    .EXAMPLE
        Start-TelemetrySync
    #>
    [CmdletBinding()]
    param()

    Write-LogInfo "Starting Telemetry ID Synchronization..."
    Write-LogInfo "DryRun: $DryRun, GenerateNew: $GenerateNew, Force: $Force"

    # Check for SQLite3
    try {
        $null = & sqlite3 -version 2>$null
        Write-LogDebug "SQLite3 is available"
    } catch {
        Write-LogError "SQLite3 is required but not found in PATH. Please install SQLite3."
        return $false
    }

    $syncResult = [SyncResult]::new()

    try {
        # Get VS Code installations
        $installations = Get-VSCodeInstallations
        if ($installations.Count -eq 0) {
            Write-LogWarning "No VS Code installations found"
            $syncResult.Message = "No installations found"
            return $syncResult
        }

        # Generate new telemetry IDs if requested or detect inconsistencies
        $newTelemetryIds = $null
        if ($GenerateNew) {
            $newTelemetryIds = New-SecureTelemetryIds
        } else {
            # Analyze existing data to determine if sync is needed
            Write-LogInfo "Analyzing existing telemetry data for inconsistencies..."

            $allTelemetryData = @()
            foreach ($installation in $installations) {
                # Check storage files
                foreach ($storageFile in $installation.StorageFiles) {
                    $data = Get-StorageTelemetryData -StoragePath $storageFile
                    if ($data) { $allTelemetryData += $data }
                }

                # Check database files
                foreach ($dbFile in $installation.DatabaseFiles) {
                    $data = Get-DatabaseTelemetryData -DatabasePath $dbFile
                    if ($data) { $allTelemetryData += $data }
                }
            }

            # Check for inconsistencies
            $inconsistenciesFound = Test-TelemetryConsistency -TelemetryDataArray $allTelemetryData

            if ($inconsistenciesFound -or $Force) {
                Write-LogWarning "Inconsistencies detected or Force flag used. Generating new IDs..."
                $newTelemetryIds = New-SecureTelemetryIds
            } else {
                Write-LogSuccess "All telemetry IDs are consistent. No synchronization needed."
                $syncResult.Success = $true
                $syncResult.Message = "No synchronization needed - all IDs are consistent"
                return $syncResult
            }
        }

        if (-not $newTelemetryIds) {
            Write-LogError "Failed to generate new telemetry IDs"
            $syncResult.Message = "Failed to generate new IDs"
            return $syncResult
        }

        # Apply synchronization to all installations
        foreach ($installation in $installations) {
            Write-LogInfo "Processing installation: $($installation.Type) at $($installation.Path)"

            # Update storage files
            foreach ($storageFile in $installation.StorageFiles) {
                if (Update-StorageTelemetry -StoragePath $storageFile -TelemetryIds $newTelemetryIds) {
                    $syncResult.FilesProcessed++
                    $syncResult.Details += "Updated storage: $storageFile"
                } else {
                    $syncResult.ErrorsCount++
                    $syncResult.Details += "Failed storage: $storageFile"
                }
            }

            # Update database files
            foreach ($dbFile in $installation.DatabaseFiles) {
                if (Update-DatabaseTelemetry -DatabasePath $dbFile -TelemetryIds $newTelemetryIds) {
                    $syncResult.DatabasesProcessed++
                    $syncResult.Details += "Updated database: $dbFile"
                } else {
                    $syncResult.ErrorsCount++
                    $syncResult.Details += "Failed database: $dbFile"
                }
            }
        }

        # Final result
        if ($syncResult.ErrorsCount -eq 0) {
            $syncResult.Success = $true
            $syncResult.Message = "Telemetry synchronization completed successfully"
            Write-LogSuccess "Telemetry ID synchronization completed successfully!"
            Write-LogInfo "Files processed: $($syncResult.FilesProcessed), Databases processed: $($syncResult.DatabasesProcessed)"
        } else {
            $syncResult.Message = "Synchronization completed with $($syncResult.ErrorsCount) errors"
            Write-LogWarning "Synchronization completed with errors. Check logs for details."
        }

        return $syncResult

    } catch {
        Write-LogError "Synchronization failed: $($_.Exception.Message)"
        $syncResult.Message = "Synchronization failed: $($_.Exception.Message)"
        return $syncResult
    }
}

#endregion

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    Start-TelemetrySync
}
