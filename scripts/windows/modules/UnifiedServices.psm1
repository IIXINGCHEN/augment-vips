# UnifiedServices.psm1
#
# Description: Bridge module to integrate PowerShell with unified Python services
# Provides access to configuration loader, ID generator, and transaction manager
#
# Author: Augment VIP Project
# Version: 1.0.0

# Import required modules
Import-Module (Join-Path $PSScriptRoot "Logger.psm1") -Force

# Global variables for service integration
$script:PythonPath = $null
$script:CommonScriptsPath = $null
$script:ServicesAvailable = $false

<#
.SYNOPSIS
    Initialize unified services integration
.DESCRIPTION
    Sets up the bridge to Python unified services
#>
function Initialize-UnifiedServices {
    [CmdletBinding()]
    param()
    
    try {
        # Find Python executable
        $script:PythonPath = Get-PythonPath
        if (-not $script:PythonPath) {
            Write-LogWarning "Python not found, unified services will use fallback implementations"
            return $false
        }
        
        # SECURITY FIX: Set common scripts path using safe path resolution with validation
        $relativePath = "..\..\common"
        # Validate the relative path doesn't contain dangerous traversal patterns
        if ($relativePath -match '\.\.[\\/].*\.\.[\\/]') {
            Write-LogWarning "SECURITY: Potentially dangerous path traversal detected in: $relativePath"
            return $false
        }

        $script:CommonScriptsPath = Resolve-Path (Join-Path $PSScriptRoot $relativePath) -ErrorAction SilentlyContinue
        if (-not $script:CommonScriptsPath -or -not (Test-Path $script:CommonScriptsPath)) {
            Write-LogWarning "Common scripts path not found or invalid: $script:CommonScriptsPath"
            return $false
        }

        # Additional security check: Ensure resolved path is within expected boundaries
        $expectedBasePath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        if (-not $script:CommonScriptsPath.Path.StartsWith($expectedBasePath)) {
            Write-LogWarning "SECURITY: Resolved path is outside expected boundaries: $($script:CommonScriptsPath.Path)"
            return $false
        }
        
        # Test service availability
        $testResult = Test-UnifiedServices
        $script:ServicesAvailable = $testResult
        
        if ($testResult) {
            Write-LogInfo "Unified services initialized successfully"
        } else {
            Write-LogWarning "Unified services initialization failed, using fallback implementations"
        }
        
        return $testResult
    }
    catch {
        Write-LogError "Failed to initialize unified services" -Exception $_.Exception
        $script:ServicesAvailable = $false
        return $false
    }
}

<#
.SYNOPSIS
    Get Python executable path
.OUTPUTS
    string - Path to Python executable or null if not found
#>
function Get-PythonPath {
    [CmdletBinding()]
    param()
    
    $pythonCommands = @('python', 'python3', 'py')
    
    foreach ($cmd in $pythonCommands) {
        try {
            $pythonPath = Get-Command $cmd -ErrorAction SilentlyContinue
            if ($pythonPath) {
                # Test if it's actually Python
                $version = & $pythonPath --version 2>&1
                if ($version -match "Python \d+\.\d+") {
                    Write-LogDebug "Found Python at: $($pythonPath.Source)"
                    return $pythonPath.Source
                }
            }
        }
        catch {
            continue
        }
    }
    
    return $null
}

<#
.SYNOPSIS
    Test if unified services are available
.OUTPUTS
    bool - True if services are available
#>
function Test-UnifiedServices {
    [CmdletBinding()]
    param()
    
    if (-not $script:PythonPath -or -not $script:CommonScriptsPath) {
        return $false
    }
    
    try {
        # Test config loader
        $configTest = & $script:PythonPath -c "
import sys
sys.path.append('$($script:CommonScriptsPath.Replace('\', '\\'))')
try:
    from config_loader import get_config_loader
    print('config_loader_ok')
except ImportError as e:
    print(f'config_loader_error: {e}')
"
        
        if ($configTest -notmatch "config_loader_ok") {
            Write-LogDebug "Config loader test failed: $configTest"
            return $false
        }
        
        # Test ID generator
        $idTest = & $script:PythonPath -c "
import sys
sys.path.append('$($script:CommonScriptsPath.Replace('\', '\\'))')
try:
    from id_generator import generate_uuid
    print('id_generator_ok')
except ImportError as e:
    print(f'id_generator_error: {e}')
"
        
        if ($idTest -notmatch "id_generator_ok") {
            Write-LogDebug "ID generator test failed: $idTest"
            return $false
        }
        
        return $true
    }
    catch {
        Write-LogDebug "Service test failed: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Get cleaning patterns from unified configuration
.PARAMETER PatternType
    Type of patterns to retrieve (augment, telemetry, extensions, custom)
.OUTPUTS
    string[] - Array of cleaning patterns
#>
function Get-UnifiedCleaningPatterns {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('augment', 'telemetry', 'extensions', 'custom')]
        [string]$PatternType
    )
    
    if (-not $script:ServicesAvailable) {
        return Get-FallbackPatterns -PatternType $PatternType
    }
    
    try {
        $pythonScript = @"
import sys
sys.path.append('$($script:CommonScriptsPath.Replace('\', '\\'))')
from config_loader import get_cleaning_patterns
import json

try:
    patterns = get_cleaning_patterns('$PatternType')
    print(json.dumps(patterns))
except Exception as e:
    print(f'ERROR: {e}')
"@
        
        $result = & $script:PythonPath -c $pythonScript
        
        if ($result -match "^ERROR:") {
            Write-LogWarning "Failed to get patterns from unified service: $result"
            return Get-FallbackPatterns -PatternType $PatternType
        }
        
        $patterns = $result | ConvertFrom-Json
        Write-LogDebug "Retrieved $($patterns.Count) patterns for type '$PatternType'"
        return $patterns
    }
    catch {
        Write-LogWarning "Error calling unified config service: $($_.Exception.Message)"
        return Get-FallbackPatterns -PatternType $PatternType
    }
}

<#
.SYNOPSIS
    Generate secure ID using unified service
.PARAMETER IdType
    Type of ID to generate
.PARAMETER Length
    Length for hex string types
.OUTPUTS
    string - Generated ID
#>
function New-UnifiedSecureId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IdType,
        [int]$Length = 64
    )
    
    if (-not $script:ServicesAvailable) {
        return New-FallbackSecureId -IdType $IdType -Length $Length
    }
    
    try {
        $pythonScript = @"
import sys
sys.path.append('$($script:CommonScriptsPath.Replace('\', '\\'))')
from id_generator import generate_telemetry_id

try:
    if '$IdType' == 'hex':
        result = generate_telemetry_id('hex', $Length)
    else:
        result = generate_telemetry_id('$IdType')
    print(result)
except Exception as e:
    print(f'ERROR: {e}')
"@
        
        $result = & $script:PythonPath -c $pythonScript
        
        if ($result -match "^ERROR:") {
            Write-LogWarning "Failed to generate ID from unified service: $result"
            return New-FallbackSecureId -IdType $IdType -Length $Length
        }
        
        Write-LogDebug "Generated $IdType ID: $result"
        return $result.Trim()
    }
    catch {
        Write-LogWarning "Error calling unified ID service: $($_.Exception.Message)"
        return New-FallbackSecureId -IdType $IdType -Length $Length
    }
}

<#
.SYNOPSIS
    Get fallback patterns when unified service is not available
.PARAMETER PatternType
    Type of patterns to retrieve
.OUTPUTS
    string[] - Array of fallback patterns
#>
function Get-FallbackPatterns {
    [CmdletBinding()]
    param(
        [string]$PatternType
    )
    
    $fallbackPatterns = @{
        "augment" = @('%augment%', '%Augment%', '%AUGMENT%', '%context7%', '%Context7%', '%CONTEXT7%')
        "telemetry" = @('%telemetry%', '%machineId%', '%deviceId%', '%sqmId%')
        "extensions" = @('%augment.%', '%context7.%', '%augment-vip%')
        "custom" = @()
    }
    
    return $fallbackPatterns[$PatternType]
}

<#
.SYNOPSIS
    Generate fallback secure ID when unified service is not available
.PARAMETER IdType
    Type of ID to generate
.PARAMETER Length
    Length for hex string types
.OUTPUTS
    string - Generated ID
#>
function New-FallbackSecureId {
    [CmdletBinding()]
    param(
        [string]$IdType,
        [int]$Length = 64
    )
    
    # Use existing CommonUtils functions as fallback
    switch ($IdType.ToLower()) {
        'machineid' { return New-SecureHexString -Length 64 }
        'deviceid' { return New-SecureUUID }
        'sqmid' { return New-SecureUUID }
        'sessionid' { return New-SecureUUID }
        'instanceid' { return New-SecureUUID }
        'uuid' { return New-SecureUUID }
        'hex' { return New-SecureHexString -Length $Length }
        'timestamp' { return Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ" }
        default { return New-SecureUUID }
    }
}

# Initialize services on module load
$initResult = Initialize-UnifiedServices
if ($initResult) {
    Write-LogInfo "UnifiedServices module loaded with Python integration"
} else {
    Write-LogInfo "UnifiedServices module loaded with fallback implementations"
}

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-UnifiedServices',
    'Test-UnifiedServices',
    'Get-UnifiedCleaningPatterns',
    'New-UnifiedSecureId',
    'Get-PythonPath'
)
