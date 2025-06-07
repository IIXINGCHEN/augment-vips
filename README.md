# VS Code 清理大师脚本

一个专为Windows系统优化的综合性PowerShell解决方案，用于清理VS Code数据和修改遥测标识符，具备完整的备份恢复功能。

## 🙏 致谢

本项目基于 [azrilaiman2003/augment-vip](https://github.com/azrilaiman2003/augment-vip) 进行二次开发和优化。

**感谢原作者 azrilaiman2003 的贡献！** 我们在原项目基础上专门为Windows系统进行了以下重大改进：
- ✅ **Windows系统完整支持** - 专门为Windows 10+系统优化
- ✅ **PowerShell模块化架构** - 企业级代码结构
- ✅ **完整的备份恢复系统** - 安全可靠的操作保障
- ✅ **多VS Code版本支持** - 标准版、Insiders版、便携版
- ✅ **企业级安全特性** - SQL注入防护、加密安全随机数生成
- ✅ **完整的文档系统** - 详细的使用指南和API文档

## 核心功能

- **数据库清理**: 移除VS Code SQLite数据库中的所有Augment相关条目
- **遥测修改**: 生成新的安全随机遥测ID (machineId, deviceId, sqmId)
- **自动备份**: 在任何修改前创建备份，具备完整性验证
- **多安装支持**: 检测并处理标准版、Insiders版和便携版VS Code安装
- **Context7框架兼容**: 专门设计用于Context7框架
- **回滚功能**: 需要时可从备份恢复
- **系统兼容**: Windows 10+ 配合 PowerShell 5.1+

## 系统要求

### 最低要求
- **操作系统**: Windows 10 或更高版本
- **PowerShell**: 版本 5.1 或更高
- **依赖项**: SQLite3, curl, jq (自动检查)
- **磁盘空间**: 至少1GB可用空间用于备份操作

### 推荐配置
- 管理员权限以获得完整功能
- PowerShell执行策略设置为RemoteSigned或Unrestricted

## 安装指南

### 快速安装
```powershell
# 下载并运行安装脚本
.\install.ps1 --master --all
```

### 手动安装
1. 克隆或下载仓库
2. 导航到scripts目录
3. 使用所需选项运行安装脚本

## 使用方法

### 主脚本 (推荐)
```powershell
# 清理数据库并修改遥测ID
.\vscode-cleanup-master.ps1 -All

# 预览操作而不执行
.\vscode-cleanup-master.ps1 -Preview -All

# 仅清理数据库
.\vscode-cleanup-master.ps1 -Clean

# 仅修改遥测ID
.\vscode-cleanup-master.ps1 -ModifyTelemetry

# 跳过备份创建
.\vscode-cleanup-master.ps1 -All -NoBackup

# 包含便携版安装
.\vscode-cleanup-master.ps1 -All -IncludePortable

# 启用详细日志
.\vscode-cleanup-master.ps1 -All -Verbose

# 显示将要执行的操作而不实际执行
.\vscode-cleanup-master.ps1 -All -WhatIf
```

### 安装脚本选项
```powershell
# 使用新的主脚本 (推荐)
.\install.ps1 --master --all

# 预览操作
.\install.ps1 --master --preview

# 传统的独立脚本
.\install.ps1 --clean
.\install.ps1 --modify-ids
.\install.ps1 --all
```

## 命令行选项

### 主脚本参数
| 参数 | 说明 |
|------|------|
| `-Clean` | 清理Augment相关的数据库条目 |
| `-ModifyTelemetry` | 修改VS Code遥测ID |
| `-All` | 执行所有操作 |
| `-Preview` | 显示预览而不进行更改 |
| `-Backup` | 创建备份 (默认: true) |
| `-NoBackup` | 跳过备份创建 |
| `-IncludePortable` | 包含便携版VS Code安装 |
| `-LogFile <path>` | 指定自定义日志文件路径 |
| `-Verbose` | 启用详细日志 |
| `-WhatIf` | 显示将要执行的操作而不实际执行 |
| `-Help` | 显示帮助信息 |

## 清理内容

### 数据库条目
- 所有包含"augment"、"Augment"或"AUGMENT"的条目
- Augment VIP的扩展相关条目
- 遥测和会话数据 (可选)

### 修改的遥测ID
- `telemetry.machineId` - 64字符十六进制字符串
- `telemetry.devDeviceId` - UUID v4
- `telemetry.sqmId` - UUID v4
- `telemetry.sessionId` - UUID v4
- `telemetry.instanceId` - UUID v4
- 时间戳字段更新为当前时间

## 备份和恢复

### 自动备份
- 在任何修改前创建
- 带时间戳的文件名便于识别
- SHA256哈希验证完整性
- 元数据文件跟踪原始位置

### 备份管理
```powershell
# 查看备份统计
Show-BackupStatistics

# 清理旧备份 (保留最近10个，最多30天)
Clear-OldBackups

# 手动创建备份
New-FileBackup -FilePath "path\to\file" -Description "手动备份"
```

### 恢复
```powershell
# 从备份恢复
$backups = Get-BackupFiles
$latestBackup = $backups | Sort-Object CreatedDate -Descending | Select-Object -First 1
Restore-FileBackup -BackupInfo $latestBackup -Force
```

## 支持的VS Code安装

### 标准位置
- 用户安装: `%LOCALAPPDATA%\Programs\Microsoft VS Code`
- 系统安装: `%ProgramFiles%\Microsoft VS Code`
- Insiders版: `%LOCALAPPDATA%\Programs\Microsoft VS Code Insiders`

### 便携版安装
- 当前目录和子目录
- 常见的便携应用目录
- 具有`data`文件夹结构的自定义位置

### 数据位置
- AppData: `%APPDATA%\Code` 或 `%APPDATA%\Code - Insiders`
- 便携版: 相对于安装目录的 `.\data\user-data`

## 安全特性

### 加密安全的随机生成
- 使用 `System.Security.Cryptography.RandomNumberGenerator`
- 正确的UUID v4生成，包含正确的版本和变体位
- 机器ID的安全十六进制字符串生成

### 文件完整性
- 所有备份的SHA256哈希验证
- 文件大小验证
- 尽可能使用原子操作

## 日志记录

### 日志级别
- **Debug**: 详细的操作信息
- **Info**: 一般信息消息
- **Warning**: 非关键问题
- **Error**: 操作失败
- **Critical**: 系统级失败

### 日志位置
- 默认: `logs\vscode-cleanup-YYYYMMDD-HHMMSS.log`
- 自定义: 使用 `-LogFile` 参数指定
- 带颜色编码的控制台输出

## 故障排除

### 常见问题

**"SQLite3 command not found"**
```powershell
# 使用Chocolatey安装
choco install sqlite

# 或使用Scoop
scoop install sqlite

# 或使用winget
winget install sqlite
```

**"执行策略阻止脚本执行"**
```powershell
# 为当前用户设置执行策略
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**"访问被拒绝"错误**
- 以管理员身份运行PowerShell
- 确保VS Code完全关闭
- 检查文件权限

### 调试模式
```powershell
# 启用详细日志进行故障排除
.\vscode-cleanup-master.ps1 -All -Verbose

# 检查系统信息
Show-SystemInformation

# 测试系统兼容性
Test-SystemCompatibility
```

## 模块架构

### 核心模块
- **Logger.psm1**: 统一日志记录和进度报告
- **SystemDetection.psm1**: 系统兼容性和要求检查
- **VSCodeDiscovery.psm1**: VS Code安装检测
- **BackupManager.psm1**: 备份创建、验证和恢复
- **DatabaseCleaner.psm1**: SQLite数据库清理操作
- **TelemetryModifier.psm1**: 安全遥测ID生成和修改

### 集成
所有模块都设计为无缝协作，同时保持独立性以便测试和维护。

## 贡献

### 开发设置
1. 克隆仓库
2. 安装所需依赖
3. 运行测试验证功能
4. 遵循PowerShell最佳实践

### 测试
```powershell
# 测试单个模块
Import-Module .\modules\Logger.psm1
Test-ModuleFunctionality

# 测试系统兼容性
Test-SystemCompatibility -Verbose

# 预览操作
.\vscode-cleanup-master.ps1 -Preview -All
```

## 许可证

本项目是Augment VIP套件的一部分，遵循项目的许可证条款。

## 支持

如有问题、疑问或贡献，请参考项目文档或联系开发团队。

## 📚 文档

- **[完整用户指南](USER_GUIDE.md)** - 详细的使用说明和API参考
- **[快速参考](QUICK_REFERENCE.md)** - 命令速查和常用操作
- **[致谢文档](CREDITS.md)** - 原作者致谢和项目贡献

---

**⚠️ 重要提示**: 在运行清理操作之前，请务必确保VS Code完全关闭。虽然会自动创建备份，但建议在运行脚本之前手动备份重要的工作区设置。
