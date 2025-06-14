# discovery_engine.ps1
# Intelligent Discovery Engine - Augment VIP Core Module
# Version: 2.0.0
# Function: Automatically discover all Augment-related data storage locations

param(
    [string]$ScanMode = "comprehensive",
    [switch]$IncludeRegistry = $true,
    [switch]$IncludeTemp = $true,
    [switch]$Verbose = $false
)

# 设置错误处理
$ErrorActionPreference = "Stop"
$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }

# 全局变量
$script:DiscoveryResults = @{
    Databases = @()
    ConfigFiles = @()
    CacheFiles = @()
    RegistryKeys = @()
    TempFiles = @()
    SessionFiles = @()
    ExtensionFiles = @()
    LogFiles = @()
    BackupFiles = @()
    Metadata = @{
        ScanStartTime = Get-Date
        ScanMode = $ScanMode
        TotalItemsFound = 0
        ScanDuration = 0
    }
}

# 日志函数
function Write-DiscoveryLog {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] [DISCOVERY] $Message"
    
    switch ($Level) {
        "INFO" { Write-Host $logMessage -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "DEBUG" { if ($Verbose) { Write-Host $logMessage -ForegroundColor Gray } }
    }
}

# 核心发现引擎类
class AugmentDiscoveryEngine {
    [hashtable]$ScanPatterns
    [hashtable]$LocationMappings
    [array]$KnownPaths
    [hashtable]$DataClassification
    
    AugmentDiscoveryEngine() {
        $this.InitializeScanPatterns()
        $this.InitializeLocationMappings()
        $this.InitializeKnownPaths()
        $this.InitializeDataClassification()
    }
    
    [void]InitializeScanPatterns() {
        $this.ScanPatterns = @{
            # Augment相关文件模式
            AugmentFiles = @(
                "*augment*",
                "*Augment*",
                "*AUGMENT*",
                "*.augment.*",
                "*augment-*",
                "*augment_*"
            )
            
            # 数据库文件模式
            DatabaseFiles = @(
                "*.vscdb",
                "*.db",
                "*.sqlite",
                "*.sqlite3",
                "state.vscdb",
                "storage.json"
            )
            
            # 配置文件模式
            ConfigFiles = @(
                "settings.json",
                "keybindings.json",
                "extensions.json",
                "*.config",
                "*.conf",
                "user.json",
                "workspace.json"
            )
            
            # 缓存文件模式
            CacheFiles = @(
                "*cache*",
                "*Cache*",
                "*.cache",
                "*temp*",
                "*tmp*",
                "*.log"
            )
            
            # 试用账号相关模式
            TrialPatterns = @(
                "*trial*",
                "*Trial*",
                "*context7*",
                "*Context7*",
                "*license*",
                "*License*",
                "*subscription*",
                "*Subscription*"
            )
            
            # 认证相关模式
            AuthPatterns = @(
                "*token*",
                "*Token*",
                "*auth*",
                "*Auth*",
                "*session*",
                "*Session*",
                "*credential*",
                "*Credential*"
            )
        }
    }
    
    [void]InitializeLocationMappings() {
        $this.LocationMappings = @{
            # VS Code 标准路径
            VSCodeStandard = @(
                "$env:APPDATA\Code",
                "$env:LOCALAPPDATA\Code",
                "$env:APPDATA\Code - Insiders",
                "$env:LOCALAPPDATA\Code - Insiders"
            )
            
            # Cursor 路径
            CursorPaths = @(
                "$env:APPDATA\Cursor",
                "$env:LOCALAPPDATA\Cursor",
                "$env:APPDATA\Cursor - Insiders",
                "$env:LOCALAPPDATA\Cursor - Insiders"
            )
            
            # 用户配置路径
            UserConfig = @(
                "$env:USERPROFILE\.vscode",
                "$env:USERPROFILE\.cursor",
                "$env:USERPROFILE\.config\Code",
                "$env:USERPROFILE\.config\Cursor"
            )
            
            # 系统临时路径
            TempPaths = @(
                "$env:TEMP",
                "$env:TMP",
                "$env:LOCALAPPDATA\Temp",
                "$env:USERPROFILE\AppData\Local\Temp"
            )
            
            # 注册表路径
            RegistryPaths = @(
                "HKCU:\Software\Microsoft\VSCode",
                "HKCU:\Software\Cursor",
                "HKCU:\Software\Classes\Applications\Code.exe",
                "HKCU:\Software\Classes\Applications\Cursor.exe",
                "HKLM:\Software\Microsoft\VSCode",
                "HKLM:\Software\Cursor"
            )
        }
    }
    
    [void]InitializeKnownPaths() {
        $this.KnownPaths = @(
            # VS Code 工作区存储
            "User\workspaceStorage",
            "User\globalStorage",
            "User\History",
            "User\snippets",
            "User\tasks.json",
            
            # 扩展相关
            "extensions",
            "logs\*\exthost*",
            "logs\*\renderer*",
            
            # 缓存和临时文件
            "CachedExtensions",
            "CachedExtensionVSIXs",
            "logs",
            "crashDumps"
        )
    }
    
    [void]InitializeDataClassification() {
        $this.DataClassification = @{
            Critical = @("databases", "user_settings", "authentication")
            Important = @("extensions", "workspace_config", "session_data")
            Optional = @("cache", "logs", "temp_files")
            Sensitive = @("tokens", "credentials", "trial_data", "license_info")
        }
    }
    
    # 主发现方法
    [hashtable]DiscoverAugmentData() {
        Write-DiscoveryLog "INFO" "开始智能发现引擎扫描 (模式: $($this.ScanPatterns.Count) 个模式)"
        
        try {
            # 阶段1: 发现VS Code/Cursor安装
            $this.DiscoverApplicationInstallations()
            
            # 阶段2: 扫描数据库文件
            $this.DiscoverDatabaseFiles()
            
            # 阶段3: 扫描配置文件
            $this.DiscoverConfigurationFiles()
            
            # 阶段4: 扫描缓存和临时文件
            $this.DiscoverCacheAndTempFiles()
            
            # 阶段5: 扫描注册表 (Windows)
            if ($IncludeRegistry) {
                $this.DiscoverRegistryEntries()
            }
            
            # 阶段6: 扫描扩展相关文件
            $this.DiscoverExtensionFiles()
            
            # 阶段7: 深度模式扫描
            if ($ScanMode -eq "comprehensive") {
                $this.PerformDeepScan()
            }
            
            # 完成扫描统计
            $this.FinalizeScanResults()
            
            Write-DiscoveryLog "SUCCESS" "智能发现完成，共发现 $($script:DiscoveryResults.Metadata.TotalItemsFound) 个项目"
            return $script:DiscoveryResults
            
        } catch {
            Write-DiscoveryLog "ERROR" "发现引擎执行失败: $($_.Exception.Message)"
            throw
        }
    }
    
    # 发现应用程序安装
    [void]DiscoverApplicationInstallations() {
        Write-DiscoveryLog "INFO" "正在发现VS Code/Cursor安装..."
        
        foreach ($pathGroup in $this.LocationMappings.Keys) {
            foreach ($path in $this.LocationMappings[$pathGroup]) {
                if (Test-Path $path) {
                    Write-DiscoveryLog "SUCCESS" "发现安装路径: $path"
                    $script:DiscoveryResults.Metadata.TotalItemsFound++
                }
            }
        }
    }
    
    # 发现数据库文件
    [void]DiscoverDatabaseFiles() {
        Write-DiscoveryLog "INFO" "正在扫描数据库文件..."
        
        foreach ($basePath in $this.LocationMappings.VSCodeStandard + $this.LocationMappings.CursorPaths) {
            if (Test-Path $basePath) {
                $this.ScanPathForDatabases($basePath)
            }
        }
    }
    
    # 扫描路径中的数据库
    [void]ScanPathForDatabases([string]$BasePath) {
        try {
            $searchPaths = @(
                "User\workspaceStorage\*\state.vscdb",
                "User\globalStorage\*\state.vscdb",
                "User\globalStorage\storage.json",
                "User\storage.json"
            )
            
            foreach ($searchPath in $searchPaths) {
                $fullPath = Join-Path $BasePath $searchPath
                $files = Get-ChildItem -Path $fullPath -ErrorAction SilentlyContinue
                
                foreach ($file in $files) {
                    if ($this.IsAugmentRelatedFile($file.FullName)) {
                        $script:DiscoveryResults.Databases += @{
                            Path = $file.FullName
                            Size = $file.Length
                            LastModified = $file.LastWriteTime
                            Type = "Database"
                            Priority = "Critical"
                        }
                        $script:DiscoveryResults.Metadata.TotalItemsFound++
                        Write-DiscoveryLog "SUCCESS" "发现数据库: $($file.FullName)"
                    }
                }
            }
        } catch {
            Write-DiscoveryLog "WARNING" "扫描数据库时出错: $($_.Exception.Message)"
        }
    }

    # 发现配置文件
    [void]DiscoverConfigurationFiles() {
        Write-DiscoveryLog "INFO" "正在扫描配置文件..."

        foreach ($basePath in $this.LocationMappings.VSCodeStandard + $this.LocationMappings.CursorPaths) {
            if (Test-Path $basePath) {
                $this.ScanPathForConfigs($basePath)
            }
        }
    }

    # 扫描配置文件
    [void]ScanPathForConfigs([string]$BasePath) {
        try {
            $configPaths = @(
                "User\settings.json",
                "User\keybindings.json",
                "User\tasks.json",
                "User\extensions.json",
                "User\globalStorage\*.json"
            )

            foreach ($configPath in $configPaths) {
                $fullPath = Join-Path $BasePath $configPath
                $files = Get-ChildItem -Path $fullPath -ErrorAction SilentlyContinue

                foreach ($file in $files) {
                    if ($this.ContainsAugmentData($file.FullName)) {
                        $script:DiscoveryResults.ConfigFiles += @{
                            Path = $file.FullName
                            Size = $file.Length
                            LastModified = $file.LastWriteTime
                            Type = "Configuration"
                            Priority = "Important"
                        }
                        $script:DiscoveryResults.Metadata.TotalItemsFound++
                        Write-DiscoveryLog "SUCCESS" "发现配置文件: $($file.FullName)"
                    }
                }
            }
        } catch {
            Write-DiscoveryLog "WARNING" "扫描配置文件时出错: $($_.Exception.Message)"
        }
    }

    # 发现缓存和临时文件
    [void]DiscoverCacheAndTempFiles() {
        Write-DiscoveryLog "INFO" "正在扫描缓存和临时文件..."

        # 扫描应用缓存
        foreach ($basePath in $this.LocationMappings.VSCodeStandard + $this.LocationMappings.CursorPaths) {
            if (Test-Path $basePath) {
                $this.ScanPathForCache($basePath)
            }
        }

        # 扫描系统临时目录
        if ($IncludeTemp) {
            foreach ($tempPath in $this.LocationMappings.TempPaths) {
                if (Test-Path $tempPath) {
                    $this.ScanTempDirectory($tempPath)
                }
            }
        }
    }

    # 扫描缓存目录
    [void]ScanPathForCache([string]$BasePath) {
        try {
            $cachePaths = @(
                "logs\*",
                "CachedExtensions\*",
                "CachedExtensionVSIXs\*",
                "crashDumps\*",
                "User\History\*"
            )

            foreach ($cachePath in $cachePaths) {
                $fullPath = Join-Path $BasePath $cachePath
                $items = Get-ChildItem -Path $fullPath -Recurse -ErrorAction SilentlyContinue

                foreach ($item in $items) {
                    if ($item.PSIsContainer -eq $false -and $this.IsAugmentRelatedFile($item.FullName)) {
                        $script:DiscoveryResults.CacheFiles += @{
                            Path = $item.FullName
                            Size = $item.Length
                            LastModified = $item.LastWriteTime
                            Type = "Cache"
                            Priority = "Optional"
                        }
                        $script:DiscoveryResults.Metadata.TotalItemsFound++
                    }
                }
            }
        } catch {
            Write-DiscoveryLog "WARNING" "扫描缓存时出错: $($_.Exception.Message)"
        }
    }

    # 扫描临时目录
    [void]ScanTempDirectory([string]$TempPath) {
        try {
            $augmentTempFiles = Get-ChildItem -Path $TempPath -Recurse -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.PSIsContainer -eq $false -and
                    $this.IsAugmentRelatedFile($_.FullName)
                }

            foreach ($file in $augmentTempFiles) {
                $script:DiscoveryResults.TempFiles += @{
                    Path = $file.FullName
                    Size = $file.Length
                    LastModified = $file.LastWriteTime
                    Type = "Temporary"
                    Priority = "Optional"
                }
                $script:DiscoveryResults.Metadata.TotalItemsFound++
            }
        } catch {
            Write-DiscoveryLog "WARNING" "扫描临时目录时出错: $($_.Exception.Message)"
        }
    }

    # 发现注册表条目
    [void]DiscoverRegistryEntries() {
        Write-DiscoveryLog "INFO" "正在扫描注册表条目..."

        foreach ($regPath in $this.LocationMappings.RegistryPaths) {
            try {
                if (Test-Path $regPath) {
                    $this.ScanRegistryPath($regPath)
                }
            } catch {
                Write-DiscoveryLog "DEBUG" "无法访问注册表路径: $regPath"
            }
        }
    }

    # 扫描注册表路径
    [void]ScanRegistryPath([string]$RegPath) {
        try {
            $regItems = Get-ChildItem -Path $regPath -Recurse -ErrorAction SilentlyContinue

            foreach ($item in $regItems) {
                $properties = Get-ItemProperty -Path $item.PSPath -ErrorAction SilentlyContinue

                foreach ($prop in $properties.PSObject.Properties) {
                    if ($this.ContainsAugmentPattern($prop.Value)) {
                        $script:DiscoveryResults.RegistryKeys += @{
                            Path = $item.PSPath
                            Property = $prop.Name
                            Value = $prop.Value
                            Type = "Registry"
                            Priority = "Important"
                        }
                        $script:DiscoveryResults.Metadata.TotalItemsFound++
                        Write-DiscoveryLog "SUCCESS" "发现注册表项: $($item.PSPath)\$($prop.Name)"
                    }
                }
            }
        } catch {
            Write-DiscoveryLog "WARNING" "扫描注册表时出错: $($_.Exception.Message)"
        }
    }

    # 发现扩展文件
    [void]DiscoverExtensionFiles() {
        Write-DiscoveryLog "INFO" "正在扫描扩展相关文件..."

        foreach ($basePath in $this.LocationMappings.VSCodeStandard + $this.LocationMappings.CursorPaths) {
            if (Test-Path $basePath) {
                $this.ScanExtensionDirectory($basePath)
            }
        }
    }

    # 扫描扩展目录
    [void]ScanExtensionDirectory([string]$BasePath) {
        try {
            $extensionPath = Join-Path $BasePath "extensions"
            if (Test-Path $extensionPath) {
                $augmentExtensions = Get-ChildItem -Path $extensionPath -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like "*augment*" -or $_.Name -like "*Augment*" }

                foreach ($ext in $augmentExtensions) {
                    $script:DiscoveryResults.ExtensionFiles += @{
                        Path = $ext.FullName
                        Name = $ext.Name
                        LastModified = $ext.LastWriteTime
                        Type = "Extension"
                        Priority = "Critical"
                    }
                    $script:DiscoveryResults.Metadata.TotalItemsFound++
                    Write-DiscoveryLog "SUCCESS" "发现Augment扩展: $($ext.FullName)"
                }
            }
        } catch {
            Write-DiscoveryLog "WARNING" "扫描扩展目录时出错: $($_.Exception.Message)"
        }
    }

    # 执行深度扫描
    [void]PerformDeepScan() {
        Write-DiscoveryLog "INFO" "正在执行深度扫描模式..."

        # 深度扫描用户目录
        $this.DeepScanUserDirectory()

        # 深度扫描程序数据目录
        $this.DeepScanProgramData()

        # 扫描网络缓存
        $this.ScanNetworkCache()
    }

    # 深度扫描用户目录
    [void]DeepScanUserDirectory() {
        try {
            $userProfile = $env:USERPROFILE
            $searchPaths = @(
                "$userProfile\.vscode*",
                "$userProfile\.cursor*",
                "$userProfile\Documents\*augment*",
                "$userProfile\Downloads\*augment*"
            )

            foreach ($searchPath in $searchPaths) {
                $items = Get-ChildItem -Path $searchPath -Recurse -ErrorAction SilentlyContinue
                foreach ($item in $items) {
                    if ($item.PSIsContainer -eq $false -and $this.IsAugmentRelatedFile($item.FullName)) {
                        $script:DiscoveryResults.ConfigFiles += @{
                            Path = $item.FullName
                            Size = $item.Length
                            LastModified = $item.LastWriteTime
                            Type = "UserData"
                            Priority = "Important"
                        }
                        $script:DiscoveryResults.Metadata.TotalItemsFound++
                    }
                }
            }
        } catch {
            Write-DiscoveryLog "WARNING" "深度扫描用户目录时出错: $($_.Exception.Message)"
        }
    }

    # 深度扫描程序数据目录
    [void]DeepScanProgramData() {
        try {
            $programData = $env:ProgramData
            $searchPaths = @(
                "$programData\*augment*",
                "$programData\Microsoft\VSCode\*augment*"
            )

            foreach ($searchPath in $searchPaths) {
                $items = Get-ChildItem -Path $searchPath -Recurse -ErrorAction SilentlyContinue
                foreach ($item in $items) {
                    if ($item.PSIsContainer -eq $false) {
                        $script:DiscoveryResults.ConfigFiles += @{
                            Path = $item.FullName
                            Size = $item.Length
                            LastModified = $item.LastWriteTime
                            Type = "SystemData"
                            Priority = "Important"
                        }
                        $script:DiscoveryResults.Metadata.TotalItemsFound++
                    }
                }
            }
        } catch {
            Write-DiscoveryLog "WARNING" "深度扫描程序数据目录时出错: $($_.Exception.Message)"
        }
    }

    # 扫描网络缓存
    [void]ScanNetworkCache() {
        try {
            $internetCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"
            if (Test-Path $internetCachePath) {
                $cacheFiles = Get-ChildItem -Path $internetCachePath -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like "*augment*" -or $_.Name -like "*context7*" }

                foreach ($file in $cacheFiles) {
                    $script:DiscoveryResults.CacheFiles += @{
                        Path = $file.FullName
                        Size = $file.Length
                        LastModified = $file.LastWriteTime
                        Type = "NetworkCache"
                        Priority = "Optional"
                    }
                    $script:DiscoveryResults.Metadata.TotalItemsFound++
                }
            }
        } catch {
            Write-DiscoveryLog "WARNING" "扫描网络缓存时出错: $($_.Exception.Message)"
        }
    }

    # 检查文件是否与Augment相关
    [bool]IsAugmentRelatedFile([string]$FilePath) {
        $fileName = [System.IO.Path]::GetFileName($FilePath).ToLower()
        $fileContent = ""

        # 检查文件名模式
        foreach ($pattern in $this.ScanPatterns.AugmentFiles) {
            if ($fileName -like $pattern.ToLower()) {
                return $true
            }
        }

        # 检查试用账号模式
        foreach ($pattern in $this.ScanPatterns.TrialPatterns) {
            if ($fileName -like $pattern.ToLower()) {
                return $true
            }
        }

        # 检查认证模式
        foreach ($pattern in $this.ScanPatterns.AuthPatterns) {
            if ($fileName -like $pattern.ToLower()) {
                return $true
            }
        }

        # 对于小文件，检查内容
        try {
            $fileInfo = Get-Item $FilePath -ErrorAction SilentlyContinue
            if ($fileInfo -and $fileInfo.Length -lt 1MB) {
                $fileContent = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
                if ($fileContent) {
                    return $this.ContainsAugmentData($FilePath, $fileContent)
                }
            }
        } catch {
            # 忽略文件读取错误
        }

        return $false
    }

    # 检查文件内容是否包含Augment数据
    [bool]ContainsAugmentData([string]$FilePath, [string]$Content = "") {
        if ([string]::IsNullOrEmpty($Content)) {
            try {
                $Content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
            } catch {
                return $false
            }
        }

        if ([string]::IsNullOrEmpty($Content)) {
            return $false
        }

        # 检查Augment相关关键词
        $augmentKeywords = @(
            "augment", "Augment", "AUGMENT",
            "context7", "Context7", "CONTEXT7",
            "trial", "Trial", "TRIAL",
            "augment-chat", "augment-panel", "augment-view",
            "augmentcode", "augment.code",
            "vscode-augment", "augment-extension"
        )

        foreach ($keyword in $augmentKeywords) {
            if ($Content -like "*$keyword*") {
                return $true
            }
        }

        return $false
    }

    # 检查是否包含Augment模式
    [bool]ContainsAugmentPattern([string]$Value) {
        if ([string]::IsNullOrEmpty($Value)) {
            return $false
        }

        $patterns = @(
            "augment", "Augment", "AUGMENT",
            "context7", "Context7",
            "trial", "Trial"
        )

        foreach ($pattern in $patterns) {
            if ($Value -like "*$pattern*") {
                return $true
            }
        }

        return $false
    }

    # 完成扫描统计
    [void]FinalizeScanResults() {
        $script:DiscoveryResults.Metadata.ScanDuration = (Get-Date) - $script:DiscoveryResults.Metadata.ScanStartTime

        Write-DiscoveryLog "INFO" "=== 发现引擎扫描结果 ==="
        Write-DiscoveryLog "INFO" "数据库文件: $($script:DiscoveryResults.Databases.Count)"
        Write-DiscoveryLog "INFO" "配置文件: $($script:DiscoveryResults.ConfigFiles.Count)"
        Write-DiscoveryLog "INFO" "缓存文件: $($script:DiscoveryResults.CacheFiles.Count)"
        Write-DiscoveryLog "INFO" "注册表项: $($script:DiscoveryResults.RegistryKeys.Count)"
        Write-DiscoveryLog "INFO" "临时文件: $($script:DiscoveryResults.TempFiles.Count)"
        Write-DiscoveryLog "INFO" "扩展文件: $($script:DiscoveryResults.ExtensionFiles.Count)"
        Write-DiscoveryLog "INFO" "扫描耗时: $($script:DiscoveryResults.Metadata.ScanDuration.TotalSeconds) 秒"
    }
}

# 主执行函数
function Start-AugmentDiscovery {
    param(
        [string]$Mode = "comprehensive",
        [switch]$IncludeRegistry = $true,
        [switch]$IncludeTemp = $true,
        [switch]$Verbose = $false
    )

    try {
        $engine = [AugmentDiscoveryEngine]::new()
        $results = $engine.DiscoverAugmentData()

        return $results
    } catch {
        Write-DiscoveryLog "ERROR" "智能发现引擎执行失败: $($_.Exception.Message)"
        throw
    }
}

# 导出函数
Export-ModuleMember -Function Start-AugmentDiscovery
