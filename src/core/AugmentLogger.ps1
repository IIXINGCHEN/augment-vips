# AugmentLogger.ps1
# Unified Logging System for Augment VIP
# Version: 3.0.0 - Standardized and optimized
# Features: Multi-level logging, file rotation, audit trails, cross-platform support

# No parameters needed at module level

# Prevent multiple inclusions
if ($Global:AugmentLoggerLoaded) {
    return
}
$Global:AugmentLoggerLoaded = $true

# Error handling
$ErrorActionPreference = "Stop"

#region Configuration

# Global logger configuration
$Global:LoggerConfig = @{
    LogLevel = "INFO"
    OutputTargets = @("Console", "File")
    LogFile = ""
    MaxLogFileSize = 10MB
    LogRotationCount = 5
    TimestampFormat = "yyyy-MM-dd HH:mm:ss"
    EnableColors = $true
    EnableAudit = $true
    AuditFile = ""
    Initialized = $false
}

# Log level definitions with numeric values for comparison
$Global:LogLevels = @{
    DEBUG = 0
    INFO = 1
    WARNING = 2
    ERROR = 3
    SUCCESS = 4
    CRITICAL = 5
}

# Color configuration for console output
$Global:LogColors = @{
    DEBUG = "Gray"
    INFO = "White"
    WARNING = "Yellow"
    ERROR = "Red"
    SUCCESS = "Green"
    CRITICAL = "Magenta"
    RESET = "White"
}

#endregion

#region Core Functions

# Initialize the logging system
function Initialize-AugmentLogger {
    <#
    .SYNOPSIS
        Initializes the Augment VIP logging system
    .DESCRIPTION
        Sets up logging configuration, creates log directories, and prepares the logging system for use
    .PARAMETER LogDirectory
        Directory where log files will be stored
    .PARAMETER LogFileName
        Name of the main log file
    .PARAMETER LogLevel
        Minimum log level to output (DEBUG, INFO, WARNING, ERROR, SUCCESS, CRITICAL)
    .PARAMETER EnableColors
        Enable colored console output
    .PARAMETER EnableAudit
        Enable audit logging for critical events
    .EXAMPLE
        Initialize-AugmentLogger -LogDirectory "logs" -LogFileName "augment.log" -LogLevel "INFO"
    #>
    [CmdletBinding()]
    param(
        [string]$LogDirectory = "logs",
        [string]$LogFileName = "augment_vip.log",
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR", "SUCCESS", "CRITICAL")]
        [string]$LogLevel = "INFO",
        [switch]$EnableColors = $true,
        [switch]$EnableAudit = $true
    )
    
    try {
        # Create log directory if it doesn't exist
        if (-not (Test-Path $LogDirectory)) {
            New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
        }
        
        # Set configuration
        $Global:LoggerConfig.LogFile = Join-Path $LogDirectory $LogFileName
        $Global:LoggerConfig.AuditFile = Join-Path $LogDirectory "audit_$(Get-Date -Format 'yyyyMMdd').log"
        $Global:LoggerConfig.LogLevel = $LogLevel
        $Global:LoggerConfig.EnableColors = $EnableColors
        $Global:LoggerConfig.EnableAudit = $EnableAudit
        
        # Check log file size and rotate if needed
        if (Test-Path $Global:LoggerConfig.LogFile) {
            $logFile = Get-Item $Global:LoggerConfig.LogFile
            if ($logFile.Length -gt $Global:LoggerConfig.MaxLogFileSize) {
                Invoke-LogRotation
            }
        }
        
        $Global:LoggerConfig.Initialized = $true
        Write-AugmentLog -Message "Augment Logger initialized successfully" -Level "INFO" -SkipFileLog
        return $true
        
    } catch {
        Write-Host "Failed to initialize Augment Logger: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Rotate log files when they exceed size limit
function Invoke-LogRotation {
    <#
    .SYNOPSIS
        Rotates log files when they exceed the maximum size
    .DESCRIPTION
        Moves current log file to numbered backup and creates new log file
    #>
    [CmdletBinding()]
    param()
    
    try {
        $logFile = $Global:LoggerConfig.LogFile
        $logDir = Split-Path $logFile -Parent
        $logName = [System.IO.Path]::GetFileNameWithoutExtension($logFile)
        $logExt = [System.IO.Path]::GetExtension($logFile)
        
        # Rotate existing log files (keep specified number of backups)
        for ($i = $Global:LoggerConfig.LogRotationCount; $i -gt 0; $i--) {
            $oldFile = Join-Path $logDir "$logName.$i$logExt"
            $newFile = Join-Path $logDir "$logName.$($i + 1)$logExt"
            
            if (Test-Path $oldFile) {
                if ($i -eq $Global:LoggerConfig.LogRotationCount) {
                    Remove-Item $oldFile -Force
                } else {
                    Move-Item $oldFile $newFile -Force
                }
            }
        }
        
        # Move current log file to .1
        if (Test-Path $logFile) {
            $rotatedFile = Join-Path $logDir "$logName.1$logExt"
            Move-Item $logFile $rotatedFile -Force
        }
        
    } catch {
        Write-Host "Failed to rotate log file: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Universal log writing function
function Write-AugmentLog {
    <#
    .SYNOPSIS
        Writes a log message to configured outputs
    .DESCRIPTION
        Core logging function that handles message formatting, level filtering, and output routing
    .PARAMETER Message
        The message to log
    .PARAMETER Level
        Log level (DEBUG, INFO, WARNING, ERROR, SUCCESS, CRITICAL)
    .PARAMETER Category
        Category for organizing log messages
    .PARAMETER AdditionalData
        Additional data to include in structured logs
    .PARAMETER SkipFileLog
        Skip writing to file log
    .PARAMETER SkipConsoleLog
        Skip writing to console
    .EXAMPLE
        Write-AugmentLog -Message "Operation completed" -Level "SUCCESS" -Category "CLEANUP"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR", "SUCCESS", "CRITICAL")]
        [string]$Level,
        
        [string]$Category = "GENERAL",
        [hashtable]$AdditionalData = @{},
        [switch]$SkipFileLog,
        [switch]$SkipConsoleLog
    )
    
    # Initialize logger if not already done
    if (-not $Global:LoggerConfig.Initialized) {
        Initialize-AugmentLogger | Out-Null
    }
    
    try {
        # Check if message meets minimum log level
        $currentLevelValue = $Global:LogLevels[$Global:LoggerConfig.LogLevel]
        $messageLevelValue = $Global:LogLevels[$Level]

        if ($messageLevelValue -lt $currentLevelValue) {
            return
        }

        # Create timestamp
        $timestamp = Get-Date -Format $Global:LoggerConfig.TimestampFormat

        # Build structured log entry
        $logEntry = @{
            Timestamp = $timestamp
            Level = $Level
            Category = $Category
            Message = $Message
            ProcessId = $PID
            ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
            ScriptName = if ($MyInvocation.ScriptName) { Split-Path $MyInvocation.ScriptName -Leaf } else { "Unknown" }
            AdditionalData = $AdditionalData
        }
        
        # Output to console
        if (-not $SkipConsoleLog -and $Global:LoggerConfig.OutputTargets -contains "Console") {
            $consoleMessage = "[$timestamp] [$Level] [$Category] $Message"

            if ($Global:LoggerConfig.EnableColors -and $Global:LogColors.ContainsKey($Level)) {
                Write-Host $consoleMessage -ForegroundColor $Global:LogColors[$Level]
            } else {
                Write-Host $consoleMessage
            }
        }

        # Output to file log
        if (-not $SkipFileLog -and $Global:LoggerConfig.OutputTargets -contains "File" -and $Global:LoggerConfig.LogFile) {
            $fileMessage = $logEntry | ConvertTo-Json -Compress
            Add-Content -Path $Global:LoggerConfig.LogFile -Value $fileMessage -Encoding UTF8
        }

        # Output to audit log for important events
        if ($Global:LoggerConfig.EnableAudit -and $Level -in @("ERROR", "CRITICAL", "SUCCESS") -and $Global:LoggerConfig.AuditFile) {
            $auditEntry = @{
                Timestamp = $timestamp
                Level = $Level
                Category = $Category
                Message = $Message
                ProcessId = $PID
                ScriptName = if ($MyInvocation.ScriptName) { Split-Path $MyInvocation.ScriptName -Leaf } else { "Unknown" }
            }
            $auditMessage = $auditEntry | ConvertTo-Json -Compress
            Add-Content -Path $Global:LoggerConfig.AuditFile -Value $auditMessage -Encoding UTF8
        }

    } catch {
        Write-Host "Logging error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

#endregion

#region Convenience Functions

# Information logging
function Write-LogInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Category = "INFO",
        [hashtable]$AdditionalData = @{},
        [switch]$SkipFileLog,
        [switch]$SkipConsoleLog
    )
    Write-AugmentLog -Message $Message -Level "INFO" -Category $Category -AdditionalData $AdditionalData -SkipFileLog:$SkipFileLog -SkipConsoleLog:$SkipConsoleLog
}

# Success logging
function Write-LogSuccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Category = "SUCCESS",
        [hashtable]$AdditionalData = @{},
        [switch]$SkipFileLog,
        [switch]$SkipConsoleLog
    )
    Write-AugmentLog -Message $Message -Level "SUCCESS" -Category $Category -AdditionalData $AdditionalData -SkipFileLog:$SkipFileLog -SkipConsoleLog:$SkipConsoleLog
}

# Warning logging
function Write-LogWarning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Category = "WARNING",
        [hashtable]$AdditionalData = @{},
        [switch]$SkipFileLog,
        [switch]$SkipConsoleLog
    )
    Write-AugmentLog -Message $Message -Level "WARNING" -Category $Category -AdditionalData $AdditionalData -SkipFileLog:$SkipFileLog -SkipConsoleLog:$SkipConsoleLog
}

# Error logging
function Write-LogError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Category = "ERROR",
        [hashtable]$AdditionalData = @{},
        [switch]$SkipFileLog,
        [switch]$SkipConsoleLog
    )
    Write-AugmentLog -Message $Message -Level "ERROR" -Category $Category -AdditionalData $AdditionalData -SkipFileLog:$SkipFileLog -SkipConsoleLog:$SkipConsoleLog
}

# Debug logging
function Write-LogDebug {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Category = "DEBUG",
        [hashtable]$AdditionalData = @{},
        [switch]$SkipFileLog,
        [switch]$SkipConsoleLog
    )
    Write-AugmentLog -Message $Message -Level "DEBUG" -Category $Category -AdditionalData $AdditionalData -SkipFileLog:$SkipFileLog -SkipConsoleLog:$SkipConsoleLog
}

# Critical logging
function Write-LogCritical {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Category = "CRITICAL",
        [hashtable]$AdditionalData = @{},
        [switch]$SkipFileLog,
        [switch]$SkipConsoleLog
    )
    Write-AugmentLog -Message $Message -Level "CRITICAL" -Category $Category -AdditionalData $AdditionalData -SkipFileLog:$SkipFileLog -SkipConsoleLog:$SkipConsoleLog
}

# Audit logging for security and compliance
function Write-AuditLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,
        [Parameter(Mandatory = $true)]
        [string]$Details,
        [string]$Category = "AUDIT"
    )
    Write-AugmentLog -Message "$Action - $Details" -Level "INFO" -Category $Category
}

#endregion

# Functions are automatically available when dot-sourced
# Export-ModuleMember is not needed for dot-sourced scripts

# Module initialization message
if ($VerbosePreference -eq 'Continue') {
    Write-Host "[INFO] AugmentLogger v3.0.0 loaded successfully" -ForegroundColor Green
}
