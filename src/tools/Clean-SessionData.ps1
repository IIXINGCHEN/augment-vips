# Clean-SessionData.ps1
# Encrypted Session Data Deep Cleaner
# Deep cleaning of all encrypted session data and authentication tokens
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
    Initialize-AugmentLogger -LogDirectory "logs" -LogFileName "session_data_cleanup.log" -LogLevel "INFO"
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

#region Session Data Patterns

function Get-EncryptedSessionPatterns {
    <#
    .SYNOPSIS
        Gets patterns for encrypted session data identification
    .DESCRIPTION
        Returns array of patterns used to identify encrypted session and authentication data
    #>
    return @(
        # Critical encrypted session patterns
        "secret://%augment%",
        "secret://%vscode-augment%",
        "secret://%sessions%",
        "secret://%authentication%",
        "secret://%auth%",
        "secret://%token%",
        
        # Augment session specific patterns
        "%augment.sessions%",
        "%extensionId%augment%",
        "%key%augment%",
        "%key%sessions%",
        
        # Authentication and token patterns
        "%authToken%",
        "%accessToken%",
        "%refreshToken%",
        "%sessionToken%",
        "%bearerToken%",
        
        # Extension authentication patterns
        "%vscode.authentication%",
        "%ms-vscode.vscode-account%",
        "%github.vscode-pull-request-github%",
        
        # Augment specific authentication
        "%augment.auth%",
        "%augment.token%",
        "%augment.session%",
        "%augment.credential%"
    )
}

function Get-SessionDataQuery {
    <#
    .SYNOPSIS
        Generates SQL query to find session data
    .DESCRIPTION
        Creates a SELECT query to identify session-related entries
    #>
    $patterns = Get-EncryptedSessionPatterns
    $conditions = @()
    
    foreach ($pattern in $patterns) {
        $conditions += "key LIKE '$pattern'"
    }
    
    $whereClause = $conditions -join " OR`n    "
    
    return @"
SELECT key, length(value) as data_length FROM ItemTable WHERE
    $whereClause;
"@
}

function Get-SessionCleaningQuery {
    <#
    .SYNOPSIS
        Generates SQL query to delete session data
    .DESCRIPTION
        Creates a DELETE query to remove session-related entries
    #>
    $patterns = Get-EncryptedSessionPatterns
    $conditions = @()
    
    foreach ($pattern in $patterns) {
        $conditions += "key LIKE '$pattern'"
    }
    
    $whereClause = $conditions -join " OR`n    "
    
    return @"
DELETE FROM ItemTable WHERE
    $whereClause;
"@
}

#endregion

#region Core Functions

function Test-SessionData {
    <#
    .SYNOPSIS
        Analyzes session data in a database
    .DESCRIPTION
        Scans database for session-related data and returns analysis
    .PARAMETER DatabasePath
        Path to the SQLite database file
    .EXAMPLE
        Test-SessionData -DatabasePath "C:\path\to\state.vscdb"
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
        Write-LogDebug "Analyzing session data in: $DatabasePath"
        
        $analysisQuery = Get-SessionDataQuery
        $result = & sqlite3 $DatabasePath $analysisQuery 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $result) {
            $sessionData = @()
            foreach ($line in $result) {
                if ($line -and $line.Contains("|")) {
                    $parts = $line.Split("|", 2)
                    $sessionData += @{
                        Key = $parts[0]
                        DataLength = [int]$parts[1]
                        Database = $DatabasePath
                    }
                }
            }
            return $sessionData
        }
        
        return @()
    } catch {
        Write-LogWarning "Failed to analyze session data in $DatabasePath`: $($_.Exception.Message)"
        return @()
    }
}

function Remove-DatabaseSessionData {
    <#
    .SYNOPSIS
        Removes session data from a specific database
    .DESCRIPTION
        Removes session-related entries from SQLite database
    .PARAMETER DatabasePath
        Path to the SQLite database file
    .EXAMPLE
        Remove-DatabaseSessionData -DatabasePath "C:\path\to\state.vscdb"
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
        Write-LogInfo "Cleaning session data from: $DatabasePath"
        
        # First, analyze what we're about to remove
        $sessionData = Test-SessionData -DatabasePath $DatabasePath
        if ($sessionData.Count -gt 0) {
            Write-LogInfo "Found $($sessionData.Count) encrypted session entries:"
            foreach ($data in $sessionData) {
                Write-LogDebug "  - $($data.Key) ($($data.DataLength) bytes)"
            }
        } else {
            Write-LogInfo "No encrypted session data found in database"
            return $true
        }
        
        if ($DryRun) {
            Write-LogInfo "DRY RUN: Would remove $($sessionData.Count) session entries from $DatabasePath"
            return $true
        }
        
        # Execute cleaning query
        $cleaningQuery = Get-SessionCleaningQuery
        & sqlite3 $DatabasePath $cleaningQuery
        
        if ($LASTEXITCODE -eq 0) {
            # Get count of changes
            $changesCount = & sqlite3 $DatabasePath "SELECT changes();"
            
            # Run VACUUM to reclaim space
            & sqlite3 $DatabasePath "VACUUM;"
            
            Write-LogSuccess "Removed $changesCount encrypted session entries from: $DatabasePath"
            return $true
        } else {
            Write-LogError "Failed to clean session data from: $DatabasePath"
            return $false
        }
        
    } catch {
        Write-LogError "Exception cleaning session data from $DatabasePath`: $($_.Exception.Message)"
        return $false
    }
}

function Remove-ExtensionStorage {
    <#
    .SYNOPSIS
        Cleans Augment extension storage
    .DESCRIPTION
        Removes Augment-related extension storage files and directories
    .PARAMETER InstallationPath
        Path to VS Code installation directory
    .EXAMPLE
        Remove-ExtensionStorage -InstallationPath "C:\Users\User\AppData\Roaming\Code"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallationPath
    )
    
    Write-LogInfo "Cleaning extension storage in: $InstallationPath"
    
    # Clean global storage for Augment extension
    $globalStoragePaths = @(
        "$InstallationPath\User\globalStorage\augment.vscode-augment",
        "$InstallationPath\User\globalStorage\augment.augment-chat",
        "$InstallationPath\User\globalStorage\augment.augment-panel"
    )
    
    $cleanedCount = 0
    
    foreach ($path in $globalStoragePaths) {
        if (Test-Path $path) {
            try {
                if ($DryRun) {
                    Write-LogInfo "DRY RUN: Would remove extension storage: $path"
                } else {
                    Remove-Item $path -Recurse -Force
                    Write-LogSuccess "Removed extension storage: $path"
                }
                $cleanedCount++
            } catch {
                Write-LogError "Failed to remove extension storage $path`: $($_.Exception.Message)"
            }
        }
    }
    
    # Clean workspace storage for current project
    $workspaceStoragePath = "$InstallationPath\User\workspaceStorage"
    if (Test-Path $workspaceStoragePath) {
        $workspaceDirs = Get-ChildItem $workspaceStoragePath -Directory
        foreach ($dir in $workspaceDirs) {
            $augmentFiles = Get-ChildItem $dir.FullName -Filter "*augment*" -Recurse -ErrorAction SilentlyContinue
            foreach ($file in $augmentFiles) {
                try {
                    if ($DryRun) {
                        Write-LogInfo "DRY RUN: Would remove workspace file: $($file.FullName)"
                    } else {
                        Remove-Item $file.FullName -Force
                        Write-LogSuccess "Removed workspace file: $($file.FullName)"
                    }
                    $cleanedCount++
                } catch {
                    Write-LogError "Failed to remove workspace file $($file.FullName)`: $($_.Exception.Message)"
                }
            }
        }
    }
    
    return $cleanedCount
}

function Get-VSCodeInstallations {
    <#
    .SYNOPSIS
        Discovers VS Code and related editor installations (统一版本)
    .DESCRIPTION
        使用统一的路径发现逻辑，返回标准格式的安装信息
    .EXAMPLE
        Get-VSCodeInstallations
    #>
    [CmdletBinding()]
    param()

    # 使用统一的安装发现函数
    if (Get-Command Get-UnifiedVSCodeInstallations -ErrorAction SilentlyContinue) {
        Write-LogDebug "使用统一安装发现函数"
        return Get-UnifiedVSCodeInstallations
    } else {
        # 回退实现（保持兼容性）
        Write-LogWarning "统一安装发现函数不可用，使用回退实现"

        $installations = @()

        # 使用统一路径获取函数
        if ($Global:UtilitiesAvailable -and (Get-Command Get-StandardVSCodePaths -ErrorAction SilentlyContinue)) {
            $pathInfo = Get-StandardVSCodePaths
            $searchPaths = $pathInfo.VSCodeStandard + $pathInfo.CursorPaths
        } else {
            # 最终回退路径列表
            $searchPaths = @(
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

function Start-SessionDataCleanup {
    <#
    .SYNOPSIS
        Main function to clean session data
    .DESCRIPTION
        Orchestrates the complete session data cleanup process
    .EXAMPLE
        Start-SessionDataCleanup
    #>
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Starting Encrypted Session Data Deep Cleaning..."
    
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
    $totalSessionsRemoved = 0
    
    foreach ($installation in $installations) {
        Write-LogInfo "Processing installation: $($installation.Type) at $($installation.Path)"
        
        # Clean database session data
        foreach ($dbPath in $installation.DatabasePaths) {
            $dbFiles = Get-ChildItem -Path $dbPath -ErrorAction SilentlyContinue
            foreach ($dbFile in $dbFiles) {
                if (Remove-DatabaseSessionData -DatabasePath $dbFile.FullName) {
                    $totalCleaned++
                } else {
                    $totalErrors++
                }
            }
        }
        
        # Clean extension storage
        $storageCleanedCount = Remove-ExtensionStorage -InstallationPath $installation.Path
        $totalSessionsRemoved += $storageCleanedCount
    }
    
    Write-LogSuccess "Encrypted session data cleaning completed."
    Write-LogInfo "Databases cleaned: $totalCleaned, Storage items removed: $totalSessionsRemoved, Errors: $totalErrors"
    
    if ($totalErrors -eq 0) {
        Write-LogSuccess "All encrypted session data successfully removed!"
        Write-LogInfo "Authentication tokens and session data cleared - login state reset."
        return $true
    } else {
        Write-LogWarning "Some errors occurred during session data cleaning."
        return $false
    }
}

#endregion

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    Start-SessionDataCleanup
}
