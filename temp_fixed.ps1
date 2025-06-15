# StandardImports.ps1
# 标准化导入模块 - 为所有工具脚本提供统一的核心功能导入
# 版本: 1.0.0
# 功能: 统一日志、路径发现、数据库操作等核心功能

# 防止重复导入
if ($Global:StandardImportsLoaded) {
    return
}
$Global:StandardImportsLoaded = $true

# 获取脚本根目录
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path $scriptRoot -Parent

#region 核心模块导入

# 导入日志模块
$loggerPath = Join-Path $scriptRoot "AugmentLogger.ps1"
if (Test-Path $loggerPath) {
    . $loggerPath
    # 初始化日志系统
    if (-not $Global:LoggerConfig.Initialized) {
        Initialize-AugmentLogger -LogDirectory "logs" -LogFileName "augment_tools.log" -LogLevel "INFO"
    }
    $Global:LoggerAvailable = $true
} else {
    # 回退日志函数
    function Write-LogInfo { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor White }
    function Write-LogSuccess { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
    function Write-LogWarning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    function Write-LogError { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
    function Write-LogDebug { param([string]$Message) if ($VerbosePreference -eq 'Continue') { Write-Host "[DEBUG] $Message" -ForegroundColor Gray } }
    $Global:LoggerAvailable = $false
}

# 导入通用工具模块
$utilitiesPath = Join-Path $scriptRoot "utilities\common_utilities.ps1"
if (Test-Path $utilitiesPath) {
    . $utilitiesPath
    $Global:UtilitiesAvailable = $true
} else {
    # 回退路径发现函数
    function Get-StandardVSCodePaths {
        return @{
            VSCodeStandard = @(
                "$env:APPDATA\Code",
                "$env:LOCALAPPDATA\Code",
                "$env:APPDATA\Code - Insiders",
                "$env:LOCALAPPDATA\Code - Insiders"
            )
            CursorPaths = @(
                "$env:APPDATA\Cursor",
                "$env:LOCALAPPDATA\Cursor",
                "$env:APPDATA\Cursor - Insiders",
                "$env:LOCALAPPDATA\Cursor - Insiders"
            )
        }
    }
    $Global:UtilitiesAvailable = $false
}

# 导入配置管理模块
$configPath = Join-Path $scriptRoot "ConfigurationManager.ps1"
if (Test-Path $configPath) {
    . $configPath
    $Global:ConfigManagerAvailable = $true
} else {
    $Global:ConfigManagerAvailable = $false
}

#endregion

#region 统一功能函数

# 统一的VS Code安装发现函数
function Get-UnifiedVSCodeInstallations {
    <#
    .SYNOPSIS
        统一的VS Code和Cursor安装发现函数
    .DESCRIPTION
        使用标准化的路径发现逻辑，返回统一格式的安装信息
    .OUTPUTS
        [array] 安装信息数组
    .EXAMPLE
        $installations = Get-UnifiedVSCodeInstallations
    #>
    [CmdletBinding()]
    param()

    Write-LogInfo "Discovering VS Code and Cursor installations..."
    
    $installations = @()
    
    # 使用统一的路径获取函数
    if ($Global:UtilitiesAvailable) {
        $paths = Get-StandardVSCodePaths
        $allPaths = $paths.VSCodeStandard + $paths.CursorPaths
    } else {
        # 回退路径列表
        $allPaths = @(
            "$env:APPDATA\Code",
            "$env:APPDATA\Cursor",
            "$env:APPDATA\Code - Insiders",
            "$env:APPDATA\Code - Exploration",
            "$env:LOCALAPPDATA\Code",
            "$env:LOCALAPPDATA\Cursor",
            "$env:LOCALAPPDATA\Code - Insiders",
            "$env:LOCALAPPDATA\VSCodium"
        )
    }
    
    foreach ($path in $allPaths) {
        if (Test-Path $path) {
            Write-LogInfo "Found installation: $path"
            
            $installation = @{
                Path = $path
                Type = Split-Path $path -Leaf
                StorageFiles = @()
                DatabaseFiles = @()
                WorkspaceFiles = @()
            }
            
            # 查找存储文件
            $storagePatterns = @(
                "$path\User\storage.json",
                "$path\User\globalStorage\storage.json"
            )
            
            foreach ($pattern in $storagePatterns) {
                if (Test-Path $pattern) {
                    $installation.StorageFiles += $pattern
                    Write-LogDebug "Found storage file: $pattern"
                }
            }
            
            # 查找数据库文件
            $dbPatterns = @(
                "$path\User\globalStorage\state.vscdb",
                "$path\User\workspaceStorage\*\state.vscdb"
            )
            
            foreach ($dbPattern in $dbPatterns) {
                $dbFiles = Get-ChildItem -Path $dbPattern -ErrorAction SilentlyContinue
                foreach ($dbFile in $dbFiles) {
                    $installation.DatabaseFiles += $dbFile.FullName
                    Write-LogDebug "Found database file: $($dbFile.FullName)"
                }
            }
            
            # 查找工作区文件
            $workspacePattern = "$path\User\workspaceStorage\*\workspace.json"
            $workspaceFiles = Get-ChildItem -Path $workspacePattern -ErrorAction SilentlyContinue
            foreach ($file in $workspaceFiles) {
                $installation.WorkspaceFiles += $file.FullName
                Write-LogDebug "Found workspace file: $($file.FullName)"
            }
            
            if ($installation.StorageFiles.Count -gt 0 -or $installation.DatabaseFiles.Count -gt 0 -or $installation.WorkspaceFiles.Count -gt 0) {
                $installations += $installation
            }
        }
    }
    
    Write-LogInfo "Total installations found: $($installations.Count)"
    return $installations
}

# 统一的SQLite查询函数
function Invoke-UnifiedSQLiteQuery {
    <#
    .SYNOPSIS
        统一的SQLite查询执行函数
    .DESCRIPTION
        标准化的SQLite查询执行，包含错误处理和日志记录
    .PARAMETER DatabasePath
        数据库文件路径
    .PARAMETER Query
        要执行的SQL查询
    .PARAMETER ReturnOutput
        是否返回查询输出
    .OUTPUTS
        [object] 查询结果或执行状态
    .EXAMPLE
        $result = Invoke-UnifiedSQLiteQuery -DatabasePath $dbPath -Query $sql -ReturnOutput
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,
        
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [Parameter(Mandatory = $false)]
        [switch]$ReturnOutput
    )

    try {
        Write-LogDebug "Executing SQLite query on: $DatabasePath"
        Write-LogDebug "Query: $Query"
        
        if ($ReturnOutput) {
            $result = & sqlite3 $DatabasePath $Query 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-LogDebug "Query executed successfully, returned $($result.Count) rows"
                return $result
            } else {
                Write-LogWarning "Query execution failed with exit code: $LASTEXITCODE"
                return $null
            }
        } else {
            & sqlite3 $DatabasePath $Query 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-LogDebug "Query executed successfully"
                return $true
            } else {
                Write-LogWarning "Query execution failed with exit code: $LASTEXITCODE"
                return $false
            }
        }
    } catch {
        Write-LogError "SQLite query exception: $($_.Exception.Message)"
        return if ($ReturnOutput) { $null } else { $false }
    }
}

#endregion

#region 导出信息

# 记录导入状态
Write-LogInfo "Standard imports loaded successfully"
Write-LogDebug "Logger available: $Global:LoggerAvailable"
Write-LogDebug "Utilities available: $Global:UtilitiesAvailable"
Write-LogDebug "Config manager available: $Global:ConfigManagerAvailable"

#endregion

