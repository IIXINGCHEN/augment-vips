# Augment Account Restriction Fix Guide

## 🚨 Problem: "Your account has been restricted. To continue, purchase a subscription."

If you're seeing this error message when using Augment in VS Code or Cursor, this guide will help you resolve it quickly.

## 🔧 Quick Fix Solutions

### Option 1: Specialized Account Restriction Fix Tool (Recommended)

**Download and run the specialized fix:**

```powershell
# Download the specialized fix tool
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/fix-account-restriction.ps1" -OutFile "fix-account-restriction.ps1"

# Run the fix (will prompt for confirmation)
.\fix-account-restriction.ps1

# Or preview what will be fixed first
.\fix-account-restriction.ps1 -DryRun -VerboseOutput
```

### Option 2: Main Installer with Auto-Detection

**The main installer now automatically detects and fixes account restrictions:**

```powershell
# One-line fix (auto-detects and resolves restrictions)
irm https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1 | iex

# Or download and run locally
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/IIXINGCHEN/augment-vips/main/install.ps1" -OutFile "install.ps1"
.\install.ps1 -Operation clean -VerboseOutput
```

## 🔍 What Causes This Error?

The "Your account has been restricted" error occurs when Augment detects:

1. **Active Authentication Sessions**: Stored in `Augment.vscode-augment` database entries
2. **Encrypted Session Data**: Stored as `secret://augment.sessions` in the database
3. **Extension State Data**: Workbench integration data that tracks usage
4. **Global Storage Files**: Extension-specific directories and configuration files

## 🛠️ What Our Fix Does

### Automatic Detection
- Scans VS Code and Cursor installations for Augment restriction data
- Identifies authenticated sessions that cause restrictions
- Locates global storage directories with extension data

### Safe Cleanup Process
1. **Creates Automatic Backups**: All modified files are backed up with timestamps
2. **Removes Database Entries**: Cleans specific Augment-related database records
3. **Deletes Global Storage**: Removes extension directories and configuration files
4. **Preserves User Data**: Only removes Augment-specific restriction data

### Specific Data Removed
- `Augment.vscode-augment` - Main extension configuration
- `secret://augment.sessions` - Encrypted session data
- `workbench.view.extension.augment-*` - UI state data
- `augment.vscode-augment` directory - Global storage files

## 📋 Step-by-Step Manual Process

If you prefer to understand what's happening, here's the manual process:

### Step 1: Close VS Code/Cursor
```powershell
# Close all VS Code and Cursor instances
Get-Process | Where-Object {$_.Name -like "*Code*" -or $_.Name -like "*Cursor*"} | Stop-Process -Force
```

### Step 2: Backup Important Data
```powershell
# Create backup directory
$backupDir = "AugmentBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $backupDir

# Backup database
Copy-Item "$env:APPDATA\Code\User\globalStorage\state.vscdb" "$backupDir\state.vscdb.backup"
```

### Step 3: Remove Restriction Data
```powershell
# Remove database entries
sqlite3 "$env:APPDATA\Code\User\globalStorage\state.vscdb" "DELETE FROM ItemTable WHERE key = 'Augment.vscode-augment';"
sqlite3 "$env:APPDATA\Code\User\globalStorage\state.vscdb" "DELETE FROM ItemTable WHERE key LIKE 'secret://%augment%';"
sqlite3 "$env:APPDATA\Code\User\globalStorage\state.vscdb" "DELETE FROM ItemTable WHERE key LIKE 'workbench.view.extension.augment%';"

# Remove global storage directory
Remove-Item "$env:APPDATA\Code\User\globalStorage\augment.vscode-augment" -Recurse -Force -ErrorAction SilentlyContinue
```

### Step 4: Verify Cleanup
```powershell
# Check if data was removed
sqlite3 "$env:APPDATA\Code\User\globalStorage\state.vscdb" "SELECT key FROM ItemTable WHERE key LIKE '%augment%';"
# Should return no results

# Check if directory was removed
Test-Path "$env:APPDATA\Code\User\globalStorage\augment.vscode-augment"
# Should return False
```

## ✅ Verification

After running the fix:

1. **Restart VS Code/Cursor** completely
2. **Open Augment extension** - it should work without restriction errors
3. **Check for clean state** - no "account restricted" messages should appear

## 🔄 If Problems Persist

If you still see restriction errors after the fix:

### Check Cursor IDE (if applicable)
```powershell
# Run fix for Cursor as well
.\fix-account-restriction.ps1 -VerboseOutput
# The tool automatically checks both VS Code and Cursor
```

### Clear Additional Cache
```powershell
# Clear extension cache
Remove-Item "$env:APPDATA\Code\CachedExtensions" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:APPDATA\Cursor\CachedExtensions" -Recurse -Force -ErrorAction SilentlyContinue
```

### Reset Extension Settings
```powershell
# Reset workspace settings (if needed)
.\install.ps1 -Operation all -VerboseOutput
```

## 🛡️ Safety Features

### Automatic Backups
- All modified files are automatically backed up with timestamps
- Backups are created before any changes are made
- Easy restoration if needed

### Dry Run Mode
```powershell
# Preview changes without making them
.\fix-account-restriction.ps1 -DryRun -VerboseOutput
```

### Verbose Logging
```powershell
# See detailed information about what's being done
.\fix-account-restriction.ps1 -VerboseOutput
```

## 📞 Support

If you encounter any issues:

1. **Check the logs** - verbose output shows exactly what was processed
2. **Verify prerequisites** - ensure SQLite3 is available
3. **Try the main installer** - it has additional fallback mechanisms
4. **Report issues** - provide verbose output logs for troubleshooting

## 🎯 Success Indicators

You'll know the fix worked when:

- ✅ No "account restricted" error messages
- ✅ Augment extension loads normally
- ✅ All Augment features are accessible
- ✅ No subscription prompts appear

The fix typically resolves the issue immediately after restarting VS Code/Cursor.
