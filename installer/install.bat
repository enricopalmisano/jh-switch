@echo off
REM jhSwitch Installer - No external dependencies required
REM Works on any Windows system with PowerShell 5.1+

setlocal enabledelayedexpansion

echo.
echo ========================================
echo jhSwitch Installation
echo ========================================
echo.

REM Get the parent directory (project root)
cd /d "%~dp0.."

REM Run the PowerShell installation code inline
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  $ErrorActionPreference = 'Stop'; ^
  $INSTALL_DIR = Join-Path $env:APPDATA 'jhswitch'; ^
  $REQUIRED_FILES = @('jhswitch.cmd', 'jhswitch.ps1', 'providers.ps1'); ^
  Write-Host 'Checking required files...'; ^
  $missingFiles = @(); ^
  foreach ($file in $REQUIRED_FILES) { ^
    if (-not (Test-Path -LiteralPath $file)) { $missingFiles += $file } ^
  }; ^
  if ($missingFiles.Count -gt 0) { ^
    Write-Host "ERROR: Missing files: $($missingFiles -join ', ')" -ForegroundColor Red; ^
    exit 1 ^
  }; ^
  Write-Host 'OK - All required files found' -ForegroundColor Green; ^
  Write-Host ''; ^
  Write-Host "Creating installation directory: $INSTALL_DIR"; ^
  if (Test-Path -LiteralPath $INSTALL_DIR) { ^
    Write-Host 'WARNING - Directory already exists. Files will be overwritten.' -ForegroundColor Yellow ^
  } else { ^
    [void](New-Item -ItemType Directory -Path $INSTALL_DIR -Force) ^
  }; ^
  Write-Host 'OK - Installation directory ready' -ForegroundColor Green; ^
  Write-Host ''; ^
  Write-Host 'Copying files...'; ^
  foreach ($file in $REQUIRED_FILES) { ^
    Copy-Item -LiteralPath $file -Destination (Join-Path $INSTALL_DIR $file) -Force; ^
    Write-Host "   OK - $file" ^
  }; ^
  Write-Host 'OK - Files copied' -ForegroundColor Green; ^
  Write-Host ''; ^
  Write-Host 'Updating PATH...'; ^
  $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User'); ^
  $partsRaw = if ($userPath) { $userPath -split ';' } else { @() }; ^
  $parts = @(); ^
  $normalizedInstall = [System.IO.Path]::GetFullPath($INSTALL_DIR).TrimEnd('\'); ^
  $hasInstall = $false; ^
  foreach ($entryRaw in $partsRaw) { ^
    if ([string]::IsNullOrWhiteSpace($entryRaw)) { continue }; ^
    $entry = $entryRaw.Trim(); ^
    if ($entry -like ('* ' + $INSTALL_DIR)) { ^
      $baseEntry = $entry.Substring(0, $entry.Length - $INSTALL_DIR.Length - 1).TrimEnd(); ^
      if (-not [string]::IsNullOrWhiteSpace($baseEntry)) { $parts += $baseEntry }; ^
      $hasInstall = $true; ^
      continue ^
    }; ^
    try { $normalizedEntry = [System.IO.Path]::GetFullPath($entry).TrimEnd('\') } catch { $normalizedEntry = $entry.TrimEnd('\') }; ^
    if ($normalizedEntry -ieq $normalizedInstall) { ^
      $hasInstall = $true; ^
      continue ^
    }; ^
    $parts += $entry ^
  }; ^
  if ($hasInstall) { ^
    Write-Host 'WARNING - Already in PATH' -ForegroundColor Yellow ^
  } else { ^
    $parts += $INSTALL_DIR; ^
    Write-Host 'OK - Added jhSwitch to PATH' -ForegroundColor Green ^
  }; ^
  $newPath = ($parts -join ';'); ^
  [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User'); ^
  $env:PATH = $newPath; ^
  Write-Host 'OK - PATH updated' -ForegroundColor Green; ^
  Write-Host '' ^
  Write-Host 'Installation Complete!' -ForegroundColor Green; ^
  Write-Host ''; ^
  Write-Host 'Verification:'; ^
  Write-Host "   - Installation folder: $INSTALL_DIR"; ^
  Write-Host "   - Files: $($REQUIRED_FILES -join ', ')"; ^
  Write-Host ''; ^
  Write-Host 'Usage:'; ^
  Write-Host '   jhswitch list          - List installed JDKs'; ^
  Write-Host '   jhswitch remote-list   - List available JDKs'; ^
  Write-Host '   jhswitch install ^<jdk^> - Install a JDK'; ^
  Write-Host '   jhswitch use ^<jdk^>     - Switch to a JDK'; ^
  Write-Host '   jhswitch --help        - Show all commands'; ^
  Write-Host ''; ^
  Write-Host 'Installation successful! Restart your terminal to use jhswitch.' -ForegroundColor Green; ^
  Write-Host ''

if %ERRORLEVEL% equ 0 (
    pause
) else (
    echo.
    echo ERROR: Installation failed
    echo.
    pause
    exit /b 1
)
