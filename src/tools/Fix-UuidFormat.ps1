# Fix-UuidFormat.ps1
#
# UUID Format Repair Tool for VS Code storage.json files
# Fixes non-standard UUID formats to proper UUID v4 format
# Specifically addresses the issue where UUID third segment doesn't start with '4'

param(
    [Parameter(Mandatory=$true)]
    [string]$StorageFile,

    [switch]$DryRun = $false,

    [switch]$VerboseLogging = $false
)

# Set error handling
$ErrorActionPreference = "Stop"
$VerbosePreference = if ($VerboseLogging) { "Continue" } else { "SilentlyContinue" }

# Load required modules
$ScriptDir = Split-Path -Parent $PSScriptRoot
$ProjectRoot = Split-Path -Parent $ScriptDir

# Initialize configuration paths
$ConfigFile = Join-Path $ProjectRoot "src\config\augment_patterns.json"

# Check if config file exists
if (-not (Test-Path $ConfigFile)) {
    Write-FixLog "ERROR" "Configuration file not found: $ConfigFile"
    exit 1
}

. "$ProjectRoot\src\core\configuration\ConfigLoader.ps1"
Initialize-ConfigPaths $ProjectRoot

# UUID patterns
$UuidV4Pattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
$InvalidUuidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[^4][0-9a-fA-F]{3}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'

# Logging functions
function Write-FixLog {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] [UUID-FIX] $Message"
    
    switch ($Level) {
        "INFO" { Write-Host $logMessage -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "DEBUG" { if ($VerboseLogging) { Write-Host $logMessage -ForegroundColor Gray } }
    }
}

# Function to generate UUID v4
function New-UuidV4 {
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    
    # Generate 16 random bytes
    $bytes = New-Object byte[] 16
    $rng.GetBytes($bytes)
    
    # Set version (4) and variant bits according to RFC 4122
    $bytes[6] = ($bytes[6] -band 0x0F) -bor 0x40  # Version 4
    $bytes[8] = ($bytes[8] -band 0x3F) -bor 0x80  # Variant bits
    
    # Convert to UUID string format
    $uuid = [System.BitConverter]::ToString($bytes[0..3]) + "-" +
            [System.BitConverter]::ToString($bytes[4..5]) + "-" +
            [System.BitConverter]::ToString($bytes[6..7]) + "-" +
            [System.BitConverter]::ToString($bytes[8..9]) + "-" +
            [System.BitConverter]::ToString($bytes[10..15])
    
    $rng.Dispose()
    
    return $uuid.Replace("-", "").ToLower() -replace '(.{8})(.{4})(.{4})(.{4})(.{12})', '$1-$2-$3-$4-$5'
}

# Function to fix UUID format
function Repair-UuidFormat {
    param([string]$Uuid)
    
    Write-FixLog "DEBUG" "Checking UUID format: $Uuid"
    
    # Check if UUID is already in correct v4 format
    if ($Uuid -match $UuidV4Pattern) {
        Write-FixLog "DEBUG" "UUID is already in correct v4 format"
        return $Uuid
    }
    
    # Check if UUID needs fixing (third segment doesn't start with 4)
    if ($Uuid -match $InvalidUuidPattern) {
        # Extract parts
        $parts = $Uuid.Split('-')
        
        if ($parts.Length -eq 5) {
            # Fix third segment (version) - replace first character with '4'
            $parts[2] = "4" + $parts[2].Substring(1)
            
            # Fix fourth segment (variant) if needed
            $variantChar = $parts[3].Substring(0, 1)
            if ($variantChar -notmatch '[89abAB]') {
                $parts[3] = "a" + $parts[3].Substring(1)
                Write-FixLog "DEBUG" "Fixed variant bits in fourth segment"
            }
            
            # Reconstruct UUID
            $fixedUuid = $parts -join '-'
            
            Write-FixLog "INFO" "UUID format fixed: $Uuid -> $fixedUuid"
            
            # Validate the fixed UUID
            if ($fixedUuid -match $UuidV4Pattern) {
                return $fixedUuid
            } else {
                Write-FixLog "ERROR" "Failed to create valid UUID v4 format"
                throw "UUID repair failed"
            }
        }
    }
    
    # If we can't fix it, generate a new one
    Write-FixLog "WARNING" "UUID format is invalid, generating new UUID v4"
    return New-UuidV4
}

# Function to fix storage.json file
function Repair-StorageJson {
    param(
        [string]$StorageFilePath,
        [bool]$DryRunMode
    )
    
    Write-FixLog "INFO" "Fixing UUID formats in storage file: $StorageFilePath"
    
    # Validate input file
    if (-not (Test-Path $StorageFilePath)) {
        Write-FixLog "ERROR" "Storage file not found: $StorageFilePath"
        throw "File not found"
    }
    
    # Load and validate JSON
    try {
        $storageContent = Get-Content $StorageFilePath -Raw | ConvertFrom-Json
    } catch {
        Write-FixLog "ERROR" "Invalid JSON format in storage file: $($_.Exception.Message)"
        throw "Invalid JSON"
    }
    
    # Create backup
    if (-not $DryRunMode) {
        $backupFile = "$StorageFilePath.uuid_fix_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $StorageFilePath $backupFile
        Write-FixLog "INFO" "Backup created: $backupFile"
    }
    
    # Extract current UUID values
    $machineId = $storageContent.'telemetry.machineId'
    $deviceId = $storageContent.'telemetry.devDeviceId'
    $sqmId = $storageContent.'telemetry.sqmId'
    
    Write-FixLog "INFO" "Current IDs:"
    Write-FixLog "INFO" "  Machine ID: $machineId"
    Write-FixLog "INFO" "  Device ID: $deviceId"
    Write-FixLog "INFO" "  SQM ID: $sqmId"
    
    # Check and fix each UUID
    $changesNeeded = $false
    $fixedDeviceId = $deviceId
    $fixedSqmId = $sqmId
    
    # Fix device ID
    if ($deviceId) {
        $newDeviceId = Repair-UuidFormat $deviceId
        if ($newDeviceId -ne $deviceId) {
            $changesNeeded = $true
            $fixedDeviceId = $newDeviceId
            Write-FixLog "INFO" "Device ID will be fixed: $deviceId -> $fixedDeviceId"
        }
    } else {
        $fixedDeviceId = New-UuidV4
        $changesNeeded = $true
        Write-FixLog "INFO" "Device ID will be generated: $fixedDeviceId"
    }
    
    # Fix SQM ID
    if ($sqmId) {
        $newSqmId = Repair-UuidFormat $sqmId
        if ($newSqmId -ne $sqmId) {
            $changesNeeded = $true
            $fixedSqmId = $newSqmId
            Write-FixLog "INFO" "SQM ID will be fixed: $sqmId -> $fixedSqmId"
        }
    } else {
        $fixedSqmId = New-UuidV4
        $changesNeeded = $true
        Write-FixLog "INFO" "SQM ID will be generated: $fixedSqmId"
    }
    
    # Apply changes if needed
    if ($changesNeeded) {
        if ($DryRunMode) {
            Write-FixLog "INFO" "DRY RUN: Would apply the following changes:"
            Write-FixLog "INFO" "  Device ID: $deviceId -> $fixedDeviceId"
            Write-FixLog "INFO" "  SQM ID: $sqmId -> $fixedSqmId"
        } else {
            # Apply fixes
            $storageContent.'telemetry.devDeviceId' = $fixedDeviceId
            $storageContent.'telemetry.sqmId' = $fixedSqmId
            
            # Save the file
            try {
                $storageContent | ConvertTo-Json -Depth 10 -Compress:$false | Set-Content $StorageFilePath -Encoding UTF8
                Write-FixLog "SUCCESS" "UUID formats fixed successfully in $StorageFilePath"
                
                # Verify the changes
                $verifyContent = Get-Content $StorageFilePath -Raw | ConvertFrom-Json
                $verifyDeviceId = $verifyContent.'telemetry.devDeviceId'
                $verifySqmId = $verifyContent.'telemetry.sqmId'
                
                Write-FixLog "INFO" "Verification - Updated IDs:"
                Write-FixLog "INFO" "  Device ID: $verifyDeviceId"
                Write-FixLog "INFO" "  SQM ID: $verifySqmId"
                
                # Validate formats
                if (($verifyDeviceId -match $UuidV4Pattern) -and ($verifySqmId -match $UuidV4Pattern)) {
                    Write-FixLog "SUCCESS" "All UUIDs are now in correct v4 format"
                    return $true
                } else {
                    Write-FixLog "ERROR" "UUID format verification failed"
                    return $false
                }
            } catch {
                Write-FixLog "ERROR" "Failed to save fixed storage file: $($_.Exception.Message)"
                throw "Save failed"
            }
        }
    } else {
        Write-FixLog "INFO" "No UUID format fixes needed"
    }
    
    return $true
}

# Main execution
try {
    Write-FixLog "INFO" "Starting UUID format repair tool"
    Write-FixLog "INFO" "Target file: $StorageFile"
    Write-FixLog "INFO" "Dry run: $DryRun"
    
    # Load configuration
    if (-not (Load-AugmentConfig)) {
        Write-FixLog "ERROR" "Failed to load unified configuration"
        exit 1
    }
    
    # Fix the storage file
    if (Repair-StorageJson $StorageFile $DryRun) {
        Write-FixLog "SUCCESS" "UUID format repair completed successfully"
        exit 0
    } else {
        Write-FixLog "ERROR" "UUID format repair failed"
        exit 1
    }
} catch {
    Write-FixLog "ERROR" "UUID format repair failed: $($_.Exception.Message)"
    exit 1
}
