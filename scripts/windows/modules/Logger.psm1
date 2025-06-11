# Logger.psm1
#
# Description: Unified logging module for VS Code cleanup operations
# Provides consistent logging, error handling, and progress reporting
#
# Author: Augment VIP Project
# Version: 1.0.0

# Module variables
$script:LogLevel = "Info"
$script:LogFile = $null
$script:EnableConsoleOutput = $true
$script:EnableFileOutput = $false
$script:EnableSensitiveFiltering = $true

# Sensitive information patterns to filter from logs
$script:SensitivePatterns = @(
    # File paths containing usernames
    '(?i)C:\\Users\\[^\\]+',
    # Registry paths
    'HKEY_[A-Z_]+\\[^\\s]+',
    # UUIDs and machine IDs
    '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
    '[0-9a-f]{32,64}',
    # IP addresses
    '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b',
    # Email addresses
    '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
)

# ANSI color codes for console output
$script:Colors = @{
    Reset = "`e[0m"
    Bold = "`e[1m"
    Red = "`e[31m"
    Green = "`e[32m"
    Yellow = "`e[33m"
    Blue = "`e[34m"
    Magenta = "`e[35m"
    Cyan = "`e[36m"
    White = "`e[37m"
    BrightRed = "`e[91m"
    BrightGreen = "`e[92m"
    BrightYellow = "`e[93m"
    BrightBlue = "`e[94m"
}

# Log levels
enum LogLevel {
    Debug = 0
    Info = 1
    Warning = 2
    Error = 3
    Critical = 4
}

<#
.SYNOPSIS
    Initializes the logging system
.DESCRIPTION
    Sets up logging configuration including log file path, log level, and output options
.PARAMETER LogFilePath
    Path to the log file (optional)
.PARAMETER Level
    Minimum log level to record
.PARAMETER EnableConsole
    Enable console output
.PARAMETER EnableFile
    Enable file output
#>
function Initialize-Logger {
    [CmdletBinding()]
    param(
        [string]$LogFilePath,
        [LogLevel]$Level = [LogLevel]::Info,
        [bool]$EnableConsole = $true,
        [bool]$EnableFile = $false
    )
    
    $script:LogLevel = $Level
    $script:EnableConsoleOutput = $EnableConsole
    $script:EnableFileOutput = $EnableFile
    
    if ($LogFilePath) {
        $script:LogFile = $LogFilePath
        $script:EnableFileOutput = $true
        
        # Create log directory if it doesn't exist
        $logDir = Split-Path -Parent $LogFilePath
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        # Write initial log entry
        Write-LogInfo "Logger initialized - Log file: $LogFilePath"
    }
}

<#
.SYNOPSIS
    Writes a debug message
.PARAMETER Message
    The message to log
.PARAMETER Category
    Optional category for the message
#>
function Write-LogDebug {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Category = "DEBUG"
    )
    
    Write-LogMessage -Level ([LogLevel]::Debug) -Message $Message -Category $Category -Color $script:Colors.Cyan
}

<#
.SYNOPSIS
    Writes an informational message
.PARAMETER Message
    The message to log
.PARAMETER Category
    Optional category for the message
#>
function Write-LogInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Category = "INFO"
    )
    
    Write-LogMessage -Level ([LogLevel]::Info) -Message $Message -Category $Category -Color $script:Colors.Blue
}

<#
.SYNOPSIS
    Writes a warning message
.PARAMETER Message
    The message to log
.PARAMETER Category
    Optional category for the message
#>
function Write-LogWarning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Category = "WARNING"
    )
    
    Write-LogMessage -Level ([LogLevel]::Warning) -Message $Message -Category $Category -Color $script:Colors.Yellow
}

<#
.SYNOPSIS
    Writes an error message
.PARAMETER Message
    The message to log
.PARAMETER Category
    Optional category for the message
.PARAMETER Exception
    Optional exception object
#>
function Write-LogError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Category = "ERROR",
        [System.Exception]$Exception
    )
    
    $fullMessage = $Message
    if ($Exception) {
        $fullMessage += " | Exception: $($Exception.Message)"
        if ($Exception.InnerException) {
            $fullMessage += " | Inner: $($Exception.InnerException.Message)"
        }
    }
    
    Write-LogMessage -Level ([LogLevel]::Error) -Message $fullMessage -Category $Category -Color $script:Colors.BrightRed
}

<#
.SYNOPSIS
    Writes a critical error message
.PARAMETER Message
    The message to log
.PARAMETER Category
    Optional category for the message
.PARAMETER Exception
    Optional exception object
#>
function Write-LogCritical {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Category = "CRITICAL",
        [System.Exception]$Exception
    )
    
    $fullMessage = $Message
    if ($Exception) {
        $fullMessage += " | Exception: $($Exception.Message)"
        if ($Exception.InnerException) {
            $fullMessage += " | Inner: $($Exception.InnerException.Message)"
        }
    }
    
    Write-LogMessage -Level ([LogLevel]::Critical) -Message $fullMessage -Category $Category -Color "$($script:Colors.Bold)$($script:Colors.BrightRed)"
}

<#
.SYNOPSIS
    Writes a success message
.PARAMETER Message
    The message to log
.PARAMETER Category
    Optional category for the message
#>
function Write-LogSuccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Category = "SUCCESS"
    )
    
    Write-LogMessage -Level ([LogLevel]::Info) -Message $Message -Category $Category -Color $script:Colors.BrightGreen
}

<#
.SYNOPSIS
    Core logging function
.PARAMETER Level
    Log level
.PARAMETER Message
    The message to log
.PARAMETER Category
    Message category
.PARAMETER Color
    Console color
#>
function Write-LogMessage {
    [CmdletBinding()]
    param(
        [LogLevel]$Level,
        [string]$Message,
        [string]$Category,
        [string]$Color
    )
    
    # Check if we should log this level
    if ($Level -lt $script:LogLevel) {
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Category] $Message"
    
    # Console output
    if ($script:EnableConsoleOutput) {
        $consoleMessage = "$Color[$Category]$($script:Colors.Reset) $Message"
        Write-Host $consoleMessage
    }
    
    # File output
    if ($script:EnableFileOutput -and $script:LogFile) {
        try {
            # Apply sensitive information filtering for file output
            $filteredLogEntry = if ($script:EnableSensitiveFiltering) {
                Remove-SensitiveInfo -Message $logEntry
            } else {
                $logEntry
            }
            Add-Content -Path $script:LogFile -Value $filteredLogEntry -Encoding UTF8
        }
        catch {
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
    }
}

<#
.SYNOPSIS
    Displays a progress bar
.PARAMETER Activity
    Description of the activity
.PARAMETER Status
    Current status
.PARAMETER PercentComplete
    Percentage complete (0-100)
.PARAMETER Id
    Progress bar ID for multiple progress bars
#>
function Write-LogProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Activity,
        [string]$Status = "Processing...",
        [int]$PercentComplete = 0,
        [int]$Id = 1
    )
    
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -Id $Id
}

<#
.SYNOPSIS
    Removes sensitive information from log messages
.PARAMETER Message
    The message to filter
.OUTPUTS
    string - Filtered message with sensitive information masked
#>
function Remove-SensitiveInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $script:EnableSensitiveFiltering) {
        return $Message
    }

    $filteredMessage = $Message

    try {
        foreach ($pattern in $script:SensitivePatterns) {
            $filteredMessage = $filteredMessage -replace $pattern, '[FILTERED]'
        }

        # Additional specific filtering
        # Replace username in paths with generic placeholder
        $filteredMessage = $filteredMessage -replace "\\Users\\$env:USERNAME\\", '\Users\[USER]\'

        # Replace computer name
        if ($env:COMPUTERNAME) {
            $filteredMessage = $filteredMessage -replace $env:COMPUTERNAME, '[COMPUTER]'
        }

        # Replace domain name
        if ($env:USERDOMAIN) {
            $filteredMessage = $filteredMessage -replace $env:USERDOMAIN, '[DOMAIN]'
        }

        return $filteredMessage
    }
    catch {
        Write-Warning "Failed to filter sensitive information from log message"
        return $Message
    }
}

<#
.SYNOPSIS
    Enables or disables sensitive information filtering
.PARAMETER Enable
    Enable sensitive information filtering
#>
function Set-SensitiveFiltering {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Enable
    )

    $script:EnableSensitiveFiltering = $Enable
    $status = if ($Enable) { "enabled" } else { "disabled" }
    Write-LogInfo "Sensitive information filtering $status"
}

<#
.SYNOPSIS
    Adds a custom sensitive pattern to the filter list
.PARAMETER Pattern
    Regular expression pattern to add
#>
function Add-SensitivePattern {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    try {
        # Test the pattern to ensure it's valid
        "test" -match $Pattern | Out-Null
        $script:SensitivePatterns += $Pattern
        Write-LogDebug "Added sensitive pattern: $Pattern"
    }
    catch {
        Write-LogError "Invalid regex pattern: $Pattern" -Exception $_.Exception
    }
}

<#
.SYNOPSIS
    Completes a progress bar
.PARAMETER Id
    Progress bar ID to complete
#>
function Complete-LogProgress {
    [CmdletBinding()]
    param(
        [int]$Id = 1
    )
    
    Write-Progress -Activity "Completed" -Completed -Id $Id
}

<#
.SYNOPSIS
    Displays a user-friendly success message with green color and icon
.PARAMETER Message
    The success message to display
.PARAMETER ShowIcon
    Whether to show a success icon (default: true)
#>
function Show-SuccessMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [bool]$ShowIcon = $true
    )

    $icon = if ($ShowIcon) { "[OK] " } else { "" }
    $coloredMessage = "$($script:Colors.BrightGreen)$($script:Colors.Bold)$icon$Message$($script:Colors.Reset)"
    Write-Host $coloredMessage

    # Also log to file if enabled
    if ($script:EnableFileOutput -and $script:LogFile) {
        $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [SUCCESS] $Message"
        try {
            Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8
        }
        catch {
            Write-Warning "Failed to write success message to log file"
        }
    }
}

<#
.SYNOPSIS
    Displays a user-friendly error message with red color and icon
.PARAMETER Message
    The error message to display
.PARAMETER ShowIcon
    Whether to show an error icon (default: true)
.PARAMETER Exception
    Optional exception object for detailed logging
#>
function Show-ErrorMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [bool]$ShowIcon = $true,
        [System.Exception]$Exception
    )

    $icon = if ($ShowIcon) { "[ERROR] " } else { "" }
    $coloredMessage = "$($script:Colors.BrightRed)$($script:Colors.Bold)$icon$Message$($script:Colors.Reset)"
    Write-Host $coloredMessage

    # Also log to file if enabled
    if ($script:EnableFileOutput -and $script:LogFile) {
        $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [ERROR] $Message"
        if ($Exception) {
            $logEntry += " | Exception: $($Exception.Message)"
        }

        try {
            $filteredLogEntry = if ($script:EnableSensitiveFiltering) {
                Remove-SensitiveInfo -Message $logEntry
            } else {
                $logEntry
            }
            Add-Content -Path $script:LogFile -Value $filteredLogEntry -Encoding UTF8
        }
        catch {
            Write-Warning "Failed to write error message to log file"
        }
    }
}

<#
.SYNOPSIS
    Displays a user-friendly warning message with yellow color and icon
.PARAMETER Message
    The warning message to display
.PARAMETER ShowIcon
    Whether to show a warning icon (default: true)
#>
function Show-WarningMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [bool]$ShowIcon = $true
    )

    $icon = if ($ShowIcon) { "[WARNING] " } else { "" }
    $coloredMessage = "$($script:Colors.BrightYellow)$($script:Colors.Bold)$icon$Message$($script:Colors.Reset)"
    Write-Host $coloredMessage

    # Also log to file if enabled
    if ($script:EnableFileOutput -and $script:LogFile) {
        $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WARNING] $Message"
        try {
            $filteredLogEntry = if ($script:EnableSensitiveFiltering) {
                Remove-SensitiveInfo -Message $logEntry
            } else {
                $logEntry
            }
            Add-Content -Path $script:LogFile -Value $filteredLogEntry -Encoding UTF8
        }
        catch {
            Write-Warning "Failed to write warning message to log file"
        }
    }
}

<#
.SYNOPSIS
    Displays a user-friendly information message with blue color and icon
.PARAMETER Message
    The information message to display
.PARAMETER ShowIcon
    Whether to show an info icon (default: true)
#>
function Show-InfoMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [bool]$ShowIcon = $true
    )

    $icon = if ($ShowIcon) { "[INFO] " } else { "" }
    $coloredMessage = "$($script:Colors.BrightBlue)$icon$Message$($script:Colors.Reset)"
    Write-Host $coloredMessage

    # Also log to file if enabled
    if ($script:EnableFileOutput -and $script:LogFile) {
        $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] $Message"
        try {
            $filteredLogEntry = if ($script:EnableSensitiveFiltering) {
                Remove-SensitiveInfo -Message $logEntry
            } else {
                $logEntry
            }
            Add-Content -Path $script:LogFile -Value $filteredLogEntry -Encoding UTF8
        }
        catch {
            Write-Warning "Failed to write info message to log file"
        }
    }
}

<#
.SYNOPSIS
    Displays a user-friendly operation status with progress indicator
.PARAMETER Operation
    The operation being performed
.PARAMETER Status
    Current status (Starting, InProgress, Completed, Failed)
.PARAMETER Details
    Optional additional details
#>
function Show-OperationStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Operation,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Starting', 'InProgress', 'Completed', 'Failed')]
        [string]$Status,
        [string]$Details = ""
    )

    $icon = switch ($Status) {
        'Starting' { "[START]" }
        'InProgress' { "[PROGRESS]" }
        'Completed' { "[DONE]" }
        'Failed' { "[FAILED]" }
    }

    $color = switch ($Status) {
        'Starting' { $script:Colors.BrightBlue }
        'InProgress' { $script:Colors.BrightYellow }
        'Completed' { $script:Colors.BrightGreen }
        'Failed' { $script:Colors.BrightRed }
    }

    $message = "$icon $Operation - $Status"
    if ($Details) {
        $message += " ($Details)"
    }

    $coloredMessage = "$color$($script:Colors.Bold)$message$($script:Colors.Reset)"
    Write-Host $coloredMessage
}

<#
.SYNOPSIS
    Shows a formatted banner with title and optional subtitle
.PARAMETER Title
    Main title text
.PARAMETER Subtitle
    Optional subtitle text
.PARAMETER Color
    Color for the banner (default: BrightBlue)
#>
function Show-Banner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [string]$Subtitle = "",
        [string]$Color = "BrightBlue"
    )

    $bannerColor = $script:Colors[$Color]
    $separator = "=" * ($Title.Length + 4)

    Write-Host ""
    Write-Host "$bannerColor$($script:Colors.Bold)$separator$($script:Colors.Reset)"
    Write-Host "$bannerColor$($script:Colors.Bold)  $Title  $($script:Colors.Reset)"
    if ($Subtitle) {
        Write-Host "$bannerColor  $Subtitle  $($script:Colors.Reset)"
    }
    Write-Host "$bannerColor$($script:Colors.Bold)$separator$($script:Colors.Reset)"
    Write-Host ""
}

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-Logger',
    'Write-LogDebug',
    'Write-LogInfo',
    'Write-LogWarning',
    'Write-LogError',
    'Write-LogCritical',
    'Write-LogSuccess',
    'Write-LogProgress',
    'Complete-LogProgress',
    'Remove-SensitiveInfo',
    'Set-SensitiveFiltering',
    'Add-SensitivePattern',
    'Show-SuccessMessage',
    'Show-ErrorMessage',
    'Show-WarningMessage',
    'Show-InfoMessage',
    'Show-OperationStatus',
    'Show-Banner'
)
