# Clean-WorkspaceBinding.ps1
# Workspace Binding Data Cleaner
# Removes all workspace-specific Augment bindings and project tracking data
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
    Initialize-AugmentLogger -LogDirectory "logs" -LogFileName "workspace_binding_cleanup.log" -LogLevel "INFO"
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

#region Workspace Binding Patterns

function Get-WorkspaceBindingPatterns {
    <#
    .SYNOPSIS
        Gets patterns for workspace binding data identification
    .DESCRIPTION
        Returns array of patterns used to identify workspace-related data
    #>
    return @(
        # Workspace message states
        "%workspaceMessageStates%",
        "%workspaceStates%",
        "%messageStates%",
        
        # Workspace summary and tracking
        "%workspaceSummary%",
        "%workspaceTracking%",
        "%workspaceData%",
        "%workspaceInfo%",
        
        # Folder and project bindings
        "%folderRoot%",
        "%projectRoot%",
        "%workspaceRoot%",
        "%folderUri%",
        "%projectUri%",
        
        # Workspace-specific Augment data
        "%workspace.augment%",
        "%augment.workspace%",
        "%workbench.workspace.augment%",
        
        # Project-specific states
        "%projectStates%",
        "%projectData%",
        "%projectInfo%",
        "%projectTracking%",
        
        # Recent workspaces and folders
        "%recentWorkspaces%",
        "%recentFolders%",
        "%recentProjects%",
        
        # Workspace storage references
        "%workspaceStorage%",
        "%globalStorage%workspace%",
        
        # Backup workspace references
        "%backupWorkspaces%",
        "%workspaceBackup%",
        
        # Profile associations with workspaces
        "%profileAssociations%",
        "%workspaceProfiles%"
    )
}

function Get-WorkspaceDataQuery {
    <#
    .SYNOPSIS
        Generates SQL query to find workspace data
    .DESCRIPTION
        Creates a SELECT query to identify workspace-related entries
    #>
    $patterns = Get-WorkspaceBindingPatterns
    $conditions = @()
    
    foreach ($pattern in $patterns) {
        $conditions += "key LIKE '$pattern'"
    }
    
    # Add value-based searches for current project path
    $currentPath = (Get-Location).Path.Replace("\", "\\")
    $conditions += "value LIKE '%$currentPath%'"
    $conditions += "value LIKE '%augment-vips%'"
    $conditions += "value LIKE '%SRC%'"
    
    $whereClause = $conditions -join " OR`n    "
    
    return @"
SELECT key, substr(value, 1, 200) as value_preview FROM ItemTable WHERE
    $whereClause;
"@
}

function Get-WorkspaceCleaningQuery {
    <#
    .SYNOPSIS
        Generates SQL query to delete workspace data
    .DESCRIPTION
        Creates a DELETE query to remove workspace-related entries
    #>
    $patterns = Get-WorkspaceBindingPatterns
    $conditions = @()
    
    foreach ($pattern in $patterns) {
        $conditions += "key LIKE '$pattern'"
    }
    
    # Add value-based cleaning for current project path
    $currentPath = (Get-Location).Path.Replace("\", "\\")
    $conditions += "value LIKE '%$currentPath%'"
    $conditions += "value LIKE '%augment-vips%'"
    $conditions += "value LIKE '%SRC%'"
    
    $whereClause = $conditions -join " OR`n    "
    
    return @"
DELETE FROM ItemTable WHERE
    $whereClause;
"@
}

#endregion

#region Core Functions

function Test-WorkspaceBindings {
    <#
    .SYNOPSIS
        Analyzes workspace bindings in a database
    .DESCRIPTION
        Scans database for workspace-related data and returns analysis
    .PARAMETER DatabasePath
        Path to the SQLite database file
    .EXAMPLE
        Test-WorkspaceBindings -DatabasePath "C:\path\to\state.vscdb"
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
        Write-LogDebug "Analyzing workspace bindings in: $DatabasePath"
        
        $analysisQuery = Get-WorkspaceDataQuery
        $result = & sqlite3 $DatabasePath $analysisQuery 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $result) {
            $workspaceData = @()
            foreach ($line in $result) {
                if ($line -and $line.Contains("|")) {
                    $parts = $line.Split("|", 2)
                    $workspaceData += @{
                        Key = $parts[0]
                        ValuePreview = if ($parts.Length -gt 1) { $parts[1] } else { "" }
                        Database = $DatabasePath
                    }
                }
            }
            return $workspaceData
        }
        
        return @()
    } catch {
        Write-LogWarning "Failed to analyze workspace bindings in $DatabasePath`: $($_.Exception.Message)"
        return @()
    }
}

function Remove-DatabaseWorkspaceBindings {
    <#
    .SYNOPSIS
        Removes workspace bindings from a specific database
    .DESCRIPTION
        Removes workspace-related entries from SQLite database
    .PARAMETER DatabasePath
        Path to the SQLite database file
    .EXAMPLE
        Remove-DatabaseWorkspaceBindings -DatabasePath "C:\path\to\state.vscdb"
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
        Write-LogInfo "Cleaning workspace bindings from: $DatabasePath"
        
        # First, analyze what we're about to remove
        $workspaceData = Test-WorkspaceBindings -DatabasePath $DatabasePath
        if ($workspaceData.Count -gt 0) {
            Write-LogInfo "Found $($workspaceData.Count) workspace binding entries:"
            foreach ($data in $workspaceData) {
                $preview = if ($data.ValuePreview.Length -gt 80) { 
                    $data.ValuePreview.Substring(0, 80) + "..." 
                } else { 
                    $data.ValuePreview 
                }
                Write-LogDebug "  - $($data.Key): $preview"
            }
            
            # Check for critical workspace message states
            $workspaceStates = $workspaceData | Where-Object { $_.Key -match "workspaceMessageStates" }
            if ($workspaceStates) {
                Write-LogWarning "Found workspace message states - this tracks project usage!"
                foreach ($state in $workspaceStates) {
                    Write-LogDebug "Workspace state: $($state.ValuePreview)"
                }
            }
        } else {
            Write-LogInfo "No workspace binding data found in database"
            return $true
        }
        
        if ($DryRun) {
            Write-LogInfo "DRY RUN: Would remove $($workspaceData.Count) workspace binding entries from $DatabasePath"
            return $true
        }
        
        # Execute cleaning query
        $cleaningQuery = Get-WorkspaceCleaningQuery
        & sqlite3 $DatabasePath $cleaningQuery
        
        if ($LASTEXITCODE -eq 0) {
            # Get count of changes
            $changesCount = & sqlite3 $DatabasePath "SELECT changes();"
            
            # Run VACUUM to reclaim space
            & sqlite3 $DatabasePath "VACUUM;"
            
            Write-LogSuccess "Removed $changesCount workspace binding entries from: $DatabasePath"
            return $true
        } else {
            Write-LogError "Failed to clean workspace bindings from: $DatabasePath"
            return $false
        }
        
    } catch {
        Write-LogError "Exception cleaning workspace bindings from $DatabasePath`: $($_.Exception.Message)"
        return $false
    }
}

function Remove-StorageWorkspaceReferences {
    <#
    .SYNOPSIS
        Cleans workspace references from storage files
    .DESCRIPTION
        Removes workspace-related references from VS Code storage files
    .PARAMETER StoragePath
        Path to the storage.json file
    .EXAMPLE
        Remove-StorageWorkspaceReferences -StoragePath "C:\path\to\storage.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StoragePath
    )
    
    if (-not (Test-Path $StoragePath)) {
        return $false
    }
    
    try {
        Write-LogInfo "Cleaning workspace references from: $StoragePath"
        
        $content = Get-Content $StoragePath -Raw | ConvertFrom-Json
        $modified = $false
        
        # Clean backup workspaces
        if ($content.PSObject.Properties.Name -contains "backupWorkspaces") {
            $backup = $content.backupWorkspaces
            
            # Clean folders array
            if ($backup.PSObject.Properties.Name -contains "folders") {
                $originalCount = $backup.folders.Count
                $backup.folders = @($backup.folders | Where-Object { 
                    $_.folderUri -notmatch "augment" -and $_.folderUri -notmatch "SRC"
                })
                
                if ($backup.folders.Count -lt $originalCount) {
                    Write-LogSuccess "Removed $($originalCount - $backup.folders.Count) folder references"
                    $modified = $true
                }
            }
        }
        
        # Clean profile associations
        if ($content.PSObject.Properties.Name -contains "profileAssociations") {
            $profiles = $content.profileAssociations
            
            if ($profiles.PSObject.Properties.Name -contains "workspaces") {
                $workspaces = $profiles.workspaces
                $workspaceKeys = $workspaces.PSObject.Properties.Name | Where-Object { 
                    $_ -match "augment" -or $_ -match "SRC" 
                }
                
                foreach ($key in $workspaceKeys) {
                    if ($DryRun) {
                        Write-LogInfo "DRY RUN: Would remove workspace profile: $key"
                    } else {
                        $workspaces.PSObject.Properties.Remove($key)
                        Write-LogSuccess "Removed workspace profile: $key"
                        $modified = $true
                    }
                }
            }
        }
        
        # Clean window state references
        if ($content.PSObject.Properties.Name -contains "windowsState") {
            $windowState = $content.windowsState
            
            if ($windowState.PSObject.Properties.Name -contains "lastActiveWindow") {
                $lastWindow = $windowState.lastActiveWindow
                
                if ($lastWindow.PSObject.Properties.Name -contains "folder") {
                    $folderUri = $lastWindow.folder
                    if ($folderUri -match "augment" -or $folderUri -match "SRC") {
                        if ($DryRun) {
                            Write-LogInfo "DRY RUN: Would clear last active window folder"
                        } else {
                            $lastWindow.PSObject.Properties.Remove("folder")
                            Write-LogSuccess "Cleared last active window folder reference"
                            $modified = $true
                        }
                    }
                }
            }
        }
        
        # Save changes if modified
        if ($modified -and -not $DryRun) {
            $content | ConvertTo-Json -Depth 10 | Set-Content $StoragePath -Encoding UTF8
            Write-LogSuccess "Updated storage file: $StoragePath"
        }
        
        return $true
        
    } catch {
        Write-LogError "Failed to clean workspace references from $StoragePath`: $($_.Exception.Message)"
        return $false
    }
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

function Start-WorkspaceBindingCleanup {
    <#
    .SYNOPSIS
        Main function to clean workspace bindings
    .DESCRIPTION
        Orchestrates the complete workspace binding cleanup process
    .EXAMPLE
        Start-WorkspaceBindingCleanup
    #>
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Starting Workspace Binding Data Cleaning..."
    
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
        
        # Clean database workspace bindings
        foreach ($dbPath in $installation.DatabasePaths) {
            $dbFiles = Get-ChildItem -Path $dbPath -ErrorAction SilentlyContinue
            foreach ($dbFile in $dbFiles) {
                if (Remove-DatabaseWorkspaceBindings -DatabasePath $dbFile.FullName) {
                    $totalCleaned++
                } else {
                    $totalErrors++
                }
            }
        }
        
        # Clean storage file workspace references
        foreach ($storageFile in $installation.StorageFiles) {
            if (Remove-StorageWorkspaceReferences -StoragePath $storageFile) {
                $totalCleaned++
            } else {
                $totalErrors++
            }
        }
    }
    
    Write-LogSuccess "Workspace binding cleaning completed."
    Write-LogInfo "Files processed: $totalCleaned, Errors: $totalErrors"
    
    if ($totalErrors -eq 0) {
        Write-LogSuccess "All workspace bindings successfully removed!"
        Write-LogInfo "Project tracking data cleared - workspace usage history reset."
        return $true
    } else {
        Write-LogWarning "Some errors occurred during workspace binding cleanup."
        return $false
    }
}

#endregion

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    Start-WorkspaceBindingCleanup
}
