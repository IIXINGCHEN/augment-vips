# DependencyManager.psm1
#
# Description: Dependency management module for Augment VIP
# Handles automatic detection and installation of required dependencies
#
# Author: Augment VIP Project
# Version: 1.0.0

# Import Logger module
Import-Module (Join-Path $PSScriptRoot "Logger.psm1") -Force

# Required dependencies configuration
$script:RequiredDependencies = @{
    "sqlite3" = @{
        Name = "sqlite3"
        Description = "SQLite command-line tool"
        ChocolateyPackage = "sqlite"
        ScoopPackage = "sqlite"
        WingetPackage = "SQLite.SQLite"
        TestCommand = "sqlite3 --version"
    }
    "curl" = @{
        Name = "curl"
        Description = "Command-line HTTP client"
        ChocolateyPackage = "curl"
        ScoopPackage = "curl"
        WingetPackage = "cURL.cURL"
        TestCommand = "curl --version"
    }
    "jq" = @{
        Name = "jq"
        Description = "JSON processor"
        ChocolateyPackage = "jq"
        ScoopPackage = "jq"
        WingetPackage = "jqlang.jq"
        TestCommand = "jq --version"
    }
}

# Package manager configurations
$script:PackageManagers = @{
    "Chocolatey" = @{
        Name = "Chocolatey"
        TestCommand = "choco --version"
        InstallCommand = "choco install {0} -y"
        Priority = 1
    }
    "Scoop" = @{
        Name = "Scoop"
        TestCommand = "scoop --version"
        InstallCommand = "scoop install {0}"
        Priority = 2
    }
    "Winget" = @{
        Name = "Windows Package Manager"
        TestCommand = "winget --version"
        InstallCommand = "winget install {0} --accept-package-agreements --accept-source-agreements"
        Priority = 3
    }
}

<#
.SYNOPSIS
    Tests if a package manager is available
.PARAMETER ManagerName
    Name of the package manager to test
.OUTPUTS
    System.Boolean - True if package manager is available
#>
function Test-PackageManager {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManagerName
    )
    
    if (-not $script:PackageManagers.ContainsKey($ManagerName)) {
        Write-LogError "Unknown package manager: $ManagerName"
        return $false
    }
    
    $manager = $script:PackageManagers[$ManagerName]
    $testCommand = $manager.TestCommand
    
    try {
        # Safe command execution with validation
        if ([string]::IsNullOrWhiteSpace($testCommand)) {
            Write-LogWarning "Empty test command for $($manager.Name)"
            return $false
        }

        # Validate command for dangerous characters
        if ($testCommand -match '[;&|`$<>]') {
            Write-LogWarning "Potentially dangerous characters in command: $testCommand"
            return $false
        }

        $commandParts = $testCommand -split '\s+'
        $executable = $commandParts[0]
        $arguments = $commandParts[1..($commandParts.Length-1)]

        # Additional validation for executable path
        if (-not $executable -or $executable -match '[;&|`$<>]') {
            Write-LogWarning "Invalid executable path: $executable"
            return $false
        }

        # Enhanced security: Validate and escape arguments
        $validatedArguments = @()
        foreach ($arg in $arguments) {
            if ($null -ne $arg -and $arg -ne "") {
                # Remove dangerous characters and validate
                $cleanArg = $arg -replace '[;&|`$<>]', ''
                if ($cleanArg -ne $arg) {
                    Write-LogWarning "Sanitized dangerous characters from argument: $arg -> $cleanArg"
                }
                $validatedArguments += $cleanArg
            }
        }

        # Use secure process execution with validated arguments
        $processArgs = @{
            FilePath = $executable
            ArgumentList = $validatedArguments
            NoNewWindow = $true
            Wait = $true
            PassThru = $true
            ErrorAction = 'SilentlyContinue'
        }
        $process = Start-Process @processArgs
        if ($process.ExitCode -eq 0) {
            Write-LogDebug "$($manager.Name) is available"
            return $true
        }
    }
    catch {
        Write-LogDebug "$($manager.Name) is not available: $($_.Exception.Message)"
    }
    
    return $false
}

<#
.SYNOPSIS
    Gets available package managers sorted by priority
.OUTPUTS
    System.Array - Array of available package manager names
#>
function Get-AvailablePackageManagers {
    [CmdletBinding()]
    param()
    
    $availableManagers = @()
    
    foreach ($managerName in $script:PackageManagers.Keys) {
        if (Test-PackageManager -ManagerName $managerName) {
            $availableManagers += @{
                Name = $managerName
                Priority = $script:PackageManagers[$managerName].Priority
            }
        }
    }
    
    # Sort by priority (lower number = higher priority)
    $sortedManagers = $availableManagers | Sort-Object Priority | ForEach-Object { $_.Name }
    
    return $sortedManagers
}

<#
.SYNOPSIS
    Installs Chocolatey package manager
.OUTPUTS
    System.Boolean - True if installation was successful
#>
function Install-Chocolatey {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Installing Chocolatey package manager..."
    
    try {
        # Check if running as administrator
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            Write-LogWarning "Administrator privileges recommended for Chocolatey installation"
        }
        
        # Set execution policy temporarily
        $originalPolicy = Get-ExecutionPolicy
        Set-ExecutionPolicy Bypass -Scope Process -Force
        
        # Download and install Chocolatey using safe method
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

        # Use secure method to install Chocolatey
        $installUri = 'https://community.chocolatey.org/install.ps1'
        Write-LogDebug "Downloading Chocolatey installer from: $installUri"

        # Download script to temporary file for security validation
        $tempScript = Join-Path $env:TEMP "chocolatey-install-$(Get-Date -Format 'yyyyMMddHHmmss').ps1"

        try {
            # Download with security validation
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($installUri, $tempScript)

            # Basic security check on downloaded script
            $scriptContent = Get-Content $tempScript -Raw
            if ($scriptContent -match 'Invoke-Expression|iex|cmd|powershell.*-c') {
                Write-LogWarning "Downloaded script contains potentially dangerous commands"
            }

            # Execute the installer with restricted scope
            & $tempScript

        } finally {
            # Clean up temporary file
            if (Test-Path $tempScript) {
                Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Restore original execution policy
        Set-ExecutionPolicy $originalPolicy -Scope Process -Force
        
        # Verify installation
        if (Test-PackageManager -ManagerName "Chocolatey") {
            Write-LogSuccess "Chocolatey installed successfully"
            return $true
        } else {
            Write-LogError "Chocolatey installation verification failed"
            return $false
        }
    }
    catch {
        Write-LogError "Failed to install Chocolatey" -Exception $_.Exception
        return $false
    }
}

<#
.SYNOPSIS
    Tests if a dependency is available
.PARAMETER DependencyName
    Name of the dependency to test
.OUTPUTS
    System.Boolean - True if dependency is available
#>
function Test-Dependency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Alias("Name")]
        [string]$DependencyName
    )

    if (-not $script:RequiredDependencies.ContainsKey($DependencyName)) {
        Write-LogError "Unknown dependency: $DependencyName"
        return $false
    }

    $dependency = $script:RequiredDependencies[$DependencyName]
    $testCommand = $dependency.TestCommand

    try {
        # Try using Get-Command first (more reliable for PATH detection)
        $command = Get-Command $dependency.Name -ErrorAction SilentlyContinue
        if ($command) {
            Write-LogDebug "$($dependency.Name) is available at: $($command.Source)"
            return $true
        }

        # Fallback to safe command execution
        try {
            # Validate command before execution
            if ([string]::IsNullOrWhiteSpace($testCommand)) {
                Write-LogWarning "Empty test command for $($dependency.Name)"
                return $false
            }

            # Check for dangerous characters
            if ($testCommand -match '[;&|`$<>]') {
                Write-LogWarning "Potentially dangerous characters in command: $testCommand"
                return $false
            }

            # Parse command safely
            $commandParts = $testCommand -split '\s+'
            $executable = $commandParts[0]
            $arguments = $commandParts[1..($commandParts.Length-1)]

            # Additional validation for executable
            if (-not $executable -or $executable -match '[;&|`$<>]') {
                Write-LogWarning "Invalid executable path: $executable"
                return $false
            }

            # Execute with Start-Process for security
            # Enhanced security: Validate and escape arguments
            $validatedArguments = @()
            foreach ($arg in $arguments) {
                if ($null -ne $arg -and $arg -ne "") {
                    # Remove dangerous characters and validate
                    $cleanArg = $arg -replace '[;&|`$<>]', ''
                    if ($cleanArg -ne $arg) {
                        Write-LogWarning "Sanitized dangerous characters from argument: $arg -> $cleanArg"
                    }
                    $validatedArguments += $cleanArg
                }
            }

            # Use secure process execution with validated arguments
            $processArgs = @{
                FilePath = $executable
                ArgumentList = $validatedArguments
                NoNewWindow = $true
                Wait = $true
                PassThru = $true
                ErrorAction = 'SilentlyContinue'
            }
            $process = Start-Process @processArgs
            if ($process.ExitCode -eq 0) {
                Write-LogDebug "$($dependency.Name) is available"
                return $true
            }
        } catch {
            Write-LogDebug "Safe command execution failed for $($dependency.Name)"
        }
    }
    catch {
        Write-LogDebug "$($dependency.Name) is not available: $($_.Exception.Message)"
    }

    return $false
}

<#
.SYNOPSIS
    Gets missing dependencies
.OUTPUTS
    System.Array - Array of missing dependency names
#>
function Get-MissingDependencies {
    [CmdletBinding()]
    param()

    $missingDeps = @()

    foreach ($depName in $script:RequiredDependencies.Keys) {
        if (-not (Test-Dependency -DependencyName $depName)) {
            $missingDeps += $depName
        }
    }

    return $missingDeps
}

<#
.SYNOPSIS
    Installs a dependency using the specified package manager
.PARAMETER DependencyName
    Name of the dependency to install
.PARAMETER PackageManager
    Package manager to use for installation
.OUTPUTS
    System.Boolean - True if installation was successful
#>
function Install-Dependency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DependencyName,

        [Parameter(Mandatory = $true)]
        [string]$PackageManager
    )

    if (-not $script:RequiredDependencies.ContainsKey($DependencyName)) {
        Write-LogError "Unknown dependency: $DependencyName"
        return $false
    }

    if (-not $script:PackageManagers.ContainsKey($PackageManager)) {
        Write-LogError "Unknown package manager: $PackageManager"
        return $false
    }

    $dependency = $script:RequiredDependencies[$DependencyName]
    $manager = $script:PackageManagers[$PackageManager]

    # Get the package name for this manager
    $packageName = switch ($PackageManager) {
        "Chocolatey" { $dependency.ChocolateyPackage }
        "Scoop" { $dependency.ScoopPackage }
        "Winget" { $dependency.WingetPackage }
        default { $dependency.Name }
    }

    Write-LogInfo "Installing $($dependency.Description) using $($manager.Name)..."

    try {
        $installCommand = $manager.InstallCommand -f $packageName
        Write-LogDebug "Executing: $installCommand"

        # Safe command execution with validation
        if ([string]::IsNullOrWhiteSpace($installCommand)) {
            Write-LogError "Empty install command"
            return $false
        }

        # Validate command for dangerous characters
        if ($installCommand -match '[;&|`$<>]') {
            Write-LogWarning "Potentially dangerous characters in install command: $installCommand"
            return $false
        }

        $commandParts = $installCommand -split '\s+'
        $executable = $commandParts[0]
        $arguments = $commandParts[1..($commandParts.Length-1)]

        # Additional validation for executable
        if (-not $executable -or $executable -match '[;&|`$<>]') {
            Write-LogError "Invalid executable path: $executable"
            return $false
        }

        # Enhanced security: Validate and escape arguments
        $validatedArguments = @()
        foreach ($arg in $arguments) {
            if ($null -ne $arg -and $arg -ne "") {
                # Remove dangerous characters and validate
                $cleanArg = $arg -replace '[;&|`$<>]', ''
                if ($cleanArg -ne $arg) {
                    Write-LogWarning "Sanitized dangerous characters from argument: $arg -> $cleanArg"
                }
                $validatedArguments += $cleanArg
            }
        }

        # Use secure process execution with validated arguments
        $processArgs = @{
            FilePath = $executable
            ArgumentList = $validatedArguments
            NoNewWindow = $true
            Wait = $true
            PassThru = $true
            ErrorAction = 'Stop'
        }
        $process = Start-Process @processArgs
        $result = $process.ExitCode

        if ($result -eq 0) {
            # Refresh environment variables to pick up newly installed tools
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

            # Wait a moment for the installation to complete
            Start-Sleep -Seconds 2

            # Verify installation
            if (Test-Dependency -DependencyName $DependencyName) {
                Write-LogSuccess "$($dependency.Description) installed successfully"
                return $true
            } else {
                Write-LogWarning "$($dependency.Description) installation completed but verification failed"
                Write-LogDebug "PATH after refresh: $env:Path"
                return $false
            }
        } else {
            Write-LogError "$($dependency.Description) installation failed with exit code: $result"
            return $false
        }
    }
    catch {
        Write-LogError "Failed to install $($dependency.Description)" -Exception $_.Exception
        return $false
    }
}

<#
.SYNOPSIS
    Prompts user for confirmation to install dependencies
.PARAMETER MissingDependencies
    Array of missing dependency names
.OUTPUTS
    System.Boolean - True if user confirms installation
#>
function Confirm-AutoInstall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$MissingDependencies
    )

    if ($MissingDependencies.Count -eq 0) {
        return $true
    }

    Write-LogWarning "The following dependencies are missing:"
    foreach ($dep in $MissingDependencies) {
        $dependency = $script:RequiredDependencies[$dep]
        Write-LogWarning "  - $($dependency.Description) ($($dependency.Name))"
    }

    Write-Host ""
    Write-Host "Would you like to automatically install these dependencies? (Y/N): " -NoNewline -ForegroundColor Yellow
    $response = Read-Host

    return ($response -match '^[Yy]')
}

<#
.SYNOPSIS
    Installs all missing dependencies (skips already installed ones)
.PARAMETER AutoConfirm
    Skip user confirmation and install automatically
.PARAMETER Force
    Force reinstallation of all dependencies, even if already installed
.OUTPUTS
    System.Boolean - True if all dependencies were installed successfully
#>
function Install-MissingDependencies {
    [CmdletBinding()]
    param(
        [switch]$AutoConfirm,
        [switch]$Force
    )

    Write-LogInfo "Checking dependency status..."

    # Get current dependency status
    $allDeps = $script:RequiredDependencies.Keys
    $availableDeps = @()
    $missingDeps = @()

    foreach ($dep in $allDeps) {
        if (Test-Dependency -DependencyName $dep) {
            $availableDeps += $dep
        } else {
            $missingDeps += $dep
        }
    }

    # Report current status
    if ($availableDeps.Count -gt 0) {
        Write-LogSuccess "Already installed dependencies: $($availableDeps -join ', ')"
    }

    if ($missingDeps.Count -eq 0 -and -not $Force) {
        Write-LogSuccess "All required dependencies are already installed - skipping installation"
        return $true
    }

    if ($Force) {
        Write-LogInfo "Force mode enabled - will reinstall all dependencies"
        $depsToInstall = $allDeps
    } else {
        Write-LogInfo "Missing dependencies that need installation: $($missingDeps -join ', ')"
        $depsToInstall = $missingDeps
    }

    # Get user confirmation unless auto-confirm is enabled
    if (-not $AutoConfirm -and -not (Confirm-AutoInstall -MissingDependencies $depsToInstall)) {
        Write-LogInfo "Dependency installation cancelled by user"
        return $false
    }

    # Get available package managers
    $availableManagers = Get-AvailablePackageManagers

    if ($availableManagers.Count -eq 0) {
        Write-LogWarning "No package managers available. Attempting to install Chocolatey..."

        if (Install-Chocolatey) {
            $availableManagers = @("Chocolatey")
        } else {
            Write-LogError "Failed to install Chocolatey. Manual installation required."
            Show-ManualInstallInstructions -MissingDependencies $missingDeps
            return $false
        }
    }

    Write-LogInfo "Using package manager: $($availableManagers[0])"
    $selectedManager = $availableManagers[0]

    # Install each dependency that needs installation
    $successCount = 0
    $failCount = 0
    $skippedCount = 0

    foreach ($dep in $depsToInstall) {
        # Skip if already installed (unless Force mode)
        if (-not $Force -and (Test-Dependency -DependencyName $dep)) {
            Write-LogInfo "Skipping $dep - already installed"
            $skippedCount++
            continue
        }

        Write-LogInfo "Installing $dep..."
        if (Install-Dependency -DependencyName $dep -PackageManager $selectedManager) {
            $successCount++
        } else {
            $failCount++
            Write-LogWarning "Failed to install $dep, trying alternative methods..."

            # Try other package managers as fallback
            $installed = $false
            for ($i = 1; $i -lt $availableManagers.Count; $i++) {
                $fallbackManager = $availableManagers[$i]
                Write-LogInfo "Trying $fallbackManager as fallback..."

                if (Install-Dependency -DependencyName $dep -PackageManager $fallbackManager) {
                    $successCount++
                    $failCount--
                    $installed = $true
                    break
                }
            }

            if (-not $installed) {
                Write-LogError "All installation methods failed for $dep"
            }
        }
    }

    # Report results
    Write-LogInfo "Installation summary:"
    Write-LogInfo "  Successfully installed: $successCount dependencies"
    if ($skippedCount -gt 0) {
        Write-LogInfo "  Skipped (already installed): $skippedCount dependencies"
    }
    if ($failCount -gt 0) {
        Write-LogWarning "  Failed to install: $failCount dependencies"
    }

    # Final verification
    $finalMissing = Get-MissingDependencies
    if ($finalMissing.Count -gt 0) {
        Write-LogWarning "Dependencies still missing after installation: $($finalMissing -join ', ')"
        Show-ManualInstallInstructions -MissingDependencies $finalMissing
        return $false
    } else {
        Write-LogSuccess "All required dependencies are now available!"
        return $true
    }
}

<#
.SYNOPSIS
    Shows manual installation instructions for missing dependencies
.PARAMETER MissingDependencies
    Array of missing dependency names
#>
function Show-ManualInstallInstructions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$MissingDependencies
    )

    Write-LogInfo "Manual installation instructions:"
    Write-LogInfo "================================="

    foreach ($dep in $MissingDependencies) {
        $dependency = $script:RequiredDependencies[$dep]
        Write-LogInfo " "
        Write-LogInfo "$($dependency.Description) ($($dependency.Name)):"

        # Chocolatey
        Write-LogInfo "  Using Chocolatey:"
        Write-LogInfo "    choco install $($dependency.ChocolateyPackage) -y"

        # Scoop
        Write-LogInfo "  Using Scoop:"
        Write-LogInfo "    scoop install $($dependency.ScoopPackage)"

        # Winget
        Write-LogInfo "  Using Windows Package Manager:"
        Write-LogInfo "    winget install $($dependency.WingetPackage)"
    }

    Write-LogInfo " "
    Write-LogInfo "After manual installation, run the script again to continue."
}

<#
.SYNOPSIS
    Main dependency management function
.PARAMETER AutoInstall
    Automatically install missing dependencies without user confirmation
.PARAMETER SkipInstall
    Only check dependencies, don't install
.PARAMETER Force
    Force reinstallation of all dependencies, even if already installed
.OUTPUTS
    System.Boolean - True if all dependencies are available
#>
function Invoke-DependencyManagement {
    [CmdletBinding()]
    param(
        [switch]$AutoInstall,
        [switch]$SkipInstall,
        [switch]$Force
    )

    Write-LogInfo "Starting dependency management..."

    # Check current status
    $missingDeps = Get-MissingDependencies
    $availableDeps = @()

    foreach ($depName in $script:RequiredDependencies.Keys) {
        if (Test-Dependency -DependencyName $depName) {
            $availableDeps += $depName
        }
    }

    # Report current status
    if ($availableDeps.Count -gt 0) {
        Write-LogSuccess "Available dependencies: $($availableDeps -join ', ')"
    }

    if ($missingDeps.Count -eq 0) {
        Write-LogSuccess "All required dependencies are available"
        return $true
    }

    Write-LogWarning "Missing dependencies: $($missingDeps -join ', ')"

    if ($SkipInstall) {
        Write-LogInfo "Skipping installation as requested"
        Show-ManualInstallInstructions -MissingDependencies $missingDeps
        return $false
    }

    # Attempt to install missing dependencies
    return Install-MissingDependencies -AutoConfirm:$AutoInstall -Force:$Force
}

<#
.SYNOPSIS
    Gets dependency status report
.OUTPUTS
    PSCustomObject - Dependency status information
#>
function Get-DependencyStatus {
    [CmdletBinding()]
    param()

    $status = @{
        TotalDependencies = $script:RequiredDependencies.Count
        AvailableDependencies = @()
        MissingDependencies = @()
        AvailablePackageManagers = @()
    }

    # Check dependencies
    foreach ($depName in $script:RequiredDependencies.Keys) {
        if (Test-Dependency -DependencyName $depName) {
            $status.AvailableDependencies += $depName
        } else {
            $status.MissingDependencies += $depName
        }
    }

    # Check package managers
    $status.AvailablePackageManagers = Get-AvailablePackageManagers

    return [PSCustomObject]$status
}

# Export module functions
Export-ModuleMember -Function @(
    'Test-PackageManager',
    'Get-AvailablePackageManagers',
    'Install-Chocolatey',
    'Test-Dependency',
    'Get-MissingDependencies',
    'Install-Dependency',
    'Confirm-AutoInstall',
    'Install-MissingDependencies',
    'Show-ManualInstallInstructions',
    'Invoke-DependencyManagement',
    'Get-DependencyStatus'
)
