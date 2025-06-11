# Augment VIP Cleaner - 专业的VS Code数据清理与隐私保护工具

一个专为清理VS Code中Augment相关数据而设计的企业级工具，提供数据库清理、遥测标识符修改、完整备份恢复等功能。基于原项目augment-vip进行Windows系统优化，具备PowerShell模块化架构和企业级安全特性。

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

- **智能依赖管理**: 自动检测和安装必需依赖（sqlite3, curl, jq），已安装的跳过，缺失的自动安装
- **数据库清理**: 移除VS Code SQLite数据库中的所有相关条目
- **遥测修改**: 生成新的安全随机遥测ID (machineId, deviceId, sqmId)
- **自动备份**: 在任何修改前创建备份，具备完整性验证
- **多安装支持**: 检测并处理标准版、Insiders版和便携版VS Code安装
- **回滚功能**: 需要时可从备份恢复
- **系统兼容**: Windows 10+ 配合 PowerShell 5.1+

## 🌍 跨平台系统要求

### 支持的操作系统
- **Windows**: PowerShell 5.1+ (主要) 或 Python 3.6+ (备用)
- **Linux**: Python 3.6+ 和 bash
- **macOS**: Python 3.6+ 和 bash

### 通用要求
- **磁盘空间**: 至少1GB可用空间用于备份操作
- **权限**: 建议使用管理员/sudo权限

### Windows特定要求
- PowerShell执行策略设置为RemoteSigned或Unrestricted
- SQLite3, curl, jq (智能自动安装 - 已安装的跳过，缺失的自动安装)

### Linux/macOS特定要求
- Python 3.6或更高版本
- python3-venv (虚拟环境支持)
- 基本的系统工具 (bash, chmod等)

### ⚠️ 重要安全提醒
**使用前必读**：本工具会修改VS Code的数据库和配置文件，存在一定风险。请务必：
- 📋 **阅读免责声明** - 详细了解使用风险，请参阅 [免责声明](DISCLAIMER.md)
- 💾 **备份重要数据** - 使用前备份VS Code配置和重要项目
- 🧪 **测试环境验证** - 建议先在测试环境中验证功能
- ⚖️ **自行承担风险** - 用户完全自行承担使用风险

### ⚠️ 重要：PowerShell执行策略设置
Windows系统默认阻止运行未签名的PowerShell脚本。在运行本项目脚本前，您需要设置执行策略：

```powershell
# 推荐方案：为当前用户设置执行策略（安全）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 验证设置
Get-ExecutionPolicy -List
```

**如果仍然遇到执行策略错误，可以使用以下临时解决方案：**
```powershell
# 方案1：临时绕过执行策略
PowerShell -ExecutionPolicy Bypass -File .\install.ps1 -Operation All

# 方案2：解除文件阻止
Unblock-File .\install.ps1
Unblock-File .\run.ps1
Unblock-File .\scripts\augment-vip-launcher.ps1
Unblock-File .\scripts\windows\vscode-cleanup-master.ps1
```

## 🚀 跨平台安装指南

### 一键安装 (推荐)
```bash
# 通用安装脚本 - 自动检测平台
./install.sh --all

# 预览操作
./install.sh --preview

# 仅清理数据库
./install.sh --clean

# 仅修改遥测ID
./install.sh --modify-ids
```

### Windows安装
```powershell
# 1. 设置PowerShell执行策略（首次运行必需）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 2. 使用快速启动脚本（推荐）
.\run.ps1 -Operation All

# 3. 或使用跨平台启动器
.\scripts\augment-vip-launcher.ps1 -Operation All

# 4. 或强制使用Python实现
.\install.sh --python-only --all
```

### Linux/macOS安装
```bash
# 使用通用安装脚本（推荐）
./install.sh --all

# 或直接使用Linux脚本
./scripts/linux/install.sh --all
```

### 手动安装
1. 克隆或下载仓库
2. 导航到项目根目录
3. 根据平台选择合适的安装方式

## 使用方法

### 主脚本 (推荐)
```powershell
# 使用快速启动脚本（推荐）
.\run.ps1 -Operation All

# 预览操作而不执行
.\run.ps1 -Operation Preview

# 仅清理数据库
.\run.ps1 -Operation Clean

# 仅修改遥测ID
.\run.ps1 -Operation ModifyTelemetry

# 直接使用Windows脚本（高级用法）
.\scripts\windows\vscode-cleanup-master.ps1 -All

# 跳过备份创建
.\scripts\windows\vscode-cleanup-master.ps1 -All -NoBackup

# 启用详细日志
.\scripts\windows\vscode-cleanup-master.ps1 -All -Verbose

# 显示将要执行的操作而不实际执行
.\scripts\windows\vscode-cleanup-master.ps1 -All -WhatIf
```

### 安装脚本选项
```powershell
# 使用快速启动脚本（推荐）
.\run.ps1 -Operation All

# 预览操作
.\run.ps1 -Operation Preview

# 使用跨平台启动器
.\scripts\augment-vip-launcher.ps1 -Operation All

# 远程安装和执行（智能依赖管理）
irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex

# 带智能依赖自动安装（推荐）
irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vip/main/install.ps1 | iex -AutoInstallDependencies
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
| `-AutoInstallDependencies` | 自动安装缺失的依赖（智能跳过已安装的） |
| `-SkipDependencyInstall` | 跳过依赖安装检查 |
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
# 🎯 新功能：智能自动安装（推荐）
.\scripts\augment-vip-launcher.ps1 -Operation Preview -AutoInstallDependencies

# 手动安装方式：
# 使用Chocolatey安装
choco install sqlite

# 或使用Scoop
scoop install sqlite

# 或使用winget
winget install sqlite
```

**智能依赖管理说明**：
- ✅ **自动检测**：系统会自动检测 sqlite3、curl、jq 的安装状态
- ✅ **智能跳过**：已安装的依赖会被自动跳过，不会重复安装
- ✅ **自动安装**：只安装缺失的依赖，支持多种包管理器
- ✅ **包管理器支持**：优先使用 Chocolatey，备选 Scoop 和 Winget
- ✅ **自动回退**：如果没有包管理器，会自动安装 Chocolatey

**"执行策略阻止脚本执行"**
```powershell
# 推荐方案：为当前用户设置执行策略（永久）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 临时方案：绕过执行策略运行单个脚本
PowerShell -ExecutionPolicy Bypass -File .\run.ps1 -Operation All

# 解除文件阻止（如果文件来自网络下载）
Unblock-File .\*.ps1
Unblock-File .\scripts\*.ps1
Unblock-File .\scripts\windows\*.ps1

# 验证当前执行策略设置
Get-ExecutionPolicy -List
```

**执行策略说明：**
- `Restricted`（默认）：不允许运行任何脚本
- `RemoteSigned`（推荐）：允许本地脚本，远程脚本需要签名
- `Unrestricted`：允许所有脚本（不推荐）
- `Bypass`：临时绕过所有限制

**"访问被拒绝"错误**
- 以管理员身份运行PowerShell
- 确保VS Code完全关闭
- 检查文件权限

### 调试模式
```powershell
# 启用详细日志进行故障排除
.\run.ps1 -Operation All -VerboseOutput

# 或直接使用Windows脚本
.\scripts\windows\vscode-cleanup-master.ps1 -All -Verbose

# 检查系统信息 (需要先导入模块)
Import-Module .\scripts\windows\modules\SystemDetection.psm1 -Force
Show-SystemInformation

# 测试系统兼容性
Test-SystemCompatibility
```

## 模块架构

### 核心模块
- **Logger.psm1**: 统一日志记录和进度报告
- **DependencyManager.psm1**: 智能依赖检测和自动安装管理
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
Import-Module .\scripts\windows\modules\Logger.psm1 -Force
Test-ModuleFunctionality

# 测试系统兼容性
Import-Module .\scripts\windows\modules\SystemDetection.psm1 -Force
Test-SystemCompatibility -Verbose

# 预览操作
.\run.ps1 -Operation Preview

# 或直接使用Windows脚本
.\scripts\windows\vscode-cleanup-master.ps1 -Preview -All
```

## 📄 许可证

本项目基于 [azrilaiman2003/augment-vip](https://github.com/azrilaiman2003/augment-vip) 进行开发，遵循 **MIT License**。

### 许可证信息
- **原始项目**: MIT License © 2024 azrilaiman2003
- **Windows增强版**: MIT License © 2024 IIXINGCHEN
- **许可证文件**: [LICENSE](LICENSE)

### 使用条款
本软件按"原样"提供，不提供任何明示或暗示的保证。详细条款请参阅 [LICENSE](LICENSE) 文件。

### 致谢要求
使用本项目时，请保留对原作者 azrilaiman2003 和Augment VIP Cleaner项目  作者的适当致谢。

## 支持

如有问题、疑问或贡献，请参考项目文档或联系开发团队。

## 📚 文档

- **[完整用户指南](USER_GUIDE.md)** - 详细的使用说明、快速参考和API文档
- **[故障排除指南](TROUBLESHOOTING.md)** - 高级问题诊断和解决方案
- **[致谢文档](CREDITS.md)** - 原作者致谢和项目贡献
- **[免责声明](DISCLAIMER.md)** - 重要的使用风险和法律声明

---

**⚠️ 重要提示**:
1. **首次使用必读**：Windows系统默认阻止PowerShell脚本运行，请先设置执行策略：`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
2. **运行前准备**：确保VS Code完全关闭后再运行清理操作
3. **安全备份**：虽然会自动创建备份，但建议手动备份重要的工作区设置
4. **遇到问题**：请参考 [故障排除指南](TROUBLESHOOTING.md) 获取详细解决方案
