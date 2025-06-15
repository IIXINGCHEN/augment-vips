# cleanup_strategy_engine.ps1
# 清理策略引擎 - Augment VIP 全面重构清理引擎核心模块
# 版本: 2.0.0
# 功能: 根据发现的数据类型选择最佳清理策略，实现智能化清理决策

param(
    [string]$StrategyMode = "adaptive",
    [string]$RiskTolerance = "medium",
    [switch]$EnableParallel = $true,
    [switch]$Verbose = $false
)

# 设置错误处理
$ErrorActionPreference = "Stop"
$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }

# 导入公共工具函数
$commonUtilitiesPath = Join-Path (Split-Path $PSScriptRoot -Parent) "core\common_utilities.ps1"
if (Test-Path $commonUtilitiesPath) {
    . $commonUtilitiesPath
}

# 加载清理模式配置
$script:CleanupModesConfig = $null
try {
    $configPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config\cleanup_modes.json"
    if (Test-Path $configPath) {
        $script:CleanupModesConfig = Get-Content $configPath -Raw | ConvertFrom-Json
        Write-Verbose "已加载清理模式配置: $configPath"
    }
} catch {
    Write-Warning "无法加载清理模式配置: $($_.Exception.Message)"
}

# 全局策略配置（保持向后兼容）
$script:StrategyConfig = @{
    Modes = @{
        Minimal = @{
            Description = "最小清理模式 - 只清理最基本的试用数据"
            RiskLevel = "very_low"
            BackupRequired = $true
            ConfirmationRequired = $true
        }
        Conservative = @{
            Description = "保守模式 - 只清理明确安全的数据"
            RiskLevel = "low"
            BackupRequired = $true
            ConfirmationRequired = $true
        }
        Standard = @{
            Description = "标准模式 - 平衡清理效果和安全性"
            RiskLevel = "medium"
            BackupRequired = $true
            ConfirmationRequired = $false
        }
        Aggressive = @{
            Description = "激进模式 - 最大化清理效果"
            RiskLevel = "high"
            BackupRequired = $true
            ConfirmationRequired = $true
        }
        Adaptive = @{
            Description = "自适应模式 - 根据数据类型动态调整策略"
            RiskLevel = "variable"
            BackupRequired = $true
            ConfirmationRequired = $false
        }
        Forensic = @{
            Description = "取证模式 - 彻底清除所有痕迹"
            RiskLevel = "very_high"
            BackupRequired = $true
            ConfirmationRequired = $true
        }
        Custom = @{
            Description = "自定义模式 - 用户自定义清理策略"
            RiskLevel = "user_defined"
            BackupRequired = $true
            ConfirmationRequired = $true
        }
    }
    
    Operations = @{
        DatabaseClean = @{
            Priority = 1
            RequiresBackup = $true
            ParallelSafe = $false
            EstimatedTime = 30
        }
        ConfigClean = @{
            Priority = 2
            RequiresBackup = $true
            ParallelSafe = $true
            EstimatedTime = 15
        }
        CacheClean = @{
            Priority = 3
            RequiresBackup = $false
            ParallelSafe = $true
            EstimatedTime = 10
        }
        RegistryClean = @{
            Priority = 4
            RequiresBackup = $true
            ParallelSafe = $false
            EstimatedTime = 20
        }
        ExtensionClean = @{
            Priority = 5
            RequiresBackup = $true
            ParallelSafe = $true
            EstimatedTime = 25
        }
    }
}

# 日志函数
function Write-StrategyLog {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] [STRATEGY] $Message"
    
    switch ($Level) {
        "INFO" { Write-Host $logMessage -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "DEBUG" { if ($Verbose) { Write-Host $logMessage -ForegroundColor Gray } }
    }
}

# 清理策略引擎类
class CleanupStrategyEngine {
    [hashtable]$DiscoveredData
    [string]$SelectedMode
    [hashtable]$CleanupPlan
    [hashtable]$RiskAssessment
    [array]$OperationQueue
    
    CleanupStrategyEngine([hashtable]$DiscoveredData, [string]$Mode) {
        $this.DiscoveredData = $DiscoveredData
        $this.SelectedMode = $Mode
        $this.CleanupPlan = @{}
        $this.RiskAssessment = @{}
        $this.OperationQueue = @()
        
        $this.InitializeStrategy()
    }
    
    [void]InitializeStrategy() {
        Write-StrategyLog "INFO" "初始化清理策略引擎 (模式: $($this.SelectedMode))"
        
        # 验证模式
        if (-not $script:StrategyConfig.Modes.ContainsKey($this.SelectedMode)) {
            Write-StrategyLog "WARNING" "未知策略模式: $($this.SelectedMode)，使用自适应模式"
            $this.SelectedMode = "Adaptive"
        }
        
        Write-StrategyLog "INFO" "策略模式: $($script:StrategyConfig.Modes[$this.SelectedMode].Description)"
    }
    
    # 生成清理计划
    [hashtable]GenerateCleanupPlan() {
        Write-StrategyLog "INFO" "开始生成清理计划..."
        
        try {
            # 阶段1: 风险评估
            $this.PerformRiskAssessment()
            
            # 阶段2: 策略选择
            $this.SelectCleanupStrategies()
            
            # 阶段3: 操作排序
            $this.PrioritizeOperations()
            
            # 阶段4: 生成执行计划
            $this.BuildExecutionPlan()
            
            # 阶段5: 验证计划
            $this.ValidateCleanupPlan()
            
            Write-StrategyLog "SUCCESS" "清理计划生成完成，包含 $($this.OperationQueue.Count) 个操作"
            return $this.CleanupPlan
            
        } catch {
            Write-StrategyLog "ERROR" "生成清理计划失败: $($_.Exception.Message)"
            throw
        }
    }
    
    # 执行风险评估
    [void]PerformRiskAssessment() {
        Write-StrategyLog "INFO" "正在执行风险评估..."
        
        $this.RiskAssessment = @{
            OverallRisk = "low"
            DataTypes = @{}
            CriticalItems = @()
            Warnings = @()
            Recommendations = @()
        }
        
        # 评估数据库风险
        $this.AssessDatabaseRisk()
        
        # 评估配置文件风险
        $this.AssessConfigRisk()
        
        # 评估注册表风险
        $this.AssessRegistryRisk()
        
        # 评估扩展风险
        $this.AssessExtensionRisk()
        
        # 计算总体风险
        $this.CalculateOverallRisk()
    }
    
    # 评估数据库风险
    [void]AssessDatabaseRisk() {
        $dbCount = $this.DiscoveredData.Databases.Count
        $dbRisk = "low"
        
        if ($dbCount -gt 10) {
            $dbRisk = "medium"
            $this.RiskAssessment.Warnings += "发现大量数据库文件 ($dbCount 个)，清理可能需要较长时间"
        }
        
        if ($dbCount -gt 50) {
            $dbRisk = "high"
            $this.RiskAssessment.Warnings += "数据库文件数量异常 ($dbCount 个)，建议分批处理"
        }
        
        $this.RiskAssessment.DataTypes["Databases"] = @{
            Count = $dbCount
            Risk = $dbRisk
            EstimatedTime = $dbCount * 2  # 每个数据库预计2秒
        }
        
        Write-StrategyLog "DEBUG" "数据库风险评估: $dbRisk (数量: $dbCount)"
    }
    
    # 评估配置文件风险
    [void]AssessConfigRisk() {
        $configCount = $this.DiscoveredData.ConfigFiles.Count
        $configRisk = "low"
        
        # 检查关键配置文件
        $criticalConfigs = $this.DiscoveredData.ConfigFiles | Where-Object { 
            $_.Path -like "*settings.json" -or $_.Path -like "*keybindings.json" 
        }
        
        if ($criticalConfigs.Count -gt 0) {
            $configRisk = "medium"
            $this.RiskAssessment.CriticalItems += $criticalConfigs
            $this.RiskAssessment.Warnings += "发现关键配置文件，将创建备份"
        }
        
        $this.RiskAssessment.DataTypes["ConfigFiles"] = @{
            Count = $configCount
            Risk = $configRisk
            CriticalCount = $criticalConfigs.Count
            EstimatedTime = $configCount * 1
        }
        
        Write-StrategyLog "DEBUG" "配置文件风险评估: $configRisk (数量: $configCount, 关键: $($criticalConfigs.Count))"
    }
    
    # 评估注册表风险
    [void]AssessRegistryRisk() {
        $regCount = $this.DiscoveredData.RegistryKeys.Count
        $regRisk = if ($regCount -gt 0) { "medium" } else { "none" }
        
        if ($regCount -gt 0) {
            $this.RiskAssessment.Warnings += "发现注册表项 ($regCount 个)，需要管理员权限"
            $this.RiskAssessment.Recommendations += "建议以管理员身份运行以清理注册表项"
        }
        
        $this.RiskAssessment.DataTypes["RegistryKeys"] = @{
            Count = $regCount
            Risk = $regRisk
            EstimatedTime = $regCount * 3
        }
        
        Write-StrategyLog "DEBUG" "注册表风险评估: $regRisk (数量: $regCount)"
    }
    
    # 评估扩展风险
    [void]AssessExtensionRisk() {
        $extCount = $this.DiscoveredData.ExtensionFiles.Count
        $extRisk = if ($extCount -gt 0) { "high" } else { "none" }
        
        if ($extCount -gt 0) {
            $this.RiskAssessment.CriticalItems += $this.DiscoveredData.ExtensionFiles
            $this.RiskAssessment.Warnings += "发现Augment扩展 ($extCount 个)，将完全移除"
            $this.RiskAssessment.Recommendations += "清理后需要重新安装所需的扩展"
        }
        
        $this.RiskAssessment.DataTypes["ExtensionFiles"] = @{
            Count = $extCount
            Risk = $extRisk
            EstimatedTime = $extCount * 5
        }
        
        Write-StrategyLog "DEBUG" "扩展风险评估: $extRisk (数量: $extCount)"
    }
    
    # 计算总体风险
    [void]CalculateOverallRisk() {
        $riskLevels = $this.RiskAssessment.DataTypes.Values | ForEach-Object { $_.Risk }
        
        if ($riskLevels -contains "high") {
            $this.RiskAssessment.OverallRisk = "high"
        } elseif ($riskLevels -contains "medium") {
            $this.RiskAssessment.OverallRisk = "medium"
        } else {
            $this.RiskAssessment.OverallRisk = "low"
        }
        
        # 计算总预计时间
        $totalTime = ($this.RiskAssessment.DataTypes.Values | ForEach-Object { $_.EstimatedTime } | Measure-Object -Sum).Sum
        $this.RiskAssessment.EstimatedTotalTime = $totalTime
        
        Write-StrategyLog "INFO" "总体风险评估: $($this.RiskAssessment.OverallRisk), 预计耗时: $totalTime 秒"
    }

    # 选择清理策略
    [void]SelectCleanupStrategies() {
        Write-StrategyLog "INFO" "正在选择清理策略..."

        # 首先尝试从配置文件加载策略
        if ($script:CleanupModesConfig -and $this.ApplyConfigBasedStrategy()) {
            Write-StrategyLog "INFO" "使用配置文件中的清理策略: $($this.SelectedMode)"
            return
        }

        # 回退到内置策略
        switch ($this.SelectedMode) {
            "Minimal" { $this.ApplyMinimalStrategy() }
            "Conservative" { $this.ApplyConservativeStrategy() }
            "Standard" { $this.ApplyStandardStrategy() }
            "Aggressive" { $this.ApplyAggressiveStrategy() }
            "Adaptive" { $this.ApplyAdaptiveStrategy() }
            "Forensic" { $this.ApplyForensicStrategy() }
            "Custom" { $this.ApplyCustomStrategy() }
            default { $this.ApplyStandardStrategy() }
        }
    }

    # 应用基于配置文件的策略
    [bool]ApplyConfigBasedStrategy() {
        try {
            $modeConfig = $script:CleanupModesConfig.cleanup_modes.($this.SelectedMode.ToLower())
            if (-not $modeConfig) {
                Write-StrategyLog "WARNING" "配置文件中未找到模式: $($this.SelectedMode)"
                return $false
            }

            Write-StrategyLog "INFO" "应用配置策略: $($modeConfig.name)"

            # 创建进度跟踪器
            $enabledOps = ($modeConfig.operations.PSObject.Properties | Where-Object { $_.Value.enabled -eq $true }).Count
            $progressTracker = New-ProgressTracker $enabledOps "应用清理策略"

            foreach ($operation in $modeConfig.operations.PSObject.Properties) {
                $opName = $operation.Name
                $opConfig = $operation.Value

                if ($opConfig.enabled) {
                    Update-ProgressTracker $progressTracker "配置操作: $opName"

                    $this.AddOperation($this.MapOperationName($opName), $opConfig.strategy, @{
                        TargetPatterns = $opConfig.patterns
                        BackupRequired = $opConfig.backup_before -eq $true
                        ConfirmEach = $opConfig.confirmation_required -eq $true
                        AdminRequired = $opConfig.admin_required -eq $true
                        DeepScan = $opConfig.deep_scan -eq $true
                        VacuumAfter = $opConfig.vacuum_after -eq $true
                    })
                }
            }

            Write-Progress -Activity "应用清理策略" -Completed
            return $true
        } catch {
            Write-StrategyLog "ERROR" "应用配置策略失败: $($_.Exception.Message)"
            return $false
        }
    }

    # 映射操作名称
    [string]MapOperationName([string]$ConfigName) {
        $mapping = @{
            'database_clean' = 'DatabaseClean'
            'config_clean' = 'ConfigClean'
            'cache_clean' = 'CacheClean'
            'registry_clean' = 'RegistryClean'
            'extension_clean' = 'ExtensionClean'
            'identity_reset' = 'IdentityReset'
            'network_cache_clean' = 'NetworkCacheClean'
            'log_clean' = 'LogClean'
        }

        return $mapping[$ConfigName] ?? $ConfigName
    }

    # 应用最小策略
    [void]ApplyMinimalStrategy() {
        Write-StrategyLog "INFO" "应用最小清理策略"

        # 只清理最基本的试用数据
        $this.AddOperation("DatabaseClean", "trial_only", @{
            TargetPatterns = @("*trial*", "*Trial*", "*TRIAL*")
            BackupRequired = $true
            ConfirmEach = $true
        })

        $this.AddOperation("CacheClean", "safe", @{
            TargetPatterns = @("*trial*cache*", "*temp*trial*")
            BackupRequired = $false
            ConfirmEach = $false
        })
    }

    # 应用保守策略
    [void]ApplyConservativeStrategy() {
        Write-StrategyLog "INFO" "应用保守清理策略"

        # 只清理明确安全的项目
        $this.AddOperation("DatabaseClean", "selective", @{
            TargetPatterns = @("*trial*", "*context7*")
            BackupRequired = $true
            ConfirmEach = $true
        })

        $this.AddOperation("CacheClean", "safe", @{
            TargetPatterns = @("*augment*cache*", "*temp*augment*")
            BackupRequired = $false
            ConfirmEach = $false
        })
    }

    # 应用标准策略
    [void]ApplyStandardStrategy() {
        Write-StrategyLog "INFO" "应用标准清理策略"

        # 平衡的清理方案
        $this.AddOperation("DatabaseClean", "comprehensive", @{
            TargetPatterns = @("*augment*", "*trial*", "*context7*", "*telemetry*")
            BackupRequired = $true
            ConfirmEach = $false
        })

        $this.AddOperation("ConfigClean", "selective", @{
            TargetPatterns = @("*augment*")
            BackupRequired = $true
            ConfirmEach = $false
        })

        $this.AddOperation("CacheClean", "full", @{
            TargetPatterns = @("*augment*", "*cache*")
            BackupRequired = $false
            ConfirmEach = $false
        })

        if ($this.DiscoveredData.ExtensionFiles.Count -gt 0) {
            $this.AddOperation("ExtensionClean", "remove", @{
                TargetPatterns = @("*augment*")
                BackupRequired = $true
                ConfirmEach = $true
            })
        }
    }

    # 应用激进策略
    [void]ApplyAggressiveStrategy() {
        Write-StrategyLog "INFO" "应用激进清理策略"

        # 最大化清理效果
        $this.AddOperation("DatabaseClean", "deep", @{
            TargetPatterns = @("*augment*", "*trial*", "*context7*", "*telemetry*", "*machineId*", "*deviceId*")
            BackupRequired = $true
            ConfirmEach = $false
        })

        $this.AddOperation("ConfigClean", "comprehensive", @{
            TargetPatterns = @("*augment*", "*trial*", "*context7*")
            BackupRequired = $true
            ConfirmEach = $false
        })

        $this.AddOperation("CacheClean", "deep", @{
            TargetPatterns = @("*augment*", "*cache*", "*temp*", "*log*")
            BackupRequired = $false
            ConfirmEach = $false
        })

        if ($this.DiscoveredData.RegistryKeys.Count -gt 0) {
            $this.AddOperation("RegistryClean", "full", @{
                TargetPatterns = @("*augment*", "*context7*")
                BackupRequired = $true
                ConfirmEach = $true
            })
        }

        if ($this.DiscoveredData.ExtensionFiles.Count -gt 0) {
            $this.AddOperation("ExtensionClean", "purge", @{
                TargetPatterns = @("*augment*")
                BackupRequired = $true
                ConfirmEach = $false
            })
        }
    }

    # 应用自适应策略
    [void]ApplyAdaptiveStrategy() {
        Write-StrategyLog "INFO" "应用自适应清理策略"

        # 根据风险评估动态调整
        $overallRisk = $this.RiskAssessment.OverallRisk

        # 数据库清理 - 始终执行
        $dbStrategy = if ($overallRisk -eq "high") { "selective" } else { "comprehensive" }
        $this.AddOperation("DatabaseClean", $dbStrategy, @{
            TargetPatterns = @("*augment*", "*trial*", "*context7*", "*telemetry*")
            BackupRequired = $true
            ConfirmEach = ($overallRisk -eq "high")
        })

        # 配置文件清理 - 根据关键文件数量决定
        $criticalConfigs = $this.RiskAssessment.DataTypes["ConfigFiles"].CriticalCount
        if ($criticalConfigs -gt 0) {
            $configStrategy = if ($criticalConfigs -gt 5) { "selective" } else { "standard" }
            $this.AddOperation("ConfigClean", $configStrategy, @{
                TargetPatterns = @("*augment*")
                BackupRequired = $true
                ConfirmEach = ($criticalConfigs -gt 5)
            })
        }

        # 缓存清理 - 总是安全执行
        $this.AddOperation("CacheClean", "full", @{
            TargetPatterns = @("*augment*", "*cache*")
            BackupRequired = $false
            ConfirmEach = $false
        })

        # 扩展清理 - 根据数量决定
        $extCount = $this.DiscoveredData.ExtensionFiles.Count
        if ($extCount -gt 0) {
            $extStrategy = if ($extCount -gt 3) { "selective" } else { "remove" }
            $this.AddOperation("ExtensionClean", $extStrategy, @{
                TargetPatterns = @("*augment*")
                BackupRequired = $true
                ConfirmEach = ($extCount -gt 3)
            })
        }

        # 注册表清理 - 仅在低风险时执行
        if ($this.DiscoveredData.RegistryKeys.Count -gt 0 -and $overallRisk -ne "high") {
            $this.AddOperation("RegistryClean", "selective", @{
                TargetPatterns = @("*augment*")
                BackupRequired = $true
                ConfirmEach = $true
            })
        }
    }

    # 应用取证策略
    [void]ApplyForensicStrategy() {
        Write-StrategyLog "INFO" "应用取证清理策略"

        # 最彻底的清理，包括所有可能的痕迹
        $this.AddOperation("DatabaseClean", "forensic", @{
            TargetPatterns = @("*augment*", "*trial*", "*context7*", "*telemetry*", "*machineId*", "*deviceId*", "*session*")
            BackupRequired = $true
            ConfirmEach = $false
            VacuumAfter = $true
        })

        $this.AddOperation("ConfigClean", "forensic", @{
            TargetPatterns = @("*augment*", "*trial*", "*context7*", "*license*", "*subscription*")
            BackupRequired = $true
            ConfirmEach = $false
            DeepScan = $true
        })

        $this.AddOperation("CacheClean", "forensic", @{
            TargetPatterns = @("*augment*", "*cache*", "*temp*", "*log*", "*trial*", "*context*")
            BackupRequired = $false
            ConfirmEach = $false
            IncludeSystemTemp = $true
        })

        if ($this.DiscoveredData.RegistryKeys.Count -gt 0) {
            $this.AddOperation("RegistryClean", "forensic", @{
                TargetPatterns = @("*augment*", "*context7*", "*trial*", "*vscode*augment*")
                BackupRequired = $true
                ConfirmEach = $false
                AdminRequired = $true
                DeepScan = $true
            })
        }

        if ($this.DiscoveredData.ExtensionFiles.Count -gt 0) {
            $this.AddOperation("ExtensionClean", "forensic", @{
                TargetPatterns = @("*augment*", "*context7*")
                BackupRequired = $true
                ConfirmEach = $false
                IncludeDependencies = $true
            })
        }

        # 完整的身份重置
        $this.AddOperation("IdentityReset", "complete", @{
            BackupRequired = $true
            GenerateNewAll = $true
        })

        # 网络缓存清理
        $this.AddOperation("NetworkCacheClean", "full", @{
            TargetPatterns = @("*augment*", "*context7*")
            BackupRequired = $false
        })

        # 日志清理
        $this.AddOperation("LogClean", "selective", @{
            TargetPatterns = @("*augment*", "*trial*", "*context7*")
            BackupRequired = $false
        })
    }

    # 应用自定义策略
    [void]ApplyCustomStrategy() {
        Write-StrategyLog "INFO" "应用自定义清理策略"
        Write-StrategyLog "WARNING" "自定义策略需要用户配置，使用标准策略作为基础"

        # 默认使用标准策略，用户可以通过配置文件自定义
        $this.ApplyStandardStrategy()
    }

    # 添加操作到队列
    [void]AddOperation([string]$OperationType, [string]$Strategy, [hashtable]$Parameters) {
        $operation = @{
            Type = $OperationType
            Strategy = $Strategy
            Parameters = $Parameters
            Priority = $script:StrategyConfig.Operations[$OperationType].Priority
            EstimatedTime = $script:StrategyConfig.Operations[$OperationType].EstimatedTime
            RequiresBackup = $script:StrategyConfig.Operations[$OperationType].RequiresBackup
            ParallelSafe = $script:StrategyConfig.Operations[$OperationType].ParallelSafe
            Status = "Pending"
        }

        $this.OperationQueue += $operation
        Write-StrategyLog "DEBUG" "添加操作: $OperationType ($Strategy)"
    }

    # 操作优先级排序
    [void]PrioritizeOperations() {
        Write-StrategyLog "INFO" "正在排序清理操作..."

        # 按优先级排序
        $this.OperationQueue = $this.OperationQueue | Sort-Object Priority

        # 调整并行执行组
        $this.GroupParallelOperations()

        Write-StrategyLog "INFO" "操作排序完成，共 $($this.OperationQueue.Count) 个操作"
    }

    # 分组并行操作
    [void]GroupParallelOperations() {
        if (-not $EnableParallel) {
            Write-StrategyLog "DEBUG" "并行执行已禁用"
            return
        }

        $parallelGroups = @()
        $currentGroup = @()

        foreach ($operation in $this.OperationQueue) {
            if ($operation.ParallelSafe -and $currentGroup.Count -lt 3) {
                $currentGroup += $operation
            } else {
                if ($currentGroup.Count -gt 0) {
                    $parallelGroups += ,@($currentGroup)
                    $currentGroup = @()
                }
                $parallelGroups += ,@($operation)
            }
        }

        if ($currentGroup.Count -gt 0) {
            $parallelGroups += ,@($currentGroup)
        }

        # 更新操作队列以反映分组
        for ($i = 0; $i -lt $parallelGroups.Count; $i++) {
            $group = $parallelGroups[$i]
            foreach ($op in $group) {
                $op.ExecutionGroup = $i
                $op.CanRunInParallel = ($group.Count -gt 1)
            }
        }

        Write-StrategyLog "DEBUG" "创建了 $($parallelGroups.Count) 个执行组"
    }

    # 构建执行计划
    [void]BuildExecutionPlan() {
        Write-StrategyLog "INFO" "正在构建执行计划..."

        $this.CleanupPlan = @{
            Metadata = @{
                GeneratedAt = Get-Date
                StrategyMode = $this.SelectedMode
                TotalOperations = $this.OperationQueue.Count
                EstimatedDuration = ($this.OperationQueue | ForEach-Object { $_.EstimatedTime } | Measure-Object -Sum).Sum
                OverallRisk = $this.RiskAssessment.OverallRisk
            }

            PreExecutionChecks = @{
                VSCodeRunning = "Check if VS Code/Cursor is running"
                BackupSpace = "Verify sufficient disk space for backups"
                Permissions = "Check required permissions"
                Dependencies = "Verify required tools (sqlite3, etc.)"
            }

            Operations = $this.OperationQueue

            PostExecutionTasks = @{
                Verification = "Verify cleanup effectiveness"
                Cleanup = "Remove temporary files"
                Report = "Generate cleanup report"
                Restart = "Recommend application restart"
            }

            RiskAssessment = $this.RiskAssessment

            RollbackPlan = @{
                BackupLocations = @()
                RestoreInstructions = @()
                EmergencyContacts = @()
            }
        }

        # 生成备份计划
        $this.GenerateBackupPlan()

        # 生成回滚计划
        $this.GenerateRollbackPlan()

        Write-StrategyLog "SUCCESS" "执行计划构建完成"
    }

    # 生成备份计划
    [void]GenerateBackupPlan() {
        $backupPlan = @{
            BackupRoot = Join-Path $env:TEMP "AugmentVIP_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            RequiredSpace = 0
            BackupItems = @()
        }

        foreach ($operation in $this.OperationQueue) {
            if ($operation.RequiresBackup) {
                switch ($operation.Type) {
                    "DatabaseClean" {
                        foreach ($db in $this.DiscoveredData.Databases) {
                            $backupPlan.BackupItems += @{
                                Source = $db.Path
                                Type = "Database"
                                Size = $db.Size
                                Priority = "Critical"
                            }
                            $backupPlan.RequiredSpace += $db.Size
                        }
                    }
                    "ConfigClean" {
                        foreach ($config in $this.DiscoveredData.ConfigFiles) {
                            $backupPlan.BackupItems += @{
                                Source = $config.Path
                                Type = "Configuration"
                                Size = $config.Size
                                Priority = "Important"
                            }
                            $backupPlan.RequiredSpace += $config.Size
                        }
                    }
                    "ExtensionClean" {
                        foreach ($ext in $this.DiscoveredData.ExtensionFiles) {
                            $backupPlan.BackupItems += @{
                                Source = $ext.Path
                                Type = "Extension"
                                Size = (Get-ChildItem $ext.Path -Recurse | Measure-Object -Property Length -Sum).Sum
                                Priority = "Critical"
                            }
                        }
                    }
                }
            }
        }

        $this.CleanupPlan.BackupPlan = $backupPlan
        Write-StrategyLog "INFO" "备份计划: $($backupPlan.BackupItems.Count) 个项目, 需要空间: $([math]::Round($backupPlan.RequiredSpace / 1MB, 2)) MB"
    }

    # 生成回滚计划
    [void]GenerateRollbackPlan() {
        $rollbackPlan = @{
            AutoRollbackTriggers = @(
                "Critical error during execution",
                "User cancellation",
                "System instability detected"
            )

            ManualRollbackSteps = @(
                "1. Stop all VS Code/Cursor processes",
                "2. Restore database files from backup",
                "3. Restore configuration files from backup",
                "4. Restore extension files from backup",
                "5. Clear temporary files",
                "6. Restart applications"
            )

            RollbackValidation = @(
                "Verify all files restored successfully",
                "Check application startup",
                "Validate configuration integrity",
                "Test basic functionality"
            )
        }

        $this.CleanupPlan.RollbackPlan = $rollbackPlan
    }

    # 验证清理计划
    [void]ValidateCleanupPlan() {
        Write-StrategyLog "INFO" "正在验证清理计划..."

        $validationResults = @{
            IsValid = $true
            Errors = @()
            Warnings = @()
            Recommendations = @()
        }

        # 验证操作队列
        if ($this.OperationQueue.Count -eq 0) {
            $validationResults.Errors += "没有找到需要执行的清理操作"
            $validationResults.IsValid = $false
        }

        # 验证磁盘空间
        $requiredSpace = $this.CleanupPlan.BackupPlan.RequiredSpace
        $availableSpace = (Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace

        if ($requiredSpace -gt $availableSpace * 0.1) {  # 需要超过10%的可用空间
            $validationResults.Warnings += "备份可能需要大量磁盘空间 ($([math]::Round($requiredSpace / 1MB, 2)) MB)"
        }

        if ($requiredSpace -gt $availableSpace * 0.5) {  # 需要超过50%的可用空间
            $validationResults.Errors += "磁盘空间不足以创建备份"
            $validationResults.IsValid = $false
        }

        # 验证权限要求
        $needsAdmin = $this.OperationQueue | Where-Object { $_.Type -eq "RegistryClean" }
        if ($needsAdmin.Count -gt 0) {
            $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
            $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

            if (-not $isAdmin) {
                $validationResults.Warnings += "注册表清理需要管理员权限"
                $validationResults.Recommendations += "建议以管理员身份重新运行"
            }
        }

        # 验证依赖工具
        $requiredTools = @("sqlite3")
        foreach ($tool in $requiredTools) {
            if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
                $validationResults.Errors += "缺少必需工具: $tool"
                $validationResults.IsValid = $false
            }
        }

        $this.CleanupPlan.ValidationResults = $validationResults

        if ($validationResults.IsValid) {
            Write-StrategyLog "SUCCESS" "清理计划验证通过"
        } else {
            Write-StrategyLog "ERROR" "清理计划验证失败: $($validationResults.Errors -join '; ')"
        }

        if ($validationResults.Warnings.Count -gt 0) {
            Write-StrategyLog "WARNING" "验证警告: $($validationResults.Warnings -join '; ')"
        }
    }
}

# 主执行函数
function New-CleanupStrategy {
    param(
        [hashtable]$DiscoveredData,
        [string]$Mode = "adaptive",
        [string]$RiskTolerance = "medium",
        [switch]$EnableParallel = $true,
        [switch]$Verbose = $false
    )

    try {
        $engine = [CleanupStrategyEngine]::new($DiscoveredData, $Mode)
        $plan = $engine.GenerateCleanupPlan()

        return $plan
    } catch {
        Write-StrategyLog "ERROR" "清理策略生成失败: $($_.Exception.Message)"
        throw
    }
}

# 导出函数
Export-ModuleMember -Function New-CleanupStrategy
