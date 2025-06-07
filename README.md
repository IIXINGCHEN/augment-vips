# VS Code Cleanup Master Script

A comprehensive PowerShell solution for cleaning VS Code data and modifying telemetry identifiers with full backup and recovery capabilities.

## 🙏 致谢 / Acknowledgments

本项目基于 [azrilaiman2003/augment-vip](https://github.com/azrilaiman2003/augment-vip) 进行二次开发和优化。

**感谢原作者的贡献！** 我们在原项目基础上进行了以下重大改进：
- ✅ **Windows系统完整支持** - 专门为Windows 10+系统优化
- ✅ **PowerShell模块化架构** - 企业级代码结构
- ✅ **完整的备份恢复系统** - 安全可靠的操作保障
- ✅ **多VS Code版本支持** - 标准版、Insiders版、便携版
- ✅ **企业级安全特性** - SQL注入防护、加密安全随机数生成
- ✅ **完整的文档系统** - 详细的使用指南和API文档

This project is based on [azrilaiman2003/augment-vip](https://github.com/azrilaiman2003/augment-vip) with significant enhancements and optimizations.

**Thanks to the original author!** We have made the following major improvements:
- ✅ **Complete Windows Support** - Optimized for Windows 10+ systems
- ✅ **PowerShell Modular Architecture** - Enterprise-grade code structure
- ✅ **Full Backup & Recovery System** - Safe and reliable operation guarantee
- ✅ **Multi VS Code Version Support** - Standard, Insiders, and Portable editions
- ✅ **Enterprise Security Features** - SQL injection protection, cryptographically secure random generation
- ✅ **Complete Documentation System** - Detailed user guides and API documentation

## Features

- **Database Cleaning**: Remove all Augment-related entries from VS Code SQLite databases
- **Telemetry Modification**: Generate new secure random telemetry IDs (machineId, deviceId, sqmId)
- **Automatic Backup**: Create backups before any modifications with integrity verification
- **Multi-Installation Support**: Detect and process standard, Insiders, and portable VS Code installations
- **Context7 Framework Compatible**: Specifically designed to work with Context7 framework
- **Rollback Capability**: Restore from backups if needed
- **System Compatibility**: Windows 10+ with PowerShell 5.1+

## System Requirements

### Minimum Requirements
- **Operating System**: Windows 10 or higher
- **PowerShell**: Version 5.1 or higher
- **Dependencies**: SQLite3, curl, jq (automatically checked)
- **Disk Space**: At least 1GB free space for backup operations

### Recommended
- Administrator privileges for full functionality
- PowerShell execution policy set to RemoteSigned or Unrestricted

## Installation

### Quick Install
```powershell
# Download and run the installation script
.\install.ps1 --master --all
```

### Manual Installation
1. Clone or download the repository
2. Navigate to the scripts directory
3. Run the installation script with desired options

## Usage

### Master Script (Recommended)
```powershell
# Clean databases and modify telemetry IDs
.\vscode-cleanup-master.ps1 -All

# Preview operations without executing
.\vscode-cleanup-master.ps1 -Preview -All

# Clean databases only
.\vscode-cleanup-master.ps1 -Clean

# Modify telemetry IDs only
.\vscode-cleanup-master.ps1 -ModifyTelemetry

# Skip backup creation
.\vscode-cleanup-master.ps1 -All -NoBackup

# Include portable installations
.\vscode-cleanup-master.ps1 -All -IncludePortable

# Enable verbose logging
.\vscode-cleanup-master.ps1 -All -Verbose

# Show what would be done without executing
.\vscode-cleanup-master.ps1 -All -WhatIf
```

### Installation Script Options
```powershell
# Use new master script (recommended)
.\install.ps1 --master --all

# Preview operations
.\install.ps1 --master --preview

# Traditional individual scripts
.\install.ps1 --clean
.\install.ps1 --modify-ids
.\install.ps1 --all
```

## Command Line Options

### Master Script Parameters
| Parameter | Description |
|-----------|-------------|
| `-Clean` | Clean Augment-related database entries |
| `-ModifyTelemetry` | Modify VS Code telemetry IDs |
| `-All` | Perform all operations |
| `-Preview` | Show preview without making changes |
| `-Backup` | Create backups (default: true) |
| `-NoBackup` | Skip backup creation |
| `-IncludePortable` | Include portable VS Code installations |
| `-LogFile <path>` | Specify custom log file path |
| `-Verbose` | Enable verbose logging |
| `-WhatIf` | Show what would be done without executing |
| `-Help` | Show help information |

## What Gets Cleaned

### Database Entries
- All entries containing "augment", "Augment", or "AUGMENT"
- Context7 framework related entries
- Extension-related entries for Augment VIP
- Telemetry and session data (optional)

### Telemetry IDs Modified
- `telemetry.machineId` - 64-character hex string
- `telemetry.devDeviceId` - UUID v4
- `telemetry.sqmId` - UUID v4
- `telemetry.sessionId` - UUID v4
- `telemetry.instanceId` - UUID v4
- Timestamp fields updated to current time

## Backup and Recovery

### Automatic Backups
- Created before any modification
- Timestamped filenames for easy identification
- SHA256 hash verification for integrity
- Metadata files for tracking original locations

### Backup Management
```powershell
# View backup statistics
Show-BackupStatistics

# Clean old backups (keeps 10 most recent, max 30 days)
Clear-OldBackups

# Manual backup creation
New-FileBackup -FilePath "path\to\file" -Description "Manual backup"
```

### Recovery
```powershell
# Restore from backup
$backups = Get-BackupFiles
$latestBackup = $backups | Sort-Object CreatedDate -Descending | Select-Object -First 1
Restore-FileBackup -BackupInfo $latestBackup -Force
```

## Supported VS Code Installations

### Standard Locations
- User installation: `%LOCALAPPDATA%\Programs\Microsoft VS Code`
- System installation: `%ProgramFiles%\Microsoft VS Code`
- Insiders: `%LOCALAPPDATA%\Programs\Microsoft VS Code Insiders`

### Portable Installations
- Current directory and subdirectories
- Common portable app directories
- Custom locations with `data` folder structure

### Data Locations
- AppData: `%APPDATA%\Code` or `%APPDATA%\Code - Insiders`
- Portable: `.\data\user-data` relative to installation

## Security Features

### Cryptographically Secure Random Generation
- Uses `System.Security.Cryptography.RandomNumberGenerator`
- Proper UUID v4 generation with correct version and variant bits
- Secure hex string generation for machine IDs

### File Integrity
- SHA256 hash verification for all backups
- File size validation
- Atomic operations where possible

## Logging

### Log Levels
- **Debug**: Detailed operation information
- **Info**: General information messages
- **Warning**: Non-critical issues
- **Error**: Operation failures
- **Critical**: System-level failures

### Log Locations
- Default: `logs\vscode-cleanup-YYYYMMDD-HHMMSS.log`
- Custom: Specify with `-LogFile` parameter
- Console output with color coding

## Troubleshooting

### Common Issues

**"SQLite3 command not found"**
```powershell
# Install using Chocolatey
choco install sqlite

# Or using Scoop
scoop install sqlite

# Or using winget
winget install sqlite
```

**"Execution policy prevents script execution"**
```powershell
# Set execution policy for current user
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**"Access denied" errors**
- Run PowerShell as Administrator
- Ensure VS Code is completely closed
- Check file permissions

### Debug Mode
```powershell
# Enable verbose logging for troubleshooting
.\vscode-cleanup-master.ps1 -All -Verbose

# Check system information
Show-SystemInformation

# Test system compatibility
Test-SystemCompatibility
```

## Module Architecture

### Core Modules
- **Logger.psm1**: Unified logging and progress reporting
- **SystemDetection.psm1**: System compatibility and requirements checking
- **VSCodeDiscovery.psm1**: VS Code installation detection
- **BackupManager.psm1**: Backup creation, verification, and restoration
- **DatabaseCleaner.psm1**: SQLite database cleaning operations
- **TelemetryModifier.psm1**: Secure telemetry ID generation and modification

### Integration
All modules are designed to work together seamlessly while maintaining independence for testing and maintenance.

## Contributing

### Development Setup
1. Clone the repository
2. Install required dependencies
3. Run tests to verify functionality
4. Follow PowerShell best practices

### Testing
```powershell
# Test individual modules
Import-Module .\modules\Logger.psm1
Test-ModuleFunctionality

# Test system compatibility
Test-SystemCompatibility -Verbose

# Preview operations
.\vscode-cleanup-master.ps1 -Preview -All
```

## License

This project is part of the Augment VIP suite and follows the project's licensing terms.

## Support

For issues, questions, or contributions, please refer to the project documentation or contact the development team.

---

**⚠️ Important**: Always ensure VS Code is completely closed before running cleanup operations. While backups are created automatically, it's recommended to manually backup important workspace settings before running the script.
