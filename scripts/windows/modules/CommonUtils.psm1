# CommonUtils.psm1
#
# Description: Common utilities module for VS Code cleanup operations
# Provides unified ID generation, configuration management, and error handling
#
# Author: Augment VIP Project
# Version: 1.0.0

# Import Logger module for consistent logging
Import-Module (Join-Path $PSScriptRoot "Logger.psm1") -Force

# Module variables for configuration caching
$script:ConfigCache = $null
$script:ConfigLastModified = $null

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

<#
.SYNOPSIS
    Generates a cryptographically secure UUID (Version 4)
.DESCRIPTION
    Creates a RFC 4122 compliant UUID v4 using cryptographically secure random number generation
.OUTPUTS
    string - Secure UUID
#>
function New-SecureUUID {
    [CmdletBinding()]
    param()

    try {
        # Generate random bytes for UUID
        $bytes = New-Object byte[] 16
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($bytes)
        $rng.Dispose()
        
        # Set version (4) and variant bits according to RFC 4122
        $bytes[6] = ($bytes[6] -band 0x0F) -bor 0x40  # Version 4
        $bytes[8] = ($bytes[8] -band 0x3F) -bor 0x80  # Variant 10
        
        # Format as UUID string
        $uuid = [System.Guid]::new($bytes).ToString()
        Write-LogDebug "Generated secure UUID: $uuid"
        return $uuid
    }
    catch {
        Write-LogError "Failed to generate secure UUID" -Exception $_.Exception
        # Fallback to .NET Guid if crypto fails
        $fallbackUuid = [System.Guid]::NewGuid().ToString()
        Write-LogWarning "Using fallback UUID generation: $fallbackUuid"
        return $fallbackUuid
    }
}

<#
.SYNOPSIS
    Generates a cryptographically secure hexadecimal string
.PARAMETER Length
    Length of the hex string to generate
.OUTPUTS
    string - Secure hex string
#>
function New-SecureHexString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Length
    )
    
    if ($Length -le 0) {
        throw "Length must be greater than 0"
    }
    
    try {
        # Calculate number of bytes needed (2 hex chars per byte)
        $byteCount = [Math]::Ceiling($Length / 2)
        
        # Generate random bytes using cryptographically secure RNG
        $bytes = New-Object byte[] $byteCount
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($bytes)
        $rng.Dispose()
        
        # Convert to hex string and trim to exact length
        $hexString = [System.BitConverter]::ToString($bytes).Replace("-", "").ToLower()
        $result = $hexString.Substring(0, [Math]::Min($hexString.Length, $Length))
        
        Write-LogDebug "Generated secure hex string of length: $($result.Length)"
        return $result
    }
    catch {
        Write-LogError "Failed to generate secure hex string" -Exception $_.Exception
        throw
    }
}

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
        $randomPart = New-SecureHexString -Length 16
        $filename = "${Prefix}_${timestamp}_${randomPart}${Extension}"
        
        Write-LogDebug "Generated secure filename: $filename"
        return $filename
    }
    catch {
        Write-LogError "Failed to generate secure filename" -Exception $_.Exception
        # Fallback to basic random
        $fallback = "${Prefix}_$(Get-Date -Format 'yyyyMMdd_HHmmss')_$(Get-Random)${Extension}"
        Write-LogWarning "Using fallback filename: $fallback"
        return $fallback
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'New-SecureUUID',
    'New-SecureHexString',
    'Get-VSCodePaths',
    'Get-Configuration',
    'Invoke-SafeOperation',
    'New-SecureFileName'
)
