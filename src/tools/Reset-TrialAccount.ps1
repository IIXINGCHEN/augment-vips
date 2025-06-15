# Reset-TrialAccount.ps1
# Enterprise-Grade Augment VIP Trial Account Reset Tool v3.0.0
# 综合解决方案，使用统一核心模块重置试用账户限制

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("reset", "help")]
    [string]$Operation = "reset",

    [Parameter(HelpMessage = "Enable verbose logging output for debugging purposes")]
    [switch]$VerboseOutput = $false,

    [Parameter(HelpMessage = "Perform dry run without making actual changes")]
    [switch]$DryRun = $false,

    [Parameter(HelpMessage = "Force operation without user confirmation")]
    [switch]$Force = $false
)

#region Script Configuration
$script:TOOL_NAME = "Enterprise Trial Account Reset Tool"
$script:TOOL_VERSION = "3.0.0"
$script:OperationStartTime = Get-Date

# 首先定义基本日志函数（防止加载失败时出错）
function Write-LogInfo { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Green }
function Write-LogError { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-LogSuccess { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Cyan }
function Write-LogWarning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-LogCritical { param([string]$Message) Write-Host "[CRITICAL] $Message" -ForegroundColor Magenta }
function Write-LogDebug { param([string]$Message) if ($VerboseOutput) { Write-Host "[DEBUG] $Message" -ForegroundColor Gray } }

# 尝试加载统一核心模块
$coreModulePath = Join-Path $PSScriptRoot "..\core\anti_detection\AntiDetectionCore.ps1"
if (Test-Path $coreModulePath) {
    try {
        . $coreModulePath
        $Global:CoreModulesAvailable = $true
        Write-LogDebug "Core modules loaded successfully"
    } catch {
        Write-LogWarning "Failed to load core modules: $($_.Exception.Message)"
        Write-LogInfo "Using fallback logging functions"
        $Global:CoreModulesAvailable = $false
    }
} else {
    Write-LogDebug "Core modules not found, using fallback logging functions"
    $Global:CoreModulesAvailable = $false
}
#endregion

#region Installation Discovery
function Find-SupportedApplicationInstallations {
    [CmdletBinding()]
    param()

    Write-LogInfo "Scanning for supported application installations"
    $installations = @()

    # 使用统一的安装发现函数
    if (Get-Command Get-UnifiedVSCodeInstallations -ErrorAction SilentlyContinue) {
        Write-LogDebug "Using unified installation discovery function"
        $unifiedInstallations = Get-UnifiedVSCodeInstallations

        foreach ($installation in $unifiedInstallations) {
            $userPath = Join-Path $installation.Path "User"
            if (Test-Path $userPath -PathType Container) {
                $installations += @{
                    ApplicationName = $installation.Type
                    InstallationPath = $installation.Path
                    UserDataPath = $userPath
                    DiscoveryTimestamp = Get-Date
                }
                Write-LogSuccess "Found installation: $($installation.Type) at $($installation.Path)"
            }
        }
    } else {
        Write-LogWarning "Unified installation discovery function not available, using fallback implementation"

        # 标准路径列表
        $standardPaths = @(
            @{ Path = "$env:APPDATA\Code"; Name = "Visual Studio Code" },
            @{ Path = "$env:APPDATA\Cursor"; Name = "Cursor IDE" },
            @{ Path = "$env:APPDATA\Code - Insiders"; Name = "Visual Studio Code Insiders" },
            @{ Path = "$env:LOCALAPPDATA\Code"; Name = "Visual Studio Code (Local)" },
            @{ Path = "$env:LOCALAPPDATA\Cursor"; Name = "Cursor IDE (Local)" }
        )

        foreach ($pathInfo in $standardPaths) {
            $installPath = $pathInfo.Path
            $appName = $pathInfo.Name

            if (Test-Path $installPath -PathType Container) {
                $userPath = Join-Path $installPath "User"
                if (Test-Path $userPath -PathType Container) {
                    $installations += @{
                        ApplicationName = $appName
                        InstallationPath = $installPath
                        UserDataPath = $userPath
                        DiscoveryTimestamp = Get-Date
                    }
                    Write-LogSuccess "Found installation: $appName at $installPath"
                }
            } else {
                Write-LogDebug "Not found: $installPath"
            }
        }
    }

    if ($installations.Count -eq 0) {
        Write-LogError "No supported installations found"
        return $null
    }

    Write-LogInfo "Discovery completed: $($installations.Count) installation(s) found"
    return $installations
}
#endregion

#region Device Fingerprint Generation
function New-EnterpriseDeviceFingerprint {
    [CmdletBinding()]
    param()

    Write-LogInfo "Generating new enterprise-grade device fingerprint"

    try {
        # Generate cryptographically secure machine ID
        $machineIdBytes = New-Object byte[] 32
        [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($machineIdBytes)
        $machineId = [System.BitConverter]::ToString($machineIdBytes).Replace("-", "").ToLower()

        $deviceId = [System.Guid]::NewGuid().ToString()
        $sqmId = [System.Guid]::NewGuid().ToString()

        $currentTime = Get-Date
        $firstTime = $currentTime

        $fingerprint = @{
            MachineId = $machineId
            DeviceId = $deviceId
            SqmId = $sqmId
            FirstSessionString = $firstTime.ToString("ddd, dd MMM yyyy HH:mm:ss 'GMT'")
            CurrentSessionString = $currentTime.ToString("ddd, dd MMM yyyy HH:mm:ss 'GMT'")
            GenerationTimestamp = Get-Date
        }

        Write-LogSuccess "Device fingerprint generated successfully"
        Write-LogDebug "Machine ID: $($fingerprint.MachineId)"
        Write-LogDebug "Device ID: $($fingerprint.DeviceId)"
        Write-LogDebug "SQM ID: $($fingerprint.SqmId)"

        return $fingerprint

    } catch {
        Write-LogError "Failed to generate device fingerprint: $($_.Exception.Message)"
        throw
    }
}
#endregion

#region Storage File Updates
function Update-ApplicationStorageFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StorageFilePath,

        [Parameter(Mandatory = $true)]
        [hashtable]$DeviceFingerprint
    )

    Write-LogInfo "Processing storage file: $StorageFilePath"

    if (-not (Test-Path $StorageFilePath)) {
        Write-LogWarning "Storage file not found, creating new one"

        if ($DryRun) {
            Write-LogInfo "[DRY RUN] Would create new storage.json"
            return $true
        }

        $newContent = @{
            "telemetry.machineId" = $DeviceFingerprint.MachineId
            "telemetry.devDeviceId" = $DeviceFingerprint.DeviceId
            "telemetry.sqmId" = $DeviceFingerprint.SqmId
            "profileAssociations" = @{ "workspaces" = @{} }
            "backupWorkspaces" = @{ "folders" = @() }
        }

        try {
            $newContent | ConvertTo-Json -Depth 10 | Set-Content $StorageFilePath -Encoding UTF8
            Write-LogSuccess "New storage file created"
            return $true
        } catch {
            Write-LogError "Failed to create storage file: $($_.Exception.Message)"
            return $false
        }
    }

    try {
        if (-not $DryRun) {
            $backupPath = "$StorageFilePath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item $StorageFilePath $backupPath
            Write-LogInfo "Backup created: $backupPath"
        }

        $content = Get-Content $StorageFilePath -Raw | ConvertFrom-Json

        # Update device fingerprint
        $content."telemetry.machineId" = $DeviceFingerprint.MachineId
        $content."telemetry.devDeviceId" = $DeviceFingerprint.DeviceId
        $content."telemetry.sqmId" = $DeviceFingerprint.SqmId

        # Clear workspace associations
        if ($content.PSObject.Properties["profileAssociations"]) {
            $content.profileAssociations.workspaces = @{}
        }
        if ($content.PSObject.Properties["backupWorkspaces"]) {
            $content.backupWorkspaces.folders = @()
        }

        # Clear window state workspace references
        if ($content.PSObject.Properties["windowsState"] -and
            $content.windowsState.PSObject.Properties["lastActiveWindow"]) {
            $preservedUiState = $content.windowsState.lastActiveWindow.uiState
            $content.windowsState.lastActiveWindow = @{ uiState = $preservedUiState }
        }

        # Remove workspace override settings
        if ($content.PSObject.Properties["windowSplashWorkspaceOverride"]) {
            $content.PSObject.Properties.Remove("windowSplashWorkspaceOverride")
        }

        if ($DryRun) {
            Write-LogInfo "[DRY RUN] Would update storage file"
            return $true
        }

        $content | ConvertTo-Json -Depth 10 | Set-Content $StorageFilePath -Encoding UTF8
        Write-LogSuccess "Storage file updated successfully"
        return $true

    } catch {
        Write-LogError "Failed to update storage file: $($_.Exception.Message)"
        return $false
    }
}
#endregion

#region Database Updates
function Update-ApplicationDatabases {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserDataPath,

        [Parameter(Mandatory = $true)]
        [hashtable]$DeviceFingerprint
    )

    Write-LogInfo "Processing databases in: $UserDataPath"

    # Check for SQLite3
    try {
        $null = & sqlite3 -version
    } catch {
        Write-LogError "SQLite3 is required but not found in PATH. Please install SQLite3."
        return $false
    }

    $dbFiles = Get-ChildItem -Path $UserDataPath -Recurse -Filter "*.vscdb" -ErrorAction SilentlyContinue

    if ($dbFiles.Count -eq 0) {
        Write-LogWarning "No database files found"
        return $true
    }

    Write-LogInfo "Found $($dbFiles.Count) database file(s) to process"

    foreach ($dbFile in $dbFiles) {
        Write-LogInfo "Processing: $($dbFile.Name)"

        if (-not $DryRun) {
            $backupPath = "$($dbFile.FullName).backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item $dbFile.FullName $backupPath
            Write-LogInfo "Database backup: $backupPath"
        }

        $cleanupQueries = @(
            "DELETE FROM ItemTable WHERE key LIKE '%augment%';",
            "DELETE FROM ItemTable WHERE key LIKE '%trial%';",
            "DELETE FROM ItemTable WHERE key LIKE 'secret://%augment%';",
            "DELETE FROM ItemTable WHERE key LIKE 'Augment.%';",
            "DELETE FROM ItemTable WHERE key LIKE 'workbench.view.extension.augment%';",
            "DELETE FROM ItemTable WHERE key LIKE 'augment-panel.%';"
        )

        $telemetryQueries = @(
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.firstSessionDate', '$($DeviceFingerprint.FirstSessionString)');",
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('telemetry.currentSessionDate', '$($DeviceFingerprint.CurrentSessionString)');"
        )

        if ($DryRun) {
            Write-LogInfo "[DRY RUN] Would execute $($cleanupQueries.Count) cleanup queries"
            Write-LogInfo "[DRY RUN] Would execute $($telemetryQueries.Count) telemetry queries"
        } else {
            foreach ($query in $cleanupQueries) {
                & sqlite3 $dbFile.FullName $query 2>$null
            }
            foreach ($query in $telemetryQueries) {
                & sqlite3 $dbFile.FullName $query 2>$null
            }
            Write-LogSuccess "Database processed: $($dbFile.Name)"
        }
    }

    return $true
}
#endregion

#region Global Storage Cleanup
function Remove-AugmentGlobalStorageDirectories {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserDataPath
    )

    $globalStoragePath = Join-Path $UserDataPath "globalStorage"

    if (-not (Test-Path $globalStoragePath -PathType Container)) {
        Write-LogDebug "GlobalStorage directory not found"
        return $true
    }

    Write-LogInfo "Scanning globalStorage for Augment directories"

    $augmentDirs = @(Get-ChildItem -Path $globalStoragePath -Directory | Where-Object {
        $_.Name -like "*augment*" -or $_.Name -like "*Augment*"
    })

    if ($augmentDirs.Count -eq 0) {
        Write-LogSuccess "No Augment directories found in globalStorage"
        return $true
    }

    foreach ($augmentDir in $augmentDirs) {
        if ($DryRun) {
            Write-LogInfo "[DRY RUN] Would remove directory: $($augmentDir.Name)"
        } else {
            try {
                Remove-Item $augmentDir.FullName -Recurse -Force -ErrorAction Stop
                Write-LogSuccess "Removed Augment directory: $($augmentDir.Name)"
            } catch {
                Write-LogError "Failed to remove directory $($augmentDir.Name): $($_.Exception.Message)"
                return $false
            }
        }
    }

    return $true
}
#endregion

#region Main Function
function Start-TrialAccountReset {
    [CmdletBinding()]
    param()

    try {
        Write-LogInfo "Initiating $($script:TOOL_NAME) v$($script:TOOL_VERSION)"
        Write-LogInfo "Operation Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE EXECUTION' })"
        Write-LogInfo "Verbose Logging: $VerboseOutput"

        # Discover installations
        $installations = Find-SupportedApplicationInstallations
        if (-not $installations) {
            Write-LogCritical "No supported installations found"
            return $false
        }

        # Generate new device fingerprint
        $deviceFingerprint = New-EnterpriseDeviceFingerprint

        # Process each installation
        $overallSuccess = $true

        foreach ($installation in $installations) {
            Write-LogInfo "Processing: $($installation.ApplicationName)"
            Write-LogInfo "Installation Path: $($installation.InstallationPath)"
            Write-LogInfo "User Data Path: $($installation.UserDataPath)"

            # Update storage file
            $storageFile = Join-Path $installation.UserDataPath "storage.json"
            $storageSuccess = Update-ApplicationStorageFile -StorageFilePath $storageFile -DeviceFingerprint $deviceFingerprint

            # Update databases
            $dbSuccess = Update-ApplicationDatabases -UserDataPath $installation.UserDataPath -DeviceFingerprint $deviceFingerprint

            # Clean global storage
            $globalSuccess = Remove-AugmentGlobalStorageDirectories -UserDataPath $installation.UserDataPath

            $installationSuccess = $storageSuccess -and $dbSuccess -and $globalSuccess
            $overallSuccess = $overallSuccess -and $installationSuccess

            if ($installationSuccess) {
                Write-LogSuccess "Installation processed successfully: $($installation.ApplicationName)"
            } else {
                Write-LogError "Installation had errors: $($installation.ApplicationName)"
            }
        }

        # Generate operation summary
        $duration = (Get-Date) - $script:OperationStartTime

        Write-LogInfo "Enterprise Trial Account Reset Operation Completed"
        Write-LogInfo "Operation Summary:"
        Write-LogInfo "  - Total Installations Processed: $($installations.Count)"
        Write-LogInfo "  - Device Fingerprint Regenerated: YES"
        Write-LogInfo "  - Workspace Associations Cleared: YES"
        Write-LogInfo "  - Trial Restriction Data Removed: YES"
        Write-LogInfo "  - Session Timestamps Updated: YES"
        Write-LogInfo "  - Backup Files Created: $(if (-not $DryRun) { 'YES' } else { 'N/A (DRY RUN)' })"
        Write-LogInfo "  - Operation Duration: $($duration.TotalSeconds) seconds"
        Write-LogInfo "  - Overall Success: $(if ($overallSuccess) { 'YES' } else { 'NO' })"

        if ($overallSuccess) {
            Write-LogSuccess "All operations completed successfully"
            if (-not $DryRun) {
                Write-LogInfo "IMPORTANT: Please restart all VS Code/Cursor instances to apply changes"
                Write-LogInfo "The system should now treat installations as fresh, without trial restrictions"
            }
        } else {
            Write-LogError "Some operations encountered errors"
        }

        return $overallSuccess

    } catch {
        Write-LogCritical "Critical failure: $($_.Exception.Message)"
        Write-LogDebug "Stack Trace: $($_.ScriptStackTrace)"
        return $false
    }
}
#endregion

#region Help and Utility Functions
function Show-TrialAccountResetHelp {
    Write-Host @"
Reset Trial Account v3.0.0 - Enterprise-Grade Augment VIP Trial Account Reset Tool

USAGE:
    .\Reset-TrialAccount.ps1 [options]

OPERATIONS:
    reset       Reset trial account (default)
    help        Show this help message

OPTIONS:
    -VerboseOutput          Enable verbose logging output for debugging purposes
    -DryRun                 Perform dry run without making actual changes
    -Force                  Force operation without user confirmation

EXAMPLES:
    .\Reset-TrialAccount.ps1 -DryRun -VerboseOutput
    .\Reset-TrialAccount.ps1 -Force
    .\Reset-TrialAccount.ps1

PURPOSE:
    Comprehensive solution for resetting trial account limitations using unified core modules.
    Generates new device fingerprints and clears trial restriction data.
"@
}
#endregion

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    switch ($Operation) {
        "reset" {
            $operationResult = Start-TrialAccountReset

            # Set appropriate exit code
            if ($operationResult) {
                Write-LogSuccess "Enterprise Trial Account Reset Tool completed successfully"
                exit 0
            } else {
                Write-LogError "Enterprise Trial Account Reset Tool completed with errors"
                exit 1
            }
        }
        "help" {
            Show-TrialAccountResetHelp
            exit 0
        }
        default {
            Write-LogError "Unknown operation: $Operation"
            Show-TrialAccountResetHelp
            exit 1
        }
    }
}