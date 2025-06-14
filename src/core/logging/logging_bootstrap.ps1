# logging_bootstrap.ps1
# Bootstrap logging functions for Augment VIP
# Provides basic logging functionality before full logging system is loaded
# Version: 1.0.0

# Global logging configuration
$script:LoggingBootstrapLoaded = $false
$script:LogLevel = "INFO"
$script:LogFile = $null
$script:EnableConsoleOutput = $true

function Ensure-LoggingAvailable {
    <#
    .SYNOPSIS
        Ensures basic logging functions are available
    .PARAMETER ScriptName
        Name of the script for logging context
    #>
    param([string]$ScriptName = "AugmentVIP")
    
    if ($script:LoggingBootstrapLoaded) {
        return
    }
    
    # Define basic logging functions if they don't exist
    if (-not (Get-Command Write-LogInfo -ErrorAction SilentlyContinue)) {
        function global:Write-LogInfo {
            param([string]$Message, [string]$Category = "")
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logMessage = "[$timestamp] [INFO] $(if($Category){"[$Category] "})$Message"
            if ($script:EnableConsoleOutput) {
                Write-Host $logMessage -ForegroundColor White
            }
            if ($script:LogFile) {
                Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction SilentlyContinue
            }
        }
    }
    
    if (-not (Get-Command Write-LogSuccess -ErrorAction SilentlyContinue)) {
        function global:Write-LogSuccess {
            param([string]$Message, [string]$Category = "")
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logMessage = "[$timestamp] [SUCCESS] $(if($Category){"[$Category] "})$Message"
            if ($script:EnableConsoleOutput) {
                Write-Host $logMessage -ForegroundColor Green
            }
            if ($script:LogFile) {
                Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction SilentlyContinue
            }
        }
    }
    
    if (-not (Get-Command Write-LogWarning -ErrorAction SilentlyContinue)) {
        function global:Write-LogWarning {
            param([string]$Message, [string]$Category = "")
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logMessage = "[$timestamp] [WARNING] $(if($Category){"[$Category] "})$Message"
            if ($script:EnableConsoleOutput) {
                Write-Host $logMessage -ForegroundColor Yellow
            }
            if ($script:LogFile) {
                Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction SilentlyContinue
            }
        }
    }
    
    if (-not (Get-Command Write-LogError -ErrorAction SilentlyContinue)) {
        function global:Write-LogError {
            param([string]$Message, [string]$Category = "")
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logMessage = "[$timestamp] [ERROR] $(if($Category){"[$Category] "})$Message"
            if ($script:EnableConsoleOutput) {
                Write-Host $logMessage -ForegroundColor Red
            }
            if ($script:LogFile) {
                Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction SilentlyContinue
            }
        }
    }
    
    if (-not (Get-Command Write-LogDebug -ErrorAction SilentlyContinue)) {
        function global:Write-LogDebug {
            param([string]$Message, [string]$Category = "")
            if ($VerbosePreference -eq "Continue" -or $script:LogLevel -eq "DEBUG") {
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $logMessage = "[$timestamp] [DEBUG] $(if($Category){"[$Category] "})$Message"
                if ($script:EnableConsoleOutput) {
                    Write-Host $logMessage -ForegroundColor Gray
                }
                if ($script:LogFile) {
                    Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction SilentlyContinue
                }
            }
        }
    }
    
    if (-not (Get-Command Write-LogCritical -ErrorAction SilentlyContinue)) {
        function global:Write-LogCritical {
            param([string]$Message, [string]$Category = "")
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logMessage = "[$timestamp] [CRITICAL] $(if($Category){"[$Category] "})$Message"
            if ($script:EnableConsoleOutput) {
                Write-Host $logMessage -ForegroundColor Magenta
            }
            if ($script:LogFile) {
                Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction SilentlyContinue
            }
        }
    }
    
    $script:LoggingBootstrapLoaded = $true
    Write-LogDebug "Logging bootstrap loaded for $ScriptName" "BOOTSTRAP"
}

function Set-LoggingBootstrapConfig {
    <#
    .SYNOPSIS
        Configures the logging bootstrap
    #>
    param(
        [string]$LogLevel = "INFO",
        [string]$LogFile = $null,
        [bool]$EnableConsoleOutput = $true
    )
    
    $script:LogLevel = $LogLevel
    $script:LogFile = $LogFile
    $script:EnableConsoleOutput = $EnableConsoleOutput
    
    Write-LogDebug "Logging bootstrap configured: Level=$LogLevel, File=$LogFile, Console=$EnableConsoleOutput" "BOOTSTRAP"
}

# Auto-initialize if called directly
if ($MyInvocation.InvocationName -ne '.') {
    Ensure-LoggingAvailable
}
