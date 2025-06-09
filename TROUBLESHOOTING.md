# VS Code Cleanup Master - 故障排除指南

> 💡 **提示**: 基本使用方法请参考 [USER_GUIDE.md](USER_GUIDE.md) 中的快速参考章节。本文档专注于解决具体的技术问题。

## 📋 目录

- [PowerShell执行策略问题](#powershell执行策略问题)
- [模块导入问题](#模块导入问题)
- [依赖项问题](#依赖项问题)
- [权限问题](#权限问题)
- [VS Code检测问题](#vs-code检测问题)
- [备份和恢复问题](#备份和恢复问题)
- [性能问题](#性能问题)
- [高级调试](#高级调试)

## 🚨 PowerShell执行策略问题

> 💡 **快速解决**: 运行 `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`，详细说明请参考 [USER_GUIDE.md](USER_GUIDE.md)。

### 高级执行策略问题

#### 企业环境中的组策略限制
```powershell
# 检查组策略设置
Get-ExecutionPolicy -List

# 如果显示 "MachinePolicy" 或 "UserPolicy"，说明被组策略限制
# 解决方案：联系IT管理员或使用便携版PowerShell
```

#### 文件来源标记问题
```powershell
# 检查文件是否被标记为来自网络
Get-Item .\scripts\*.ps1 | Get-ItemProperty -Name Zone.Identifier -ErrorAction SilentlyContinue

# 批量移除网络来源标记
Get-ChildItem .\scripts\ -Recurse | Unblock-File
```

## 🔧 模块导入问题

### 高级模块问题诊断
```powershell
# 检查模块依赖关系
$modules = @("Logger", "SystemDetection", "VSCodeDiscovery", "BackupManager", "DatabaseCleaner", "TelemetryModifier")
foreach ($module in $modules) {
    $modulePath = ".\scripts\windows\modules\$module.psm1"
    if (Test-Path $modulePath) {
        try {
            Import-Module $modulePath -Force -PassThru | Select-Object Name, Version, ModuleType
        } catch {
            Write-Warning "Failed to import $module`: $($_.Exception.Message)"
        }
    } else {
        Write-Error "Module file not found: $modulePath"
    }
}
```

### 模块版本冲突
```powershell
# 检查已加载的同名模块
Get-Module | Where-Object { $_.Name -in @("Logger", "SystemDetection") }

# 强制移除冲突模块
Remove-Module Logger, SystemDetection -Force -ErrorAction SilentlyContinue
```

## 📦 依赖项问题

### 高级依赖问题
```powershell
# 检查所有依赖项状态
$dependencies = @{
    "sqlite3" = "sqlite3 -version"
    "curl" = "curl --version"
    "git" = "git --version"
}

foreach ($dep in $dependencies.GetEnumerator()) {
    try {
        $result = Invoke-Expression $dep.Value 2>$null
        Write-Host "✅ $($dep.Key): Available" -ForegroundColor Green
    } catch {
        Write-Host "❌ $($dep.Key): Missing" -ForegroundColor Red
    }
}
```

### 环境变量问题
```powershell
# 检查PATH环境变量
$env:PATH -split ';' | Where-Object { $_ -like "*sqlite*" -or $_ -like "*curl*" }

# 临时添加到PATH（当前会话）
$env:PATH += ";C:\sqlite3;C:\curl"
```

## 🔐 权限问题

### 访问被拒绝错误
```powershell
# 1. 以管理员身份运行PowerShell
# 右键点击PowerShell图标 -> "以管理员身份运行"

# 2. 检查文件权限
Get-Acl "C:\Users\$env:USERNAME\AppData\Roaming\Code\storage.json"

# 3. 确保VS Code完全关闭
Get-Process Code -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process "Code - Insiders" -ErrorAction SilentlyContinue | Stop-Process -Force

# 4. 检查文件是否被占用
Handle.exe storage.json  # 需要安装 Sysinternals Handle
```

## 🔍 VS Code检测问题

### 未找到VS Code安装
```powershell
# 手动检查常见安装位置
$locations = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
    "$env:ProgramFiles\Microsoft VS Code\Code.exe",
    "$env:ProgramFiles(x86)\Microsoft VS Code\Code.exe",
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\Code - Insiders.exe"
)

foreach ($location in $locations) {
    if (Test-Path $location) {
        Write-Host "✅ Found: $location" -ForegroundColor Green
    } else {
        Write-Host "❌ Not found: $location" -ForegroundColor Red
    }
}

# 检查便携版
.\scripts\vscode-cleanup-master.ps1 -Preview -All -IncludePortable -Verbose

# 手动指定VS Code路径（如果需要修改脚本）
```

## 💾 备份和恢复问题

### 备份创建失败
```powershell
# 检查磁盘空间
Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "C:"} | 
    Select-Object DeviceID, @{Name="FreeSpaceGB";Expression={[Math]::Round($_.FreeSpace/1GB,2)}}

# 清理旧备份
Import-Module .\scripts\windows\modules\BackupManager.psm1 -Force
Clear-OldBackups -Force

# 更改备份位置
$env:BACKUP_DIRECTORY = "D:\Backups"
```

### 备份完整性验证失败
```powershell
# 检查备份完整性
$backups = Get-BackupFiles
foreach ($backup in $backups) {
    if (Test-BackupIntegrity -BackupInfo $backup) {
        Write-Host "✅ $($backup.BackupPath)" -ForegroundColor Green
    } else {
        Write-Host "❌ $($backup.BackupPath)" -ForegroundColor Red
    }
}
```

## 🚀 性能问题

### 脚本运行缓慢
```powershell
# 跳过备份以提高速度（仅测试环境）
.\run.ps1 -Operation All -NoBackup

# 分步执行
.\run.ps1 -Operation Clean           # 仅清理数据库
.\run.ps1 -Operation ModifyTelemetry # 仅修改遥测

# 或直接使用Windows脚本（高级用法）
.\scripts\windows\vscode-cleanup-master.ps1 -All -NoBackup
```

### 内存使用过高
```powershell
# 监控内存使用
Get-Process PowerShell | Select-Object Name, WorkingSet, VirtualMemorySize

# 强制垃圾回收
[System.GC]::Collect()

# 重启PowerShell会话
```

## � 高级调试

### 深度系统诊断
```powershell
# 完整系统状态检查
$systemDiag = @{
    PowerShellVersion = $PSVersionTable
    ExecutionPolicy = Get-ExecutionPolicy -List
    ModulePath = $env:PSModulePath -split ';'
    ProcessList = Get-Process | Where-Object { $_.ProcessName -like "*code*" }
    DiskSpace = Get-CimInstance -ClassName Win32_LogicalDisk | Select-Object DeviceID, @{Name="FreeSpaceGB";Expression={[Math]::Round($_.FreeSpace/1GB,2)}}
    NetworkConnectivity = Test-NetConnection -ComputerName "github.com" -Port 443 -InformationLevel Quiet
}

$systemDiag | ConvertTo-Json -Depth 3 | Out-File "system-diagnostic.json"
```

### 性能分析
```powershell
# 监控脚本性能
Measure-Command { .\run.ps1 -Operation All -Preview }

# 内存使用监控
$before = Get-Process PowerShell | Measure-Object WorkingSet -Sum
.\run.ps1 -Operation Clean
$after = Get-Process PowerShell | Measure-Object WorkingSet -Sum
Write-Host "Memory usage: $([Math]::Round(($after.Sum - $before.Sum) / 1MB, 2)) MB"
```

### 错误追踪
```powershell
# 启用详细错误追踪
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

try {
    .\run.ps1 -Operation All
} catch {
    $_.Exception | Format-List -Force
    $_.ScriptStackTrace
}
```

## 🔄 重置和恢复

### 重置环境
```powershell
# 移除所有模块
Remove-Module Logger, SystemDetection, VSCodeDiscovery, BackupManager, DatabaseCleaner, TelemetryModifier -Force -ErrorAction SilentlyContinue

# 清理变量
Get-Variable | Where-Object { $_.Name -like "*vscode*" -or $_.Name -like "*backup*" } | Remove-Variable -Force -ErrorAction SilentlyContinue

# 重新初始化
.\run.ps1 -Help
```

### 从备份恢复
```powershell
# 获取所有备份
$backups = Get-BackupFiles

# 恢复最新备份
$latestBackup = $backups | Sort-Object CreatedDate -Descending | Select-Object -First 1
Restore-FileBackup -BackupInfo $latestBackup -Force
```

---

**故障排除指南版本**: 1.0.0  
**最后更新**: 2024年1月  
**适用版本**: VS Code Cleanup Master 1.0.0
