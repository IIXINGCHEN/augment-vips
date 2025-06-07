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

# 文本格式�?
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
    
    # 检查标准路�?
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
        # 其他可能的存储位�?
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
        # 检查文件是否存�?
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

# 主函�?
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

# 运行主函�?
Main
