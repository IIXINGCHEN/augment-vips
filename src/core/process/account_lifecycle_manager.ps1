# account_lifecycle_manager.ps1
# 账号生命周期管理器 - Augment VIP 全面重构清理引擎核心模块
# 版本: 2.0.0
# 功能: 管理Augment账号的完整生命周期，实现安全的账号退出和状态重置

param(
    [string]$AccountAction = "logout",
    [switch]$ForceLogout = $false,
    [switch]$ClearTrialData = $true,
    [switch]$VerboseOutput = $false
)

# 设置错误处理
$ErrorActionPreference = "Stop"
$VerbosePreference = if ($VerboseOutput) { "Continue" } else { "SilentlyContinue" }

# 加载统一配置
. "$PSScriptRoot\ConfigLoader.ps1"
if (-not (Load-AugmentConfig)) {
    Write-Error "Failed to load unified configuration"
    exit 1
}

# Global account management configuration - now loaded from unified configuration
$script:AccountConfig = @{
    AuthenticationSources = @{
        VSCode = @{
            TokenPaths = (Get-FilePaths).Tokens
            SessionPaths = (Get-FilePaths).Sessions
            ConfigKeys = @(
                "github.gitAuthentication",
                "accounts.sync.enabled",
                "settingsSync.account"
            )
        }

        Augment = @{
            TokenPaths = (Get-FilePaths).Tokens
            SessionPaths = (Get-FilePaths).Sessions
            ConfigKeys = @(
                "augment.authentication",
                "augment.account",
                "augment.session",
                "context7.authentication",
                "context7.account"
            )
        }

        Trial = @{
            DataPaths = @(
                "User\globalStorage\*trial*\*",
                "User\workspaceStorage\*\*trial*"
            )
            ConfigKeys = @(
                "trial.status",
                "trial.remaining",
                "trial.expired",
                "license.check",
                "subscription.status"
            )
        }
    }

    IdentityData = @{
        MachineIdentifiers = @(
            (Get-TelemetryFields).MachineId,
            (Get-TelemetryFields).DeviceId,
            (Get-TelemetryFields).SqmId,
            (Get-TelemetryFields).MachineIdAlt,
            (Get-TelemetryFields).DeviceIdAlt,
            (Get-TelemetryFields).SqmIdAlt
        )

        SessionIdentifiers = @(
            "telemetry.sessionId",
            "sessionId",
            "installationId",
            "userId"
        )

        AuthTokens = @(
            "authToken",
            "accessToken",
            "refreshToken",
            "bearerToken",
            "apiKey"
        )
    }
}

# 日志函数
function Write-AccountLog {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] [ACCOUNT] $Message"
    
    switch ($Level) {
        "INFO" { Write-Host $logMessage -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "DEBUG" { if ($Verbose) { Write-Host $logMessage -ForegroundColor Gray } }
    }
}

# 账号生命周期管理器类
class AccountLifecycleManager {
    [hashtable]$DiscoveredData
    [hashtable]$AccountStatus
    [hashtable]$LogoutPlan
    [array]$AuthenticationSources
    [hashtable]$IdentityResetPlan
    
    AccountLifecycleManager([hashtable]$DiscoveredData) {
        $this.DiscoveredData = $DiscoveredData
        $this.AccountStatus = @{}
        $this.LogoutPlan = @{}
        $this.AuthenticationSources = @()
        $this.IdentityResetPlan = @{}
        
        $this.InitializeManager()
    }
    
    [void]InitializeManager() {
        Write-AccountLog "INFO" "初始化账号生命周期管理器"
        
        # 检测当前账号状态
        $this.DetectAccountStatus()
        
        # 识别认证源
        $this.IdentifyAuthenticationSources()
        
        Write-AccountLog "INFO" "账号管理器初始化完成"
    }
    
    # 检测账号状态
    [void]DetectAccountStatus() {
        Write-AccountLog "INFO" "正在检测账号状态..."
        
        $this.AccountStatus = @{
            VSCodeAccount = @{
                IsLoggedIn = $false
                AccountType = "None"
                LastActivity = $null
                TokensFound = 0
            }
            
            AugmentAccount = @{
                IsLoggedIn = $false
                AccountType = "None"
                TrialStatus = "Unknown"
                LastActivity = $null
                TokensFound = 0
            }
            
            TrialData = @{
                HasTrialData = $false
                TrialExpired = $false
                TrialRemaining = 0
                LicenseStatus = "Unknown"
            }
        }
        
        # 检测VS Code账号状态
        $this.DetectVSCodeAccount()
        
        # 检测Augment账号状态
        $this.DetectAugmentAccount()
        
        # 检测试用数据状态
        $this.DetectTrialDataStatus()
    }
    
    # 检测VS Code账号
    [void]DetectVSCodeAccount() {
        try {
            $vscodePaths = $script:AccountConfig.AuthenticationSources.VSCode.TokenPaths
            $tokenCount = 0
            
            foreach ($basePath in $this.GetVSCodeBasePaths()) {
                foreach ($tokenPath in $vscodePaths) {
                    $fullPath = Join-Path $basePath $tokenPath
                    $tokens = Get-ChildItem -Path $fullPath -Recurse -ErrorAction SilentlyContinue
                    $tokenCount += $tokens.Count
                }
            }
            
            $this.AccountStatus.VSCodeAccount.TokensFound = $tokenCount
            $this.AccountStatus.VSCodeAccount.IsLoggedIn = ($tokenCount -gt 0)
            
            if ($tokenCount -gt 0) {
                Write-AccountLog "INFO" "检测到VS Code账号登录状态 (令牌数: $tokenCount)"
            }
            
        } catch {
            Write-AccountLog "WARNING" "检测VS Code账号状态时出错: $($_.Exception.Message)"
        }
    }
    
    # 检测Augment账号
    [void]DetectAugmentAccount() {
        try {
            $augmentPaths = $script:AccountConfig.AuthenticationSources.Augment.TokenPaths
            $tokenCount = 0
            $lastActivity = $null
            
            foreach ($basePath in $this.GetVSCodeBasePaths()) {
                foreach ($tokenPath in $augmentPaths) {
                    $fullPath = Join-Path $basePath $tokenPath
                    $tokens = Get-ChildItem -Path $fullPath -Recurse -ErrorAction SilentlyContinue
                    
                    foreach ($token in $tokens) {
                        $tokenCount++
                        if ($token.LastWriteTime -gt $lastActivity) {
                            $lastActivity = $token.LastWriteTime
                        }
                    }
                }
            }
            
            $this.AccountStatus.AugmentAccount.TokensFound = $tokenCount
            $this.AccountStatus.AugmentAccount.IsLoggedIn = ($tokenCount -gt 0)
            $this.AccountStatus.AugmentAccount.LastActivity = $lastActivity
            
            if ($tokenCount -gt 0) {
                Write-AccountLog "INFO" "检测到Augment账号登录状态 (令牌数: $tokenCount, 最后活动: $lastActivity)"
            }
            
        } catch {
            Write-AccountLog "WARNING" "检测Augment账号状态时出错: $($_.Exception.Message)"
        }
    }
    
    # 检测试用数据状态
    [void]DetectTrialDataStatus() {
        try {
            $trialDataFound = $false
            $trialExpired = $false
            
            # 检查数据库中的试用数据
            foreach ($db in $this.DiscoveredData.Databases) {
                if ($this.CheckDatabaseForTrialData($db.Path)) {
                    $trialDataFound = $true
                    break
                }
            }
            
            # 检查配置文件中的试用数据
            foreach ($config in $this.DiscoveredData.ConfigFiles) {
                if ($this.CheckConfigForTrialData($config.Path)) {
                    $trialDataFound = $true
                    break
                }
            }
            
            $this.AccountStatus.TrialData.HasTrialData = $trialDataFound
            
            if ($trialDataFound) {
                Write-AccountLog "WARNING" "检测到试用账号数据，可能导致试用限制问题"
            }
            
        } catch {
            Write-AccountLog "WARNING" "检测试用数据状态时出错: $($_.Exception.Message)"
        }
    }
    
    # 检查数据库中的试用数据
    [bool]CheckDatabaseForTrialData([string]$DatabasePath) {
        try {
            if (-not (Test-Path $DatabasePath)) {
                return $false
            }
            
            $trialQuery = @"
SELECT COUNT(*) FROM ItemTable WHERE
    LOWER(key) LIKE '%trial%' OR
    LOWER(key) LIKE '%context7%' OR
    key LIKE '%trialPrompt%' OR
    key LIKE '%licenseCheck%' OR
    key LIKE '%subscription%'
LIMIT 1;
"@
            
            $result = sqlite3 $DatabasePath $trialQuery 2>$null
            return ([int]$result -gt 0)
            
        } catch {
            return $false
        }
    }
    
    # Check configuration files for trial data
    [bool]CheckConfigForTrialData([string]$ConfigPath) {
        try {
            if (-not (Test-Path $ConfigPath)) {
                return $false
            }
            
            $content = Get-Content $ConfigPath -Raw -ErrorAction SilentlyContinue
            if ([string]::IsNullOrEmpty($content)) {
                return $false
            }
            
            $trialKeywords = @("trial", "Trial", "context7", "Context7", "license", "subscription")
            
            foreach ($keyword in $trialKeywords) {
                if ($content -like "*$keyword*") {
                    return $true
                }
            }
            
            return $false
            
        } catch {
            return $false
        }
    }
    
    # Get VS Code base paths
    [array]GetVSCodeBasePaths() {
        return @(
            "$env:APPDATA\Code",
            "$env:LOCALAPPDATA\Code",
            "$env:APPDATA\Code - Insiders",
            "$env:LOCALAPPDATA\Code - Insiders",
            "$env:APPDATA\Cursor",
            "$env:LOCALAPPDATA\Cursor"
        ) | Where-Object { Test-Path $_ }
    }

    # 识别认证源
    [void]IdentifyAuthenticationSources() {
        Write-AccountLog "INFO" "正在识别认证源..."

        $this.AuthenticationSources = @()

        foreach ($basePath in $this.GetVSCodeBasePaths()) {
            # 检查VS Code认证
            if ($this.HasVSCodeAuthentication($basePath)) {
                $this.AuthenticationSources += @{
                    Type = "VSCode"
                    BasePath = $basePath
                    Priority = "Medium"
                }
            }

            # 检查Augment认证
            if ($this.HasAugmentAuthentication($basePath)) {
                $this.AuthenticationSources += @{
                    Type = "Augment"
                    BasePath = $basePath
                    Priority = "High"
                }
            }
        }

        Write-AccountLog "INFO" "识别到 $($this.AuthenticationSources.Count) 个认证源"
    }

    # 检查VS Code认证
    [bool]HasVSCodeAuthentication([string]$BasePath) {
        $authPaths = $script:AccountConfig.AuthenticationSources.VSCode.TokenPaths

        foreach ($authPath in $authPaths) {
            $fullPath = Join-Path $BasePath $authPath
            if (Get-ChildItem -Path $fullPath -ErrorAction SilentlyContinue) {
                return $true
            }
        }

        return $false
    }

    # 检查Augment认证
    [bool]HasAugmentAuthentication([string]$BasePath) {
        $authPaths = $script:AccountConfig.AuthenticationSources.Augment.TokenPaths

        foreach ($authPath in $authPaths) {
            $fullPath = Join-Path $BasePath $authPath
            if (Get-ChildItem -Path $fullPath -ErrorAction SilentlyContinue) {
                return $true
            }
        }

        return $false
    }

    # 执行账号退出
    [hashtable]PerformAccountLogout() {
        Write-AccountLog "INFO" "开始执行账号退出流程..."

        $logoutResults = @{
            Success = $true
            VSCodeLogout = @{ Success = $false; Details = "" }
            AugmentLogout = @{ Success = $false; Details = "" }
            TrialDataCleared = @{ Success = $false; Details = "" }
            IdentityReset = @{ Success = $false; Details = "" }
            Errors = @()
            Summary = ""
        }

        try {
            # 阶段1: VS Code账号退出
            if ($this.AccountStatus.VSCodeAccount.IsLoggedIn) {
                $logoutResults.VSCodeLogout = $this.LogoutVSCodeAccount()
            } else {
                $logoutResults.VSCodeLogout = @{ Success = $true; Details = "无需退出，未检测到登录状态" }
            }

            # 阶段2: Augment账号退出
            if ($this.AccountStatus.AugmentAccount.IsLoggedIn) {
                $logoutResults.AugmentLogout = $this.LogoutAugmentAccount()
            } else {
                $logoutResults.AugmentLogout = @{ Success = $true; Details = "无需退出，未检测到登录状态" }
            }

            # 阶段3: 清理试用数据
            if ($ClearTrialData -and $this.AccountStatus.TrialData.HasTrialData) {
                $logoutResults.TrialDataCleared = $this.ClearTrialData()
            } else {
                $logoutResults.TrialDataCleared = @{ Success = $true; Details = "无试用数据需要清理" }
            }

            # 阶段4: 重置身份标识
            $logoutResults.IdentityReset = $this.ResetIdentityData()

            # 计算总体结果
            $allSuccess = $logoutResults.VSCodeLogout.Success -and
                         $logoutResults.AugmentLogout.Success -and
                         $logoutResults.TrialDataCleared.Success -and
                         $logoutResults.IdentityReset.Success

            $logoutResults.Success = $allSuccess
            $logoutResults.Summary = if ($allSuccess) { "账号退出流程完全成功" } else { "账号退出流程部分成功" }

            Write-AccountLog "SUCCESS" $logoutResults.Summary
            return $logoutResults

        } catch {
            $logoutResults.Success = $false
            $logoutResults.Errors += $_.Exception.Message
            $logoutResults.Summary = "账号退出流程失败: $($_.Exception.Message)"

            Write-AccountLog "ERROR" $logoutResults.Summary
            return $logoutResults
        }
    }

    # 验证登出状态
    [hashtable]VerifyLogoutStatus() {
        Write-AccountLog "INFO" "验证登出状态..."

        $verificationResult = @{
            Success = $true
            VSCodeTokensRemaining = 0
            AugmentTokensRemaining = 0
            SessionsRemaining = 0
            Details = ""
        }

        try {
            # 重新检测账号状态
            $this.DetectAccountStatus()

            # 检查VS Code令牌残留
            $verificationResult.VSCodeTokensRemaining = $this.AccountStatus.VSCodeAccount.TokensFound

            # 检查Augment令牌残留
            $verificationResult.AugmentTokensRemaining = $this.AccountStatus.AugmentAccount.TokensFound

            # 检查会话残留
            $sessionCount = 0
            foreach ($basePath in $this.GetVSCodeBasePaths()) {
                $sessionPaths = $script:AccountConfig.AuthenticationSources.VSCode.SessionPaths +
                               $script:AccountConfig.AuthenticationSources.Augment.SessionPaths

                foreach ($sessionPath in $sessionPaths) {
                    $fullPath = Join-Path $basePath $sessionPath
                    if (Test-Path $fullPath) {
                        $sessionCount++
                    }
                }
            }
            $verificationResult.SessionsRemaining = $sessionCount

            # 判断登出是否成功
            if ($verificationResult.VSCodeTokensRemaining -eq 0 -and
                $verificationResult.AugmentTokensRemaining -eq 0 -and
                $verificationResult.SessionsRemaining -eq 0) {
                $verificationResult.Success = $true
                $verificationResult.Details = "登出验证成功，所有认证数据已清理"
            } else {
                $verificationResult.Success = $false
                $verificationResult.Details = "登出验证失败，仍有残留数据: VS Code令牌($($verificationResult.VSCodeTokensRemaining)), Augment令牌($($verificationResult.AugmentTokensRemaining)), 会话($($verificationResult.SessionsRemaining))"
            }

            Write-AccountLog "INFO" $verificationResult.Details

        } catch {
            $verificationResult.Success = $false
            $verificationResult.Details = "登出状态验证失败: $($_.Exception.Message)"
            Write-AccountLog "ERROR" $verificationResult.Details
        }

        return $verificationResult
    }

    # 增强的VS Code账号退出
    [hashtable]LogoutVSCodeAccount() {
        Write-AccountLog "INFO" "正在退出VS Code账号..."

        $result = @{ Success = $true; Details = ""; TokensCleared = 0; ConfigsCleared = 0; ForcedCleanups = 0 }

        try {
            # 扩展的认证令牌路径
            $extendedTokenPaths = $script:AccountConfig.AuthenticationSources.VSCode.TokenPaths + @(
                "User\globalStorage\ms-vscode.vscode-account\*",
                "User\globalStorage\github.vscode-pull-request-github\*",
                "User\globalStorage\ms-vscode-remote.remote-*\*",
                "User\globalStorage\ms-vscode.azure-account\*",
                "User\globalStorage\*.authentication\*",
                "User\workspaceStorage\*\vscode.authentication",
                "User\workspaceStorage\*\ms-vscode.vscode-account"
            )

            foreach ($source in $this.AuthenticationSources | Where-Object { $_.Type -eq "VSCode" }) {
                $basePath = $source.BasePath

                # 清理认证令牌（增强版）
                foreach ($tokenPath in $extendedTokenPaths) {
                    $fullPath = Join-Path $basePath $tokenPath
                    $tokens = Get-ChildItem -Path $fullPath -Recurse -ErrorAction SilentlyContinue

                    foreach ($token in $tokens) {
                        $maxRetries = 3
                        $retryCount = 0
                        $tokenCleared = $false

                        while ($retryCount -lt $maxRetries -and -not $tokenCleared) {
                            try {
                                # 检查文件是否被锁定
                                if ($this.IsFileLocked($token.FullName)) {
                                    Write-AccountLog "WARNING" "文件被锁定，尝试强制解锁: $($token.FullName)"
                                    $this.ForceUnlockFile($token.FullName)
                                    Start-Sleep -Milliseconds 500
                                }

                                # 尝试删除文件
                                Remove-Item $token.FullName -Force -Recurse -ErrorAction Stop
                                $result.TokensCleared++
                                $tokenCleared = $true
                                Write-AccountLog "DEBUG" "清理VS Code令牌: $($token.FullName)"

                            } catch {
                                $retryCount++
                                Write-AccountLog "WARNING" "清理令牌失败 (尝试 $retryCount/$maxRetries): $($token.FullName) - $($_.Exception.Message)"

                                if ($retryCount -lt $maxRetries) {
                                    Start-Sleep -Milliseconds (500 * $retryCount)
                                } else {
                                    # 最后尝试强制清理
                                    if ($this.ForceDeleteFile($token.FullName)) {
                                        $result.TokensCleared++
                                        $result.ForcedCleanups++
                                        $tokenCleared = $true
                                        Write-AccountLog "WARNING" "强制清理令牌成功: $($token.FullName)"
                                    } else {
                                        Write-AccountLog "ERROR" "无法清理令牌: $($token.FullName)"
                                    }
                                }
                            }
                        }
                    }
                }

                # 清理会话数据（增强版）
                $extendedSessionPaths = $script:AccountConfig.AuthenticationSources.VSCode.SessionPaths + @(
                    "User\workspaceStorage\*\ms-vscode.vscode-account",
                    "User\globalStorage\ms-vscode.vscode-account",
                    "User\globalStorage\vscode.authentication",
                    "User\state\*authentication*",
                    "User\logs\*authentication*"
                )

                foreach ($sessionPath in $extendedSessionPaths) {
                    $fullPath = Join-Path $basePath $sessionPath
                    if (Test-Path $fullPath) {
                        try {
                            Remove-Item $fullPath -Force -Recurse -ErrorAction Stop
                            $result.ConfigsCleared++
                            Write-AccountLog "DEBUG" "清理VS Code会话: $fullPath"
                        } catch {
                            Write-AccountLog "WARNING" "无法清理会话: $fullPath - $($_.Exception.Message)"

                            # 尝试强制清理
                            if ($this.ForceDeleteFile($fullPath)) {
                                $result.ConfigsCleared++
                                $result.ForcedCleanups++
                                Write-AccountLog "WARNING" "强制清理会话成功: $fullPath"
                            }
                        }
                    }
                }
            }

            $result.Details = "清理了 $($result.TokensCleared) 个令牌和 $($result.ConfigsCleared) 个配置"
            if ($result.ForcedCleanups -gt 0) {
                $result.Details += "，强制清理了 $($result.ForcedCleanups) 个项目"
            }

            Write-AccountLog "SUCCESS" "VS Code账号退出完成: $($result.Details)"

        } catch {
            $result.Success = $false
            $result.Details = "VS Code账号退出失败: $($_.Exception.Message)"
            Write-AccountLog "ERROR" $result.Details
        }

        return $result
    }

    # Augment账号退出
    [hashtable]LogoutAugmentAccount() {
        Write-AccountLog "INFO" "正在退出Augment账号..."

        $result = @{ Success = $true; Details = ""; TokensCleared = 0; ConfigsCleared = 0 }

        try {
            foreach ($source in $this.AuthenticationSources | Where-Object { $_.Type -eq "Augment" }) {
                $basePath = $source.BasePath

                # 清理Augment认证令牌
                foreach ($tokenPath in $script:AccountConfig.AuthenticationSources.Augment.TokenPaths) {
                    $fullPath = Join-Path $basePath $tokenPath
                    $tokens = Get-ChildItem -Path $fullPath -Recurse -ErrorAction SilentlyContinue

                    foreach ($token in $tokens) {
                        try {
                            Remove-Item $token.FullName -Force -Recurse
                            $result.TokensCleared++
                            Write-AccountLog "DEBUG" "清理Augment令牌: $($token.FullName)"
                        } catch {
                            Write-AccountLog "WARNING" "无法清理令牌: $($token.FullName) - $($_.Exception.Message)"
                        }
                    }
                }

                # 清理Augment会话数据
                foreach ($sessionPath in $script:AccountConfig.AuthenticationSources.Augment.SessionPaths) {
                    $fullPath = Join-Path $basePath $sessionPath
                    if (Test-Path $fullPath) {
                        try {
                            Remove-Item $fullPath -Force -Recurse
                            $result.ConfigsCleared++
                            Write-AccountLog "DEBUG" "清理Augment会话: $fullPath"
                        } catch {
                            Write-AccountLog "WARNING" "无法清理会话: $fullPath - $($_.Exception.Message)"
                        }
                    }
                }
            }

            $result.Details = "清理了 $($result.TokensCleared) 个令牌和 $($result.ConfigsCleared) 个配置"
            Write-AccountLog "SUCCESS" "Augment账号退出完成: $($result.Details)"

        } catch {
            $result.Success = $false
            $result.Details = "Augment账号退出失败: $($_.Exception.Message)"
            Write-AccountLog "ERROR" $result.Details
        }

        return $result
    }

    # 清理试用数据
    [hashtable]ClearTrialData() {
        Write-AccountLog "INFO" "正在清理试用账号数据..."

        $result = @{ Success = $true; Details = ""; DatabasesCleared = 0; ConfigsCleared = 0; EntriesRemoved = 0 }

        try {
            # 清理数据库中的试用数据
            foreach ($db in $this.DiscoveredData.Databases) {
                $entriesRemoved = $this.ClearTrialDataFromDatabase($db.Path)
                if ($entriesRemoved -gt 0) {
                    $result.DatabasesCleared++
                    $result.EntriesRemoved += $entriesRemoved
                    Write-AccountLog "SUCCESS" "从数据库清理试用数据: $($db.Path) ($entriesRemoved 条记录)"
                }
            }

            # 清理配置文件中的试用数据
            foreach ($config in $this.DiscoveredData.ConfigFiles) {
                if ($this.ClearTrialDataFromConfig($config.Path)) {
                    $result.ConfigsCleared++
                    Write-AccountLog "SUCCESS" "从配置文件清理试用数据: $($config.Path)"
                }
            }

            # 清理试用相关的全局存储
            $this.ClearTrialGlobalStorage()

            $result.Details = "清理了 $($result.DatabasesCleared) 个数据库，$($result.ConfigsCleared) 个配置文件，共 $($result.EntriesRemoved) 条记录"
            Write-AccountLog "SUCCESS" "试用数据清理完成: $($result.Details)"

        } catch {
            $result.Success = $false
            $result.Details = "试用数据清理失败: $($_.Exception.Message)"
            Write-AccountLog "ERROR" $result.Details
        }

        return $result
    }

    # 从数据库清理试用数据
    [int]ClearTrialDataFromDatabase([string]$DatabasePath) {
        try {
            if (-not (Test-Path $DatabasePath)) {
                return 0
            }

            # 创建备份
            $backupPath = "$DatabasePath.trial_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item $DatabasePath $backupPath

            # 全面的试用数据清理查询
            $trialCleanQuery = @"
DELETE FROM ItemTable WHERE
    -- 试用账号相关条目 (全面清理)
    LOWER(key) LIKE '%trial%' OR
    LOWER(key) LIKE '%context7%' OR
    key LIKE '%trialPrompt%' OR
    key LIKE '%trial-prompt%' OR
    key LIKE '%licenseCheck%' OR
    key LIKE '%license-check%' OR
    key LIKE '%trialExpired%' OR
    key LIKE '%trial-expired%' OR
    key LIKE '%trialRemaining%' OR
    key LIKE '%trial-remaining%' OR
    key LIKE '%trialStatus%' OR
    key LIKE '%trial-status%' OR
    key LIKE '%trialLimit%' OR
    key LIKE '%trial-limit%' OR
    key LIKE '%trialCount%' OR
    key LIKE '%trial-count%' OR
    key LIKE '%trialUsage%' OR
    key LIKE '%trial-usage%' OR
    key LIKE '%trialActivation%' OR
    key LIKE '%trial-activation%' OR
    key LIKE '%trialPeriod%' OR
    key LIKE '%trial-period%' OR
    key LIKE '%trialStartDate%' OR
    key LIKE '%trial-start-date%' OR
    key LIKE '%trialEndDate%' OR
    key LIKE '%trial-end-date%' OR
    LOWER(key) LIKE '%subscription%' OR
    key LIKE '%subscriptionStatus%' OR
    key LIKE '%subscription-status%' OR
    key LIKE '%licenseKey%' OR
    key LIKE '%license-key%' OR
    key LIKE '%licenseType%' OR
    key LIKE '%license-type%' OR
    key LIKE '%licenseExpiry%' OR
    key LIKE '%license-expiry%' OR

    -- Context7 特定数据
    key LIKE '%context7.trial%' OR
    key LIKE '%context7.license%' OR
    key LIKE '%context7.subscription%' OR

    -- Augment 试用相关
    key LIKE '%augment.trial%' OR
    key LIKE '%augment.license%' OR
    key LIKE '%augment.subscription%' OR

    -- 值中包含试用信息的条目
    LOWER(value) LIKE '%trial%' OR
    LOWER(value) LIKE '%context7%' OR
    LOWER(value) LIKE '%license%' OR
    LOWER(value) LIKE '%subscription%';
"@

            # 执行清理
            $result = sqlite3 $DatabasePath $trialCleanQuery

            # 获取删除的记录数
            $changesQuery = "SELECT changes();"
            $changesCount = sqlite3 $DatabasePath $changesQuery

            # 运行VACUUM回收空间
            sqlite3 $DatabasePath "VACUUM;"

            return [int]$changesCount

        } catch {
            Write-AccountLog "ERROR" "清理数据库试用数据失败: $DatabasePath - $($_.Exception.Message)"
            return 0
        }
    }

    # 从配置文件清理试用数据
    [bool]ClearTrialDataFromConfig([string]$ConfigPath) {
        try {
            if (-not (Test-Path $ConfigPath)) {
                return $false
            }

            $extension = [System.IO.Path]::GetExtension($ConfigPath).ToLower()

            if ($extension -eq '.json') {
                return $this.ClearTrialDataFromJsonConfig($ConfigPath)
            } else {
                return $this.ClearTrialDataFromTextConfig($ConfigPath)
            }

        } catch {
            Write-AccountLog "ERROR" "清理配置文件试用数据失败: $ConfigPath - $($_.Exception.Message)"
            return $false
        }
    }

    # 从JSON配置清理试用数据
    [bool]ClearTrialDataFromJsonConfig([string]$ConfigPath) {
        try {
            # 创建备份
            $backupPath = "$ConfigPath.trial_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item $ConfigPath $backupPath

            $content = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $modified = $false

            # 试用相关的配置键
            $trialKeys = @(
                "trial", "Trial", "TRIAL",
                "context7", "Context7", "CONTEXT7",
                "license", "License", "LICENSE",
                "subscription", "Subscription", "SUBSCRIPTION",
                "augment.trial", "augment.license", "augment.subscription"
            )

            foreach ($key in $trialKeys) {
                if ($content.PSObject.Properties.Name -contains $key) {
                    $content.PSObject.Properties.Remove($key)
                    $modified = $true
                    Write-AccountLog "DEBUG" "移除配置键: $key"
                }
            }

            if ($modified) {
                $content | ConvertTo-Json -Depth 10 -Compress | Set-Content $ConfigPath -Encoding UTF8
                return $true
            }

            return $false

        } catch {
            Write-AccountLog "ERROR" "清理JSON配置试用数据失败: $ConfigPath - $($_.Exception.Message)"
            return $false
        }
    }

    # 从文本配置清理试用数据
    [bool]ClearTrialDataFromTextConfig([string]$ConfigPath) {
        try {
            $content = Get-Content $ConfigPath -Raw
            $originalContent = $content

            # 移除包含试用关键词的行
            $lines = $content -split "`n"
            $filteredLines = @()

            foreach ($line in $lines) {
                $shouldKeep = $true

                $trialPatterns = @("trial", "Trial", "context7", "Context7", "license", "subscription")
                foreach ($pattern in $trialPatterns) {
                    if ($line -like "*$pattern*") {
                        $shouldKeep = $false
                        break
                    }
                }

                if ($shouldKeep) {
                    $filteredLines += $line
                }
            }

            $newContent = $filteredLines -join "`n"

            if ($newContent -ne $originalContent) {
                # 创建备份
                $backupPath = "$ConfigPath.trial_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Copy-Item $ConfigPath $backupPath

                Set-Content $ConfigPath $newContent -Encoding UTF8
                return $true
            }

            return $false

        } catch {
            Write-AccountLog "ERROR" "清理文本配置试用数据失败: $ConfigPath - $($_.Exception.Message)"
            return $false
        }
    }

    # 清理试用相关的全局存储
    [void]ClearTrialGlobalStorage() {
        try {
            foreach ($basePath in $this.GetVSCodeBasePaths()) {
                $trialPaths = $script:AccountConfig.AuthenticationSources.Trial.DataPaths

                foreach ($trialPath in $trialPaths) {
                    $fullPath = Join-Path $basePath $trialPath
                    $items = Get-ChildItem -Path $fullPath -Recurse -ErrorAction SilentlyContinue

                    foreach ($item in $items) {
                        try {
                            Remove-Item $item.FullName -Force -Recurse
                            Write-AccountLog "DEBUG" "清理试用存储: $($item.FullName)"
                        } catch {
                            Write-AccountLog "WARNING" "无法清理试用存储: $($item.FullName) - $($_.Exception.Message)"
                        }
                    }
                }
            }
        } catch {
            Write-AccountLog "WARNING" "清理试用全局存储时出错: $($_.Exception.Message)"
        }
    }

    # 重置身份数据
    [hashtable]ResetIdentityData() {
        Write-AccountLog "INFO" "正在重置身份标识数据..."

        $result = @{ Success = $true; Details = ""; IdentifiersReset = 0; ConfigsModified = 0 }

        try {
            # 生成新的身份标识
            $newIdentifiers = $this.GenerateNewIdentifiers()

            # 重置数据库中的身份标识
            foreach ($db in $this.DiscoveredData.Databases) {
                $resetCount = $this.ResetDatabaseIdentifiers($db.Path, $newIdentifiers)
                if ($resetCount -gt 0) {
                    $result.IdentifiersReset += $resetCount
                    Write-AccountLog "SUCCESS" "重置数据库身份标识: $($db.Path) ($resetCount 个标识)"
                }
            }

            # 重置配置文件中的身份标识
            foreach ($config in $this.DiscoveredData.ConfigFiles) {
                if ($this.ResetConfigIdentifiers($config.Path, $newIdentifiers)) {
                    $result.ConfigsModified++
                    Write-AccountLog "SUCCESS" "重置配置文件身份标识: $($config.Path)"
                }
            }

            $result.Details = "重置了 $($result.IdentifiersReset) 个身份标识，修改了 $($result.ConfigsModified) 个配置文件"
            Write-AccountLog "SUCCESS" "身份数据重置完成: $($result.Details)"

            # 记录新的身份标识
            Write-AccountLog "INFO" "新身份标识已生成:"
            Write-AccountLog "INFO" "  机器ID: $($newIdentifiers.MachineId)"
            Write-AccountLog "INFO" "  设备ID: $($newIdentifiers.DeviceId)"
            Write-AccountLog "INFO" "  会话ID: $($newIdentifiers.SessionId)"

        } catch {
            $result.Success = $false
            $result.Details = "身份数据重置失败: $($_.Exception.Message)"
            Write-AccountLog "ERROR" $result.Details
        }

        return $result
    }

    # 生成新的身份标识
    [hashtable]GenerateNewIdentifiers() {
        # 使用加密安全的随机数生成器
        $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()

        # 生成机器ID (64位十六进制)
        $machineIdBytes = New-Object byte[] 32
        $rng.GetBytes($machineIdBytes)
        $machineId = [System.BitConverter]::ToString($machineIdBytes) -replace '-', '' | ForEach-Object { $_.ToLower() }

        # 生成其他ID
        $deviceId = [System.Guid]::NewGuid().ToString()
        $sqmId = [System.Guid]::NewGuid().ToString()
        $sessionId = [System.Guid]::NewGuid().ToString()
        $installationId = [System.Guid]::NewGuid().ToString()
        $userId = [System.Guid]::NewGuid().ToString()

        $rng.Dispose()

        return @{
            MachineId = $machineId
            DeviceId = $deviceId
            SqmId = $sqmId
            SessionId = $sessionId
            InstallationId = $installationId
            UserId = $userId
            GeneratedAt = Get-Date
        }
    }

    # 重置数据库中的身份标识
    [int]ResetDatabaseIdentifiers([string]$DatabasePath, [hashtable]$NewIdentifiers) {
        try {
            if (-not (Test-Path $DatabasePath)) {
                return 0
            }

            # 创建备份
            $backupPath = "$DatabasePath.identity_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item $DatabasePath $backupPath

            $totalUpdated = 0

            # 更新各种身份标识
            $identifierMappings = @{
                "machineId" = $NewIdentifiers.MachineId
                "deviceId" = $NewIdentifiers.DeviceId
                "sqmId" = $NewIdentifiers.SqmId
                "sessionId" = $NewIdentifiers.SessionId
                "installationId" = $NewIdentifiers.InstallationId
                "userId" = $NewIdentifiers.UserId
                "telemetry.machineId" = $NewIdentifiers.MachineId
                "telemetry.devDeviceId" = $NewIdentifiers.DeviceId
                "telemetry.sqmId" = $NewIdentifiers.SqmId
                "telemetry.sessionId" = $NewIdentifiers.SessionId
                "telemetry.installationId" = $NewIdentifiers.InstallationId
                "telemetry.userId" = $NewIdentifiers.UserId
            }

            foreach ($oldKey in $identifierMappings.Keys) {
                $newValue = $identifierMappings[$oldKey]

                # 更新键匹配的记录
                $updateQuery = @"
UPDATE ItemTable
SET value = '$newValue'
WHERE key LIKE '%$oldKey%';
"@

                $result = sqlite3 $DatabasePath $updateQuery
                $changesQuery = "SELECT changes();"
                $changesCount = sqlite3 $DatabasePath $changesQuery
                $totalUpdated += [int]$changesCount

                # 更新值匹配的记录
                $updateValueQuery = @"
UPDATE ItemTable
SET value = '$newValue'
WHERE value LIKE '%$oldKey%';
"@

                $result = sqlite3 $DatabasePath $updateValueQuery
                $changesCount = sqlite3 $DatabasePath $changesQuery
                $totalUpdated += [int]$changesCount
            }

            # 运行VACUUM
            sqlite3 $DatabasePath "VACUUM;"

            return $totalUpdated

        } catch {
            Write-AccountLog "ERROR" "重置数据库身份标识失败: $DatabasePath - $($_.Exception.Message)"
            return 0
        }
    }

    # 重置配置文件中的身份标识
    [bool]ResetConfigIdentifiers([string]$ConfigPath, [hashtable]$NewIdentifiers) {
        try {
            if (-not (Test-Path $ConfigPath)) {
                return $false
            }

            $extension = [System.IO.Path]::GetExtension($ConfigPath).ToLower()

            if ($extension -eq '.json') {
                return $this.ResetJsonConfigIdentifiers($ConfigPath, $NewIdentifiers)
            } else {
                return $this.ResetTextConfigIdentifiers($ConfigPath, $NewIdentifiers)
            }

        } catch {
            Write-AccountLog "ERROR" "重置配置文件身份标识失败: $ConfigPath - $($_.Exception.Message)"
            return $false
        }
    }

    # 重置JSON配置中的身份标识
    [bool]ResetJsonConfigIdentifiers([string]$ConfigPath, [hashtable]$NewIdentifiers) {
        try {
            # 创建备份
            $backupPath = "$ConfigPath.identity_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item $ConfigPath $backupPath

            $content = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $modified = $false

            # 身份标识映射
            $identifierMappings = @{
                "telemetry.machineId" = $NewIdentifiers.MachineId
                "telemetry.devDeviceId" = $NewIdentifiers.DeviceId
                "telemetry.sqmId" = $NewIdentifiers.SqmId
                "telemetry.sessionId" = $NewIdentifiers.SessionId
                "telemetry.installationId" = $NewIdentifiers.InstallationId
                "telemetry.userId" = $NewIdentifiers.UserId
                "machineId" = $NewIdentifiers.MachineId
                "deviceId" = $NewIdentifiers.DeviceId
                "sqmId" = $NewIdentifiers.SqmId
                "sessionId" = $NewIdentifiers.SessionId
                "installationId" = $NewIdentifiers.InstallationId
                "userId" = $NewIdentifiers.UserId
            }

            foreach ($key in $identifierMappings.Keys) {
                if ($content.PSObject.Properties.Name -contains $key) {
                    $content.$key = $identifierMappings[$key]
                    $modified = $true
                    Write-AccountLog "DEBUG" "更新身份标识: $key"
                }
            }

            if ($modified) {
                $content | ConvertTo-Json -Depth 10 -Compress | Set-Content $ConfigPath -Encoding UTF8
                return $true
            }

            return $false

        } catch {
            Write-AccountLog "ERROR" "重置JSON配置身份标识失败: $ConfigPath - $($_.Exception.Message)"
            return $false
        }
    }

    # 检查文件是否被锁定
    [bool]IsFileLocked([string]$FilePath) {
        try {
            if (-not (Test-Path $FilePath)) {
                return $false
            }

            # 尝试以独占模式打开文件
            $fileStream = [System.IO.File]::Open($FilePath, 'Open', 'ReadWrite', 'None')
            $fileStream.Close()
            return $false

        } catch [System.IO.IOException] {
            # 文件被锁定
            return $true
        } catch {
            # 其他错误，假设文件可访问
            return $false
        }
    }

    # 强制解锁文件
    [bool]ForceUnlockFile([string]$FilePath) {
        try {
            Write-AccountLog "INFO" "尝试强制解锁文件: $FilePath"

            # 尝试终止可能锁定文件的进程
            $lockingProcesses = Get-Process | Where-Object {
                try {
                    $_.Modules | Where-Object { $_.FileName -eq $FilePath }
                } catch {
                    $null
                }
            }

            foreach ($process in $lockingProcesses) {
                try {
                    Write-AccountLog "WARNING" "终止锁定文件的进程: $($process.ProcessName) (PID: $($process.Id))"
                    $process.Kill()
                    Start-Sleep -Milliseconds 100
                } catch {
                    Write-AccountLog "WARNING" "无法终止进程: $($process.ProcessName)"
                }
            }

            return $true

        } catch {
            Write-AccountLog "ERROR" "强制解锁文件失败: $FilePath - $($_.Exception.Message)"
            return $false
        }
    }

    # 强制删除文件
    [bool]ForceDeleteFile([string]$FilePath) {
        try {
            Write-AccountLog "INFO" "尝试强制删除文件: $FilePath"

            # 方法1: 修改文件属性
            if (Test-Path $FilePath) {
                Set-ItemProperty -Path $FilePath -Name Attributes -Value Normal -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $FilePath -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
            }

            # 方法2: 使用.NET方法强制删除
            if (Test-Path $FilePath) {
                [System.IO.File]::Delete($FilePath)
                if (-not (Test-Path $FilePath)) {
                    Write-AccountLog "SUCCESS" "强制删除文件成功: $FilePath"
                    return $true
                }
            }

            # 方法3: 使用cmd命令
            if (Test-Path $FilePath) {
                $result = cmd /c "del /f /q `"$FilePath`"" 2>$null
                if (-not (Test-Path $FilePath)) {
                    Write-AccountLog "SUCCESS" "使用cmd强制删除文件成功: $FilePath"
                    return $true
                }
            }

            return $false

        } catch {
            Write-AccountLog "ERROR" "强制删除文件失败: $FilePath - $($_.Exception.Message)"
            return $false
        }
    }

    # 重置文本配置中的身份标识
    [bool]ResetTextConfigIdentifiers([string]$ConfigPath, [hashtable]$NewIdentifiers) {
        try {
            $content = Get-Content $ConfigPath -Raw
            $originalContent = $content

            # 替换身份标识
            $identifierMappings = @{
                "machineId" = $NewIdentifiers.MachineId
                "deviceId" = $NewIdentifiers.DeviceId
                "sqmId" = $NewIdentifiers.SqmId
                "sessionId" = $NewIdentifiers.SessionId
                "installationId" = $NewIdentifiers.InstallationId
                "userId" = $NewIdentifiers.UserId
            }

            foreach ($pattern in $identifierMappings.Keys) {
                $newValue = $identifierMappings[$pattern]
                # 使用正则表达式替换现有的ID值
                $content = $content -replace "$pattern[`"':\s]*[a-fA-F0-9\-]{8,64}", "$pattern`": `"$newValue`""
            }

            if ($content -ne $originalContent) {
                # 创建备份
                $backupPath = "$ConfigPath.identity_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Copy-Item $ConfigPath $backupPath

                Set-Content $ConfigPath $content -Encoding UTF8
                return $true
            }

            return $false

        } catch {
            Write-AccountLog "ERROR" "重置文本配置身份标识失败: $ConfigPath - $($_.Exception.Message)"
            return $false
        }
    }
}

# 主执行函数
function Start-AccountLifecycleManagement {
    param(
        [hashtable]$DiscoveredData,
        [string]$Action = "logout",
        [switch]$ForceLogout = $false,
        [switch]$ClearTrialData = $true,
        [switch]$Verbose = $false
    )

    try {
        $manager = [AccountLifecycleManager]::new($DiscoveredData)

        switch ($Action.ToLower()) {
            "logout" {
                return $manager.PerformAccountLogout()
            }
            "status" {
                return $manager.AccountStatus
            }
            "reset-identity" {
                return $manager.ResetIdentityData()
            }
            "clear-trial" {
                return $manager.ClearTrialData()
            }
            default {
                throw "未知操作: $Action"
            }
        }

    } catch {
        Write-AccountLog "ERROR" "账号生命周期管理失败: $($_.Exception.Message)"
        throw
    }
}

# 导出函数
Export-ModuleMember -Function Start-AccountLifecycleManagement
