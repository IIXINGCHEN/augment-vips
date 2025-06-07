# BackupManager.psm1
#
# Description: Backup management system for VS Code cleanup operations
# Provides backup creation, verification, restoration, and cleanup
#
# Author: Augment VIP Project
# Version: 1.0.0

# Import Logger module
Import-Module (Join-Path $PSScriptRoot "Logger.psm1") -Force

# Backup information class
class BackupInfo {
    [string]$OriginalPath
    [string]$BackupPath
    [DateTime]$CreatedDate
    [string]$Hash
    [long]$Size
    [bool]$IsValid
    [string]$Description
    
    BackupInfo([string]$originalPath, [string]$backupPath) {
        $this.OriginalPath = $originalPath
        $this.BackupPath = $backupPath
        $this.CreatedDate = Get-Date
        $this.IsValid = $false
    }
}

# Module variables
$script:BackupDirectory = $null
$script:MaxBackupAge = 30  # days
$script:MaxBackupCount = 10

<#
.SYNOPSIS
    Initializes the backup manager
.PARAMETER BackupDirectory
    Directory to store backup files
.PARAMETER MaxAge
    Maximum age of backups in days
.PARAMETER MaxCount
    Maximum number of backups to keep
#>
function Initialize-BackupManager {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupDirectory,
        [int]$MaxAge = 30,
        [int]$MaxCount = 10
    )
    
    $script:BackupDirectory = $BackupDirectory
    $script:MaxBackupAge = $MaxAge
    $script:MaxBackupCount = $MaxCount
    
    # Create backup directory if it doesn't exist
    if (-not (Test-Path $BackupDirectory)) {
        try {
            New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
            Write-LogSuccess "Created backup directory: $BackupDirectory"
        }
        catch {
            Write-LogError "Failed to create backup directory: $BackupDirectory" -Exception $_.Exception
            throw
        }
    }
    
    Write-LogInfo "Backup manager initialized - Directory: $BackupDirectory"
}

<#
.SYNOPSIS
    Creates a backup of a file
.PARAMETER FilePath
    Path to the file to backup
.PARAMETER Description
    Optional description for the backup
.OUTPUTS
    BackupInfo - Information about the created backup
#>
function New-FileBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string]$Description = ""
    )
    
    if (-not $script:BackupDirectory) {
        throw "Backup manager not initialized. Call Initialize-BackupManager first."
    }
    
    if (-not (Test-Path $FilePath)) {
        Write-LogError "Source file not found: $FilePath"
        return $null
    }
    
    try {
        # Generate backup filename with timestamp and random suffix to prevent conflicts
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $randomSuffix = Get-Random -Minimum 1000 -Maximum 9999
        $fileName = [System.IO.Path]::GetFileName($FilePath)
        $backupFileName = "${timestamp}_${randomSuffix}_${fileName}.backup"
        $backupPath = Join-Path $script:BackupDirectory $backupFileName

        # Ensure unique filename
        $counter = 1
        while (Test-Path $backupPath) {
            $backupFileName = "${timestamp}_${randomSuffix}_${counter}_${fileName}.backup"
            $backupPath = Join-Path $script:BackupDirectory $backupFileName
            $counter++
        }
        
        # Create backup info object
        $backupInfo = [BackupInfo]::new($FilePath, $backupPath)
        $backupInfo.Description = $Description
        
        # Copy file
        Copy-Item -Path $FilePath -Destination $backupPath -Force
        
        # Calculate file hash and size
        $fileInfo = Get-Item $backupPath
        $backupInfo.Size = $fileInfo.Length
        $backupInfo.Hash = Get-FileHash -Path $backupPath -Algorithm SHA256 | Select-Object -ExpandProperty Hash
        
        # Verify backup
        if (Test-Path $backupPath) {
            $backupInfo.IsValid = Test-BackupIntegrity -BackupInfo $backupInfo
            
            if ($backupInfo.IsValid) {
                Write-LogSuccess "Created backup: $backupPath"
                
                # Save backup metadata
                Save-BackupMetadata -BackupInfo $backupInfo
                
                return $backupInfo
            }
            else {
                Write-LogError "Backup verification failed: $backupPath"
                Remove-Item $backupPath -Force -ErrorAction SilentlyContinue
                return $null
            }
        }
        else {
            Write-LogError "Backup file was not created: $backupPath"
            return $null
        }
    }
    catch {
        Write-LogError "Failed to create backup for: $FilePath" -Exception $_.Exception
        return $null
    }
}

<#
.SYNOPSIS
    Restores a file from backup
.PARAMETER BackupInfo
    Backup information object
.PARAMETER TargetPath
    Optional target path (defaults to original path)
.PARAMETER Force
    Force overwrite existing file
.OUTPUTS
    bool - True if restore was successful
#>
function Restore-FileBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [BackupInfo]$BackupInfo,
        [string]$TargetPath,
        [switch]$Force
    )
    
    if (-not (Test-Path $BackupInfo.BackupPath)) {
        Write-LogError "Backup file not found: $($BackupInfo.BackupPath)"
        return $false
    }
    
    # Use original path if target not specified
    if (-not $TargetPath) {
        $TargetPath = $BackupInfo.OriginalPath
    }
    
    # Check if target exists and Force is not specified
    if ((Test-Path $TargetPath) -and -not $Force) {
        Write-LogWarning "Target file exists: $TargetPath"
        Write-LogInfo "Use -Force to overwrite existing file"
        return $false
    }
    
    try {
        # Verify backup integrity before restore
        if (-not (Test-BackupIntegrity -BackupInfo $BackupInfo)) {
            Write-LogError "Backup integrity check failed: $($BackupInfo.BackupPath)"
            return $false
        }
        
        # Create target directory if it doesn't exist
        $targetDir = Split-Path -Parent $TargetPath
        if ($targetDir -and -not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        
        # Restore file
        Copy-Item -Path $BackupInfo.BackupPath -Destination $TargetPath -Force
        
        # Verify restore
        if (Test-Path $TargetPath) {
            Write-LogSuccess "Restored file: $TargetPath"
            return $true
        }
        else {
            Write-LogError "File was not restored: $TargetPath"
            return $false
        }
    }
    catch {
        Write-LogError "Failed to restore backup: $($BackupInfo.BackupPath)" -Exception $_.Exception
        return $false
    }
}

<#
.SYNOPSIS
    Tests backup file integrity
.PARAMETER BackupInfo
    Backup information object
.OUTPUTS
    bool - True if backup is valid
#>
function Test-BackupIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [BackupInfo]$BackupInfo
    )
    
    try {
        if (-not (Test-Path $BackupInfo.BackupPath)) {
            return $false
        }
        
        # Check file size
        $fileInfo = Get-Item $BackupInfo.BackupPath
        if ($fileInfo.Length -ne $BackupInfo.Size) {
            Write-LogWarning "Backup size mismatch: $($BackupInfo.BackupPath)"
            return $false
        }
        
        # Check file hash
        $currentHash = Get-FileHash -Path $BackupInfo.BackupPath -Algorithm SHA256 | Select-Object -ExpandProperty Hash
        if ($currentHash -ne $BackupInfo.Hash) {
            Write-LogWarning "Backup hash mismatch: $($BackupInfo.BackupPath)"
            return $false
        }
        
        return $true
    }
    catch {
        Write-LogError "Failed to verify backup integrity: $($BackupInfo.BackupPath)" -Exception $_.Exception
        return $false
    }
}

<#
.SYNOPSIS
    Gets all backup files in the backup directory
.OUTPUTS
    BackupInfo[] - Array of backup information objects
#>
function Get-BackupFiles {
    [CmdletBinding()]
    param()

    if (-not $script:BackupDirectory -or -not (Test-Path $script:BackupDirectory)) {
        Write-LogWarning "Backup directory not found or not initialized"
        return @()
    }
    
    try {
        $backupFiles = Get-ChildItem -Path $script:BackupDirectory -Filter "*.backup" | Sort-Object CreationTime -Descending
        $backupInfos = @()
        
        foreach ($file in $backupFiles) {
            # Try to load metadata
            $metadataPath = "$($file.FullName).metadata"
            if (Test-Path $metadataPath) {
                try {
                    $metadata = Get-Content $metadataPath | ConvertFrom-Json
                    $backupInfo = [BackupInfo]::new($metadata.OriginalPath, $file.FullName)
                    $backupInfo.CreatedDate = [DateTime]$metadata.CreatedDate
                    $backupInfo.Hash = $metadata.Hash
                    $backupInfo.Size = $metadata.Size
                    $backupInfo.Description = $metadata.Description
                    $backupInfo.IsValid = Test-BackupIntegrity -BackupInfo $backupInfo
                    
                    $backupInfos += $backupInfo
                }
                catch {
                    Write-LogWarning "Failed to load metadata for: $($file.Name)"
                }
            }
        }
        
        return $backupInfos
    }
    catch {
        Write-LogError "Failed to get backup files" -Exception $_.Exception
        return @()
    }
}

<#
.SYNOPSIS
    Saves backup metadata to a file
.PARAMETER BackupInfo
    Backup information object
#>
function Save-BackupMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [BackupInfo]$BackupInfo
    )
    
    try {
        $metadataPath = "$($BackupInfo.BackupPath).metadata"
        $metadata = @{
            OriginalPath = $BackupInfo.OriginalPath
            BackupPath = $BackupInfo.BackupPath
            CreatedDate = $BackupInfo.CreatedDate.ToString("o")
            Hash = $BackupInfo.Hash
            Size = $BackupInfo.Size
            Description = $BackupInfo.Description
        }
        
        $metadata | ConvertTo-Json | Set-Content -Path $metadataPath -Encoding UTF8
    }
    catch {
        Write-LogWarning "Failed to save backup metadata: $metadataPath"
    }
}

<#
.SYNOPSIS
    Cleans up old backup files
.PARAMETER Force
    Force cleanup without confirmation
#>
function Clear-OldBackups {
    [CmdletBinding()]
    param(
        [switch]$Force
    )
    
    if (-not $script:BackupDirectory) {
        Write-LogWarning "Backup manager not initialized"
        return
    }
    
    Write-LogInfo "Cleaning up old backup files..."
    
    $backups = Get-BackupFiles
    $cutoffDate = (Get-Date).AddDays(-$script:MaxBackupAge)
    
    # Find old backups
    $oldBackups = $backups | Where-Object { $_.CreatedDate -lt $cutoffDate }
    
    # Find excess backups (keep only MaxBackupCount newest)
    $excessBackups = $backups | Sort-Object CreatedDate -Descending | Select-Object -Skip $script:MaxBackupCount
    
    $toDelete = @()
    $toDelete += $oldBackups
    $toDelete += $excessBackups | Where-Object { $_ -notin $oldBackups }
    
    if ($toDelete.Count -eq 0) {
        Write-LogInfo "No old backups to clean up"
        return
    }
    
    Write-LogInfo "Found $($toDelete.Count) backup(s) to clean up"
    
    if (-not $Force) {
        $response = Read-Host "Delete $($toDelete.Count) old backup file(s)? (y/n)"
        if ($response -notmatch '^[Yy]$') {
            Write-LogInfo "Backup cleanup cancelled"
            return
        }
    }
    
    $deletedCount = 0
    foreach ($backup in $toDelete) {
        try {
            Remove-Item $backup.BackupPath -Force
            
            # Remove metadata file if it exists
            $metadataPath = "$($backup.BackupPath).metadata"
            if (Test-Path $metadataPath) {
                Remove-Item $metadataPath -Force
            }
            
            $deletedCount++
            Write-LogDebug "Deleted backup: $($backup.BackupPath)"
        }
        catch {
            Write-LogWarning "Failed to delete backup: $($backup.BackupPath)"
        }
    }
    
    Write-LogSuccess "Deleted $deletedCount backup file(s)"
}

<#
.SYNOPSIS
    Shows backup statistics
#>
function Show-BackupStatistics {
    [CmdletBinding()]
    param()

    if (-not $script:BackupDirectory) {
        Write-LogWarning "Backup manager not initialized"
        return
    }
    
    $backups = Get-BackupFiles
    $totalSize = ($backups | Measure-Object -Property Size -Sum).Sum
    $validBackups = $backups | Where-Object { $_.IsValid }
    
    Write-LogInfo "=== Backup Statistics ==="
    Write-LogInfo "Backup Directory: $script:BackupDirectory"
    Write-LogInfo "Total Backups: $($backups.Count)"
    Write-LogInfo "Valid Backups: $($validBackups.Count)"
    Write-LogInfo "Total Size: $([Math]::Round($totalSize / 1MB, 2)) MB"
    Write-LogInfo "Oldest Backup: $(if ($backups) { ($backups | Sort-Object CreatedDate | Select-Object -First 1).CreatedDate } else { 'None' })"
    Write-LogInfo "Newest Backup: $(if ($backups) { ($backups | Sort-Object CreatedDate -Descending | Select-Object -First 1).CreatedDate } else { 'None' })"
    Write-LogInfo "========================"
}

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-BackupManager',
    'New-FileBackup',
    'Restore-FileBackup',
    'Test-BackupIntegrity',
    'Get-BackupFiles',
    'Clear-OldBackups',
    'Show-BackupStatistics'
)
