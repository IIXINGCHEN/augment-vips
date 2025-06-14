# Secure File Operations Library for PowerShell
# Secure file operations with path validation and permission checks
# Version: 2.0.0
# Features: Path traversal protection, permission validation, secure file operations

param(
    [switch]$VerboseOutput = $false,
    [switch]$DebugOutput = $false
)

# Import required modules
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$loggingModule = Join-Path (Split-Path -Parent $scriptDir) "logging\unified_logger.ps1"
$errorModule = Join-Path (Split-Path -Parent $scriptDir) "error_handling\error_framework.ps1"

if (Test-Path $loggingModule) { . $loggingModule }
if (Test-Path $errorModule) { . $errorModule }

# Error handling configuration
$ErrorActionPreference = "Stop"
$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$DebugPreference = if ($Debug) { "Continue" } else { "SilentlyContinue" }

#region Security Configuration

# Global security configuration
$Global:SecureFileConfig = @{
    MaxPathLength = 4096
    MaxFilenameLength = 255
    AllowedExtensions = @('.json', '.txt', '.log', '.config', '.vscdb', '.db', '.sqlite', '.backup')
    RestrictedPaths = @(
        "$env:WINDIR",
        "$env:PROGRAMFILES",
        "${env:PROGRAMFILES(X86)}",
        "$env:SYSTEMROOT"
    )
    RequireExplicitPermission = $true
    EnablePathNormalization = $true
    EnableAuditLogging = $true
    MaxFileSize = 100MB
    TempDirectory = $env:TEMP
}

# Dangerous path patterns
$Global:DangerousPatterns = @(
    '\.\.[\\/]',           # Directory traversal
    '[\\/]\.\.[\\/]',      # Directory traversal
    '^\.\.[\\/]',          # Directory traversal at start
    '[\\/]\.',             # Hidden files/directories
    '\$',                  # Environment variables
    '%.*%',                # Windows environment variables
    '[<>:"|?*]',           # Invalid filename characters
    'CON|PRN|AUX|NUL',     # Reserved device names
    'COM[1-9]|LPT[1-9]'    # Reserved device names
)

#endregion

#region Path Validation Functions

# Validate file path for security
function Test-SecurePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [ValidateSet("Read", "Write", "Execute", "Delete")]
        [string]$Operation = "Read",
        
        [switch]$AllowCreate
    )
    
    try {
        Write-LogDebug "Validating path: $Path for operation: $Operation" "SECURE_FILE_OPS"
        
        # Check path length
        if ($Path.Length -gt $Global:SecureFileConfig.MaxPathLength) {
            Write-LogError "Path exceeds maximum length ($($Global:SecureFileConfig.MaxPathLength)): $Path" "SECURE_FILE_OPS"
            return $false
        }
        
        # Check for null bytes
        if ($Path.Contains("`0")) {
            Write-LogError "Path contains null bytes: $Path" "SECURE_FILE_OPS"
            return $false
        }
        
        # Check for dangerous patterns
        foreach ($pattern in $Global:DangerousPatterns) {
            if ($Path -match $pattern) {
                Write-LogError "Path contains dangerous pattern '$pattern': $Path" "SECURE_FILE_OPS"
                return $false
            }
        }
        
        # Normalize path to prevent traversal attacks
        $normalizedPath = $null
        if ($Global:SecureFileConfig.EnablePathNormalization) {
            try {
                $normalizedPath = [System.IO.Path]::GetFullPath($Path)
            } catch {
                Write-LogError "Failed to normalize path: $Path - $($_.Exception.Message)" "SECURE_FILE_OPS"
                return $false
            }
        } else {
            $normalizedPath = $Path
        }
        
        # Check against restricted paths
        foreach ($restrictedPath in $Global:SecureFileConfig.RestrictedPaths) {
            if ($normalizedPath.StartsWith($restrictedPath, [StringComparison]::OrdinalIgnoreCase)) {
                Write-LogError "Access denied to restricted path: $normalizedPath" "SECURE_FILE_OPS"
                return $false
            }
        }
        
        # Check file extension if it's a file
        if (-not (Test-Path $normalizedPath -PathType Container)) {
            $extension = [System.IO.Path]::GetExtension($normalizedPath).ToLower()
            if ($extension -and $Global:SecureFileConfig.AllowedExtensions -notcontains $extension) {
                Write-LogWarning "File extension not in allowed list: $extension" "SECURE_FILE_OPS"
                # Don't fail here, just warn
            }
        }
        
        # Check filename length
        $filename = [System.IO.Path]::GetFileName($normalizedPath)
        if ($filename.Length -gt $Global:SecureFileConfig.MaxFilenameLength) {
            Write-LogError "Filename exceeds maximum length ($($Global:SecureFileConfig.MaxFilenameLength)): $filename" "SECURE_FILE_OPS"
            return $false
        }
        
        # Validate operation-specific permissions
        if (-not (Test-OperationPermission -Path $normalizedPath -Operation $Operation -AllowCreate:$AllowCreate)) {
            return $false
        }
        
        Write-LogDebug "Path validation successful: $normalizedPath" "SECURE_FILE_OPS"
        return $true
        
    } catch {
        $errorContext = @{
            Path = $Path
            Operation = $Operation
            AllowCreate = $AllowCreate.IsPresent
        }
        Invoke-ErrorHandler -ErrorRecord $_ -Category "VALIDATION_ERROR" -Operation "Test-SecurePath" -Context $errorContext
        return $false
    }
}

# Test operation-specific permissions
function Test-OperationPermission {
    [CmdletBinding()]
    param(
        [string]$Path,
        [string]$Operation,
        [switch]$AllowCreate
    )
    
    try {
        $parentDir = Split-Path $Path -Parent
        
        switch ($Operation) {
            "Read" {
                if (Test-Path $Path) {
                    if (-not (Get-Item $Path).PSIsContainer) {
                        # Check if file is readable
                        try {
                            $null = Get-Content $Path -TotalCount 1 -ErrorAction Stop
                        } catch {
                            Write-LogError "File is not readable: $Path" "SECURE_FILE_OPS"
                            return $false
                        }
                    }
                } elseif (-not $AllowCreate) {
                    Write-LogError "File does not exist and creation not allowed: $Path" "SECURE_FILE_OPS"
                    return $false
                }
            }
            
            "Write" {
                if (Test-Path $Path) {
                    # Check if file is writable
                    try {
                        $fileInfo = Get-Item $Path
                        if ($fileInfo.IsReadOnly) {
                            Write-LogError "File is read-only: $Path" "SECURE_FILE_OPS"
                            return $false
                        }
                    } catch {
                        Write-LogError "Cannot access file for write check: $Path" "SECURE_FILE_OPS"
                        return $false
                    }
                } else {
                    # Check if parent directory is writable
                    if (-not (Test-Path $parentDir)) {
                        if ($AllowCreate) {
                            # Check if we can create the parent directory
                            try {
                                $testDir = Join-Path $parentDir "test_write_permission"
                                $null = New-Item -ItemType Directory -Path $testDir -Force -ErrorAction Stop
                                Remove-Item $testDir -Force -ErrorAction SilentlyContinue
                            } catch {
                                Write-LogError "Cannot create parent directory: $parentDir" "SECURE_FILE_OPS"
                                return $false
                            }
                        } else {
                            Write-LogError "Parent directory does not exist: $parentDir" "SECURE_FILE_OPS"
                            return $false
                        }
                    }
                }
            }
            
            "Execute" {
                if (-not (Test-Path $Path)) {
                    Write-LogError "File does not exist for execution: $Path" "SECURE_FILE_OPS"
                    return $false
                }
                
                $extension = [System.IO.Path]::GetExtension($Path).ToLower()
                $executableExtensions = @('.exe', '.bat', '.cmd', '.ps1', '.vbs', '.js')
                if ($executableExtensions -notcontains $extension) {
                    Write-LogWarning "File extension may not be executable: $extension" "SECURE_FILE_OPS"
                }
            }
            
            "Delete" {
                if (-not (Test-Path $Path)) {
                    Write-LogWarning "File does not exist for deletion: $Path" "SECURE_FILE_OPS"
                    return $true  # Not an error if file doesn't exist
                }
                
                try {
                    $fileInfo = Get-Item $Path
                    if ($fileInfo.IsReadOnly) {
                        Write-LogError "Cannot delete read-only file: $Path" "SECURE_FILE_OPS"
                        return $false
                    }
                } catch {
                    Write-LogError "Cannot access file for delete check: $Path" "SECURE_FILE_OPS"
                    return $false
                }
            }
        }
        
        return $true
        
    } catch {
        Write-LogError "Permission check failed for $Operation on $Path: $($_.Exception.Message)" "SECURE_FILE_OPS"
        return $false
    }
}

#endregion

#region Secure File Operations

# Secure file read operation
function Read-SecureFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [ValidateSet("String", "Bytes", "Lines")]
        [string]$ReadAs = "String",
        
        [string]$Encoding = "UTF8",
        [int]$MaxSizeBytes = 0
    )
    
    try {
        # Validate path
        if (-not (Test-SecurePath -Path $Path -Operation "Read")) {
            throw "Path validation failed for read operation: $Path"
        }
        
        $normalizedPath = [System.IO.Path]::GetFullPath($Path)
        
        # Check file size if limit specified
        if ($MaxSizeBytes -gt 0) {
            $fileInfo = Get-Item $normalizedPath
            if ($fileInfo.Length -gt $MaxSizeBytes) {
                throw "File size ($($fileInfo.Length)) exceeds maximum allowed size ($MaxSizeBytes): $normalizedPath"
            }
        }
        
        # Check against global max file size
        if ($Global:SecureFileConfig.MaxFileSize -gt 0) {
            $fileInfo = Get-Item $normalizedPath
            if ($fileInfo.Length -gt $Global:SecureFileConfig.MaxFileSize) {
                throw "File size ($($fileInfo.Length)) exceeds global maximum size ($($Global:SecureFileConfig.MaxFileSize)): $normalizedPath"
            }
        }
        
        Write-LogDebug "Reading file securely: $normalizedPath (ReadAs: $ReadAs)" "SECURE_FILE_OPS"
        
        # Perform secure read based on type
        switch ($ReadAs) {
            "String" {
                $content = Get-Content -Path $normalizedPath -Raw -Encoding $Encoding
            }
            "Bytes" {
                $content = Get-Content -Path $normalizedPath -AsByteStream
            }
            "Lines" {
                $content = Get-Content -Path $normalizedPath -Encoding $Encoding
            }
        }
        
        # Audit log if enabled
        if ($Global:SecureFileConfig.EnableAuditLogging) {
            Write-LogInfo "Secure file read completed: $normalizedPath" "SECURE_FILE_AUDIT"
        }
        
        return $content
        
    } catch {
        $errorContext = @{
            Path = $Path
            ReadAs = $ReadAs
            Encoding = $Encoding
            MaxSizeBytes = $MaxSizeBytes
        }
        Invoke-ErrorHandler -ErrorRecord $_ -Category "FILE_OPERATION_ERROR" -Operation "Read-SecureFile" -Context $errorContext
        throw
    }
}

# Secure file write operation
function Write-SecureFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        $Content,
        
        [string]$Encoding = "UTF8",
        [switch]$Append,
        [switch]$CreateDirectories,
        [switch]$Backup
    )
    
    try {
        # Validate path
        if (-not (Test-SecurePath -Path $Path -Operation "Write" -AllowCreate:$CreateDirectories)) {
            throw "Path validation failed for write operation: $Path"
        }
        
        $normalizedPath = [System.IO.Path]::GetFullPath($Path)
        
        # Create parent directories if requested
        if ($CreateDirectories) {
            $parentDir = Split-Path $normalizedPath -Parent
            if (-not (Test-Path $parentDir)) {
                Write-LogDebug "Creating parent directories: $parentDir" "SECURE_FILE_OPS"
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
        }
        
        # Create backup if requested and file exists
        if ($Backup -and (Test-Path $normalizedPath)) {
            $backupPath = "$normalizedPath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Write-LogDebug "Creating backup: $backupPath" "SECURE_FILE_OPS"
            Copy-Item -Path $normalizedPath -Destination $backupPath -Force
        }
        
        Write-LogDebug "Writing file securely: $normalizedPath (Append: $Append)" "SECURE_FILE_OPS"
        
        # Perform secure write
        if ($Append) {
            Add-Content -Path $normalizedPath -Value $Content -Encoding $Encoding
        } else {
            Set-Content -Path $normalizedPath -Value $Content -Encoding $Encoding
        }
        
        # Audit log if enabled
        if ($Global:SecureFileConfig.EnableAuditLogging) {
            Write-LogInfo "Secure file write completed: $normalizedPath" "SECURE_FILE_AUDIT"
        }
        
        return $true
        
    } catch {
        $errorContext = @{
            Path = $Path
            Encoding = $Encoding
            Append = $Append.IsPresent
            CreateDirectories = $CreateDirectories.IsPresent
            Backup = $Backup.IsPresent
        }
        Invoke-ErrorHandler -ErrorRecord $_ -Category "FILE_OPERATION_ERROR" -Operation "Write-SecureFile" -Context $errorContext
        throw
    }
}

# Secure file copy operation
function Copy-SecureFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [switch]$Force,
        [switch]$CreateDirectories,
        [switch]$VerifyIntegrity
    )

    try {
        # Validate source path
        if (-not (Test-SecurePath -Path $SourcePath -Operation "Read")) {
            throw "Source path validation failed: $SourcePath"
        }

        # Validate destination path
        if (-not (Test-SecurePath -Path $DestinationPath -Operation "Write" -AllowCreate:$CreateDirectories)) {
            throw "Destination path validation failed: $DestinationPath"
        }

        $normalizedSource = [System.IO.Path]::GetFullPath($SourcePath)
        $normalizedDestination = [System.IO.Path]::GetFullPath($DestinationPath)

        # Check if source exists
        if (-not (Test-Path $normalizedSource)) {
            throw "Source file does not exist: $normalizedSource"
        }

        # Create destination directories if requested
        if ($CreateDirectories) {
            $destParent = Split-Path $normalizedDestination -Parent
            if (-not (Test-Path $destParent)) {
                New-Item -ItemType Directory -Path $destParent -Force | Out-Null
            }
        }

        Write-LogDebug "Copying file securely: $normalizedSource -> $normalizedDestination" "SECURE_FILE_OPS"

        # Get source file hash for integrity verification
        $sourceHash = $null
        if ($VerifyIntegrity) {
            $sourceHash = Get-FileHash -Path $normalizedSource -Algorithm SHA256
        }

        # Perform copy
        Copy-Item -Path $normalizedSource -Destination $normalizedDestination -Force:$Force

        # Verify integrity if requested
        if ($VerifyIntegrity -and $sourceHash) {
            $destHash = Get-FileHash -Path $normalizedDestination -Algorithm SHA256
            if ($sourceHash.Hash -ne $destHash.Hash) {
                throw "File integrity verification failed after copy"
            }
            Write-LogDebug "File integrity verified after copy" "SECURE_FILE_OPS"
        }

        # Audit log if enabled
        if ($Global:SecureFileConfig.EnableAuditLogging) {
            Write-LogInfo "Secure file copy completed: $normalizedSource -> $normalizedDestination" "SECURE_FILE_AUDIT"
        }

        return $true

    } catch {
        $errorContext = @{
            SourcePath = $SourcePath
            DestinationPath = $DestinationPath
            Force = $Force.IsPresent
            CreateDirectories = $CreateDirectories.IsPresent
            VerifyIntegrity = $VerifyIntegrity.IsPresent
        }
        Invoke-ErrorHandler -ErrorRecord $_ -Category "FILE_OPERATION_ERROR" -Operation "Copy-SecureFile" -Context $errorContext
        throw
    }
}

# Secure file deletion operation
function Remove-SecureFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [switch]$Force,
        [switch]$Recurse,
        [switch]$SecureWipe
    )

    try {
        # Validate path
        if (-not (Test-SecurePath -Path $Path -Operation "Delete")) {
            throw "Path validation failed for delete operation: $Path"
        }

        $normalizedPath = [System.IO.Path]::GetFullPath($Path)

        # Check if path exists
        if (-not (Test-Path $normalizedPath)) {
            Write-LogWarning "File does not exist for deletion: $normalizedPath" "SECURE_FILE_OPS"
            return $true
        }

        Write-LogDebug "Removing file securely: $normalizedPath (Force: $Force, Recurse: $Recurse)" "SECURE_FILE_OPS"

        # Perform secure wipe if requested
        if ($SecureWipe -and -not (Get-Item $normalizedPath).PSIsContainer) {
            Write-LogDebug "Performing secure wipe of file: $normalizedPath" "SECURE_FILE_OPS"
            Invoke-SecureWipe -Path $normalizedPath
        }

        # Remove the file/directory
        Remove-Item -Path $normalizedPath -Force:$Force -Recurse:$Recurse

        # Audit log if enabled
        if ($Global:SecureFileConfig.EnableAuditLogging) {
            Write-LogInfo "Secure file removal completed: $normalizedPath" "SECURE_FILE_AUDIT"
        }

        return $true

    } catch {
        $errorContext = @{
            Path = $Path
            Force = $Force.IsPresent
            Recurse = $Recurse.IsPresent
            SecureWipe = $SecureWipe.IsPresent
        }
        Invoke-ErrorHandler -ErrorRecord $_ -Category "FILE_OPERATION_ERROR" -Operation "Remove-SecureFile" -Context $errorContext
        throw
    }
}

# Secure file move operation
function Move-SecureFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [switch]$Force,
        [switch]$CreateDirectories
    )

    try {
        # First copy, then delete source
        if (Copy-SecureFile -SourcePath $SourcePath -DestinationPath $DestinationPath -Force:$Force -CreateDirectories:$CreateDirectories -VerifyIntegrity) {
            Remove-SecureFile -Path $SourcePath -Force:$Force

            # Audit log if enabled
            if ($Global:SecureFileConfig.EnableAuditLogging) {
                Write-LogInfo "Secure file move completed: $SourcePath -> $DestinationPath" "SECURE_FILE_AUDIT"
            }

            return $true
        }

        return $false

    } catch {
        $errorContext = @{
            SourcePath = $SourcePath
            DestinationPath = $DestinationPath
            Force = $Force.IsPresent
            CreateDirectories = $CreateDirectories.IsPresent
        }
        Invoke-ErrorHandler -ErrorRecord $_ -Category "FILE_OPERATION_ERROR" -Operation "Move-SecureFile" -Context $errorContext
        throw
    }
}

#endregion

#region Utility Functions

# Secure wipe implementation
function Invoke-SecureWipe {
    [CmdletBinding()]
    param([string]$Path)

    try {
        $fileInfo = Get-Item $Path
        $fileSize = $fileInfo.Length

        # Overwrite with random data multiple times
        $passes = 3
        for ($pass = 1; $pass -le $passes; $pass++) {
            Write-LogDebug "Secure wipe pass $pass of $passes for: $Path" "SECURE_FILE_OPS"

            $randomData = New-Object byte[] $fileSize
            $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
            $rng.GetBytes($randomData)

            [System.IO.File]::WriteAllBytes($Path, $randomData)
            $rng.Dispose()
        }

        # Final pass with zeros
        $zeroData = New-Object byte[] $fileSize
        [System.IO.File]::WriteAllBytes($Path, $zeroData)

        Write-LogDebug "Secure wipe completed for: $Path" "SECURE_FILE_OPS"

    } catch {
        Write-LogWarning "Secure wipe failed for $Path, falling back to normal deletion: $($_.Exception.Message)" "SECURE_FILE_OPS"
    }
}

# Get secure temporary file path
function Get-SecureTempPath {
    [CmdletBinding()]
    param(
        [string]$Prefix = "augment_",
        [string]$Extension = ".tmp"
    )

    try {
        $tempDir = $Global:SecureFileConfig.TempDirectory
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $randomSuffix = [System.IO.Path]::GetRandomFileName().Split('.')[0]
        $tempFileName = "$Prefix$timestamp`_$randomSuffix$Extension"
        $tempPath = Join-Path $tempDir $tempFileName

        # Validate the generated path
        if (-not (Test-SecurePath -Path $tempPath -Operation "Write" -AllowCreate)) {
            throw "Generated temp path failed validation: $tempPath"
        }

        return $tempPath

    } catch {
        Write-LogError "Failed to generate secure temp path: $($_.Exception.Message)" "SECURE_FILE_OPS"
        throw
    }
}

# Test if path is within allowed boundaries
function Test-PathBoundary {
    [CmdletBinding()]
    param(
        [string]$Path,
        [string[]]$AllowedRoots
    )

    try {
        $normalizedPath = [System.IO.Path]::GetFullPath($Path)

        foreach ($root in $AllowedRoots) {
            $normalizedRoot = [System.IO.Path]::GetFullPath($root)
            if ($normalizedPath.StartsWith($normalizedRoot, [StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }

        return $false

    } catch {
        Write-LogError "Path boundary check failed: $($_.Exception.Message)" "SECURE_FILE_OPS"
        return $false
    }
}

# Initialize secure file operations
function Initialize-SecureFileOps {
    [CmdletBinding()]
    param(
        [string]$ConfigFile = ""
    )

    try {
        # Load configuration if provided
        if ($ConfigFile -and (Test-Path $ConfigFile)) {
            $config = Get-Content $ConfigFile | ConvertFrom-Json
            foreach ($key in $config.PSObject.Properties.Name) {
                if ($Global:SecureFileConfig.ContainsKey($key)) {
                    $Global:SecureFileConfig[$key] = $config.$key
                }
            }
        }

        # Validate temp directory
        if (-not (Test-Path $Global:SecureFileConfig.TempDirectory)) {
            New-Item -ItemType Directory -Path $Global:SecureFileConfig.TempDirectory -Force | Out-Null
        }

        Write-LogInfo "Secure file operations initialized successfully" "SECURE_FILE_OPS"
        return $true

    } catch {
        Write-LogError "Failed to initialize secure file operations: $($_.Exception.Message)" "SECURE_FILE_OPS"
        return $false
    }
}

#endregion

#region Module Export

# Auto-initialize when module is loaded
Initialize-SecureFileOps | Out-Null

# Export functions
Export-ModuleMember -Function @(
    'Test-SecurePath',
    'Read-SecureFile',
    'Write-SecureFile',
    'Copy-SecureFile',
    'Remove-SecureFile',
    'Move-SecureFile',
    'Get-SecureTempPath',
    'Test-PathBoundary',
    'Initialize-SecureFileOps'
)

#endregion
