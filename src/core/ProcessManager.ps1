# ProcessManager.ps1
# 进程检测和管理模块
# 支持多种VS Code变体的检测和强制结束

# 全局变量
$script:ProcessConfig = $null
$script:DetectedProcesses = @()

# 加载进程配置
function Load-ProcessConfig {
    param([string]$ConfigPath = "")
    
    try {
        if ([string]::IsNullOrEmpty($ConfigPath)) {
            $ConfigPath = Join-Path $PSScriptRoot "..\config\process_config.json"
        }
        
        if (-not (Test-Path $ConfigPath)) {
            Write-Warning "进程配置文件未找到: $ConfigPath"
            return $false
        }
        
        $configContent = Get-Content $ConfigPath -Raw -Encoding UTF8
        $script:ProcessConfig = $configContent | ConvertFrom-Json
        
        Write-Host "✓ 进程配置加载成功" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Error "加载进程配置失败: $($_.Exception.Message)"
        return $false
    }
}

# 检测所有支持的VS Code进程
function Find-VSCodeProcesses {
    param([bool]$Detailed = $false)
    
    if (-not $script:ProcessConfig) {
        Write-Warning "进程配置未加载，使用默认配置"
        if (-not (Load-ProcessConfig)) {
            return @()
        }
    }
    
    $detectedProcesses = @()
    $allProcesses = Get-Process -ErrorAction SilentlyContinue
    
    Write-Host "正在检测VS Code相关进程..." -ForegroundColor Cyan
    
    foreach ($processType in $script:ProcessConfig.supported_processes.PSObject.Properties) {
        $processInfo = $processType.Value
        $processNames = $processInfo.process_names
        
        foreach ($processName in $processNames) {
            # 移除.exe扩展名进行匹配
            $nameWithoutExt = $processName -replace '\.exe$', ''
            
            $matchingProcesses = $allProcesses | Where-Object { 
                $_.ProcessName -eq $nameWithoutExt -or 
                $_.ProcessName -eq $processName -or
                $_.Name -eq $processName
            }
            
            foreach ($process in $matchingProcesses) {
                $processDetail = @{
                    Process = $process
                    ProcessId = $process.Id
                    ProcessName = $process.ProcessName
                    DisplayName = $processInfo.display_name
                    Priority = $processInfo.priority
                    CloseMethod = $processInfo.close_method
                    StartTime = $process.StartTime
                    WorkingSet = [math]::Round($process.WorkingSet64 / 1MB, 2)
                    MainWindowTitle = $process.MainWindowTitle
                }
                
                $detectedProcesses += $processDetail
                
                if ($Detailed) {
                    Write-Host "  发现进程: $($processInfo.display_name) (PID: $($process.Id))" -ForegroundColor Yellow
                    Write-Host "    进程名: $($process.ProcessName)" -ForegroundColor Gray
                    Write-Host "    内存使用: $($processDetail.WorkingSet) MB" -ForegroundColor Gray
                    if ($process.MainWindowTitle) {
                        Write-Host "    窗口标题: $($process.MainWindowTitle)" -ForegroundColor Gray
                    }
                }
            }
        }
    }
    
    # 按优先级排序
    $detectedProcesses = $detectedProcesses | Sort-Object Priority
    $script:DetectedProcesses = $detectedProcesses
    
    if ($detectedProcesses.Count -gt 0) {
        Write-Host "检测到 $($detectedProcesses.Count) 个VS Code相关进程" -ForegroundColor Yellow
    } else {
        Write-Host "未检测到VS Code相关进程" -ForegroundColor Green
    }
    
    return $detectedProcesses
}

# 显示检测到的进程信息
function Show-DetectedProcesses {
    param([array]$Processes)
    
    if ($Processes.Count -eq 0) {
        Write-Host "未检测到任何VS Code相关进程" -ForegroundColor Green
        return
    }
    
    Write-Host "`n检测到以下VS Code相关进程:" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Yellow
    
    for ($i = 0; $i -lt $Processes.Count; $i++) {
        $proc = $Processes[$i]
        Write-Host "[$($i + 1)] $($proc.DisplayName)" -ForegroundColor Cyan
        Write-Host "    进程ID: $($proc.ProcessId)" -ForegroundColor Gray
        Write-Host "    进程名: $($proc.ProcessName)" -ForegroundColor Gray
        Write-Host "    内存使用: $($proc.WorkingSet) MB" -ForegroundColor Gray
        Write-Host "    启动时间: $($proc.StartTime)" -ForegroundColor Gray
        if ($proc.MainWindowTitle) {
            Write-Host "    窗口标题: $($proc.MainWindowTitle)" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

# 用户交互选择
function Get-UserChoice {
    param([array]$Processes)
    
    if (-not $script:ProcessConfig.user_interaction.prompt_before_close) {
        return "force_close"
    }
    
    Write-Host "请选择操作:" -ForegroundColor Yellow
    Write-Host "[1] 强制关闭所有检测到的进程" -ForegroundColor Red
    Write-Host "[2] 跳过进程检测，继续执行" -ForegroundColor Green
    Write-Host "[3] 取消操作" -ForegroundColor Gray
    Write-Host ""
    
    do {
        $choice = Read-Host "请输入选择 (1-3)"
        switch ($choice) {
            "1" { return "force_close" }
            "2" { return "skip" }
            "3" { return "cancel" }
            default { 
                Write-Host "无效选择，请输入 1、2 或 3" -ForegroundColor Red 
            }
        }
    } while ($true)
}

# 优雅关闭进程
function Close-ProcessGracefully {
    param(
        [System.Diagnostics.Process]$Process,
        [int]$TimeoutSeconds = 10
    )

    try {
        Write-Host "尝试优雅关闭进程: $($Process.ProcessName) (PID: $($Process.Id))" -ForegroundColor Cyan

        # 方法1: 关闭主窗口
        if ($Process.MainWindowHandle -ne [System.IntPtr]::Zero) {
            Write-Host "  发送关闭窗口消息..." -ForegroundColor Gray
            $Process.CloseMainWindow() | Out-Null

            # 等待进程退出
            if ($Process.WaitForExit($TimeoutSeconds * 1000)) {
                Write-Host "  ✓ 进程已优雅关闭" -ForegroundColor Green
                return $true
            }
        }

        return $false

    } catch {
        Write-Host "  优雅关闭失败: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# 强制结束进程
function Stop-ProcessForcefully {
    param(
        [System.Diagnostics.Process]$Process,
        [int]$TimeoutSeconds = 5
    )

    try {
        Write-Host "强制结束进程: $($Process.ProcessName) (PID: $($Process.Id))" -ForegroundColor Red

        # 刷新进程状态
        $Process.Refresh()
        if ($Process.HasExited) {
            Write-Host "  进程已退出" -ForegroundColor Green
            return $true
        }

        # 强制结束
        $Process.Kill()

        # 等待确认结束
        if ($Process.WaitForExit($TimeoutSeconds * 1000)) {
            Write-Host "  ✓ 进程已强制结束" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ⚠ 进程可能未完全结束" -ForegroundColor Yellow
            return $false
        }

    } catch {
        Write-Host "  强制结束失败: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# 关闭单个进程（按配置的方法）
function Close-SingleProcess {
    param(
        [hashtable]$ProcessDetail,
        [string]$Method = "graceful_first"
    )

    $process = $ProcessDetail.Process
    $closeMethod = $script:ProcessConfig.close_methods.$Method

    if (-not $closeMethod) {
        Write-Warning "未知的关闭方法: $Method，使用默认方法"
        $Method = "graceful_first"
        $closeMethod = $script:ProcessConfig.close_methods.$Method
    }

    Write-Host "关闭进程: $($ProcessDetail.DisplayName) (PID: $($ProcessDetail.ProcessId))" -ForegroundColor Cyan

    foreach ($step in $closeMethod.steps) {
        # 检查进程是否已退出
        $process.Refresh()
        if ($process.HasExited) {
            Write-Host "  ✓ 进程已退出" -ForegroundColor Green
            return $true
        }

        $success = $false
        switch ($step.method) {
            "close_main_window" {
                $success = Close-ProcessGracefully -Process $process -TimeoutSeconds $step.timeout
            }
            "terminate_process" {
                try {
                    Write-Host "  尝试终止进程..." -ForegroundColor Gray
                    $process.Kill()
                    $success = $process.WaitForExit($step.timeout * 1000)
                } catch {
                    Write-Host "  终止进程失败: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
            "kill_process" {
                $success = Stop-ProcessForcefully -Process $process -TimeoutSeconds $step.timeout
            }
        }

        if ($success) {
            return $true
        }

        Write-Host "  $($step.description) 失败，尝试下一种方法..." -ForegroundColor Yellow
    }

    Write-Host "  ✗ 所有关闭方法都失败了" -ForegroundColor Red
    return $false
}

# 关闭所有检测到的进程
function Close-AllDetectedProcesses {
    param([array]$Processes)

    if ($Processes.Count -eq 0) {
        Write-Host "没有需要关闭的进程" -ForegroundColor Green
        return $true
    }

    Write-Host "`n开始关闭检测到的进程..." -ForegroundColor Yellow
    Write-Host "=" * 50 -ForegroundColor Yellow

    $successCount = 0
    $failCount = 0

    foreach ($processDetail in $Processes) {
        try {
            if (Close-SingleProcess -ProcessDetail $processDetail -Method $processDetail.CloseMethod) {
                $successCount++
            } else {
                $failCount++
            }
        } catch {
            Write-Host "关闭进程时发生异常: $($_.Exception.Message)" -ForegroundColor Red
            $failCount++
        }

        Start-Sleep -Milliseconds 500  # 短暂延迟
    }

    Write-Host "`n进程关闭结果:" -ForegroundColor Yellow
    Write-Host "  成功关闭: $successCount" -ForegroundColor Green
    Write-Host "  关闭失败: $failCount" -ForegroundColor Red

    return ($failCount -eq 0)
}

# 主要的进程检测和处理函数
function Invoke-ProcessDetectionAndHandling {
    param(
        [bool]$AutoClose = $false,
        [bool]$Interactive = $true
    )

    Write-Host "`n=== VS Code 进程检测和管理 ===" -ForegroundColor Cyan

    # 加载配置
    if (-not $script:ProcessConfig) {
        if (-not (Load-ProcessConfig)) {
            Write-Warning "无法加载进程配置，跳过进程检测"
            return $true
        }
    }

    # 检测进程
    $detectedProcesses = Find-VSCodeProcesses -Detailed $true

    if ($detectedProcesses.Count -eq 0) {
        Write-Host "✓ 未检测到VS Code相关进程，可以安全继续" -ForegroundColor Green
        return $true
    }

    # 显示检测到的进程
    Show-DetectedProcesses -Processes $detectedProcesses

    # 决定处理方式
    $action = "prompt"
    if ($AutoClose) {
        $action = "force_close"
    } elseif ($Interactive) {
        $action = Get-UserChoice -Processes $detectedProcesses
    }

    switch ($action) {
        "force_close" {
            Write-Host "`n正在强制关闭所有检测到的进程..." -ForegroundColor Yellow
            return Close-AllDetectedProcesses -Processes $detectedProcesses
        }
        "skip" {
            Write-Host "`n⚠ 跳过进程处理，继续执行（可能会遇到文件锁定问题）" -ForegroundColor Yellow
            return $true
        }
        "cancel" {
            Write-Host "`n操作已取消" -ForegroundColor Gray
            return $false
        }
        default {
            Write-Host "`n未知操作，取消执行" -ForegroundColor Red
            return $false
        }
    }
}

# 导出函数
Export-ModuleMember -Function @(
    'Load-ProcessConfig',
    'Find-VSCodeProcesses',
    'Show-DetectedProcesses',
    'Close-AllDetectedProcesses',
    'Invoke-ProcessDetectionAndHandling'
)

# 关闭单个进程（按配置的方法）
function Close-SingleProcess {
    param(
        [hashtable]$ProcessDetail,
        [string]$Method = "graceful_first"
    )

    $process = $ProcessDetail.Process
    $closeMethod = $script:ProcessConfig.close_methods.$Method

    if (-not $closeMethod) {
        Write-Warning "未知的关闭方法: $Method，使用默认方法"
        $Method = "graceful_first"
        $closeMethod = $script:ProcessConfig.close_methods.$Method
    }

    Write-Host "关闭进程: $($ProcessDetail.DisplayName) (PID: $($ProcessDetail.ProcessId))" -ForegroundColor Cyan

    foreach ($step in $closeMethod.steps) {
        # 检查进程是否已退出
        $process.Refresh()
        if ($process.HasExited) {
            Write-Host "  ✓ 进程已退出" -ForegroundColor Green
            return $true
        }

        $success = $false
        switch ($step.method) {
            "close_main_window" {
                $success = Close-ProcessGracefully -Process $process -TimeoutSeconds $step.timeout
            }
            "terminate_process" {
                try {
                    Write-Host "  尝试终止进程..." -ForegroundColor Gray
                    $process.Kill()
                    $success = $process.WaitForExit($step.timeout * 1000)
                } catch {
                    Write-Host "  终止进程失败: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
            "kill_process" {
                $success = Stop-ProcessForcefully -Process $process -TimeoutSeconds $step.timeout
            }
        }

        if ($success) {
            return $true
        }

        Write-Host "  $($step.description) 失败，尝试下一种方法..." -ForegroundColor Yellow
    }

    Write-Host "  ✗ 所有关闭方法都失败了" -ForegroundColor Red
    return $false
}

# 关闭所有检测到的进程
function Close-AllDetectedProcesses {
    param([array]$Processes)

    if ($Processes.Count -eq 0) {
        Write-Host "没有需要关闭的进程" -ForegroundColor Green
        return $true
    }

    Write-Host "`n开始关闭检测到的进程..." -ForegroundColor Yellow
    Write-Host "=" * 50 -ForegroundColor Yellow

    $successCount = 0
    $failCount = 0

    foreach ($processDetail in $Processes) {
        try {
            if (Close-SingleProcess -ProcessDetail $processDetail -Method $processDetail.CloseMethod) {
                $successCount++
            } else {
                $failCount++
            }
        } catch {
            Write-Host "关闭进程时发生异常: $($_.Exception.Message)" -ForegroundColor Red
            $failCount++
        }

        Start-Sleep -Milliseconds 500  # 短暂延迟
    }

    Write-Host "`n进程关闭结果:" -ForegroundColor Yellow
    Write-Host "  成功关闭: $successCount" -ForegroundColor Green
    Write-Host "  关闭失败: $failCount" -ForegroundColor Red

    return ($failCount -eq 0)
}
