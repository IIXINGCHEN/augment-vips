# VS Code Cleanup Master - 快速参考

## 🙏 致谢

本项目基于 [azrilaiman2003/augment-vip](https://github.com/azrilaiman2003/augment-vip) 进行Windows系统优化开发。感谢原作者的贡献！

## 🚀 快速开始

### 基本命令
```powershell
# 预览所有操作
.\vscode-cleanup-master.ps1 -Preview -All

# 执行完整清理
.\vscode-cleanup-master.ps1 -All

# 仅清理数据库
.\vscode-cleanup-master.ps1 -Clean

# 仅修改遥测ID
.\vscode-cleanup-master.ps1 -ModifyTelemetry

# 显示帮助
.\vscode-cleanup-master.ps1 -Help
```

## 📋 命令参数速查

| 参数 | 说明 | 示例 |
|------|------|------|
| `-Clean` | 仅清理数据库 | `-Clean` |
| `-ModifyTelemetry` | 仅修改遥测ID | `-ModifyTelemetry` |
| `-All` | 执行所有操作 | `-All` |
| `-Preview` | 预览模式 | `-Preview -All` |
| `-NoBackup` | 跳过备份 | `-All -NoBackup` |
| `-IncludePortable` | 包含便携版 | `-All -IncludePortable:$false` |
| `-LogFile` | 自定义日志 | `-LogFile "custom.log"` |
| `-Verbose` | 详细输出 | `-All -Verbose` |
| `-WhatIf` | 显示操作预览 | `-All -WhatIf` |
| `-Help` | 显示帮助 | `-Help` |

## 🔧 常用操作

### 安装和设置
```powershell
# 设置执行策略
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 运行安装脚本
.\install.ps1 --master --all

# 检查系统兼容性
Import-Module .\modules\SystemDetection.psm1 -Force
Test-SystemCompatibility
```

### 备份管理
```powershell
# 导入备份模块
Import-Module .\modules\BackupManager.psm1 -Force

# 初始化备份管理器
Initialize-BackupManager -BackupDirectory ".\data\backups" -MaxAge 30 -MaxCount 10

# 查看备份统计
Show-BackupStatistics

# 获取所有备份
$backups = Get-BackupFiles

# 恢复最新备份
$latest = $backups | Sort-Object CreatedDate -Descending | Select-Object -First 1
Restore-FileBackup -BackupInfo $latest -Force

# 清理旧备份
Clear-OldBackups -Force
```

### 日志管理
```powershell
# 导入日志模块
Import-Module .\modules\Logger.psm1 -Force

# 初始化日志
Initialize-Logger -LogFilePath "custom.log" -Level Info -EnableConsole $true -EnableFile $true

# 写入不同级别的日志
Write-LogInfo "信息消息"
Write-LogWarning "警告消息"
Write-LogError "错误消息"
Write-LogSuccess "成功消息"
```

### VS Code 发现
```powershell
# 导入发现模块
Import-Module .\modules\VSCodeDiscovery.psm1 -Force

# 发现所有安装
$installations = Find-VSCodeInstallations -IncludePortable

# 显示发现的安装
foreach ($install in $installations) {
    Write-Host "$($install.Name) - $($install.Path)"
}

# 获取特定类型安装
$standardVSCode = Get-VSCodeInstallation -Type Standard
```

## 🛠️ 故障排除速查

### 常见错误
| 错误 | 原因 | 解决方案 |
|------|------|----------|
| `模块导入失败` | 执行策略限制 | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| `SQLite3 未找到` | 缺少依赖 | `choco install sqlite` |
| `权限不足` | 需要管理员权限 | 以管理员身份运行PowerShell |
| `VS Code 未找到` | 路径问题 | 检查VS Code安装路径 |
| `备份失败` | 磁盘空间不足 | 清理磁盘空间或更改备份位置 |

### 快速诊断
```powershell
# 运行健康检查
.\health-check.ps1 -Detailed

# 检查系统信息
Import-Module .\modules\SystemDetection.psm1 -Force
Show-SystemInformation

# 测试模块导入
$modules = @("Logger", "SystemDetection", "VSCodeDiscovery", "BackupManager", "DatabaseCleaner", "TelemetryModifier")
foreach ($module in $modules) {
    try {
        Import-Module ".\modules\$module.psm1" -Force
        Write-Host "$module`: OK" -ForegroundColor Green
    } catch {
        Write-Host "$module`: ERROR" -ForegroundColor Red
    }
}
```

## 📊 模块功能速查

### Logger.psm1
- `Initialize-Logger` - 初始化日志系统
- `Write-LogInfo/Warning/Error/Success/Debug/Critical` - 写入日志
- `Write-LogProgress/Complete-LogProgress` - 进度显示

### SystemDetection.psm1
- `Test-SystemCompatibility` - 系统兼容性检查
- `Test-WindowsVersion/PowerShellVersion/Dependencies` - 具体检查
- `Get-SystemInformation/Show-SystemInformation` - 系统信息

### VSCodeDiscovery.psm1
- `Find-VSCodeInstallations` - 发现所有安装
- `Find-StandardVSCode/InsidersVSCode/PortableVSCode` - 特定类型发现
- `Get-VSCodeInstallation` - 获取特定安装

### BackupManager.psm1
- `Initialize-BackupManager` - 初始化备份管理
- `New-FileBackup/Restore-FileBackup` - 创建/恢复备份
- `Get-BackupFiles/Clear-OldBackups` - 管理备份
- `Test-BackupIntegrity/Show-BackupStatistics` - 验证/统计

### DatabaseCleaner.psm1
- `Clear-VSCodeDatabase/Clear-VSCodeDatabases` - 清理数据库
- `Get-DatabaseAnalysis/Show-CleaningPreview` - 分析/预览
- `Test-DatabaseConnectivity/Optimize-Database` - 连接/优化

### TelemetryModifier.psm1
- `Set-VSCodeTelemetryIds/Set-VSCodeTelemetryIdsMultiple` - 修改ID
- `New-TelemetryId/New-SecureHexString/New-SecureUUID` - 生成ID
- `Get-CurrentTelemetryIds/Show-TelemetryModificationPreview` - 查看/预览

## 🔐 安全最佳实践

### 操作前检查
```powershell
# 1. 确保VS Code完全关闭
Get-Process Code -ErrorAction SilentlyContinue | Stop-Process -Force

# 2. 预览操作
.\vscode-cleanup-master.ps1 -Preview -All -Verbose

# 3. 检查备份空间
$drive = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq "C:" }
$freeSpaceGB = [Math]::Round($drive.FreeSpace / 1GB, 2)
Write-Host "可用空间: $freeSpaceGB GB"
```

### 备份验证
```powershell
# 验证备份完整性
$backups = Get-BackupFiles
foreach ($backup in $backups) {
    if (Test-BackupIntegrity -BackupInfo $backup) {
        Write-Host "✓ $($backup.BackupPath)" -ForegroundColor Green
    } else {
        Write-Host "✗ $($backup.BackupPath)" -ForegroundColor Red
    }
}
```

## 📈 性能优化

### 快速模式
```powershell
# 跳过备份（仅测试环境）
.\vscode-cleanup-master.ps1 -All -NoBackup

# 仅处理标准版
.\vscode-cleanup-master.ps1 -All -IncludePortable:$false

# 仅清理数据库
.\vscode-cleanup-master.ps1 -Clean
```

### 批量处理
```powershell
# 多台计算机批量处理
$computers = @("PC001", "PC002", "PC003")
foreach ($computer in $computers) {
    Invoke-Command -ComputerName $computer -ScriptBlock {
        cd "C:\Tools\augment-vip\scripts"
        .\vscode-cleanup-master.ps1 -All
    }
}
```

## 🔍 调试技巧

### 启用详细输出
```powershell
# 全局调试
$DebugPreference = "Continue"
$VerbosePreference = "Continue"

# 运行脚本
.\vscode-cleanup-master.ps1 -All -Verbose
```

### 日志分析
```powershell
# 查看最新日志
$latestLog = Get-ChildItem .\logs\ | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Get-Content $latestLog.FullName

# 搜索错误
Select-String -Path ".\logs\*.log" -Pattern "ERROR|CRITICAL|FAILED"

# 统计操作结果
Select-String -Path ".\logs\*.log" -Pattern "SUCCESS|completed" | Measure-Object
```

## 📞 快速支持

### 收集诊断信息
```powershell
# 一键收集诊断信息
$diagInfo = @{
    Timestamp = Get-Date
    OSVersion = [System.Environment]::OSVersion.VersionString
    PSVersion = $PSVersionTable.PSVersion.ToString()
    LastError = $Error[0]
    SystemInfo = Get-SystemInformation
}

$diagInfo | ConvertTo-Json | Out-File "diagnostic-info.json"
```

### 重置环境
```powershell
# 重置到初始状态
Remove-Module Logger, SystemDetection, VSCodeDiscovery, BackupManager, DatabaseCleaner, TelemetryModifier -Force -ErrorAction SilentlyContinue

# 清理变量
Get-Variable | Where-Object { $_.Name -like "*vscode*" -or $_.Name -like "*backup*" } | Remove-Variable -Force -ErrorAction SilentlyContinue

# 重新导入
.\vscode-cleanup-master.ps1 -Help
```

---

**快速参考版本**: 1.0.0  
**对应主版本**: VS Code Cleanup Master 1.0.0  
**最后更新**: 2024年1月
