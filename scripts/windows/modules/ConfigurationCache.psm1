# ConfigurationCache.psm1 - Configuration Cache Module for Augment VIP
# Provides configuration caching functionality to reduce parsing overhead

# Import required modules
Import-Module (Join-Path $PSScriptRoot "Logger.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "CommonUtils.psm1") -Force

# Module variables
$script:MemoryCache = @{}
$script:CacheDirectory = $null
$script:CacheEnabled = $true
$script:MaxCacheAge = 3600 # 1 hour in seconds
$script:MaxMemoryCacheSize = 100 # Maximum number of items in memory cache

<#
.SYNOPSIS
    Initializes the configuration cache system
.DESCRIPTION
    Sets up cache directory and validates cache functionality
.PARAMETER CacheDirectory
    Directory to store cache files (optional, uses temp if not specified)
.PARAMETER MaxCacheAge
    Maximum age of cache entries in seconds (default: 3600)
#>
function Initialize-ConfigurationCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$CacheDirectory,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxCacheAge = 3600
    )
    
    try {
        Write-LogInfo "Initializing configuration cache..."
        
        # Set cache directory
        if (-not $CacheDirectory) {
            $script:CacheDirectory = Join-Path $env:TEMP "augment-vip-cache"
        } else {
            $script:CacheDirectory = $CacheDirectory
        }
        
        # Create cache directory if it doesn't exist
        if (-not (Test-Path $script:CacheDirectory)) {
            New-Item -Path $script:CacheDirectory -ItemType Directory -Force | Out-Null
            Write-LogInfo "Created cache directory: $($script:CacheDirectory)"
        }
        
        # Set cache parameters
        $script:MaxCacheAge = $MaxCacheAge
        
        # Clean up old cache files
        Clear-ExpiredCache
        
        Write-LogSuccess "Configuration cache initialized successfully"
        Write-LogInfo "Cache directory: $($script:CacheDirectory)"
        Write-LogInfo "Max cache age: $($script:MaxCacheAge) seconds"
        
        return $true
    }
    catch {
        Write-LogError "Failed to initialize configuration cache: $($_.Exception.Message)"
        $script:CacheEnabled = $false
        return $false
    }
}

<#
.SYNOPSIS
    Gets a cached configuration value
.DESCRIPTION
    Retrieves a configuration value from memory or file cache
.PARAMETER Key
    The cache key to retrieve
.OUTPUTS
    The cached value or $null if not found or expired
#>
function Get-CachedConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key
    )
    
    try {
        if (-not $script:CacheEnabled) {
            return $null
        }
        
        # Check memory cache first
        if ($script:MemoryCache.ContainsKey($Key)) {
            $cacheEntry = $script:MemoryCache[$Key]
            
            # Check if entry is still valid
            if ((Get-Date) -lt $cacheEntry.ExpiryTime) {
                Write-LogDebug "Cache hit (memory): $Key"
                return $cacheEntry.Value
            } else {
                # Remove expired entry
                $script:MemoryCache.Remove($Key)
                Write-LogDebug "Cache expired (memory): $Key"
            }
        }
        
        # Check file cache
        $cacheFile = Join-Path $script:CacheDirectory "$Key.cache"
        if (Test-Path $cacheFile) {
            $fileInfo = Get-Item $cacheFile
            $ageInSeconds = ((Get-Date) - $fileInfo.LastWriteTime).TotalSeconds
            
            if ($ageInSeconds -lt $script:MaxCacheAge) {
                try {
                    $cachedData = Get-Content $cacheFile -Raw | ConvertFrom-Json
                    
                    # Add to memory cache for faster access
                    Set-MemoryCache -Key $Key -Value $cachedData -ExpiryTime (Get-Date).AddSeconds($script:MaxCacheAge - $ageInSeconds)
                    
                    Write-LogDebug "Cache hit (file): $Key"
                    return $cachedData
                }
                catch {
                    Write-LogWarning "Failed to read cache file: $cacheFile"
                    Remove-Item $cacheFile -Force -ErrorAction SilentlyContinue
                }
            } else {
                # Remove expired file
                Remove-Item $cacheFile -Force -ErrorAction SilentlyContinue
                Write-LogDebug "Cache expired (file): $Key"
            }
        }
        
        Write-LogDebug "Cache miss: $Key"
        return $null
    }
    catch {
        Write-LogError "Error retrieving cached configuration: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
    Sets a cached configuration value
.DESCRIPTION
    Stores a configuration value in both memory and file cache
.PARAMETER Key
    The cache key to set
.PARAMETER Value
    The value to cache
.PARAMETER ExpiryTime
    Optional custom expiry time (default: current time + MaxCacheAge)
#>
function Set-CachedConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        
        [Parameter(Mandatory = $true)]
        $Value,
        
        [Parameter(Mandatory = $false)]
        [DateTime]$ExpiryTime
    )
    
    try {
        if (-not $script:CacheEnabled) {
            return
        }
        
        # Set default expiry time
        if (-not $ExpiryTime) {
            $ExpiryTime = (Get-Date).AddSeconds($script:MaxCacheAge)
        }
        
        # Add to memory cache
        Set-MemoryCache -Key $Key -Value $Value -ExpiryTime $ExpiryTime
        
        # Save to file cache
        try {
            $cacheFile = Join-Path $script:CacheDirectory "$Key.cache"
            $Value | ConvertTo-Json -Depth 10 | Set-Content $cacheFile -Encoding UTF8
            Write-LogDebug "Cached configuration: $Key"
        }
        catch {
            Write-LogWarning "Failed to save cache file for key: $Key"
        }
    }
    catch {
        Write-LogError "Error setting cached configuration: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Sets a value in memory cache
.DESCRIPTION
    Internal function to manage memory cache with size limits
.PARAMETER Key
    The cache key
.PARAMETER Value
    The value to cache
.PARAMETER ExpiryTime
    The expiry time for the cache entry
#>
function Set-MemoryCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        
        [Parameter(Mandatory = $true)]
        $Value,
        
        [Parameter(Mandatory = $true)]
        [DateTime]$ExpiryTime
    )
    
    # Check if we need to clean up memory cache
    if ($script:MemoryCache.Count -ge $script:MaxMemoryCacheSize) {
        # Remove oldest entries
        $sortedEntries = $script:MemoryCache.GetEnumerator() | Sort-Object { $_.Value.ExpiryTime }
        $entriesToRemove = $sortedEntries | Select-Object -First ($script:MemoryCache.Count - $script:MaxMemoryCacheSize + 1)
        
        foreach ($entry in $entriesToRemove) {
            $script:MemoryCache.Remove($entry.Key)
        }
    }
    
    # Add or update the cache entry
    $script:MemoryCache[$Key] = @{
        Value = $Value
        ExpiryTime = $ExpiryTime
        CreatedTime = Get-Date
    }
}

<#
.SYNOPSIS
    Removes a cached configuration value
.DESCRIPTION
    Removes a configuration value from both memory and file cache
.PARAMETER Key
    The cache key to remove
#>
function Remove-CachedConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key
    )
    
    try {
        # Remove from memory cache
        if ($script:MemoryCache.ContainsKey($Key)) {
            $script:MemoryCache.Remove($Key)
        }
        
        # Remove from file cache
        $cacheFile = Join-Path $script:CacheDirectory "$Key.cache"
        if (Test-Path $cacheFile) {
            Remove-Item $cacheFile -Force
        }
        
        Write-LogDebug "Removed cached configuration: $Key"
    }
    catch {
        Write-LogError "Error removing cached configuration: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Clears all expired cache entries
.DESCRIPTION
    Removes expired entries from both memory and file cache
#>
function Clear-ExpiredCache {
    [CmdletBinding()]
    param()
    
    try {
        $currentTime = Get-Date
        $removedCount = 0
        
        # Clean memory cache
        $expiredKeys = @()
        foreach ($entry in $script:MemoryCache.GetEnumerator()) {
            if ($currentTime -gt $entry.Value.ExpiryTime) {
                $expiredKeys += $entry.Key
            }
        }
        
        foreach ($key in $expiredKeys) {
            $script:MemoryCache.Remove($key)
            $removedCount++
        }
        
        # Clean file cache
        if (Test-Path $script:CacheDirectory) {
            $cacheFiles = Get-ChildItem $script:CacheDirectory -Filter "*.cache"
            foreach ($file in $cacheFiles) {
                $ageInSeconds = ($currentTime - $file.LastWriteTime).TotalSeconds
                if ($ageInSeconds -gt $script:MaxCacheAge) {
                    Remove-Item $file.FullName -Force
                    $removedCount++
                }
            }
        }
        
        if ($removedCount -gt 0) {
            Write-LogInfo "Cleared $removedCount expired cache entries"
        }
    }
    catch {
        Write-LogError "Error clearing expired cache: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Gets cache statistics
.DESCRIPTION
    Returns information about cache usage and performance
.OUTPUTS
    Hashtable with cache statistics
#>
function Get-CacheStatistics {
    [CmdletBinding()]
    param()
    
    try {
        $fileCount = 0
        $totalFileSize = 0
        
        if (Test-Path $script:CacheDirectory) {
            $cacheFiles = Get-ChildItem $script:CacheDirectory -Filter "*.cache"
            $fileCount = $cacheFiles.Count
            $totalFileSize = ($cacheFiles | Measure-Object Length -Sum).Sum
        }
        
        return @{
            MemoryCacheEntries = $script:MemoryCache.Count
            FileCacheEntries = $fileCount
            TotalFileCacheSize = $totalFileSize
            CacheDirectory = $script:CacheDirectory
            CacheEnabled = $script:CacheEnabled
            MaxCacheAge = $script:MaxCacheAge
            MaxMemoryCacheSize = $script:MaxMemoryCacheSize
        }
    }
    catch {
        Write-LogError "Error getting cache statistics: $($_.Exception.Message)"
        return @{}
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-ConfigurationCache',
    'Get-CachedConfiguration',
    'Set-CachedConfiguration',
    'Remove-CachedConfiguration',
    'Clear-ExpiredCache',
    'Get-CacheStatistics'
)

# Initialize cache on module import
Initialize-ConfigurationCache | Out-Null
