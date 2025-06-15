# StandardImports.ps1
# Standardized import module - Provides unified core functionality imports for all tool scripts
# Version: 1.0.0
# Features: Unified logging, path discovery, database operations and other core functions

# Prevent duplicate imports
if ($Global:StandardImportsLoaded) {
    return
}
$Global:StandardImportsLoaded = $true

# Get script root directory
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path $scriptRoot -Parent

#region Core Module Imports

# Import logger module
$loggerPath = Join-Path $scriptRoot "AugmentLogger.ps1"
if (Test-Path $loggerPath) {
    . $loggerPath
    # Initialize logging system
    if (-not $Global:LoggerConfig.Initialized) {
        Initialize-AugmentLogger -LogDirectory "logs" -LogFileName "augment_tools.log" -LogLevel "INFO"
    }
    $Global:LoggerAvailable = $true
} else {
    # Fallback logging functions
    function Write-LogInfo { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor White }
    function Write-LogSuccess { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
    function Write-LogWarning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    function Write-LogError { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
    function Write-LogDebug { param([string]$Message) if ($VerbosePreference -eq 'Continue') { Write-Host "[DEBUG] $Message" -ForegroundColor Gray } }
    $Global:LoggerAvailable = $false
}

# Import common utilities module
$utilitiesPath = Join-Path $scriptRoot "utilities\common_utilities.ps1"
if (Test-Path $utilitiesPath) {
    . $utilitiesPath
    $Global:UtilitiesAvailable = $true
} else {
    # Fallback path discovery function
    function Get-StandardVSCodePaths {
        return @{
            VSCodeStandard = @(
                "$env:APPDATA\Code",
                "$env:LOCALAPPDATA\Code",
                "$env:APPDATA\Code - Insiders",
                "$env:LOCALAPPDATA\Code - Insiders"
            )
            CursorPaths = @(
                "$env:APPDATA\Cursor",
                "$env:LOCALAPPDATA\Cursor",
                "$env:APPDATA\Cursor - Insiders",
                "$env:LOCALAPPDATA\Cursor - Insiders"
            )
        }
    }
    $Global:UtilitiesAvailable = $false
}

# Import configuration management module
$configPath = Join-Path $scriptRoot "ConfigurationManager.ps1"
if (Test-Path $configPath) {
    . $configPath
    $Global:ConfigManagerAvailable = $true
} else {
    $Global:ConfigManagerAvailable = $false
}

#endregion

#region Unified Functionality Functions

# Unified VS Code installation discovery function
function Get-UnifiedVSCodeInstallations {
    <#
    .SYNOPSIS
        Unified VS Code and Cursor installation discovery function
    .DESCRIPTION
        Uses standardized path discovery logic to return installation information in unified format
    .OUTPUTS
        [array] Array of installation information
    .EXAMPLE
        $installations = Get-UnifiedVSCodeInstallations
    #>
    [CmdletBinding()]
    param()

    Write-LogInfo "Discovering VS Code and Cursor installations..."

    $installations = @()

    # Use unified path retrieval function
    if ($Global:UtilitiesAvailable) {
        $paths = Get-StandardVSCodePaths
        $allPaths = $paths.VSCodeStandard + $paths.CursorPaths
    } else {
        # Fallback path list
        $allPaths = @(
            "$env:APPDATA\Code",
            "$env:APPDATA\Cursor",
            "$env:APPDATA\Code - Insiders",
            "$env:APPDATA\Code - Exploration",
            "$env:LOCALAPPDATA\Code",
            "$env:LOCALAPPDATA\Cursor",
            "$env:LOCALAPPDATA\Code - Insiders",
            "$env:LOCALAPPDATA\VSCodium"
        )
    }

    foreach ($path in $allPaths) {
        if (Test-Path $path) {
            Write-LogInfo "Found installation: $path"

            $installation = @{
                Path = $path
                Type = Split-Path $path -Leaf
                StorageFiles = @()
                DatabaseFiles = @()
                WorkspaceFiles = @()
            }

            # Find storage files
            $storagePatterns = @(
                "$path\User\storage.json",
                "$path\User\globalStorage\storage.json"
            )

            foreach ($pattern in $storagePatterns) {
                if (Test-Path $pattern) {
                    $installation.StorageFiles += $pattern
                    Write-LogDebug "Found storage file: $pattern"
                }
            }

            # Find database files
            $dbPatterns = @(
                "$path\User\globalStorage\state.vscdb",
                "$path\User\workspaceStorage\*\state.vscdb"
            )

            foreach ($dbPattern in $dbPatterns) {
                $dbFiles = Get-ChildItem -Path $dbPattern -ErrorAction SilentlyContinue
                foreach ($dbFile in $dbFiles) {
                    $installation.DatabaseFiles += $dbFile.FullName
                    Write-LogDebug "Found database file: $($dbFile.FullName)"
                }
            }

            # Find workspace files
            $workspacePattern = "$path\User\workspaceStorage\*\workspace.json"
            $workspaceFiles = Get-ChildItem -Path $workspacePattern -ErrorAction SilentlyContinue
            foreach ($file in $workspaceFiles) {
                $installation.WorkspaceFiles += $file.FullName
                Write-LogDebug "Found workspace file: $($file.FullName)"
            }

            if ($installation.StorageFiles.Count -gt 0 -or $installation.DatabaseFiles.Count -gt 0 -or $installation.WorkspaceFiles.Count -gt 0) {
                $installations += $installation
            }
        }
    }

    Write-LogInfo "Total installations found: $($installations.Count)"
    return $installations
}

# Unified SQLite query function
function Invoke-UnifiedSQLiteQuery {
    <#
    .SYNOPSIS
        Unified SQLite query execution function
    .DESCRIPTION
        Standardized SQLite query execution with error handling and logging
    .PARAMETER DatabasePath
        Database file path
    .PARAMETER Query
        SQL query to execute
    .PARAMETER ReturnOutput
        Whether to return query output
    .OUTPUTS
        [object] Query results or execution status
    .EXAMPLE
        $result = Invoke-UnifiedSQLiteQuery -DatabasePath $dbPath -Query $sql -ReturnOutput
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,

        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $false)]
        [switch]$ReturnOutput
    )

    try {
        Write-LogDebug "Executing SQLite query on: $DatabasePath"
        Write-LogDebug "Query: $Query"

        if ($ReturnOutput) {
            $result = & sqlite3 $DatabasePath $Query 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-LogDebug "Query executed successfully, returned $($result.Count) rows"
                return $result
            } else {
                Write-LogWarning "Query execution failed with exit code: $LASTEXITCODE"
                return $null
            }
        } else {
            & sqlite3 $DatabasePath $Query 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-LogDebug "Query executed successfully"
                return $true
            } else {
                Write-LogWarning "Query execution failed with exit code: $LASTEXITCODE"
                return $false
            }
        }
    } catch {
        Write-LogError "SQLite query exception: $($_.Exception.Message)"
        return if ($ReturnOutput) { $null } else { $false }
    }
}

#endregion

#region Export Information

# Record import status
Write-LogInfo "Standard imports loaded successfully"
Write-LogDebug "Logger available: $Global:LoggerAvailable"
Write-LogDebug "Utilities available: $Global:UtilitiesAvailable"
Write-LogDebug "Config manager available: $Global:ConfigManagerAvailable"

#endregion
