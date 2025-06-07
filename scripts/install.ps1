# install.ps1
#
# Description: Installation script for the Augment VIP project (Windows version)
# This script sets up the necessary dependencies and configurations
#
# Usage: .\install.ps1 [options]
#   Options:
#     --help          Show this help message
#     --clean         Run database cleaning script after installation
#     --modify-ids    Run telemetry ID modification script after installation
#     --all           Run all scripts (clean and modify IDs)

# 设置错误处理
$ErrorActionPreference = "Stop"

# 日志函数
function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# 仓库信息
$REPO_URL = "https://raw.githubusercontent.com/azrilaiman2003/augment-vip/main"

# 获取脚本所在目录
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# 确定是独立安装还是从克隆的仓库安装
if ($SCRIPT_DIR -like "*\scripts") {
    # 脚本在scripts目录中，可能是克隆的仓库
    $PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
    $STANDALONE_MODE = $false
} else {
    # 脚本不在scripts目录中，可能是独立安装
    $STANDALONE_MODE = $true

    # 为独立安装创建项目目录
    $PROJECT_ROOT = Join-Path $SCRIPT_DIR "augment-vip"
    Write-LogInfo "Creating project directory at: $PROJECT_ROOT"
    New-Item -ItemType Directory -Force -Path $PROJECT_ROOT | Out-Null

    # 创建scripts目录
    $SCRIPT_DIR = Join-Path $PROJECT_ROOT "scripts"
    New-Item -ItemType Directory -Force -Path $SCRIPT_DIR | Out-Null

    # 复制此脚本到scripts目录
    Copy-Item $MyInvocation.MyCommand.Path -Destination $SCRIPT_DIR
}

# 检查系统依赖 (使用SystemDetection模块)
function Check-Dependencies {
    Write-LogInfo "Checking system dependencies..."

    # Try to use SystemDetection module if available
    $systemDetectionPath = Join-Path $SCRIPT_DIR "modules\SystemDetection.psm1"
    if (Test-Path $systemDetectionPath) {
        try {
            Import-Module $systemDetectionPath -Force
            $result = Test-Dependencies
            if (-not $result) {
                $response = Read-Host "Do you want to continue anyway? (y/n)"
                if ($response -notmatch '^[Yy]$') {
                    Write-LogError "Installation aborted due to missing dependencies"
                    exit 1
                }
            }
            return
        }
        catch {
            Write-LogWarning "Failed to use SystemDetection module, falling back to basic check"
        }
    }

    # Fallback to basic dependency check
    $missingDeps = @()
    $dependencies = @("sqlite3", "curl", "jq")
    foreach ($dep in $dependencies) {
        if (-not (Get-Command $dep -ErrorAction SilentlyContinue)) {
            $missingDeps += $dep
        }
    }

    if ($missingDeps.Count -gt 0) {
        Write-LogWarning "Missing dependencies: $($missingDeps -join ', ')"
        Write-LogInfo "To install on Windows, we recommend using Chocolatey: choco install $($missingDeps -join ' ')"

        $response = Read-Host "Do you want to continue anyway? (y/n)"
        if ($response -notmatch '^[Yy]$') {
            Write-LogError "Installation aborted due to missing dependencies"
            exit 1
        }
    } else {
        Write-LogSuccess "All system dependencies are installed"
    }
}

# 设置项目配置
function Setup-Configuration {
    Write-LogInfo "Setting up project configuration..."

    # 创建config目录（如果不存在）
    $configDir = Join-Path $PROJECT_ROOT "config"
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null

    # 创建默认配置文件（如果不存在）
    $configFile = Join-Path $configDir "config.json"
    if (-not (Test-Path $configFile)) {
        @{
            version = "1.0.0"
            environment = "development"
            features = @{
                cleanCodeDb = $true
            }
        } | ConvertTo-Json | Set-Content $configFile
        Write-LogSuccess "Created default configuration file"
    } else {
        Write-LogInfo "Configuration file already exists, skipping"
    }
}

# 创建必要的目录
function Create-Directories {
    Write-LogInfo "Creating project directories..."

    # 创建通用目录
    $dirs = @("logs", "data", "temp")
    foreach ($dir in $dirs) {
        New-Item -ItemType Directory -Force -Path (Join-Path $PROJECT_ROOT $dir) | Out-Null
    }

    Write-LogSuccess "Project directories created"
}

# 从仓库下载脚本（独立模式）
function Download-Scripts {
    if (-not $STANDALONE_MODE) {
        Write-LogInfo "Running in repository mode, skipping script download"
        return
    }

    Write-LogInfo "Running in standalone mode, creating required scripts..."

    # 要创建的脚本列表
    $scripts = @("clean_code_db.ps1", "id_modifier.ps1")

    # 创建每个脚本
    foreach ($script in $scripts) {
        $scriptPath = Join-Path $SCRIPT_DIR $script
        Write-LogInfo "Creating $script..."

        try {
            # 如果脚本已经存在，先删除
            if (Test-Path $scriptPath) {
                Remove-Item $scriptPath -Force
            }

            # 创建新的脚本文件
            switch ($script) {
                "clean_code_db.ps1" {
                    @'
# clean_code_db.ps1
#
# Description: Script to clean VS Code databases by removing Augment-related entries
# This script will:
# 1. Find VS Code database files
# 2. Create backups
# 3. Remove entries containing "augment"
# 4. Report results

# 设置错误处理
$ErrorActionPreference = "Stop"

# 文本格式化
$BOLD = "`e[1m"
$RED = "`e[31m"
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$BLUE = "`e[34m"
$RESET = "`e[0m"

# 日志函数
function Write-LogInfo {
    param([string]$Message)
    Write-Host "${BLUE}[INFO]${RESET} $Message"
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "${GREEN}[SUCCESS]${RESET} $Message"
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "${YELLOW}[WARNING]${RESET} $Message"
}

function Write-LogError {
    param([string]$Message)
    Write-Host "${RED}[ERROR]${RESET} $Message"
}

# 获取VS Code数据库文件路径
function Get-VSCodeDatabasePaths {
    $paths = @()
    
    # Windows路径
    $appData = $env:APPDATA
    $localAppData = $env:LOCALAPPDATA
    
    # 检查AppData路径
    $codePath = Join-Path $appData "Code"
    if (Test-Path $codePath) {
        $paths += @(
            # 工作区存储
            (Join-Path $codePath "User\workspaceStorage\*\state.vscdb"),
            (Join-Path $codePath "User\globalStorage\*\state.vscdb"),
            # 缓存
            (Join-Path $codePath "Cache\*\*.vscdb"),
            (Join-Path $codePath "CachedData\*\*.vscdb"),
            # 日志
            (Join-Path $codePath "logs\*\*.vscdb"),
            # 其他数据库文件
            (Join-Path $codePath "User\*\*.vscdb"),
            (Join-Path $codePath "User\workspaceStorage\*\*.vscdb"),
            (Join-Path $codePath "User\globalStorage\*\*.vscdb")
        )
    }
    
    # 检查LocalAppData路径
    $codePath = Join-Path $localAppData "Programs\Microsoft VS Code"
    if (Test-Path $codePath) {
        $paths += @(
            (Join-Path $codePath "resources\app\out\vs\workbench\workbench.desktop.main.js"),
            (Join-Path $codePath "resources\app\out\vs\workbench\workbench.desktop.main.js.map")
        )
    }
    
    # 检查Insiders版本
    $codeInsidersPath = Join-Path $appData "Code - Insiders"
    if (Test-Path $codeInsidersPath) {
        $paths += @(
            (Join-Path $codeInsidersPath "User\workspaceStorage\*\state.vscdb"),
            (Join-Path $codeInsidersPath "User\globalStorage\*\state.vscdb"),
            (Join-Path $codeInsidersPath "Cache\*\*.vscdb"),
            (Join-Path $codeInsidersPath "CachedData\*\*.vscdb"),
            (Join-Path $codeInsidersPath "logs\*\*.vscdb"),
            (Join-Path $codeInsidersPath "User\*\*.vscdb"),
            (Join-Path $codeInsidersPath "User\workspaceStorage\*\*.vscdb"),
            (Join-Path $codeInsidersPath "User\globalStorage\*\*.vscdb")
        )
    }
    
    return $paths
}

# 创建备份
function Backup-File {
    param(
        [string]$FilePath
    )
    
    $backupPath = "$FilePath.backup"
    try {
        Copy-Item -Path $FilePath -Destination $backupPath -Force
        Write-LogSuccess "Created backup: $backupPath"
        return $true
    } catch {
        Write-LogError "Failed to create backup for: $FilePath"
        return $false
    }
}

# 清理数据库
function Clean-Database {
    param(
        [string]$DatabasePath
    )
    
    try {
        # 检查文件是否存在
        if (-not (Test-Path $DatabasePath)) {
            Write-LogWarning "Database file not found: $DatabasePath"
            return $false
        }
        
        # 创建备份
        if (-not (Backup-File -FilePath $DatabasePath)) {
            return $false
        }
        
        # 使用SQLite清理数据库
        $tempFile = [System.IO.Path]::GetTempFileName()
        $query = @"
DELETE FROM ItemTable WHERE key LIKE '%augment%';
DELETE FROM ItemTable WHERE key LIKE '%telemetry%';
DELETE FROM ItemTable WHERE key LIKE '%machineId%';
DELETE FROM ItemTable WHERE key LIKE '%deviceId%';
DELETE FROM ItemTable WHERE key LIKE '%sqmId%';
DELETE FROM ItemTable WHERE key LIKE '%uuid%';
DELETE FROM ItemTable WHERE key LIKE '%session%';
DELETE FROM ItemTable WHERE key LIKE '%lastSessionDate%';
DELETE FROM ItemTable WHERE key LIKE '%lastSyncDate%';
DELETE FROM ItemTable WHERE key LIKE '%lastSyncMachineId%';
DELETE FROM ItemTable WHERE key LIKE '%lastSyncDeviceId%';
DELETE FROM ItemTable WHERE key LIKE '%lastSyncSqmId%';
DELETE FROM ItemTable WHERE key LIKE '%lastSyncUuid%';
DELETE FROM ItemTable WHERE key LIKE '%lastSyncSession%';
DELETE FROM ItemTable WHERE key LIKE '%lastSyncLastSessionDate%';
DELETE FROM ItemTable WHERE key LIKE '%lastSyncLastSyncDate%';
VACUUM;
"@
        
        # 执行SQLite命令
        sqlite3 $DatabasePath $query
        
        Write-LogSuccess "Cleaned database: $DatabasePath"
        return $true
    } catch {
        Write-LogError "Failed to clean database: $DatabasePath"
        Write-LogError $_.Exception.Message
        return $false
    }
}

# 主函数
function Main {
    Write-LogInfo "Starting VS Code database cleaning process"
    
    # 获取数据库路径
    $databasePaths = Get-VSCodeDatabasePaths
    if ($databasePaths.Count -eq 0) {
        Write-LogWarning "No VS Code database files found"
        return
    }
    
    $successCount = 0
    $failCount = 0
    
    # 处理每个数据库文件
    foreach ($path in $databasePaths) {
        $files = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            if (Clean-Database -DatabasePath $file.FullName) {
                $successCount++
            } else {
                $failCount++
            }
        }
    }
    
    # 报告结果
    Write-LogInfo "Cleaning process completed"
    Write-LogInfo "Successfully cleaned: $successCount databases"
    if ($failCount -gt 0) {
        Write-LogWarning "Failed to clean: $failCount databases"
    }
}

# 运行主函数
Main
'@ | Set-Content $scriptPath
                }
                "id_modifier.ps1" {
                    @'
# id_modifier.ps1
#
# Description: Script to modify VS Code telemetry IDs
# This script will:
# 1. Find VS Code storage.json file
# 2. Generate random IDs
# 3. Create backup
# 4. Update the file with new IDs

# 设置错误处理
$ErrorActionPreference = "Stop"

# 文本格式化
$BOLD = "`e[1m"
$RED = "`e[31m"
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$BLUE = "`e[34m"
$RESET = "`e[0m"

# 日志函数
function Write-LogInfo {
    param([string]$Message)
    Write-Host "${BLUE}[INFO]${RESET} $Message"
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "${GREEN}[SUCCESS]${RESET} $Message"
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "${YELLOW}[WARNING]${RESET} $Message"
}

function Write-LogError {
    param([string]$Message)
    Write-Host "${RED}[ERROR]${RESET} $Message"
}

# 获取VS Code存储文件路径
function Get-VSCodeStoragePath {
    $paths = @()
    
    # 标准路径
    $appData = $env:APPDATA
    $localAppData = $env:LOCALAPPDATA
    
    Write-LogInfo "Checking VS Code storage locations..."
    Write-LogInfo "AppData path: $appData"
    Write-LogInfo "LocalAppData path: $localAppData"
    
    # 检查标准路径
    $paths += @(
        # User目录下的文件
        (Join-Path $appData "Code\User\storage.json"),
        (Join-Path $appData "Code\User\globalStorage\storage.json"),
        (Join-Path $localAppData "Code\User\storage.json"),
        (Join-Path $localAppData "Code\User\globalStorage\storage.json"),
        # Insiders版本
        (Join-Path $appData "Code - Insiders\User\storage.json"),
        (Join-Path $appData "Code - Insiders\User\globalStorage\storage.json"),
        (Join-Path $localAppData "Code - Insiders\User\storage.json"),
        (Join-Path $localAppData "Code - Insiders\User\globalStorage\storage.json"),
        # 其他可能的存储位置
        (Join-Path $appData "Code\User\workspaceStorage\*\storage.json"),
        (Join-Path $appData "Code\User\workspaceStorage\*\globalStorage\storage.json"),
        (Join-Path $localAppData "Code\User\workspaceStorage\*\storage.json"),
        (Join-Path $localAppData "Code\User\workspaceStorage\*\globalStorage\storage.json"),
        # 缓存文件
        (Join-Path $appData "Code\Cache\*\storage.json"),
        (Join-Path $localAppData "Code\Cache\*\storage.json"),
        # 日志文件
        (Join-Path $appData "Code\logs\*\storage.json"),
        (Join-Path $localAppData "Code\logs\*\storage.json")
    )
    
    # 检查便携版路径
    $portablePaths = @(
        ".\data\user-data\User\storage.json",
        ".\data\user-data\User\globalStorage\storage.json",
        ".\user-data\User\storage.json",
        ".\user-data\User\globalStorage\storage.json"
    )
    
    foreach ($path in $portablePaths) {
        if (Test-Path $path) {
            $paths += $path
        }
    }
    
    # 检查所有可能的路径
    foreach ($path in $paths) {
        Write-LogInfo "Checking path: $path"
        if (Test-Path $path) {
            Write-LogSuccess "Found VS Code storage.json at: $path"
            return $path
        }
    }
    
    # 如果没有找到文件，尝试搜索整个VS Code目录
    Write-LogInfo "Searching for storage.json in VS Code directories..."
    $codeDirs = @(
        (Join-Path $appData "Code"),
        (Join-Path $localAppData "Code"),
        (Join-Path $appData "Code - Insiders"),
        (Join-Path $localAppData "Code - Insiders")
    )
    
    foreach ($dir in $codeDirs) {
        if (Test-Path $dir) {
            Write-LogInfo "Searching in: $dir"
            $foundFiles = Get-ChildItem -Path $dir -Recurse -Filter "storage.json" -ErrorAction SilentlyContinue
            if ($foundFiles) {
                foreach ($file in $foundFiles) {
                    Write-LogSuccess "Found storage.json at: $($file.FullName)"
                    return $file.FullName
                }
            }
        }
    }
    
    Write-LogWarning "VS Code storage.json not found in any of the following locations:"
    foreach ($path in $paths) {
        Write-LogWarning "  - $path"
    }
    return $null
}

# 生成随机ID
function Generate-RandomId {
    param(
        [int]$Length = 64
    )
    
    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    
    return [System.BitConverter]::ToString($bytes).Replace("-", "").ToLower()
}

# 生成UUID v4
function Generate-UUIDv4 {
    $guid = [System.Guid]::NewGuid()
    return $guid.ToString()
}

# 创建备份
function Backup-File {
    param(
        [string]$FilePath
    )
    
    $backupPath = "$FilePath.backup"
    try {
        Copy-Item -Path $FilePath -Destination $backupPath -Force
        Write-LogSuccess "Created backup: $backupPath"
        return $true
    } catch {
        Write-LogError "Failed to create backup for: $FilePath"
        return $false
    }
}

# 修改遥测ID
function Modify-TelemetryIds {
    param(
        [string]$StoragePath
    )
    
    try {
        # 检查文件是否存在
        if (-not (Test-Path $StoragePath)) {
            Write-LogWarning "Storage file not found: $StoragePath"
            return $false
        }
        
        # 创建备份
        if (-not (Backup-File -FilePath $StoragePath)) {
            return $false
        }
        
        # 读取当前配置
        $content = Get-Content -Path $StoragePath -Raw | ConvertFrom-Json
        
        # 生成新的ID
        $newMachineId = Generate-RandomId
        $newDeviceId = Generate-UUIDv4
        $newSqmId = Generate-UUIDv4
        
        # 更新ID (Windows格式)
        $content."telemetry.machineId" = $newMachineId
        $content."telemetry.devDeviceId" = $newDeviceId
        $content."telemetry.sqmId" = $newSqmId
        
        # 保存更改
        $content | ConvertTo-Json -Depth 10 | Set-Content -Path $StoragePath
        
        Write-LogSuccess "Updated telemetry IDs in: $StoragePath"
        Write-LogInfo "New telemetry.machineId: $newMachineId"
        Write-LogInfo "New telemetry.devDeviceId: $newDeviceId"
        Write-LogInfo "New telemetry.sqmId: $newSqmId"
        
        return $true
    } catch {
        Write-LogError "Failed to modify telemetry IDs: $StoragePath"
        Write-LogError $_.Exception.Message
        return $false
    }
}

# 主函数
function Main {
    Write-LogInfo "Starting VS Code telemetry ID modification process"
    
    # 获取存储文件路径
    $storagePath = Get-VSCodeStoragePath
    if (-not $storagePath) {
        Write-LogError "Could not find VS Code storage.json file"
        return
    }
    
    # 修改遥测ID
    if (Modify-TelemetryIds -StoragePath $storagePath) {
        Write-LogSuccess "Telemetry ID modification completed successfully"
    } else {
        Write-LogError "Telemetry ID modification failed"
    }
}

# 运行主函数
Main
'@ | Set-Content $scriptPath
                }
            }
            Write-LogSuccess "Created: $script"
        } catch {
            Write-LogError "Failed to create $script"
            return 1
        }
    }

    Write-LogSuccess "All scripts created successfully"
}

# 运行主清理脚本
function Run-MasterScript {
    param(
        [string]$Operation = "all"
    )

    Write-LogInfo "Running VS Code cleanup master script..."

    $masterScript = Join-Path $SCRIPT_DIR "vscode-cleanup-master.ps1"
    if (Test-Path $masterScript) {
        switch ($Operation.ToLower()) {
            "clean" {
                & $masterScript -Clean -Verbose
            }
            "modify-ids" {
                & $masterScript -ModifyTelemetry -Verbose
            }
            "all" {
                & $masterScript -All -Verbose
            }
            "preview" {
                & $masterScript -Preview -All -Verbose
            }
            default {
                & $masterScript -All -Verbose
            }
        }
        Write-LogSuccess "Master script execution completed"
    } else {
        Write-LogError "Master script not found"
        return 1
    }

    return 0
}

# 运行数据库清理脚本（向后兼容）
function Run-CleanScript {
    Write-LogInfo "Running database cleaning script..."

    $cleanScript = Join-Path $SCRIPT_DIR "clean_code_db.ps1"
    if (Test-Path $cleanScript) {
        & $cleanScript
        Write-LogSuccess "Database cleaning completed"
    } else {
        Write-LogError "Database cleaning script not found"
        return 1
    }

    return 0
}

# 运行遥测ID修改脚本（向后兼容）
function Run-IdModifierScript {
    Write-LogInfo "Running telemetry ID modification script..."

    $idModifierScript = Join-Path $SCRIPT_DIR "id_modifier.ps1"
    if (Test-Path $idModifierScript) {
        & $idModifierScript
        Write-LogSuccess "Telemetry ID modification completed"
    } else {
        Write-LogError "Telemetry ID modification script not found"
        return 1
    }

    return 0
}

# 显示帮助信息
function Show-Help {
    Write-Host "Augment VIP Installation Script (Windows Version)"
    Write-Host ""
    Write-Host "Usage: .\install.ps1 [options]"
    Write-Host "Options:"
    Write-Host "  --help          Show this help message"
    Write-Host "  --clean         Run database cleaning script after installation"
    Write-Host "  --modify-ids    Run telemetry ID modification script after installation"
    Write-Host "  --all           Run all scripts (clean and modify IDs)"
    Write-Host "  --preview       Show preview of operations without executing"
    Write-Host "  --master        Use the new master script (recommended)"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\install.ps1 --all"
    Write-Host "  .\install.ps1 --master --preview"
    Write-Host "  .\install.ps1 --master --all"
}

# 主安装函数
function Main {
    param(
        [switch]$Help,
        [switch]$Clean,
        [switch]$ModifyIds,
        [switch]$All,
        [switch]$Preview,
        [switch]$Master
    )

    if ($Help) {
        Show-Help
        return
    }

    Write-LogInfo "Starting installation process for Augment VIP"

    # 检查依赖
    Check-Dependencies

    # 设置配置
    Setup-Configuration

    # 创建目录
    Create-Directories

    # 下载脚本
    Download-Scripts

    # 根据参数运行脚本
    if ($Master) {
        # 使用新的主脚本
        if ($Preview) {
            Run-MasterScript -Operation "preview"
        } elseif ($All) {
            Run-MasterScript -Operation "all"
        } elseif ($Clean) {
            Run-MasterScript -Operation "clean"
        } elseif ($ModifyIds) {
            Run-MasterScript -Operation "modify-ids"
        } else {
            Run-MasterScript -Operation "all"
        }
    } else {
        # 使用传统脚本（向后兼容）
        if ($All -or $Clean) {
            Run-CleanScript
        }

        if ($All -or $ModifyIds) {
            Run-IdModifierScript
        }
    }

    Write-LogSuccess "Installation completed successfully"
}

# 解析命令行参数并运行主函数
$params = @{}
if ($args -contains "--help") { $params.Help = $true }
if ($args -contains "--clean") { $params.Clean = $true }
if ($args -contains "--modify-ids") { $params.ModifyIds = $true }
if ($args -contains "--all") { $params.All = $true }
if ($args -contains "--preview") { $params.Preview = $true }
if ($args -contains "--master") { $params.Master = $true }

Main @params