# 数据完整性验证器
# 验证是否完整找到所有Augment相关数据

param(
    [hashtable]$DiscoveredData,
    [string]$VSCodePath,
    [switch]$Verbose = $false
)

# 导入核心函数
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreDir = Join-Path (Split-Path -Parent $scriptDir) "core"
. (Join-Path $coreDir "logging.ps1")

class DataIntegrityValidator {
    [hashtable]$ValidationResults
    [array]$ExpectedPatterns
    [array]$CriticalLocations

    DataIntegrityValidator() {
        $this.ValidationResults = @{
            DatabaseIntegrity = @{}
            StorageIntegrity = @{}
            ExtensionIntegrity = @{}
            TelemetryIntegrity = @{}
            OverallScore = 0
            MissingData = @()
            Recommendations = @()
        }
        $this.InitializeExpectedPatterns()
        $this.InitializeCriticalLocations()
    }

    [void]InitializeExpectedPatterns() {
        $this.ExpectedPatterns = @(
            # 数据库中应该存在的模式
            @{
                Type = "Database"
                Pattern = "augment"
                Critical = $true
                Description = "Augment核心数据库条目"
            },
            @{
                Type = "Database" 
                Pattern = "telemetry"
                Critical = $true
                Description = "遥测数据库条目"
            },
            @{
                Type = "Storage"
                Pattern = "machineId"
                Critical = $true
                Description = "机器ID存储"
            },
            @{
                Type = "Storage"
                Pattern = "deviceId"
                Critical = $true
                Description = "设备ID存储"
            },
            @{
                Type = "Extension"
                Pattern = "augment"
                Critical = $false
                Description = "Augment扩展文件"
            }
        )
    }

    [void]InitializeCriticalLocations() {
        $this.CriticalLocations = @(
            "User\workspaceStorage",
            "User\globalStorage", 
            "User\storage.json",
            "User\machineId",
            "CachedData"
        )
    }

    [hashtable]ValidateDataIntegrity([hashtable]$discoveredData, [string]$vscodePath) {
        Write-LogInfo "开始数据完整性验证..."

        # 验证数据库完整性
        $this.ValidateDatabaseIntegrity($discoveredData.DatabaseFiles)
        
        # 验证存储完整性
        $this.ValidateStorageIntegrity($discoveredData.StorageFiles)
        
        # 验证扩展完整性
        $this.ValidateExtensionIntegrity($discoveredData.ExtensionFiles)
        
        # 验证遥测完整性
        $this.ValidateTelemetryIntegrity($discoveredData)
        
        # 检查关键位置
        $this.ValidateCriticalLocations($vscodePath)
        
        # 计算总体评分
        $this.CalculateOverallScore()
        
        # 生成建议
        $this.GenerateRecommendations()

        return $this.ValidationResults
    }

    [void]ValidateDatabaseIntegrity([array]$databaseFiles) {
        Write-LogInfo "验证数据库完整性..."
        
        $dbIntegrity = @{
            TotalFiles = $databaseFiles.Count
            ValidFiles = 0
            CorruptFiles = 0
            AugmentEntries = 0
            TelemetryEntries = 0
            Details = @()
        }

        foreach ($dbFile in $databaseFiles) {
            try {
                # 检查文件是否可访问
                if (-not (Test-Path $dbFile)) {
                    $dbIntegrity.Details += @{
                        File = $dbFile
                        Status = "Missing"
                        Error = "文件不存在"
                    }
                    continue
                }

                # 验证SQLite数据库
                $tables = sqlite3 $dbFile ".tables" 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $dbIntegrity.ValidFiles++
                    
                    # 检查Augment条目
                    $augmentCount = sqlite3 $dbFile "SELECT COUNT(*) FROM ItemTable WHERE LOWER(key) LIKE '%augment%';" 2>$null
                    if ($LASTEXITCODE -eq 0 -and $augmentCount) {
                        $dbIntegrity.AugmentEntries += [int]$augmentCount
                    }
                    
                    # 检查遥测条目
                    $telemetryCount = sqlite3 $dbFile "SELECT COUNT(*) FROM ItemTable WHERE LOWER(key) LIKE '%telemetry%' OR key LIKE '%machineId%' OR key LIKE '%deviceId%';" 2>$null
                    if ($LASTEXITCODE -eq 0 -and $telemetryCount) {
                        $dbIntegrity.TelemetryEntries += [int]$telemetryCount
                    }

                    $dbIntegrity.Details += @{
                        File = $dbFile
                        Status = "Valid"
                        AugmentEntries = [int]$augmentCount
                        TelemetryEntries = [int]$telemetryCount
                    }
                } else {
                    $dbIntegrity.CorruptFiles++
                    $dbIntegrity.Details += @{
                        File = $dbFile
                        Status = "Corrupt"
                        Error = "无法读取SQLite数据库"
                    }
                }
            } catch {
                $dbIntegrity.CorruptFiles++
                $dbIntegrity.Details += @{
                    File = $dbFile
                    Status = "Error"
                    Error = $_.Exception.Message
                }
            }
        }

        $this.ValidationResults.DatabaseIntegrity = $dbIntegrity
        Write-LogInfo "数据库验证完成: $($dbIntegrity.ValidFiles)/$($dbIntegrity.TotalFiles) 有效"
    }

    [void]ValidateStorageIntegrity([array]$storageFiles) {
        Write-LogInfo "验证存储文件完整性..."
        
        $storageIntegrity = @{
            TotalFiles = $storageFiles.Count
            ValidFiles = 0
            JsonFiles = 0
            ConfigFiles = 0
            IdentifierFiles = 0
            Details = @()
        }

        foreach ($storageFile in $storageFiles) {
            try {
                if (-not (Test-Path $storageFile)) {
                    continue
                }

                $fileInfo = Get-Item $storageFile
                $extension = $fileInfo.Extension.ToLower()
                
                if ($extension -eq '.json') {
                    # 验证JSON文件
                    try {
                        $content = Get-Content $storageFile -Raw | ConvertFrom-Json
                        $storageIntegrity.JsonFiles++
                        $storageIntegrity.ValidFiles++
                        
                        # 检查标识符
                        $identifiers = @()
                        $identifierPatterns = @('machineId', 'deviceId', 'sqmId', 'sessionId', 'installationId', 'userId')
                        foreach ($pattern in $identifierPatterns) {
                            if ($content.PSObject.Properties.Name -contains $pattern) {
                                $identifiers += $pattern
                            }
                        }
                        
                        if ($identifiers.Count -gt 0) {
                            $storageIntegrity.IdentifierFiles++
                        }

                        $storageIntegrity.Details += @{
                            File = $storageFile
                            Status = "Valid"
                            Type = "JSON"
                            Identifiers = $identifiers
                        }
                    } catch {
                        $storageIntegrity.Details += @{
                            File = $storageFile
                            Status = "Invalid JSON"
                            Error = $_.Exception.Message
                        }
                    }
                } else {
                    # 其他配置文件
                    $storageIntegrity.ConfigFiles++
                    $storageIntegrity.ValidFiles++
                    
                    $storageIntegrity.Details += @{
                        File = $storageFile
                        Status = "Valid"
                        Type = "Config"
                    }
                }
            } catch {
                $storageIntegrity.Details += @{
                    File = $storageFile
                    Status = "Error"
                    Error = $_.Exception.Message
                }
            }
        }

        $this.ValidationResults.StorageIntegrity = $storageIntegrity
        Write-LogInfo "存储验证完成: $($storageIntegrity.ValidFiles)/$($storageIntegrity.TotalFiles) 有效"
    }

    [void]ValidateExtensionIntegrity([array]$extensionFiles) {
        Write-LogInfo "验证扩展文件完整性..."
        
        $extensionIntegrity = @{
            TotalFiles = $extensionFiles.Count
            AugmentExtensions = 0
            ManifestFiles = 0
            Details = @()
        }

        foreach ($extensionFile in $extensionFiles) {
            try {
                if (-not (Test-Path $extensionFile)) {
                    continue
                }

                $fileName = [System.IO.Path]::GetFileName($extensionFile)
                
                if ($fileName -eq "package.json") {
                    # 检查扩展清单
                    try {
                        $manifest = Get-Content $extensionFile -Raw | ConvertFrom-Json
                        if ($manifest.name -like "*augment*" -or $manifest.displayName -like "*augment*") {
                            $extensionIntegrity.AugmentExtensions++
                        }
                        $extensionIntegrity.ManifestFiles++
                        
                        $extensionIntegrity.Details += @{
                            File = $extensionFile
                            Status = "Valid"
                            Type = "Manifest"
                            Name = $manifest.name
                            Version = $manifest.version
                        }
                    } catch {
                        $extensionIntegrity.Details += @{
                            File = $extensionFile
                            Status = "Invalid Manifest"
                            Error = $_.Exception.Message
                        }
                    }
                } else {
                    $extensionIntegrity.Details += @{
                        File = $extensionFile
                        Status = "Valid"
                        Type = "Extension File"
                    }
                }
            } catch {
                $extensionIntegrity.Details += @{
                    File = $extensionFile
                    Status = "Error"
                    Error = $_.Exception.Message
                }
            }
        }

        $this.ValidationResults.ExtensionIntegrity = $extensionIntegrity
        Write-LogInfo "扩展验证完成: $($extensionIntegrity.AugmentExtensions) 个Augment扩展"
    }

    [void]ValidateTelemetryIntegrity([hashtable]$discoveredData) {
        Write-LogInfo "验证遥测数据完整性..."
        
        $telemetryIntegrity = @{
            DatabaseEntries = $this.ValidationResults.DatabaseIntegrity.TelemetryEntries
            StorageIdentifiers = $this.ValidationResults.StorageIntegrity.IdentifierFiles
            CompletionScore = 0
        }

        # 计算遥测完整性评分
        $maxScore = 100
        $dbScore = [Math]::Min(50, $telemetryIntegrity.DatabaseEntries * 5)
        $storageScore = [Math]::Min(50, $telemetryIntegrity.StorageIdentifiers * 10)
        
        $telemetryIntegrity.CompletionScore = $dbScore + $storageScore

        $this.ValidationResults.TelemetryIntegrity = $telemetryIntegrity
        Write-LogInfo "遥测验证完成: $($telemetryIntegrity.CompletionScore)% 完整性"
    }

    [void]ValidateCriticalLocations([string]$vscodePath) {
        Write-LogInfo "验证关键位置..."
        
        $missingLocations = @()
        foreach ($location in $this.CriticalLocations) {
            $fullPath = Join-Path $vscodePath $location
            if (-not (Test-Path $fullPath)) {
                $missingLocations += $location
            }
        }

        if ($missingLocations.Count -gt 0) {
            $this.ValidationResults.MissingData += "关键位置缺失: $($missingLocations -join ', ')"
        }
    }

    [void]CalculateOverallScore() {
        $dbScore = if ($this.ValidationResults.DatabaseIntegrity.TotalFiles -gt 0) {
            ($this.ValidationResults.DatabaseIntegrity.ValidFiles / $this.ValidationResults.DatabaseIntegrity.TotalFiles) * 40
        } else { 0 }

        $storageScore = if ($this.ValidationResults.StorageIntegrity.TotalFiles -gt 0) {
            ($this.ValidationResults.StorageIntegrity.ValidFiles / $this.ValidationResults.StorageIntegrity.TotalFiles) * 30
        } else { 0 }

        $telemetryScore = $this.ValidationResults.TelemetryIntegrity.CompletionScore * 0.3

        $this.ValidationResults.OverallScore = [Math]::Round($dbScore + $storageScore + $telemetryScore, 2)
    }

    [void]GenerateRecommendations() {
        $recommendations = @()

        if ($this.ValidationResults.DatabaseIntegrity.CorruptFiles -gt 0) {
            $recommendations += "发现 $($this.ValidationResults.DatabaseIntegrity.CorruptFiles) 个损坏的数据库文件，建议修复或重新创建"
        }

        if ($this.ValidationResults.TelemetryIntegrity.CompletionScore -lt 50) {
            $recommendations += "遥测数据完整性较低，可能存在遗漏的标识符文件"
        }

        if ($this.ValidationResults.OverallScore -lt 80) {
            $recommendations += "总体数据完整性评分较低，建议进行深度扫描"
        }

        if ($this.ValidationResults.ExtensionIntegrity.AugmentExtensions -eq 0) {
            $recommendations += "未发现Augment扩展文件，可能已被完全清理或未安装"
        }

        $this.ValidationResults.Recommendations = $recommendations
    }
}

# 主验证函数
function Start-DataIntegrityValidation {
    param(
        [hashtable]$DiscoveredData,
        [string]$VSCodePath
    )

    Write-LogInfo "启动数据完整性验证..."
    
    $validator = [DataIntegrityValidator]::new()
    $results = $validator.ValidateDataIntegrity($DiscoveredData, $VSCodePath)
    
    Write-LogSuccess "数据完整性验证完成"
    Write-LogInfo "总体评分: $($results.OverallScore)%"
    
    if ($results.Recommendations.Count -gt 0) {
        Write-LogWarning "建议:"
        foreach ($recommendation in $results.Recommendations) {
            Write-LogWarning "  - $recommendation"
        }
    }

    return $results
}

# 如果直接运行此脚本
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $DiscoveredData -or -not $VSCodePath) {
        Write-LogError "请提供发现的数据和VS Code路径参数"
        exit 1
    }

    $results = Start-DataIntegrityValidation -DiscoveredData $DiscoveredData -VSCodePath $VSCodePath
    
    if ($Verbose) {
        $results | ConvertTo-Json -Depth 5 | Write-Host
    }
}
