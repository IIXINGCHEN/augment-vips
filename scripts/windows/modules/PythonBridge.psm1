# PythonBridge.psm1 - Python Bridge Module for Augment VIP
# Provides Python integration and bridge functionality

# Import required modules
Import-Module (Join-Path $PSScriptRoot "Logger.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "CommonUtils.psm1") -Force

# Module variables
$script:PythonPath = $null
$script:PythonVersion = $null
$script:IsPythonAvailable = $false

<#
.SYNOPSIS
    Tests if Python is available on the system
.DESCRIPTION
    Checks for Python installation and validates version compatibility
.OUTPUTS
    Boolean indicating Python availability
#>
function Test-PythonAvailability {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogInfo "Checking Python availability..."
        
        # Try to find Python executable
        $pythonCommands = @('python', 'python3', 'py')
        
        foreach ($cmd in $pythonCommands) {
            try {
                $result = & $cmd --version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $script:PythonPath = (Get-Command $cmd).Source
                    $script:PythonVersion = $result.ToString().Trim()
                    $script:IsPythonAvailable = $true
                    
                    Write-LogInfo "Python found: $($script:PythonVersion) at $($script:PythonPath)"
                    return $true
                }
            }
            catch {
                continue
            }
        }
        
        Write-LogWarning "Python not found on system"
        $script:IsPythonAvailable = $false
        return $false
    }
    catch {
        Write-LogError "Error checking Python availability: $($_.Exception.Message)"
        $script:IsPythonAvailable = $false
        return $false
    }
}

<#
.SYNOPSIS
    Executes a Python script
.DESCRIPTION
    Runs a Python script with specified arguments and returns the result
.PARAMETER ScriptPath
    Path to the Python script to execute
.PARAMETER Arguments
    Arguments to pass to the Python script
.OUTPUTS
    Execution result object with output and exit code
#>
function Invoke-PythonScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory = $false)]
        [string[]]$Arguments = @()
    )
    
    try {
        if (-not $script:IsPythonAvailable) {
            if (-not (Test-PythonAvailability)) {
                throw "Python is not available on this system"
            }
        }
        
        if (-not (Test-Path $ScriptPath)) {
            throw "Python script not found: $ScriptPath"
        }
        
        Write-LogInfo "Executing Python script: $ScriptPath"
        
        $processArgs = @($ScriptPath) + $Arguments
        $process = Start-Process -FilePath $script:PythonPath -ArgumentList $processArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput -RedirectStandardError
        
        $output = $process.StandardOutput.ReadToEnd()
        $error = $process.StandardError.ReadToEnd()
        
        $result = @{
            ExitCode = $process.ExitCode
            Output = $output
            Error = $error
            Success = ($process.ExitCode -eq 0)
        }
        
        if ($result.Success) {
            Write-LogInfo "Python script executed successfully"
        } else {
            Write-LogError "Python script failed with exit code: $($result.ExitCode)"
            if ($result.Error) {
                Write-LogError "Error output: $($result.Error)"
            }
        }
        
        return $result
    }
    catch {
        Write-LogError "Error executing Python script: $($_.Exception.Message)"
        return @{
            ExitCode = -1
            Output = ""
            Error = $_.Exception.Message
            Success = $false
        }
    }
}

<#
.SYNOPSIS
    Gets Python installation information
.DESCRIPTION
    Returns detailed information about the Python installation
.OUTPUTS
    Hashtable with Python installation details
#>
function Get-PythonInfo {
    [CmdletBinding()]
    param()
    
    if (-not $script:IsPythonAvailable) {
        Test-PythonAvailability | Out-Null
    }
    
    return @{
        IsAvailable = $script:IsPythonAvailable
        Path = $script:PythonPath
        Version = $script:PythonVersion
    }
}

<#
.SYNOPSIS
    Initializes the Python bridge module
.DESCRIPTION
    Performs initial setup and validation for Python integration
#>
function Initialize-PythonBridge {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogInfo "Initializing Python bridge module..."
        
        $available = Test-PythonAvailability
        
        if ($available) {
            Write-LogSuccess "Python bridge initialized successfully"
        } else {
            Write-LogWarning "Python bridge initialized in fallback mode (Python not available)"
        }
        
        return $available
    }
    catch {
        Write-LogError "Failed to initialize Python bridge: $($_.Exception.Message)"
        return $false
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Test-PythonAvailability',
    'Invoke-PythonScript', 
    'Get-PythonInfo',
    'Initialize-PythonBridge'
)

# Initialize module on import
Initialize-PythonBridge | Out-Null
