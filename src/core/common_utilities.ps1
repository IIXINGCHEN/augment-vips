# common_utilities.ps1
# 公共工具函数库 - Augment VIP 2.0 通用功能模块
# 版本: 2.1.0
# 功能: 提供跨模块的通用功能，减少代码重复，提高维护性

param(
    [switch]$Verbose = $false
)

# 设置错误处理
$ErrorActionPreference = "Stop"
$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }

#region 路径和文件操作工具

<#
.SYNOPSIS
    获取VS Code和Cursor的标准安装路径
.DESCRIPTION
    返回所有可能的VS Code和Cursor安装路径，包括用户级和系统级安装
.OUTPUTS
    [hashtable] 包含分类路径的哈希表
.EXAMPLE
    $paths = Get-StandardVSCodePaths
    $paths.VSCodeStandard | ForEach-Object { Write-Host $_ }
#>
function Get-StandardVSCodePaths {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    
    return @{
        # VS Code 标准路径
        VSCodeStandard = @(
            "$env:APPDATA\Code",
            "$env:LOCALAPPDATA\Code",
            "$env:APPDATA\Code - Insiders",
            "$env:LOCALAPPDATA\Code - Insiders"
        )
        
        # Cursor 路径
        CursorPaths = @(
            "$env:APPDATA\Cursor",
            "$env:LOCALAPPDATA\Cursor",
            "$env:APPDATA\Cursor - Insiders",
            "$env:LOCALAPPDATA\Cursor - Insiders"
        )
        
        # 用户配置路径
        UserConfig = @(
            "$env:USERPROFILE\.vscode",
            "$env:USERPROFILE\.cursor",
            "$env:USERPROFILE\.config\Code",
            "$env:USERPROFILE\.config\Cursor"
        )
        
        # 系统临时路径
        TempPaths = @(
            "$env:TEMP",
            "$env:TMP",
            "$env:LOCALAPPDATA\Temp",
            "$env:USERPROFILE\AppData\Local\Temp"
        )
        
        # 注册表路径
        RegistryPaths = @(
            "HKCU:\Software\Microsoft\VSCode",
            "HKCU:\Software\Cursor",
            "HKCU:\Software\Classes\Applications\Code.exe",
            "HKCU:\Software\Classes\Applications\Cursor.exe",
            "HKLM:\Software\Microsoft\VSCode",
            "HKLM:\Software\Cursor"
        )
    }
}

<#
.SYNOPSIS
    安全地测试路径是否存在
.DESCRIPTION
    测试路径是否存在，包含错误处理和权限检查
.PARAMETER Path
    要测试的路径
.PARAMETER PathType
    路径类型：'File', 'Directory', 'Any'
.OUTPUTS
    [bool] 路径是否存在且可访问
.EXAMPLE
    if (Test-PathSafely "C:\Users\Test\file.txt" -PathType "File") { ... }
#>
function Test-PathSafely {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('File', 'Directory', 'Any')]
        [string]$PathType = 'Any'
    )
    
    try {
        if (-not (Test-Path $Path)) {
            return $false
        }
        
        $item = Get-Item $Path -ErrorAction SilentlyContinue
        if (-not $item) {
            return $false
        }
        
        switch ($PathType) {
            'File' { return -not $item.PSIsContainer }
            'Directory' { return $item.PSIsContainer }
            'Any' { return $true }
        }
        
        return $true
    } catch {
        Write-Verbose "路径测试失败: $Path - $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    安全地创建目录
.DESCRIPTION
    创建目录，包含权限检查和错误处理
.PARAMETER Path
    要创建的目录路径
.PARAMETER Force
    是否强制创建（覆盖现有文件）
.OUTPUTS
    [bool] 是否成功创建
.EXAMPLE
    New-DirectorySafely "C:\Temp\NewFolder" -Force
#>
function New-DirectorySafely {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    try {
        if (Test-Path $Path) {
            if ((Get-Item $Path).PSIsContainer) {
                Write-Verbose "目录已存在: $Path"
                return $true
            } elseif ($Force) {
                Remove-Item $Path -Force
            } else {
                Write-Warning "路径已存在且不是目录: $Path"
                return $false
            }
        }
        
        $null = New-Item -Path $Path -ItemType Directory -Force:$Force
        Write-Verbose "成功创建目录: $Path"
        return $true
    } catch {
        Write-Warning "创建目录失败: $Path - $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region 数据库操作工具

<#
.SYNOPSIS
    安全地执行SQLite查询
.DESCRIPTION
    执行SQLite查询，包含SQL注入防护和错误处理
.PARAMETER DatabasePath
    数据库文件路径
.PARAMETER Query
    要执行的SQL查询
.PARAMETER QueryType
    查询类型：'Select', 'Update', 'Delete', 'Insert'
.OUTPUTS
    [object] 查询结果或操作状态
.EXAMPLE
    $result = Invoke-SQLiteQuerySafely "C:\db.sqlite" "SELECT COUNT(*) FROM table" -QueryType "Select"
#>
function Invoke-SQLiteQuerySafely {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,
        
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Select', 'Update', 'Delete', 'Insert', 'Pragma')]
        [string]$QueryType = 'Select',
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30
    )
    
    # 验证数据库文件
    if (-not (Test-PathSafely $DatabasePath -PathType "File")) {
        throw "数据库文件不存在或无法访问: $DatabasePath"
    }
    
    # 验证查询安全性
    if (-not (Test-QuerySafety $Query $QueryType)) {
        throw "查询未通过安全验证: $Query"
    }
    
    try {
        # 设置超时参数
        $timeoutArg = ".timeout $TimeoutSeconds"
        
        # 执行查询
        $result = sqlite3 -cmd $timeoutArg $DatabasePath $Query 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "SQLite查询执行失败: $result"
        }
        
        Write-Verbose "SQLite查询执行成功: $Query"
        return $result
    } catch {
        Write-Error "SQLite查询执行异常: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    验证SQL查询的安全性
.DESCRIPTION
    检查SQL查询是否包含危险操作，防止SQL注入
.PARAMETER Query
    要验证的SQL查询
.PARAMETER ExpectedType
    期望的查询类型
.OUTPUTS
    [bool] 查询是否安全
.EXAMPLE
    if (Test-QuerySafety "SELECT * FROM table" "Select") { ... }
#>
function Test-QuerySafety {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [Parameter(Mandatory = $true)]
        [string]$ExpectedType
    )
    
    # 转换为小写进行检查
    $lowerQuery = $Query.ToLower().Trim()
    
    # 危险操作模式
    $dangerousPatterns = @(
        'drop\s+table',
        'drop\s+database',
        'truncate\s+table',
        'alter\s+table',
        'create\s+table',
        'exec\s*\(',
        'execute\s*\(',
        'sp_',
        'xp_',
        '--',
        '/\*',
        '\*/',
        ';.*\w',  # 多语句
        'union\s+select',
        'information_schema',
        'sys\.',
        'master\.'
    )
    
    # 检查危险模式
    foreach ($pattern in $dangerousPatterns) {
        if ($lowerQuery -match $pattern) {
            Write-Warning "查询包含危险模式: $pattern"
            return $false
        }
    }
    
    # 验证查询类型匹配
    $typePatterns = @{
        'Select' = '^select\s+'
        'Update' = '^update\s+'
        'Delete' = '^delete\s+'
        'Insert' = '^insert\s+'
        'Pragma' = '^pragma\s+'
    }
    
    if ($typePatterns.ContainsKey($ExpectedType)) {
        if (-not ($lowerQuery -match $typePatterns[$ExpectedType])) {
            Write-Warning "查询类型不匹配，期望: $ExpectedType，实际查询: $Query"
            return $false
        }
    }
    
    return $true
}

#endregion

#region 进度显示工具

<#
.SYNOPSIS
    显示进度条
.DESCRIPTION
    显示带有详细信息的进度条
.PARAMETER Activity
    活动名称
.PARAMETER Status
    当前状态
.PARAMETER PercentComplete
    完成百分比
.PARAMETER CurrentOperation
    当前操作
.PARAMETER SecondsRemaining
    预计剩余时间（秒）
.EXAMPLE
    Show-ProgressBar "清理数据库" "正在处理文件1/10" 10 "清理state.vscdb" 45
#>
function Show-ProgressBar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Activity,
        
        [Parameter(Mandatory = $true)]
        [string]$Status,
        
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 100)]
        [int]$PercentComplete,
        
        [Parameter(Mandatory = $false)]
        [string]$CurrentOperation = "",
        
        [Parameter(Mandatory = $false)]
        [int]$SecondsRemaining = -1
    )
    
    $progressParams = @{
        Activity = $Activity
        Status = $Status
        PercentComplete = $PercentComplete
    }
    
    if ($CurrentOperation) {
        $progressParams.CurrentOperation = $CurrentOperation
    }
    
    if ($SecondsRemaining -ge 0) {
        $progressParams.SecondsRemaining = $SecondsRemaining
    }
    
    Write-Progress @progressParams
}

<#
.SYNOPSIS
    创建进度跟踪器
.DESCRIPTION
    创建一个进度跟踪器对象，用于跟踪多步骤操作的进度
.PARAMETER TotalSteps
    总步骤数
.PARAMETER Activity
    活动名称
.OUTPUTS
    [hashtable] 进度跟踪器对象
.EXAMPLE
    $tracker = New-ProgressTracker 10 "数据库清理"
    Update-ProgressTracker $tracker "开始清理" 1
#>
function New-ProgressTracker {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [int]$TotalSteps,
        
        [Parameter(Mandatory = $true)]
        [string]$Activity
    )
    
    return @{
        TotalSteps = $TotalSteps
        CurrentStep = 0
        Activity = $Activity
        StartTime = Get-Date
        StepTimes = @()
    }
}

<#
.SYNOPSIS
    更新进度跟踪器
.DESCRIPTION
    更新进度跟踪器的状态并显示进度条
.PARAMETER Tracker
    进度跟踪器对象
.PARAMETER Status
    当前状态描述
.PARAMETER StepIncrement
    步骤增量（默认为1）
.EXAMPLE
    Update-ProgressTracker $tracker "正在清理数据库文件" 1
#>
function Update-ProgressTracker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Tracker,
        
        [Parameter(Mandatory = $true)]
        [string]$Status,
        
        [Parameter(Mandatory = $false)]
        [int]$StepIncrement = 1
    )
    
    $Tracker.CurrentStep += $StepIncrement
    $Tracker.StepTimes += Get-Date
    
    $percentComplete = [Math]::Min(100, [Math]::Round(($Tracker.CurrentStep / $Tracker.TotalSteps) * 100))
    
    # 计算预计剩余时间
    $secondsRemaining = -1
    if ($Tracker.CurrentStep -gt 1) {
        $elapsed = (Get-Date) - $Tracker.StartTime
        $avgTimePerStep = $elapsed.TotalSeconds / $Tracker.CurrentStep
        $remainingSteps = $Tracker.TotalSteps - $Tracker.CurrentStep
        $secondsRemaining = [Math]::Round($avgTimePerStep * $remainingSteps)
    }
    
    Show-ProgressBar -Activity $Tracker.Activity -Status $Status -PercentComplete $percentComplete -CurrentOperation "步骤 $($Tracker.CurrentStep)/$($Tracker.TotalSteps)" -SecondsRemaining $secondsRemaining
}

#endregion

# 导出所有公共函数
Export-ModuleMember -Function @(
    'Get-StandardVSCodePaths',
    'Test-PathSafely',
    'New-DirectorySafely',
    'Invoke-SQLiteQuerySafely',
    'Test-QuerySafety',
    'Show-ProgressBar',
    'New-ProgressTracker',
    'Update-ProgressTracker'
)
