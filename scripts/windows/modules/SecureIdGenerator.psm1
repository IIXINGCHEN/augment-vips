# SecureIdGenerator.psm1 - Secure ID Generation Module for Augment VIP
# Provides cryptographically secure ID generation functionality

# Import required modules
Import-Module (Join-Path $PSScriptRoot "Logger.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "CommonUtils.psm1") -Force

# Add required .NET assemblies
Add-Type -AssemblyName System.Security

<#
.SYNOPSIS
    Generates a cryptographically secure random GUID
.DESCRIPTION
    Creates a new GUID using secure random number generation
.OUTPUTS
    String representation of the generated GUID
#>
function New-SecureGuid {
    [CmdletBinding()]
    param()
    
    try {
        $guid = [System.Guid]::NewGuid()
        Write-LogDebug "Generated secure GUID: $guid"
        return $guid.ToString()
    }
    catch {
        Write-LogError "Error generating secure GUID: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Generates a cryptographically secure machine ID
.DESCRIPTION
    Creates a machine-specific identifier using hardware and system information
.OUTPUTS
    String representation of the machine ID (SHA256 hash)
#>
function New-SecureMachineId {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogInfo "Generating secure machine ID..."
        
        # Collect machine-specific information
        $machineInfo = @()
        
        # Get processor information
        try {
            $processor = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
            if ($processor) {
                $machineInfo += $processor.ProcessorId
                $machineInfo += $processor.Name
            }
        }
        catch {
            Write-LogWarning "Could not retrieve processor information"
        }
        
        # Get motherboard information
        try {
            $motherboard = Get-WmiObject -Class Win32_BaseBoard | Select-Object -First 1
            if ($motherboard) {
                $machineInfo += $motherboard.SerialNumber
                $machineInfo += $motherboard.Product
            }
        }
        catch {
            Write-LogWarning "Could not retrieve motherboard information"
        }
        
        # Get BIOS information
        try {
            $bios = Get-WmiObject -Class Win32_BIOS | Select-Object -First 1
            if ($bios) {
                $machineInfo += $bios.SerialNumber
            }
        }
        catch {
            Write-LogWarning "Could not retrieve BIOS information"
        }
        
        # Add system information as fallback
        $machineInfo += $env:COMPUTERNAME
        $machineInfo += [Environment]::MachineName
        $machineInfo += [Environment]::OSVersion.ToString()
        
        # Create combined string and hash it
        $combinedInfo = ($machineInfo | Where-Object { $_ -and $_.Trim() }) -join "|"
        $hash = Get-SecureHash -InputString $combinedInfo -Algorithm SHA256
        
        Write-LogInfo "Secure machine ID generated successfully"
        return $hash
    }
    catch {
        Write-LogError "Error generating secure machine ID: $($_.Exception.Message)"
        # Fallback to GUID-based ID
        Write-LogWarning "Using fallback GUID-based machine ID"
        return (New-SecureGuid)
    }
}

<#
.SYNOPSIS
    Generates a cryptographically secure device ID
.DESCRIPTION
    Creates a device-specific identifier with timestamp and random components
.OUTPUTS
    String representation of the device ID
#>
function New-SecureDeviceId {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogInfo "Generating secure device ID..."
        
        # Generate random bytes
        $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
        $randomBytes = New-Object byte[] 16
        $rng.GetBytes($randomBytes)
        
        # Convert to hex string
        $randomHex = [System.BitConverter]::ToString($randomBytes).Replace("-", "").ToLower()
        
        # Add timestamp component
        $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        
        # Combine and format as UUID-like string
        $deviceId = "{0}-{1}-{2}-{3}-{4}" -f 
            $randomHex.Substring(0, 8),
            $randomHex.Substring(8, 4),
            $randomHex.Substring(12, 4),
            $randomHex.Substring(16, 4),
            $timestamp.ToString("x").PadLeft(12, '0')
        
        Write-LogInfo "Secure device ID generated successfully"
        return $deviceId
        
    }
    catch {
        Write-LogError "Error generating secure device ID: $($_.Exception.Message)"
        # Fallback to GUID
        Write-LogWarning "Using fallback GUID-based device ID"
        return (New-SecureGuid)
    }
}

<#
.SYNOPSIS
    Generates a cryptographically secure hash
.DESCRIPTION
    Creates a secure hash of the input string using specified algorithm
.PARAMETER InputString
    The string to hash
.PARAMETER Algorithm
    The hash algorithm to use (SHA256, SHA512, MD5)
.OUTPUTS
    String representation of the hash (lowercase hex)
#>
function Get-SecureHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputString,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("SHA256", "SHA512", "MD5")]
        [string]$Algorithm = "SHA256"
    )
    
    try {
        $hasher = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        $inputBytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
        $hashBytes = $hasher.ComputeHash($inputBytes)
        $hashString = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
        
        $hasher.Dispose()
        
        Write-LogDebug "Generated $Algorithm hash: $($hashString.Substring(0, 16))..."
        return $hashString
    }
    catch {
        Write-LogError "Error generating secure hash: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Generates a secure random string
.DESCRIPTION
    Creates a cryptographically secure random string of specified length
.PARAMETER Length
    The length of the random string to generate
.PARAMETER CharacterSet
    The character set to use (Alphanumeric, Hex, Base64)
.OUTPUTS
    String representation of the random string
#>
function New-SecureRandomString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Length = 32,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Alphanumeric", "Hex", "Base64")]
        [string]$CharacterSet = "Alphanumeric"
    )
    
    try {
        $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
        
        switch ($CharacterSet) {
            "Hex" {
                $bytes = New-Object byte[] ($Length / 2)
                $rng.GetBytes($bytes)
                $result = [System.BitConverter]::ToString($bytes).Replace("-", "").ToLower().Substring(0, $Length)
            }
            "Base64" {
                $bytes = New-Object byte[] ([Math]::Ceiling($Length * 3 / 4))
                $rng.GetBytes($bytes)
                $result = [System.Convert]::ToBase64String($bytes).Substring(0, $Length)
            }
            default { # Alphanumeric
                $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                $result = ""
                for ($i = 0; $i -lt $Length; $i++) {
                    $bytes = New-Object byte[] 1
                    $rng.GetBytes($bytes)
                    $result += $chars[$bytes[0] % $chars.Length]
                }
            }
        }
        
        $rng.Dispose()
        
        Write-LogDebug "Generated secure random string (length: $Length, charset: $CharacterSet)"
        return $result
    }
    catch {
        Write-LogError "Error generating secure random string: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Initializes the secure ID generator module
.DESCRIPTION
    Performs initial setup and validation for secure ID generation
#>
function Initialize-SecureIdGenerator {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogInfo "Initializing secure ID generator module..."
        
        # Test cryptographic functionality
        $testGuid = New-SecureGuid
        $testHash = Get-SecureHash -InputString "test" -Algorithm SHA256
        
        if ($testGuid -and $testHash) {
            Write-LogSuccess "Secure ID generator initialized successfully"
            return $true
        } else {
            throw "Failed to generate test IDs"
        }
    }
    catch {
        Write-LogError "Failed to initialize secure ID generator: $($_.Exception.Message)"
        return $false
    }
}

# Export functions
Export-ModuleMember -Function @(
    'New-SecureGuid',
    'New-SecureMachineId',
    'New-SecureDeviceId',
    'Get-SecureHash',
    'New-SecureRandomString',
    'Initialize-SecureIdGenerator'
)

# Initialize module on import
Initialize-SecureIdGenerator | Out-Null
