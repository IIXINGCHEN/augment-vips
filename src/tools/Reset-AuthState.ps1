# Reset-AuthState.ps1
# Authentication State Complete Reset Tool
# Completely resets all Augment authentication states and user session data
# Version: 3.0.0 - Standardized and optimized

[CmdletBinding()]
param(
    [switch]$DryRun = $false,
    [switch]$VerboseOutput = $false,
    [switch]$Force = $false
)

# Import dependencies
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreModulesPath = Split-Path $scriptPath -Parent | Join-Path -ChildPath "core"
$loggerPath = Join-Path $coreModulesPath "AugmentLogger.ps1"

if (Test-Path $loggerPath) {
    . $loggerPath
    Initialize-AugmentLogger -LogDirectory "logs" -LogFileName "auth_reset.log" -LogLevel "INFO"
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

#region Authentication State Patterns

function Get-AuthStatePatterns {
    <#
    .SYNOPSIS
        Gets authentication state patterns for identification
    .DESCRIPTION
        Returns array of patterns used to identify authentication-related data
    #>
    return @(
        # Core Augment authentication state
        "Augment.vscode-augment",
        
        # Action system states
        "%actionSystemStates%",
        "%actionStates%",
        "%systemStates%",
        
        # Authentication status patterns
        "%authenticated%",
        "%syncingPermitted%",
        "%disabledGithubCopilot%",
        "%hasMovedExtensionAside%",
        "%workspacePopulated%",
        "%workspaceSelected%",
        "%disabledCodeium%",
        "%uploadingHomeDir%",
        "%workspaceTooLarge%",
        
        # Agent and sidecar states
        "%sidecar.agent.%",
        "%hasEverUsedAgent%",
        "%hasEverUsedRemoteAgent%",
        "%agentAutoModeApproved%",
        "%lastRemoteAgentSetupScript%",
        "%chat-mode%",
        
        # Extension version tracking
        "%lastEnabledExtensionVersion%",
        "%extensionVersion%",
        
        # User preferences and settings
        "%userPreferences%",
        "%userSettings%",
        "%augment.preferences%",
        "%augment.settings%",
        
        # Trial and subscription states
        "%trialState%",
        "%subscriptionState%",
        "%licenseState%",
        "%usageState%",
        
        # Session and login states
        "%loginState%",
        "%sessionState%",
        "%authState%",
        "%userState%"
    )
}

function Get-AuthStateQuery {
    <#
    .SYNOPSIS
        Generates SQL query to find authentication state data
    .DESCRIPTION
        Creates a SELECT query to identify authentication-related entries
    #>
    $patterns = Get-AuthStatePatterns
    $conditions = @()
    
    foreach ($pattern in $patterns) {
        $conditions += "key LIKE '$pattern'"
    }
    
    # Add exact matches for critical keys
    $exactMatches = @(
        "key = 'Augment.vscode-augment'"
    )
    
    $allConditions = $conditions + $exactMatches
    $whereClause = $allConditions -join " OR`n    "
    
    return @"
SELECT key, substr(value, 1, 200) as value_preview FROM ItemTable WHERE
    $whereClause;
"@
}

function Get-AuthCleaningQuery {
    <#
    .SYNOPSIS
        Generates SQL query to delete authentication state data
    .DESCRIPTION
        Creates a DELETE query to remove authentication-related entries
    #>
    $patterns = Get-AuthStatePatterns
    $conditions = @()
    
    foreach ($pattern in $patterns) {
        $conditions += "key LIKE '$pattern'"
    }
    
    # Add exact matches for critical keys
    $exactMatches = @(
        "key = 'Augment.vscode-augment'"
    )
    
    $allConditions = $conditions + $exactMatches
    $whereClause = $allConditions -join " OR`n    "
    
    return @"
DELETE FROM ItemTable WHERE
    $whereClause;
"@
}

#endregion

#region Core Functions

function Test-AuthState {
    <#
    .SYNOPSIS
        Analyzes authentication state in a database
    .DESCRIPTION
        Scans database for authentication-related data and returns analysis
    .PARAMETER DatabasePath
        Path to the SQLite database file
    .EXAMPLE
        Test-AuthState -DatabasePath "C:\Users\User\AppData\Roaming\Code\User\globalStorage\state.vscdb"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath
    )
    
    if (-not (Test-Path $DatabasePath)) {
        return @()
    }
    
    try {
        Write-LogDebug "Analyzing auth state in: $DatabasePath"
        
        $analysisQuery = Get-AuthStateQuery
        $result = & sqlite3 $DatabasePath $analysisQuery 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $result) {
            $authData = @()
            foreach ($line in $result) {
                if ($line -and $line.Contains("|")) {
                    $parts = $line.Split("|", 2)
                    $authData += @{
                        Key = $parts[0]
                        ValuePreview = if ($parts.Length -gt 1) { $parts[1] } else { "" }
                        Database = $DatabasePath
                    }
                }
            }
            return $authData
        }
        
        return @()
    } catch {
        Write-LogWarning "Failed to analyze auth state in $DatabasePath`: $($_.Exception.Message)"
        return @()
    }
}

function Reset-DatabaseAuthState {
    <#
    .SYNOPSIS
        Resets authentication state in a specific database
    .DESCRIPTION
        Removes authentication-related entries from SQLite database
    .PARAMETER DatabasePath
        Path to the SQLite database file
    .EXAMPLE
        Reset-DatabaseAuthState -DatabasePath "C:\path\to\state.vscdb"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath
    )
    
    if (-not (Test-Path $DatabasePath)) {
        Write-LogWarning "Database not found: $DatabasePath"
        return $false
    }
    
    try {
        Write-LogInfo "Resetting auth state in: $DatabasePath"
        
        # First, analyze what we're about to remove
        $authData = Test-AuthState -DatabasePath $DatabasePath
        if ($authData.Count -gt 0) {
            Write-LogInfo "Found $($authData.Count) authentication state entries:"
            foreach ($data in $authData) {
                $preview = if ($data.ValuePreview.Length -gt 50) { 
                    $data.ValuePreview.Substring(0, 50) + "..." 
                } else { 
                    $data.ValuePreview 
                }
                Write-LogDebug "  - $($data.Key): $preview"
            }
            
            # Special handling for critical Augment state
            $augmentState = $authData | Where-Object { $_.Key -eq "Augment.vscode-augment" }
            if ($augmentState) {
                Write-LogWarning "Found critical Augment state data - this contains session ID and trial tracking!"
                Write-LogDebug "Augment state preview: $($augmentState.ValuePreview)"
            }
        } else {
            Write-LogInfo "No authentication state data found in database"
            return $true
        }
        
        if ($DryRun) {
            Write-LogInfo "DRY RUN: Would remove $($authData.Count) auth state entries from $DatabasePath"
            return $true
        }
        
        # Execute cleaning query
        $cleaningQuery = Get-AuthCleaningQuery
        & sqlite3 $DatabasePath $cleaningQuery
        
        if ($LASTEXITCODE -eq 0) {
            # Get count of changes
            $changesCount = & sqlite3 $DatabasePath "SELECT changes();"
            
            # Run VACUUM to reclaim space
            & sqlite3 $DatabasePath "VACUUM;"
            
            Write-LogSuccess "Removed $changesCount authentication state entries from: $DatabasePath"
            return $true
        } else {
            Write-LogError "Failed to reset auth state in: $DatabasePath"
            return $false
        }
        
    } catch {
        Write-LogError "Exception resetting auth state in $DatabasePath`: $($_.Exception.Message)"
        return $false
    }
}

function Reset-ExtensionPreferences {
    <#
    .SYNOPSIS
        Resets Augment-related extension preferences
    .DESCRIPTION
        Removes Augment-related settings and keybindings from VS Code configuration
    .PARAMETER InstallationPath
        Path to VS Code installation directory
    .EXAMPLE
        Reset-ExtensionPreferences -InstallationPath "C:\Users\User\AppData\Roaming\Code"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallationPath
    )
    
    Write-LogInfo "Resetting extension preferences in: $InstallationPath"
    
    # Reset user settings related to Augment
    $settingsPath = Join-Path $InstallationPath "User\settings.json"
    if (Test-Path $settingsPath) {
        try {
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            
            # Remove Augment-related settings
            $augmentSettings = $settings.PSObject.Properties.Name | Where-Object { $_ -match "augment" }
            $removedCount = 0
            
            foreach ($setting in $augmentSettings) {
                if ($DryRun) {
                    Write-LogInfo "DRY RUN: Would remove setting: $setting"
                } else {
                    $settings.PSObject.Properties.Remove($setting)
                    Write-LogDebug "Removed setting: $setting"
                }
                $removedCount++
            }
            
            if ($removedCount -gt 0 -and -not $DryRun) {
                $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
                Write-LogSuccess "Removed $removedCount Augment settings from: $settingsPath"
            }
            
        } catch {
            Write-LogWarning "Failed to reset settings in $settingsPath`: $($_.Exception.Message)"
        }
    }
    
    # Reset keybindings related to Augment
    $keybindingsPath = Join-Path $InstallationPath "User\keybindings.json"
    if (Test-Path $keybindingsPath) {
        try {
            $keybindings = Get-Content $keybindingsPath -Raw | ConvertFrom-Json
            
            if ($keybindings -is [array]) {
                $originalCount = $keybindings.Count
                $keybindings = $keybindings | Where-Object { 
                    $_.command -notmatch "augment" -and $_.when -notmatch "augment" 
                }
                $removedCount = $originalCount - $keybindings.Count
                
                if ($removedCount -gt 0) {
                    if ($DryRun) {
                        Write-LogInfo "DRY RUN: Would remove $removedCount Augment keybindings"
                    } else {
                        $keybindings | ConvertTo-Json -Depth 10 | Set-Content $keybindingsPath -Encoding UTF8
                        Write-LogSuccess "Removed $removedCount Augment keybindings from: $keybindingsPath"
                    }
                }
            }
            
        } catch {
            Write-LogWarning "Failed to reset keybindings in $keybindingsPath`: $($_.Exception.Message)"
        }
    }
}

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

function Start-AuthStateReset {
    <#
    .SYNOPSIS
        Main function to reset authentication states
    .DESCRIPTION
        Orchestrates the complete authentication state reset process
    .EXAMPLE
        Start-AuthStateReset
    #>
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Starting Authentication State Complete Reset..."
    
    # Check for SQLite3
    try {
        $null = & sqlite3 -version
    } catch {
        Write-LogError "SQLite3 is required but not found in PATH. Please install SQLite3."
        return $false
    }
    
    # Get VS Code installations
    $installations = Get-VSCodeInstallations
    if ($installations.Count -eq 0) {
        Write-LogWarning "No VS Code installations found"
        return $false
    }
    
    $totalCleaned = 0
    $totalErrors = 0
    
    foreach ($installation in $installations) {
        Write-LogInfo "Processing installation: $($installation.Type) at $($installation.Path)"
        
        # Reset database auth states
        foreach ($dbPath in $installation.DatabasePaths) {
            $dbFiles = Get-ChildItem -Path $dbPath -ErrorAction SilentlyContinue
            foreach ($dbFile in $dbFiles) {
                if (Reset-DatabaseAuthState -DatabasePath $dbFile.FullName) {
                    $totalCleaned++
                } else {
                    $totalErrors++
                }
            }
        }
        
        # Reset extension preferences
        Reset-ExtensionPreferences -InstallationPath $installation.Path
    }
    
    Write-LogSuccess "Authentication state reset completed."
    Write-LogInfo "Databases processed: $totalCleaned, Errors: $totalErrors"
    
    if ($totalErrors -eq 0) {
        Write-LogSuccess "All authentication states successfully reset!"
        Write-LogInfo "User session data cleared - Augment will see this as a new user."
        return $true
    } else {
        Write-LogWarning "Some errors occurred during authentication state reset."
        return $false
    }
}

#endregion

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    Start-AuthStateReset
}
