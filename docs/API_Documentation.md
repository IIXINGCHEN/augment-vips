# Augment VIP 2.0 API 文档

## 概述

Augment VIP 2.0 是一个企业级的VS Code Augment清理工具，提供了全面的数据发现、智能清理策略和账号生命周期管理功能。

## 核心模块

### 1. 智能发现引擎 (discovery_engine.ps1)

#### 主要功能
- 自动发现所有Augment相关数据存储位置
- 多层次数据扫描（数据库、配置、缓存、注册表、扩展）
- 智能文件识别基于文件名模式和内容分析
- 深度扫描模式支持

#### 主要函数

##### `Start-AugmentDiscovery`
```powershell
Start-AugmentDiscovery [-Mode <string>] [-IncludeRegistry <switch>] [-IncludeTemp <switch>] [-Verbose <switch>]
```

**参数说明：**
- `Mode`: 扫描模式，可选值：
  - `"comprehensive"` (默认) - 全面扫描
  - `"standard"` - 标准扫描
  - `"quick"` - 快速扫描
- `IncludeRegistry`: 是否包含注册表扫描 (默认: true)
- `IncludeTemp`: 是否包含临时文件扫描 (默认: true)
- `Verbose`: 详细输出模式

**返回值：**
```powershell
@{
    Databases = @()        # 发现的数据库文件
    ConfigFiles = @()      # 发现的配置文件
    CacheFiles = @()       # 发现的缓存文件
    RegistryKeys = @()     # 发现的注册表项
    TempFiles = @()        # 发现的临时文件
    ExtensionFiles = @()   # 发现的扩展文件
    Metadata = @{          # 扫描元数据
        ScanStartTime = [DateTime]
        ScanMode = [string]
        TotalItemsFound = [int]
        ScanDuration = [TimeSpan]
    }
}
```

**使用示例：**
```powershell
# 基本使用
$results = Start-AugmentDiscovery

# 详细扫描
$results = Start-AugmentDiscovery -Mode "comprehensive" -Verbose

# 快速扫描（不包含注册表）
$results = Start-AugmentDiscovery -Mode "quick" -IncludeRegistry:$false
```

### 2. 清理策略引擎 (cleanup_strategy_engine.ps1)

#### 主要功能
- 多种清理模式支持（最小、保守、标准、激进、自适应、取证、自定义）
- 智能风险评估
- 策略选择算法
- 操作优先级排序和并行执行支持

#### 主要函数

##### `New-CleanupStrategy`
```powershell
New-CleanupStrategy -DiscoveredData <hashtable> [-Mode <string>] [-RiskTolerance <string>] [-EnableParallel <switch>] [-Verbose <switch>]
```

**参数说明：**
- `DiscoveredData`: 发现引擎返回的数据
- `Mode`: 清理模式，可选值：
  - `"minimal"` - 最小清理
  - `"conservative"` - 保守清理
  - `"standard"` - 标准清理（推荐）
  - `"aggressive"` - 激进清理
  - `"adaptive"` - 自适应清理（默认）
  - `"forensic"` - 取证清理
  - `"custom"` - 自定义清理
- `RiskTolerance`: 风险容忍度 ("low", "medium", "high")
- `EnableParallel`: 启用并行执行
- `Verbose`: 详细输出模式

**返回值：**
```powershell
@{
    Metadata = @{
        GeneratedAt = [DateTime]
        StrategyMode = [string]
        TotalOperations = [int]
        EstimatedDuration = [int]
        OverallRisk = [string]
    }
    Operations = @()           # 清理操作列表
    RiskAssessment = @{}       # 风险评估结果
    ValidationResults = @{}    # 验证结果
    BackupPlan = @{}          # 备份计划
    RollbackPlan = @{}        # 回滚计划
}
```

**使用示例：**
```powershell
# 基本使用
$strategy = New-CleanupStrategy -DiscoveredData $discoveryResults

# 激进模式
$strategy = New-CleanupStrategy -DiscoveredData $discoveryResults -Mode "aggressive"

# 自定义风险容忍度
$strategy = New-CleanupStrategy -DiscoveredData $discoveryResults -Mode "adaptive" -RiskTolerance "high"
```

### 3. 账号生命周期管理器 (account_lifecycle_manager.ps1)

#### 主要功能
- 多层次账号状态检测
- 完整的账号退出流程
- 全面的试用数据清理
- 身份标识重置机制

#### 主要函数

##### `Start-AccountLifecycleManagement`
```powershell
Start-AccountLifecycleManagement -DiscoveredData <hashtable> [-Action <string>] [-ForceLogout <switch>] [-ClearTrialData <switch>] [-Verbose <switch>]
```

**参数说明：**
- `DiscoveredData`: 发现引擎返回的数据
- `Action`: 操作类型，可选值：
  - `"logout"` - 账号退出（默认）
  - `"status"` - 检查状态
  - `"reset-identity"` - 重置身份
  - `"clear-trial"` - 清理试用数据
- `ForceLogout`: 强制退出
- `ClearTrialData`: 清理试用数据（默认: true）
- `Verbose`: 详细输出模式

**返回值：**
```powershell
@{
    Success = [bool]
    VSCodeLogout = @{
        Success = [bool]
        Details = [string]
        TokensCleared = [int]
        ConfigsCleared = [int]
    }
    AugmentLogout = @{
        Success = [bool]
        Details = [string]
        TokensCleared = [int]
        ConfigsCleared = [int]
    }
    TrialDataCleared = @{
        Success = [bool]
        Details = [string]
        DatabasesCleared = [int]
        ConfigsCleared = [int]
        EntriesRemoved = [int]
    }
    IdentityReset = @{
        Success = [bool]
        Details = [string]
        IdentifiersReset = [int]
        ConfigsModified = [int]
    }
    Summary = [string]
}
```

**使用示例：**
```powershell
# 完整账号退出
$result = Start-AccountLifecycleManagement -DiscoveredData $discoveryResults -Action "logout"

# 仅检查状态
$status = Start-AccountLifecycleManagement -DiscoveredData $discoveryResults -Action "status"

# 仅重置身份
$resetResult = Start-AccountLifecycleManagement -DiscoveredData $discoveryResults -Action "reset-identity"
```

### 4. 公共工具函数库 (common_utilities.ps1)

#### 主要功能
- 路径和文件操作工具
- 数据库操作工具
- 进度显示工具

#### 主要函数

##### `Get-StandardVSCodePaths`
```powershell
Get-StandardVSCodePaths
```
返回所有标准的VS Code和Cursor安装路径。

##### `Test-PathSafely`
```powershell
Test-PathSafely -Path <string> [-PathType <string>]
```
安全地测试路径是否存在，包含错误处理。

##### `Invoke-SQLiteQuerySafely`
```powershell
Invoke-SQLiteQuerySafely -DatabasePath <string> -Query <string> [-QueryType <string>] [-TimeoutSeconds <int>]
```
安全地执行SQLite查询，包含SQL注入防护。

##### `New-ProgressTracker`
```powershell
New-ProgressTracker -TotalSteps <int> -Activity <string>
```
创建进度跟踪器对象。

##### `Update-ProgressTracker`
```powershell
Update-ProgressTracker -Tracker <hashtable> -Status <string> [-StepIncrement <int>]
```
更新进度跟踪器状态。

## 清理模式详解

### 1. 最小清理模式 (minimal)
- **风险等级**: 极低
- **清理范围**: 仅基本试用数据
- **预计时间**: 30秒
- **效果评分**: 60%
- **适用场景**: 首次使用、风险敏感环境

### 2. 保守清理模式 (conservative)
- **风险等级**: 低
- **清理范围**: 明确安全的数据
- **预计时间**: 60秒
- **效果评分**: 75%
- **适用场景**: 谨慎用户、生产环境

### 3. 标准清理模式 (standard)
- **风险等级**: 中等
- **清理范围**: 平衡清理效果和安全性
- **预计时间**: 120秒
- **效果评分**: 90%
- **适用场景**: 推荐模式、一般用户

### 4. 激进清理模式 (aggressive)
- **风险等级**: 高
- **清理范围**: 最大化清理效果
- **预计时间**: 180秒
- **效果评分**: 98%
- **适用场景**: 经验用户、彻底清理需求

### 5. 自适应清理模式 (adaptive)
- **风险等级**: 可变
- **清理范围**: 根据数据类型动态调整
- **预计时间**: 150秒
- **效果评分**: 92%
- **适用场景**: 智能清理、企业用户

### 6. 取证清理模式 (forensic)
- **风险等级**: 极高
- **清理范围**: 彻底清除所有痕迹
- **预计时间**: 300秒
- **效果评分**: 99%
- **适用场景**: 安全要求极高的环境

### 7. 自定义清理模式 (custom)
- **风险等级**: 用户定义
- **清理范围**: 用户自定义
- **预计时间**: 可变
- **效果评分**: 可变
- **适用场景**: 特殊需求、高级用户

## 错误处理

所有模块都包含完整的错误处理机制：

1. **输入验证**: 所有参数都经过严格验证
2. **权限检查**: 自动检查所需权限
3. **备份机制**: 重要操作前自动创建备份
4. **回滚支持**: 支持操作失败时的自动回滚
5. **详细日志**: 提供详细的操作日志和错误信息

## 安全特性

1. **SQL注入防护**: 所有数据库查询都经过安全验证
2. **路径验证**: 防止路径遍历攻击
3. **权限最小化**: 仅请求必要的权限
4. **加密随机数**: 使用加密安全的随机数生成器
5. **审计日志**: 完整的操作审计记录

## 性能优化

1. **并行执行**: 支持安全操作的并行执行
2. **智能缓存**: 避免重复的文件系统操作
3. **增量扫描**: 支持增量数据发现
4. **内存优化**: 大文件的流式处理
5. **超时控制**: 防止长时间阻塞操作
