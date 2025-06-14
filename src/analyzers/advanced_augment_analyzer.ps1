# Advanced Augment Data Discovery Analyzer
# 超级全面的Augment数据发现分析器
# 确保找到所有可能的Augment相关数据

param(
    [string]$VSCodePath,
    [switch]$DeepScan = $false,
    [switch]$IncludeLogs = $false,
    [switch]$IncludeTemp = $false,
    [switch]$Verbose = $false
)

# 导入核心函数
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreDir = Join-Path (Split-Path -Parent $scriptDir) "core"
. (Join-Path $coreDir "logging.ps1")

# 超级全面的数据发现类
class AugmentDataDiscovery {
    [hashtable]$FoundData
    [array]$ScanPaths
    [array]$SearchPatterns
    [bool]$DeepScan
    [bool]$IncludeLogs
    [bool]$IncludeTemp

    AugmentDataDiscovery([bool]$deepScan, [bool]$includeLogs, [bool]$includeTemp) {
        $this.FoundData = @{
            DatabaseFiles = @()
            StorageFiles = @()
            ConfigFiles = @()
            LogFiles = @()
            CacheFiles = @()
            TempFiles = @()
            ExtensionFiles = @()
            WorkspaceFiles = @()
            SessionFiles = @()
            BackupFiles = @()
            TrialData = @()  # 专门用于试用账号相关数据
        }
        $this.DeepScan = $deepScan
        $this.IncludeLogs = $includeLogs
        $this.IncludeTemp = $includeTemp
        $this.InitializeScanPaths()
        $this.InitializeSearchPatterns()
    }

    [void]InitializeScanPaths() {
        # 基础扫描路径
        $this.ScanPaths = @(
            # 核心用户数据
            "User\workspaceStorage",
            "User\globalStorage", 
            "User\storage.json",
            "User\settings.json",
            "User\machineId",
            
            # 缓存数据
            "CachedData",
            "CachedExtensions",
            "CachedExtensionVSIXs",
            
            # 扩展数据
            "extensions",
            "User\extensions",
            
            # 会话和状态
            "User\sessions",
            "User\state",
            "User\History",
            
            # 工作区
            "User\workspaceStorage",
            "User\globalStorage\workspaces.json"
        )

        if ($this.IncludeLogs) {
            $this.ScanPaths += @(
                "logs",
                "User\logs"
            )
        }

        if ($this.IncludeTemp) {
            $this.ScanPaths += @(
                "$env:TEMP\vscode-*",
                "$env:TEMP\Code-*",
                "$env:TEMP\Augment-*"
            )
        }

        if ($this.DeepScan) {
            $this.ScanPaths += @(
                # 深度扫描路径
                "User\snippets",
                "User\keybindings.json",
                "User\tasks.json",
                "User\launch.json",
                "User\profiles",
                "User\sync",
                "User\backups",
                "crashDumps",
                "GPUCache"
            )
        }
    }

    [void]InitializeSearchPatterns() {
        # 超级全面的搜索模式
        $this.SearchPatterns = @(
            # Augment核心模式
            "*augment*",
            "*Augment*", 
            "*AUGMENT*",
            "augment.*",
            "Augment.*",
            
            # 扩展相关
            "*vscode-augment*",
            "*augment-chat*",
            "*augment-panel*",
            "*augment-view*",
            "*augment-extension*",
            "*augmentcode*",
            "*augment.code*",
            
            # VS Code集成
            "*memento*webviewView*augment*",
            "*workbench*view*extension*augment*",
            "*workbench*panel*augment*",
            "*extensionHost*augment*",
            
            # 遥测和跟踪
            "*telemetry*",
            "*machineId*",
            "*deviceId*", 
            "*sqmId*",
            "*sessionId*",
            "*installationId*",
            "*userId*",
            
            # Context7和试用 (专门针对试用账号过多问题)
            "*context7*",
            "*Context7*",
            "*CONTEXT7*",
            "*trial*",
            "*Trial*",
            "*TRIAL*",
            "*trialPrompt*",
            "*trial-prompt*",
            "*trialExpired*",
            "*trial-expired*",
            "*trialRemaining*",
            "*trial-remaining*",
            "*trialStatus*",
            "*trial-status*",
            "*trialLimit*",
            "*trial-limit*",
            "*trialCount*",
            "*trial-count*",
            "*license*",
            "*License*",
            "*LICENSE*",
            "*licenseCheck*",
            "*license-check*",
            "*licenseKey*",
            "*license-key*",
            "*subscription*",
            "*Subscription*",
            "*SUBSCRIPTION*",
            
            # AI服务
            "*aiService*",
            "*mlService*",
            "*copilot*",
            
            # 身份验证
            "*authToken*",
            "*accessToken*",
            "*refreshToken*"
        )
    }

    [hashtable]ScanVSCodePath([string]$basePath) {
        Write-LogInfo "Starting comprehensive scan: $basePath"
        
        foreach ($scanPath in $this.ScanPaths) {
            $fullPath = Join-Path $basePath $scanPath
            $this.ScanPath($fullPath, $scanPath)
        }

        return $this.FoundData
    }

    [void]ScanPath([string]$fullPath, [string]$relativePath) {
        try {
            if (-not (Test-Path $fullPath)) {
                return
            }

            Write-LogDebug "Scanning path: $fullPath"

            # 根据路径类型分类扫描
            if ($relativePath -like "*workspaceStorage*" -or $relativePath -like "*globalStorage*") {
                $this.ScanStorageArea($fullPath, $relativePath)
            } elseif ($relativePath -like "*logs*") {
                $this.ScanLogArea($fullPath)
            } elseif ($relativePath -like "*CachedData*" -or $relativePath -like "*Cache*") {
                $this.ScanCacheArea($fullPath)
            } elseif ($relativePath -like "*extensions*") {
                $this.ScanExtensionArea($fullPath)
            } else {
                $this.ScanGenericArea($fullPath, $relativePath)
            }
        } catch {
            Write-LogWarning "Failed to scan path $fullPath: $($_.Exception.Message)"
        }
    }

    [void]ScanStorageArea([string]$path, [string]$type) {
        # 扫描存储区域
        $files = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
        
        foreach ($file in $files) {
            $fileName = $file.Name.ToLower()
            $filePath = $file.FullName
            
            # 检查文件名模式
            foreach ($pattern in $this.SearchPatterns) {
                if ($fileName -like $pattern.ToLower()) {
                    $this.CategorizeFile($filePath, $file.Extension)
                    break
                }
            }
            
            # 检查文件内容（对于小文件）
            if ($file.Length -lt 10MB -and $file.Extension -in @('.json', '.txt', '.log', '.config')) {
                if ($this.CheckFileContent($filePath)) {
                    $this.CategorizeFile($filePath, $file.Extension)
                }

                # 专门检查试用相关数据
                if ($this.CheckTrialContent($filePath)) {
                    $this.FoundData.TrialData += $filePath
                }
            }

            # 检查数据库文件中的试用数据
            if ($file.Extension -eq '.vscdb' -or $file.Extension -eq '.db') {
                $this.CheckDatabaseTrialData($filePath)
            }
        }
    }

    [void]ScanLogArea([string]$path) {
        if (-not $this.IncludeLogs) { return }
        
        $logFiles = Get-ChildItem -Path $path -Recurse -Include "*.log" -ErrorAction SilentlyContinue
        foreach ($logFile in $logFiles) {
            if ($this.CheckFileContent($logFile.FullName)) {
                $this.FoundData.LogFiles += $logFile.FullName
            }
        }
    }

    [void]ScanCacheArea([string]$path) {
        $cacheFiles = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
        
        foreach ($file in $cacheFiles) {
            foreach ($pattern in $this.SearchPatterns) {
                if ($file.Name -like $pattern) {
                    $this.FoundData.CacheFiles += $file.FullName
                    break
                }
            }
        }
    }

    [void]ScanExtensionArea([string]$path) {
        $extensionFiles = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
        
        foreach ($file in $extensionFiles) {
            if ($file.Name -like "*augment*" -or $file.DirectoryName -like "*augment*") {
                $this.FoundData.ExtensionFiles += $file.FullName
            }
        }
    }

    [void]ScanGenericArea([string]$path, [string]$type) {
        $files = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
        
        foreach ($file in $files) {
            foreach ($pattern in $this.SearchPatterns) {
                if ($file.Name -like $pattern) {
                    $this.CategorizeFile($file.FullName, $file.Extension)
                    break
                }
            }
        }
    }

    [bool]CheckFileContent([string]$filePath) {
        try {
            $content = Get-Content $filePath -Raw -ErrorAction SilentlyContinue
            if (-not $content) { return $false }

            foreach ($pattern in $this.SearchPatterns) {
                $cleanPattern = $pattern -replace '\*', ''
                if ($content -like "*$cleanPattern*") {
                    return $true
                }
            }
            return $false
        } catch {
            return $false
        }
    }

    [bool]CheckTrialContent([string]$filePath) {
        try {
            $content = Get-Content $filePath -Raw -ErrorAction SilentlyContinue
            if (-not $content) { return $false }

            # 专门的试用相关模式检测
            $trialPatterns = @(
                "trial", "Trial", "TRIAL",
                "context7", "Context7", "CONTEXT7",
                "trialPrompt", "trial-prompt",
                "trialExpired", "trial-expired",
                "trialRemaining", "trial-remaining",
                "trialStatus", "trial-status",
                "trialLimit", "trial-limit",
                "trialCount", "trial-count",
                "licenseCheck", "license-check",
                "subscription", "Subscription"
            )

            foreach ($pattern in $trialPatterns) {
                if ($content -like "*$pattern*") {
                    Write-LogDebug "Found trial-related content in: $filePath (pattern: $pattern)"
                    return $true
                }
            }
            return $false
        } catch {
            return $false
        }
    }

    [void]CheckDatabaseTrialData([string]$dbPath) {
        try {
            # 检查数据库中的试用相关条目
            $trialQuery = @"
SELECT key, value FROM ItemTable WHERE
    LOWER(key) LIKE '%trial%' OR
    LOWER(key) LIKE '%context7%' OR
    key LIKE '%trialPrompt%' OR
    key LIKE '%trial-prompt%' OR
    key LIKE '%licenseCheck%' OR
    key LIKE '%license-check%' OR
    key LIKE '%trialExpired%' OR
    key LIKE '%trial-expired%' OR
    key LIKE '%trialRemaining%' OR
    key LIKE '%trial-remaining%' OR
    key LIKE '%trialStatus%' OR
    key LIKE '%trial-status%' OR
    key LIKE '%trialLimit%' OR
    key LIKE '%trial-limit%' OR
    key LIKE '%trialCount%' OR
    key LIKE '%trial-count%' OR
    key LIKE '%subscription%' OR
    key LIKE '%Subscription%';
"@

            $trialEntries = sqlite3 $dbPath $trialQuery 2>$null
            if ($LASTEXITCODE -eq 0 -and $trialEntries) {
                Write-LogInfo "Found trial data in database: $dbPath"
                $this.FoundData.TrialData += $dbPath

                # 记录具体的试用条目
                $trialEntries | ForEach-Object {
                    Write-LogDebug "Trial entry: $_"
                }
            }
        } catch {
            Write-LogWarning "Failed to check trial data in database: $dbPath - $($_.Exception.Message)"
        }
    }

    [void]CategorizeFile([string]$filePath, [string]$extension) {
        switch ($extension.ToLower()) {
            '.vscdb' { $this.FoundData.DatabaseFiles += $filePath }
            '.db' { $this.FoundData.DatabaseFiles += $filePath }
            '.sqlite' { $this.FoundData.DatabaseFiles += $filePath }
            '.sqlite3' { $this.FoundData.DatabaseFiles += $filePath }
            '.json' { $this.FoundData.StorageFiles += $filePath }
            '.log' { $this.FoundData.LogFiles += $filePath }
            '.config' { $this.FoundData.ConfigFiles += $filePath }
            '.backup' { $this.FoundData.BackupFiles += $filePath }
            default { 
                if ($filePath -like "*workspace*") {
                    $this.FoundData.WorkspaceFiles += $filePath
                } else {
                    $this.FoundData.StorageFiles += $filePath
                }
            }
        }
    }

    [hashtable]GenerateReport() {
        $totalFiles = 0
        foreach ($category in $this.FoundData.Keys) {
            $count = $this.FoundData[$category].Count
            $totalFiles += $count
            Write-LogInfo "$category: $count files"
        }

        # 专门报告试用数据
        $trialCount = $this.FoundData.TrialData.Count
        if ($trialCount -gt 0) {
            Write-LogWarning "TRIAL ACCOUNT ISSUE DETECTED: Found $trialCount files with trial-related data"
            Write-LogWarning "This may indicate trial account limit issues"
            Write-LogInfo "Trial data files:"
            foreach ($trialFile in $this.FoundData.TrialData) {
                Write-LogInfo "  - $trialFile"
            }
        } else {
            Write-LogSuccess "No trial-related data found"
        }

        Write-LogSuccess "Total discovered $totalFiles Augment-related files"

        return @{
            TotalFiles = $totalFiles
            Categories = $this.FoundData
            TrialDataCount = $trialCount
            HasTrialIssues = ($trialCount -gt 0)
            ScanCompleted = Get-Date
            TrialAnalysis = $this.GenerateTrialAnalysis()
        }
    }

    [hashtable]GenerateTrialAnalysis() {
        $analysis = @{
            TrialFilesFound = $this.FoundData.TrialData.Count
            DatabasesWithTrialData = 0
            ConfigFilesWithTrialData = 0
            LogFilesWithTrialData = 0
            TrialPatterns = @()
            Recommendations = @()
        }

        foreach ($trialFile in $this.FoundData.TrialData) {
            $extension = [System.IO.Path]::GetExtension($trialFile).ToLower()
            switch ($extension) {
                '.vscdb' { $analysis.DatabasesWithTrialData++ }
                '.db' { $analysis.DatabasesWithTrialData++ }
                '.json' { $analysis.ConfigFilesWithTrialData++ }
                '.config' { $analysis.ConfigFilesWithTrialData++ }
                '.log' { $analysis.LogFilesWithTrialData++ }
            }
        }

        # 生成建议
        if ($analysis.TrialFilesFound -gt 0) {
            $analysis.Recommendations += "Run cleanup operation to remove trial-related data"
            $analysis.Recommendations += "Use command: .\install.ps1 -Operation clean"

            if ($analysis.DatabasesWithTrialData -gt 0) {
                $analysis.Recommendations += "Focus on database cleanup - $($analysis.DatabasesWithTrialData) databases contain trial data"
            }

            if ($analysis.ConfigFilesWithTrialData -gt 0) {
                $analysis.Recommendations += "Check configuration files - $($analysis.ConfigFilesWithTrialData) config files contain trial data"
            }
        }

        return $analysis
    }
}

# 主执行函数
function Start-AdvancedAugmentAnalysis {
    param(
        [string]$VSCodePath,
        [bool]$DeepScan = $false,
        [bool]$IncludeLogs = $false,
        [bool]$IncludeTemp = $false
    )

    Write-LogInfo "启动高级Augment数据分析..."
    Write-LogInfo "扫描路径: $VSCodePath"
    Write-LogInfo "深度扫描: $DeepScan"
    Write-LogInfo "包含日志: $IncludeLogs" 
    Write-LogInfo "包含临时文件: $IncludeTemp"

    $analyzer = [AugmentDataDiscovery]::new($DeepScan, $IncludeLogs, $IncludeTemp)
    $results = $analyzer.ScanVSCodePath($VSCodePath)
    $report = $analyzer.GenerateReport()

    return $report
}

# 如果直接运行此脚本
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $VSCodePath) {
        Write-LogError "请提供VS Code路径参数"
        exit 1
    }

    $report = Start-AdvancedAugmentAnalysis -VSCodePath $VSCodePath -DeepScan $DeepScan -IncludeLogs $IncludeLogs -IncludeTemp $IncludeTemp
    
    Write-LogSuccess "=== 高级Augment数据分析完成 ==="
    Write-LogInfo "发现报告已生成"
    
    if ($Verbose) {
        $report | ConvertTo-Json -Depth 5 | Write-Host
    }
}
