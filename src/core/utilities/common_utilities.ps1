# common_utilities.ps1
# Common utility functions library - Augment VIP 2.0 universal functionality module
# Version: 2.1.0
# Features: Provides cross-module common functionality, reduces code duplication, improves maintainability

# No parameters needed at module level

# Set error handling
$ErrorActionPreference = "Stop"
$VerbosePreference = if ($VerbosePreference -eq 'Continue') { "Continue" } else { "SilentlyContinue" }

#region Path and File Operation Tools

<#
.SYNOPSIS
    Get standard installation paths for VS Code and Cursor
.DESCRIPTION
    Returns all possible VS Code and Cursor installation paths, including user-level and system-level installations
.OUTPUTS
    [hashtable] Hashtable containing categorized paths
.EXAMPLE
    $paths = Get-StandardVSCodePaths
    $paths.VSCodeStandard | ForEach-Object { Write-Host $_ }
#>
function Get-StandardVSCodePaths {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{
        # VS Code standard paths
        VSCodeStandard = @(
            "$env:APPDATA\Code",
            "$env:LOCALAPPDATA\Code",
            "$env:APPDATA\Code - Insiders",
            "$env:LOCALAPPDATA\Code - Insiders"
        )

        # Cursor paths
        CursorPaths = @(
            "$env:APPDATA\Cursor",
            "$env:LOCALAPPDATA\Cursor",
            "$env:APPDATA\Cursor - Insiders",
            "$env:LOCALAPPDATA\Cursor - Insiders"
        )

        # User configuration paths
        UserConfig = @(
            "$env:USERPROFILE\.vscode",
            "$env:USERPROFILE\.cursor",
            "$env:USERPROFILE\.config\Code",
            "$env:USERPROFILE\.config\Cursor"
        )

        # System temporary paths
        TempPaths = @(
            "$env:TEMP",
            "$env:TMP",
            "$env:LOCALAPPDATA\Temp",
            "$env:USERPROFILE\AppData\Local\Temp"
        )

        # Registry paths
        RegistryPaths = @(
            "HKCU:\Software\Microsoft\VSCode",
            "HKCU:\Software\Cursor",
            "HKCU:\Software\Classes\Applications\Code.exe",
            "HKCU:\Software\Classes\Applications\Cursor.exe",
            "HKLM:\Software\Microsoft\VSCode",
            "HKLM:\Software\Cursor"
        )
    }
}

<#
.SYNOPSIS
    Safely test if a path exists
.DESCRIPTION
    Tests if a path exists, includes error handling and permission checking
.PARAMETER Path
    Path to test
.PARAMETER PathType
    Path type: 'File', 'Directory', 'Any'
.OUTPUTS
    [bool] Whether the path exists and is accessible
.EXAMPLE
    if (Test-PathSafely "C:\Users\Test\file.txt" -PathType "File") { ... }
#>
function Test-PathSafely {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet('File', 'Directory', 'Any')]
        [string]$PathType = 'Any'
    )

    try {
        if (-not (Test-Path $Path)) {
            return $false
        }

        $item = Get-Item $Path -ErrorAction SilentlyContinue
        if (-not $item) {
            return $false
        }

        switch ($PathType) {
            'File' { return -not $item.PSIsContainer }
            'Directory' { return $item.PSIsContainer }
            'Any' { return $true }
        }

        return $true
    } catch {
        Write-Verbose "Path test failed: $Path - $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Safely create a directory
.DESCRIPTION
    Creates a directory, includes permission checking and error handling
.PARAMETER Path
    Directory path to create
.PARAMETER Force
    Whether to force creation (overwrite existing files)
.OUTPUTS
    [bool] Whether creation was successful
.EXAMPLE
    New-DirectorySafely "C:\Temp\NewFolder" -Force
#>
function New-DirectorySafely {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    try {
        if (Test-Path $Path) {
            if ((Get-Item $Path).PSIsContainer) {
                Write-Verbose "Directory already exists: $Path"
                return $true
            } elseif ($Force) {
                Remove-Item $Path -Force
            } else {
                Write-Warning "Path already exists and is not a directory: $Path"
                return $false
            }
        }

        $null = New-Item -Path $Path -ItemType Directory -Force:$Force
        Write-Verbose "Successfully created directory: $Path"
        return $true
    } catch {
        Write-Warning "Failed to create directory: $Path - $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Database Operation Tools

<#
.SYNOPSIS
    Safely execute SQLite queries
.DESCRIPTION
    Executes SQLite queries with SQL injection protection and error handling
.PARAMETER DatabasePath
    Database file path
.PARAMETER Query
    SQL query to execute
.PARAMETER QueryType
    Query type: 'Select', 'Update', 'Delete', 'Insert'
.OUTPUTS
    [object] Query results or operation status
.EXAMPLE
    $result = Invoke-SQLiteQuerySafely "C:\db.sqlite" "SELECT COUNT(*) FROM table" -QueryType "Select"
#>
function Invoke-SQLiteQuerySafely {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,

        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Select', 'Update', 'Delete', 'Insert', 'Pragma')]
        [string]$QueryType = 'Select',

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30
    )

    # Validate database file
    if (-not (Test-PathSafely $DatabasePath -PathType "File")) {
        throw "Database file does not exist or is not accessible: $DatabasePath"
    }

    # Validate query safety
    if (-not (Test-QuerySafety $Query $QueryType)) {
        throw "Query failed security validation: $Query"
    }

    try {
        # Set timeout parameter
        $timeoutArg = ".timeout $TimeoutSeconds"

        # Execute query
        $result = sqlite3 -cmd $timeoutArg $DatabasePath $Query 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "SQLite query execution failed: $result"
        }

        Write-Verbose "SQLite query executed successfully: $Query"
        return $result
    } catch {
        Write-Error "SQLite query execution exception: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Validate SQL query safety
.DESCRIPTION
    Checks if SQL query contains dangerous operations, prevents SQL injection
.PARAMETER Query
    SQL query to validate
.PARAMETER ExpectedType
    Expected query type
.OUTPUTS
    [bool] Whether the query is safe
.EXAMPLE
    if (Test-QuerySafety "SELECT * FROM table" "Select") { ... }
#>
function Test-QuerySafety {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedType
    )

    # Convert to lowercase for checking
    $lowerQuery = $Query.ToLower().Trim()

    # Dangerous operation patterns
    $dangerousPatterns = @(
        'drop\s+table',
        'drop\s+database',
        'truncate\s+table',
        'alter\s+table',
        'create\s+table',
        'exec\s*\(',
        'execute\s*\(',
        'sp_',
        'xp_',
        '--',
        '/\*',
        '\*/',
        ';.*\w',  # Multiple statements
        'union\s+select',
        'information_schema',
        'sys\.',
        'master\.'
    )

    # Check for dangerous patterns
    foreach ($pattern in $dangerousPatterns) {
        if ($lowerQuery -match $pattern) {
            Write-Warning "Query contains dangerous pattern: $pattern"
            return $false
        }
    }

    # Validate query type match
    $typePatterns = @{
        'Select' = '^select\s+'
        'Update' = '^update\s+'
        'Delete' = '^delete\s+'
        'Insert' = '^insert\s+'
        'Pragma' = '^pragma\s+'
    }

    if ($typePatterns.ContainsKey($ExpectedType)) {
        if (-not ($lowerQuery -match $typePatterns[$ExpectedType])) {
            Write-Warning "Query type mismatch, expected: $ExpectedType, actual query: $Query"
            return $false
        }
    }

    return $true
}

#endregion

#region Progress Display Tools

<#
.SYNOPSIS
    Display progress bar
.DESCRIPTION
    Displays a progress bar with detailed information
.PARAMETER Activity
    Activity name
.PARAMETER Status
    Current status
.PARAMETER PercentComplete
    Completion percentage
.PARAMETER CurrentOperation
    Current operation
.PARAMETER SecondsRemaining
    Estimated remaining time (seconds)
.EXAMPLE
    Show-ProgressBar "Database Cleanup" "Processing file 1/10" 10 "Cleaning state.vscdb" 45
#>
function Show-ProgressBar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Activity,

        [Parameter(Mandatory = $true)]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 100)]
        [int]$PercentComplete,

        [Parameter(Mandatory = $false)]
        [string]$CurrentOperation = "",

        [Parameter(Mandatory = $false)]
        [int]$SecondsRemaining = -1
    )

    $progressParams = @{
        Activity = $Activity
        Status = $Status
        PercentComplete = $PercentComplete
    }

    if ($CurrentOperation) {
        $progressParams.CurrentOperation = $CurrentOperation
    }

    if ($SecondsRemaining -ge 0) {
        $progressParams.SecondsRemaining = $SecondsRemaining
    }

    Write-Progress @progressParams
}

<#
.SYNOPSIS
    Create progress tracker
.DESCRIPTION
    Creates a progress tracker object for tracking multi-step operation progress
.PARAMETER TotalSteps
    Total number of steps
.PARAMETER Activity
    Activity name
.OUTPUTS
    [hashtable] Progress tracker object
.EXAMPLE
    $tracker = New-ProgressTracker 10 "Database Cleanup"
    Update-ProgressTracker $tracker "Starting cleanup" 1
#>
function New-ProgressTracker {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [int]$TotalSteps,

        [Parameter(Mandatory = $true)]
        [string]$Activity
    )

    return @{
        TotalSteps = $TotalSteps
        CurrentStep = 0
        Activity = $Activity
        StartTime = Get-Date
        StepTimes = @()
    }
}

<#
.SYNOPSIS
    Update progress tracker
.DESCRIPTION
    Updates progress tracker status and displays progress bar
.PARAMETER Tracker
    Progress tracker object
.PARAMETER Status
    Current status description
.PARAMETER StepIncrement
    Step increment (default is 1)
.EXAMPLE
    Update-ProgressTracker $tracker "Cleaning database files" 1
#>
function Update-ProgressTracker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Tracker,

        [Parameter(Mandatory = $true)]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [int]$StepIncrement = 1
    )

    $Tracker.CurrentStep += $StepIncrement
    $Tracker.StepTimes += Get-Date

    $percentComplete = [Math]::Min(100, [Math]::Round(($Tracker.CurrentStep / $Tracker.TotalSteps) * 100))

    # Calculate estimated remaining time
    $secondsRemaining = -1
    if ($Tracker.CurrentStep -gt 1) {
        $elapsed = (Get-Date) - $Tracker.StartTime
        $avgTimePerStep = $elapsed.TotalSeconds / $Tracker.CurrentStep
        $remainingSteps = $Tracker.TotalSteps - $Tracker.CurrentStep
        $secondsRemaining = [Math]::Round($avgTimePerStep * $remainingSteps)
    }

    Show-ProgressBar -Activity $Tracker.Activity -Status $Status -PercentComplete $percentComplete -CurrentOperation "Step $($Tracker.CurrentStep)/$($Tracker.TotalSteps)" -SecondsRemaining $secondsRemaining
}

#endregion

# Export all public functions (only when loaded as module)
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    # When dot-sourced, functions are automatically available in the calling scope
    Write-Verbose "Common utilities loaded via dot-sourcing"
} else {
    # When imported as module, export functions
    Export-ModuleMember -Function @(
        'Get-StandardVSCodePaths',
        'Test-PathSafely',
        'New-DirectorySafely',
        'Invoke-SQLiteQuerySafely',
        'Test-QuerySafety',
        'Show-ProgressBar',
        'New-ProgressTracker',
        'Update-ProgressTracker'
    )
}
