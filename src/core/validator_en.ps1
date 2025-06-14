# validator_en.ps1
# Augment VIP Cleanup Validator - English Version
# Validates cleanup effectiveness and account logout status

param(
    [switch]$Verbose = $false,
    [switch]$DetailedReport = $false
)

$ErrorActionPreference = "Stop"
$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }

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

function Test-AugmentResidue {
    param([hashtable]$VSCodePaths)
    
    Write-ValidatorLog "INFO" "Checking for Augment residue files..."
    
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

function Test-DatabaseResidue {
    param([hashtable]$VSCodePaths)
    
    Write-ValidatorLog "INFO" "Checking database for Augment residue..."
    
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
                Write-ValidatorLog "WARNING" "Cannot check database: $($dbFile.FullName)"
            }
        }
    }
    
    return $databaseResidue
}

function Test-AuthenticationTokens {
    param([hashtable]$VSCodePaths)
    
    Write-ValidatorLog "INFO" "Checking for authentication token residue..."
    
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
    
    # Determine cleanup status
    if ($report.TotalIssues -eq 0) {
        $report.CleanupStatus = "COMPLETE"
        $report.Recommendations += "Cleanup complete, no Augment residue detected"
    } elseif ($report.TotalIssues -le 3) {
        $report.CleanupStatus = "MOSTLY_CLEAN"
        $report.Recommendations += "Cleanup mostly complete, minor residue detected"
        $report.Recommendations += "Consider manual deletion or re-run cleanup tool"
    } else {
        $report.CleanupStatus = "INCOMPLETE"
        $report.Recommendations += "Cleanup incomplete, significant residue detected"
        $report.Recommendations += "Recommend re-running with forensic mode"
        $report.Recommendations += "Ensure VS Code is completely closed before retry"
    }
    
    return $report
}

function Start-AugmentCleanupValidation {
    Write-ValidatorLog "INFO" "Starting Augment cleanup validation..."
    
    # Get VS Code paths
    $vscodePaths = Get-VSCodePaths
    if ($vscodePaths.Count -eq 0) {
        Write-ValidatorLog "WARNING" "No VS Code installations found"
        return
    }
    
    Write-ValidatorLog "INFO" "Found $($vscodePaths.Count) VS Code installation(s)"
    
    # Perform checks
    $fileResidue = Test-AugmentResidue $vscodePaths
    $databaseResidue = Test-DatabaseResidue $vscodePaths
    $authTokens = Test-AuthenticationTokens $vscodePaths
    
    # Generate report
    $report = Generate-CleanupReport $fileResidue $databaseResidue $authTokens
    
    # Display results
    Write-ValidatorLog "SUCCESS" "=== AUGMENT CLEANUP VALIDATION REPORT ==="
    Write-ValidatorLog "INFO" "Validation Time: $($report.Timestamp)"
    Write-ValidatorLog "INFO" "Cleanup Status: $($report.CleanupStatus)"
    Write-ValidatorLog "INFO" "File Residue: $($report.FileResidueCount) items"
    Write-ValidatorLog "INFO" "Database Residue: $($report.DatabaseResidueCount) items"
    Write-ValidatorLog "INFO" "Auth Tokens: $($report.AuthTokenCount) items"
    Write-ValidatorLog "INFO" "Total Issues: $($report.TotalIssues) items"
    
    foreach ($recommendation in $report.Recommendations) {
        Write-ValidatorLog "INFO" "Recommendation: $recommendation"
    }
    
    if ($DetailedReport -and $report.TotalIssues -gt 0) {
        Write-ValidatorLog "INFO" "=== DETAILED RESIDUE INFORMATION ==="
        
        if ($fileResidue.Count -gt 0) {
            Write-ValidatorLog "WARNING" "File residue found:"
            foreach ($file in $fileResidue) {
                Write-ValidatorLog "WARNING" "  $($file.Type): $($file.Path)"
            }
        }
        
        if ($databaseResidue.Count -gt 0) {
            Write-ValidatorLog "WARNING" "Database residue found:"
            foreach ($db in $databaseResidue) {
                Write-ValidatorLog "WARNING" "  Database: $($db.Database) ($($db.Count) entries)"
            }
        }
        
        if ($authTokens.Count -gt 0) {
            Write-ValidatorLog "WARNING" "Authentication tokens found:"
            foreach ($token in $authTokens) {
                Write-ValidatorLog "WARNING" "  Token: $($token.Path)"
            }
        }
    }
    
    Write-ValidatorLog "SUCCESS" "=== VALIDATION COMPLETE ==="
    
    return $report
}

# Execute validation
if ($MyInvocation.InvocationName -ne '.') {
    Start-AugmentCleanupValidation
}
