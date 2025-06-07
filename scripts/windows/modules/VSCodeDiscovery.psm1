# VSCodeDiscovery.psm1
#
# Description: VS Code installation discovery module with production-verified methods
# Based on augment-vip-powershell implementation
#
# Author: Augment VIP Project
# Version: 1.0.0

# Import required modules
Import-Module (Join-Path $PSScriptRoot "Logger.psm1") -Force

# VS Code installation types
enum VSCodeType {
    Standard
    Insiders
    Portable
}

# VS Code installation class
class VSCodeInstallation {
    [VSCodeType]$Type
    [string]$Name
    [string]$Path
    [string]$DataPath
    [string]$UserDataPath
    [string]$StorageJsonPath
    [string[]]$DatabasePaths
    [string]$Version
    [bool]$IsValid
    
    VSCodeInstallation([VSCodeType]$type, [string]$name, [string]$path) {
        $this.Type = $type
        $this.Name = $name
        $this.Path = $path
        $this.DatabasePaths = @()
        $this.IsValid = $false
    }
}

<#
.SYNOPSIS
    Discovers all VS Code installations on the system using production-verified logic
.PARAMETER IncludePortable
    Include portable installations in the search
.OUTPUTS
    VSCodeInstallation[] - Array of discovered installations
#>
function Find-VSCodeInstallations {
    [CmdletBinding()]
    param(
        [switch]$IncludePortable = $true
    )
    
    Write-LogInfo "Discovering VS Code installations using production-tested logic..."
    
    $installations = @()
    
    # Use production-verified method to check for VS Code data directories
    $appData = $env:APPDATA
    $localAppData = $env:LOCALAPPDATA
    
    Write-LogDebug "AppData path: $appData"
    Write-LogDebug "LocalAppData path: $localAppData"
    
    # Check for standard VS Code
    $codePath = Join-Path $appData "Code"
    if (Test-Path $codePath) {
        Write-LogDebug "Found VS Code data directory at: $codePath"
        $installation = [VSCodeInstallation]::new([VSCodeType]::Standard, "VS Code", "Standard Installation")
        $installations += $installation
    }
    
    # Check for VS Code Insiders
    $codeInsidersPath = Join-Path $appData "Code - Insiders"
    if (Test-Path $codeInsidersPath) {
        Write-LogDebug "Found VS Code Insiders data directory at: $codeInsidersPath"
        $installation = [VSCodeInstallation]::new([VSCodeType]::Insiders, "VS Code Insiders", "Insiders Installation")
        $installations += $installation
    }
    
    # Check for portable installations if enabled
    if ($IncludePortable) {
        $installations += Find-PortableVSCode
    }
    
    # Complete installation information
    foreach ($installation in $installations) {
        Complete-InstallationInfo -Installation $installation
    }
    
    $validInstallations = $installations | Where-Object { $_.IsValid }
    
    Write-LogInfo "Found $($validInstallations.Count) valid VS Code installation(s)"
    foreach ($install in $validInstallations) {
        Write-LogSuccess "$($install.Name) - Data: $($install.DataPath)"
    }
    
    return $validInstallations
}

<#
.SYNOPSIS
    Finds standard VS Code installations
.OUTPUTS
    VSCodeInstallation[] - Array of standard installations
#>
function Find-StandardVSCode {
    [CmdletBinding()]
    param()

    Write-LogDebug "Searching for standard VS Code installations..."
    
    $installations = @()
    $searchPaths = @(
        # User installation
        (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code"),
        # System installation
        "${env:ProgramFiles}\Microsoft VS Code",
        "${env:ProgramFiles(x86)}\Microsoft VS Code"
    )
    
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $codeExe = Join-Path $path "Code.exe"
            if (Test-Path $codeExe) {
                Write-LogDebug "Found standard VS Code at: $path"
                $installation = [VSCodeInstallation]::new([VSCodeType]::Standard, "VS Code", $path)
                $installations += $installation
            }
        }
    }
    
    return $installations
}

<#
.SYNOPSIS
    Finds VS Code Insiders installations
.OUTPUTS
    VSCodeInstallation[] - Array of Insiders installations
#>
function Find-InsidersVSCode {
    [CmdletBinding()]
    param()

    Write-LogDebug "Searching for VS Code Insiders installations..."
    
    $installations = @()
    $searchPaths = @(
        # User installation
        (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code Insiders"),
        # System installation
        "${env:ProgramFiles}\Microsoft VS Code Insiders",
        "${env:ProgramFiles(x86)}\Microsoft VS Code Insiders"
    )
    
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $codeExe = Join-Path $path "Code - Insiders.exe"
            if (Test-Path $codeExe) {
                Write-LogDebug "Found VS Code Insiders at: $path"
                $installation = [VSCodeInstallation]::new([VSCodeType]::Insiders, "VS Code Insiders", $path)
                $installations += $installation
            }
        }
    }
    
    return $installations
}

<#
.SYNOPSIS
    Finds portable VS Code installations
.OUTPUTS
    VSCodeInstallation[] - Array of portable installations
#>
function Find-PortableVSCode {
    [CmdletBinding()]
    param()

    Write-LogDebug "Searching for portable VS Code installations..."
    
    $installations = @()
    
    # Common portable installation locations
    $searchLocations = @(
        # Current directory and subdirectories
        ".",
        ".\VSCode",
        ".\Code",
        ".\VSCode-Portable",
        # Common portable app directories
        "${env:SystemDrive}\PortableApps\VSCode",
        "${env:SystemDrive}\Portable\VSCode",
        "${env:USERPROFILE}\Portable\VSCode",
        "${env:USERPROFILE}\Desktop\VSCode"
    )
    
    foreach ($location in $searchLocations) {
        if (Test-Path $location) {
            $portableInstalls = Find-PortableInDirectory -Directory $location
            $installations += $portableInstalls
        }
    }
    
    return $installations
}

<#
.SYNOPSIS
    Searches for portable VS Code in a specific directory
.PARAMETER Directory
    Directory to search in
.OUTPUTS
    VSCodeInstallation[] - Array of portable installations found
#>
function Find-PortableInDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory
    )
    
    $installations = @()
    
    try {
        # Look for Code.exe in the directory and subdirectories
        $codeExes = Get-ChildItem -Path $Directory -Filter "Code.exe" -Recurse -ErrorAction SilentlyContinue
        
        foreach ($exe in $codeExes) {
            $installPath = $exe.Directory.FullName
            
            # Check if this looks like a portable installation
            $dataDir = Join-Path $installPath "data"
            if (Test-Path $dataDir) {
                Write-LogDebug "Found portable VS Code at: $installPath"
                $installation = [VSCodeInstallation]::new([VSCodeType]::Portable, "VS Code Portable", $installPath)
                $installations += $installation
            }
        }
    }
    catch {
        Write-LogDebug "Error searching directory $Directory`: $($_.Exception.Message)"
    }
    
    return $installations
}

<#
.SYNOPSIS
    Completes installation information for a VS Code installation
.PARAMETER Installation
    VS Code installation object to complete
#>
function Complete-InstallationInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [VSCodeInstallation]$Installation
    )
    
    try {
        # Set data paths based on installation type
        switch ($Installation.Type) {
            ([VSCodeType]::Standard) {
                $Installation.DataPath = Join-Path $env:APPDATA "Code"
                $Installation.UserDataPath = Join-Path $Installation.DataPath "User"
            }
            ([VSCodeType]::Insiders) {
                $Installation.DataPath = Join-Path $env:APPDATA "Code - Insiders"
                $Installation.UserDataPath = Join-Path $Installation.DataPath "User"
            }
            ([VSCodeType]::Portable) {
                $Installation.DataPath = Join-Path $Installation.Path "data\user-data"
                $Installation.UserDataPath = Join-Path $Installation.DataPath "User"
            }
        }
        
        # Set storage.json path
        $Installation.StorageJsonPath = Join-Path $Installation.UserDataPath "storage.json"
        
        # Find database files
        $Installation.DatabasePaths = Find-DatabaseFiles -DataPath $Installation.DataPath
        
        # Get version information
        $Installation.Version = Get-VSCodeVersion -InstallPath $Installation.Path
        
        # Validate installation
        $Installation.IsValid = Test-InstallationValidity -Installation $Installation
        
        if ($Installation.IsValid) {
            Write-LogDebug "Completed info for $($Installation.Name) - Version: $($Installation.Version)"
        }
    }
    catch {
        Write-LogError "Failed to complete installation info for $($Installation.Name)" -Exception $_.Exception
        $Installation.IsValid = $false
    }
}

<#
.SYNOPSIS
    Finds database files for a VS Code installation using production-tested patterns
.PARAMETER DataPath
    VS Code data directory path
.OUTPUTS
    string[] - Array of database file paths
#>
function Find-DatabaseFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DataPath
    )

    $databasePaths = @()

    if (-not (Test-Path $DataPath)) {
        Write-LogDebug "Data path does not exist: $DataPath"
        return $databasePaths
    }

    # Use production-verified database file patterns
    $patterns = @(
        # Workspace storage
        "User\workspaceStorage\*\state.vscdb",
        "User\globalStorage\*\state.vscdb",
        # Cache
        "Cache\*\*.vscdb",
        "CachedData\*\*.vscdb",
        # Logs
        "logs\*\*.vscdb",
        # Other database files
        "User\*\*.vscdb",
        "User\workspaceStorage\*\*.vscdb",
        "User\globalStorage\*\*.vscdb"
    )

    foreach ($pattern in $patterns) {
        $fullPattern = Join-Path $DataPath $pattern
        try {
            $files = Get-ChildItem -Path $fullPattern -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                $databasePaths += $file.FullName
                Write-LogDebug "Found database file: $($file.FullName)"
            }
        }
        catch {
            # Ignore errors for missing paths
            Write-LogDebug "Pattern not found: $fullPattern"
        }
    }

    Write-LogDebug "Found $($databasePaths.Count) database files in $DataPath"
    return $databasePaths
}

<#
.SYNOPSIS
    Gets VS Code version from installation
.PARAMETER InstallPath
    VS Code installation path
.OUTPUTS
    string - Version string
#>
function Get-VSCodeVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallPath
    )

    try {
        # Try to get version from package.json
        $packageJson = Join-Path $InstallPath "resources\app\package.json"
        if (Test-Path $packageJson) {
            $package = Get-Content $packageJson | ConvertFrom-Json
            return $package.version
        }

        # Try to get version from executable
        $codeExe = Get-ChildItem -Path $InstallPath -Filter "Code*.exe" | Select-Object -First 1
        if ($codeExe) {
            $version = (Get-ItemProperty $codeExe.FullName).VersionInfo.ProductVersion
            if ($version) {
                return $version
            }
        }

        return "Unknown"
    }
    catch {
        return "Unknown"
    }
}

<#
.SYNOPSIS
    Tests if a VS Code installation is valid
.PARAMETER Installation
    VS Code installation to test
.OUTPUTS
    bool - True if installation is valid
#>
function Test-InstallationValidity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [VSCodeInstallation]$Installation
    )

    # Check if data directory exists (most reliable method)
    if (-not (Test-Path $Installation.DataPath)) {
        Write-LogDebug "$($Installation.Name): Data directory not found at $($Installation.DataPath)"
        return $false
    }

    # Check if User directory exists
    if (-not (Test-Path $Installation.UserDataPath)) {
        Write-LogDebug "$($Installation.Name): User data directory not found at $($Installation.UserDataPath)"
        return $false
    }

    # For portable installations, check specific data directory structure
    if ($Installation.Type -eq [VSCodeType]::Portable) {
        $dataDir = Join-Path $Installation.Path "data"
        if (-not (Test-Path $dataDir)) {
            Write-LogDebug "$($Installation.Name): No data directory found for portable installation"
            return $false
        }
    }

    # Check if there are database files or storage.json file
    $hasData = $false
    if ($Installation.DatabasePaths.Count -gt 0) {
        $hasData = $true
    } elseif (Test-Path $Installation.StorageJsonPath) {
        $hasData = $true
    }

    if (-not $hasData) {
        Write-LogDebug "$($Installation.Name): No database files or storage.json found"
        # Even without data files, consider valid if directory structure is correct
        # return $false
    }

    Write-LogDebug "$($Installation.Name): Installation is valid"
    return $true
}

<#
.SYNOPSIS
    Gets a specific VS Code installation by type
.PARAMETER Type
    VS Code installation type
.OUTPUTS
    VSCodeInstallation - First installation of the specified type
#>
function Get-VSCodeInstallation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [VSCodeType]$Type
    )

    $installations = Find-VSCodeInstallations
    return $installations | Where-Object { $_.Type -eq $Type } | Select-Object -First 1
}

<#
.SYNOPSIS
    Gets VS Code database file paths using production-verified method
.OUTPUTS
    string[] - Array of database file path patterns
#>
function Get-VSCodeDatabasePaths {
    $paths = @()

    # Windows paths
    $appData = $env:APPDATA
    $localAppData = $env:LOCALAPPDATA

    # Check AppData paths
    $codePath = Join-Path $appData "Code"
    if (Test-Path $codePath) {
        $paths += @(
            # Workspace storage
            (Join-Path $codePath "User\workspaceStorage\*\state.vscdb"),
            (Join-Path $codePath "User\globalStorage\*\state.vscdb"),
            # Cache
            (Join-Path $codePath "Cache\*\*.vscdb"),
            (Join-Path $codePath "CachedData\*\*.vscdb"),
            # Logs
            (Join-Path $codePath "logs\*\*.vscdb"),
            # Other database files
            (Join-Path $codePath "User\*\*.vscdb"),
            (Join-Path $codePath "User\workspaceStorage\*\*.vscdb"),
            (Join-Path $codePath "User\globalStorage\*\*.vscdb")
        )
    }

    # Check LocalAppData paths
    $codePath = Join-Path $localAppData "Programs\Microsoft VS Code"
    if (Test-Path $codePath) {
        $paths += @(
            (Join-Path $codePath "resources\app\out\vs\workbench\workbench.desktop.main.js"),
            (Join-Path $codePath "resources\app\out\vs\workbench\workbench.desktop.main.js.map")
        )
    }

    # Check Insiders version
    $codeInsidersPath = Join-Path $appData "Code - Insiders"
    if (Test-Path $codeInsidersPath) {
        $paths += @(
            (Join-Path $codeInsidersPath "User\workspaceStorage\*\state.vscdb"),
            (Join-Path $codeInsidersPath "User\globalStorage\*\state.vscdb"),
            (Join-Path $codeInsidersPath "Cache\*\*.vscdb"),
            (Join-Path $codeInsidersPath "CachedData\*\*.vscdb"),
            (Join-Path $codeInsidersPath "logs\*\*.vscdb"),
            (Join-Path $codeInsidersPath "User\*\*.vscdb"),
            (Join-Path $codeInsidersPath "User\workspaceStorage\*\*.vscdb"),
            (Join-Path $codeInsidersPath "User\globalStorage\*\*.vscdb")
        )
    }

    return $paths
}

<#
.SYNOPSIS
    Gets VS Code storage.json file path using production-verified method
.OUTPUTS
    string - Path to storage.json file or null if not found
#>
function Get-VSCodeStoragePath {
    $paths = @()

    # Standard paths
    $appData = $env:APPDATA
    $localAppData = $env:LOCALAPPDATA

    Write-LogInfo "Checking VS Code storage locations..."
    Write-LogInfo "AppData path: $appData"
    Write-LogInfo "LocalAppData path: $localAppData"

    # Check standard paths
    $paths += @(
        # User directory files
        (Join-Path $appData "Code\User\storage.json"),
        (Join-Path $appData "Code\User\globalStorage\storage.json"),
        (Join-Path $localAppData "Code\User\storage.json"),
        (Join-Path $localAppData "Code\User\globalStorage\storage.json"),
        # Insiders version
        (Join-Path $appData "Code - Insiders\User\storage.json"),
        (Join-Path $appData "Code - Insiders\User\globalStorage\storage.json"),
        (Join-Path $localAppData "Code - Insiders\User\storage.json"),
        (Join-Path $localAppData "Code - Insiders\User\globalStorage\storage.json"),
        # Other possible storage locations
        (Join-Path $appData "Code\User\workspaceStorage\*\storage.json"),
        (Join-Path $appData "Code\User\workspaceStorage\*\globalStorage\storage.json"),
        (Join-Path $localAppData "Code\User\workspaceStorage\*\storage.json"),
        (Join-Path $localAppData "Code\User\workspaceStorage\*\globalStorage\storage.json"),
        # Cache files
        (Join-Path $appData "Code\Cache\*\storage.json"),
        (Join-Path $localAppData "Code\Cache\*\storage.json"),
        # Log files
        (Join-Path $appData "Code\logs\*\storage.json"),
        (Join-Path $localAppData "Code\logs\*\storage.json")
    )

    # Check portable paths
    $portablePaths = @(
        ".\data\user-data\User\storage.json",
        ".\data\user-data\User\globalStorage\storage.json",
        ".\user-data\User\storage.json",
        ".\user-data\User\globalStorage\storage.json"
    )

    foreach ($path in $portablePaths) {
        if (Test-Path $path) {
            $paths += $path
        }
    }

    # Check all possible paths
    foreach ($path in $paths) {
        Write-LogInfo "Checking path: $path"
        if (Test-Path $path) {
            Write-LogSuccess "Found VS Code storage.json at: $path"
            return $path
        }
    }

    # If no file found, try searching entire VS Code directories
    Write-LogInfo "Searching for storage.json in VS Code directories..."
    $codeDirs = @(
        (Join-Path $appData "Code"),
        (Join-Path $localAppData "Code"),
        (Join-Path $appData "Code - Insiders"),
        (Join-Path $localAppData "Code - Insiders")
    )

    foreach ($dir in $codeDirs) {
        if (Test-Path $dir) {
            Write-LogInfo "Searching in: $dir"
            $foundFiles = Get-ChildItem -Path $dir -Recurse -Filter "storage.json" -ErrorAction SilentlyContinue
            if ($foundFiles) {
                foreach ($file in $foundFiles) {
                    Write-LogSuccess "Found storage.json at: $($file.FullName)"
                    return $file.FullName
                }
            }
        }
    }

    Write-LogWarning "VS Code storage.json not found in any of the following locations:"
    foreach ($path in $paths) {
        Write-LogWarning "  - $path"
    }
    return $null
}

# Export module functions
Export-ModuleMember -Function @(
    'Find-VSCodeInstallations',
    'Find-StandardVSCode',
    'Find-InsidersVSCode',
    'Find-PortableVSCode',
    'Get-VSCodeInstallation',
    'Get-VSCodeDatabasePaths',
    'Get-VSCodeStoragePath'
)
