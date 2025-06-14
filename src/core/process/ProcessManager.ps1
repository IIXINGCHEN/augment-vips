# ProcessManager.ps1
# Production-grade VS Code process detection and management module
# Supports multiple VS Code variants with advanced termination strategies

#Requires -Version 5.1

using namespace System.Diagnostics
using namespace System.Management.Automation

# Module-level variables
$script:ProcessConfiguration = $null
$script:DetectedProcesses = @()
$script:LoggingEnabled = $true

# Custom exception types
class ProcessManagerException : System.Exception {
    ProcessManagerException([string]$message) : base($message) {}
    ProcessManagerException([string]$message, [System.Exception]$innerException) : base($message, $innerException) {}
}

class ProcessConfigurationException : ProcessManagerException {
    ProcessConfigurationException([string]$message) : base($message) {}
    ProcessConfigurationException([string]$message, [System.Exception]$innerException) : base($message, $innerException) {}
}

class ProcessDetectionException : ProcessManagerException {
    ProcessDetectionException([string]$message) : base($message) {}
    ProcessDetectionException([string]$message, [System.Exception]$innerException) : base($message, $innerException) {}
}

# Logging functions
function Write-ProcessLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Verbose')]
        [string]$Level = 'Info',
        
        [Parameter(Mandatory = $false)]
        [string]$Component = 'ProcessManager'
    )
    
    if (-not $script:LoggingEnabled) { return }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $logMessage = "[$timestamp] [$Level] [$Component] $Message"
    
    switch ($Level) {
        'Error' { Write-Error $logMessage }
        'Warning' { Write-Warning $logMessage }
        'Debug' { Write-Debug $logMessage }
        'Verbose' { Write-Verbose $logMessage }
        default { Write-Host $logMessage -ForegroundColor Cyan }
    }
}

# Configuration management
class ProcessConfiguration {
    [hashtable]$SupportedProcesses
    [hashtable]$CloseMethods
    [hashtable]$UserInteraction
    [string]$ConfigurationPath
    
    ProcessConfiguration([string]$configPath) {
        $this.ConfigurationPath = $configPath
        $this.LoadConfiguration()
    }
    
    [void]LoadConfiguration() {
        try {
            if (-not (Test-Path $this.ConfigurationPath)) {
                throw [ProcessConfigurationException]::new("Configuration file not found: $($this.ConfigurationPath)")
            }
            
            $configContent = Get-Content $this.ConfigurationPath -Raw -Encoding UTF8
            $config = $configContent | ConvertFrom-Json
            
            $this.SupportedProcesses = @{}
            foreach ($property in $config.supported_processes.PSObject.Properties) {
                $this.SupportedProcesses[$property.Name] = $property.Value
            }
            
            $this.CloseMethods = @{}
            foreach ($property in $config.close_methods.PSObject.Properties) {
                $this.CloseMethods[$property.Name] = $property.Value
            }
            
            $this.UserInteraction = @{}
            foreach ($property in $config.user_interaction.PSObject.Properties) {
                $this.UserInteraction[$property.Name] = $property.Value
            }
            
            Write-ProcessLog "Configuration loaded successfully from: $($this.ConfigurationPath)"
            
        } catch {
            throw [ProcessConfigurationException]::new("Failed to load configuration: $($_.Exception.Message)", $_.Exception)
        }
    }
    
    [bool]ValidateConfiguration() {
        try {
            if ($null -eq $this.SupportedProcesses -or $this.SupportedProcesses.Count -eq 0) {
                throw [ProcessConfigurationException]::new("No supported processes defined in configuration")
            }
            
            if ($null -eq $this.CloseMethods -or $this.CloseMethods.Count -eq 0) {
                throw [ProcessConfigurationException]::new("No close methods defined in configuration")
            }
            
            Write-ProcessLog "Configuration validation passed"
            return $true
            
        } catch {
            Write-ProcessLog "Configuration validation failed: $($_.Exception.Message)" -Level Error
            return $false
        }
    }
}

# Process detection and management
class ProcessDetector {
    [ProcessConfiguration]$Configuration
    [System.Collections.ArrayList]$DetectedProcesses
    
    ProcessDetector([ProcessConfiguration]$config) {
        $this.Configuration = $config
        $this.DetectedProcesses = [System.Collections.ArrayList]::new()
    }
    
    [System.Collections.ArrayList]FindVSCodeProcesses([bool]$detailed = $false) {
        try {
            $this.DetectedProcesses.Clear()
            $allProcesses = Get-Process -ErrorAction SilentlyContinue
            
            Write-ProcessLog "Starting VS Code process detection..."
            
            foreach ($processType in $this.Configuration.SupportedProcesses.Keys) {
                $processInfo = $this.Configuration.SupportedProcesses[$processType]
                $processNames = $processInfo.process_names
                
                foreach ($processName in $processNames) {
                    $nameWithoutExt = $processName -replace '\.exe$', ''
                    
                    $matchingProcesses = $allProcesses | Where-Object { 
                        $_.ProcessName -eq $nameWithoutExt -or 
                        $_.ProcessName -eq $processName -or
                        $_.Name -eq $processName
                    }
                    
                    foreach ($process in $matchingProcesses) {
                        $processDetail = @{
                            Process = $process
                            ProcessId = $process.Id
                            ProcessName = $process.ProcessName
                            DisplayName = $processInfo.display_name
                            Priority = $processInfo.priority
                            CloseMethod = $processInfo.close_method
                            StartTime = $process.StartTime
                            WorkingSetMB = [math]::Round($process.WorkingSet64 / 1MB, 2)
                            MainWindowTitle = $process.MainWindowTitle
                            ProcessType = $processType
                        }
                        
                        $this.DetectedProcesses.Add($processDetail) | Out-Null
                        
                        if ($detailed) {
                            Write-ProcessLog "Detected process: $($processInfo.display_name) (PID: $($process.Id))" -Level Debug
                            Write-ProcessLog "  Process name: $($process.ProcessName)" -Level Debug
                            Write-ProcessLog "  Memory usage: $($processDetail.WorkingSetMB) MB" -Level Debug
                            if ($process.MainWindowTitle) {
                                Write-ProcessLog "  Window title: $($process.MainWindowTitle)" -Level Debug
                            }
                        }
                    }
                }
            }
            
            # Sort by priority
            $sortedProcesses = $this.DetectedProcesses | Sort-Object Priority
            $this.DetectedProcesses.Clear()
            $this.DetectedProcesses.AddRange($sortedProcesses)
            
            if ($this.DetectedProcesses.Count -gt 0) {
                Write-ProcessLog "Detected $($this.DetectedProcesses.Count) VS Code related processes"
            } else {
                Write-ProcessLog "No VS Code related processes detected"
            }
            
            return $this.DetectedProcesses
            
        } catch {
            throw [ProcessDetectionException]::new("Process detection failed: $($_.Exception.Message)", $_.Exception)
        }
    }
    
    [void]DisplayDetectedProcesses() {
        if ($this.DetectedProcesses.Count -eq 0) {
            Write-ProcessLog "No VS Code related processes detected"
            return
        }
        
        Write-ProcessLog "Detected VS Code related processes:"
        Write-Host "=" * 60 -ForegroundColor Yellow
        
        for ($i = 0; $i -lt $this.DetectedProcesses.Count; $i++) {
            $proc = $this.DetectedProcesses[$i]
            Write-Host "[$($i + 1)] $($proc.DisplayName)" -ForegroundColor Cyan
            Write-Host "    Process ID: $($proc.ProcessId)" -ForegroundColor Gray
            Write-Host "    Process Name: $($proc.ProcessName)" -ForegroundColor Gray
            Write-Host "    Memory Usage: $($proc.WorkingSetMB) MB" -ForegroundColor Gray
            Write-Host "    Start Time: $($proc.StartTime)" -ForegroundColor Gray
            if ($proc.MainWindowTitle) {
                Write-Host "    Window Title: $($proc.MainWindowTitle)" -ForegroundColor Gray
            }
            Write-Host ""
        }
    }
}

# Process termination manager
class ProcessTerminator {
    [ProcessConfiguration]$Configuration
    
    ProcessTerminator([ProcessConfiguration]$config) {
        $this.Configuration = $config
    }
    
    [bool]CloseProcessGracefully([System.Diagnostics.Process]$process, [int]$timeoutSeconds = 10) {
        try {
            Write-ProcessLog "Attempting graceful closure of process: $($process.ProcessName) (PID: $($process.Id))"
            
            if ($process.MainWindowHandle -ne [System.IntPtr]::Zero) {
                Write-ProcessLog "Sending close window message..." -Level Debug
                $process.CloseMainWindow() | Out-Null
                
                if ($process.WaitForExit($timeoutSeconds * 1000)) {
                    Write-ProcessLog "Process closed gracefully" -Level Debug
                    return $true
                }
            }
            
            return $false
            
        } catch {
            Write-ProcessLog "Graceful closure failed: $($_.Exception.Message)" -Level Warning
            return $false
        }
    }
    
    [bool]TerminateProcessForcefully([System.Diagnostics.Process]$process, [int]$timeoutSeconds = 5) {
        try {
            Write-ProcessLog "Force terminating process: $($process.ProcessName) (PID: $($process.Id))" -Level Warning

            $process.Refresh()
            if ($process.HasExited) {
                Write-ProcessLog "Process already exited"
                return $true
            }

            $process.Kill()

            if ($process.WaitForExit($timeoutSeconds * 1000)) {
                Write-ProcessLog "Process force terminated successfully"
                return $true
            } else {
                Write-ProcessLog "Process may not have terminated completely" -Level Warning
                return $false
            }

        } catch {
            Write-ProcessLog "Force termination failed: $($_.Exception.Message)" -Level Error
            return $false
        }
    }

    [bool]CloseProcessByMethod([hashtable]$processDetail, [string]$method = "graceful_first") {
        try {
            $process = $processDetail.Process
            $closeMethod = $this.Configuration.CloseMethods[$method]

            if ($null -eq $closeMethod) {
                Write-ProcessLog "Unknown close method: $method, using default" -Level Warning
                $method = "graceful_first"
                $closeMethod = $this.Configuration.CloseMethods[$method]
            }

            Write-ProcessLog "Closing process: $($processDetail.DisplayName) (PID: $($processDetail.ProcessId))"

            foreach ($step in $closeMethod.steps) {
                $process.Refresh()
                if ($process.HasExited) {
                    Write-ProcessLog "Process already exited"
                    return $true
                }

                $success = $false
                switch ($step.method) {
                    "close_main_window" {
                        $success = $this.CloseProcessGracefully($process, $step.timeout)
                    }
                    "terminate_process" {
                        try {
                            Write-ProcessLog "Attempting process termination..." -Level Debug
                            $process.Kill()
                            $success = $process.WaitForExit($step.timeout * 1000)
                        } catch {
                            Write-ProcessLog "Process termination failed: $($_.Exception.Message)" -Level Warning
                        }
                    }
                    "kill_process" {
                        $success = $this.TerminateProcessForcefully($process, $step.timeout)
                    }
                }

                if ($success) {
                    return $true
                }

                Write-ProcessLog "$($step.description) failed, trying next method..." -Level Warning
            }

            Write-ProcessLog "All close methods failed for process: $($processDetail.DisplayName)" -Level Error
            return $false

        } catch {
            Write-ProcessLog "Process closure failed: $($_.Exception.Message)" -Level Error
            return $false
        }
    }

    [hashtable]CloseAllProcesses([System.Collections.ArrayList]$processes) {
        $result = @{
            SuccessCount = 0
            FailureCount = 0
            TotalCount = $processes.Count
            FailedProcesses = @()
        }

        if ($processes.Count -eq 0) {
            Write-ProcessLog "No processes to close"
            return $result
        }

        Write-ProcessLog "Starting closure of $($processes.Count) detected processes..."

        foreach ($processDetail in $processes) {
            try {
                if ($this.CloseProcessByMethod($processDetail, $processDetail.CloseMethod)) {
                    $result.SuccessCount++
                } else {
                    $result.FailureCount++
                    $result.FailedProcesses += $processDetail
                }
            } catch {
                Write-ProcessLog "Exception during process closure: $($_.Exception.Message)" -Level Error
                $result.FailureCount++
                $result.FailedProcesses += $processDetail
            }

            Start-Sleep -Milliseconds 500
        }

        Write-ProcessLog "Process closure results:"
        Write-ProcessLog "  Successfully closed: $($result.SuccessCount)"
        Write-ProcessLog "  Failed to close: $($result.FailureCount)"

        return $result
    }
}

# User interaction manager
class UserInteractionManager {
    [ProcessConfiguration]$Configuration

    UserInteractionManager([ProcessConfiguration]$config) {
        $this.Configuration = $config
    }

    [string]GetUserChoice([System.Collections.ArrayList]$processes) {
        if (-not $this.Configuration.UserInteraction.prompt_before_close) {
            return "force_close"
        }

        Write-Host "Please select an action:" -ForegroundColor Yellow
        Write-Host "[1] Force close all detected processes" -ForegroundColor Red
        Write-Host "[2] Skip process detection and continue" -ForegroundColor Green
        Write-Host "[3] Cancel operation" -ForegroundColor Gray
        Write-Host ""

        do {
            $choice = Read-Host "Enter your choice (1-3)"
            switch ($choice) {
                "1" { return "force_close" }
                "2" { return "skip" }
                "3" { return "cancel" }
                default {
                    Write-Host "Invalid choice. Please enter 1, 2, or 3" -ForegroundColor Red
                }
            }
        } while ($true)

        # This line should never be reached, but PowerShell requires explicit return
        return "cancel"
    }
}

# Main process management orchestrator
class ProcessManager {
    [ProcessConfiguration]$Configuration
    [ProcessDetector]$Detector
    [ProcessTerminator]$Terminator
    [UserInteractionManager]$UserInteraction

    ProcessManager([string]$configPath) {
        try {
            $this.Configuration = [ProcessConfiguration]::new($configPath)
            if (-not $this.Configuration.ValidateConfiguration()) {
                throw [ProcessConfigurationException]::new("Configuration validation failed")
            }

            $this.Detector = [ProcessDetector]::new($this.Configuration)
            $this.Terminator = [ProcessTerminator]::new($this.Configuration)
            $this.UserInteraction = [UserInteractionManager]::new($this.Configuration)

            Write-ProcessLog "ProcessManager initialized successfully"

        } catch {
            throw [ProcessManagerException]::new("ProcessManager initialization failed: $($_.Exception.Message)", $_.Exception)
        }
    }

    [bool]ExecuteProcessDetectionAndHandling([bool]$autoClose = $false, [bool]$interactive = $true) {
        try {
            Write-ProcessLog "=== VS Code Process Detection and Management ===" -Component "ProcessManager"

            $detectedProcesses = $this.Detector.FindVSCodeProcesses($true)

            if ($detectedProcesses.Count -eq 0) {
                Write-ProcessLog "No VS Code related processes detected, safe to continue"
                return $true
            }

            $this.Detector.DisplayDetectedProcesses()

            $action = "skip"  # Default action for non-interactive mode
            if ($autoClose) {
                $action = "force_close"
            } elseif ($interactive) {
                $action = $this.UserInteraction.GetUserChoice($detectedProcesses)
            } else {
                # Non-interactive mode: default to skip to avoid blocking execution
                Write-ProcessLog "Non-interactive mode: continuing with detected processes running (file locks may occur)" -Level Info
                $action = "skip"
            }

            switch ($action) {
                "force_close" {
                    Write-ProcessLog "Force closing all detected processes..." -Level Warning
                    $result = $this.Terminator.CloseAllProcesses($detectedProcesses)
                    return ($result.FailureCount -eq 0)
                }
                "skip" {
                    # Only show warning if this was a user choice in interactive mode
                    if ($interactive) {
                        Write-ProcessLog "Skipping process handling, continuing execution (may encounter file lock issues)" -Level Warning
                    }
                    return $true
                }
                "cancel" {
                    Write-ProcessLog "Operation cancelled by user"
                    return $false
                }
                default {
                    Write-ProcessLog "Unknown action, cancelling execution" -Level Error
                    return $false
                }
            }

            # This line should never be reached, but PowerShell requires explicit return
            return $false

        } catch {
            Write-ProcessLog "Process detection and handling failed: $($_.Exception.Message)" -Level Error
            return $false
        }
    }
}

# Public API Functions
function Load-ProcessConfig {
    <#
    .SYNOPSIS
        Loads process configuration from specified path or default location.

    .DESCRIPTION
        Initializes the process configuration from a JSON file. If no path is specified,
        uses the default configuration file location relative to the script root.

    .PARAMETER ConfigPath
        Optional path to the configuration file. If not specified, uses default location.

    .EXAMPLE
        Load-ProcessConfig
        Load-ProcessConfig -ConfigPath "C:\Config\custom_process_config.json"

    .OUTPUTS
        [bool] Returns $true if configuration loaded successfully, $false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = ""
    )

    try {
        if ([string]::IsNullOrEmpty($ConfigPath)) {
            $ConfigPath = Join-Path $PSScriptRoot "..\..\config\process_config.json"
        }

        $script:ProcessConfiguration = [ProcessConfiguration]::new($ConfigPath)
        return $script:ProcessConfiguration.ValidateConfiguration()

    } catch {
        Write-ProcessLog "Failed to load process configuration: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Find-VSCodeProcesses {
    <#
    .SYNOPSIS
        Detects all VS Code related processes on the system.

    .DESCRIPTION
        Scans the system for VS Code processes based on the loaded configuration.
        Returns detailed information about detected processes.

    .PARAMETER Detailed
        If specified, provides detailed logging during the detection process.

    .EXAMPLE
        Find-VSCodeProcesses
        Find-VSCodeProcesses -Detailed

    .OUTPUTS
        [System.Collections.ArrayList] Array of detected process details.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$Detailed = $false
    )

    try {
        if ($null -eq $script:ProcessConfiguration) {
            if (-not (Load-ProcessConfig)) {
                Write-ProcessLog "Process configuration not available, returning empty result" -Level Warning
                return [System.Collections.ArrayList]::new()
            }
        }

        $detector = [ProcessDetector]::new($script:ProcessConfiguration)
        return $detector.FindVSCodeProcesses($Detailed)

    } catch {
        Write-ProcessLog "Process detection failed: $($_.Exception.Message)" -Level Error
        return [System.Collections.ArrayList]::new()
    }
}

function Show-DetectedProcesses {
    <#
    .SYNOPSIS
        Displays information about detected VS Code processes.

    .DESCRIPTION
        Formats and displays detailed information about the provided process list.

    .PARAMETER Processes
        Array of process details to display.

    .EXAMPLE
        $processes = Find-VSCodeProcesses
        Show-DetectedProcesses -Processes $processes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList]$Processes
    )

    try {
        if ($null -eq $script:ProcessConfiguration) {
            Write-ProcessLog "Process configuration not available" -Level Warning
            return
        }

        $detector = [ProcessDetector]::new($script:ProcessConfiguration)
        $detector.DetectedProcesses = $Processes
        $detector.DisplayDetectedProcesses()

    } catch {
        Write-ProcessLog "Failed to display processes: $($_.Exception.Message)" -Level Error
    }
}

function Close-AllDetectedProcesses {
    <#
    .SYNOPSIS
        Closes all processes in the provided list using configured methods.

    .DESCRIPTION
        Attempts to close all processes using the termination strategies defined
        in the configuration. Returns detailed results about the operation.

    .PARAMETER Processes
        Array of process details to close.

    .EXAMPLE
        $processes = Find-VSCodeProcesses
        $result = Close-AllDetectedProcesses -Processes $processes

    .OUTPUTS
        [hashtable] Results containing success/failure counts and details.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList]$Processes
    )

    try {
        if ($null -eq $script:ProcessConfiguration) {
            Write-ProcessLog "Process configuration not available" -Level Error
            return @{ SuccessCount = 0; FailureCount = 0; TotalCount = 0; FailedProcesses = @() }
        }

        $terminator = [ProcessTerminator]::new($script:ProcessConfiguration)
        return $terminator.CloseAllProcesses($Processes)

    } catch {
        Write-ProcessLog "Failed to close processes: $($_.Exception.Message)" -Level Error
        return @{ SuccessCount = 0; FailureCount = $Processes.Count; TotalCount = $Processes.Count; FailedProcesses = $Processes }
    }
}

function Invoke-ProcessDetectionAndHandling {
    <#
    .SYNOPSIS
        Main entry point for VS Code process detection and management.

    .DESCRIPTION
        Orchestrates the complete process detection and handling workflow including
        user interaction, process detection, and termination based on user choice.

    .PARAMETER AutoClose
        If specified, automatically closes detected processes without user interaction.

    .PARAMETER Interactive
        If specified, prompts user for action when processes are detected.

    .EXAMPLE
        Invoke-ProcessDetectionAndHandling
        Invoke-ProcessDetectionAndHandling -AutoClose $true
        Invoke-ProcessDetectionAndHandling -Interactive $false

    .OUTPUTS
        [bool] Returns $true if operation completed successfully, $false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$AutoClose = $false,

        [Parameter(Mandatory = $false)]
        [bool]$Interactive = $true
    )

    try {
        $configPath = Join-Path $PSScriptRoot "..\..\config\process_config.json"
        $processManager = [ProcessManager]::new($configPath)
        return $processManager.ExecuteProcessDetectionAndHandling($AutoClose, $Interactive)

    } catch {
        Write-ProcessLog "Process detection and handling failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# Module initialization
try {
    Write-ProcessLog "ProcessManager module loaded successfully" -Component "ModuleInit"
} catch {
    Write-Error "Failed to initialize ProcessManager module: $($_.Exception.Message)"
}
