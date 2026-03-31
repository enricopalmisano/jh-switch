# jhSwitch Installer Script
# This script installs jhSwitch globally on Windows

param(
    [switch]$Force,
    [string]$InstallPath = ""
)

Write-Host "=== jhSwitch Installer ===" -ForegroundColor Green
Write-Host ""

# Check if running as administrator (optional but recommended)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Determine installation directory
if ([string]::IsNullOrWhiteSpace($InstallPath)) {
    if ($isAdmin) {
        $InstallPath = "$env:ProgramFiles\jhswitch"
    } else {
        $InstallPath = "$env:LOCALAPPDATA\jhswitch"
    }
}

$InstallPath = $InstallPath.TrimEnd('\')

# Check if already installed
if (Test-Path $InstallPath) {
    if (-not $Force) {
        Write-Host "jhSwitch is already installed at: $InstallPath" -ForegroundColor Yellow
        $choice = Read-Host "Do you want to reinstall? (Y/N)"
        if ($choice -notmatch '^[Yy]') {
            Write-Host "Installation cancelled." -ForegroundColor Red
            exit 0
        }
    }
    Write-Host "Removing previous installation..." -ForegroundColor Yellow
    try {
        Remove-Item -Path $InstallPath -Recurse -Force
    } catch {
        Write-Host "Error removing previous installation: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Create installation directory
Write-Host "Installing to: $InstallPath" -ForegroundColor Cyan
try {
    New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
} catch {
    Write-Host "Error creating installation directory: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Get script directory (where this installer is located)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Copy files
$filesToCopy = @(
    "jhswitch.cmd",
    "jhswitch.ps1", 
    "providers.ps1",
    "README.md"
)

Write-Host "Copying files..." -ForegroundColor Cyan
foreach ($file in $filesToCopy) {
    $source = Join-Path $ScriptDir $file
    $destination = Join-Path $InstallPath $file
    
    if (Test-Path $source) {
        try {
            Copy-Item -Path $source -Destination $destination -Force
            Write-Host "  - $file copied successfully" -ForegroundColor Green
        } catch {
            $errorMsg = $_.Exception.Message
            Write-Host "  - Failed to copy $file`: $errorMsg" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  - File not found: $file" -ForegroundColor Red
        exit 1
    }
}

# Add to PATH
Write-Host "Adding to PATH..." -ForegroundColor Cyan
try {
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notlike "*$InstallPath*") {
        $newPath = $currentPath + ";" + $InstallPath
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        Write-Host "  - Added to user PATH" -ForegroundColor Green
    } else {
        Write-Host "  - Already in PATH" -ForegroundColor Green
    }
} catch {
    Write-Host "  - Failed to update PATH: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    You may need to add $InstallPath to your PATH manually" -ForegroundColor Yellow
}

# Create uninstall script
$uninstallScript = @"
@echo off
echo Uninstalling jhSwitch...
powershell -ExecutionPolicy Bypass -File "$InstallPath\uninstall.ps1"
pause
"@

$uninstallBatPath = Join-Path $InstallPath "uninstall.bat"
$uninstallScript | Out-File -FilePath $uninstallBatPath -Encoding ASCII

# Test installation
Write-Host "Testing installation..." -ForegroundColor Cyan
try {
    $originalPath = $env:PATH
    $env:PATH = $env:PATH + ";" + $InstallPath
    
    $testOutput = & jhswitch.cmd --help 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  - Installation successful!" -ForegroundColor Green
    } else {
        Write-Host "  - Installation test failed" -ForegroundColor Red
    }
    
    $env:PATH = $originalPath
} catch {
    Write-Host "  - Installation test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Installation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "jhSwitch has been installed to: $InstallPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT:" -ForegroundColor Yellow
Write-Host "1. Close and reopen your terminal to use the updated PATH" -ForegroundColor White
Write-Host "2. Then you can run: jhswitch <command>" -ForegroundColor White
Write-Host ""
Write-Host "To uninstall, run: $uninstallBatPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Quick test:" -ForegroundColor Yellow
Write-Host "  jhswitch --help" -ForegroundColor White
Write-Host "  jhswitch list" -ForegroundColor White
Write-Host ""
