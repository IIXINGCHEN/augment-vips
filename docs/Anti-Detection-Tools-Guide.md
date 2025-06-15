# Anti-Detection Tools Usage Guide

## 📋 Table of Contents
- [Quick Start](#quick-start)
- [Tools Overview](#tools-overview)
- [Usage Methods](#usage-methods)
- [Recommended Workflows](#recommended-workflows)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

## 🚀 Quick Start

### 1. One-Click Complete Fix (Recommended for Beginners)
```powershell
# Navigate to project directory
cd G:\SRC\augment-vips\augment-vips

# Run complete fix tool (preview mode)
powershell -ExecutionPolicy Bypass -File "src\tools\Complete-Augment-Fix.ps1" -DryRun

# Execute actual fix after confirmation
powershell -ExecutionPolicy Bypass -File "src\tools\Complete-Augment-Fix.ps1"
```

### 2. Master Controller (Recommended for Advanced Users)
```powershell
# Analyze current detection risks
powershell -ExecutionPolicy Bypass -File "src\tools\Advanced-Anti-Detection.ps1" -Operation analyze

# Execute complete anti-detection (aggressive mode)
powershell -ExecutionPolicy Bypass -File "src\tools\Advanced-Anti-Detection.ps1" -Operation complete -ThreatLevel AGGRESSIVE

# Nuclear level anti-detection (maximum intensity)
powershell -ExecutionPolicy Bypass -File "src\tools\Advanced-Anti-Detection.ps1" -Operation complete -ThreatLevel NUCLEAR
```

## 🛠️ Tools Overview

### Core Anti-Detection Tools
| Tool Name | Main Function | Use Case |
|-----------|---------------|----------|
| `Advanced-Anti-Detection.ps1` | Master controller, coordinates all anti-detection components | One-stop anti-detection solution |
| `Session-ID-Isolator.ps1` | Session ID isolation and reset | Solve session tracking issues |
| `Cross-Account-Delinker.ps1` | Cross-account association breaking | Prevent account correlation detection |
| `Network-Session-Manager.ps1` | Network session management | Network-level isolation |

### Specialized Tools
| Tool Name | Main Function | Use Case |
|-----------|---------------|----------|
| `Reset-TrialAccount.ps1` | Trial account reset | Bypass trial limitations |
| `Reset-DeviceFingerprint.ps1` | Device fingerprint reset | Change device identity |
| `Clean-SessionData.ps1` | Deep session data cleaning | Clear authentication traces |
| `Network-Fingerprint-Spoof.ps1` | Network fingerprint spoofing | Network identity masking |
| `System-Environment-Reset.ps1` | System environment reset | System-level cleanup |

## 📖 Usage Methods

### Basic Syntax
```powershell
powershell -ExecutionPolicy Bypass -File "src\tools\[ToolName].ps1" [Parameters]
```

### Common Parameters
- `-Operation` : Operation type (help, analyze, reset, clean, etc.)
- `-DryRun` : Preview mode, no actual modifications
- `-VerboseOutput` : Detailed log output
- `-Force` : Force execution, skip confirmations

### Specific Tool Usage Examples

#### 1. Master Controller (Advanced-Anti-Detection.ps1)
```powershell
# Show help
powershell -ExecutionPolicy Bypass -File "src\tools\Advanced-Anti-Detection.ps1" -Operation help

# Analyze detection risks
powershell -ExecutionPolicy Bypass -File "src\tools\Advanced-Anti-Detection.ps1" -Operation analyze -VerboseOutput

# Complete anti-detection (preview)
powershell -ExecutionPolicy Bypass -File "src\tools\Advanced-Anti-Detection.ps1" -Operation complete -ThreatLevel AGGRESSIVE -DryRun

# Execute complete anti-detection
powershell -ExecutionPolicy Bypass -File "src\tools\Advanced-Anti-Detection.ps1" -Operation complete -ThreatLevel AGGRESSIVE
```

#### 2. Trial Account Reset (Reset-TrialAccount.ps1)
```powershell
# Preview reset operation
powershell -ExecutionPolicy Bypass -File "src\tools\Reset-TrialAccount.ps1" -DryRun -VerboseOutput

# Execute reset
powershell -ExecutionPolicy Bypass -File "src\tools\Reset-TrialAccount.ps1"
```

#### 3. Session ID Isolation (Session-ID-Isolator.ps1)
```powershell
# Analyze session correlation risks
powershell -ExecutionPolicy Bypass -File "src\tools\Session-ID-Isolator.ps1" -Operation analyze

# Execute session isolation
powershell -ExecutionPolicy Bypass -File "src\tools\Session-ID-Isolator.ps1" -Operation isolate -IsolationLevel HIGH
```

#### 4. Cross-Account Delinking (Cross-Account-Delinker.ps1)
```powershell
# Analyze correlation risks
powershell -ExecutionPolicy Bypass -File "src\tools\Cross-Account-Delinker.ps1" -Operation analyze

# Execute delinking
powershell -ExecutionPolicy Bypass -File "src\tools\Cross-Account-Delinker.ps1" -Operation delink -DelinkLevel AGGRESSIVE
```

#### 5. Device Fingerprint Reset (Reset-DeviceFingerprint.ps1)
```powershell
# Preview reset
powershell -ExecutionPolicy Bypass -File "src\tools\Reset-DeviceFingerprint.ps1" -DryRun

# Execute reset
powershell -ExecutionPolicy Bypass -File "src\tools\Reset-DeviceFingerprint.ps1"
```

#### 6. Session Data Cleaning (Clean-SessionData.ps1)
```powershell
# Preview cleaning
powershell -ExecutionPolicy Bypass -File "src\tools\Clean-SessionData.ps1" -DryRun

# Execute cleaning
powershell -ExecutionPolicy Bypass -File "src\tools\Clean-SessionData.ps1"
```

## 🎯 Recommended Workflows

### Scenario 1: First Use/Complete Reset
```powershell
# 1. Analyze current state
powershell -ExecutionPolicy Bypass -File "src\tools\Advanced-Anti-Detection.ps1" -Operation analyze

# 2. Execute complete reset (preview)
powershell -ExecutionPolicy Bypass -File "src\tools\Complete-Augment-Fix.ps1" -DryRun

# 3. Execute after confirmation
powershell -ExecutionPolicy Bypass -File "src\tools\Complete-Augment-Fix.ps1"
```

### Scenario 2: Trial Account Expired
```powershell
# 1. Reset trial account
powershell -ExecutionPolicy Bypass -File "src\tools\Reset-TrialAccount.ps1" -DryRun
powershell -ExecutionPolicy Bypass -File "src\tools\Reset-TrialAccount.ps1"

# 2. Reset device fingerprint
powershell -ExecutionPolicy Bypass -File "src\tools\Reset-DeviceFingerprint.ps1"

# 3. Clean session data
powershell -ExecutionPolicy Bypass -File "src\tools\Clean-SessionData.ps1"
```

### Scenario 3: Account Correlation Detected
```powershell
# 1. Analyze correlation risks
powershell -ExecutionPolicy Bypass -File "src\tools\Cross-Account-Delinker.ps1" -Operation analyze

# 2. Execute delinking
powershell -ExecutionPolicy Bypass -File "src\tools\Cross-Account-Delinker.ps1" -Operation delink -DelinkLevel NUCLEAR

# 3. Session isolation
powershell -ExecutionPolicy Bypass -File "src\tools\Session-ID-Isolator.ps1" -Operation isolate -IsolationLevel CRITICAL
```

### Scenario 4: Network Detection Issues
```powershell
# 1. Network fingerprint spoofing
powershell -ExecutionPolicy Bypass -File "src\tools\Network-Fingerprint-Spoof.ps1" -Operation spoof -SpoofLevel STEALTH

# 2. Network session management
powershell -ExecutionPolicy Bypass -File "src\tools\Network-Session-Manager.ps1" -Operation isolate -IsolationLevel STEALTH
```

## ⚙️ Advanced Usage

### Threat Level Descriptions
- `CONSERVATIVE` / `LOW` : Basic cleanup, minimal impact
- `STANDARD` / `MEDIUM` : Standard cleanup, balanced effect and impact
- `AGGRESSIVE` / `HIGH` : Aggressive cleanup, strong anti-detection
- `NUCLEAR` / `CRITICAL` : Nuclear-level cleanup, maximum intensity

### Batch Operation Example
```powershell
# Create batch script
@"
@echo off
echo Starting anti-detection operations...
powershell -ExecutionPolicy Bypass -File "src\tools\Reset-TrialAccount.ps1" -DryRun
pause
powershell -ExecutionPolicy Bypass -File "src\tools\Reset-TrialAccount.ps1"
powershell -ExecutionPolicy Bypass -File "src\tools\Reset-DeviceFingerprint.ps1"
powershell -ExecutionPolicy Bypass -File "src\tools\Clean-SessionData.ps1"
echo Operations completed!
pause
"@ | Out-File -FilePath "Quick-Reset.bat" -Encoding ASCII
```

## 🔧 Troubleshooting

### Common Issues

1. **Execution Policy Error**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

2. **SQLite3 Not Found**
```powershell
# Download and install SQLite3, ensure it's in PATH
```

3. **Insufficient Permissions**
```powershell
# Run PowerShell as Administrator
```

4. **Core Module Loading Failed**
```powershell
# Check if file paths are correct
# Ensure all dependency files exist
```

### Verify Tools Are Working
```powershell
# Test help function for all tools
Get-ChildItem "src\tools\*.ps1" | ForEach-Object {
    Write-Host "Testing: $($_.Name)" -ForegroundColor Cyan
    & $_.FullName -Operation help
}
```

## ⚠️ Important Reminders

1. **Backup Important Data**: Please backup important VS Code/Cursor configurations before execution
2. **Close Applications**: Please close all VS Code/Cursor instances during execution
3. **Use DryRun First**: Recommended to use `-DryRun` parameter for preview on first use
4. **Administrator Rights**: Some operations may require administrator privileges
5. **Restart Applications**: Restart VS Code/Cursor after operations to apply changes

## 📞 Support

If you encounter issues, please check:
1. PowerShell version (recommended 5.1+)
2. Execution policy settings
3. File paths are correct
4. Sufficient permissions
