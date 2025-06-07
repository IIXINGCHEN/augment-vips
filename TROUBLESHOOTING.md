# VS Code Cleanup Master - 故障排除指南

## 🙏 致谢

本项目基于 [azrilaiman2003/augment-vip](https://github.com/azrilaiman2003/augment-vip) 进行Windows系统优化开发。感谢原作者的贡献！

## 📋 目录

- [PowerShell执行策略问题](#powershell执行策略问题)
- [模块导入问题](#模块导入问题)
- [依赖项问题](#依赖项问题)
- [权限问题](#权限问题)
- [VS Code检测问题](#vs-code检测问题)
- [备份和恢复问题](#备份和恢复问题)
- [性能问题](#性能问题)
- [日志和调试](#日志和调试)

## 🚨 PowerShell执行策略问题

### 问题描述
这是最常见的问题。Windows系统默认阻止运行未签名的PowerShell脚本，会出现以下错误：

```
无法加载文件 xxx.ps1。未对文件进行数字签名。无法在当前系统上运行该脚本。
UnauthorizedAccess
Execution of scripts is disabled on this system
```

### 解决方案

#### 方案1：永久设置执行策略（推荐）
```powershell
# 检查当前执行策略
Get-ExecutionPolicy -List

# 为当前用户设置（推荐，最安全）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 为所有用户设置（需要管理员权限）
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine

# 验证设置
Get-ExecutionPolicy -Scope CurrentUser
```

#### 方案2：临时绕过执行策略
```powershell
# 单次运行脚本
PowerShell -ExecutionPolicy Bypass -File .\scripts\install.ps1 --master --all

# 或者在当前会话中临时设置
Set-ExecutionPolicy Bypass -Scope Process
```

#### 方案3：解除文件阻止
```powershell
# 解除单个文件阻止
Unblock-File .\scripts\install.ps1

# 解除所有脚本文件阻止
Get-ChildItem .\scripts\*.ps1 | Unblock-File
Get-ChildItem .\scripts\modules\*.psm1 | Unblock-File

# 批量解除阻止
Unblock-File .\scripts\*.ps1
Unblock-File .\scripts\modules\*.psm1
```

### 执行策略说明

| 策略 | 说明 | 安全级别 | 推荐度 |
|------|------|----------|--------|
| `Restricted` | 禁止所有脚本（Windows默认） | 最高 | ❌ 太严格 |
| `RemoteSigned` | 本地脚本可运行，远程脚本需签名 | 高 | ✅ 推荐 |
| `Unrestricted` | 允许所有脚本，远程脚本有警告 | 中 | ⚠️ 谨慎使用 |
| `Bypass` | 无限制，无警告 | 低 | ❌ 仅临时使用 |

### 验证解决方案
```powershell
# 检查执行策略设置
Get-ExecutionPolicy -List

# 测试脚本运行
.\scripts\vscode-cleanup-master.ps1 -Help

# 测试模块导入
Import-Module .\scripts\modules\Logger.psm1 -Force
```

## 🔧 模块导入问题

### 问题描述
```
Failed to import module Logger.psm1
Import-Module : 无法加载指定的模块
```

### 解决方案
```powershell
# 1. 检查文件是否存在
Test-Path .\scripts\modules\Logger.psm1

# 2. 检查执行策略（参考上面的解决方案）
Get-ExecutionPolicy

# 3. 解除模块文件阻止
Unblock-File .\scripts\modules\*.psm1

# 4. 强制导入模块
Import-Module .\scripts\modules\Logger.psm1 -Force -Verbose

# 5. 检查模块路径
$env:PSModulePath -split ';'

# 6. 测试所有模块
$modules = @("Logger", "SystemDetection", "VSCodeDiscovery", "BackupManager", "DatabaseCleaner", "TelemetryModifier")
foreach ($module in $modules) {
    try {
        Import-Module ".\scripts\modules\$module.psm1" -Force
        Write-Host "$module`: ✅ OK" -ForegroundColor Green
    } catch {
        Write-Host "$module`: ❌ ERROR - $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

## 📦 依赖项问题

### SQLite3 未找到
```powershell
# 检查是否已安装
sqlite3 -version

# 使用包管理器安装
# Chocolatey
choco install sqlite

# Scoop
scoop install sqlite

# winget
winget install sqlite.sqlite

# 手动安装
# 1. 下载 SQLite3 from https://www.sqlite.org/download.html
# 2. 解压到 C:\sqlite3
# 3. 添加到 PATH 环境变量
```

### curl 和 jq 未找到（可选依赖）
```powershell
# 安装 curl（Windows 10+ 通常已内置）
winget install curl.curl

# 安装 jq
choco install jq
# 或
scoop install jq
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
Import-Module .\scripts\modules\BackupManager.psm1 -Force
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

## 📊 日志和调试

### 启用详细调试
```powershell
# 全局调试设置
$DebugPreference = "Continue"
$VerbosePreference = "Continue"

# 运行脚本
.\run.ps1 -Operation All -VerboseOutput

# 或直接使用Windows脚本
.\scripts\windows\vscode-cleanup-master.ps1 -All -Verbose

# 查看系统信息
Import-Module .\scripts\windows\modules\SystemDetection.psm1 -Force
Show-SystemInformation
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

### 收集诊断信息
```powershell
# 一键收集诊断信息
$diagInfo = @{
    Timestamp = Get-Date
    OSVersion = [System.Environment]::OSVersion.VersionString
    PSVersion = $PSVersionTable.PSVersion.ToString()
    ExecutionPolicy = Get-ExecutionPolicy -List
    LastError = $Error[0]
    VSCodePaths = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code",
        "$env:ProgramFiles\Microsoft VS Code",
        "$env:APPDATA\Code"
    ) | Where-Object { Test-Path $_ }
}

$diagInfo | ConvertTo-Json -Depth 3 | Out-File "diagnostic-info.json"
Write-Host "诊断信息已保存到 diagnostic-info.json"
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
