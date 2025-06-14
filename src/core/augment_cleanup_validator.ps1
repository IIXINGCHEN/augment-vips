# augment_cleanup_validator.ps1
# Augment VIP 清理验证器 - 验证清理效果和账号登出状态
# 版本: 1.0.0
# 功能: 验证Augment账号是否已完全退出，检测残留数据

param(
    [switch]$Verbose = $false,
    [switch]$DetailedReport = $false
)

# 设置错误处理
$ErrorActionPreference = "Stop"
$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }

# 日志函数
function Write-ValidatorLog {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# 获取VS Code路径
function Get-VSCodePaths {
    $paths = @{}
    $appData = $env:APPDATA
    $localAppData = $env:LOCALAPPDATA
    
    $standardPaths = @(
        @{ Path = "$appData\Code"; Type = "Stable" },
        @{ Path = "$localAppData\Code"; Type = "Stable-Local" },
        @{ Path = "$appData\Code - Insiders"; Type = "Insiders" },
        @{ Path = "$localAppData\Code - Insiders"; Type = "Insiders-Local" }
    )
    
    foreach ($pathInfo in $standardPaths) {
        if (Test-Path $pathInfo.Path) {
            $paths[$pathInfo.Type] = $pathInfo.Path
        }
    }
    
    return $paths
}

# 检查Augment残留文件
function Test-AugmentResidue {
    param([hashtable]$VSCodePaths)
    
    Write-ValidatorLog "INFO" "检查Augment残留文件..."
    
    $residueFound = @()
    $augmentPatterns = @(
        "User\globalStorage\augment.*",
        "User\globalStorage\*augment*",
        "User\workspaceStorage\*\augment.*",
        "User\globalStorage\context7.*",
        "User\globalStorage\*context7*",
        "User\workspaceStorage\*\context7.*"
    )
    
    foreach ($basePath in $VSCodePaths.Values) {
        foreach ($pattern in $augmentPatterns) {
            $fullPath = Join-Path $basePath $pattern
            $items = Get-ChildItem -Path $fullPath -Recurse -ErrorAction SilentlyContinue
            
            foreach ($item in $items) {
                $residueFound += @{
                    Path = $item.FullName
                    Type = if ($item.PSIsContainer) { "Directory" } else { "File" }
                    Size = if (-not $item.PSIsContainer) { $item.Length } else { 0 }
                    LastModified = $item.LastWriteTime
                }
            }
        }
    }
    
    return $residueFound
}

# 检查数据库中的Augment数据
function Test-DatabaseResidue {
    param([hashtable]$VSCodePaths)
    
    Write-ValidatorLog "INFO" "检查数据库中的Augment残留数据..."
    
    $databaseResidue = @()
    
    foreach ($basePath in $VSCodePaths.Values) {
        $dbFiles = Get-ChildItem -Path "$basePath\User\workspaceStorage\*\state.vscdb" -ErrorAction SilentlyContinue
        
        foreach ($dbFile in $dbFiles) {
            try {
                $checkQuery = @"
SELECT key, value FROM ItemTable WHERE 
    LOWER(key) LIKE '%augment%' OR 
    LOWER(key) LIKE '%context7%' OR
    key LIKE '%trial%'
LIMIT 10;
"@
                $result = sqlite3 $dbFile.FullName $checkQuery 2>$null
                if ($result -and $result.Count -gt 0) {
                    $databaseResidue += @{
                        Database = $dbFile.FullName
                        Entries = $result
                        Count = $result.Count
                    }
                }
            } catch {
                Write-ValidatorLog "WARNING" "无法检查数据库: $($dbFile.FullName)"
            }
        }
    }
    
    return $databaseResidue
}

# 检查认证令牌
function Test-AuthenticationTokens {
    param([hashtable]$VSCodePaths)
    
    Write-ValidatorLog "INFO" "检查认证令牌残留..."
    
    $authTokens = @()
    
    foreach ($basePath in $VSCodePaths.Values) {
        $authPaths = @(
            "User\globalStorage\vscode.authentication",
            "User\globalStorage\ms-vscode.vscode-account"
        )
        
        foreach ($authPath in $authPaths) {
            $fullAuthPath = Join-Path $basePath $authPath
            if (Test-Path $fullAuthPath) {
                $authFiles = Get-ChildItem -Path $fullAuthPath -Recurse -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Name -match "augment|context7" }
                
                foreach ($authFile in $authFiles) {
                    $authTokens += @{
                        Path = $authFile.FullName
                        Name = $authFile.Name
                        Size = $authFile.Length
                        LastModified = $authFile.LastWriteTime
                    }
                }
            }
        }
    }
    
    return $authTokens
}

# 生成清理报告
function Generate-CleanupReport {
    param(
        [array]$FileResidue,
        [array]$DatabaseResidue, 
        [array]$AuthTokens
    )
    
    $report = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        CleanupStatus = "UNKNOWN"
        FileResidueCount = $FileResidue.Count
        DatabaseResidueCount = $DatabaseResidue.Count
        AuthTokenCount = $AuthTokens.Count
        TotalIssues = $FileResidue.Count + $DatabaseResidue.Count + $AuthTokens.Count
        Details = @{
            FileResidue = $FileResidue
            DatabaseResidue = $DatabaseResidue
            AuthTokens = $AuthTokens
        }
        Recommendations = @()
    }
    
    # 确定清理状态
    if ($report.TotalIssues -eq 0) {
        $report.CleanupStatus = "COMPLETE"
        $report.Recommendations += "清理完成，未发现Augment残留数据"
    } elseif ($report.TotalIssues -le 3) {
        $report.CleanupStatus = "MOSTLY_CLEAN"
        $report.Recommendations += "清理基本完成，发现少量残留数据"
        $report.Recommendations += "建议手动删除剩余文件或重新运行清理工具"
    } else {
        $report.CleanupStatus = "INCOMPLETE"
        $report.Recommendations += "清理不完整，发现大量残留数据"
        $report.Recommendations += "建议使用forensic模式重新运行清理工具"
        $report.Recommendations += "确保VS Code完全关闭后再次尝试"
    }
    
    return $report
}

# 主验证函数
function Start-AugmentCleanupValidation {
    Write-ValidatorLog "INFO" "开始Augment清理验证..."
    
    # 获取VS Code路径
    $vscodePaths = Get-VSCodePaths
    if ($vscodePaths.Count -eq 0) {
        Write-ValidatorLog "WARNING" "未找到VS Code安装"
        return
    }
    
    Write-ValidatorLog "INFO" "找到 $($vscodePaths.Count) 个VS Code安装"
    
    # 执行各项检查
    $fileResidue = Test-AugmentResidue $vscodePaths
    $databaseResidue = Test-DatabaseResidue $vscodePaths
    $authTokens = Test-AuthenticationTokens $vscodePaths
    
    # 生成报告
    $report = Generate-CleanupReport $fileResidue $databaseResidue $authTokens
    
    # 显示结果
    Write-ValidatorLog "SUCCESS" "=== AUGMENT 清理验证报告 ==="
    Write-ValidatorLog "INFO" "验证时间: $($report.Timestamp)"
    Write-ValidatorLog "INFO" "清理状态: $($report.CleanupStatus)"
    Write-ValidatorLog "INFO" "文件残留: $($report.FileResidueCount) 个"
    Write-ValidatorLog "INFO" "数据库残留: $($report.DatabaseResidueCount) 个"
    Write-ValidatorLog "INFO" "认证令牌: $($report.AuthTokenCount) 个"
    Write-ValidatorLog "INFO" "总问题数: $($report.TotalIssues) 个"
    
    foreach ($recommendation in $report.Recommendations) {
        Write-ValidatorLog "INFO" "建议: $recommendation"
    }
    
    if ($DetailedReport -and $report.TotalIssues -gt 0) {
        Write-ValidatorLog "INFO" "=== 详细残留信息 ==="
        
        if ($fileResidue.Count -gt 0) {
            Write-ValidatorLog "WARNING" "发现文件残留:"
            foreach ($file in $fileResidue) {
                Write-ValidatorLog "WARNING" "  $($file.Type): $($file.Path)"
            }
        }
        
        if ($databaseResidue.Count -gt 0) {
            Write-ValidatorLog "WARNING" "发现数据库残留:"
            foreach ($db in $databaseResidue) {
                Write-ValidatorLog "WARNING" "  数据库: $($db.Database) ($($db.Count) 条记录)"
            }
        }
        
        if ($authTokens.Count -gt 0) {
            Write-ValidatorLog "WARNING" "发现认证令牌:"
            foreach ($token in $authTokens) {
                Write-ValidatorLog "WARNING" "  令牌: $($token.Path)"
            }
        }
    }
    
    Write-ValidatorLog "SUCCESS" "=== 验证完成 ==="
    
    return $report
}

# 执行验证
if ($MyInvocation.InvocationName -ne '.') {
    Start-AugmentCleanupValidation
}
