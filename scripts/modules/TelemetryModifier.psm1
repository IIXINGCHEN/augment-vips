# TelemetryModifier.psm1
#
# Description: Enhanced telemetry ID modification module for VS Code
# Generates secure random IDs and modifies VS Code telemetry identifiers
#
# Author: Augment VIP Project
# Version: 1.0.0

# Import required modules
Import-Module (Join-Path $PSScriptRoot "Logger.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "BackupManager.psm1") -Force

# Telemetry modification result class
class TelemetryModificationResult {
    [string]$StoragePath
    [bool]$Success
    [string]$ErrorMessage
    [string]$BackupPath
    [hashtable]$OldIds
    [hashtable]$NewIds
    [DateTime]$ModificationDate
    
    TelemetryModificationResult([string]$storagePath) {
        $this.StoragePath = $storagePath
        $this.Success = $false
        $this.OldIds = @{}
        $this.NewIds = @{}
        $this.ModificationDate = Get-Date
    }
}

# Telemetry ID types
$script:TelemetryIdTypes = @{
    'telemetry.machineId' = @{ Type = 'HexString'; Length = 64 }
    'telemetry.devDeviceId' = @{ Type = 'UUID'; Length = 36 }
    'telemetry.sqmId' = @{ Type = 'UUID'; Length = 36 }
    'telemetry.sessionId' = @{ Type = 'UUID'; Length = 36 }
    'telemetry.instanceId' = @{ Type = 'UUID'; Length = 36 }
    'telemetry.firstSessionDate' = @{ Type = 'Timestamp'; Length = 0 }
    'telemetry.lastSessionDate' = @{ Type = 'Timestamp'; Length = 0 }
}

<#
.SYNOPSIS
    Modifies telemetry IDs in VS Code storage.json file
.PARAMETER StorageJsonPath
    Path to the VS Code storage.json file
.PARAMETER CreateBackup
    Create backup before modification
.PARAMETER IdTypes
    Array of ID types to modify (defaults to all)
.OUTPUTS
    TelemetryModificationResult - Result of the modification operation
#>
function Set-VSCodeTelemetryIds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StorageJsonPath,
        [bool]$CreateBackup = $true,
        [string[]]$IdTypes = @()
    )
    
    $result = [TelemetryModificationResult]::new($StorageJsonPath)
    
    try {
        # Check if storage file exists
        if (-not (Test-Path $StorageJsonPath)) {
            $result.ErrorMessage = "Storage file not found"
            Write-LogWarning "Storage file not found: $StorageJsonPath"
            return $result
        }
        
        Write-LogInfo "Modifying telemetry IDs in: $StorageJsonPath"
        
        # Create backup if requested
        if ($CreateBackup) {
            $backupInfo = New-FileBackup -FilePath $StorageJsonPath -Description "Pre-telemetry modification backup"
            if ($backupInfo) {
                $result.BackupPath = $backupInfo.BackupPath
                Write-LogSuccess "Created backup: $($backupInfo.BackupPath)"
            } else {
                $result.ErrorMessage = "Failed to create backup"
                Write-LogError "Failed to create backup for: $StorageJsonPath"
                return $result
            }
        }
        
        # Read and parse storage.json
        $storageContent = Get-Content -Path $StorageJsonPath -Raw -Encoding UTF8
        $storageData = $storageContent | ConvertFrom-Json
        
        # Determine which ID types to modify
        $idsToModify = if ($IdTypes.Count -gt 0) { $IdTypes } else { $script:TelemetryIdTypes.Keys }
        
        # Store old IDs and generate new ones
        foreach ($idType in $idsToModify) {
            if ($script:TelemetryIdTypes.ContainsKey($idType)) {
                $idConfig = $script:TelemetryIdTypes[$idType]
                
                # Store old value if it exists
                if ($storageData.PSObject.Properties.Name -contains $idType) {
                    $result.OldIds[$idType] = $storageData.$idType
                }
                
                # Generate new ID
                $newId = New-TelemetryId -Type $idConfig.Type -Length $idConfig.Length
                $result.NewIds[$idType] = $newId
                
                # Update storage data
                $storageData | Add-Member -MemberType NoteProperty -Name $idType -Value $newId -Force
                
                Write-LogDebug "Updated $idType`: $newId"
            }
        }
        
        # Save modified storage.json
        $modifiedJson = $storageData | ConvertTo-Json -Depth 10
        Set-Content -Path $StorageJsonPath -Value $modifiedJson -Encoding UTF8
        
        $result.Success = $true
        Write-LogSuccess "Telemetry IDs modified successfully"
        
        # Log the changes
        foreach ($idType in $result.NewIds.Keys) {
            Write-LogInfo "New $idType`: $($result.NewIds[$idType])"
        }
        
    }
    catch {
        $result.ErrorMessage = $_.Exception.Message
        Write-LogError "Failed to modify telemetry IDs: $StorageJsonPath" -Exception $_.Exception
    }
    
    return $result
}

<#
.SYNOPSIS
    Generates a new telemetry ID of the specified type
.PARAMETER Type
    Type of ID to generate (HexString, UUID, Timestamp)
.PARAMETER Length
    Length for HexString type
.OUTPUTS
    string - Generated ID
#>
function New-TelemetryId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('HexString', 'UUID', 'Timestamp')]
        [string]$Type,
        [int]$Length = 64
    )
    
    switch ($Type) {
        'HexString' {
            return New-SecureHexString -Length $Length
        }
        'UUID' {
            return New-SecureUUID
        }
        'Timestamp' {
            return Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
        }
        default {
            throw "Unknown ID type: $Type"
        }
    }
}

<#
.SYNOPSIS
    Generates a cryptographically secure hexadecimal string
.PARAMETER Length
    Length of the hex string (number of hex characters)
.OUTPUTS
    string - Secure hex string
#>
function New-SecureHexString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Length
    )
    
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
        return $hexString.Substring(0, [Math]::Min($hexString.Length, $Length))
    }
    catch {
        Write-LogError "Failed to generate secure hex string" -Exception $_.Exception
        throw
    }
}

<#
.SYNOPSIS
    Generates a cryptographically secure UUID (Version 4)
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
        return $uuid
    }
    catch {
        Write-LogError "Failed to generate secure UUID" -Exception $_.Exception
        # Fallback to .NET Guid if crypto fails
        return [System.Guid]::NewGuid().ToString()
    }
}

<#
.SYNOPSIS
    Validates a VS Code storage.json file structure
.PARAMETER StorageJsonPath
    Path to the storage.json file
.OUTPUTS
    bool - True if file is valid
#>
function Test-StorageJsonValidity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StorageJsonPath
    )
    
    try {
        if (-not (Test-Path $StorageJsonPath)) {
            Write-LogDebug "Storage file not found: $StorageJsonPath"
            return $false
        }
        
        # Try to parse JSON
        $content = Get-Content -Path $StorageJsonPath -Raw -Encoding UTF8
        $data = $content | ConvertFrom-Json
        
        # Basic validation - should be an object
        if ($data -is [PSCustomObject]) {
            Write-LogDebug "Storage JSON is valid: $StorageJsonPath"
            return $true
        } else {
            Write-LogDebug "Storage JSON has invalid structure: $StorageJsonPath"
            return $false
        }
    }
    catch {
        Write-LogDebug "Storage JSON parsing failed: $StorageJsonPath - $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Gets current telemetry IDs from storage.json
.PARAMETER StorageJsonPath
    Path to the storage.json file
.OUTPUTS
    hashtable - Current telemetry IDs
#>
function Get-CurrentTelemetryIds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StorageJsonPath
    )
    
    $currentIds = @{}
    
    try {
        if (-not (Test-Path $StorageJsonPath)) {
            Write-LogWarning "Storage file not found: $StorageJsonPath"
            return $currentIds
        }
        
        $content = Get-Content -Path $StorageJsonPath -Raw -Encoding UTF8
        $data = $content | ConvertFrom-Json
        
        foreach ($idType in $script:TelemetryIdTypes.Keys) {
            if ($data.PSObject.Properties.Name -contains $idType) {
                $currentIds[$idType] = $data.$idType
            }
        }
        
        Write-LogDebug "Retrieved $($currentIds.Count) telemetry IDs from storage"
    }
    catch {
        Write-LogError "Failed to get current telemetry IDs" -Exception $_.Exception
    }
    
    return $currentIds
}

<#
.SYNOPSIS
    Modifies telemetry IDs for multiple VS Code installations
.PARAMETER StorageJsonPaths
    Array of storage.json file paths
.PARAMETER CreateBackup
    Create backups before modification
.PARAMETER IdTypes
    Array of ID types to modify
.OUTPUTS
    TelemetryModificationResult[] - Array of modification results
#>
function Set-VSCodeTelemetryIdsMultiple {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$StorageJsonPaths,
        [bool]$CreateBackup = $true,
        [string[]]$IdTypes = @()
    )
    
    $results = @()
    $totalFiles = $StorageJsonPaths.Count
    $currentIndex = 0
    
    Write-LogInfo "Starting telemetry ID modification for $totalFiles file(s)"
    
    foreach ($storagePath in $StorageJsonPaths) {
        $currentIndex++
        $percentComplete = [Math]::Round(($currentIndex / $totalFiles) * 100)
        
        Write-LogProgress -Activity "Modifying Telemetry IDs" -Status "Processing $currentIndex of $totalFiles" -PercentComplete $percentComplete
        
        $result = Set-VSCodeTelemetryIds -StorageJsonPath $storagePath -CreateBackup $CreateBackup -IdTypes $IdTypes
        $results += $result
    }
    
    Complete-LogProgress
    
    # Summary
    $successCount = ($results | Where-Object { $_.Success }).Count
    $totalIdsModified = ($results | Where-Object { $_.Success } | ForEach-Object { $_.NewIds.Count } | Measure-Object -Sum).Sum
    
    Write-LogInfo "Telemetry ID modification summary:"
    Write-LogInfo "  Files processed: $totalFiles"
    Write-LogInfo "  Successful: $successCount"
    Write-LogInfo "  Failed: $($totalFiles - $successCount)"
    Write-LogInfo "  Total IDs modified: $totalIdsModified"
    
    return $results
}

<#
.SYNOPSIS
    Shows telemetry modification preview
.PARAMETER StorageJsonPaths
    Array of storage.json file paths
.PARAMETER IdTypes
    Array of ID types to preview
#>
function Show-TelemetryModificationPreview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$StorageJsonPaths,
        [string[]]$IdTypes = @()
    )
    
    Write-LogInfo "=== Telemetry Modification Preview ==="
    
    $idsToModify = if ($IdTypes.Count -gt 0) { $IdTypes } else { $script:TelemetryIdTypes.Keys }
    
    Write-LogInfo "ID types to modify: $($idsToModify -join ', ')"
    Write-LogInfo ""
    
    foreach ($storagePath in $StorageJsonPaths) {
        Write-LogInfo "File: $storagePath"
        
        if (Test-Path $storagePath) {
            $currentIds = Get-CurrentTelemetryIds -StorageJsonPath $storagePath
            
            foreach ($idType in $idsToModify) {
                $currentValue = if ($currentIds.ContainsKey($idType)) { $currentIds[$idType] } else { "(not set)" }
                Write-LogInfo "  $idType`: $currentValue"
            }
        } else {
            Write-LogWarning "  File not found"
        }
        
        Write-LogInfo ""
    }
    
    Write-LogInfo "=================================="
}

<#
.SYNOPSIS
    Generates a preview of new telemetry IDs without modifying files
.PARAMETER IdTypes
    Array of ID types to generate
.OUTPUTS
    hashtable - Preview of new IDs
#>
function New-TelemetryIdPreview {
    [CmdletBinding()]
    param(
        [string[]]$IdTypes = @()
    )
    
    $idsToGenerate = if ($IdTypes.Count -gt 0) { $IdTypes } else { $script:TelemetryIdTypes.Keys }
    $previewIds = @{}
    
    foreach ($idType in $idsToGenerate) {
        if ($script:TelemetryIdTypes.ContainsKey($idType)) {
            $idConfig = $script:TelemetryIdTypes[$idType]
            $newId = New-TelemetryId -Type $idConfig.Type -Length $idConfig.Length
            $previewIds[$idType] = $newId
        }
    }
    
    return $previewIds
}

<#
.SYNOPSIS
    Modifies telemetry IDs using production-verified method
.PARAMETER StoragePath
    Path to the VS Code storage.json file
.PARAMETER CreateBackup
    Create backup before modification (default: true)
.OUTPUTS
    bool - True if modification was successful
#>
function Set-TelemetryIdsProductionMethod {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StoragePath,
        [bool]$CreateBackup = $true
    )

    try {
        # Check if file exists
        if (-not (Test-Path $StoragePath)) {
            Write-LogWarning "Storage file not found: $StoragePath"
            return $false
        }

        # Create backup if requested
        if ($CreateBackup) {
            $backupPath = "$StoragePath.backup"
            try {
                Copy-Item -Path $StoragePath -Destination $backupPath -Force
                Write-LogSuccess "Created backup: $backupPath"
            } catch {
                Write-LogError "Failed to create backup for: $StoragePath"
                return $false
            }
        }

        # Read current configuration
        $content = Get-Content -Path $StoragePath -Raw | ConvertFrom-Json

        # Generate new IDs using production-verified method
        $newMachineId = New-RandomId
        $newDeviceId = New-UUIDv4
        $newSqmId = New-UUIDv4

        # Update IDs (Windows format)
        $content."telemetry.machineId" = $newMachineId
        $content."telemetry.devDeviceId" = $newDeviceId
        $content."telemetry.sqmId" = $newSqmId

        # Save changes
        $content | ConvertTo-Json -Depth 10 | Set-Content -Path $StoragePath

        Write-LogSuccess "Updated telemetry IDs in: $StoragePath"
        Write-LogInfo "New telemetry.machineId: $newMachineId"
        Write-LogInfo "New telemetry.devDeviceId: $newDeviceId"
        Write-LogInfo "New telemetry.sqmId: $newSqmId"

        return $true
    } catch {
        Write-LogError "Failed to modify telemetry IDs: $StoragePath"
        Write-LogError $_.Exception.Message
        return $false
    }
}

<#
.SYNOPSIS
    Generates a random ID using production-verified method
.OUTPUTS
    string - Random hex string
#>
function New-RandomId {
    param(
        [int]$Length = 64
    )

    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)

    return [System.BitConverter]::ToString($bytes).Replace("-", "").ToLower()
}

<#
.SYNOPSIS
    Generates a UUID v4 using production-verified method
.OUTPUTS
    string - UUID v4 string
#>
function New-UUIDv4 {
    $guid = [System.Guid]::NewGuid()
    return $guid.ToString()
}

# Export module functions
Export-ModuleMember -Function @(
    'Set-VSCodeTelemetryIds',
    'Set-VSCodeTelemetryIdsMultiple',
    'New-TelemetryId',
    'New-SecureHexString',
    'New-SecureUUID',
    'Test-StorageJsonValidity',
    'Get-CurrentTelemetryIds',
    'Show-TelemetryModificationPreview',
    'New-TelemetryIdPreview',
    'Set-TelemetryIdsProductionMethod',
    'New-RandomId',
    'New-UUIDv4'
)
