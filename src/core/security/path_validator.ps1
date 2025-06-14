# Path Validator Module for PowerShell
# Advanced path validation and security checks
# Version: 2.0.0
# Features: Path traversal protection, whitelist/blacklist validation, security scanning

param(
    [switch]$DebugOutput = $false
)

# Import required modules
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$loggingModule = Join-Path (Split-Path -Parent $scriptDir) "logging\unified_logger.ps1"

if (Test-Path $loggingModule) { . $loggingModule }

# Error handling configuration
$ErrorActionPreference = "Stop"
$VerbosePreference = if ($VerbosePreference -eq 'Continue') { "Continue" } else { "SilentlyContinue" }
$DebugPreference = if ($DebugOutput) { "Continue" } else { "SilentlyContinue" }

#region Path Validation Configuration

# Global path validation configuration
$Global:PathValidatorConfig = @{
    MaxPathLength = 4096
    MaxFilenameLength = 255
    MaxDirectoryDepth = 32
    EnableStrictValidation = $true
    EnableSecurityScanning = $true
    CaseSensitive = $false
    AllowUnicodeCharacters = $true
    AllowSpaces = $true
    AllowDots = $true
}

# Security patterns and rules
$Global:SecurityPatterns = @{
    PathTraversal = @(
        '\.\.[\\/]',
        '[\\/]\.\.[\\/]',
        '^\.\.[\\/]',
        '[\\/]\.\.$'
    )
    
    DangerousCharacters = @(
        '[<>:"|?*]',           # Windows invalid characters
        '[\x00-\x1F]',         # Control characters
        '[\x7F-\x9F]',         # Extended control characters
        '\$\{.*\}',            # Variable expansion
        '`.*`',                # Command substitution
        '\$\(.*\)'             # Command substitution
    )
    
    ReservedNames = @(
        '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)',  # Windows reserved names
        '^\.+$',                                         # Dot-only names
        '^\s+$',                                         # Whitespace-only names
        '^-'                                             # Names starting with dash
    )
    
    SuspiciousPatterns = @(
        'eval\s*\(',           # Code evaluation
        'exec\s*\(',           # Code execution
        'system\s*\(',         # System calls
        'shell_exec\s*\(',     # Shell execution
        'passthru\s*\(',       # Command passthrough
        '`[^`]*`',             # Backtick execution
        '\$\([^)]*\)'          # Command substitution
    )
}

# Whitelist and blacklist configurations
$Global:PathWhitelist = @{
    Extensions = @('.json', '.txt', '.log', '.config', '.vscdb', '.db', '.sqlite', '.backup', '.csv', '.xml')
    Directories = @()
    Patterns = @()
}

$Global:PathBlacklist = @{
    Extensions = @('.exe', '.bat', '.cmd', '.com', '.scr', '.pif', '.vbs', '.js', '.jar', '.dll', '.sys')
    Directories = @(
        "$env:WINDIR",
        "$env:PROGRAMFILES",
        "${env:PROGRAMFILES(X86)}",
        "$env:SYSTEMROOT",
        "$env:SYSTEM32"
    )
    Patterns = @(
        'temp.*\.exe$',
        'download.*\.(exe|bat|cmd)$',
        'cache.*\.(dll|sys)$'
    )
}

#endregion

#region Core Validation Functions

# Main path validation function
function Test-PathSecurity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [ValidateSet("File", "Directory", "Any")]
        [string]$PathType = "Any",
        
        [switch]$AllowNonExistent,
        [switch]$StrictMode,
        [switch]$EnableWhitelist,
        [switch]$EnableBlacklist
    )
    
    try {
        Write-LogDebug "Validating path security: $Path (Type: $PathType)" "PATH_VALIDATOR"
        
        # Initialize validation result
        $validationResult = @{
            IsValid = $true
            Errors = @()
            Warnings = @()
            SecurityIssues = @()
            NormalizedPath = ""
            PathType = $PathType
            ValidationTime = Get-Date
        }
        
        # Basic path validation
        $basicValidation = Test-BasicPathValidation -Path $Path
        if (-not $basicValidation.IsValid) {
            $validationResult.IsValid = $false
            $validationResult.Errors += $basicValidation.Errors
        }
        
        # Security pattern validation
        $securityValidation = Test-SecurityPatterns -Path $Path
        if (-not $securityValidation.IsValid) {
            $validationResult.IsValid = $false
            $validationResult.SecurityIssues += $securityValidation.Issues
        }
        
        # Path normalization
        try {
            $validationResult.NormalizedPath = [System.IO.Path]::GetFullPath($Path)
        } catch {
            $validationResult.Errors += "Failed to normalize path: $($_.Exception.Message)"
            $validationResult.IsValid = $false
        }
        
        # Path traversal validation
        $traversalValidation = Test-PathTraversal -Path $validationResult.NormalizedPath
        if (-not $traversalValidation.IsValid) {
            $validationResult.IsValid = $false
            $validationResult.SecurityIssues += $traversalValidation.Issues
        }
        
        # Whitelist validation
        if ($EnableWhitelist) {
            $whitelistValidation = Test-PathWhitelist -Path $validationResult.NormalizedPath
            if (-not $whitelistValidation.IsValid) {
                $validationResult.IsValid = $false
                $validationResult.Errors += $whitelistValidation.Errors
            }
        }
        
        # Blacklist validation
        if ($EnableBlacklist) {
            $blacklistValidation = Test-PathBlacklist -Path $validationResult.NormalizedPath
            if (-not $blacklistValidation.IsValid) {
                $validationResult.IsValid = $false
                $validationResult.SecurityIssues += $blacklistValidation.Issues
            }
        }
        
        # Path type validation
        if (-not $AllowNonExistent -and $validationResult.NormalizedPath) {
            $typeValidation = Test-PathTypeValidation -Path $validationResult.NormalizedPath -ExpectedType $PathType
            if (-not $typeValidation.IsValid) {
                $validationResult.IsValid = $false
                $validationResult.Errors += $typeValidation.Errors
            }
        }
        
        # Log validation result
        if ($validationResult.IsValid) {
            Write-LogDebug "Path validation successful: $Path" "PATH_VALIDATOR"
        } else {
            $errorSummary = "Path validation failed: $Path. Errors: $($validationResult.Errors -join '; '). Security Issues: $($validationResult.SecurityIssues -join '; ')"
            Write-LogWarning $errorSummary "PATH_VALIDATOR"
        }
        
        return $validationResult
        
    } catch {
        Write-LogError "Path validation error: $($_.Exception.Message)" "PATH_VALIDATOR"
        return @{
            IsValid = $false
            Errors = @("Validation process failed: $($_.Exception.Message)")
            Warnings = @()
            SecurityIssues = @()
            NormalizedPath = ""
            PathType = $PathType
            ValidationTime = Get-Date
        }
    }
}

# Basic path validation
function Test-BasicPathValidation {
    [CmdletBinding()]
    param([string]$Path)
    
    $result = @{
        IsValid = $true
        Errors = @()
    }
    
    # Check for null or empty path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $result.IsValid = $false
        $result.Errors += "Path is null or empty"
        return $result
    }
    
    # Check path length
    if ($Path.Length -gt $Global:PathValidatorConfig.MaxPathLength) {
        $result.IsValid = $false
        $result.Errors += "Path exceeds maximum length ($($Global:PathValidatorConfig.MaxPathLength)): $($Path.Length)"
    }
    
    # Check for null bytes
    if ($Path.Contains("`0")) {
        $result.IsValid = $false
        $result.Errors += "Path contains null bytes"
    }
    
    # Check filename length
    $filename = [System.IO.Path]::GetFileName($Path)
    if ($filename.Length -gt $Global:PathValidatorConfig.MaxFilenameLength) {
        $result.IsValid = $false
        $result.Errors += "Filename exceeds maximum length ($($Global:PathValidatorConfig.MaxFilenameLength)): $($filename.Length)"
    }
    
    # Check directory depth
    $pathParts = $Path.Split([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    if ($pathParts.Length -gt $Global:PathValidatorConfig.MaxDirectoryDepth) {
        $result.IsValid = $false
        $result.Errors += "Path exceeds maximum directory depth ($($Global:PathValidatorConfig.MaxDirectoryDepth)): $($pathParts.Length)"
    }
    
    return $result
}

# Security pattern validation
function Test-SecurityPatterns {
    [CmdletBinding()]
    param([string]$Path)
    
    $result = @{
        IsValid = $true
        Issues = @()
    }
    
    # Check dangerous characters
    foreach ($pattern in $Global:SecurityPatterns.DangerousCharacters) {
        if ($Path -match $pattern) {
            $result.IsValid = $false
            $result.Issues += "Path contains dangerous characters matching pattern: $pattern"
        }
    }
    
    # Check reserved names
    $filename = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    foreach ($pattern in $Global:SecurityPatterns.ReservedNames) {
        if ($filename -match $pattern) {
            $result.IsValid = $false
            $result.Issues += "Filename matches reserved name pattern: $pattern"
        }
    }
    
    # Check suspicious patterns
    foreach ($pattern in $Global:SecurityPatterns.SuspiciousPatterns) {
        if ($Path -match $pattern) {
            $result.Issues += "Path contains suspicious pattern: $pattern"
            # Note: This doesn't make IsValid false, just adds to issues
        }
    }
    
    return $result
}

# Path traversal validation
function Test-PathTraversal {
    [CmdletBinding()]
    param([string]$Path)
    
    $result = @{
        IsValid = $true
        Issues = @()
    }
    
    # Check for path traversal patterns
    foreach ($pattern in $Global:SecurityPatterns.PathTraversal) {
        if ($Path -match $pattern) {
            $result.IsValid = $false
            $result.Issues += "Path contains traversal pattern: $pattern"
        }
    }
    
    # Additional traversal checks
    if ($Path.Contains("..")) {
        $result.IsValid = $false
        $result.Issues += "Path contains directory traversal sequence: .."
    }
    
    return $result
}

# Whitelist validation
function Test-PathWhitelist {
    [CmdletBinding()]
    param([string]$Path)
    
    $result = @{
        IsValid = $true
        Errors = @()
    }
    
    # Check extension whitelist
    if ($Global:PathWhitelist.Extensions.Count -gt 0) {
        $extension = [System.IO.Path]::GetExtension($Path).ToLower()
        if ($extension -and $Global:PathWhitelist.Extensions -notcontains $extension) {
            $result.IsValid = $false
            $result.Errors += "File extension not in whitelist: $extension"
        }
    }
    
    # Check directory whitelist
    if ($Global:PathWhitelist.Directories.Count -gt 0) {
        $isInWhitelistedDir = $false
        foreach ($whitelistedDir in $Global:PathWhitelist.Directories) {
            if ($Path.StartsWith($whitelistedDir, [StringComparison]::OrdinalIgnoreCase)) {
                $isInWhitelistedDir = $true
                break
            }
        }
        if (-not $isInWhitelistedDir) {
            $result.IsValid = $false
            $result.Errors += "Path not in whitelisted directory"
        }
    }
    
    # Check pattern whitelist
    if ($Global:PathWhitelist.Patterns.Count -gt 0) {
        $matchesWhitelistPattern = $false
        foreach ($pattern in $Global:PathWhitelist.Patterns) {
            if ($Path -match $pattern) {
                $matchesWhitelistPattern = $true
                break
            }
        }
        if (-not $matchesWhitelistPattern) {
            $result.IsValid = $false
            $result.Errors += "Path does not match any whitelisted pattern"
        }
    }
    
    return $result
}

# Blacklist validation
function Test-PathBlacklist {
    [CmdletBinding()]
    param([string]$Path)
    
    $result = @{
        IsValid = $true
        Issues = @()
    }
    
    # Check extension blacklist
    $extension = [System.IO.Path]::GetExtension($Path).ToLower()
    if ($extension -and $Global:PathBlacklist.Extensions -contains $extension) {
        $result.IsValid = $false
        $result.Issues += "File extension is blacklisted: $extension"
    }
    
    # Check directory blacklist
    foreach ($blacklistedDir in $Global:PathBlacklist.Directories) {
        if ($Path.StartsWith($blacklistedDir, [StringComparison]::OrdinalIgnoreCase)) {
            $result.IsValid = $false
            $result.Issues += "Path is in blacklisted directory: $blacklistedDir"
        }
    }
    
    # Check pattern blacklist
    foreach ($pattern in $Global:PathBlacklist.Patterns) {
        if ($Path -match $pattern) {
            $result.IsValid = $false
            $result.Issues += "Path matches blacklisted pattern: $pattern"
        }
    }
    
    return $result
}

# Path type validation
function Test-PathTypeValidation {
    [CmdletBinding()]
    param(
        [string]$Path,
        [string]$ExpectedType
    )
    
    $result = @{
        IsValid = $true
        Errors = @()
    }
    
    if (-not (Test-Path $Path)) {
        $result.IsValid = $false
        $result.Errors += "Path does not exist: $Path"
        return $result
    }
    
    $item = Get-Item $Path
    
    switch ($ExpectedType) {
        "File" {
            if ($item.PSIsContainer) {
                $result.IsValid = $false
                $result.Errors += "Expected file but found directory: $Path"
            }
        }
        "Directory" {
            if (-not $item.PSIsContainer) {
                $result.IsValid = $false
                $result.Errors += "Expected directory but found file: $Path"
            }
        }
        "Any" {
            # No specific validation needed
        }
    }
    
    return $result
}

#endregion

#region Utility Functions

# Initialize path validator
function Initialize-PathValidator {
    [CmdletBinding()]
    param(
        [string]$ConfigFile = ""
    )
    
    try {
        # Load configuration if provided
        if ($ConfigFile -and (Test-Path $ConfigFile)) {
            $config = Get-Content $ConfigFile | ConvertFrom-Json
            
            # Update configuration
            foreach ($key in $config.PSObject.Properties.Name) {
                if ($Global:PathValidatorConfig.ContainsKey($key)) {
                    $Global:PathValidatorConfig[$key] = $config.$key
                }
            }
            
            # Update whitelist if provided
            if ($config.PSObject.Properties.Name -contains "Whitelist") {
                if ($config.Whitelist.Extensions) {
                    $Global:PathWhitelist.Extensions = $config.Whitelist.Extensions
                }
                if ($config.Whitelist.Directories) {
                    $Global:PathWhitelist.Directories = $config.Whitelist.Directories
                }
                if ($config.Whitelist.Patterns) {
                    $Global:PathWhitelist.Patterns = $config.Whitelist.Patterns
                }
            }
            
            # Update blacklist if provided
            if ($config.PSObject.Properties.Name -contains "Blacklist") {
                if ($config.Blacklist.Extensions) {
                    $Global:PathBlacklist.Extensions = $config.Blacklist.Extensions
                }
                if ($config.Blacklist.Directories) {
                    $Global:PathBlacklist.Directories = $config.Blacklist.Directories
                }
                if ($config.Blacklist.Patterns) {
                    $Global:PathBlacklist.Patterns = $config.Blacklist.Patterns
                }
            }
        }
        
        Write-LogInfo "Path validator initialized successfully" "PATH_VALIDATOR"
        return $true
        
    } catch {
        Write-LogError "Failed to initialize path validator: $($_.Exception.Message)" "PATH_VALIDATOR"
        return $false
    }
}

# Get validation configuration
function Get-PathValidatorConfig {
    [CmdletBinding()]
    param()
    
    return @{
        Config = $Global:PathValidatorConfig.Clone()
        Whitelist = @{
            Extensions = $Global:PathWhitelist.Extensions
            Directories = $Global:PathWhitelist.Directories
            Patterns = $Global:PathWhitelist.Patterns
        }
        Blacklist = @{
            Extensions = $Global:PathBlacklist.Extensions
            Directories = $Global:PathBlacklist.Directories
            Patterns = $Global:PathBlacklist.Patterns
        }
        SecurityPatterns = $Global:SecurityPatterns
    }
}

#endregion

#region Module Export

# Auto-initialize when module is loaded
Initialize-PathValidator | Out-Null

# Export functions
Export-ModuleMember -Function @(
    'Test-PathSecurity',
    'Initialize-PathValidator',
    'Get-PathValidatorConfig'
)

#endregion
