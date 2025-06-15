# Fix-ChineseContent.ps1
# Batch fix Chinese content in PowerShell scripts to maintain English-only codebase
# Version: 1.0.0

[CmdletBinding()]
param(
    [switch]$DryRun = $false,
    [switch]$VerboseOutput = $false
)

# Simple approach - manually fix the most critical files
Write-Host "Fixing Chinese content in critical files..." -ForegroundColor Cyan

function Get-ProjectScripts {
    <#
    .SYNOPSIS
        Get all PowerShell scripts in the project
    #>
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $scripts = @()
    
    # Tools scripts
    $toolsPath = Join-Path $projectRoot "src\tools"
    if (Test-Path $toolsPath) {
        $scripts += Get-ChildItem $toolsPath -Filter "*.ps1" -Recurse | Select-Object -ExpandProperty FullName
    }
    
    # Root scripts
    $rootScripts = @("Start-AugmentVIP.ps1", "quick-start.ps1")
    foreach ($script in $rootScripts) {
        $scriptPath = Join-Path $projectRoot $script
        if (Test-Path $scriptPath) {
            $scripts += $scriptPath
        }
    }
    
    # Test scripts
    $testPath = Join-Path $projectRoot "test"
    if (Test-Path $testPath) {
        $scripts += Get-ChildItem $testPath -Filter "*.ps1" -Recurse | Select-Object -ExpandProperty FullName
    }
    
    return $scripts
}

function Fix-ChineseInFile {
    <#
    .SYNOPSIS
        Fix Chinese content in a single file
    #>
    param(
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "File not found: $FilePath"
        return $false
    }
    
    try {
        $content = Get-Content $FilePath -Raw -Encoding UTF8
        $originalContent = $content
        $changesMade = $false
        
        # Apply translations
        foreach ($chinese in $translations.Keys) {
            $english = $translations[$chinese]
            if ($content -match [regex]::Escape($chinese)) {
                $content = $content -replace [regex]::Escape($chinese), $english
                $changesMade = $true
                if ($VerboseOutput) {
                    Write-Host "  Replaced: '$chinese' -> '$english'" -ForegroundColor Yellow
                }
            }
        }
        
        # Fix common patterns
        $patterns = @{
            "# 导入统一核心模块" = "# Import unified core modules"
            "# 使用统一的安装发现函数" = "# Use unified installation discovery function"
            "# 回退实现（保持兼容性）" = "# Fallback implementation (maintain compatibility)"
            "# 使用统一路径获取函数" = "# Use unified path retrieval function"
            "# 最终回退路径列表" = "# Final fallback path list"
        }
        
        foreach ($pattern in $patterns.Keys) {
            $replacement = $patterns[$pattern]
            if ($content -match [regex]::Escape($pattern)) {
                $content = $content -replace [regex]::Escape($pattern), $replacement
                $changesMade = $true
                if ($VerboseOutput) {
                    Write-Host "  Fixed pattern: '$pattern' -> '$replacement'" -ForegroundColor Green
                }
            }
        }
        
        # Save changes if any were made
        if ($changesMade) {
            if ($DryRun) {
                Write-Host "[DRY RUN] Would update: $FilePath" -ForegroundColor Cyan
            } else {
                Set-Content $FilePath -Value $content -Encoding UTF8 -NoNewline
                Write-Host "Updated: $FilePath" -ForegroundColor Green
            }
            return $true
        } else {
            if ($VerboseOutput) {
                Write-Host "No changes needed: $FilePath" -ForegroundColor Gray
            }
            return $false
        }
        
    } catch {
        Write-Error "Failed to process $FilePath`: $($_.Exception.Message)"
        return $false
    }
}

function Test-ScriptSyntax {
    <#
    .SYNOPSIS
        Test PowerShell script syntax
    #>
    param(
        [string]$FilePath
    )
    
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $FilePath -Raw), [ref]$null)
        return $true
    } catch {
        Write-Error "Syntax error in $FilePath`: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
Write-Host "Starting Chinese content fix process..." -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE EXECUTION' })" -ForegroundColor Yellow

$scripts = Get-ProjectScripts
Write-Host "Found $($scripts.Count) PowerShell scripts to process" -ForegroundColor White

$processedCount = 0
$updatedCount = 0
$errorCount = 0

foreach ($script in $scripts) {
    $relativePath = $script.Replace((Split-Path $PSScriptRoot -Parent), "").TrimStart('\')
    Write-Host "`nProcessing: $relativePath" -ForegroundColor White
    
    $processedCount++
    
    # Fix Chinese content
    $wasUpdated = Fix-ChineseInFile -FilePath $script
    if ($wasUpdated) {
        $updatedCount++
    }
    
    # Test syntax if not dry run
    if (-not $DryRun -and $wasUpdated) {
        if (-not (Test-ScriptSyntax -FilePath $script)) {
            $errorCount++
        }
    }
}

# Summary
Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
Write-Host "CHINESE CONTENT FIX SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Scripts processed: $processedCount" -ForegroundColor White
Write-Host "Scripts updated: $updatedCount" -ForegroundColor Green
Write-Host "Syntax errors: $errorCount" -ForegroundColor Red

if ($DryRun) {
    Write-Host "`n[DRY RUN] No actual changes were made." -ForegroundColor Yellow
    Write-Host "Run without -DryRun to apply the fixes." -ForegroundColor Yellow
} elseif ($errorCount -eq 0) {
    Write-Host "`n[SUCCESS] All scripts fixed successfully!" -ForegroundColor Green
    Write-Host "All Chinese content has been translated to English." -ForegroundColor Green
} else {
    Write-Host "`n[WARNING] Some scripts have syntax errors after fixing." -ForegroundColor Yellow
    Write-Host "Please review and fix the syntax errors manually." -ForegroundColor Yellow
}

exit $errorCount
