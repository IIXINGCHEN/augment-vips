# ConfigurationManager.ps1
# Unified Configuration Management for Augment VIP
# Version: 3.0.0 - Standardized and optimized
# Features: Centralized config loading, validation, hot-reload, encryption support

[CmdletBinding()]
param(
    [switch]$VerboseOutput = $false,
    [switch]$DebugOutput = $false
)

# Prevent multiple inclusions
if ($Global:AugmentConfigManagerLoaded) {
    return
}
$Global:AugmentConfigManagerLoaded = $true

# Import dependencies
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$loggerPath = Join-Path $scriptPath "AugmentLogger.ps1"
if (Test-Path $loggerPath) {
    . $loggerPath
}

# Error handling
$ErrorActionPreference = "Stop"

#region Configuration

# Global configuration manager state
$Global:ConfigManager = @{
    Configurations = @{}
    ConfigFiles = @{}
    Environment = "Development"
    DefaultConfigPath = ""
    EnableHotReload = $false
    EnableValidation = $true
    EnableEncryption = $false
    ConfigSchema = @{}
    LastLoadTime = $null
    FileWatchers = @{}
    Initialized = $false
}

# Configuration validation schema
$Global:ConfigSchema = @{
    Required = @()
    Optional = @()
    Types = @{}
    Constraints = @{}
    Defaults = @{}
}

# Default configuration paths - simplified structure
$Global:DefaultConfigPaths = @{
    MainConfig = "src/config/config.json"
    Patterns = "src/config/patterns.json"
}

#endregion

#region Core Functions

# Convert PSCustomObject to hashtable (for PowerShell 5.1 compatibility)
function Convert-PSObjectToHashtable {
    <#
    .SYNOPSIS
        Converts PSCustomObject to hashtable recursively
    .DESCRIPTION
        Provides compatibility for older PowerShell versions that don't support -AsHashtable
    .PARAMETER InputObject
        The PSCustomObject to convert
    .EXAMPLE
        Convert-PSObjectToHashtable $psObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject
    )

    if ($InputObject -is [PSCustomObject]) {
        $hashtable = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $value = $property.Value
            if ($value -is [PSCustomObject]) {
                $hashtable[$property.Name] = Convert-PSObjectToHashtable $value
            } elseif ($value -is [Array]) {
                $hashtable[$property.Name] = @()
                foreach ($item in $value) {
                    if ($item -is [PSCustomObject]) {
                        $hashtable[$property.Name] += Convert-PSObjectToHashtable $item
                    } else {
                        $hashtable[$property.Name] += $item
                    }
                }
            } else {
                $hashtable[$property.Name] = $value
            }
        }
        return $hashtable
    } else {
        return $InputObject
    }
}

# Initialize configuration manager
function Initialize-ConfigurationManager {
    <#
    .SYNOPSIS
        Initializes the Augment VIP configuration management system
    .DESCRIPTION
        Sets up configuration loading, validation, and monitoring capabilities
    .PARAMETER Environment
        Environment name (Development, Testing, Production)
    .PARAMETER DefaultConfigPath
        Default path for configuration files
    .PARAMETER EnableHotReload
        Enable automatic reloading when config files change
    .PARAMETER EnableValidation
        Enable configuration validation
    .PARAMETER EnableEncryption
        Enable configuration encryption support
    .EXAMPLE
        Initialize-ConfigurationManager -Environment "Production" -EnableValidation
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("Development", "Testing", "Production")]
        [string]$Environment = "Development",
        [string]$DefaultConfigPath = "",
        [switch]$EnableHotReload,
        [switch]$EnableValidation = $true,
        [switch]$EnableEncryption
    )
    
    try {
        Write-LogInfo "Initializing Configuration Manager" -Category "CONFIG"
        
        # Set configuration
        $Global:ConfigManager.Environment = $Environment
        $Global:ConfigManager.DefaultConfigPath = if ($DefaultConfigPath) { $DefaultConfigPath } else { "src/config" }
        $Global:ConfigManager.EnableHotReload = $EnableHotReload
        $Global:ConfigManager.EnableValidation = $EnableValidation
        $Global:ConfigManager.EnableEncryption = $EnableEncryption
        $Global:ConfigManager.LastLoadTime = Get-Date
        
        # Load default configurations
        $success = $true
        foreach ($configName in $Global:DefaultConfigPaths.Keys) {
            $configPath = $Global:DefaultConfigPaths[$configName]
            if (-not (Load-Configuration -Name $configName -Path $configPath)) {
                Write-LogWarning "Failed to load configuration: $configName" -Category "CONFIG"
                $success = $false
            }
        }
        
        # Setup file watchers if hot reload is enabled
        if ($EnableHotReload) {
            Initialize-ConfigFileWatchers
        }
        
        $Global:ConfigManager.Initialized = $true
        Write-LogSuccess "Configuration Manager initialized successfully" -Category "CONFIG"
        return $success
        
    } catch {
        Write-LogError "Failed to initialize Configuration Manager: $($_.Exception.Message)" -Category "CONFIG"
        return $false
    }
}

# Load configuration from file
function Load-Configuration {
    <#
    .SYNOPSIS
        Loads a configuration file into memory
    .DESCRIPTION
        Reads and parses configuration files with validation and error handling
    .PARAMETER Name
        Configuration name/identifier
    .PARAMETER Path
        Path to configuration file
    .PARAMETER Validate
        Enable validation for this configuration
    .EXAMPLE
        Load-Configuration -Name "AugmentPatterns" -Path "config/augment_patterns.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [switch]$Validate = $true
    )
    
    try {
        Write-LogDebug "Loading configuration: $Name from $Path" -Category "CONFIG"
        
        # Check if file exists
        if (-not (Test-Path $Path)) {
            Write-LogError "Configuration file not found: $Path" -Category "CONFIG"
            return $false
        }
        
        # Read and parse configuration file
        $configContent = Get-Content -Path $Path -Raw -Encoding UTF8
        $configData = $null
        
        # Determine file type and parse accordingly
        $extension = [System.IO.Path]::GetExtension($Path).ToLower()
        switch ($extension) {
            ".json" {
                try {
                    # Try with -AsHashtable first (PowerShell 6+)
                    $configData = $configContent | ConvertFrom-Json -AsHashtable
                } catch {
                    # Fallback for older PowerShell versions
                    $configData = $configContent | ConvertFrom-Json
                    # Convert PSCustomObject to hashtable for consistency
                    if ($configData -is [PSCustomObject]) {
                        $configData = Convert-PSObjectToHashtable $configData
                    }
                }
            }
            ".xml" {
                $configData = [xml]$configContent
            }
            { $_ -in @(".yaml", ".yml") } {
                # Note: PowerShell doesn't have native YAML support
                Write-LogWarning "YAML configuration files require additional modules" -Category "CONFIG"
                return $false
            }
            default {
                Write-LogError "Unsupported configuration file format: $extension" -Category "CONFIG"
                return $false
            }
        }
        
        # Validate configuration if enabled
        if ($Validate -and $Global:ConfigManager.EnableValidation) {
            if (-not (Test-ConfigurationValidation -Name $Name -Data $configData)) {
                Write-LogError "Configuration validation failed: $Name" -Category "CONFIG"
                return $false
            }
        }
        
        # Store configuration
        $Global:ConfigManager.Configurations[$Name] = $configData
        $Global:ConfigManager.ConfigFiles[$Name] = $Path
        
        Write-LogSuccess "Configuration loaded successfully: $Name" -Category "CONFIG"
        return $true
        
    } catch {
        Write-LogError "Failed to load configuration $Name`: $($_.Exception.Message)" -Category "CONFIG"
        return $false
    }
}

# Get configuration value
function Get-ConfigurationValue {
    <#
    .SYNOPSIS
        Retrieves a configuration value by path
    .DESCRIPTION
        Gets configuration values using dot notation path (e.g., "database.connection.timeout")
    .PARAMETER ConfigName
        Name of the configuration
    .PARAMETER Path
        Dot notation path to the value
    .PARAMETER DefaultValue
        Default value if path not found
    .EXAMPLE
        Get-ConfigurationValue -ConfigName "ProcessConfig" -Path "cleanup.modes.conservative" -DefaultValue @{}
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigName,
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [object]$DefaultValue = $null
    )
    
    try {
        # Check if configuration exists
        if (-not $Global:ConfigManager.Configurations.ContainsKey($ConfigName)) {
            Write-LogWarning "Configuration not found: $ConfigName" -Category "CONFIG"
            return $DefaultValue
        }
        
        $config = $Global:ConfigManager.Configurations[$ConfigName]
        $pathParts = $Path -split '\.'
        $currentValue = $config
        
        # Navigate through the path
        foreach ($part in $pathParts) {
            if ($currentValue -is [hashtable] -and $currentValue.ContainsKey($part)) {
                $currentValue = $currentValue[$part]
            } elseif ($currentValue -is [PSCustomObject] -and $currentValue.PSObject.Properties.Name -contains $part) {
                $currentValue = $currentValue.$part
            } else {
                Write-LogDebug "Configuration path not found: $ConfigName.$Path" -Category "CONFIG"
                return $DefaultValue
            }
        }
        
        return $currentValue
        
    } catch {
        Write-LogError "Failed to get configuration value $ConfigName.$Path`: $($_.Exception.Message)" -Category "CONFIG"
        return $DefaultValue
    }
}

# Set configuration value
function Set-ConfigurationValue {
    <#
    .SYNOPSIS
        Sets a configuration value by path
    .DESCRIPTION
        Sets configuration values using dot notation path
    .PARAMETER ConfigName
        Name of the configuration
    .PARAMETER Path
        Dot notation path to the value
    .PARAMETER Value
        Value to set
    .PARAMETER SaveToFile
        Save changes back to file
    .EXAMPLE
        Set-ConfigurationValue -ConfigName "ProcessConfig" -Path "cleanup.enabled" -Value $true -SaveToFile
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigName,
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [object]$Value,
        [switch]$SaveToFile
    )
    
    try {
        # Check if configuration exists
        if (-not $Global:ConfigManager.Configurations.ContainsKey($ConfigName)) {
            Write-LogError "Configuration not found: $ConfigName" -Category "CONFIG"
            return $false
        }
        
        $config = $Global:ConfigManager.Configurations[$ConfigName]
        $pathParts = $Path -split '\.'
        $currentValue = $config
        
        # Navigate to parent of target value
        for ($i = 0; $i -lt ($pathParts.Length - 1); $i++) {
            $part = $pathParts[$i]
            if ($currentValue -is [hashtable]) {
                if (-not $currentValue.ContainsKey($part)) {
                    $currentValue[$part] = @{}
                }
                $currentValue = $currentValue[$part]
            } else {
                Write-LogError "Cannot set value at path: $ConfigName.$Path" -Category "CONFIG"
                return $false
            }
        }
        
        # Set the final value
        $finalKey = $pathParts[-1]
        if ($currentValue -is [hashtable]) {
            $currentValue[$finalKey] = $Value
        } else {
            Write-LogError "Cannot set value at path: $ConfigName.$Path" -Category "CONFIG"
            return $false
        }
        
        # Save to file if requested
        if ($SaveToFile) {
            Save-Configuration -Name $ConfigName
        }
        
        Write-LogDebug "Configuration value set: $ConfigName.$Path" -Category "CONFIG"
        return $true
        
    } catch {
        Write-LogError "Failed to set configuration value $ConfigName.$Path`: $($_.Exception.Message)" -Category "CONFIG"
        return $false
    }
}

# Save configuration to file
function Save-Configuration {
    <#
    .SYNOPSIS
        Saves configuration back to file
    .DESCRIPTION
        Writes configuration data back to its source file
    .PARAMETER Name
        Configuration name to save
    .EXAMPLE
        Save-Configuration -Name "ProcessConfig"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    try {
        # Check if configuration and file path exist
        if (-not $Global:ConfigManager.Configurations.ContainsKey($Name)) {
            Write-LogError "Configuration not found: $Name" -Category "CONFIG"
            return $false
        }
        
        if (-not $Global:ConfigManager.ConfigFiles.ContainsKey($Name)) {
            Write-LogError "Configuration file path not found: $Name" -Category "CONFIG"
            return $false
        }
        
        $configData = $Global:ConfigManager.Configurations[$Name]
        $filePath = $Global:ConfigManager.ConfigFiles[$Name]
        
        # Convert to JSON and save
        $jsonContent = $configData | ConvertTo-Json -Depth 10
        Set-Content -Path $filePath -Value $jsonContent -Encoding UTF8
        
        Write-LogSuccess "Configuration saved: $Name" -Category "CONFIG"
        return $true
        
    } catch {
        Write-LogError "Failed to save configuration $Name`: $($_.Exception.Message)" -Category "CONFIG"
        return $false
    }
}

# Validate configuration data
function Test-ConfigurationValidation {
    <#
    .SYNOPSIS
        Validates configuration data against schema
    .DESCRIPTION
        Performs validation checks on configuration data
    .PARAMETER Name
        Configuration name
    .PARAMETER Data
        Configuration data to validate
    .EXAMPLE
        Test-ConfigurationValidation -Name "ProcessConfig" -Data $configData
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [object]$Data
    )
    
    try {
        Write-LogDebug "Validating configuration: $Name" -Category "CONFIG"
        
        # Basic validation - check if data is not null/empty
        if ($null -eq $Data) {
            Write-LogError "Configuration data is null: $Name" -Category "CONFIG"
            return $false
        }
        
        # Additional validation can be added here based on schema
        # For now, we'll do basic structural validation
        
        Write-LogDebug "Configuration validation passed: $Name" -Category "CONFIG"
        return $true
        
    } catch {
        Write-LogError "Configuration validation error for $Name`: $($_.Exception.Message)" -Category "CONFIG"
        return $false
    }
}

# Initialize file watchers for hot reload
function Initialize-ConfigFileWatchers {
    <#
    .SYNOPSIS
        Sets up file system watchers for configuration hot reload
    .DESCRIPTION
        Creates file system watchers to automatically reload configurations when files change
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-LogInfo "Initializing configuration file watchers" -Category "CONFIG"
        
        foreach ($configName in $Global:ConfigManager.ConfigFiles.Keys) {
            $filePath = $Global:ConfigManager.ConfigFiles[$configName]
            $directory = Split-Path $filePath -Parent
            $fileName = Split-Path $filePath -Leaf
            
            # Create file system watcher
            $watcher = New-Object System.IO.FileSystemWatcher
            $watcher.Path = $directory
            $watcher.Filter = $fileName
            $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite
            $watcher.EnableRaisingEvents = $true
            
            # Register event handler
            $action = {
                $path = $Event.SourceEventArgs.FullPath
                $name = $Event.SourceEventArgs.Name
                Write-LogInfo "Configuration file changed: $name" -Category "CONFIG"
                
                # Find configuration name by file path
                foreach ($cfgName in $Global:ConfigManager.ConfigFiles.Keys) {
                    if ($Global:ConfigManager.ConfigFiles[$cfgName] -eq $path) {
                        Load-Configuration -Name $cfgName -Path $path
                        break
                    }
                }
            }
            
            Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action
            $Global:ConfigManager.FileWatchers[$configName] = $watcher
        }
        
        Write-LogSuccess "Configuration file watchers initialized" -Category "CONFIG"
        
    } catch {
        Write-LogError "Failed to initialize file watchers: $($_.Exception.Message)" -Category "CONFIG"
    }
}

#endregion

#region Convenience Functions

# Initialize configuration paths with project root
function Initialize-ConfigPaths {
    <#
    .SYNOPSIS
        Initializes configuration paths with the project root directory
    .DESCRIPTION
        Sets up the default configuration paths based on the project root
    .PARAMETER ProjectRoot
        The root directory of the project
    .EXAMPLE
        Initialize-ConfigPaths "C:\Projects\AugmentVIP"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    try {
        Write-LogDebug "Initializing configuration paths with project root: $ProjectRoot" -Category "CONFIG"

        # Update default configuration paths with project root
        $Global:DefaultConfigPaths = @{
            MainConfig = Join-Path $ProjectRoot "src\config\config.json"
            Patterns = Join-Path $ProjectRoot "src\config\patterns.json"
            ProcessConfig = Join-Path $ProjectRoot "src\config\process_config.json"
        }

        # Set the default config path for the manager
        $Global:ConfigManager.DefaultConfigPath = Join-Path $ProjectRoot "src\config"

        Write-LogDebug "Configuration paths initialized successfully" -Category "CONFIG"
        return $true

    } catch {
        Write-LogError "Failed to initialize configuration paths: $($_.Exception.Message)" -Category "CONFIG"
        return $false
    }
}

# Load Augment configuration
function Load-AugmentConfig {
    <#
    .SYNOPSIS
        Loads all Augment-specific configuration files
    .DESCRIPTION
        Loads the main configuration files needed for Augment VIP operations
    .EXAMPLE
        Load-AugmentConfig
    #>
    [CmdletBinding()]
    param()

    try {
        Write-LogDebug "Loading Augment configuration files" -Category "CONFIG"

        $success = $true

        # Load main configuration files
        foreach ($configName in $Global:DefaultConfigPaths.Keys) {
            $configPath = $Global:DefaultConfigPaths[$configName]
            if (Test-Path $configPath) {
                if (-not (Load-Configuration -Name $configName -Path $configPath)) {
                    Write-LogWarning "Failed to load configuration: $configName from $configPath" -Category "CONFIG"
                    $success = $false
                }
            } else {
                Write-LogWarning "Configuration file not found: $configPath" -Category "CONFIG"
                $success = $false
            }
        }

        if ($success) {
            Write-LogSuccess "All Augment configuration files loaded successfully" -Category "CONFIG"
        } else {
            Write-LogWarning "Some configuration files failed to load" -Category "CONFIG"
        }

        return $success

    } catch {
        Write-LogError "Failed to load Augment configuration: $($_.Exception.Message)" -Category "CONFIG"
        return $false
    }
}

# Get main configuration
function Get-MainConfig {
    [CmdletBinding()]
    param()
    return Get-ConfigurationValue -ConfigName "MainConfig" -Path "" -DefaultValue @{}
}

# Get patterns configuration
function Get-PatternsConfig {
    [CmdletBinding()]
    param()
    return Get-ConfigurationValue -ConfigName "Patterns" -Path "" -DefaultValue @{}
}

# Get database patterns
function Get-DatabasePatterns {
    [CmdletBinding()]
    param()
    return Get-ConfigurationValue -ConfigName "Patterns" -Path "database_patterns" -DefaultValue @{}
}

# Get cleanup modes
function Get-CleanupModes {
    [CmdletBinding()]
    param()
    return Get-ConfigurationValue -ConfigName "Patterns" -Path "cleanup_modes" -DefaultValue @{}
}

# Get security configuration
function Get-SecurityConfig {
    [CmdletBinding()]
    param()
    return Get-ConfigurationValue -ConfigName "MainConfig" -Path "security" -DefaultValue @{}
}

# Get process management configuration
function Get-ProcessConfig {
    [CmdletBinding()]
    param()
    return Get-ConfigurationValue -ConfigName "MainConfig" -Path "process_management" -DefaultValue @{}
}

# Get logging configuration
function Get-LoggingConfig {
    [CmdletBinding()]
    param()
    return Get-ConfigurationValue -ConfigName "MainConfig" -Path "logging" -DefaultValue @{}
}

# Get database configuration
function Get-DatabaseConfig {
    [CmdletBinding()]
    param()
    return Get-ConfigurationValue -ConfigName "MainConfig" -Path "database" -DefaultValue @{}
}

# Get telemetry configuration
function Get-TelemetryConfig {
    [CmdletBinding()]
    param()
    return Get-ConfigurationValue -ConfigName "MainConfig" -Path "telemetry" -DefaultValue @{}
}

#endregion

# Export functions for module use (only when loaded as module)
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    # Loaded via dot-sourcing, no need to export
    Write-LogDebug "ConfigurationManager loaded via dot-sourcing" -Category "CONFIG"
} else {
    # Loaded as module, export functions
    Export-ModuleMember -Function @(
        'Initialize-ConfigurationManager',
        'Load-Configuration',
        'Get-ConfigurationValue',
        'Set-ConfigurationValue',
        'Save-Configuration',
        'Test-ConfigurationValidation',
        'Initialize-ConfigPaths',
        'Load-AugmentConfig',
        'Get-MainConfig',
        'Get-PatternsConfig',
        'Get-AugmentPatterns',
        'Get-CleanupModes',
        'Get-ProcessConfig',
        'Get-SecurityConfig',
        'Get-ApplicationSettings'
    )
}

# Module initialization message
if ($VerbosePreference -eq 'Continue') {
    Write-Host "[INFO] ConfigurationManager v3.0.0 loaded successfully" -ForegroundColor Green
}
