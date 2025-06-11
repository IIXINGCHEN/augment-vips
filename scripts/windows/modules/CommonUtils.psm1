# CommonUtils.psm1
#
# Description: Common utilities module for VS Code cleanup operations
# Provides unified ID generation, configuration management, and error handling
#
# Author: Augment VIP Project
# Version: 1.0.0

# Import required modules for consistent logging and ID generation
Import-Module (Join-Path $PSScriptRoot "Logger.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "UnifiedServices.psm1") -Force

# Module variables for configuration caching and optimization
$script:ConfigCache = $null
$script:ConfigLastModified = $null
$script:GlobalConfigInstance = $null

# Configuration access optimization
function Get-GlobalConfig {
    [CmdletBinding()]
    param()

    if ($script:GlobalConfigInstance -eq $null) {
        $script:GlobalConfigInstance = Get-Configuration
    }
    return $script:GlobalConfigInstance
}

# Clear configuration cache (useful for testing)
function Clear-ConfigCache {
    [CmdletBinding()]
    param()

    $script:ConfigCache = $null
    $script:ConfigLastModified = $null
    $script:GlobalConfigInstance = $null
    Write-LogDebug "Configuration cache cleared"
}

# Common VS Code paths configuration
$script:VSCodePaths = @{
    Windows = @{
        Standard = @(
            "$env:APPDATA\Code\User\",
            "$env:LOCALAPPDATA\Programs\Microsoft VS Code\"
        )
        Insiders = @(
            "$env:APPDATA\Code - Insiders\User\",
            "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\"
        )
        Portable = @(
            ".\data\user-data\User\",
            ".\Code\data\user-data\User\"
        )
    }
    Linux = @(
        "~/.config/Code/User/",
        "~/.vscode/",
        "~/.config/Code - Insiders/User/"
    )
    MacOS = @(
        "~/Library/Application Support/Code/User/",
        "~/Library/Application Support/Code - Insiders/User/"
    )
}

# Note: New-SecureUUID and New-SecureHexString functions removed to eliminate code duplication
# Use New-UnifiedSecureId from UnifiedServices.psm1 for all ID generation needs
# This provides consistent, secure ID generation with automatic fallback mechanisms

<#
.SYNOPSIS
    Gets VS Code installation paths for the current platform
.PARAMETER Platform
    Target platform (Windows, Linux, MacOS)
.PARAMETER InstallationType
    Type of installation (Standard, Insiders, Portable)
.OUTPUTS
    string[] - Array of potential paths
#>
function Get-VSCodePaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Windows', 'Linux', 'MacOS')]
        [string]$Platform = 'Windows',
        [Parameter(Mandatory = $false)]
        [ValidateSet('Standard', 'Insiders', 'Portable', 'All')]
        [string]$InstallationType = 'All'
    )
    
    $paths = @()
    
    try {
        if ($Platform -eq 'Windows') {
            if ($InstallationType -in @('Standard', 'All')) {
                $paths += $script:VSCodePaths.Windows.Standard
            }
            if ($InstallationType -in @('Insiders', 'All')) {
                $paths += $script:VSCodePaths.Windows.Insiders
            }
            if ($InstallationType -in @('Portable', 'All')) {
                $paths += $script:VSCodePaths.Windows.Portable
            }
        }
        elseif ($Platform -eq 'Linux') {
            $paths += $script:VSCodePaths.Linux
        }
        elseif ($Platform -eq 'MacOS') {
            $paths += $script:VSCodePaths.MacOS
        }
        
        Write-LogDebug "Retrieved $($paths.Count) VS Code paths for $Platform ($InstallationType)"
        return $paths
    }
    catch {
        Write-LogError "Failed to get VS Code paths" -Exception $_.Exception
        return @()
    }
}

<#
.SYNOPSIS
    Loads and caches configuration from config.json
.OUTPUTS
    PSCustomObject - Configuration object
#>
function Get-Configuration {
    [CmdletBinding()]
    param()
    
    try {
        $configPath = Join-Path $PSScriptRoot "..\..\..\config\config.json"
        
        # Check if config file exists
        if (-not (Test-Path $configPath)) {
            Write-LogWarning "Configuration file not found: $configPath"
            return $null
        }
        
        # Check if we need to reload config (file modified or not cached)
        $configModified = (Get-Item $configPath).LastWriteTime
        if ($script:ConfigCache -eq $null -or $script:ConfigLastModified -ne $configModified) {
            Write-LogDebug "Loading configuration from: $configPath"
            $configContent = Get-Content -Path $configPath -Raw | ConvertFrom-Json
            $script:ConfigCache = $configContent
            $script:ConfigLastModified = $configModified
        }
        
        return $script:ConfigCache
    }
    catch {
        Write-LogError "Failed to load configuration" -Exception $_.Exception
        return $null
    }
}

<#
.SYNOPSIS
    Generic error handling wrapper for common operations
.PARAMETER ScriptBlock
    The script block to execute with error handling
.PARAMETER ErrorMessage
    Custom error message prefix
.PARAMETER ReturnOnError
    Value to return on error (default: $null)
#>
function Invoke-SafeOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$ScriptBlock,
        [string]$ErrorMessage = "Operation failed",
        [object]$ReturnOnError = $null
    )
    
    try {
        return & $ScriptBlock
    }
    catch {
        Write-LogError "$ErrorMessage" -Exception $_.Exception
        return $ReturnOnError
    }
}

<#
.SYNOPSIS
    Generates a secure random filename for temporary files
.PARAMETER Prefix
    Optional prefix for the filename
.PARAMETER Extension
    File extension (default: .tmp)
.OUTPUTS
    string - Secure random filename
#>
function New-SecureFileName {
    [CmdletBinding()]
    param(
        [string]$Prefix = "temp",
        [string]$Extension = ".tmp"
    )

    try {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        # Use unified service for consistent ID generation
        $randomPart = New-UnifiedSecureId -IdType "hex" -Length 16
        $filename = "${Prefix}_${timestamp}_${randomPart}${Extension}"

        Write-LogDebug "Generated secure filename: $filename"
        return $filename
    }
    catch {
        Write-LogError "Failed to generate secure filename" -Exception $_.Exception
        # Fallback to timestamp-based filename (still secure)
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
        $fallback = "${Prefix}_${timestamp}${Extension}"
        Write-LogWarning "Using fallback filename: $fallback"
        return $fallback
    }
}

<#
.SYNOPSIS
    Validates file path to prevent directory traversal attacks
.PARAMETER Path
    File path to validate
.OUTPUTS
    bool - True if path is safe, False otherwise
#>
function Test-SafePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Path
    )

    try {
        # Check for null or empty path - return false for empty paths
        if ([string]::IsNullOrWhiteSpace($Path)) {
            Write-LogDebug "Empty or null path provided - returning false"
            return $false
        }

        # Enhanced security: Check for dangerous patterns with balanced validation
        $dangerousPatterns = @(
            '\.\.[\\/]',     # Parent directory traversal - SECURITY FIX
            '\.\.\\',        # Windows parent directory traversal - SECURITY FIX
            '\.\.\/',        # Unix parent directory traversal - SECURITY FIX
            '[<>"|?*]',      # Invalid filename characters (removed : to allow drive letters)
            '^\s*$',         # Empty or whitespace-only
            '\x00',          # Null bytes
            '\$\{',          # Variable expansion attempts
            '`',             # PowerShell escape character
            ';',             # Command separator
            '&',             # Command separator
            '\|'             # Pipe character
        )

        foreach ($pattern in $dangerousPatterns) {
            if ($Path -match $pattern) {
                Write-LogWarning "SECURITY: Dangerous pattern '$pattern' detected in path: $Path"
                return $false
            }
        }

        # Enhanced path validation with security checks
        try {
            # Allow absolute paths in system directories for legitimate operations
            $isSystemPath = $false
            $systemPaths = @(
                $env:TEMP,
                $env:TMP,
                $env:APPDATA,
                $env:LOCALAPPDATA,
                $env:USERPROFILE
            )

            foreach ($sysPath in $systemPaths) {
                if ($sysPath -and $Path.StartsWith($sysPath, [StringComparison]::OrdinalIgnoreCase)) {
                    $isSystemPath = $true
                    break
                }
            }

            # For non-system paths, check relative path constraints
            if (-not $isSystemPath) {
                $resolvedPath = Resolve-Path $Path -ErrorAction SilentlyContinue
                if ($resolvedPath) {
                    $currentDir = Get-Location
                    $relativePath = [System.IO.Path]::GetRelativePath($currentDir, $resolvedPath)

                    if ($relativePath.StartsWith('..')) {
                        Write-LogWarning "Path resolves outside current directory: $Path"
                        return $false
                    }
                }
            }
        } catch {
            # Path doesn't exist yet, which is okay for new files
            Write-LogDebug "Path validation: $Path (new file)"
        }

        return $true
    }
    catch {
        Write-LogError "Path validation failed for: $Path" -Exception $_.Exception
        return $false
    }
}

<#
.SYNOPSIS
    Safely executes a command without using Invoke-Expression
.PARAMETER Command
    Command to execute
.PARAMETER Arguments
    Command arguments
.OUTPUTS
    Process exit code
#>
function Invoke-SafeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Command,
        [ValidateNotNull()]
        [string[]]$Arguments = @()
    )

    try {
        # Validate command path for security
        if (-not (Test-SafePath -Path $Command)) {
            throw "Unsafe command path detected: $Command"
        }

        # Validate arguments for injection attempts
        foreach ($arg in $Arguments) {
            if ($arg -match '[;&|`$<>]') {
                Write-LogWarning "Potentially dangerous characters detected in argument: $arg"
            }
        }

        Write-LogDebug "Executing safe command: $Command with arguments: $($Arguments -join ' ')"

        # Use more secure process execution
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $Command
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true

        # Add arguments safely
        foreach ($arg in $Arguments) {
            if ($null -ne $arg -and $arg -ne "") {
                $processInfo.ArgumentList.Add($arg)
            }
        }

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null
        $process.WaitForExit()

        return $process.ExitCode
    }
    catch {
        Write-LogError "Safe command execution failed: $Command" -Exception $_.Exception
        return -1
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Get-VSCodePaths',
    'Get-Configuration',
    'Get-GlobalConfig',
    'Clear-ConfigCache',
    'Invoke-SafeOperation',
    'New-SecureFileName',
    'Test-SafePath',
    'Invoke-SafeCommand'
)
