[CmdletBinding()]
param(
    [switch]$VerboseOutput = $false,
    [switch]$DryRun = $false,
    [switch]$Force = $false,
    [string]$TargetPath = ""
)

# Standalone logging functions
function Write-LogInfo { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor White }
function Write-LogSuccess { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-LogWarning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-LogError { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-LogDebug { param([string]$Message) if ($VerboseOutput) { Write-Host "[DEBUG] $Message" -ForegroundColor Gray } }

# Set error handling
$ErrorActionPreference = "Stop"

function Test-FileAccess {
    <#
    .SYNOPSIS
        Tests if a file can be accessed for read/write operations
    .PARAMETER FilePath
        Path to the file to test
    .EXAMPLE
        Test-FileAccess -FilePath "C:\path\to\file.db"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        return @{
            Accessible = $false
            Reason = "File does not exist"
            CanRead = $false
            CanWrite = $false
            IsLocked = $false
        }
    }

    $result = @{
        Accessible = $true
        Reason = ""
        CanRead = $false
        CanWrite = $false
        IsLocked = $false
        LockingProcesses = @()
    }

    try {
        # Test read access
        $stream = [System.IO.File]::OpenRead($FilePath)
        $stream.Close()
        $result.CanRead = $true
        Write-LogDebug "Read access OK: $FilePath"
    } catch {
        $result.CanRead = $false
        $result.Reason += "Cannot read file. "
        Write-LogDebug "Read access failed: $FilePath - $($_.Exception.Message)"
    }

    try {
        # Test write access
        $stream = [System.IO.File]::OpenWrite($FilePath)
        $stream.Close()
        $result.CanWrite = $true
        Write-LogDebug "Write access OK: $FilePath"
    } catch {
        $result.CanWrite = $false
        $result.IsLocked = $true
        $result.Reason += "Cannot write file (possibly locked). "
        Write-LogDebug "Write access failed: $FilePath - $($_.Exception.Message)"
        
        # Try to identify locking processes
        try {
            $lockingProcesses = Get-ProcessesUsingFile -FilePath $FilePath
            $result.LockingProcesses = $lockingProcesses
        } catch {
            Write-LogDebug "Could not identify locking processes for: $FilePath"
        }
    }

    if (-not $result.CanRead -or -not $result.CanWrite) {
        $result.Accessible = $false
    }

    return $result
}

function Get-ProcessesUsingFile {
    <#
    .SYNOPSIS
        Gets processes that are using a specific file
    .PARAMETER FilePath
        Path to the file
    .EXAMPLE
        Get-ProcessesUsingFile -FilePath "C:\path\to\file.db"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $processes = @()
    
    try {
        # Use handle.exe if available, otherwise use PowerShell method
        if (Get-Command "handle.exe" -ErrorAction SilentlyContinue) {
            $handleOutput = & handle.exe $FilePath 2>$null
            foreach ($line in $handleOutput) {
                if ($line -match "(\w+\.exe)\s+pid:\s+(\d+)") {
                    $processes += @{
                        ProcessName = $matches[1]
                        ProcessId = [int]$matches[2]
                    }
                }
            }
        } else {
            # Fallback: Check common VS Code processes
            $vsCodeProcesses = Get-Process -Name "Code", "Cursor" -ErrorAction SilentlyContinue
            foreach ($proc in $vsCodeProcesses) {
                $processes += @{
                    ProcessName = $proc.ProcessName
                    ProcessId = $proc.Id
                }
            }
        }
    } catch {
        Write-LogDebug "Error getting processes using file: $($_.Exception.Message)"
    }

    return $processes
}

function Set-FilePermissions {
    <#
    .SYNOPSIS
        Sets appropriate permissions on a file
    .PARAMETER FilePath
        Path to the file
    .PARAMETER Owner
        Owner to set (default: current user)
    .EXAMPLE
        Set-FilePermissions -FilePath "C:\path\to\file.db"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string]$Owner = $env:USERNAME
    )

    if (-not (Test-Path $FilePath)) {
        Write-LogError "File does not exist: $FilePath"
        return $false
    }

    try {
        Write-LogInfo "Setting permissions for: $FilePath"
        
        if ($DryRun) {
            Write-LogInfo "DRY RUN: Would set permissions for $FilePath"
            return $true
        }

        # Get current ACL
        $acl = Get-Acl $FilePath
        
        # Set owner to current user
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $acl.SetOwner($currentUser.User)
        
        # Grant full control to current user
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $currentUser.User,
            "FullControl",
            "Allow"
        )
        $acl.SetAccessRule($accessRule)
        
        # Apply the ACL
        Set-Acl -Path $FilePath -AclObject $acl
        
        Write-LogSuccess "Permissions set successfully for: $FilePath"
        return $true
        
    } catch {
        Write-LogError "Failed to set permissions for $FilePath`: $($_.Exception.Message)"
        return $false
    }
}

function Wait-ForFileAccess {
    <#
    .SYNOPSIS
        Waits for a file to become accessible
    .PARAMETER FilePath
        Path to the file
    .PARAMETER MaxWaitSeconds
        Maximum time to wait in seconds
    .EXAMPLE
        Wait-ForFileAccess -FilePath "C:\path\to\file.db" -MaxWaitSeconds 30
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [int]$MaxWaitSeconds = 30
    )

    $startTime = Get-Date
    $timeout = $startTime.AddSeconds($MaxWaitSeconds)
    
    Write-LogInfo "Waiting for file access: $FilePath (max $MaxWaitSeconds seconds)"
    
    while ((Get-Date) -lt $timeout) {
        $accessTest = Test-FileAccess -FilePath $FilePath
        
        if ($accessTest.Accessible) {
            Write-LogSuccess "File is now accessible: $FilePath"
            return $true
        }
        
        Write-LogDebug "File still locked, waiting... ($($accessTest.Reason))"
        Start-Sleep -Seconds 2
    }
    
    Write-LogWarning "Timeout waiting for file access: $FilePath"
    return $false
}

function Repair-FilePermissions {
    <#
    .SYNOPSIS
        Main function to repair file permissions
    .PARAMETER FilePaths
        Array of file paths to repair
    .EXAMPLE
        Repair-FilePermissions -FilePaths @("file1.db", "file2.json")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$FilePaths
    )

    $results = @{
        TotalFiles = $FilePaths.Count
        SuccessCount = 0
        FailureCount = 0
        LockedFiles = @()
        PermissionErrors = @()
        Details = @()
    }

    Write-LogInfo "Starting file permission repair for $($FilePaths.Count) files..."

    foreach ($filePath in $FilePaths) {
        Write-LogInfo "Processing: $filePath"
        
        # Test current access
        $accessTest = Test-FileAccess -FilePath $filePath
        
        if ($accessTest.Accessible) {
            Write-LogSuccess "File already accessible: $filePath"
            $results.SuccessCount++
            $results.Details += "Already accessible: $filePath"
            continue
        }
        
        Write-LogWarning "File access issues detected: $filePath"
        Write-LogWarning "Reason: $($accessTest.Reason)"
        
        if ($accessTest.IsLocked -and $accessTest.LockingProcesses.Count -gt 0) {
            Write-LogWarning "File is locked by processes:"
            foreach ($proc in $accessTest.LockingProcesses) {
                Write-LogWarning "  - $($proc.ProcessName) (PID: $($proc.ProcessId))"
            }
            $results.LockedFiles += $filePath
            
            if ($Force) {
                Write-LogWarning "Force flag enabled - attempting to wait for file access..."
                if (Wait-ForFileAccess -FilePath $filePath -MaxWaitSeconds 30) {
                    # Try to set permissions after waiting
                    if (Set-FilePermissions -FilePath $filePath) {
                        $results.SuccessCount++
                        $results.Details += "Repaired after waiting: $filePath"
                    } else {
                        $results.FailureCount++
                        $results.PermissionErrors += $filePath
                        $results.Details += "Failed to repair: $filePath"
                    }
                } else {
                    $results.FailureCount++
                    $results.Details += "Timeout waiting for access: $filePath"
                }
            } else {
                $results.FailureCount++
                $results.Details += "File locked, use -Force to attempt repair: $filePath"
            }
        } else {
            # Try to set permissions
            if (Set-FilePermissions -FilePath $filePath) {
                $results.SuccessCount++
                $results.Details += "Permissions repaired: $filePath"
            } else {
                $results.FailureCount++
                $results.PermissionErrors += $filePath
                $results.Details += "Failed to set permissions: $filePath"
            }
        }
    }

    # Summary
    Write-LogInfo "=== FILE PERMISSION REPAIR SUMMARY ==="
    Write-LogInfo "Total files processed: $($results.TotalFiles)"
    Write-LogSuccess "Successfully repaired: $($results.SuccessCount)"
    if ($results.FailureCount -gt 0) {
        Write-LogError "Failed to repair: $($results.FailureCount)"
    }
    if ($results.LockedFiles.Count -gt 0) {
        Write-LogWarning "Locked files detected: $($results.LockedFiles.Count)"
    }
    if ($results.PermissionErrors.Count -gt 0) {
        Write-LogError "Permission errors: $($results.PermissionErrors.Count)"
    }

    return $results
}

function Get-VSCodeDatabaseFiles {
    <#
    .SYNOPSIS
        Gets all VS Code and Cursor database and configuration files
    .EXAMPLE
        Get-VSCodeDatabaseFiles
    #>
    [CmdletBinding()]
    param()

    $files = @()
    $basePaths = @(
        "$env:APPDATA\Code",
        "$env:APPDATA\Cursor",
        "$env:LOCALAPPDATA\Code",
        "$env:LOCALAPPDATA\Cursor"
    )

    foreach ($basePath in $basePaths) {
        if (Test-Path $basePath) {
            Write-LogDebug "Scanning: $basePath"

            # Database files
            $dbPaths = @(
                "$basePath\User\globalStorage\state.vscdb",           # Main database
                "$basePath\User\workspaceStorage\*\state.vscdb",      # Workspace databases
                "$basePath\User\globalStorage\*\state.vscdb"          # Extension databases
            )

            foreach ($dbPath in $dbPaths) {
                if ($dbPath -like "*\*\*") {
                    # Pattern with wildcards
                    $dbFiles = Get-ChildItem -Path $dbPath -ErrorAction SilentlyContinue
                    foreach ($dbFile in $dbFiles) {
                        $files += $dbFile.FullName
                    }
                } else {
                    # Direct path
                    if (Test-Path $dbPath) {
                        $files += $dbPath
                    }
                }
            }

            # Configuration files
            $configPaths = @(
                "$basePath\User\storage.json",
                "$basePath\User\globalStorage\storage.json",
                "$basePath\User\settings.json"
            )

            foreach ($configPath in $configPaths) {
                if (Test-Path $configPath) {
                    $files += $configPath
                }
            }
        }
    }

    Write-LogInfo "Found $($files.Count) VS Code/Cursor files to check"
    return $files
}

function Start-PermissionRepair {
    <#
    .SYNOPSIS
        Main function to start permission repair process
    .EXAMPLE
        Start-PermissionRepair
    #>
    [CmdletBinding()]
    param()

    Write-LogInfo "Starting VS Code/Cursor file permission repair..."
    Write-LogInfo "DryRun: $DryRun, Force: $Force, VerboseOutput: $VerboseOutput"

    try {
        # Get all relevant files
        if ($TargetPath) {
            if (Test-Path $TargetPath) {
                $filesToCheck = @($TargetPath)
            } else {
                Write-LogError "Target path does not exist: $TargetPath"
                return $false
            }
        } else {
            $filesToCheck = Get-VSCodeDatabaseFiles
        }

        if ($filesToCheck.Count -eq 0) {
            Write-LogWarning "No files found to check"
            return $true
        }

        # Repair permissions
        $repairResult = Repair-FilePermissions -FilePaths $filesToCheck

        # Final status
        if ($repairResult.FailureCount -eq 0) {
            Write-LogSuccess "All file permissions are correct!"
            return $true
        } else {
            Write-LogWarning "Some files could not be repaired. Check the details above."
            if ($repairResult.LockedFiles.Count -gt 0) {
                Write-LogWarning "Note: Some files are locked by running VS Code/Cursor processes"
                Write-LogInfo "This is normal and expected when applications are running"
            }
            return $false
        }

    } catch {
        Write-LogError "Permission repair failed: $($_.Exception.Message)"
        return $false
    }
}

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    Start-PermissionRepair
}

function Get-VSCodeDatabaseFiles {
    <#
    .SYNOPSIS
        Gets all VS Code and Cursor database and configuration files
    .EXAMPLE
        Get-VSCodeDatabaseFiles
    #>
    [CmdletBinding()]
    param()

    $files = @()
    $basePaths = @(
        "$env:APPDATA\Code",
        "$env:APPDATA\Cursor",
        "$env:LOCALAPPDATA\Code",
        "$env:LOCALAPPDATA\Cursor"
    )

    foreach ($basePath in $basePaths) {
        if (Test-Path $basePath) {
            Write-LogDebug "Scanning: $basePath"

            # Database files
            $dbPaths = @(
                "$basePath\User\globalStorage\state.vscdb",           # Main database
                "$basePath\User\workspaceStorage\*\state.vscdb",      # Workspace databases
                "$basePath\User\globalStorage\*\state.vscdb"          # Extension databases
            )

            foreach ($dbPath in $dbPaths) {
                if ($dbPath -like "*\*\*") {
                    # Pattern with wildcards
                    $dbFiles = Get-ChildItem -Path $dbPath -ErrorAction SilentlyContinue
                    foreach ($dbFile in $dbFiles) {
                        $files += $dbFile.FullName
                    }
                } else {
                    # Direct path
                    if (Test-Path $dbPath) {
                        $files += $dbPath
                    }
                }
            }

            # Configuration files
            $configPaths = @(
                "$basePath\User\storage.json",
                "$basePath\User\globalStorage\storage.json",
                "$basePath\User\settings.json"
            )

            foreach ($configPath in $configPaths) {
                if (Test-Path $configPath) {
                    $files += $configPath
                }
            }
        }
    }

    Write-LogInfo "Found $($files.Count) VS Code/Cursor files to check"
    return $files
}

function Start-PermissionRepair {
    <#
    .SYNOPSIS
        Main function to start permission repair process
    .EXAMPLE
        Start-PermissionRepair
    #>
    [CmdletBinding()]
    param()

    Write-LogInfo "Starting VS Code/Cursor file permission repair..."
    Write-LogInfo "DryRun: $DryRun, Force: $Force, VerboseOutput: $VerboseOutput"

    try {
        # Get all relevant files
        if ($TargetPath) {
            if (Test-Path $TargetPath) {
                $filesToCheck = @($TargetPath)
            } else {
                Write-LogError "Target path does not exist: $TargetPath"
                return $false
            }
        } else {
            $filesToCheck = Get-VSCodeDatabaseFiles
        }

        if ($filesToCheck.Count -eq 0) {
            Write-LogWarning "No files found to check"
            return $true
        }

        # Repair permissions
        $repairResult = Repair-FilePermissions -FilePaths $filesToCheck

        # Final status
        if ($repairResult.FailureCount -eq 0) {
            Write-LogSuccess "All file permissions are correct!"
            return $true
        } else {
            Write-LogWarning "Some files could not be repaired. Check the details above."
            if ($repairResult.LockedFiles.Count -gt 0) {
                Write-LogWarning "Recommendation: Close VS Code/Cursor and run with -Force flag"
            }
            return $false
        }

    } catch {
        Write-LogError "Permission repair failed: $($_.Exception.Message)"
        return $false
    }
}

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    Start-PermissionRepair
}
