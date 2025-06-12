# Augment VIP - Enterprise Cross-Platform VS Code Cleaner

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/IIXINGCHEN/augment-vips)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)](https://github.com/IIXINGCHEN/augment-vips)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Security](https://img.shields.io/badge/security-enterprise%20grade-red.svg)](docs/SECURITY.md)

Enterprise-grade cross-platform tool for cleaning VS Code Augment data and modifying telemetry IDs. Built with zero-redundancy architecture, comprehensive security controls, and production-ready reliability.

## 🚀 Quick Start

### One-Line Installation

```bash
# Cross-platform unified installer
curl -fsSL https://gh.imixc.top/raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 | bash
```

### Manual Installation

```bash
# Clone repository
git clone https://github.com/IIXINGCHEN/augment-vips.git
cd augment-vips

# Make installer executable
chmod +x install

# Run with automatic platform detection
./install --operation all
```

## 📋 Features

### Core Functionality
- **Database Cleaning**: Remove Augment-related entries from VS Code databases
- **Telemetry Modification**: Generate new machine IDs, device IDs, and SQM IDs
- **Cross-Platform Support**: Windows (PowerShell), Linux (Bash), macOS (Bash)
- **Automatic Discovery**: Find VS Code installations and data files automatically

### Enterprise Features
- **Zero-Redundancy Architecture**: Shared core modules, platform-specific implementations
- **Comprehensive Security**: Input validation, audit logging, backup creation
- **Production Ready**: Error handling, monitoring, performance optimization
- **Modular Design**: Extensible architecture with clear separation of concerns

### Security & Compliance
- **Audit Logging**: Complete operation tracking for compliance
- **Automatic Backups**: Safe operations with rollback capability
- **Input Validation**: Comprehensive sanitization and security checks
- **Access Controls**: Configurable security policies and restrictions

## 🏗️ Architecture

```
augment-vip/
├── install                    # Unified cross-platform entry point
├── core/                      # Zero-redundancy shared modules
│   ├── common.sh             # Common functions and utilities
│   ├── platform.sh           # Platform detection and adaptation
│   ├── security.sh           # Security validation and controls
│   ├── validation.sh         # Input validation and sanitization
│   ├── dependencies.sh       # Dependency management
│   ├── paths.sh              # Cross-platform path resolution
│   ├── database.sh           # SQLite database operations
│   ├── telemetry.sh          # Telemetry ID processing
│   ├── backup.sh             # Backup and recovery
│   └── logging.sh            # Enterprise logging system
├── platforms/                # Platform-specific implementations
│   ├── windows.ps1           # Windows PowerShell implementation
│   ├── linux.sh              # Linux Bash implementation
│   └── macos.sh              # macOS Bash implementation
├── config/                   # Configuration management
│   ├── settings.json         # Main configuration
│   └── security.json         # Security policies
├── tests/                    # Comprehensive test suite
│   ├── unit/                 # Unit tests
│   ├── integration/          # Integration tests
│   ├── security/             # Security tests
│   └── performance/          # Performance tests
└── docs/                     # Enterprise documentation
    ├── SECURITY.md           # Security documentation
    ├── DEPLOYMENT.md         # Deployment guide
    └── TROUBLESHOOTING.md    # Troubleshooting guide
```

## 🖥️ Platform Support

### Windows
- **Requirements**: Windows 10+, PowerShell 5.1+
- **Package Manager**: Chocolatey (auto-installable)
- **Dependencies**: sqlite3, curl, jq

### Linux
- **Requirements**: Modern Linux distribution, Bash 4.0+
- **Package Managers**: apt, dnf, yum, pacman, zypper
- **Dependencies**: sqlite3, curl, jq

### macOS
- **Requirements**: macOS 10.12+, Bash 4.0+
- **Package Manager**: Homebrew
- **Dependencies**: sqlite3, curl, jq

## 📖 Usage

### Basic Operations

```bash
# Clean VS Code databases only
./install --operation clean

# Modify telemetry IDs only
./install --operation modify-ids

# Perform both operations
./install --operation all

# Dry run (preview changes)
./install --operation all --dry-run

# Verbose output
./install --operation all --verbose
```

### Platform-Specific Usage

```bash
# Windows (PowerShell)
.\platforms\windows.ps1 -Operation all -Verbose

# Linux
./platforms/linux.sh --operation all --verbose

# macOS
./platforms/macos.sh --operation all --verbose
```

### Advanced Configuration

```bash
# Custom configuration file
./install --operation all --config custom-config.json

# Force specific platform
./install --operation all --platform linux
```

## ⚙️ Configuration

### Main Configuration (`config/settings.json`)

```json
{
  "general": {
    "auto_backup": true,
    "backup_retention_days": 30,
    "verification_enabled": true
  },
  "security": {
    "security_level": "high",
    "audit_logging": true,
    "input_validation": "strict"
  },
  "database": {
    "timeout_seconds": 30,
    "backup_before_clean": true,
    "integrity_check": true
  }
}
```

### Security Policy (`config/security.json`)

```json
{
  "security_level": "high",
  "allowed_operations": [
    "database_clean",
    "telemetry_modify",
    "backup_create"
  ],
  "restricted_paths": [
    "/etc", "/usr", "/bin",
    "C:\\Windows", "C:\\Program Files"
  ]
}
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

For detailed security information, see [SECURITY.md](docs/SECURITY.md).

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

### Run Test Suite

```bash
# Run all tests
./tests/run_tests.sh

# Run specific test types
./tests/run_tests.sh --type unit,security

# Verbose test output
./tests/run_tests.sh --verbose

# Stop on first failure
./tests/run_tests.sh --stop-on-failure
```

### Test Types
- **Unit Tests**: Individual module testing
- **Integration Tests**: Cross-module functionality
- **Security Tests**: Vulnerability and security validation
- **Performance Tests**: Performance benchmarks

## 🚀 Deployment

### Production Deployment

1. **Download and Verify**
   ```bash
   curl -fsSL https://gh.imixc.top/raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 -o install.ps1
   # Verify checksum and signature
   ```

2. **Configure Security**
   ```bash
   # Review and customize security policies
   vim config/security.json
   ```

3. **Test in Staging**
   ```bash
   # Run comprehensive tests
   ./tests/run_tests.sh
   # Perform dry run
   ./install --operation all --dry-run
   ```

4. **Deploy to Production**
   ```bash
   # Execute with monitoring
   ./install --operation all --verbose
   ```

For detailed deployment instructions, see [DEPLOYMENT.md](docs/DEPLOYMENT.md).

## 🔧 Troubleshooting

### Common Issues

**VS Code Not Found**
```bash
# Ensure VS Code is installed and has been run at least once
# Check installation paths manually
```

**Permission Denied**
```bash
# Ensure appropriate file permissions
chmod +x install
# On Windows, run PowerShell as Administrator if needed
```

**Dependencies Missing**
```bash
# Install dependencies manually or enable auto-installation
# Windows: choco install sqlite curl jq
# Linux: sudo apt install sqlite3 curl jq
# macOS: brew install sqlite3 curl jq
```

For comprehensive troubleshooting, see [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

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
- **Documentation**: [Project Wiki](https://github.com/IIXINGCHEN/augment-vips/wiki)
- **Security**: [Security Policy](docs/SECURITY.md)

## 🏆 Acknowledgments

- VS Code team for the excellent editor
- Open source community for tools and libraries
- Security researchers for best practices
- Enterprise users for requirements and feedback

---

**⚠️ Important**: Always backup your VS Code data before running this tool. While the tool creates automatic backups, having your own backup ensures data safety.
