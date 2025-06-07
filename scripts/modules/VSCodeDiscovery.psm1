# VSCodeDiscovery.psm1
#
# Description: VS Code installation discovery module
# Automatically detects standard, Insiders, and portable VS Code installations
#
# Author: Augment VIP Project
# Version: 1.0.0

# Import Logger module
Import-Module (Join-Path $PSScriptRoot "Logger.psm1") -Force

# VS Code installation types
enum VSCodeType {
    Standard = 0
    Insiders = 1
    Portable = 2
}

# VS Code installation information class
class VSCodeInstallation {
    [VSCodeType]$Type
    [string]$Name
    [string]$Path
    [string]$DataPath
    [string]$UserDataPath
    [string]$StorageJsonPath
    [string[]]$DatabasePaths
    [bool]$IsValid
    [string]$Version
    
    VSCodeInstallation([VSCodeType]$type, [string]$name, [string]$path) {
        $this.Type = $type
        $this.Name = $name
        $this.Path = $path
        $this.IsValid = $false
        $this.DatabasePaths = @()
    }
}

<#
.SYNOPSIS
    Discovers all VS Code installations on the system
.DESCRIPTION
    Scans for standard, Insiders, and portable VS Code installations
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
    
    Write-LogInfo "Discovering VS Code installations..."
    
    $installations = @()
    
    # Find standard installations
    $installations += Find-StandardVSCode
    
    # Find Insiders installations
    $installations += Find-InsidersVSCode
    
    # Find portable installations
    if ($IncludePortable) {
        $installations += Find-PortableVSCode
    }
    
    # Validate and populate installation details
    foreach ($installation in $installations) {
        Complete-InstallationInfo -Installation $installation
    }
    
    $validInstallations = $installations | Where-Object { $_.IsValid }
    
    Write-LogInfo "Found $($validInstallations.Count) valid VS Code installation(s)"
    foreach ($install in $validInstallations) {
        Write-LogSuccess "$($install.Name) - $($install.Path)"
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
    
    # Search in common drive roots (limited to C: and D: for security)
    $allowedDrives = @("C", "D")
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -in $allowedDrives -and $_.Used -gt 0 }
    foreach ($drive in $drives) {
        $driveRoot = "$($drive.Name):\"
        $portablePaths = @(
            (Join-Path $driveRoot "VSCode"),
            (Join-Path $driveRoot "Code"),
            (Join-Path $driveRoot "PortableApps\VSCode")
        )

        foreach ($path in $portablePaths) {
            # Validate path to prevent traversal attacks
            if ((Test-Path $path) -and $path.StartsWith($driveRoot)) {
                $portableInstalls = Find-PortableInDirectory -Directory $path
                $installations += $portableInstalls
            }
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
    Finds database files for a VS Code installation
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
        return $databasePaths
    }
    
    # Database file patterns
    $patterns = @(
        "User\workspaceStorage\*\state.vscdb",
        "User\globalStorage\*\state.vscdb",
        "Cache\*\*.vscdb",
        "CachedData\*\*.vscdb",
        "logs\*\*.vscdb",
        "User\*\*.vscdb"
    )
    
    foreach ($pattern in $patterns) {
        $fullPattern = Join-Path $DataPath $pattern
        try {
            $files = Get-ChildItem -Path $fullPattern -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                $databasePaths += $file.FullName
            }
        }
        catch {
            # Ignore errors for missing paths
        }
    }
    
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
    
    # Check if executable exists
    $exeNames = @("Code.exe", "Code - Insiders.exe")
    $hasExecutable = $false
    
    foreach ($exeName in $exeNames) {
        $exePath = Join-Path $Installation.Path $exeName
        if (Test-Path $exePath) {
            $hasExecutable = $true
            break
        }
    }
    
    if (-not $hasExecutable) {
        Write-LogDebug "$($Installation.Name): No executable found"
        return $false
    }
    
    # For portable installations, check data directory
    if ($Installation.Type -eq [VSCodeType]::Portable) {
        $dataDir = Join-Path $Installation.Path "data"
        if (-not (Test-Path $dataDir)) {
            Write-LogDebug "$($Installation.Name): No data directory found for portable installation"
            return $false
        }
    }
    
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

# Export module functions
Export-ModuleMember -Function @(
    'Find-VSCodeInstallations',
    'Find-StandardVSCode',
    'Find-InsidersVSCode',
    'Find-PortableVSCode',
    'Get-VSCodeInstallation'
)
