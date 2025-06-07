# CentralizedBackupHandler.psm1
#
# Description: Centralized backup management system for VS Code cleanup operations
# Provides unified backup creation, categorization, and automatic cleanup
#
# Author: Augment VIP Project
# Version: 1.0.0

# Import required modules
try {
    Import-Module (Join-Path $PSScriptRoot "Logger.psm1") -Force -Global -DisableNameChecking
} catch {
    # Logger module might already be loaded globally
    Write-Verbose "Logger module import: $($_.Exception.Message)"
}

# Backup categories
enum BackupCategory {
    Database
    Telemetry
    Configuration
    Extension
}

# Enhanced backup information class
class CentralizedBackupInfo {
    [string]$OriginalPath
    [string]$BackupPath
    [DateTime]$CreatedDate
    [string]$Hash
    [long]$Size
    [bool]$IsValid
    [string]$Description
    [BackupCategory]$Category
    [string]$FileName
    
    CentralizedBackupInfo([string]$originalPath, [string]$backupPath, [BackupCategory]$category) {
        $this.OriginalPath = $originalPath
        $this.BackupPath = $backupPath
        $this.Category = $category
        $this.CreatedDate = Get-Date
        $this.IsValid = $false
        $this.FileName = [System.IO.Path]::GetFileName($originalPath)
    }
}

# Module variables
$script:CentralBackupDirectory = $null
$script:MaxBackupsPerCategory = 3
$script:CategoryDirectories = @{
    [BackupCategory]::Database = "databases"
    [BackupCategory]::Telemetry = "telemetry"
    [BackupCategory]::Configuration = "configuration"
    [BackupCategory]::Extension = "extensions"
}

<#
.SYNOPSIS
    Initializes the centralized backup handler
.PARAMETER BackupDirectory
    Root directory for centralized backups
.PARAMETER MaxBackupsPerCategory
    Maximum number of backups to keep per category (default: 3)
#>
function Initialize-CentralizedBackupHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupDirectory,
        [int]$MaxBackupsPerCategory = 3
    )
    
    $script:CentralBackupDirectory = $BackupDirectory
    $script:MaxBackupsPerCategory = $MaxBackupsPerCategory
    
    # Create main backup directory
    if (-not (Test-Path $BackupDirectory)) {
        try {
            New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
            Write-LogSuccess "Created centralized backup directory: $BackupDirectory"
        }
        catch {
            Write-LogError "Failed to create backup directory: $BackupDirectory" -Exception $_.Exception
            throw
        }
    }
    
    # Create category subdirectories
    foreach ($category in $script:CategoryDirectories.Keys) {
        $categoryPath = Join-Path $BackupDirectory $script:CategoryDirectories[$category]
        if (-not (Test-Path $categoryPath)) {
            try {
                New-Item -ItemType Directory -Path $categoryPath -Force | Out-Null
                Write-LogDebug "Created category directory: $categoryPath"
            }
            catch {
                Write-LogWarning "Failed to create category directory: $categoryPath"
            }
        }
    }
    
    Write-LogInfo "Centralized backup handler initialized - Directory: $BackupDirectory, Max per category: $MaxBackupsPerCategory"
}

<#
.SYNOPSIS
    Creates a centralized backup of a file
.PARAMETER FilePath
    Path to the file to backup
.PARAMETER Category
    Backup category for organization
.PARAMETER Description
    Optional description for the backup
.OUTPUTS
    CentralizedBackupInfo - Information about the created backup
#>
function New-CentralizedBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [BackupCategory]$Category,
        [string]$Description = ""
    )
    
    if (-not $script:CentralBackupDirectory) {
        throw "Centralized backup handler not initialized. Call Initialize-CentralizedBackupHandler first."
    }
    
    if (-not (Test-Path $FilePath)) {
        Write-LogError "Source file not found: $FilePath"
        return $null
    }
    
    try {
        # Generate backup filename with timestamp
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $fileName = [System.IO.Path]::GetFileName($FilePath)
        $backupFileName = "${timestamp}_${fileName}.backup"
        
        # Get category directory
        $categoryDir = Join-Path $script:CentralBackupDirectory $script:CategoryDirectories[$Category]
        $backupPath = Join-Path $categoryDir $backupFileName
        
        # Ensure unique filename
        $counter = 1
        while (Test-Path $backupPath) {
            $backupFileName = "${timestamp}_${counter}_${fileName}.backup"
            $backupPath = Join-Path $categoryDir $backupFileName
            $counter++
        }
        
        # Create backup info object
        $backupInfo = [CentralizedBackupInfo]::new($FilePath, $backupPath, $Category)
        $backupInfo.Description = $Description
        
        # Copy file
        Copy-Item -Path $FilePath -Destination $backupPath -Force
        
        # Calculate file hash and size
        $fileInfo = Get-Item $backupPath
        $backupInfo.Size = $fileInfo.Length
        $backupInfo.Hash = Get-FileHash -Path $backupPath -Algorithm SHA256 | Select-Object -ExpandProperty Hash
        
        # Verify backup
        if (Test-Path $backupPath) {
            $backupInfo.IsValid = Test-CentralizedBackupIntegrity -BackupInfo $backupInfo
            
            if ($backupInfo.IsValid) {
                Write-LogSuccess "Created centralized backup: $backupPath"
                
                # Save backup metadata
                Save-CentralizedBackupMetadata -BackupInfo $backupInfo
                
                # Auto-cleanup old backups for this category
                Clear-OldCentralizedBackups -Category $Category -Force
                
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
        Write-LogError "Failed to create centralized backup for: $FilePath" -Exception $_.Exception
        return $null
    }
}

<#
.SYNOPSIS
    Tests the integrity of a centralized backup
.PARAMETER BackupInfo
    Backup information object to test
.OUTPUTS
    bool - True if backup is valid
#>
function Test-CentralizedBackupIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [CentralizedBackupInfo]$BackupInfo
    )
    
    try {
        if (-not (Test-Path $BackupInfo.BackupPath)) {
            return $false
        }
        
        # Check file size
        $fileInfo = Get-Item $BackupInfo.BackupPath
        if ($fileInfo.Length -ne $BackupInfo.Size) {
            return $false
        }
        
        # Check file hash if available
        if ($BackupInfo.Hash) {
            $currentHash = Get-FileHash -Path $BackupInfo.BackupPath -Algorithm SHA256 | Select-Object -ExpandProperty Hash
            return ($currentHash -eq $BackupInfo.Hash)
        }
        
        return $true
    }
    catch {
        Write-LogWarning "Failed to verify backup integrity: $($BackupInfo.BackupPath)"
        return $false
    }
}

<#
.SYNOPSIS
    Saves centralized backup metadata
.PARAMETER BackupInfo
    Backup information object
#>
function Save-CentralizedBackupMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [CentralizedBackupInfo]$BackupInfo
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
            Category = $BackupInfo.Category.ToString()
            FileName = $BackupInfo.FileName
        }
        
        $metadata | ConvertTo-Json | Set-Content -Path $metadataPath -Encoding UTF8
    }
    catch {
        Write-LogWarning "Failed to save centralized backup metadata: $metadataPath"
    }
}

<#
.SYNOPSIS
    Gets all centralized backup files for a specific category
.PARAMETER Category
    Backup category to retrieve
.OUTPUTS
    CentralizedBackupInfo[] - Array of backup information objects
#>
function Get-CentralizedBackups {
    [CmdletBinding()]
    param(
        [BackupCategory]$Category
    )

    if (-not $script:CentralBackupDirectory) {
        Write-LogWarning "Centralized backup handler not initialized"
        return @()
    }

    $backupInfos = @()

    if ($Category) {
        $categories = @($Category)
    } else {
        $categories = $script:CategoryDirectories.Keys
    }

    foreach ($cat in $categories) {
        $categoryDir = Join-Path $script:CentralBackupDirectory $script:CategoryDirectories[$cat]

        if (-not (Test-Path $categoryDir)) {
            continue
        }

        try {
            $backupFiles = Get-ChildItem -Path $categoryDir -Filter "*.backup" | Sort-Object CreationTime -Descending

            foreach ($file in $backupFiles) {
                # Try to load metadata
                $metadataPath = "$($file.FullName).metadata"
                if (Test-Path $metadataPath) {
                    try {
                        $metadata = Get-Content $metadataPath | ConvertFrom-Json
                        $backupInfo = [CentralizedBackupInfo]::new($metadata.OriginalPath, $file.FullName, [BackupCategory]$metadata.Category)
                        $backupInfo.CreatedDate = [DateTime]$metadata.CreatedDate
                        $backupInfo.Hash = $metadata.Hash
                        $backupInfo.Size = $metadata.Size
                        $backupInfo.Description = $metadata.Description
                        $backupInfo.FileName = $metadata.FileName
                        $backupInfo.IsValid = Test-CentralizedBackupIntegrity -BackupInfo $backupInfo

                        $backupInfos += $backupInfo
                    }
                    catch {
                        Write-LogWarning "Failed to load metadata for: $($file.Name)"
                    }
                }
            }
        }
        catch {
            Write-LogWarning "Failed to enumerate backups in category: $cat"
        }
    }

    return $backupInfos
}

<#
.SYNOPSIS
    Cleans up old centralized backups for a specific category
.PARAMETER Category
    Backup category to clean up
.PARAMETER Force
    Force cleanup without confirmation
#>
function Clear-OldCentralizedBackups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [BackupCategory]$Category,
        [switch]$Force
    )

    if (-not $script:CentralBackupDirectory) {
        Write-LogWarning "Centralized backup handler not initialized"
        return
    }

    $backups = Get-CentralizedBackups -Category $Category | Sort-Object CreatedDate -Descending

    if ($backups.Count -le $script:MaxBackupsPerCategory) {
        Write-LogDebug "No old backups to clean up for category: $Category"
        return
    }

    # Keep only the newest MaxBackupsPerCategory backups
    $toDelete = $backups | Select-Object -Skip $script:MaxBackupsPerCategory

    Write-LogInfo "Cleaning up $($toDelete.Count) old backup(s) for category: $Category"

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

    if ($deletedCount -gt 0) {
        Write-LogSuccess "Deleted $deletedCount old backup file(s) for category: $Category"
    }
}

<#
.SYNOPSIS
    Shows centralized backup statistics
.PARAMETER Category
    Optional category to show statistics for
#>
function Show-CentralizedBackupStatistics {
    [CmdletBinding()]
    param(
        [BackupCategory]$Category
    )

    if (-not $script:CentralBackupDirectory) {
        Write-LogWarning "Centralized backup handler not initialized"
        return
    }

    Write-LogInfo "=== Centralized Backup Statistics ==="
    Write-LogInfo "Backup Directory: $script:CentralBackupDirectory"
    Write-LogInfo "Max Backups Per Category: $script:MaxBackupsPerCategory"
    Write-LogInfo ""

    if ($Category) {
        $categories = @($Category)
    } else {
        $categories = $script:CategoryDirectories.Keys
    }

    $totalBackups = 0
    $totalSize = 0

    foreach ($cat in $categories) {
        $backups = Get-CentralizedBackups -Category $cat
        $categorySize = ($backups | Measure-Object -Property Size -Sum).Sum

        Write-LogInfo "Category: $cat"
        Write-LogInfo "  Count: $($backups.Count)"
        Write-LogInfo "  Size: $([Math]::Round($categorySize / 1MB, 2)) MB"
        Write-LogInfo "  Valid: $($backups | Where-Object { $_.IsValid } | Measure-Object | Select-Object -ExpandProperty Count)"

        if ($backups.Count -gt 0) {
            $newest = $backups | Sort-Object CreatedDate -Descending | Select-Object -First 1
            $oldest = $backups | Sort-Object CreatedDate | Select-Object -First 1
            Write-LogInfo "  Newest: $($newest.CreatedDate.ToString('yyyy-MM-dd HH:mm:ss'))"
            Write-LogInfo "  Oldest: $($oldest.CreatedDate.ToString('yyyy-MM-dd HH:mm:ss'))"
        }

        Write-LogInfo ""

        $totalBackups += $backups.Count
        $totalSize += $categorySize
    }

    Write-LogInfo "Total Backups: $totalBackups"
    Write-LogInfo "Total Size: $([Math]::Round($totalSize / 1MB, 2)) MB"
    Write-LogInfo "=================================="
}

<#
.SYNOPSIS
    Removes old backup files that are scattered in VS Code directories
.PARAMETER Force
    Force cleanup without confirmation
#>
function Clear-ScatteredBackups {
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    Write-LogInfo "Cleaning up scattered backup files in VS Code directories..."

    $vsCodePaths = @(
        "$env:APPDATA\Code\User",
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code"
    )

    $deletedCount = 0

    foreach ($basePath in $vsCodePaths) {
        if (Test-Path $basePath) {
            try {
                $backupFiles = Get-ChildItem -Path $basePath -Recurse -Filter "*.backup" -ErrorAction SilentlyContinue

                foreach ($file in $backupFiles) {
                    try {
                        Remove-Item $file.FullName -Force
                        $deletedCount++
                        Write-LogDebug "Deleted scattered backup: $($file.FullName)"
                    }
                    catch {
                        Write-LogWarning "Failed to delete scattered backup: $($file.FullName)"
                    }
                }
            }
            catch {
                Write-LogWarning "Failed to enumerate scattered backups in: $basePath"
            }
        }
    }

    if ($deletedCount -gt 0) {
        Write-LogSuccess "Deleted $deletedCount scattered backup file(s)"
    } else {
        Write-LogInfo "No scattered backup files found"
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-CentralizedBackupHandler',
    'New-CentralizedBackup',
    'Test-CentralizedBackupIntegrity',
    'Get-CentralizedBackups',
    'Clear-OldCentralizedBackups',
    'Show-CentralizedBackupStatistics',
    'Clear-ScatteredBackups'
)
