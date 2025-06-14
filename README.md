# Augment VIP - Enterprise Cross-Platform VS Code Cleaner

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/IIXINGCHEN/augment-vips)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)](https://github.com/IIXINGCHEN/augment-vips)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Security](https://img.shields.io/badge/security-enterprise%20grade-red.svg)](https://github.com/IIXINGCHEN/augment-vips)
[![Config](https://img.shields.io/badge/config-unified%20system-orange.svg)](https://github.com/IIXINGCHEN/augment-vips)

Enterprise-grade cross-platform tool for cleaning VS Code Augment data, resolving trial account limit issues, and modifying telemetry IDs. Built with unified configuration system, zero-redundancy architecture, comprehensive security controls, and production-ready reliability.

## 🚀 Quick Start

### 🔥 Trial Account Issue? Fix in 30 seconds!

If you're seeing **"trial account limit exceeded"** errors with Augment:

```powershell
# Windows - One command fix (uses unified configuration):
irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 | iex

# Linux/macOS - Two command fix (with unified configuration):
curl -fsSL https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 -o install.ps1
pwsh install.ps1 -Operation clean
```

**That's it!** Your trial account data will be cleaned using our unified configuration system and you can use Augment again.

### ✨ New in v2.0.0: Unified Configuration System

All data patterns and formats are now centrally managed for 100% consistency across all platforms and modules.

### One-Line Installation

**Windows (PowerShell)**
```powershell
# One-line remote execution (cleans trial account data)
irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 | iex

# Or download and run locally for more control:
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1" -OutFile "install.ps1"
.\install.ps1 -Operation clean -Verbose
```

**Linux/macOS (PowerShell Core)**
```bash
# Install PowerShell Core first (if not installed):
# Ubuntu/Debian: sudo apt install powershell
# macOS: brew install powershell

# Download and run
curl -fsSL https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 -o install.ps1
pwsh install.ps1 -Operation clean -Verbose
```

### Manual Installation

```bash
# Clone repository
git clone https://github.com/IIXINGCHEN/augment-vips.git
cd augment-vips

# Windows PowerShell
.\install.ps1 -Operation clean -Verbose

# Linux/macOS (requires PowerShell Core)
pwsh install.ps1 -Operation clean -Verbose

# Preview changes first (dry run)
.\install.ps1 -Operation clean -DryRun
```

## 📋 Features

### Core Functionality
- **Trial Account Fix**: Resolve "trial account limit exceeded" issues by cleaning trial data
- **Database Cleaning**: Remove Augment-related entries from VS Code databases using 87 unified patterns
- **Smart Detection**: Advanced pattern matching for trial-related data cleanup
- **Telemetry Modification**: Generate new machine IDs, device IDs, and SQM IDs with enhanced entropy
- **Cross-Platform Support**: Windows (PowerShell), Linux/macOS (PowerShell Core)
- **Automatic Discovery**: Find VS Code installations and data files automatically
- **Unified Configuration**: Central configuration management for 100% data format consistency

### Trial Account Issues Solved
- **Context7 Data**: Removes trial context data that causes account limits
- **Augment Plugin Data**: Cleans Augment extension configuration and state
- **Chat View State**: Removes chat interface state data
- **Panel State**: Cleans workbench panel state information
- **License Check Data**: Removes license validation entries

### Enterprise Features
- **Unified Configuration System**: Central JSON-based configuration with automatic loading and validation
- **Zero-Redundancy Architecture**: Shared core modules, platform-specific implementations
- **Configuration-Driven Operations**: All data patterns loaded from unified configuration files
- **Comprehensive Security**: Enhanced input validation, audit logging, backup creation
- **Production Ready**: Error handling, monitoring, performance optimization, fallback mechanisms
- **Modular Design**: Extensible architecture with clear separation of concerns
- **Cross-Platform Consistency**: 100% identical behavior across Windows, Linux, and macOS

### Security & Compliance
- **Audit Logging**: Complete operation tracking for compliance
- **Automatic Backups**: Safe operations with rollback capability
- **Input Validation**: Comprehensive sanitization and security checks
- **Access Controls**: Configurable security policies and restrictions

## 🏗️ Architecture

```
augment-vips/
├── install.ps1               # Main PowerShell installer (Windows/Cross-platform)
├── install                   # Cross-platform entry point (planned)
├── README.md                 # This documentation
├── src/                      # All source code organized under src/
│   ├── config/               # 🆕 Unified Configuration System
│   │   ├── augment_patterns.json    # 🆕 Central data patterns (87 patterns)
│   │   ├── cleanup_modes.json       # Cleanup operation modes
│   │   ├── settings.json            # Main configuration
│   │   └── security.json            # Security policies
│   ├── core/                 # Zero-redundancy shared modules
│   │   ├── config_loader.sh         # 🆕 Bash configuration loader
│   │   ├── ConfigLoader.ps1         # 🆕 PowerShell configuration loader
│   │   ├── common.sh                # Common functions and utilities
│   │   ├── platform.sh              # Platform detection and adaptation
│   │   ├── security.sh              # Security validation and controls
│   │   ├── validation.sh            # Input validation and sanitization
│   │   ├── dependencies.sh          # Dependency management
│   │   ├── paths.sh                 # Cross-platform path resolution
│   │   ├── database.sh              # 🔄 SQLite operations (config-driven)
│   │   ├── backup.sh                # Backup and recovery
│   │   ├── logging.sh               # Enterprise logging system
│   │   ├── migration.sh             # Migration operations
│   │   ├── telemetry.sh             # 🔄 Telemetry ID management (config-driven)
│   │   ├── account_lifecycle_manager.ps1  # 🔄 Account management (config-driven)
│   │   └── [other modules]          # Additional core modules
│   ├── platforms/            # Platform-specific implementations
│   │   ├── windows.ps1              # 🔄 Windows PowerShell (config-driven)
│   │   ├── linux.sh                 # Linux Bash implementation
│   │   └── macos.sh                 # macOS Bash implementation
│   ├── controllers/          # Main control scripts
│   │   └── master_migration_controller.sh      # Enterprise migration controller
│   ├── analyzers/            # Analysis and diagnostic tools
│   │   ├── advanced_augment_analyzer.ps1       # Advanced PowerShell analyzer
│   │   ├── advanced_augment_analyzer.sh        # Advanced Bash analyzer
│   │   ├── augment_config_analyzer.sh          # Configuration analyzer
│   │   └── data_integrity_validator.ps1        # Data integrity validator
├── logs/                     # Runtime logs and reports
└── docs/                     # Documentation (planned)

🆕 = New in v2.0.0    🔄 = Updated for unified configuration
```

## 🖥️ Platform Support

### Windows (Primary Platform)
- **Requirements**: Windows 10+, PowerShell 5.1+
- **Package Manager**: Chocolatey (auto-installable)
- **Dependencies**: sqlite3, curl, jq (auto-installed via Chocolatey)
- **Remote Installation**: Supports `irm | iex` for one-line installation
- **Execution Policy**: May require `Set-ExecutionPolicy RemoteSigned` or `-ExecutionPolicy Bypass`
- **Status**: ✅ Fully implemented and tested

### Linux (PowerShell Core)
- **Requirements**: Modern Linux distribution, PowerShell Core 7.0+
- **Installation**: `sudo apt install powershell` (Ubuntu/Debian) or equivalent
- **Dependencies**: sqlite3, curl, jq (auto-installed)
- **Status**: ✅ Supported via PowerShell Core

### macOS (PowerShell Core)
- **Requirements**: macOS 10.12+, PowerShell Core 7.0+
- **Installation**: `brew install powershell`
- **Dependencies**: sqlite3, curl, jq (auto-installed via Homebrew)
- **Status**: ✅ Supported via PowerShell Core

## 📖 Usage

### Basic Operations (v2.0.0 with Unified Configuration)

**Cross-Platform (PowerShell Core)**
```bash
# Clean VS Code databases using unified configuration (87 patterns)
pwsh install.ps1 -Operation clean

# Perform comprehensive cleanup with unified configuration
pwsh install.ps1 -Operation all

# Dry run with configuration validation (preview changes)
pwsh install.ps1 -Operation clean -DryRun

# Verbose output with configuration loading details
pwsh install.ps1 -Operation clean -Verbose

# Force fallback mode (bypass unified configuration)
pwsh install.ps1 -Operation clean -UseFallback
```

**Windows (PowerShell)**
```powershell
# Clean VS Code databases using unified configuration (87 patterns)
.\install.ps1 -Operation clean

# Perform comprehensive cleanup with unified configuration
.\install.ps1 -Operation all

# Dry run with configuration validation (preview changes)
.\install.ps1 -Operation clean -DryRun

# Verbose output with configuration loading details
.\install.ps1 -Operation clean -Verbose

# Force fallback mode (bypass unified configuration)
.\install.ps1 -Operation clean -UseFallback
```

### Platform-Specific Usage

**Windows (PowerShell)**
```powershell
# Remote execution with parameters
& { $script = irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1; Invoke-Expression $script } -Operation clean -Verbose

# Local execution (after cloning)
.\install.ps1 -Operation clean -Verbose

# Use platform-specific script
.\src\platforms\windows.ps1 -Operation clean -Verbose
```

**Linux/macOS (PowerShell Core)**
```bash
# Remote execution
curl -fsSL https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 -o install.ps1
pwsh install.ps1 -Operation clean -Verbose

# Local execution (after cloning)
pwsh install.ps1 -Operation clean -Verbose

# Use platform-specific script (if available)
# Note: Currently only Windows PowerShell implementation is complete
```

### Advanced Configuration and Core Module Usage

**Using Core Modules Directly (v2.0.0)**
```bash
# Load and test unified configuration
source src/core/config_loader.sh
load_augment_config
echo "Loaded ${#AUGMENT_PATTERNS[@]} patterns"

# Use database module with unified configuration
source src/core/database.sh
init_database  # Automatically loads unified configuration
clean_vscode_database "/path/to/vscode/data" false  # false = not dry run

# Use telemetry module with unified configuration
source src/core/telemetry.sh
init_telemetry  # Automatically loads unified configuration
modify_storage_file "/path/to/storage.json" "new_machine_id" "new_device_id" "new_sqm_id"
```

**PowerShell Core Module Usage**
```powershell
# Load unified configuration
. "src\core\ConfigLoader.ps1"
Load-AugmentConfig

# Check loaded patterns
$patterns = Get-AugmentPatterns
Write-Host "Loaded $($patterns.Count) patterns"

# Get telemetry field mappings
$fields = Get-TelemetryFields
Write-Host "Machine ID field: $($fields.MachineId)"

# Generate SQL cleaning query from unified configuration
$sql = New-SqlCleaningQuery
Write-Host $sql
```

**Configuration File Management**
```bash
# Validate configuration file
jq empty src/config/augment_patterns.json && echo "Valid JSON" || echo "Invalid JSON"

# View configuration version
jq -r '.version' src/config/augment_patterns.json

# Count total patterns
jq '[.database_patterns | to_entries[] | .value[]] | length' src/config/augment_patterns.json

# View telemetry field mappings
jq '.telemetry_fields' src/config/augment_patterns.json
```

**Advanced Operations**
```powershell
# Windows: Run with specific parameters and configuration validation
.\install.ps1 -Operation clean -Verbose -DryRun

# Check configuration loading status
.\install.ps1 -Operation clean -DryRun -Verbose | Select-String "configuration"

# Test fallback mode
.\install.ps1 -Operation clean -UseFallback -Verbose
```

## ⚙️ Configuration (v2.0.0 Unified System)

### Unified Configuration Files

The tool now uses a comprehensive unified configuration system located in `src/config/` directory:

**Core Configuration Files:**
- `src/config/augment_patterns.json` - **🆕 Central data patterns** (87 cleaning patterns)
- `src/config/cleanup_modes.json` - Cleanup operation modes and strategies
- `src/config/settings.json` - Main application configuration
- `src/config/security.json` - Security policies and validation rules

### Configuration Structure

**augment_patterns.json** (Main configuration file):
```json
{
  "version": "2.0.0",
  "database_patterns": {
    "augment_core": ["pattern1", "pattern2", ...],
    "telemetry": ["pattern1", "pattern2", ...],
    "trial_data": ["pattern1", "pattern2", ...],
    "analytics": ["pattern1", "pattern2", ...],
    "ai_services": ["pattern1", "pattern2", ...],
    "authentication": ["pattern1", "pattern2", ...]
  },
  "telemetry_fields": {
    "machine_id": "telemetry.machineId",
    "device_id": "telemetry.devDeviceId",
    "sqm_id": "telemetry.sqmId"
  },
  "file_paths": {
    "storage_files": ["path1", "path2", ...],
    "token_paths": ["path1", "path2", ...],
    "session_paths": ["path1", "path2", ...]
  }
}
```

### Configuration Loading

**Automatic Loading:**
- All modules automatically load unified configuration on initialization
- Fallback to embedded patterns if configuration loading fails
- Configuration validation ensures data integrity

**Manual Configuration Management:**
```bash
# Validate configuration
jq empty src/config/augment_patterns.json

# View configuration version
jq -r '.version' src/config/augment_patterns.json

# Count patterns by category
jq '.database_patterns | to_entries[] | "\(.key): \(.value | length)"' src/config/augment_patterns.json

# Export configuration for backup
cp src/config/augment_patterns.json augment_patterns_backup_$(date +%Y%m%d).json
```

## 🔒 Security

### Security Features
- **Input Validation**: Comprehensive sanitization of all inputs
- **Path Validation**: Prevention of directory traversal attacks
- **Audit Logging**: Complete operation tracking
- **Backup Creation**: Automatic backups before modifications
- **Access Controls**: Configurable operation restrictions

### Security Best Practices
- Always run with minimal required privileges
- Review audit logs regularly
- Keep backups in secure locations
- Use dry-run mode for testing
- Validate configuration files

For detailed security information, see the project repository.

## 🆕 What's New in v2.0.0

### Unified Configuration System
- **Central Configuration**: All data patterns managed in `src/config/augment_patterns.json`
- **87 Cleaning Patterns**: Comprehensive pattern matching for all Augment-related data
- **Cross-Platform Consistency**: 100% identical behavior across Windows, Linux, and macOS
- **Configuration Validation**: Automatic validation and fallback mechanisms
- **Version Control**: Configuration versioning and update tracking

### Enhanced Security & Reliability
- **Configuration-Driven Operations**: All modules load patterns from unified configuration
- **Improved Error Handling**: Enhanced fallback mechanisms and error recovery
- **Audit Trail**: Detailed logging of configuration loading and pattern usage
- **Data Integrity**: Validation of configuration files and pattern consistency

### Developer Experience
- **Modular Configuration Loaders**: Separate loaders for Bash and PowerShell
- **Real-time Configuration**: Dynamic loading without code changes
- **Debugging Support**: Verbose logging of configuration loading process
- **Extensible Architecture**: Easy addition of new patterns and configurations

### Migration from v1.0.0
- **Automatic Fallback**: v1.0.0 patterns used if configuration loading fails
- **Backward Compatibility**: All existing commands continue to work
- **Enhanced Functionality**: Same commands now use unified configuration for better results

## 📊 Monitoring & Logging

### Log Files
- **Operation Logs**: `logs/augment-vip_YYYYMMDD_HHMMSS.log`
- **Audit Logs**: `logs/augment-vip_audit_YYYYMMDD_HHMMSS.log`
- **Error Logs**: `logs/augment-vip_errors.log`

### Reports
- **Operation Reports**: Detailed execution summaries
- **Dependency Reports**: System dependency status
- **Security Reports**: Security validation results
- **Performance Reports**: Execution metrics

## 🧪 Testing

### Testing (v2.0.0 Enhanced)

**Configuration Testing:**
```bash
# Test unified configuration loading
source src/core/config_loader.sh
load_augment_config && echo "✓ Configuration loaded successfully" || echo "✗ Configuration failed"

# Validate configuration file
jq empty src/config/augment_patterns.json && echo "✓ Valid JSON" || echo "✗ Invalid JSON"

# Test pattern count
echo "Total patterns: $(jq '[.database_patterns | to_entries[] | .value[]] | length' src/config/augment_patterns.json)"
```

**PowerShell Configuration Testing:**
```powershell
# Test PowerShell configuration loading
. "src\core\ConfigLoader.ps1"
if (Load-AugmentConfig) {
    Write-Host "✓ Configuration loaded successfully" -ForegroundColor Green
    $patterns = Get-AugmentPatterns
    Write-Host "✓ Loaded $($patterns.Count) patterns" -ForegroundColor Green
} else {
    Write-Host "✗ Configuration failed" -ForegroundColor Red
}
```

**Operational Testing:**
```powershell
# Test the tool with dry-run mode and configuration validation
.\install.ps1 -Operation clean -DryRun -Verbose

# Test with fallback mode
.\install.ps1 -Operation clean -DryRun -UseFallback -Verbose

# Verify trial account data detection with unified patterns
.\install.ps1 -Operation clean -DryRun | Select-String "pattern"

# Test configuration-driven SQL generation
.\install.ps1 -Operation clean -DryRun -Verbose | Select-String "unified configuration"
```

**Core Module Testing:**
```bash
# Test database module with unified configuration
source src/core/database.sh
init_database
echo "Database module initialized with ${#AUGMENT_PATTERNS[@]} patterns"

# Test telemetry module with unified configuration
source src/core/telemetry.sh
init_telemetry
echo "Telemetry fields: machine=${MACHINE_ID_FIELD}, device=${DEVICE_ID_FIELD}, sqm=${SQM_ID_FIELD}"
```

## 🚀 Deployment

### Production Deployment

1. **Download and Verify**

   **Windows (PowerShell)**
   ```powershell
   # Download installer
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1" -OutFile "install.ps1"
   # Verify and run
   .\install.ps1 -Operation clean -DryRun
   ```

   **Linux/macOS (PowerShell Core)**
   ```bash
   # Download installer
   curl -fsSL https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 -o install.ps1
   # Verify and run
   pwsh install.ps1 -Operation clean -DryRun
   ```

2. **Test in Staging**
   ```powershell
   # Perform dry run to preview changes
   .\install.ps1 -Operation clean -DryRun -Verbose
   ```

3. **Deploy to Production**
   ```powershell
   # Execute with monitoring
   .\install.ps1 -Operation clean -Verbose
   ```

**Note**: Detailed deployment documentation is planned for future releases.

## 🔧 Troubleshooting

### Common Issues

**VS Code Not Found**
```bash
# Ensure VS Code is installed and has been run at least once
# Check installation paths manually
```

**Permission Denied**
```bash
# Linux/macOS: Ensure appropriate file permissions
chmod +x install
```
```powershell
# Windows: Set execution policy or run as Administrator
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
# Or run with bypass: powershell -ExecutionPolicy Bypass -File install.ps1
```

**Dependencies Missing**
```powershell
# Windows: Dependencies auto-install via Chocolatey
# Manual installation if needed:
choco install sqlite curl jq
```
```bash
# Linux: Install via package manager
sudo apt install sqlite3 curl jq          # Ubuntu/Debian
sudo dnf install sqlite curl jq           # Fedora
sudo pacman -S sqlite curl jq             # Arch

# macOS: Install via Homebrew
brew install sqlite3 curl jq
```

**PowerShell Execution Policy (Windows)**
```powershell
# If remote execution fails, try:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or use bypass for one-time execution:
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 | iex"
```

**Trial Account Issues (v2.0.0 Enhanced)**
```powershell
# If you see "trial account limit exceeded" errors:
.\install.ps1 -Operation clean -Verbose

# This will clean trial-related data using 87 unified patterns from configuration
# Check if unified configuration is being used:
.\install.ps1 -Operation clean -DryRun -Verbose | Select-String "unified configuration"

# Force fallback mode if configuration issues occur:
.\install.ps1 -Operation clean -UseFallback -Verbose
```

**Configuration Issues (v2.0.0)**
```powershell
# If configuration loading fails:
# 1. Validate configuration file
jq empty src/config/augment_patterns.json

# 2. Check file permissions
Get-Acl src/config/augment_patterns.json

# 3. Use fallback mode
.\install.ps1 -Operation clean -UseFallback

# 4. Regenerate configuration (if corrupted)
# Backup current config and restore from repository
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow enterprise coding standards
- Add comprehensive tests for new features
- Update documentation for changes
- Ensure security compliance
- Test on all supported platforms

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/IIXINGCHEN/augment-vips/issues)
- **Documentation**: [Project Repository](https://github.com/IIXINGCHEN/augment-vips)
- **Security**: [GitHub Repository](https://github.com/IIXINGCHEN/augment-vips)

## 🏆 Acknowledgments

- VS Code team for the excellent editor
- Open source community for tools and libraries
- Security researchers for best practices
- Enterprise users for requirements and feedback

---

## 🔍 Quick Reference Commands

### Essential Commands (v2.0.0)
```powershell
# Quick trial account fix (Windows)
irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 | iex

# Local execution with unified configuration
.\install.ps1 -Operation clean -Verbose

# Test configuration loading
.\install.ps1 -Operation clean -DryRun -Verbose | Select-String "configuration"

# Use fallback mode if needed
.\install.ps1 -Operation clean -UseFallback

# Validate configuration file
jq empty src/config/augment_patterns.json && echo "✓ Valid" || echo "✗ Invalid"
```

### Core Module Commands
```bash
# Load and test unified configuration
source src/core/config_loader.sh && load_augment_config

# Check loaded patterns
echo "Loaded ${#AUGMENT_PATTERNS[@]} patterns"

# View telemetry field mappings
echo "Machine ID field: ${MACHINE_ID_FIELD}"
```

---

**⚠️ Important**: Always backup your VS Code data before running this tool. While the tool creates automatic backups, having your own backup ensures data safety.

**🆕 v2.0.0 Note**: The unified configuration system provides enhanced reliability and consistency. If you encounter any configuration-related issues, use the `-UseFallback` parameter to use embedded patterns.
