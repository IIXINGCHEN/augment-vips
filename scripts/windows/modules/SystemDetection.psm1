# SystemDetection.psm1
#
# Description: System compatibility detection module
# Detects Windows version, PowerShell version, and required dependencies
#
# Author: Augment VIP Project
# Version: 1.0.0

# Import Logger module
Import-Module (Join-Path $PSScriptRoot "Logger.psm1") -Force

# Import DependencyManager module
Import-Module (Join-Path $PSScriptRoot "DependencyManager.psm1") -Force

# Import CommonUtils module
Import-Module (Join-Path $PSScriptRoot "CommonUtils.psm1") -Force

# System requirements
$script:MinWindowsVersion = [Version]"10.0.0.0"
$script:MinPowerShellVersion = [Version]"5.1.0.0"
$script:RequiredDependencies = @("sqlite3", "curl", "jq")

<#
.SYNOPSIS
    Performs comprehensive system compatibility check
.DESCRIPTION
    Checks Windows version, PowerShell version, and required dependencies
.PARAMETER SkipDependencies
    Skip dependency checking
.OUTPUTS
    System.Boolean - True if system is compatible
#>
function Test-SystemCompatibility {
    [CmdletBinding()]
    param(
        [switch]$SkipDependencies
    )
    
    Write-LogInfo "Starting system compatibility check..."
    
    $isCompatible = $true
    
    # Check Windows version
    if (-not (Test-WindowsVersion)) {
        $isCompatible = $false
    }
    
    # Check PowerShell version
    if (-not (Test-PowerShellVersion)) {
        $isCompatible = $false
    }
    
    # Check dependencies with enhanced management
    if (-not $SkipDependencies) {
        $dependencyStatus = Get-DependencyStatus
        if ($dependencyStatus.MissingDependencies.Count -gt 0) {
            Write-LogWarning "Missing dependencies detected: $($dependencyStatus.MissingDependencies -join ', ')"
            Write-LogInfo "Use Invoke-DependencyManagement to automatically install missing dependencies"
        } else {
            Write-LogSuccess "All dependencies are available"
        }
    }
    
    # Check execution policy
    if (-not (Test-ExecutionPolicy)) {
        Write-LogWarning "PowerShell execution policy may prevent script execution"
    }
    
    # Check administrator privileges
    Test-AdministratorPrivileges
    
    if ($isCompatible) {
        Write-LogSuccess "System compatibility check passed"
    } else {
        Write-LogError "System compatibility check failed"
    }
    
    return $isCompatible
}

<#
.SYNOPSIS
    Checks Windows version compatibility
.OUTPUTS
    System.Boolean - True if Windows version is supported
#>
function Test-WindowsVersion {
    [CmdletBinding()]
    param()

    try {
        $osVersion = [System.Environment]::OSVersion.Version
        $osName = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
        
        Write-LogInfo "Detected OS: $osName (Version: $osVersion)"
        
        if ($osVersion -ge $script:MinWindowsVersion) {
            Write-LogSuccess "Windows version is supported"
            return $true
        } else {
            Write-LogError "Windows version $osVersion is not supported. Minimum required: $($script:MinWindowsVersion)"
            return $false
        }
    }
    catch {
        Write-LogError "Failed to detect Windows version" -Exception $_.Exception
        return $false
    }
}

<#
.SYNOPSIS
    Checks PowerShell version compatibility
.OUTPUTS
    System.Boolean - True if PowerShell version is supported
#>
function Test-PowerShellVersion {
    [CmdletBinding()]
    param()

    try {
        $psVersion = $PSVersionTable.PSVersion
        $psEdition = $PSVersionTable.PSEdition
        
        Write-LogInfo "Detected PowerShell: $psEdition $psVersion"
        
        if ($psVersion -ge $script:MinPowerShellVersion) {
            Write-LogSuccess "PowerShell version is supported"
            return $true
        } else {
            Write-LogError "PowerShell version $psVersion is not supported. Minimum required: $($script:MinPowerShellVersion)"
            return $false
        }
    }
    catch {
        Write-LogError "Failed to detect PowerShell version" -Exception $_.Exception
        return $false
    }
}

<#
.SYNOPSIS
    Checks for required dependencies
.OUTPUTS
    System.Boolean - True if all dependencies are available
#>
function Test-Dependencies {
    [CmdletBinding()]
    param()

    Write-LogInfo "Checking required dependencies..."
    
    $missingDeps = @()
    $availableDeps = @()
    
    foreach ($dep in $script:RequiredDependencies) {
        Write-LogDebug "Checking for dependency: $dep"
        
        $command = Get-Command $dep -ErrorAction SilentlyContinue
        if ($command) {
            $availableDeps += $dep
            Write-LogDebug "Found $dep at: $($command.Source)"
        } else {
            $missingDeps += $dep
        }
    }
    
    # Report results
    if ($availableDeps.Count -gt 0) {
        Write-LogSuccess "Available dependencies: $($availableDeps -join ', ')"
    }
    
    if ($missingDeps.Count -gt 0) {
        Write-LogWarning "Missing dependencies: $($missingDeps -join ', ')"
        Write-LogInfo "To install missing dependencies on Windows:"
        Write-LogInfo "  Using Chocolatey: choco install $($missingDeps -join ' ')"
        Write-LogInfo "  Using Scoop: scoop install $($missingDeps -join ' ')"
        Write-LogInfo "  Using winget: winget install $($missingDeps -join ' ')"
        return $false
    }
    
    Write-LogSuccess "All dependencies are available"
    return $true
}

<#
.SYNOPSIS
    Enhanced dependency checking with automatic installation option
.PARAMETER AutoInstall
    Automatically install missing dependencies
.PARAMETER SkipInstall
    Only check dependencies, don't install
.OUTPUTS
    System.Boolean - True if all dependencies are available
#>
function Test-DependenciesEnhanced {
    [CmdletBinding()]
    param(
        [switch]$AutoInstall,
        [switch]$SkipInstall
    )

    Write-LogInfo "Enhanced dependency checking..."

    try {
        return Invoke-DependencyManagement -AutoInstall:$AutoInstall -SkipInstall:$SkipInstall
    }
    catch {
        Write-LogError "Enhanced dependency check failed, falling back to basic check" -Exception $_.Exception
        return Test-Dependencies
    }
}

<#
.SYNOPSIS
    Checks PowerShell execution policy
.OUTPUTS
    System.Boolean - True if execution policy allows script execution
#>
function Test-ExecutionPolicy {
    [CmdletBinding()]
    param()

    try {
        $policy = Get-ExecutionPolicy
        Write-LogInfo "Current execution policy: $policy"
        
        $allowedPolicies = @("Unrestricted", "RemoteSigned", "Bypass")
        
        if ($policy -in $allowedPolicies) {
            Write-LogSuccess "Execution policy allows script execution"
            return $true
        } else {
            Write-LogWarning "Execution policy '$policy' may prevent script execution"
            Write-LogInfo "To change execution policy, run as administrator:"
            Write-LogInfo "  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
            return $false
        }
    }
    catch {
        Write-LogError "Failed to check execution policy" -Exception $_.Exception
        return $false
    }
}

<#
.SYNOPSIS
    Checks if running with administrator privileges
.OUTPUTS
    System.Boolean - True if running as administrator
#>
function Test-AdministratorPrivileges {
    [CmdletBinding()]
    param()

    try {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if ($isAdmin) {
            Write-LogSuccess "Running with administrator privileges"
        } else {
            Write-LogInfo "Running without administrator privileges"
            Write-LogInfo "Some operations may require administrator rights"
        }

        return $isAdmin
    }
    catch {
        Write-LogError "Failed to check administrator privileges" -Exception $_.Exception
        return $false
    }
}

<#
.SYNOPSIS
    Enforces administrator privileges for critical operations
.PARAMETER OperationName
    Name of the operation requiring admin privileges
.PARAMETER AllowContinue
    Allow operation to continue without admin privileges (with warning)
.OUTPUTS
    System.Boolean - True if admin privileges are available or operation can continue
#>
function Assert-AdminPrivileges {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OperationName,
        [switch]$AllowContinue
    )

    try {
        $isAdmin = Test-AdministratorPrivileges

        if (-not $isAdmin) {
            $message = "Operation '$OperationName' requires administrator privileges"

            if ($AllowContinue) {
                Show-WarningMessage "$message - Continuing with limited functionality"
                Show-WarningMessage "Some features may not work correctly without admin rights"
                return $true
            } else {
                Show-ErrorMessage $message
                Show-ErrorMessage "Please restart PowerShell as Administrator to perform this operation"
                Show-InfoMessage "Right-click PowerShell and select 'Run as Administrator'"
                return $false
            }
        }

        Write-LogDebug "Administrator privileges confirmed for operation: $OperationName"
        return $true
    }
    catch {
        Write-LogError "Failed to verify administrator privileges for operation: $OperationName" -Exception $_.Exception

        if ($AllowContinue) {
            Write-LogWarning "Continuing operation despite privilege check failure"
            return $true
        }

        return $false
    }
}

<#
.SYNOPSIS
    Checks if the current user has write access to a specific path
.PARAMETER Path
    Path to check for write access
.OUTPUTS
    System.Boolean - True if write access is available
#>
function Test-WriteAccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    try {
        # SECURITY FIX: Enhanced input validation
        if (-not (Test-SafePath -Path $Path)) {
            Write-LogWarning "SECURITY: Unsafe path detected: $Path"
            return $false
        }

        # Ensure the directory exists
        $directory = if (Test-Path $Path -PathType Container) {
            $Path
        } else {
            Split-Path $Path -Parent
        }

        if (-not (Test-Path $directory)) {
            Write-LogDebug "Directory does not exist: $directory"
            return $false
        }

        # Try to create a temporary file to test write access
        # Use secure random number generation
        $randomBytes = New-Object byte[] 8
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($randomBytes)
        $rng.Dispose()
        $randomHex = [System.BitConverter]::ToString($randomBytes) -replace '-', ''
        $testFile = Join-Path $directory "write_test_$randomHex.tmp"

        try {
            "test" | Out-File -FilePath $testFile -Force
            Remove-Item $testFile -Force -ErrorAction SilentlyContinue
            Write-LogDebug "Write access confirmed for: $directory"
            return $true
        }
        catch {
            Write-LogDebug "Write access denied for: $directory"
            return $false
        }
    }
    catch {
        Write-LogError "Failed to test write access for: $Path" -Exception $_.Exception
        return $false
    }
}

<#
.SYNOPSIS
    Gets detailed system information
.OUTPUTS
    System.Collections.Hashtable - System information
#>
function Get-SystemInformation {
    [CmdletBinding()]
    param()

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $computer = Get-CimInstance -ClassName Win32_ComputerSystem
        $processor = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
        
        # Check admin privileges directly to avoid circular dependency
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        $systemInfo = @{
            ComputerName = $computer.Name
            OSName = $os.Caption
            OSVersion = $os.Version
            OSArchitecture = $os.OSArchitecture
            TotalMemoryGB = [Math]::Round($computer.TotalPhysicalMemory / 1GB, 2)
            ProcessorName = $processor.Name
            ProcessorCores = $processor.NumberOfCores
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            PowerShellEdition = $PSVersionTable.PSEdition
            ExecutionPolicy = Get-ExecutionPolicy
            IsAdmin = $isAdmin
            UserName = $env:USERNAME
            UserDomain = $env:USERDOMAIN
        }
        
        return $systemInfo
    }
    catch {
        Write-LogError "Failed to gather system information" -Exception $_.Exception
        return @{}
    }
}

<#
.SYNOPSIS
    Displays system information summary
#>
function Show-SystemInformation {
    [CmdletBinding()]
    param()

    Write-LogInfo "=== System Information ==="
    
    $sysInfo = Get-SystemInformation
    
    foreach ($key in $sysInfo.Keys | Sort-Object) {
        Write-LogInfo "$key`: $($sysInfo[$key])"
    }
    
    Write-LogInfo "=========================="
}

<#
.SYNOPSIS
    Checks if the system meets minimum requirements for VS Code operations
.OUTPUTS
    System.Boolean - True if system meets requirements
#>
function Test-VSCodeOperationRequirements {
    [CmdletBinding()]
    param()

    Write-LogInfo "Checking VS Code operation requirements..."
    
    $requirements = @{
        "File System Access" = Test-Path $env:APPDATA
        "Registry Access" = $true  # Will be tested when needed
        "SQLite Support" = (Get-Command sqlite3 -ErrorAction SilentlyContinue) -ne $null
        "JSON Processing" = $true  # PowerShell native support
        "Backup Space" = Test-DiskSpace
    }
    
    $allMet = $true
    foreach ($req in $requirements.GetEnumerator()) {
        if ($req.Value) {
            Write-LogSuccess "$($req.Key): Available"
        } else {
            Write-LogError "$($req.Key): Not available"
            $allMet = $false
        }
    }
    
    return $allMet
}

<#
.SYNOPSIS
    Checks available disk space for backup operations
.OUTPUTS
    System.Boolean - True if sufficient disk space is available
#>
function Test-DiskSpace {
    [CmdletBinding()]
    param()

    try {
        $systemDrive = $env:SystemDrive
        $drive = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $systemDrive }
        
        if ($drive) {
            $freeSpaceGB = [Math]::Round($drive.FreeSpace / 1GB, 2)
            Write-LogInfo "Available disk space on $systemDrive`: $freeSpaceGB GB"
            
            # Require at least 1GB free space for backup operations
            if ($freeSpaceGB -ge 1) {
                return $true
            } else {
                Write-LogWarning "Low disk space: $freeSpaceGB GB available"
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-LogError "Failed to check disk space" -Exception $_.Exception
        return $true  # Assume OK if we can't check
    }
}

<#
.SYNOPSIS
    Loads and validates project configuration
.PARAMETER ConfigPath
    Path to configuration file
.OUTPUTS
    PSCustomObject - Configuration object
#>
function Get-ProjectConfiguration {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = ".\config\config.json"
    )

    try {
        if (-not (Test-Path $ConfigPath)) {
            Write-LogWarning "Configuration file not found: $ConfigPath"
            return $null
        }

        $configContent = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        Write-LogDebug "Loaded configuration from: $ConfigPath"
        return $configContent
    }
    catch {
        Write-LogError "Failed to load configuration" -Exception $_.Exception
        return $null
    }
}

<#
.SYNOPSIS
    Gets the list of required modules from configuration
.OUTPUTS
    string[] - Array of module names
#>
function Get-RequiredModules {
    [CmdletBinding()]
    param()

    $config = Get-ProjectConfiguration
    if ($config -and $config.modules -and $config.modules.windows -and $config.modules.windows.required) {
        return $config.modules.windows.required
    }

    # Fallback to hardcoded list if config is not available
    Write-LogWarning "Using fallback module list"
    return @("Logger", "SystemDetection", "VSCodeDiscovery", "BackupManager", "DatabaseCleaner", "TelemetryModifier")
}

# Export module functions
Export-ModuleMember -Function @(
    'Test-SystemCompatibility',
    'Test-WindowsVersion',
    'Test-PowerShellVersion',
    'Test-Dependencies',
    'Test-DependenciesEnhanced',
    'Test-ExecutionPolicy',
    'Test-AdministratorPrivileges',
    'Assert-AdminPrivileges',
    'Test-WriteAccess',
    'Get-SystemInformation',
    'Show-SystemInformation',
    'Test-VSCodeOperationRequirements',
    'Test-DiskSpace',
    'Get-ProjectConfiguration',
    'Get-RequiredModules'
)
