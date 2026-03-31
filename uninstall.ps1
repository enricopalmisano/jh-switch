# jhSwitch Uninstaller Script
# This script removes jhSwitch from the system

Write-Host "=== jhSwitch Uninstaller ===" -ForegroundColor Red
Write-Host ""

# Get installation directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$installPath = $scriptPath

Write-Host "Removing jhSwitch from: $installPath" -ForegroundColor Yellow

# Check if directory exists
if (-not (Test-Path $installPath)) {
    Write-Host "Installation directory not found: $installPath" -ForegroundColor Red
    Write-Host "jhSwitch may not be installed or was already removed." -ForegroundColor Yellow
    exit 0
}

# Remove from PATH
Write-Host "Removing from PATH..." -ForegroundColor Yellow
try {
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -like "*$installPath*") {
        $newPath = $currentPath -replace [regex]::Escape(";$installPath"), ""
        $newPath = $newPath -replace [regex]::Escape("$installPath;"), ""
        $newPath = $newPath -replace [regex]::Escape($installPath), ""
        
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        Write-Host "  ✓ Removed from user PATH" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Not in PATH" -ForegroundColor Green
    }
} catch {
    Write-Host "  ✗ Failed to update PATH: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    You may need to remove $installPath from your PATH manually" -ForegroundColor Yellow
}

# Remove installation directory
Write-Host "Removing installation files..." -ForegroundColor Yellow
try {
    # Remove read-only attribute if present
    Get-ChildItem -Path $installPath -Recurse | ForEach-Object {
        if ($_.Attributes -band [System.IO.FileAttributes]::ReadOnly) {
            $_.Attributes = $_.Attributes -bxor [System.IO.FileAttributes]::ReadOnly
        }
    }
    
    Remove-Item -Path $installPath -Recurse -Force
    Write-Host "  ✓ Installation files removed" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to remove installation files: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    You may need to manually delete: $installPath" -ForegroundColor Yellow
}

# Clean up any remaining JDK files (optional)
$cleanupJdks = Read-Host "Do you also want to remove downloaded JDK files? (Y/N)"
if ($cleanupJdks -match '^[Yy]') {
    $jdkPath = Join-Path $env:USERPROFILE ".jhsdk"
    if (Test-Path $jdkPath) {
        try {
            Write-Host "Removing JDK files from: $jdkPath" -ForegroundColor Yellow
            Remove-Item -Path $jdkPath -Recurse -Force
            Write-Host "  ✓ JDK files removed" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ Failed to remove JDK files: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "No JDK files found to remove." -ForegroundColor Green
    }
    
    # Also remove config
    $configPath = Join-Path $env:USERPROFILE ".jhswitch"
    if (Test-Path $configPath) {
        try {
            Remove-Item -Path $configPath -Recurse -Force
            Write-Host "  ✓ Configuration files removed" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ Failed to remove config files: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "JDK files and configuration kept at:" -ForegroundColor Cyan
    Write-Host "  $env:USERPROFILE\.jhsdk" -ForegroundColor White
    Write-Host "  $env:USERPROFILE\.jhswitch" -ForegroundColor White
}

Write-Host ""
Write-Host "=== Uninstallation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "jhSwitch has been removed from your system." -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT:" -ForegroundColor Yellow
Write-Host "1. Close and reopen your terminal to update the PATH" -ForegroundColor White
Write-Host "2. The 'jhswitch' command will no longer be available" -ForegroundColor White
Write-Host ""
