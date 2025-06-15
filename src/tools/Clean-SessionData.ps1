# Clean-SessionData.ps1
# Encrypted Session Data Deep Cleaner
# Deep cleaning of all encrypted session data and authentication tokens
# Version: 3.0.0 - Standardized and optimized

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("clean", "help")]
    [string]$Operation = "clean",

    [switch]$DryRun = $false,
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
    function Write-LogDebug { param([string]$Message) if ($VerbosePreference -eq 'Continue') { Write-Host "[DEBUG] $Message" -ForegroundColor Gray } }
}

# Set error handling
$ErrorActionPreference = "Stop"

#region Session Data Patterns
function Get-EncryptedSessionPatterns {
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
#endregion

function Remove-ExtensionStorage {
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
}

function Start-SessionDataCleanup {
    [CmdletBinding()]
    param()

    Write-LogInfo "Starting encrypted session data cleanup"
    Write-LogInfo "Operation Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE EXECUTION' })"

    # Check for SQLite3
    try {
        $null = & sqlite3 -version
        Write-LogInfo "SQLite3 found and ready"
    } catch {
        Write-LogError "SQLite3 is required but not found in PATH. Please install SQLite3."
        return $false
    }

    # Get installations
    $installations = Get-VSCodeInstallations

    if ($installations.Count -eq 0) {
        Write-LogWarning "No VS Code/Cursor installations found"
        return $true
    }

    Write-LogInfo "Found $($installations.Count) installation(s) to process"

    $overallSuccess = $true
    $totalCleaned = 0

    foreach ($installation in $installations) {
        Write-LogInfo "Processing: $($installation.Type) at $($installation.Path)"

        # Clean databases
        foreach ($dbPattern in $installation.DatabasePaths) {
            $dbFiles = Get-ChildItem $dbPattern -ErrorAction SilentlyContinue
            foreach ($dbFile in $dbFiles) {
                $success = Remove-DatabaseSessionData -DatabasePath $dbFile.FullName
                $overallSuccess = $overallSuccess -and $success
            }
        }

        # Clean extension storage
        $cleanedCount = Remove-ExtensionStorage -InstallationPath $installation.Path
        $totalCleaned += $cleanedCount

        Write-LogSuccess "Completed processing: $($installation.Type)"
    }

    Write-LogInfo "Session data cleanup completed"
    Write-LogInfo "Total items cleaned: $totalCleaned"
    Write-LogInfo "Overall success: $(if ($overallSuccess) { 'YES' } else { 'NO' })"

    if (-not $DryRun) {
        Write-LogInfo "IMPORTANT: Please restart all VS Code/Cursor instances to apply changes"
    }

    return $overallSuccess
}

#region Help and Utility Functions
function Show-SessionDataCleanupHelp {
    Write-Host @"
Clean Session Data v3.0.0 - Encrypted Session Data Deep Cleaner

USAGE:
    .\Clean-SessionData.ps1 [options]

OPERATIONS:
    clean       Clean session data (default)
    help        Show this help message

OPTIONS:
    -DryRun             Preview operations without making changes
    -Force              Force operation without user confirmation
    -Verbose            Enable detailed logging

EXAMPLES:
    .\Clean-SessionData.ps1 -DryRun -Verbose
    .\Clean-SessionData.ps1 -Force
    .\Clean-SessionData.ps1

PURPOSE:
    Deep cleaning of all encrypted session data and authentication tokens.
    Removes session-related entries from SQLite databases and extension storage.
"@
}
#endregion

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    switch ($Operation) {
        "clean" {
            $result = Start-SessionDataCleanup
            if ($result) {
                exit 0
            } else {
                exit 1
            }
        }
        "help" {
            Show-SessionDataCleanupHelp
            exit 0
        }
        default {
            Write-LogError "Unknown operation: $Operation"
            Show-SessionDataCleanupHelp
            exit 1
        }
    }
}