# Fix-UuidFormat.ps1
# UUID Format Repair Tool for VS Code storage.json files
# Fixes non-standard UUID formats to proper UUID v4 format
# Version: 2.1.0 - 统一导入重构版本

param(
    [Parameter(Mandatory=$true)]
    [string]$StorageFile,

    [switch]$DryRun = $false,

    [switch]$VerboseLogging = $false
)

# 导入统一核心模块
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreModulesPath = Split-Path $scriptPath -Parent | Join-Path -ChildPath "core"
$standardImportsPath = Join-Path $coreModulesPath "StandardImports.ps1"

if (Test-Path $standardImportsPath) {
    . $standardImportsPath
    Write-LogInfo "已加载统一核心模块"
} else {
    # 紧急回退日志（仅在StandardImports不可用时使用）
    function Write-LogInfo { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor White }
    function Write-LogSuccess { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
    function Write-LogWarning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    function Write-LogError { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
    function Write-LogDebug { param([string]$Message) if ($VerboseLogging) { Write-Host "[DEBUG] $Message" -ForegroundColor Gray } }
    Write-LogWarning "StandardImports不可用，使用回退日志系统"
}

# Set error handling
$ErrorActionPreference = "Stop"
$VerbosePreference = if ($VerboseLogging) { "Continue" } else { "SilentlyContinue" }

# UUID patterns
$UuidV4Pattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
$InvalidUuidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[^4][0-9a-fA-F]{3}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'

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

    Write-LogDebug "Checking UUID format: $Uuid"

    # Check if UUID is already in correct v4 format
    if ($Uuid -match $UuidV4Pattern) {
        Write-LogDebug "UUID is already in correct v4 format"
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
                Write-LogDebug "Fixed variant bits in fourth segment"
            }

            # Reconstruct UUID
            $fixedUuid = $parts -join '-'

            Write-LogInfo "UUID format fixed: $Uuid -> $fixedUuid"

            # Validate the fixed UUID
            if ($fixedUuid -match $UuidV4Pattern) {
                return $fixedUuid
            } else {
                Write-LogError "Failed to create valid UUID v4 format"
                throw "UUID repair failed"
            }
        }
    }

    # If we can't fix it, generate a new one
    Write-LogWarning "UUID format is invalid, generating new UUID v4"
    return New-UuidV4
}

# Function to fix storage.json file
function Repair-StorageJson {
    param(
        [string]$StorageFilePath,
        [bool]$DryRunMode
    )

    Write-LogInfo "Fixing UUID formats in storage file: $StorageFilePath"

    # Validate input file
    if (-not (Test-Path $StorageFilePath)) {
        Write-LogError "Storage file not found: $StorageFilePath"
        throw "File not found"
    }

    # Load and validate JSON
    try {
        $storageContent = Get-Content $StorageFilePath -Raw | ConvertFrom-Json
    } catch {
        Write-LogError "Invalid JSON format in storage file: $($_.Exception.Message)"
        throw "Invalid JSON"
    }

    # Create backup
    if (-not $DryRunMode) {
        $backupFile = "$StorageFilePath.uuid_fix_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $StorageFilePath $backupFile
        Write-LogInfo "Backup created: $backupFile"
    }
    
    # Extract current UUID values
    $machineId = $storageContent.'telemetry.machineId'
    $deviceId = $storageContent.'telemetry.devDeviceId'
    $sqmId = $storageContent.'telemetry.sqmId'

    Write-LogInfo "Current IDs:"
    Write-LogInfo "  Machine ID: $machineId"
    Write-LogInfo "  Device ID: $deviceId"
    Write-LogInfo "  SQM ID: $sqmId"

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
            Write-LogInfo "Device ID will be fixed: $deviceId -> $fixedDeviceId"
        }
    } else {
        $fixedDeviceId = New-UuidV4
        $changesNeeded = $true
        Write-LogInfo "Device ID will be generated: $fixedDeviceId"
    }

    # Fix SQM ID
    if ($sqmId) {
        $newSqmId = Repair-UuidFormat $sqmId
        if ($newSqmId -ne $sqmId) {
            $changesNeeded = $true
            $fixedSqmId = $newSqmId
            Write-LogInfo "SQM ID will be fixed: $sqmId -> $fixedSqmId"
        }
    } else {
        $fixedSqmId = New-UuidV4
        $changesNeeded = $true
        Write-LogInfo "SQM ID will be generated: $fixedSqmId"
    }
    
    # Apply changes if needed
    if ($changesNeeded) {
        if ($DryRunMode) {
            Write-LogInfo "DRY RUN: Would apply the following changes:"
            Write-LogInfo "  Device ID: $deviceId -> $fixedDeviceId"
            Write-LogInfo "  SQM ID: $sqmId -> $fixedSqmId"
        } else {
            # Apply fixes
            $storageContent.'telemetry.devDeviceId' = $fixedDeviceId
            $storageContent.'telemetry.sqmId' = $fixedSqmId

            # Save the file
            try {
                $storageContent | ConvertTo-Json -Depth 10 -Compress:$false | Set-Content $StorageFilePath -Encoding UTF8
                Write-LogSuccess "UUID formats fixed successfully in $StorageFilePath"

                # Verify the changes
                $verifyContent = Get-Content $StorageFilePath -Raw | ConvertFrom-Json
                $verifyDeviceId = $verifyContent.'telemetry.devDeviceId'
                $verifySqmId = $verifyContent.'telemetry.sqmId'

                Write-LogInfo "Verification - Updated IDs:"
                Write-LogInfo "  Device ID: $verifyDeviceId"
                Write-LogInfo "  SQM ID: $verifySqmId"

                # Validate formats
                if (($verifyDeviceId -match $UuidV4Pattern) -and ($verifySqmId -match $UuidV4Pattern)) {
                    Write-LogSuccess "All UUIDs are now in correct v4 format"
                    return $true
                } else {
                    Write-LogError "UUID format verification failed"
                    return $false
                }
            } catch {
                Write-LogError "Failed to save fixed storage file: $($_.Exception.Message)"
                throw "Save failed"
            }
        }
    } else {
        Write-LogInfo "No UUID format fixes needed"
    }
    
    return $true
}

# Main execution
try {
    Write-LogInfo "Starting UUID format repair tool"
    Write-LogInfo "Target file: $StorageFile"
    Write-LogInfo "Dry run: $DryRun"

    # Fix the storage file (simplified - removed config dependency)
    if (Repair-StorageJson $StorageFile $DryRun) {
        Write-LogSuccess "UUID format repair completed successfully"
        exit 0
    } else {
        Write-LogError "UUID format repair failed"
        exit 1
    }
} catch {
    Write-LogError "UUID format repair failed: $($_.Exception.Message)"
    exit 1
}
