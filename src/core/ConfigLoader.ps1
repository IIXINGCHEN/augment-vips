# ConfigLoader.ps1
#
# Unified configuration loader for Augment VIP PowerShell modules
# Ensures all PowerShell modules use identical data patterns and formats
# Production-ready with comprehensive validation and error handling

# Configuration file paths
$script:ConfigFile = Join-Path $PROJECT_ROOT "src\config\augment_patterns.json"
$script:ProcessConfigFile = Join-Path $PROJECT_ROOT "src\config\process_config.json"

# Global configuration variables
$script:AugmentPatterns = @()
$script:AugmentCorePatterns = @()
$script:TelemetryPatterns = @()
$script:TrialPatterns = @()
$script:AnalyticsPatterns = @()
$script:AiPatterns = @()
$script:AuthPatterns = @()

# Telemetry field mappings
$script:MachineIdField = ""
$script:DeviceIdField = ""
$script:SqmIdField = ""
$script:MachineIdAltField = ""
$script:DeviceIdAltField = ""
$script:SqmIdAltField = ""

# File path configurations
$script:StorageFilePaths = @()
$script:TokenPaths = @()
$script:SessionPaths = @()

# SQL generation settings
$script:SqlCaseSensitive = $false
$script:SqlUseLowerFunction = $true
$script:SqlTransactionMode = "IMMEDIATE"
$script:SqlVacuumAfterDelete = $true

# ID generation settings
$script:MachineIdLength = 64
$script:MachineIdFormat = "hex"
$script:DeviceIdFormat = "uuid"
$script:SqmIdFormat = "uuid"
$script:EntropySources = @()

# Process configuration variables
$script:ProcessConfig = $null

# Configuration validation function
function Test-ConfigFile {
    param([string]$ConfigPath)
    
    Write-LogDebug "Validating configuration file: $ConfigPath"
    
    # Check file existence
    if (-not (Test-Path $ConfigPath)) {
        Write-LogError "Configuration file not found: $ConfigPath"
        return $false
    }
    
    # Check file readability
    try {
        $null = Get-Content $ConfigPath -ErrorAction Stop
    } catch {
        Write-LogError "Configuration file not readable: $ConfigPath - $($_.Exception.Message)"
        return $false
    }
    
    # Validate JSON format
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-LogError "Configuration file is not valid JSON: $ConfigPath - $($_.Exception.Message)"
        return $false
    }
    
    # Check required fields
    $requiredFields = @("version", "database_patterns", "telemetry_fields", "file_paths")
    
    foreach ($field in $requiredFields) {
        if (-not $config.PSObject.Properties[$field]) {
            Write-LogError "Required field missing in configuration: $field"
            return $false
        }
    }
    
    Write-LogDebug "Configuration file validation passed"
    return $true
}

# Load database patterns
function Import-DatabasePatterns {
    param([PSCustomObject]$Config)
    
    Write-LogDebug "Loading database patterns from configuration"
    
    try {
        # Load individual pattern categories
        $script:AugmentCorePatterns = @($Config.database_patterns.augment_core | Where-Object { $_ -and $_ -ne "null" })
        $script:TelemetryPatterns = @($Config.database_patterns.telemetry | Where-Object { $_ -and $_ -ne "null" })
        $script:TrialPatterns = @($Config.database_patterns.trial_data | Where-Object { $_ -and $_ -ne "null" })
        $script:AnalyticsPatterns = @($Config.database_patterns.analytics | Where-Object { $_ -and $_ -ne "null" })
        $script:AiPatterns = @($Config.database_patterns.ai_services | Where-Object { $_ -and $_ -ne "null" })
        $script:AuthPatterns = @($Config.database_patterns.authentication | Where-Object { $_ -and $_ -ne "null" })
        
        # Combine all patterns into master array
        $script:AugmentPatterns = @()
        $script:AugmentPatterns += $AugmentCorePatterns
        $script:AugmentPatterns += $TelemetryPatterns
        $script:AugmentPatterns += $TrialPatterns
        $script:AugmentPatterns += $AnalyticsPatterns
        $script:AugmentPatterns += $AiPatterns
        $script:AugmentPatterns += $AuthPatterns
        
        # Remove empty entries
        $script:AugmentPatterns = @($AugmentPatterns | Where-Object { $_ -and $_ -ne "null" -and $_.Trim() -ne "" })
        
        Write-LogDebug "Loaded $($AugmentPatterns.Count) database patterns"
        return $true
        
    } catch {
        Write-LogError "Failed to load database patterns: $($_.Exception.Message)"
        return $false
    }
}

# Load telemetry field mappings
function Import-TelemetryFields {
    param([PSCustomObject]$Config)
    
    Write-LogDebug "Loading telemetry field mappings"
    
    try {
        $script:MachineIdField = $Config.telemetry_fields.machine_id ?? "telemetry.machineId"
        $script:DeviceIdField = $Config.telemetry_fields.device_id ?? "telemetry.devDeviceId"
        $script:SqmIdField = $Config.telemetry_fields.sqm_id ?? "telemetry.sqmId"
        
        # Load fallback fields
        if ($Config.telemetry_fields.fallback_fields) {
            $script:MachineIdAltField = $Config.telemetry_fields.fallback_fields.machine_id_alt ?? "machineId"
            $script:DeviceIdAltField = $Config.telemetry_fields.fallback_fields.device_id_alt ?? "deviceId"
            $script:SqmIdAltField = $Config.telemetry_fields.fallback_fields.sqm_id_alt ?? "sqmId"
        }
        
        Write-LogDebug "Telemetry fields loaded: machine=$MachineIdField, device=$DeviceIdField, sqm=$SqmIdField"
        return $true
        
    } catch {
        Write-LogError "Failed to load telemetry fields: $($_.Exception.Message)"
        return $false
    }
}

# Load file path configurations
function Import-FilePaths {
    param([PSCustomObject]$Config)
    
    Write-LogDebug "Loading file path configurations"
    
    try {
        $script:StorageFilePaths = @($Config.file_paths.storage_files | Where-Object { $_ -and $_ -ne "null" })
        $script:TokenPaths = @($Config.file_paths.token_paths | Where-Object { $_ -and $_ -ne "null" })
        $script:SessionPaths = @($Config.file_paths.session_paths | Where-Object { $_ -and $_ -ne "null" })
        
        Write-LogDebug "File paths loaded: storage=$($StorageFilePaths.Count), tokens=$($TokenPaths.Count), sessions=$($SessionPaths.Count)"
        return $true
        
    } catch {
        Write-LogError "Failed to load file paths: $($_.Exception.Message)"
        return $false
    }
}

# Load SQL generation settings
function Import-SqlSettings {
    param([PSCustomObject]$Config)
    
    Write-LogDebug "Loading SQL generation settings"
    
    try {
        $script:SqlCaseSensitive = $Config.sql_generation.case_sensitive ?? $false
        $script:SqlUseLowerFunction = $Config.sql_generation.use_lower_function ?? $true
        $script:SqlTransactionMode = $Config.sql_generation.transaction_mode ?? "IMMEDIATE"
        $script:SqlVacuumAfterDelete = $Config.sql_generation.vacuum_after_delete ?? $true
        
        Write-LogDebug "SQL settings loaded: case_sensitive=$SqlCaseSensitive, use_lower=$SqlUseLowerFunction"
        return $true
        
    } catch {
        Write-LogError "Failed to load SQL settings: $($_.Exception.Message)"
        return $false
    }
}

# Load ID generation settings
function Import-IdSettings {
    param([PSCustomObject]$Config)
    
    Write-LogDebug "Loading ID generation settings"
    
    try {
        $script:MachineIdLength = $Config.id_generation.machine_id_length ?? 64
        $script:MachineIdFormat = $Config.id_generation.machine_id_format ?? "hex"
        $script:DeviceIdFormat = $Config.id_generation.device_id_format ?? "uuid"
        $script:SqmIdFormat = $Config.id_generation.sqm_id_format ?? "uuid"
        
        $script:EntropySources = @($Config.id_generation.entropy_sources | Where-Object { $_ -and $_ -ne "null" })
        
        Write-LogDebug "ID settings loaded: machine_length=$MachineIdLength, entropy_sources=$($EntropySources.Count)"
        return $true
        
    } catch {
        Write-LogError "Failed to load ID settings: $($_.Exception.Message)"
        return $false
    }
}

# Load process configuration
function Import-ProcessConfig {
    param([string]$ProcessConfigPath = $script:ProcessConfigFile)

    Write-LogDebug "Loading process configuration from: $ProcessConfigPath"

    try {
        if (-not (Test-Path $ProcessConfigPath)) {
            Write-LogWarning "Process configuration file not found: $ProcessConfigPath"
            return $false
        }

        $processConfig = Get-Content $ProcessConfigPath -Raw | ConvertFrom-Json
        $script:ProcessConfig = $processConfig

        Write-LogDebug "Process configuration loaded successfully"
        Write-LogInfo "  Supported processes: $($processConfig.supported_processes.PSObject.Properties.Count)"
        Write-LogInfo "  Detection enabled: $($processConfig.process_detection.enabled)"

        return $true

    } catch {
        Write-LogError "Failed to load process configuration: $($_.Exception.Message)"
        return $false
    }
}

# Generate SQL cleaning query from patterns
function New-SqlCleaningQuery {
    param([string[]]$Patterns = $script:AugmentPatterns)
    
    if (-not $Patterns -or $Patterns.Count -eq 0) {
        Write-LogError "No patterns available for SQL query generation"
        return $null
    }
    
    $queryParts = @()
    
    foreach ($pattern in $Patterns) {
        if ($pattern -and $pattern.Trim() -ne "") {
            if ($script:SqlUseLowerFunction -and -not $script:SqlCaseSensitive) {
                $queryParts += "LOWER(key) LIKE LOWER('$pattern')"
            } else {
                $queryParts += "key LIKE '$pattern'"
            }
        }
    }
    
    if ($queryParts.Count -eq 0) {
        Write-LogError "No valid patterns for SQL query generation"
        return $null
    }
    
    $whereClause = $queryParts -join " OR`n    "
    
    $query = @"
DELETE FROM ItemTable WHERE
    $whereClause;
"@
    
    return $query
}

# Main configuration loading function
function Load-AugmentConfig {
    param([string]$ConfigPath = $script:ConfigFile)
    
    Write-LogInfo "Loading unified Augment configuration from: $ConfigPath"
    
    # Validate configuration file
    if (-not (Test-ConfigFile $ConfigPath)) {
        Write-LogError "Configuration validation failed"
        return $false
    }
    
    try {
        # Load configuration
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        
        # Load all configuration sections
        if (-not (Import-DatabasePatterns $config)) {
            Write-LogError "Failed to load database patterns"
            return $false
        }
        
        if (-not (Import-TelemetryFields $config)) {
            Write-LogError "Failed to load telemetry fields"
            return $false
        }
        
        if (-not (Import-FilePaths $config)) {
            Write-LogError "Failed to load file paths"
            return $false
        }
        
        if (-not (Import-SqlSettings $config)) {
            Write-LogError "Failed to load SQL settings"
            return $false
        }
        
        if (-not (Import-IdSettings $config)) {
            Write-LogError "Failed to load ID settings"
            return $false
        }
        
        # Log configuration summary
        $configVersion = $config.version ?? "unknown"
        
        Write-LogSuccess "Configuration loaded successfully"
        Write-LogInfo "  Version: $configVersion"
        Write-LogInfo "  Total patterns: $($AugmentPatterns.Count)"
        Write-LogInfo "  Storage paths: $($StorageFilePaths.Count)"
        Write-LogInfo "  Token paths: $($TokenPaths.Count)"
        Write-LogInfo "  Session paths: $($SessionPaths.Count)"
        
        Write-AuditLog "CONFIG_LOAD" "Configuration loaded: version=$configVersion, patterns=$($AugmentPatterns.Count)"
        
        return $true
        
    } catch {
        Write-LogError "Failed to load configuration: $($_.Exception.Message)"
        return $false
    }
}

# Export configuration access functions
function Get-AugmentPatterns { return $script:AugmentPatterns }
function Get-TelemetryFields { 
    return @{
        MachineId = $script:MachineIdField
        DeviceId = $script:DeviceIdField
        SqmId = $script:SqmIdField
        MachineIdAlt = $script:MachineIdAltField
        DeviceIdAlt = $script:DeviceIdAltField
        SqmIdAlt = $script:SqmIdAltField
    }
}
function Get-FilePaths {
    return @{
        Storage = $script:StorageFilePaths
        Tokens = $script:TokenPaths
        Sessions = $script:SessionPaths
    }
}
function Get-SqlSettings {
    return @{
        CaseSensitive = $script:SqlCaseSensitive
        UseLowerFunction = $script:SqlUseLowerFunction
        TransactionMode = $script:SqlTransactionMode
        VacuumAfterDelete = $script:SqlVacuumAfterDelete
    }
}
function Get-IdSettings {
    return @{
        MachineIdLength = $script:MachineIdLength
        MachineIdFormat = $script:MachineIdFormat
        DeviceIdFormat = $script:DeviceIdFormat
        SqmIdFormat = $script:SqmIdFormat
        EntropySources = $script:EntropySources
    }
}

Write-LogDebug "Configuration loader module initialized"
