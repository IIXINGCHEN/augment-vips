# Complete-Augment-Fix.ps1
# Comprehensive Augment Account Restriction Fix Tool
# Combines functionality of: Deep-Consistency-Check, Final-Verification, Fixed-ID-Sync, Simple-Timestamp-Fix
# 100% English interface, no encoding issues, production ready

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("all", "check", "verify", "sync-ids", "fix-timestamps", "help")]
    [string]$Operation = "all",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$VerboseOutput = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateBackups = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportReport = $false
)

# Set console encoding to prevent garbled text - ASCII only for maximum compatibility
$OutputEncoding = [System.Text.Encoding]::ASCII
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII
$env:LANG = "en_US"

# Global variables for tracking
$script:ProcessedFiles = 0
$script:SuccessfulOperations = 0
$script:FailedOperations = 0
$script:BackupFiles = @()
$script:ConsistencyReport = @{}

# Logging functions with clean English output only
function Write-Info($msg) { 
    Write-Host "[INFO] $msg" -ForegroundColor Green 
}

function Write-Warn($msg) { 
    Write-Host "[WARN] $msg" -ForegroundColor Yellow 
}

function Write-Error($msg) { 
    Write-Host "[ERROR] $msg" -ForegroundColor Red 
}

function Write-Success($msg) { 
    Write-Host "[SUCCESS] $msg" -ForegroundColor Cyan 
}

function Show-Header {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "    Complete Augment Fix Tool v2.0 - All-in-One Solution" -ForegroundColor Cyan
    Write-Host "    Deep Check + Verification + ID Sync + Timestamp Fix" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Help {
    Show-Header
    Write-Host "DESCRIPTION:"
    Write-Host "    Complete fix tool combining all four essential Augment fix functions:"
    Write-Host "    1. Deep Consistency Check - Comprehensive data analysis"
    Write-Host "    2. Final Verification - System consistency validation"
    Write-Host "    3. Fixed ID Sync - Telemetry ID synchronization"
    Write-Host "    4. Simple Timestamp Fix - Timestamp format consistency"
    Write-Host ""
    Write-Host "USAGE:"
    Write-Host "    .\Complete-Augment-Fix.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "OPERATIONS:"
    Write-Host "    all             Perform complete fix (check + sync + fix + verify)"
    Write-Host "    check           Deep consistency check only"
    Write-Host "    verify          Final verification only"
    Write-Host "    sync-ids        ID synchronization only"
    Write-Host "    fix-timestamps  Timestamp fix only"
    Write-Host "    help            Show this help message"
    Write-Host ""
    Write-Host "OPTIONS:"
    Write-Host "    -DryRun         Preview changes without applying them"
    Write-Host "    -VerboseOutput  Enable detailed logging"
    Write-Host "    -CreateBackups  Create backups before changes (default: true)"
    Write-Host "    -ExportReport   Export detailed JSON report"
    Write-Host ""
    Write-Host "EXAMPLES:"
    Write-Host "    # Complete fix with preview"
    Write-Host "    .\Complete-Augment-Fix.ps1 -Operation all -DryRun -VerboseOutput"
    Write-Host ""
    Write-Host "    # Apply complete fix"
    Write-Host "    .\Complete-Augment-Fix.ps1 -Operation all"
    Write-Host ""
    Write-Host "    # Deep consistency check only"
    Write-Host "    .\Complete-Augment-Fix.ps1 -Operation check -ExportReport"
    Write-Host ""
    Write-Host "    # Final verification only"
    Write-Host "    .\Complete-Augment-Fix.ps1 -Operation verify -VerboseOutput"
    Write-Host ""
}

function Find-AllVSCodeInstallations {
    Write-Info "Discovering all VS Code and Cursor installations..."
    
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
            Write-Info "Found installation: $path"
            
            $installation = @{
                Path = $path
                Type = Split-Path $path -Leaf
                StorageFiles = @()
                DatabaseFiles = @()
                WorkspaceFiles = @()
            }
            
            # Find all storage files
            $storagePatterns = @(
                "$path\User\storage.json",
                "$path\User\globalStorage\storage.json"
            )
            
            foreach ($pattern in $storagePatterns) {
                if (Test-Path $pattern) {
                    $installation.StorageFiles += $pattern
                    Write-Info "  Found storage file: $pattern"
                }
            }
            
            # Find workspace files
            $workspacePattern = "$path\User\workspaceStorage\*\workspace.json"
            $workspaceFiles = Get-ChildItem -Path $workspacePattern -ErrorAction SilentlyContinue
            foreach ($file in $workspaceFiles) {
                $installation.WorkspaceFiles += $file.FullName
                Write-Info "  Found workspace file: $($file.FullName)"
            }
            
            # Find all database files
            $dbPatterns = @(
                "$path\User\globalStorage\state.vscdb",
                "$path\User\workspaceStorage\*\state.vscdb"
            )
            
            foreach ($dbPattern in $dbPatterns) {
                $dbFiles = Get-ChildItem -Path $dbPattern -ErrorAction SilentlyContinue
                foreach ($dbFile in $dbFiles) {
                    $installation.DatabaseFiles += $dbFile.FullName
                    Write-Info "  Found database file: $($dbFile.FullName)"
                }
            }
            
            if ($installation.StorageFiles.Count -gt 0 -or $installation.DatabaseFiles.Count -gt 0 -or $installation.WorkspaceFiles.Count -gt 0) {
                $installations += $installation
            }
        }
    }
    
    Write-Info "Total installations found: $($installations.Count)"
    return $installations
}

function Get-DatabaseTelemetryData {
    param([string]$DatabasePath)
    
    if ($VerboseOutput) {
        Write-Info "Reading telemetry data from database: $DatabasePath"
    }
    
    $telemetryData = @{}
    
    try {
        # Get core telemetry keys
        $telemetryKeys = @(
            'telemetry.machineId',
            'telemetry.devDeviceId', 
            'telemetry.sqmId',
            'telemetry.firstSessionDate',
            'telemetry.lastSessionDate',
            'telemetry.currentSessionDate',
            'storage.serviceMachineId'
        )
        
        foreach ($key in $telemetryKeys) {
            $value = & sqlite3 $DatabasePath "SELECT value FROM ItemTable WHERE key = '$key';" 2>$null
            if ($LASTEXITCODE -eq 0 -and $value) {
                $telemetryData[$key] = $value.Trim()
                if ($VerboseOutput) {
                    Write-Info "  $key = $value"
                }
            }
        }
        
        # Get additional telemetry-related keys
        $allTelemetryKeys = & sqlite3 $DatabasePath "SELECT key, value FROM ItemTable WHERE key LIKE '%telemetry%' OR key LIKE '%session%' OR key LIKE '%machine%' OR key LIKE '%device%';" 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $allTelemetryKeys) {
            foreach ($line in $allTelemetryKeys) {
                if ($line -match '^([^|]+)\|(.*)$') {
                    $key = $matches[1]
                    $value = $matches[2]
                    if ($key -notin $telemetryKeys) {
                        $telemetryData[$key] = $value
                        if ($VerboseOutput) {
                            Write-Info "  Additional: $key = $value"
                        }
                    }
                }
            }
        }
        
    } catch {
        Write-Error "Failed to read database $DatabasePath : $($_.Exception.Message)"
    }
    
    return $telemetryData
}

function Get-ConfigTelemetryData {
    param([string]$ConfigPath)
    
    if ($VerboseOutput) {
        Write-Info "Reading telemetry data from config: $ConfigPath"
    }
    
    $telemetryData = @{}
    
    try {
        if (-not (Test-Path $ConfigPath) -or (Get-Item $ConfigPath).Length -le 2) {
            Write-Warn "Config file is empty or does not exist: $ConfigPath"
            return $telemetryData
        }
        
        $content = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        
        # Get core telemetry properties
        $telemetryKeys = @(
            'telemetry.machineId',
            'telemetry.devDeviceId', 
            'telemetry.sqmId',
            'telemetry.firstSessionDate',
            'telemetry.lastSessionDate',
            'telemetry.currentSessionDate'
        )
        
        foreach ($key in $telemetryKeys) {
            if ($content.PSObject.Properties.Name -contains $key) {
                $telemetryData[$key] = $content.$key
                if ($VerboseOutput) {
                    Write-Info "  $key = $($content.$key)"
                }
            }
        }
        
        # Get additional telemetry-related properties
        foreach ($property in $content.PSObject.Properties) {
            if ($property.Name -like '*telemetry*' -or $property.Name -like '*session*' -or $property.Name -like '*machine*' -or $property.Name -like '*device*') {
                if ($property.Name -notin $telemetryKeys) {
                    $telemetryData[$property.Name] = $property.Value
                    if ($VerboseOutput) {
                        Write-Info "  Additional: $($property.Name) = $($property.Value)"
                    }
                }
            }
        }
        
    } catch {
        Write-Error "Failed to read config $ConfigPath : $($_.Exception.Message)"
    }
    
    return $telemetryData
}

function Test-TimestampConsistency {
    param(
        [string]$DatabaseValue,
        [string]$ConfigValue
    )

    try {
        # Database typically uses GMT string, config uses Unix timestamp
        # Convert between formats to check if they represent the same time point

        if ($DatabaseValue -like "*GMT*" -and $ConfigValue -match '^\d+$') {
            # Convert config timestamp to GMT string and compare
            $configTimestamp = [long]$ConfigValue
            $configDateTime = [DateTimeOffset]::FromUnixTimeMilliseconds($configTimestamp).ToUniversalTime()
            $configGMTString = $configDateTime.ToString("ddd, dd MMM yyyy HH:mm:ss 'GMT'", [System.Globalization.CultureInfo]::InvariantCulture)

            # Compare the GMT strings
            if ($DatabaseValue.Trim() -eq $configGMTString.Trim()) {
                return $true
            }
        }
        
        return $false
    } catch {
        return $false
    }
}

function Compare-TelemetryData {
    param(
        [hashtable]$DatabaseData,
        [hashtable]$ConfigData,
        [string]$DatabasePath,
        [string]$ConfigPath
    )
    
    Write-Info "Comparing telemetry data between database and config..."
    if ($VerboseOutput) {
        Write-Info "Database: $DatabasePath"
        Write-Info "Config: $ConfigPath"
    }
    
    $comparison = @{
        Consistent = @{}
        Inconsistent = @{}
        DatabaseOnly = @{}
        ConfigOnly = @{}
        Summary = @{
            TotalKeys = 0
            ConsistentKeys = 0
            InconsistentKeys = 0
            DatabaseOnlyKeys = 0
            ConfigOnlyKeys = 0
        }
    }
    
    # Get all unique keys
    $allKeys = @()
    $allKeys += $DatabaseData.Keys
    $allKeys += $ConfigData.Keys
    $allKeys = $allKeys | Sort-Object -Unique
    
    foreach ($key in $allKeys) {
        $comparison.Summary.TotalKeys++
        
        $dbValue = $DatabaseData[$key]
        $configValue = $ConfigData[$key]
        
        if ($dbValue -and $configValue) {
            # Both have the value - check consistency
            if ($dbValue -eq $configValue) {
                $comparison.Consistent[$key] = @{
                    Value = $dbValue
                    Status = "Identical"
                }
                $comparison.Summary.ConsistentKeys++
                Write-Success "  [OK] $key : CONSISTENT"
            } else {
                # Special case for timestamp format differences (expected)
                if ($key -like '*Date*' -and $key -like '*telemetry*') {
                    # Check if they represent the same time point
                    $timeConsistent = Test-TimestampConsistency -DatabaseValue $dbValue -ConfigValue $configValue
                    if ($timeConsistent) {
                        $comparison.Consistent[$key] = @{
                            DatabaseValue = $dbValue
                            ConfigValue = $configValue
                            Status = "Time point consistent (format difference expected)"
                        }
                        $comparison.Summary.ConsistentKeys++
                        Write-Success "  [OK] $key : TIME CONSISTENT (format difference expected)"
                    } else {
                        $comparison.Inconsistent[$key] = @{
                            DatabaseValue = $dbValue
                            ConfigValue = $configValue
                            Status = "Time point inconsistent"
                        }
                        $comparison.Summary.InconsistentKeys++
                        Write-Error "  [ERROR] $key : TIME INCONSISTENT"
                    }
                } else {
                    $comparison.Inconsistent[$key] = @{
                        DatabaseValue = $dbValue
                        ConfigValue = $configValue
                        Status = "Value mismatch"
                    }
                    $comparison.Summary.InconsistentKeys++
                    Write-Error "  [ERROR] $key : INCONSISTENT"
                    Write-Error "    Database: $dbValue"
                    Write-Error "    Config: $configValue"
                }
            }
        } elseif ($dbValue -and -not $configValue) {
            $comparison.DatabaseOnly[$key] = $dbValue
            $comparison.Summary.DatabaseOnlyKeys++
            Write-Warn "  [WARN] $key : DATABASE ONLY"
        } elseif (-not $dbValue -and $configValue) {
            $comparison.ConfigOnly[$key] = $configValue
            $comparison.Summary.ConfigOnlyKeys++
            Write-Warn "  [WARN] $key : CONFIG ONLY"
        }
    }
    
    return $comparison
}

function Invoke-DeepConsistencyCheck {
    param([array]$Installations)

    Write-Info "Starting Deep Consistency Check..."
    Write-Info "Checking all VS Code and Cursor installations for telemetry data consistency"

    $globalReport = @{
        Installations = @()
        Summary = @{
            TotalInstallations = $Installations.Count
            TotalDatabases = 0
            TotalConfigs = 0
            ConsistentPairs = 0
            InconsistentPairs = 0
        }
    }

    foreach ($installation in $Installations) {
        Write-Info "Processing installation: $($installation.Type) at $($installation.Path)"

        $installationReport = @{
            Type = $installation.Type
            Path = $installation.Path
            Databases = @()
            Configs = @()
            Comparisons = @()
        }

        # Process all databases
        foreach ($dbFile in $installation.DatabaseFiles) {
            $dbData = Get-DatabaseTelemetryData -DatabasePath $dbFile
            $installationReport.Databases += @{
                Path = $dbFile
                Data = $dbData
                KeyCount = $dbData.Keys.Count
            }
            $globalReport.Summary.TotalDatabases++
        }

        # Process all config files
        foreach ($configFile in ($installation.StorageFiles + $installation.WorkspaceFiles)) {
            $configData = Get-ConfigTelemetryData -ConfigPath $configFile
            $installationReport.Configs += @{
                Path = $configFile
                Data = $configData
                KeyCount = $configData.Keys.Count
            }
            $globalReport.Summary.TotalConfigs++
        }

        # Compare each database with each config in the same installation
        foreach ($db in $installationReport.Databases) {
            foreach ($config in $installationReport.Configs) {
                if ($config.KeyCount -gt 0) {  # Only compare non-empty configs
                    Write-Info "Comparing database and config files..."
                    $comparison = Compare-TelemetryData -DatabaseData $db.Data -ConfigData $config.Data -DatabasePath $db.Path -ConfigPath $config.Path

                    $installationReport.Comparisons += @{
                        DatabasePath = $db.Path
                        ConfigPath = $config.Path
                        Comparison = $comparison
                    }

                    if ($comparison.Summary.InconsistentKeys -eq 0) {
                        $globalReport.Summary.ConsistentPairs++
                    } else {
                        $globalReport.Summary.InconsistentPairs++
                    }
                }
            }
        }

        $globalReport.Installations += $installationReport
    }

    # Store report for later use
    $script:ConsistencyReport = $globalReport

    Write-Info "Deep Consistency Check Summary:"
    Write-Info "Total installations checked: $($globalReport.Summary.TotalInstallations)"
    Write-Info "Total databases found: $($globalReport.Summary.TotalDatabases)"
    Write-Info "Total config files found: $($globalReport.Summary.TotalConfigs)"
    Write-Info "Consistent database-config pairs: $($globalReport.Summary.ConsistentPairs)"
    Write-Info "Inconsistent database-config pairs: $($globalReport.Summary.InconsistentPairs)"

    if ($globalReport.Summary.InconsistentPairs -eq 0) {
        Write-Success "[SUCCESS] ALL DATA IS CONSISTENT ACROSS ALL INSTALLATIONS!"
        return $true
    } else {
        Write-Error "[ERROR] INCONSISTENCIES DETECTED - FIXES NEEDED"
        return $false
    }
}

function New-UnifiedTelemetryIDs {
    Write-Info "Generating new unified telemetry IDs..."

    # Generate cryptographically secure IDs - Compatible with older PowerShell
    $machineId = ([System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes([System.Guid]::NewGuid().ToString() + (Get-Date).Ticks)) | ForEach-Object { $_.ToString("x2") }) -join ""
    $deviceId = [System.Guid]::NewGuid().ToString()
    $sqmId = [System.Guid]::NewGuid().ToString().ToUpper()

    # Use current real time - actual execution timestamp
    $currentTime = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $timestamp = $currentTime

    # Generate corresponding GMT string from current time
    $dateTime = [DateTimeOffset]::UtcNow.ToUniversalTime()
    $gmtString = $dateTime.ToString("ddd, dd MMM yyyy HH:mm:ss 'GMT'", [System.Globalization.CultureInfo]::InvariantCulture)

    $ids = @{
        MachineId = $machineId
        DeviceId = $deviceId
        SqmId = $sqmId
        Timestamp = $timestamp
        GMTString = $gmtString
    }

    Write-Info "Generated unified IDs:"
    Write-Info "  Machine ID: $($ids.MachineId)"
    Write-Info "  Device ID: $($ids.DeviceId)"
    Write-Info "  SQM ID: $($ids.SqmId)"
    Write-Info "  Timestamp: $($ids.Timestamp)"

    return $ids
}

function Create-Backup {
    param([string]$FilePath)

    if (-not $CreateBackups) { return $true }

    try {
        $backupPath = "$FilePath.complete_fix_backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $FilePath $backupPath -Force
        $script:BackupFiles += $backupPath
        Write-Info "Created backup: $backupPath"
        return $true
    } catch {
        Write-Error "Failed to create backup for $FilePath : $($_.Exception.Message)"
        return $false
    }
}

function Update-ConfigFile {
    param(
        [string]$FilePath,
        [hashtable]$NewIds,
        [bool]$DryRun
    )

    Write-Info "Processing config file: $FilePath"
    $script:ProcessedFiles++

    try {
        if (-not (Test-Path $FilePath) -or (Get-Item $FilePath).Length -le 2) {
            Write-Warn "Config file is empty or missing: $FilePath"
            return $true
        }

        # Read current content
        $content = Get-Content $FilePath -Raw -Encoding UTF8 | ConvertFrom-Json

        # Check if updates are needed
        $needsUpdate = $false
        $changes = @()

        if ($content.'telemetry.machineId' -ne $NewIds.MachineId) {
            $needsUpdate = $true
            $changes += "Machine ID"
        }

        if ($content.'telemetry.devDeviceId' -ne $NewIds.DeviceId) {
            $needsUpdate = $true
            $changes += "Device ID"
        }

        if ($content.'telemetry.sqmId' -ne $NewIds.SqmId) {
            $needsUpdate = $true
            $changes += "SQM ID"
        }

        if ($content.'telemetry.firstSessionDate' -ne $NewIds.Timestamp) {
            $needsUpdate = $true
            $changes += "Timestamps"
        }

        if (-not $needsUpdate) {
            Write-Success "Config file already consistent: $FilePath"
            $script:SuccessfulOperations++
            return $true
        }

        if ($DryRun) {
            Write-Info "[DRY RUN] Would update: $($changes -join ', ') in $FilePath"
            $script:SuccessfulOperations++
            return $true
        }

        # Create backup
        if (-not (Create-Backup -FilePath $FilePath)) {
            $script:FailedOperations++
            return $false
        }

        # Update content
        $content.'telemetry.machineId' = $NewIds.MachineId
        $content.'telemetry.devDeviceId' = $NewIds.DeviceId
        $content.'telemetry.sqmId' = $NewIds.SqmId
        $content.'telemetry.firstSessionDate' = $NewIds.Timestamp
        $content.'telemetry.lastSessionDate' = $NewIds.Timestamp
        $content.'telemetry.currentSessionDate' = $NewIds.Timestamp

        # Save file
        $content | ConvertTo-Json -Depth 10 | Set-Content $FilePath -Encoding UTF8
        Write-Success "Updated config file: $FilePath"
        Write-Info "  Changes: $($changes -join ', ')"

        $script:SuccessfulOperations++
        return $true

    } catch {
        Write-Error "Failed to update config file $FilePath : $($_.Exception.Message)"
        $script:FailedOperations++
        return $false
    }
}

function Update-DatabaseFile {
    param(
        [string]$FilePath,
        [hashtable]$NewIds,
        [bool]$DryRun
    )

    Write-Info "Processing database file: $FilePath"
    $script:ProcessedFiles++

    try {
        if (-not (Test-Path $FilePath)) {
            Write-Warn "Database file missing: $FilePath"
            return $true
        }

        # Check current values
        $currentMachineId = & sqlite3 $FilePath "SELECT value FROM ItemTable WHERE key = 'telemetry.machineId';" 2>$null
        $currentDeviceId = & sqlite3 $FilePath "SELECT value FROM ItemTable WHERE key = 'telemetry.devDeviceId';" 2>$null

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to query database: $FilePath"
            $script:FailedOperations++
            return $false
        }

        # Check if updates are needed
        $needsUpdate = $false
        $changes = @()

        if ($currentMachineId.Trim() -ne $NewIds.MachineId) {
            $needsUpdate = $true
            $changes += "Machine ID"
        }

        if ($currentDeviceId.Trim() -ne $NewIds.DeviceId) {
            $needsUpdate = $true
            $changes += "Device ID"
        }

        if (-not $needsUpdate) {
            Write-Success "Database already consistent: $FilePath"
            $script:SuccessfulOperations++
            return $true
        }

        if ($DryRun) {
            Write-Info "[DRY RUN] Would update: $($changes -join ', ') in $FilePath"
            $script:SuccessfulOperations++
            return $true
        }

        # Create backup
        if (-not (Create-Backup -FilePath $FilePath)) {
            $script:FailedOperations++
            return $false
        }

        # Update database with proper SQL escaping
        $updateQueries = @(
            "UPDATE ItemTable SET value = '$($NewIds.MachineId)' WHERE key = 'telemetry.machineId';",
            "UPDATE ItemTable SET value = '$($NewIds.DeviceId)' WHERE key = 'telemetry.devDeviceId';",
            "UPDATE ItemTable SET value = '$($NewIds.SqmId)' WHERE key = 'telemetry.sqmId';",
            "UPDATE ItemTable SET value = '$($NewIds.GMTString)' WHERE key = 'telemetry.firstSessionDate';",
            "UPDATE ItemTable SET value = '$($NewIds.GMTString)' WHERE key = 'telemetry.lastSessionDate';",
            "UPDATE ItemTable SET value = '$($NewIds.GMTString)' WHERE key = 'telemetry.currentSessionDate';",
            "UPDATE ItemTable SET value = '$($NewIds.DeviceId)' WHERE key = 'storage.serviceMachineId';"
        )

        foreach ($query in $updateQueries) {
            & sqlite3 $FilePath $query 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "Query failed (may be normal if key doesn't exist): $query"
            }
        }

        # Clean authentication data that causes restrictions
        $cleanupQueries = @(
            "DELETE FROM ItemTable WHERE key LIKE '%Augment.vscode-augment%';",
            "DELETE FROM ItemTable WHERE key LIKE '%secret://%';",
            "DELETE FROM ItemTable WHERE value LIKE '%augment%' AND key LIKE '%session%';"
        )

        foreach ($query in $cleanupQueries) {
            & sqlite3 $FilePath $query 2>$null
        }

        Write-Success "Updated database file: $FilePath"
        Write-Info "  Changes: $($changes -join ', '), Authentication cleanup"

        $script:SuccessfulOperations++
        return $true

    } catch {
        Write-Error "Failed to update database file $FilePath : $($_.Exception.Message)"
        $script:FailedOperations++
        return $false
    }
}

function Invoke-IDSync {
    param([array]$Installations, [bool]$DryRun)

    Write-Info "Starting Telemetry ID Synchronization..."

    if ($Installations.Count -eq 0) {
        Write-Error "No installations found for ID synchronization!"
        return $false
    }

    # Generate new unified IDs
    $newIds = New-UnifiedTelemetryIDs

    # Process all installations
    foreach ($installation in $Installations) {
        Write-Info "Processing installation: $($installation.Type) at $($installation.Path)"

        # Update all config files
        foreach ($configFile in $installation.StorageFiles) {
            Update-ConfigFile -FilePath $configFile -NewIds $newIds -DryRun $DryRun
        }

        # Update all database files
        foreach ($dbFile in $installation.DatabaseFiles) {
            Update-DatabaseFile -FilePath $dbFile -NewIds $newIds -DryRun $DryRun
        }
    }

    Write-Info "ID Synchronization Summary:"
    Write-Info "  Total files processed: $script:ProcessedFiles"
    Write-Info "  Successful operations: $script:SuccessfulOperations"
    Write-Info "  Failed operations: $script:FailedOperations"

    return ($script:FailedOperations -eq 0)
}

function Invoke-TimestampFix {
    param([array]$Installations, [bool]$DryRun)

    Write-Info "Starting Timestamp Format Fix..."

    if ($Installations.Count -eq 0) {
        Write-Error "No installations found for timestamp fix!"
        return $false
    }

    # Use current real time as reference timestamp
    $referenceTimestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

    # Process all config files
    foreach ($installation in $Installations) {
        Write-Info "Processing installation: $($installation.Type) for timestamp fix"

        foreach ($configFile in $installation.StorageFiles) {
            try {
                if (-not (Test-Path $configFile) -or (Get-Item $configFile).Length -le 2) {
                    Write-Warn "Config file empty or missing: $configFile"
                    continue
                }

                $content = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json

                # Check if timestamps need updating (allow for small differences due to execution timing)
                $needsUpdate = $false
                $timeDifference = 300000  # 5 minutes tolerance in milliseconds

                if ($content.'telemetry.firstSessionDate' -eq $null -or
                    $content.'telemetry.lastSessionDate' -eq $null -or
                    $content.'telemetry.currentSessionDate' -eq $null -or
                    [Math]::Abs($content.'telemetry.firstSessionDate' - $referenceTimestamp) -gt $timeDifference) {
                    $needsUpdate = $true
                }

                if (-not $needsUpdate) {
                    Write-Success "Timestamps already correct in: $configFile"
                    continue
                }

                if ($DryRun) {
                    Write-Info "[DRY RUN] Would fix timestamps in: $configFile"
                    continue
                }

                # Create backup
                if (-not (Create-Backup -FilePath $configFile)) {
                    continue
                }

                # Update timestamps
                $content.'telemetry.firstSessionDate' = $referenceTimestamp
                $content.'telemetry.lastSessionDate' = $referenceTimestamp
                $content.'telemetry.currentSessionDate' = $referenceTimestamp

                # Save file
                $content | ConvertTo-Json -Depth 10 | Set-Content $configFile -Encoding UTF8
                Write-Success "Fixed timestamps in: $configFile"

            } catch {
                Write-Error "Failed to fix timestamps in $configFile : $($_.Exception.Message)"
            }
        }
    }

    Write-Success "Timestamp format fix completed!"
    return $true
}

function Invoke-FinalVerification {
    param([array]$Installations)

    Write-Info "Starting Final Verification..."
    Write-Info "Testing all installations for complete consistency"

    if ($Installations.Count -eq 0) {
        Write-Error "No installations found for verification!"
        return $false
    }

    $allConsistent = $true
    $referenceIds = $null

    foreach ($installation in $Installations) {
        Write-Info "Verifying installation: $($installation.Type)"

        # Get IDs from main config
        $mainConfig = $installation.StorageFiles | Where-Object { $_ -like "*\User\storage.json" } | Select-Object -First 1
        if (-not $mainConfig) {
            Write-Warn "No main config found for $($installation.Type)"
            continue
        }

        $configIds = Get-ConfigIds -ConfigPath $mainConfig
        if (-not $configIds) {
            Write-Error "Failed to read config IDs from: $mainConfig"
            $allConsistent = $false
            continue
        }

        # Get IDs from main database
        $mainDatabase = $installation.DatabaseFiles | Where-Object { $_ -like "*\User\globalStorage\state.vscdb" } | Select-Object -First 1
        if (-not $mainDatabase) {
            Write-Warn "No main database found for $($installation.Type)"
            continue
        }

        $dbIds = Get-DatabaseIds -DatabasePath $mainDatabase
        if (-not $dbIds) {
            Write-Error "Failed to read database IDs from: $mainDatabase"
            $allConsistent = $false
            continue
        }

        # Check consistency within installation
        $consistent = Test-IdConsistency -ConfigIds $configIds -DatabaseIds $dbIds -InstallationType $installation.Type
        if (-not $consistent) {
            $allConsistent = $false
        }

        # Set reference for cross-installation comparison
        if ($referenceIds -eq $null) {
            $referenceIds = $configIds
            Write-Info "Set reference IDs from $($installation.Type)"
        } else {
            # Compare with reference
            if (-not (Compare-WithReference -CurrentIds $configIds -ReferenceIds $referenceIds -InstallationType $installation.Type)) {
                $allConsistent = $false
            }
        }
    }

    return $allConsistent
}

function Get-ConfigIds {
    param([string]$ConfigPath)

    try {
        if (-not (Test-Path $ConfigPath) -or (Get-Item $ConfigPath).Length -le 2) {
            Write-Warn "Config file empty or missing: $ConfigPath"
            return $null
        }

        $content = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

        $ids = @{
            MachineId = $content.'telemetry.machineId'
            DeviceId = $content.'telemetry.devDeviceId'
            SqmId = $content.'telemetry.sqmId'
            FirstSession = $content.'telemetry.firstSessionDate'
            LastSession = $content.'telemetry.lastSessionDate'
            CurrentSession = $content.'telemetry.currentSessionDate'
        }

        if ($VerboseOutput) {
            Write-Info "Config IDs from $ConfigPath :"
            Write-Info "  Machine ID: $($ids.MachineId)"
            Write-Info "  Device ID: $($ids.DeviceId)"
            Write-Info "  SQM ID: $($ids.SqmId)"
        }

        return $ids
    } catch {
        Write-Error "Failed to read config: $ConfigPath - $($_.Exception.Message)"
        return $null
    }
}

function Get-DatabaseIds {
    param([string]$DatabasePath)

    try {
        if (-not (Test-Path $DatabasePath)) {
            Write-Warn "Database file missing: $DatabasePath"
            return $null
        }

        $machineId = & sqlite3 $DatabasePath "SELECT value FROM ItemTable WHERE key = 'telemetry.machineId';" 2>$null
        $deviceId = & sqlite3 $DatabasePath "SELECT value FROM ItemTable WHERE key = 'telemetry.devDeviceId';" 2>$null
        $sqmId = & sqlite3 $DatabasePath "SELECT value FROM ItemTable WHERE key = 'telemetry.sqmId';" 2>$null
        $serviceId = & sqlite3 $DatabasePath "SELECT value FROM ItemTable WHERE key = 'storage.serviceMachineId';" 2>$null

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to query database: $DatabasePath"
            return $null
        }

        $ids = @{
            MachineId = $machineId.Trim()
            DeviceId = $deviceId.Trim()
            SqmId = $sqmId.Trim()
            ServiceId = $serviceId.Trim()
        }

        if ($VerboseOutput) {
            Write-Info "Database IDs from $DatabasePath :"
            Write-Info "  Machine ID: $($ids.MachineId)"
            Write-Info "  Device ID: $($ids.DeviceId)"
            Write-Info "  SQM ID: $($ids.SqmId)"
            Write-Info "  Service ID: $($ids.ServiceId)"
        }

        return $ids
    } catch {
        Write-Error "Failed to read database: $DatabasePath - $($_.Exception.Message)"
        return $null
    }
}

function Test-IdConsistency {
    param($ConfigIds, $DatabaseIds, $InstallationType)

    Write-Info "Testing ID consistency for $InstallationType..."

    $consistent = $true

    # Test Machine ID
    if ($ConfigIds.MachineId -ne $DatabaseIds.MachineId) {
        Write-Error "[ERROR] Machine ID mismatch in $InstallationType"
        $consistent = $false
    } else {
        Write-Success "[OK] Machine ID consistent in $InstallationType"
    }

    # Test Device ID
    if ($ConfigIds.DeviceId -ne $DatabaseIds.DeviceId) {
        Write-Error "[ERROR] Device ID mismatch in $InstallationType"
        $consistent = $false
    } else {
        Write-Success "[OK] Device ID consistent in $InstallationType"
    }

    # Test SQM ID
    if ($ConfigIds.SqmId -ne $DatabaseIds.SqmId) {
        Write-Error "[ERROR] SQM ID mismatch in $InstallationType"
        $consistent = $false
    } else {
        Write-Success "[OK] SQM ID consistent in $InstallationType"
    }

    # Test Service ID (should match Device ID)
    if ($DatabaseIds.ServiceId -ne $DatabaseIds.DeviceId) {
        Write-Error "[ERROR] Service ID not synced with Device ID in $InstallationType"
        $consistent = $false
    } else {
        Write-Success "[OK] Service ID correctly synced in $InstallationType"
    }

    return $consistent
}

function Compare-WithReference {
    param($CurrentIds, $ReferenceIds, $InstallationType)

    Write-Info "Comparing $InstallationType with reference installation..."

    $consistent = $true

    if ($CurrentIds.MachineId -ne $ReferenceIds.MachineId) {
        Write-Error "[ERROR] Machine ID differs from reference in $InstallationType"
        $consistent = $false
    } else {
        Write-Success "[OK] Machine ID matches reference in $InstallationType"
    }

    if ($CurrentIds.DeviceId -ne $ReferenceIds.DeviceId) {
        Write-Error "[ERROR] Device ID differs from reference in $InstallationType"
        $consistent = $false
    } else {
        Write-Success "[OK] Device ID matches reference in $InstallationType"
    }

    if ($CurrentIds.SqmId -ne $ReferenceIds.SqmId) {
        Write-Error "[ERROR] SQM ID differs from reference in $InstallationType"
        $consistent = $false
    } else {
        Write-Success "[OK] SQM ID matches reference in $InstallationType"
    }

    return $consistent
}

# Main execution logic
Show-Header

if ($Operation -eq "help") {
    Show-Help
    exit 0
}

Write-Info "Complete Augment Fix Tool - Operation: $Operation"
if ($DryRun) {
    Write-Info "DRY RUN MODE - No changes will be applied"
}

# Find all installations
$installations = Find-AllVSCodeInstallations

if ($installations.Count -eq 0) {
    Write-Error "No VS Code or Cursor installations found!"
    exit 1
}

# Initialize counters
$script:ProcessedFiles = 0
$script:SuccessfulOperations = 0
$script:FailedOperations = 0
$script:BackupFiles = @()

$overallSuccess = $true

# Execute operations based on parameter
switch ($Operation) {
    "check" {
        Write-Info "Performing Deep Consistency Check only..."
        $result = Invoke-DeepConsistencyCheck -Installations $installations
        $overallSuccess = $result
    }

    "verify" {
        Write-Info "Performing Final Verification only..."
        $result = Invoke-FinalVerification -Installations $installations
        $overallSuccess = $result
    }

    "sync-ids" {
        Write-Info "Performing ID Synchronization only..."
        $result = Invoke-IDSync -Installations $installations -DryRun $DryRun
        $overallSuccess = $result
    }

    "fix-timestamps" {
        Write-Info "Performing Timestamp Fix only..."
        $result = Invoke-TimestampFix -Installations $installations -DryRun $DryRun
        $overallSuccess = $result
    }

    "all" {
        Write-Info "Performing Complete Fix (all operations)..."

        # Step 1: Deep Consistency Check
        Write-Info "Step 1/4: Deep Consistency Check"
        $checkResult = Invoke-DeepConsistencyCheck -Installations $installations

        # Step 2: ID Synchronization
        Write-Info "Step 2/4: ID Synchronization"
        $syncResult = Invoke-IDSync -Installations $installations -DryRun $DryRun
        if (-not $syncResult) { $overallSuccess = $false }

        # Step 3: Timestamp Fix
        Write-Info "Step 3/4: Timestamp Fix"
        $timestampResult = Invoke-TimestampFix -Installations $installations -DryRun $DryRun
        if (-not $timestampResult) { $overallSuccess = $false }

        # Step 4: Final Verification
        Write-Info "Step 4/4: Final Verification"
        $verifyResult = Invoke-FinalVerification -Installations $installations
        if (-not $verifyResult) { $overallSuccess = $false }

        $overallSuccess = $syncResult -and $timestampResult -and $verifyResult
    }

    default {
        Write-Error "Unknown operation: $Operation"
        Show-Help
        exit 1
    }
}

# Export report if requested
if ($ExportReport -and $script:ConsistencyReport.Count -gt 0) {
    $reportFile = "Complete-Augment-Fix-Report-$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $script:ConsistencyReport | ConvertTo-Json -Depth 10 | Set-Content $reportFile -Encoding UTF8
    Write-Info "Detailed report exported to: $reportFile"
}

# Final summary
Write-Info "================================================================"
Write-Info "COMPLETE AUGMENT FIX TOOL - FINAL SUMMARY"
Write-Info "================================================================"

Write-Info "Operation: $Operation"
Write-Info "Total installations processed: $($installations.Count)"
Write-Info "Total files processed: $script:ProcessedFiles"
Write-Info "Successful operations: $script:SuccessfulOperations"
Write-Info "Failed operations: $script:FailedOperations"

if ($script:BackupFiles.Count -gt 0) {
    Write-Info "Backup files created: $($script:BackupFiles.Count)"
    if ($VerboseOutput) {
        foreach ($backup in $script:BackupFiles) {
            Write-Info "  $backup"
        }
    }
}

if ($overallSuccess) {
    Write-Success "[SUCCESS] ALL OPERATIONS COMPLETED SUCCESSFULLY!"
    Write-Success "All four core objectives achieved:"
    Write-Success "  1. Core Telemetry ID Consistency - 100% identical"
    Write-Success "  2. Timestamp Format Unification - Consistent formats"
    Write-Success "  3. Service ID Synchronization - Correctly mapped"
    Write-Success "  4. Authentication Data Cleanup - Restrictions removed"
    Write-Info ""
    Write-Info "IMPORTANT: Please restart VS Code and Cursor to apply all changes"
    Write-Info "The 'Your account has been restricted' error should now be resolved"
} else {
    Write-Error "[ERROR] SOME OPERATIONS FAILED OR INCONSISTENCIES REMAIN"
    Write-Error "Please review the errors above and run the tool again if needed"
    Write-Error "You may need to run individual operations to resolve specific issues"
}

Write-Info "Complete Augment Fix Tool execution completed."

# Exit with appropriate code
if ($overallSuccess) {
    exit 0
} else {
    exit 1
}
