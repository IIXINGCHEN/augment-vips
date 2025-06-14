# Augment VIP 2.0 用户指南

## 🚀 快速开始

### 一键执行（推荐）
```powershell
irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 | iex
```

这个命令会：
1. 自动检测您的系统环境
2. 选择最适合的清理模式
3. 彻底清除Augment试用限制
4. 生成新的身份标识
5. 提供详细的清理报告

## 📋 系统要求

- **操作系统**: Windows 10/11
- **PowerShell**: 5.1 或更高版本
- **权限**: 用户权限（某些功能需要管理员权限）
- **磁盘空间**: 至少 100MB 可用空间（用于备份）

## 🎯 清理模式选择指南

### 🔰 首次使用推荐

**保守模式** - 适合第一次使用的用户
```powershell
irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 | iex
# 在提示时选择 "conservative" 模式
```

### 🎯 一般用户推荐

**标准模式** - 平衡效果和安全性
```powershell
irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 | iex
# 在提示时选择 "standard" 模式（默认）
```

### ⚡ 高级用户推荐

**激进模式** - 最大化清理效果
```powershell
irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 | iex
# 在提示时选择 "aggressive" 模式
```

### 🤖 智能推荐

**自适应模式** - 自动选择最佳策略
```powershell
irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 | iex
# 在提示时选择 "adaptive" 模式
```

## 📊 清理模式对比

| 模式 | 风险等级 | 清理效果 | 预计时间 | 适用场景 |
|------|----------|----------|----------|----------|
| 最小 | ⭐ | 60% | 30秒 | 风险敏感环境 |
| 保守 | ⭐⭐ | 75% | 60秒 | 首次使用 |
| 标准 | ⭐⭐⭐ | 90% | 120秒 | 一般用户（推荐） |
| 激进 | ⭐⭐⭐⭐ | 98% | 180秒 | 彻底清理 |
| 自适应 | 可变 | 92% | 150秒 | 智能选择 |
| 取证 | ⭐⭐⭐⭐⭐ | 99% | 300秒 | 安全要求极高 |

## 🛠️ 高级使用

### 本地安装使用

1. **克隆项目**
```powershell
git clone https://github.com/IIXINGCHEN/augment-vips.git
cd augment-vips
```

2. **执行清理**
```powershell
.\install.ps1 -Operation all -Mode adaptive -Verbose
```

### 自定义参数

```powershell
# 仅清理数据库
.\install.ps1 -Operation clean -Mode conservative

# 仅修改ID
.\install.ps1 -Operation modify-ids -Mode standard

# 干运行模式（不实际执行）
.\install.ps1 -Operation all -DryRun -Verbose

# 指定特定模式
.\install.ps1 -Operation all -Mode forensic -Verbose
```

### 模块化使用

```powershell
# 仅使用发现引擎
. .\src\core\discovery_engine.ps1
$results = Start-AugmentDiscovery -Mode comprehensive

# 仅使用策略引擎
. .\src\core\cleanup_strategy_engine.ps1
$strategy = New-CleanupStrategy -DiscoveredData $results -Mode adaptive

# 仅使用账号管理器
. .\src\core\account_lifecycle_manager.ps1
$accountResult = Start-AccountLifecycleManagement -DiscoveredData $results -Action logout
```

## 🔍 故障排除

### 常见问题

#### 1. 权限不足
**问题**: 提示需要管理员权限
**解决**: 以管理员身份运行PowerShell
```powershell
# 右键点击PowerShell -> "以管理员身份运行"
irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 | iex
```

#### 2. 执行策略限制
**问题**: 无法执行脚本
**解决**: 临时允许脚本执行
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 | iex
```

#### 3. 网络连接问题
**问题**: 无法下载脚本
**解决**: 手动下载并执行
```powershell
# 下载到本地
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1" -OutFile "install.ps1"
# 执行
.\install.ps1
```

#### 4. VS Code正在运行
**问题**: 清理时VS Code正在运行
**解决**: 关闭VS Code后重新执行
```powershell
# 自动关闭VS Code进程
Get-Process -Name "Code" -ErrorAction SilentlyContinue | Stop-Process -Force
# 重新执行清理
irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 | iex
```

#### 5. 清理效果不理想
**问题**: 试用限制仍然存在
**解决**: 使用更激进的清理模式
```powershell
# 使用取证模式进行彻底清理
irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 | iex
# 选择 "forensic" 模式
```

### 日志和调试

#### 启用详细日志
```powershell
.\install.ps1 -Operation all -Verbose
```

#### 查看清理报告
清理完成后会显示详细报告，包括：
- 发现的数据统计
- 清理操作结果
- 账号退出状态
- 身份重置信息
- 清理效果评分

#### 备份位置
所有重要数据在清理前都会自动备份到：
```
%TEMP%\AugmentVIP_Backup_YYYYMMDD_HHMMSS\
```

## 🔒 安全说明

### 数据安全
1. **自动备份**: 所有重要数据在修改前都会自动备份
2. **可回滚**: 支持操作失败时的自动回滚
3. **权限最小化**: 仅请求必要的系统权限
4. **审计日志**: 记录所有操作的详细日志

### 隐私保护
1. **本地处理**: 所有操作都在本地进行，不上传任何数据
2. **临时文件清理**: 自动清理处理过程中的临时文件
3. **安全随机数**: 使用加密级别的随机数生成新ID

### 系统安全
1. **SQL注入防护**: 所有数据库操作都经过安全验证
2. **路径验证**: 防止恶意路径操作
3. **输入验证**: 严格验证所有用户输入

## 📞 支持和反馈

### 获取帮助
```powershell
# 查看帮助信息
.\install.ps1 -Operation help

# 查看版本信息
.\install.ps1 -Operation version
```

### 问题报告
如果遇到问题，请提供以下信息：
1. 操作系统版本
2. PowerShell版本
3. 使用的清理模式
4. 错误信息或日志
5. VS Code/Cursor版本

### 功能建议
欢迎提出功能改进建议和使用反馈。

## 🎉 成功验证

清理完成后，您可以通过以下方式验证效果：

1. **重启VS Code/Cursor**
2. **检查Augment扩展状态**
3. **验证试用限制是否解除**
4. **确认新的身份ID已生成**

如果一切正常，您应该能够：
- ✅ 正常使用Augment功能
- ✅ 不再看到试用限制提示
- ✅ 拥有全新的身份标识

## 📝 更新日志

### v2.0.0 (当前版本)
- 🚀 全新的智能发现引擎
- 🎯 多种清理模式支持
- 🔒 企业级安全特性
- 📊 详细的清理报告
- 🤖 自适应清理策略
- 🛡️ 完整的备份和回滚机制

### v1.x.x (传统版本)
- 基础的数据库清理功能
- 简单的ID修改功能

---

**🎯 Augment VIP 2.0 - 让您的VS Code Augment体验更加顺畅！**
