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
    
    Write-LogMessage -Level ([LogLevel]::Error) -Message $fullMessage -Category $Category -Color $script:Colors.Red
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
    
    Write-LogMessage -Level ([LogLevel]::Critical) -Message $fullMessage -Category $Category -Color "$($script:Colors.Bold)$($script:Colors.Red)"
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
    
    Write-LogMessage -Level ([LogLevel]::Info) -Message $Message -Category $Category -Color $script:Colors.Green
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
            Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8
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
    'Complete-LogProgress'
)
