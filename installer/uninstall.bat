@echo off
REM jhSwitch Uninstaller - No external dependencies required
REM Works on any Windows system with PowerShell 5.1+

setlocal enabledelayedexpansion

echo.
echo ========================================
echo jhSwitch Uninstallation
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  $ErrorActionPreference = 'Stop'; ^
  $INSTALL_DIR = Join-Path $env:APPDATA 'jhswitch'; ^
  Write-Host "Install directory: $INSTALL_DIR"; ^
  if (-not (Test-Path -LiteralPath $INSTALL_DIR)) { ^
    Write-Host 'jhSwitch is not installed in the default location.' -ForegroundColor Yellow; ^
  } else { ^
    $confirm = Read-Host 'Proceed with uninstall? (Y/N)'; ^
    if ($confirm -ne 'Y' -and $confirm -ne 'y') { ^
      Write-Host 'Uninstall canceled.' -ForegroundColor Yellow; ^
      exit 0 ^
    }; ^
    Remove-Item -LiteralPath $INSTALL_DIR -Recurse -Force; ^
    Write-Host 'OK - Installation folder removed.' -ForegroundColor Green; ^
  }; ^
  $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User'); ^
  if ([string]::IsNullOrWhiteSpace($userPath)) { ^
    Write-Host 'INFO - User PATH is empty.'; ^
    exit 0 ^
  }; ^
  $partsRaw = $userPath -split ';'; ^
  $parts = @(); ^
  foreach ($entry in $partsRaw) { ^
    if (-not [string]::IsNullOrWhiteSpace($entry)) { $parts += $entry } ^
  }; ^
  $normalizedInstall = [System.IO.Path]::GetFullPath($INSTALL_DIR).TrimEnd('\'); ^
  $filtered = @(); ^
  foreach ($p in $parts) { ^
    try { $np = [System.IO.Path]::GetFullPath($p).TrimEnd('\') } catch { $np = $p.TrimEnd('\') }; ^
    if ($np -ine $normalizedInstall) { $filtered += $p } ^
  }; ^
  $newPath = ($filtered -join ';'); ^
  [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User'); ^
  Write-Host 'OK - PATH updated.' -ForegroundColor Green; ^
  Write-Host ''; ^
  Write-Host 'Uninstall complete. Restart your terminal to apply PATH changes.' -ForegroundColor Green

if %ERRORLEVEL% neq 0 (
  echo.
  echo ERROR: Uninstall failed
  echo.
  pause
  exit /b 1
)

echo.
echo Done.
pause
