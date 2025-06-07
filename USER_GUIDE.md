# VS Code Cleanup Master - 完整使用文档

## 📋 目录

- [概述](#概述)
- [系统要求](#系统要求)
- [安装指南](#安装指南)
- [快速开始](#快速开始)
- [详细使用说明](#详细使用说明)
- [高级功能](#高级功能)
- [故障排除](#故障排除)
- [最佳实践](#最佳实践)
- [API参考](#api参考)
- [常见问题](#常见问题)

## 🎯 概述

VS Code Cleanup Master 是一个专业的PowerShell工具套件，专门用于清理VS Code中的Augment相关数据和修改遥测标识符。该工具提供企业级的安全性、完整的备份恢复机制，并支持多种VS Code安装类型。

### 核心功能
- **数据库清理**：移除所有Augment和Context7相关条目
- **遥测修改**：生成新的安全随机遥测ID
- **自动备份**：操作前自动创建备份，支持完整恢复
- **多安装支持**：标准版、Insiders版、便携版VS Code
- **安全保障**：SQL注入防护、加密安全随机数生成
- **审计日志**：完整的操作记录和错误追踪

## 🖥️ 系统要求

### 最低要求
- **操作系统**：Windows 10 (版本 1903) 或更高版本
- **PowerShell**：版本 5.1 或更高版本
- **内存**：至少 4GB RAM
- **磁盘空间**：至少 1GB 可用空间（用于备份）
- **权限**：建议使用管理员权限运行

### 推荐配置
- **操作系统**：Windows 11 最新版本
- **PowerShell**：PowerShell 7.x
- **内存**：8GB RAM 或更多
- **磁盘空间**：5GB 可用空间
- **权限**：管理员权限

### 必需依赖
- **SQLite3**：用于数据库操作
- **curl**：用于网络操作（可选）
- **jq**：用于JSON处理（可选）

## 🚀 安装指南

### 方法一：自动安装（推荐）

1. **下载项目文件**
   ```powershell
   # 克隆或下载项目到本地目录
   cd "C:\Tools"
   # 解压项目文件到 augment-vip 目录
   ```

2. **运行安装脚本**
   ```powershell
   # 以管理员身份打开PowerShell
   cd "C:\Tools\augment-vip\scripts"
   
   # 设置执行策略（如果需要）
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   
   # 运行安装脚本
   .\install.ps1 --master --all
   ```

3. **验证安装**
   ```powershell
   # 测试主脚本
   .\vscode-cleanup-master.ps1 -Help
   ```

### 方法二：手动安装

1. **检查依赖**
   ```powershell
   # 检查PowerShell版本
   $PSVersionTable.PSVersion
   
   # 检查SQLite3
   sqlite3 -version
   
   # 如果缺少SQLite3，使用Chocolatey安装
   choco install sqlite
   ```

2. **验证模块**
   ```powershell
   # 测试模块导入
   Import-Module .\modules\Logger.psm1 -Force
   Import-Module .\modules\SystemDetection.psm1 -Force
   
   # 运行系统兼容性检查
   Test-SystemCompatibility
   ```

## ⚡ 快速开始

### 基本使用流程

1. **预览操作**（推荐首次使用）
   ```powershell
   .\vscode-cleanup-master.ps1 -Preview -All
   ```

2. **执行完整清理**
   ```powershell
   .\vscode-cleanup-master.ps1 -All
   ```

3. **仅清理数据库**
   ```powershell
   .\vscode-cleanup-master.ps1 -Clean
   ```

4. **仅修改遥测ID**
   ```powershell
   .\vscode-cleanup-master.ps1 -ModifyTelemetry
   ```

### 安全操作建议

⚠️ **重要提醒**：
- 确保VS Code完全关闭后再运行脚本
- 首次使用建议先运行预览模式
- 重要数据请手动备份
- 在测试环境中验证后再用于生产环境

## 📖 详细使用说明

### 命令行参数详解

```powershell
.\vscode-cleanup-master.ps1 [参数]
```

| 参数 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `-Clean` | 开关 | 仅执行数据库清理 | `-Clean` |
| `-ModifyTelemetry` | 开关 | 仅修改遥测ID | `-ModifyTelemetry` |
| `-All` | 开关 | 执行所有操作 | `-All` |
| `-Preview` | 开关 | 预览模式，不执行实际操作 | `-Preview -All` |
| `-NoBackup` | 开关 | 跳过备份创建 | `-All -NoBackup` |
| `-IncludePortable` | 开关 | 包含便携版VS Code（默认启用） | `-All -IncludePortable:$false` |
| `-LogFile` | 字符串 | 指定日志文件路径 | `-LogFile "C:\Logs\cleanup.log"` |
| `-Verbose` | 开关 | 启用详细日志 | `-All -Verbose` |
| `-WhatIf` | 开关 | 显示将要执行的操作 | `-All -WhatIf` |
| `-Help` | 开关 | 显示帮助信息 | `-Help` |

### 使用场景示例

#### 场景1：首次使用
```powershell
# 1. 检查系统兼容性
.\vscode-cleanup-master.ps1 -Help

# 2. 预览将要执行的操作
.\vscode-cleanup-master.ps1 -Preview -All -Verbose

# 3. 确认无误后执行
.\vscode-cleanup-master.ps1 -All -Verbose
```

#### 场景2：仅清理特定内容
```powershell
# 仅清理数据库，不修改遥测ID
.\vscode-cleanup-master.ps1 -Clean -Verbose

# 仅修改遥测ID，不清理数据库
.\vscode-cleanup-master.ps1 -ModifyTelemetry -Verbose
```

#### 场景3：批量处理
```powershell
# 处理包括便携版在内的所有VS Code安装
.\vscode-cleanup-master.ps1 -All -IncludePortable -Verbose

# 快速处理，跳过备份（不推荐）
.\vscode-cleanup-master.ps1 -All -NoBackup
```

#### 场景4：自定义日志
```powershell
# 指定自定义日志文件
.\vscode-cleanup-master.ps1 -All -LogFile "D:\MyLogs\vscode-cleanup.log" -Verbose
```

### 操作流程详解

#### 1. 系统检查阶段
脚本会自动执行以下检查：
- Windows版本兼容性
- PowerShell版本验证
- 必需依赖项检查
- 磁盘空间验证
- 执行权限确认

#### 2. VS Code发现阶段
自动扫描并识别：
- 标准VS Code安装
- VS Code Insiders安装
- 便携版VS Code安装
- 数据库文件位置
- 配置文件路径

#### 3. 备份阶段
为每个将要修改的文件创建备份：
- 时间戳命名
- SHA256完整性验证
- 元数据记录
- 备份位置：`data\backups\`

#### 4. 清理阶段
执行数据清理操作：
- 数据库条目清理
- 遥测ID生成和替换
- 操作结果验证
- 详细日志记录

#### 5. 验证阶段
确认操作成功：
- 备份完整性检查
- 修改结果验证
- 错误报告生成
- 统计信息汇总

## 🔧 高级功能

### 备份管理

#### 查看备份统计
```powershell
# 导入备份管理模块
Import-Module .\modules\BackupManager.psm1 -Force

# 显示备份统计信息
Show-BackupStatistics
```

#### 手动创建备份
```powershell
# 为特定文件创建备份
New-FileBackup -FilePath "C:\Users\User\AppData\Roaming\Code\storage.json" -Description "手动备份"
```

#### 恢复备份
```powershell
# 获取所有备份
$backups = Get-BackupFiles

# 恢复最新备份
$latestBackup = $backups | Sort-Object CreatedDate -Descending | Select-Object -First 1
Restore-FileBackup -BackupInfo $latestBackup -Force
```

#### 清理旧备份
```powershell
# 清理30天前的备份
Clear-OldBackups -Force
```

### 自定义清理模式

#### 修改清理模式
编辑 `scripts\modules\DatabaseCleaner.psm1` 文件中的模式：

```powershell
# 自定义Augment清理模式
$script:AugmentPatterns = @(
    '%augment%',
    '%Augment%',
    '%AUGMENT%',
    '%your-custom-pattern%'  # 添加自定义模式
)
```

#### 添加新的清理类别
```powershell
# 在DatabaseCleaner.psm1中添加新模式
$script:CustomPatterns = @(
    '%custom1%',
    '%custom2%'
)
```

### 日志管理

#### 配置日志级别
```powershell
# 导入日志模块
Import-Module .\modules\Logger.psm1 -Force

# 初始化日志（仅记录警告和错误）
Initialize-Logger -LogFilePath "custom.log" -Level Warning -EnableConsole $true -EnableFile $true
```

#### 自定义日志格式
日志文件格式：`[时间戳] [级别] 消息内容`

示例：
```
[2024-01-15 14:30:25] [INFO] Starting database cleaning operation...
[2024-01-15 14:30:26] [SUCCESS] Database cleaning completed
[2024-01-15 14:30:27] [WARNING] Some dependencies are missing
```

### 批处理和自动化

#### 创建批处理脚本
```batch
@echo off
cd /d "C:\Tools\augment-vip\scripts"
powershell.exe -ExecutionPolicy Bypass -File "vscode-cleanup-master.ps1" -All -Verbose
pause
```

#### 计划任务集成
```powershell
# 创建计划任务（需要管理员权限）
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\Tools\augment-vip\scripts\vscode-cleanup-master.ps1 -All"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 9AM
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "VSCode Cleanup" -Description "Weekly VS Code cleanup"
```

## 🔍 故障排除

### 常见错误及解决方案

#### 1. 模块导入失败
**错误信息**：`Failed to import module Logger.psm1`

**解决方案**：
```powershell
# 检查文件是否存在
Test-Path .\modules\Logger.psm1

# 检查执行策略
Get-ExecutionPolicy

# 设置执行策略
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 手动导入测试
Import-Module .\modules\Logger.psm1 -Force -Verbose
```

#### 2. SQLite3 未找到
**错误信息**：`SQLite3 command not found`

**解决方案**：
```powershell
# 使用Chocolatey安装
choco install sqlite

# 使用Scoop安装
scoop install sqlite

# 使用winget安装
winget install sqlite.sqlite

# 验证安装
sqlite3 -version
```

#### 3. 权限不足
**错误信息**：`Access denied` 或 `UnauthorizedAccessException`

**解决方案**：
```powershell
# 以管理员身份运行PowerShell
# 或者检查文件权限
Get-Acl "C:\Users\User\AppData\Roaming\Code\storage.json"

# 确保VS Code完全关闭
Get-Process Code -ErrorAction SilentlyContinue | Stop-Process -Force
```

#### 4. 备份空间不足
**错误信息**：`Low disk space` 或备份创建失败

**解决方案**：
```powershell
# 检查磁盘空间
Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "C:"}

# 清理旧备份
Clear-OldBackups -Force

# 使用外部存储
.\vscode-cleanup-master.ps1 -All -LogFile "D:\Backups\cleanup.log"
```

#### 5. VS Code 未找到
**错误信息**：`No VS Code installations found`

**解决方案**：
```powershell
# 手动检查VS Code安装位置
Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
Test-Path "$env:ProgramFiles\Microsoft VS Code\Code.exe"

# 检查便携版
.\vscode-cleanup-master.ps1 -Preview -All -IncludePortable -Verbose

# 手动指定路径（如果需要修改脚本）
```

### 调试模式

#### 启用详细调试
```powershell
# 启用详细输出
.\vscode-cleanup-master.ps1 -All -Verbose

# 启用PowerShell调试
$DebugPreference = "Continue"
.\vscode-cleanup-master.ps1 -All

# 查看系统信息
Import-Module .\modules\SystemDetection.psm1 -Force
Show-SystemInformation
```

#### 日志分析
```powershell
# 查看最新日志文件
Get-ChildItem .\logs\ | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content

# 搜索错误信息
Select-String -Path ".\logs\*.log" -Pattern "ERROR|CRITICAL"

# 分析备份状态
Get-BackupFiles | Where-Object {-not $_.IsValid}
```

### 性能优化

#### 大量文件处理
```powershell
# 跳过备份以提高速度（不推荐用于生产环境）
.\vscode-cleanup-master.ps1 -All -NoBackup

# 仅处理特定类型
.\vscode-cleanup-master.ps1 -Clean  # 仅数据库清理
.\vscode-cleanup-master.ps1 -ModifyTelemetry  # 仅遥测修改
```

#### 内存优化
```powershell
# 监控内存使用
Get-Process PowerShell | Select-Object Name, WorkingSet, VirtualMemorySize

# 清理PowerShell会话
[System.GC]::Collect()
```

## 💡 最佳实践

### 安全操作建议

1. **操作前准备**
   - 完全关闭VS Code和相关进程
   - 手动备份重要的工作区设置
   - 在测试环境中先验证脚本

2. **权限管理**
   - 使用最小必要权限原则
   - 避免在生产服务器上运行
   - 定期审查操作日志

3. **备份策略**
   - 始终启用自动备份
   - 定期验证备份完整性
   - 保留多个版本的备份

4. **监控和审计**
   - 启用详细日志记录
   - 定期检查操作结果
   - 建立操作审计流程

### 企业环境部署

#### 1. 集中化部署
```powershell
# 创建网络共享部署
$networkPath = "\\server\tools\vscode-cleanup"
Copy-Item -Path "C:\Tools\augment-vip" -Destination $networkPath -Recurse

# 创建统一配置
$config = @{
    BackupRetentionDays = 30
    LogLevel = "Info"
    DefaultOperations = @("Clean", "ModifyTelemetry")
}
$config | ConvertTo-Json | Set-Content "$networkPath\config\enterprise.json"
```

#### 2. 批量执行
```powershell
# 为多台机器创建执行脚本
$computers = @("PC001", "PC002", "PC003")
foreach ($computer in $computers) {
    Invoke-Command -ComputerName $computer -ScriptBlock {
        cd "C:\Tools\augment-vip\scripts"
        .\vscode-cleanup-master.ps1 -All -LogFile "C:\Logs\cleanup-$(Get-Date -Format 'yyyyMMdd').log"
    }
}
```

#### 3. 结果收集
```powershell
# 收集所有机器的日志
$logPath = "\\server\logs\vscode-cleanup"
$computers = @("PC001", "PC002", "PC003")
foreach ($computer in $computers) {
    $remoteLogs = "\\$computer\C$\Logs\cleanup-*.log"
    Copy-Item $remoteLogs -Destination "$logPath\$computer\" -ErrorAction SilentlyContinue
}
```

### 维护和更新

#### 定期维护任务
```powershell
# 每周执行的维护脚本
# 1. 清理旧备份
Clear-OldBackups -Force

# 2. 检查磁盘空间
$freeSpace = (Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "C:"}).FreeSpace / 1GB
if ($freeSpace -lt 5) {
    Write-Warning "Disk space low: $freeSpace GB remaining"
}

# 3. 验证模块完整性
$modules = @("Logger", "SystemDetection", "VSCodeDiscovery", "BackupManager", "DatabaseCleaner", "TelemetryModifier")
foreach ($module in $modules) {
    try {
        Import-Module ".\modules\$module.psm1" -Force
        Write-Host "$module module OK" -ForegroundColor Green
    } catch {
        Write-Host "$module module ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

#### 版本更新流程
1. **备份当前版本**
2. **测试新版本**
3. **逐步部署**
4. **验证功能**
5. **回滚计划**

## 📚 API参考

### 核心模块函数

#### Logger.psm1 - 日志记录模块
```powershell
# 初始化日志系统
Initialize-Logger -LogFilePath <string> -Level <LogLevel> -EnableConsole <bool> -EnableFile <bool>

# 日志记录函数
Write-LogInfo -Message <string>           # 信息日志
Write-LogWarning -Message <string>        # 警告日志
Write-LogError -Message <string> -Exception <Exception>  # 错误日志
Write-LogSuccess -Message <string>        # 成功日志
Write-LogDebug -Message <string>          # 调试日志
Write-LogCritical -Message <string> -Exception <Exception>  # 严重错误日志

# 进度显示
Write-LogProgress -Activity <string> -Status <string> -PercentComplete <int>
Complete-LogProgress -Id <int>
```

**使用示例**：
```powershell
Import-Module .\modules\Logger.psm1 -Force
Initialize-Logger -LogFilePath "custom.log" -Level Info -EnableConsole $true -EnableFile $true
Write-LogInfo "操作开始"
Write-LogSuccess "操作完成"
```

#### SystemDetection.psm1 - 系统检测模块
```powershell
# 系统兼容性检查
Test-SystemCompatibility [-SkipDependencies]  # 完整系统检查
Test-WindowsVersion                            # Windows版本检查
Test-PowerShellVersion                         # PowerShell版本检查
Test-Dependencies                              # 依赖项检查
Test-ExecutionPolicy                           # 执行策略检查
Test-AdministratorPrivileges                   # 管理员权限检查

# 系统信息
Get-SystemInformation                          # 获取系统信息
Show-SystemInformation                         # 显示系统信息
Test-VSCodeOperationRequirements              # VS Code操作要求检查
Test-DiskSpace                                # 磁盘空间检查
```

**使用示例**：
```powershell
Import-Module .\modules\SystemDetection.psm1 -Force
if (Test-SystemCompatibility) {
    Write-Host "系统兼容" -ForegroundColor Green
} else {
    Write-Host "系统不兼容" -ForegroundColor Red
}
Show-SystemInformation
```

#### VSCodeDiscovery.psm1 - VS Code发现模块
```powershell
# VS Code安装发现
Find-VSCodeInstallations [-IncludePortable]   # 发现所有安装
Find-StandardVSCode                           # 发现标准版
Find-InsidersVSCode                           # 发现Insiders版
Find-PortableVSCode                           # 发现便携版
Get-VSCodeInstallation -Type <VSCodeType>     # 获取特定类型安装
```

**VSCodeType枚举**：
- `Standard` - 标准版VS Code
- `Insiders` - Insiders版VS Code
- `Portable` - 便携版VS Code

**使用示例**：
```powershell
Import-Module .\modules\VSCodeDiscovery.psm1 -Force
$installations = Find-VSCodeInstallations -IncludePortable
foreach ($install in $installations) {
    Write-Host "发现: $($install.Name) 位于 $($install.Path)"
}
```

#### BackupManager.psm1 - 备份管理模块
```powershell
# 备份管理初始化
Initialize-BackupManager -BackupDirectory <string> -MaxAge <int> -MaxCount <int>

# 备份操作
New-FileBackup -FilePath <string> -Description <string>                    # 创建备份
Restore-FileBackup -BackupInfo <BackupInfo> -TargetPath <string> -Force   # 恢复备份
Test-BackupIntegrity -BackupInfo <BackupInfo>                             # 验证备份完整性

# 备份管理
Get-BackupFiles                               # 获取所有备份
Clear-OldBackups [-Force]                     # 清理旧备份
Show-BackupStatistics                         # 显示备份统计
```

**使用示例**：
```powershell
Import-Module .\modules\BackupManager.psm1 -Force
Initialize-BackupManager -BackupDirectory "C:\Backups" -MaxAge 30 -MaxCount 10

# 创建备份
$backup = New-FileBackup -FilePath "C:\test.txt" -Description "测试备份"

# 恢复备份
if ($backup) {
    Restore-FileBackup -BackupInfo $backup -Force
}

# 查看统计
Show-BackupStatistics
```

#### DatabaseCleaner.psm1 - 数据库清理模块
```powershell
# 单个数据库清理
Clear-VSCodeDatabase -DatabasePath <string> -CreateBackup <bool> -CleanAugment <bool> -CleanTelemetry <bool> -CleanExtensions <bool>

# 批量数据库清理
Clear-VSCodeDatabases -DatabasePaths <string[]> -CreateBackup <bool> -CleanAugment <bool> -CleanTelemetry <bool> -CleanExtensions <bool>

# 数据库分析
Get-DatabaseAnalysis -DatabasePath <string>    # 分析数据库内容
Show-CleaningPreview -DatabasePaths <string[]> # 显示清理预览

# 数据库工具
Test-DatabaseConnectivity -DatabasePath <string>  # 测试数据库连接
Optimize-Database -DatabasePath <string>           # 优化数据库
```

**使用示例**：
```powershell
Import-Module .\modules\DatabaseCleaner.psm1 -Force

# 分析数据库
$analysis = Get-DatabaseAnalysis -DatabasePath "C:\path\to\database.vscdb"
Write-Host "Augment条目: $($analysis.AugmentEntries)"

# 清理数据库
$result = Clear-VSCodeDatabase -DatabasePath "C:\path\to\database.vscdb" -CreateBackup $true -CleanAugment $true
if ($result.Success) {
    Write-Host "清理成功，移除了 $($result.TotalEntriesRemoved) 个条目"
}
```

#### TelemetryModifier.psm1 - 遥测修改模块
```powershell
# 遥测ID修改
Set-VSCodeTelemetryIds -StorageJsonPath <string> -CreateBackup <bool> -IdTypes <string[]>
Set-VSCodeTelemetryIdsMultiple -StorageJsonPaths <string[]> -CreateBackup <bool> -IdTypes <string[]>

# ID生成
New-TelemetryId -Type <string> -Length <int>    # 生成新的遥测ID
New-SecureHexString -Length <int>               # 生成安全十六进制字符串
New-SecureUUID                                  # 生成安全UUID

# 验证和预览
Test-StorageJsonValidity -StorageJsonPath <string>                           # 验证storage.json
Get-CurrentTelemetryIds -StorageJsonPath <string>                           # 获取当前遥测ID
Show-TelemetryModificationPreview -StorageJsonPaths <string[]> -IdTypes <string[]>  # 显示修改预览
New-TelemetryIdPreview -IdTypes <string[]>                                   # 预览新ID
```

**支持的ID类型**：
- `telemetry.machineId` - 机器ID (64字符十六进制)
- `telemetry.devDeviceId` - 设备ID (UUID v4)
- `telemetry.sqmId` - SQM ID (UUID v4)
- `telemetry.sessionId` - 会话ID (UUID v4)
- `telemetry.instanceId` - 实例ID (UUID v4)
- `telemetry.firstSessionDate` - 首次会话日期
- `telemetry.lastSessionDate` - 最后会话日期

**使用示例**：
```powershell
Import-Module .\modules\TelemetryModifier.psm1 -Force

# 预览当前ID
$currentIds = Get-CurrentTelemetryIds -StorageJsonPath "C:\path\to\storage.json"
$currentIds.GetEnumerator() | ForEach-Object { Write-Host "$($_.Key): $($_.Value)" }

# 生成新ID预览
$newIds = New-TelemetryIdPreview
$newIds.GetEnumerator() | ForEach-Object { Write-Host "新 $($_.Key): $($_.Value)" }

# 修改遥测ID
$result = Set-VSCodeTelemetryIds -StorageJsonPath "C:\path\to\storage.json" -CreateBackup $true
if ($result.Success) {
    Write-Host "成功修改了 $($result.NewIds.Count) 个遥测ID"
}
```

## ❓ 常见问题

### Q1: 脚本是否会影响VS Code的正常使用？
**A**: 不会。脚本只清理Augment相关的数据，不会影响VS Code的核心功能、扩展或用户设置。

### Q2: 如果操作出错，如何恢复？
**A**: 脚本会自动创建备份。使用以下命令恢复：
```powershell
$backups = Get-BackupFiles
$latestBackup = $backups | Sort-Object CreatedDate -Descending | Select-Object -First 1
Restore-FileBackup -BackupInfo $latestBackup -Force
```

### Q3: 脚本支持哪些VS Code版本？
**A**: 支持所有现代版本的VS Code，包括：
- VS Code 稳定版
- VS Code Insiders版
- 便携版VS Code

### Q4: 可以在企业环境中批量使用吗？
**A**: 可以。脚本支持静默模式和批量处理，适合企业环境部署。

### Q5: 脚本的安全性如何？
**A**: 脚本具备企业级安全性：
- SQL注入防护
- 加密安全的随机数生成
- 路径遍历防护
- 完整的审计日志

### Q6: 如何验证清理效果？
**A**: 使用预览模式查看将要清理的内容：
```powershell
.\vscode-cleanup-master.ps1 -Preview -All -Verbose
```

### Q7: 脚本运行需要多长时间？
**A**: 通常1-5分钟，取决于：
- VS Code安装数量
- 数据库文件大小
- 系统性能

### Q8: 可以自定义清理规则吗？
**A**: 可以。编辑 `DatabaseCleaner.psm1` 中的清理模式来自定义规则。

### Q9: 如何获得技术支持？
**A**: 
- 查看日志文件了解详细错误信息
- 使用 `-Verbose` 参数获得详细输出
- 检查本文档的故障排除部分

### Q10: 脚本是否开源？
**A**: 是的，这是Augment VIP项目的一部分，遵循项目的开源许可证。

## 🔧 配置文件示例

### 企业配置文件 (enterprise-config.json)
```json
{
  "backup": {
    "enabled": true,
    "retentionDays": 30,
    "maxBackupCount": 10,
    "directory": "D:\\VSCode-Backups"
  },
  "logging": {
    "level": "Info",
    "enableConsole": true,
    "enableFile": true,
    "directory": "D:\\VSCode-Logs"
  },
  "cleaning": {
    "augmentPatterns": [
      "%augment%",
      "%Augment%",
      "%AUGMENT%",
      "%context7%",
      "%Context7%",
      "%CONTEXT7%"
    ],
    "customPatterns": [
      "%your-custom-pattern%"
    ]
  },
  "telemetry": {
    "modifyIds": true,
    "idTypes": [
      "telemetry.machineId",
      "telemetry.devDeviceId",
      "telemetry.sqmId"
    ]
  },
  "discovery": {
    "includePortable": true,
    "searchPaths": [
      "C:\\PortableApps\\VSCode",
      "D:\\Tools\\VSCode"
    ]
  }
}
```

### 使用配置文件的脚本示例
```powershell
# load-config-example.ps1
param(
    [string]$ConfigPath = ".\config\enterprise-config.json"
)

# 加载配置
if (Test-Path $ConfigPath) {
    $config = Get-Content $ConfigPath | ConvertFrom-Json

    # 应用配置
    $backupDir = $config.backup.directory
    $logLevel = $config.logging.level
    $includePortable = $config.discovery.includePortable

    Write-Host "使用配置文件: $ConfigPath"
    Write-Host "备份目录: $backupDir"
    Write-Host "日志级别: $logLevel"

    # 执行清理
    .\vscode-cleanup-master.ps1 -All -Verbose
} else {
    Write-Error "配置文件未找到: $ConfigPath"
}
```

## 📋 实用脚本集合

### 1. 批量处理脚本 (batch-cleanup.ps1)
```powershell
# 批量处理多台计算机的VS Code清理
param(
    [string[]]$ComputerNames = @("PC001", "PC002", "PC003"),
    [string]$LogPath = "\\server\logs\vscode-cleanup"
)

$results = @()

foreach ($computer in $ComputerNames) {
    Write-Host "处理计算机: $computer" -ForegroundColor Yellow

    try {
        $result = Invoke-Command -ComputerName $computer -ScriptBlock {
            cd "C:\Tools\augment-vip\scripts"
            .\vscode-cleanup-master.ps1 -All -LogFile "C:\Temp\cleanup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
            return @{
                Computer = $env:COMPUTERNAME
                Success = $true
                Message = "清理完成"
                Timestamp = Get-Date
            }
        } -ErrorAction Stop

        $results += $result
        Write-Host "✓ $computer 处理成功" -ForegroundColor Green

    } catch {
        $results += @{
            Computer = $computer
            Success = $false
            Message = $_.Exception.Message
            Timestamp = Get-Date
        }
        Write-Host "✗ $computer 处理失败: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 生成报告
$report = $results | ConvertTo-Html -Title "VS Code 清理报告" -Head "<style>table{border-collapse:collapse;width:100%;}th,td{border:1px solid #ddd;padding:8px;text-align:left;}th{background-color:#f2f2f2;}</style>"
$reportPath = "$LogPath\cleanup-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
$report | Out-File $reportPath

Write-Host "报告已生成: $reportPath" -ForegroundColor Cyan
```

### 2. 健康检查脚本 (health-check.ps1)
```powershell
# VS Code 清理工具健康检查脚本
param(
    [switch]$Detailed
)

Write-Host "=== VS Code 清理工具健康检查 ===" -ForegroundColor Cyan

# 1. 检查模块完整性
Write-Host "`n1. 检查模块完整性..." -ForegroundColor Yellow
$modules = @("Logger", "SystemDetection", "VSCodeDiscovery", "BackupManager", "DatabaseCleaner", "TelemetryModifier")
$moduleStatus = @{}

foreach ($module in $modules) {
    $modulePath = ".\modules\$module.psm1"
    if (Test-Path $modulePath) {
        try {
            Import-Module $modulePath -Force -ErrorAction Stop
            $moduleStatus[$module] = "✓ 正常"
            Write-Host "  $module`: 正常" -ForegroundColor Green
        } catch {
            $moduleStatus[$module] = "✗ 错误: $($_.Exception.Message)"
            Write-Host "  $module`: 错误" -ForegroundColor Red
        }
    } else {
        $moduleStatus[$module] = "✗ 文件缺失"
        Write-Host "  $module`: 文件缺失" -ForegroundColor Red
    }
}

# 2. 检查系统兼容性
Write-Host "`n2. 检查系统兼容性..." -ForegroundColor Yellow
try {
    $compatible = Test-SystemCompatibility -SkipDependencies
    if ($compatible) {
        Write-Host "  系统兼容性: ✓ 通过" -ForegroundColor Green
    } else {
        Write-Host "  系统兼容性: ✗ 失败" -ForegroundColor Red
    }
} catch {
    Write-Host "  系统兼容性: ✗ 检查失败" -ForegroundColor Red
}

# 3. 检查依赖项
Write-Host "`n3. 检查依赖项..." -ForegroundColor Yellow
$dependencies = @("sqlite3", "curl", "jq")
foreach ($dep in $dependencies) {
    if (Get-Command $dep -ErrorAction SilentlyContinue) {
        Write-Host "  $dep`: ✓ 已安装" -ForegroundColor Green
    } else {
        Write-Host "  $dep`: ✗ 未安装" -ForegroundColor Red
    }
}

# 4. 检查VS Code安装
Write-Host "`n4. 检查VS Code安装..." -ForegroundColor Yellow
try {
    $installations = Find-VSCodeInstallations -IncludePortable
    if ($installations.Count -gt 0) {
        Write-Host "  发现 $($installations.Count) 个VS Code安装:" -ForegroundColor Green
        foreach ($install in $installations) {
            Write-Host "    - $($install.Name) ($($install.Type))" -ForegroundColor Cyan
        }
    } else {
        Write-Host "  ✗ 未发现VS Code安装" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ VS Code检查失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. 检查备份目录
Write-Host "`n5. 检查备份目录..." -ForegroundColor Yellow
$backupDir = ".\data\backups"
if (Test-Path $backupDir) {
    $backupCount = (Get-ChildItem $backupDir -Filter "*.backup" -ErrorAction SilentlyContinue).Count
    Write-Host "  备份目录: ✓ 存在 ($backupCount 个备份文件)" -ForegroundColor Green
} else {
    Write-Host "  备份目录: ✗ 不存在" -ForegroundColor Red
}

# 6. 检查日志目录
Write-Host "`n6. 检查日志目录..." -ForegroundColor Yellow
$logDir = ".\logs"
if (Test-Path $logDir) {
    $logCount = (Get-ChildItem $logDir -Filter "*.log" -ErrorAction SilentlyContinue).Count
    Write-Host "  日志目录: ✓ 存在 ($logCount 个日志文件)" -ForegroundColor Green
} else {
    Write-Host "  日志目录: ✗ 不存在" -ForegroundColor Red
}

# 详细信息
if ($Detailed) {
    Write-Host "`n=== 详细系统信息 ===" -ForegroundColor Cyan
    Show-SystemInformation

    Write-Host "`n=== 备份统计 ===" -ForegroundColor Cyan
    try {
        Initialize-BackupManager -BackupDirectory $backupDir -MaxAge 30 -MaxCount 10
        Show-BackupStatistics
    } catch {
        Write-Host "无法显示备份统计" -ForegroundColor Red
    }
}

Write-Host "`n=== 健康检查完成 ===" -ForegroundColor Cyan
```

### 3. 自动维护脚本 (maintenance.ps1)
```powershell
# 自动维护脚本 - 建议每周运行
param(
    [int]$BackupRetentionDays = 30,
    [int]$LogRetentionDays = 7,
    [switch]$Force
)

Write-Host "=== VS Code 清理工具自动维护 ===" -ForegroundColor Cyan

# 1. 清理旧备份
Write-Host "`n1. 清理旧备份文件..." -ForegroundColor Yellow
try {
    Initialize-BackupManager -BackupDirectory ".\data\backups" -MaxAge $BackupRetentionDays -MaxCount 10
    Clear-OldBackups -Force:$Force
    Write-Host "  ✓ 备份清理完成" -ForegroundColor Green
} catch {
    Write-Host "  ✗ 备份清理失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. 清理旧日志
Write-Host "`n2. 清理旧日志文件..." -ForegroundColor Yellow
try {
    $cutoffDate = (Get-Date).AddDays(-$LogRetentionDays)
    $oldLogs = Get-ChildItem ".\logs" -Filter "*.log" | Where-Object { $_.LastWriteTime -lt $cutoffDate }

    if ($oldLogs.Count -gt 0) {
        if ($Force -or (Read-Host "删除 $($oldLogs.Count) 个旧日志文件? (y/n)") -match '^[Yy]$') {
            $oldLogs | Remove-Item -Force
            Write-Host "  ✓ 删除了 $($oldLogs.Count) 个旧日志文件" -ForegroundColor Green
        } else {
            Write-Host "  - 跳过日志清理" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  - 没有需要清理的旧日志" -ForegroundColor Green
    }
} catch {
    Write-Host "  ✗ 日志清理失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. 检查磁盘空间
Write-Host "`n3. 检查磁盘空间..." -ForegroundColor Yellow
try {
    $drive = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq "C:" }
    $freeSpaceGB = [Math]::Round($drive.FreeSpace / 1GB, 2)

    if ($freeSpaceGB -lt 5) {
        Write-Host "  ⚠ 磁盘空间不足: $freeSpaceGB GB" -ForegroundColor Red
    } elseif ($freeSpaceGB -lt 10) {
        Write-Host "  ⚠ 磁盘空间较低: $freeSpaceGB GB" -ForegroundColor Yellow
    } else {
        Write-Host "  ✓ 磁盘空间充足: $freeSpaceGB GB" -ForegroundColor Green
    }
} catch {
    Write-Host "  ✗ 磁盘空间检查失败" -ForegroundColor Red
}

# 4. 验证模块完整性
Write-Host "`n4. 验证模块完整性..." -ForegroundColor Yellow
$modules = @("Logger", "SystemDetection", "VSCodeDiscovery", "BackupManager", "DatabaseCleaner", "TelemetryModifier")
$failedModules = @()

foreach ($module in $modules) {
    try {
        Import-Module ".\modules\$module.psm1" -Force -ErrorAction Stop
    } catch {
        $failedModules += $module
    }
}

if ($failedModules.Count -eq 0) {
    Write-Host "  ✓ 所有模块正常" -ForegroundColor Green
} else {
    Write-Host "  ✗ 模块错误: $($failedModules -join ', ')" -ForegroundColor Red
}

# 5. 生成维护报告
Write-Host "`n5. 生成维护报告..." -ForegroundColor Yellow
$reportPath = ".\logs\maintenance-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$report = @"
VS Code 清理工具维护报告
生成时间: $(Get-Date)
备份保留天数: $BackupRetentionDays
日志保留天数: $LogRetentionDays
磁盘可用空间: $freeSpaceGB GB
失败模块: $($failedModules -join ', ')
"@

$report | Out-File $reportPath -Encoding UTF8
Write-Host "  ✓ 维护报告已生成: $reportPath" -ForegroundColor Green

Write-Host "`n=== 维护完成 ===" -ForegroundColor Cyan
```

---

## 📞 技术支持

### 支持渠道
1. **文档查阅**: 查看本文档的故障排除部分
2. **日志分析**: 检查日志文件中的详细错误信息
3. **详细输出**: 使用 `-Verbose` 参数运行脚本获得更多信息
4. **健康检查**: 运行 `health-check.ps1` 脚本诊断问题
5. **社区支持**: 联系项目维护团队

### 报告问题时请提供
- 操作系统版本和PowerShell版本
- 完整的错误消息和堆栈跟踪
- 相关的日志文件内容
- 重现问题的步骤
- 系统配置信息（运行 `Show-SystemInformation`）

---

**版本**: 1.0.0
**最后更新**: 2024年1月
**文档语言**: 中文
**维护状态**: 活跃维护

© 2024 Augment VIP Project. 保留所有权利。
