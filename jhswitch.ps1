$ErrorActionPreference = "Stop"

# Importa i provider
. (Join-Path $PSScriptRoot "providers.ps1")

$Command = ""
$Arg1 = ""
if ($args.Count -ge 1) { $Command = [string]$args[0] }
if ($args.Count -ge 2) { $Arg1 = [string]$args[1] }

function Get-ConfigDir {
  return Join-Path $env:USERPROFILE ".jhswitch"
}

function Get-ConfigPath {
  return Join-Path (Get-ConfigDir) "config.json"
}

function Get-DefaultJdkRoot {
  return Join-Path $env:USERPROFILE ".jhsdk"
}

function Ensure-Dir([string]$PathValue) {
  if (-not (Test-Path -LiteralPath $PathValue)) {
    New-Item -ItemType Directory -Path $PathValue | Out-Null
  }
}

function Load-Config {
  $configDir = Get-ConfigDir
  Ensure-Dir $configDir
  $configPath = Get-ConfigPath
  if (-not (Test-Path -LiteralPath $configPath)) {
    return @{}
  }
  try {
    $obj = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    $map = @{}
    if ($obj) {
      foreach ($p in $obj.PSObject.Properties) {
        $map[$p.Name] = $p.Value
      }
    }
    return $map
  } catch {
    throw "Error: invalid configuration file."
  }
}

function Save-Config([hashtable]$Config) {
  $configDir = Get-ConfigDir
  Ensure-Dir $configDir
  $configPath = Get-ConfigPath
  ($Config | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $configPath -Encoding UTF8
}

function Normalize-Path([string]$InputPath) {
  if ([string]::IsNullOrWhiteSpace($InputPath)) {
    throw "Invalid path."
  }
  return [System.IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InputPath))
}

function Get-JdkRoot {
  $config = Load-Config
  if ($config.ContainsKey("jdkRoot") -and -not [string]::IsNullOrWhiteSpace($config.jdkRoot)) {
    $root = Normalize-Path $config.jdkRoot
  } else {
    $root = Get-DefaultJdkRoot
  }
  Ensure-Dir $root
  return $root
}

function Get-JdkFolders([string]$Root) {
  if (-not (Test-Path -LiteralPath $Root)) {
    return @()
  }
  return @(Get-ChildItem -LiteralPath $Root -Directory | Select-Object -ExpandProperty Name | Sort-Object)
}

function Confirm-YesNo([string]$PromptText) {
  $answer = (Read-Host $PromptText).Trim().ToLowerInvariant()
  return ($answer -eq "y" -or $answer -eq "yes")
}

function Set-UserJavaHome([string]$PathValue) {
  [Environment]::SetEnvironmentVariable("JAVA_HOME", $PathValue, "User")
  $env:JAVA_HOME = $PathValue
}

function Clear-UserJavaHome {
  [Environment]::SetEnvironmentVariable("JAVA_HOME", $null, "User")
  Remove-Item Env:JAVA_HOME -ErrorAction SilentlyContinue
}

function Update-UserPathJdkBin([string]$JdkRoot, [string]$NewBin) {
  $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
  $parts = if ($userPath) { @($userPath -split ';' | Where-Object { $_ -ne "" }) } else { @() }
  $normalizedRoot = (Normalize-Path $JdkRoot).TrimEnd('\')
  # Remove any existing \bin entries that live under the JDK root (old active JDK)
  $filtered = @($parts | Where-Object {
    $p = $_.TrimEnd('\')
    try { $np = [System.IO.Path]::GetFullPath($p) } catch { return $true }
    -not ($np.ToLowerInvariant().StartsWith($normalizedRoot.ToLowerInvariant() + '\') -and $np.ToLowerInvariant().EndsWith('\bin'))
  })
  # Add the new bin path if not already present
  $normalizedBin = (Normalize-Path $NewBin).TrimEnd('\')
  $alreadyPresent = $filtered | Where-Object {
    try { [System.IO.Path]::GetFullPath($_).TrimEnd('\').ToLowerInvariant() -eq $normalizedBin.ToLowerInvariant() } catch { $false }
  }
  if (-not $alreadyPresent) { $filtered += $NewBin }
  $newPath = $filtered -join ';'
  [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
  $env:PATH = $newPath
}

function Get-UserJavaHome {
  $reg = [Environment]::GetEnvironmentVariable("JAVA_HOME", "User")
  if (-not [string]::IsNullOrWhiteSpace($reg)) {
    return $reg.Trim()
  }
  if (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
    return $env:JAVA_HOME.Trim()
  }
  return $null
}

function Get-CurrentJavaVersion {
  $pid   = [System.Diagnostics.Process]::GetCurrentProcess().Id
  $tmpOut = Join-Path $env:TEMP "jhswitch-stdout-$pid.txt"
  $tmpErr = Join-Path $env:TEMP "jhswitch-stderr-$pid.txt"
  $javaHome = Get-UserJavaHome
  if ($javaHome) {
    $javaExe = Join-Path $javaHome "bin\java.exe"
    if (Test-Path -LiteralPath $javaExe) {
      try {
        Start-Process -FilePath $javaExe -ArgumentList "-version" -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr -Wait -PassThru -NoNewWindow | Out-Null
        $stderr = Get-Content $tmpErr -Raw -ErrorAction SilentlyContinue
        Remove-Item $tmpOut, $tmpErr -ErrorAction SilentlyContinue
        if ($stderr) { return ($stderr.Split("`n")[0]).Trim() }
      } catch {
        Remove-Item $tmpOut, $tmpErr -ErrorAction SilentlyContinue
      }
    }
  }
  try {
    Start-Process -FilePath "java" -ArgumentList "-version" -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr -Wait -PassThru -NoNewWindow | Out-Null
    $stderr = Get-Content $tmpErr -Raw -ErrorAction SilentlyContinue
    Remove-Item $tmpOut, $tmpErr -ErrorAction SilentlyContinue
    if ($stderr) { return ($stderr.Split("`n")[0]).Trim() }
  } catch {
    Remove-Item $tmpOut, $tmpErr -ErrorAction SilentlyContinue
  }
  return $null
}

function Resolve-Install([string]$Name) {
  if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
  $registry = Get-ProviderRegistry
  return $registry.ResolveInstall($Name)
}

function Download-AndExtract([string]$DownloadUrl, [string]$InstallRoot, [string]$FolderName, [string]$ChecksumUrl = "", [string]$ExpectedChecksum = "") {
  $temp = Join-Path $env:TEMP ("jhswitch-" + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
  $zipPath = Join-Path $temp "jdk.zip"
  $extractPath = Join-Path $temp "unzipped"
  Ensure-Dir $extractPath
  try {
    Write-Host "Download: $DownloadUrl"
    Invoke-WebRequest -UseBasicParsing -Uri $DownloadUrl -OutFile $zipPath
    # Verify SHA256 checksum
    if (-not [string]::IsNullOrWhiteSpace($ExpectedChecksum)) {
      Write-Host "Verifying checksum..."
      $actual   = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
      $expected = $ExpectedChecksum.Trim().ToLowerInvariant()
      if ($actual -ne $expected) { throw "SHA256 checksum mismatch. The download may be corrupted or tampered with." }
      Write-Host "Checksum OK."
    } elseif (-not [string]::IsNullOrWhiteSpace($ChecksumUrl)) {
      Write-Host "Verifying checksum..."
      $raw      = (Invoke-WebRequest -UseBasicParsing -Uri $ChecksumUrl).Content.Trim()
      $expected = if ($raw -match '^([0-9a-fA-F]{64})') { $Matches[1].ToLowerInvariant() } else { $raw.ToLowerInvariant() }
      $actual   = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
      if ($actual -ne $expected) { throw "SHA256 checksum mismatch. The download may be corrupted or tampered with." }
      Write-Host "Checksum OK."
    }
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    $firstDir = Get-ChildItem -LiteralPath $extractPath -Directory | Select-Object -First 1
    if (-not $firstDir) { throw "Invalid downloaded archive: no folder found." }
    $target = Join-Path $InstallRoot $FolderName
    if (Test-Path -LiteralPath $target) { throw "Destination folder already exists: $target" }
    Move-Item -LiteralPath $firstDir.FullName -Destination $target
    return $target
  } finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
  }
}

function Assert-SafeJdkName([string]$Name) {
  if ([string]::IsNullOrWhiteSpace($Name)) { throw "JDK name is required." }
  if ($Name.Contains("\") -or $Name.Contains("/") -or $Name.Contains("..")) { throw "Invalid JDK name." }
  return $Name.Trim()
}

function Move-JdkSubfolders([string]$SourceRoot, [string]$DestRoot) {
  if (-not (Test-Path -LiteralPath $SourceRoot)) { return }
  Ensure-Dir $DestRoot
  $entries = Get-ChildItem -LiteralPath $SourceRoot -Directory
  foreach ($ent in $entries) {
    $from = $ent.FullName
    $to = Join-Path $DestRoot $ent.Name
    if (Test-Path -LiteralPath $to) {
      Write-Host "Skipped (already exists in destination): $($ent.Name)"
      continue
    }
    try {
      Move-Item -LiteralPath $from -Destination $to
    } catch {
      Copy-Item -LiteralPath $from -Destination $to -Recurse -Force
      Remove-Item -LiteralPath $from -Recurse -Force
    }
  }
}

function Infer-JdkNameFromJavaHome([string]$JavaHome, [string]$OldRoot) {
  if (-not $JavaHome) { return $null }
  $h = Normalize-Path $JavaHome
  $o = Normalize-Path $OldRoot
  if (-not $h.StartsWith($o, [System.StringComparison]::OrdinalIgnoreCase)) { return $null }
  $rel = $h.Substring($o.Length).TrimStart('\','/')
  if ([string]::IsNullOrWhiteSpace($rel)) { return $null }
  return $rel.Split('\','/')[0]
}

function Maybe-UpdateJavaHomeAfterMove([string]$OldRoot, [string]$NewRoot, [bool]$DidMove) {
  if (-not $DidMove) { return }
  $regHome = Get-UserJavaHome
  if (-not $regHome) { return }
  $jdkName = Infer-JdkNameFromJavaHome $regHome $OldRoot
  if (-not $jdkName) { return }
  $newJavaHome = Join-Path $NewRoot $jdkName
  if (-not (Test-Path -LiteralPath $newJavaHome)) { return }
  $msg = "JAVA_HOME points to a JDK under the previous folder. Update JAVA_HOME to the new path for `"$jdkName`"?`n  $newJavaHome`n(Y=Yes, N=No)"
  if (Confirm-YesNo $msg) {
    Set-UserJavaHome $newJavaHome
    Write-Host "JAVA_HOME set to: $newJavaHome"
    Write-Host "Open a new terminal session to use the updated persistent value."
  }
}

function Can-OfferDeleteOldRoot([string]$OldRoot, [string]$NewRoot) {
  $o = Normalize-Path $OldRoot
  $n = Normalize-Path $NewRoot
  if ($o -ieq $n) { return $false }
  if ($n.StartsWith($o.TrimEnd('\') + "\", [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
  return (Test-Path -LiteralPath $o)
}

function Maybe-DeleteOldRoot([string]$OldRoot, [string]$NewRoot) {
  if (-not (Can-OfferDeleteOldRoot $OldRoot $NewRoot)) { return }
  $msg = "Delete the previous JDK install folder and all of its contents?`n  $OldRoot`n(Y=Yes, N=No)"
  if (Confirm-YesNo $msg) {
    Remove-Item -LiteralPath $OldRoot -Recurse -Force
    Write-Host "Removed folder: $OldRoot"
  }
}

function Run-ChangeDir {
  $oldRoot = Get-JdkRoot
  $inputPath = Read-Host "Enter the folder where JDKs will be installed and managed"
  if ([string]::IsNullOrWhiteSpace($inputPath)) { throw "Invalid path." }
  $newRoot = Normalize-Path $inputPath
  Ensure-Dir $newRoot
  if ($oldRoot -ieq $newRoot) {
    $cfg = Load-Config
    $cfg["jdkRoot"] = $newRoot
    Save-Config $cfg
    Write-Host "JDK install folder unchanged: $newRoot"
    return
  }
  $move = Confirm-YesNo "Move JDK folders from the previous location to the new one?`n  From: $oldRoot`n  To:   $newRoot`n(Y=Yes, N=No)"
  if ($move) { Move-JdkSubfolders $oldRoot $newRoot }
  $cfg = Load-Config
  $cfg["jdkRoot"] = $newRoot
  Save-Config $cfg
  Write-Host "JDK install folder set to: $newRoot"
  Maybe-UpdateJavaHomeAfterMove $oldRoot $newRoot $move
  Maybe-DeleteOldRoot $oldRoot $newRoot
}

function Run-ResetDefDir {
  $oldRoot = Get-JdkRoot
  $newRoot = Get-DefaultJdkRoot
  if ($oldRoot -ieq $newRoot) {
    $cfg = Load-Config
    if ($cfg.ContainsKey("jdkRoot")) {
      $cfg.Remove("jdkRoot")
      Save-Config $cfg
      Write-Host "JDK install folder was already the default; removed redundant path from config."
    } else {
      Write-Host "JDK install folder is already the default: $newRoot"
    }
    return
  }
  $move = Confirm-YesNo "Move JDK folders from the previous location to the default folder?`n  From: $oldRoot`n  To:   $newRoot`n(Y=Yes, N=No)"
  if ($move) { Move-JdkSubfolders $oldRoot $newRoot }
  $cfg = Load-Config
  if ($cfg.ContainsKey("jdkRoot")) { $cfg.Remove("jdkRoot") }
  Save-Config $cfg
  Write-Host "JDK install folder reset to default: $(Get-JdkRoot)"
  Maybe-UpdateJavaHomeAfterMove $oldRoot $newRoot $move
  Maybe-DeleteOldRoot $oldRoot $newRoot
}

function Run-CurrentDir { Write-Host (Get-JdkRoot) }

function Run-List {
  $root = Get-JdkRoot
  $folders = Get-JdkFolders $root
  if ($folders.Count -eq 0) { Write-Host "No JDK found in: $root"; return }
  Write-Host "Available JDKs:"
  foreach ($f in $folders) { Write-Host "- $f" }
}

function Get-RemoteCache {
  $cachePath = Join-Path (Get-ConfigDir) "remote-cache.json"
  if (-not (Test-Path -LiteralPath $cachePath)) { return $null }
  try {
    $raw = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if (($now - [long]$raw.timestamp) -lt 3600) {
      $result = @{}
      foreach ($prop in $raw.providers.PSObject.Properties) {
        $result[$prop.Name] = @{
          DisplayNames = @($prop.Value.DisplayNames)
          Majors       = @($prop.Value.Majors)
        }
      }
      return $result
    }
  } catch {}
  return $null
}

function Set-RemoteCache([hashtable]$Data) {
  $cachePath = Join-Path (Get-ConfigDir) "remote-cache.json"
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  @{ timestamp = $now; providers = $Data } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cachePath -Encoding UTF8
}

function Run-RemoteList {
  $cached = Get-RemoteCache
  if ($null -ne $cached) {
    foreach ($providerName in ($cached.Keys | Sort-Object)) {
      Write-Host "$providerName (Windows x64, latest):"
      foreach ($name in $cached[$providerName].DisplayNames) { Write-Host "  - $name" }
      Write-Host ""
    }
    Write-Host "(Cached. Refreshes automatically after 1 hour.)"
    return
  }
  Write-Host "Fetching available JDKs (this may take a moment)..."
  $registry = Get-ProviderRegistry
  $allJdks  = $registry.GetAllAvailableJdks()
  $cacheData = @{}
  foreach ($providerName in ($allJdks.Keys | Sort-Object)) {
    $providerInfo = $allJdks[$providerName]
    $displayNames = $providerInfo.DisplayNames
    Write-Host "$providerName (Windows x64, latest):"
    foreach ($name in $displayNames) { Write-Host "  - $name" }
    Write-Host ""
    $cacheData[$providerName] = @{
      DisplayNames = $displayNames
      Majors       = $providerInfo.Majors
    }
  }
  Set-RemoteCache $cacheData
}

function Run-Install([string]$Name) {
  if ([string]::IsNullOrWhiteSpace($Name)) { throw "Usage: jhswitch install <jdk_name>" }
  $registry = Get-ProviderRegistry
  $res = $registry.ResolveInstall($Name)
  if (-not $res) {
    throw "Invalid JDK name. Examples: `"corretto-21`" or `"21`" (Corretto), `"microsoft-jdk-21`" (Microsoft)."
  }
  
  # Verifica che la versione sia disponibile
  $provider = $registry.FindProvider($Name)
  $availableMajors = $provider.GetAvailableMajors()
  if ($res.Major -notin $availableMajors) {
    throw "$($res.FolderName) is not offered by $($res.Provider). Run `"jhswitch remote-list`"."
  }
  
  $checksumUrl      = if ($res.ContainsKey("ChecksumUrl"))      { $res.ChecksumUrl }      else { "" }
  $expectedChecksum = if ($res.ContainsKey("ExpectedChecksum")) { $res.ExpectedChecksum } else { "" }
  $installedPath = Download-AndExtract $res.DownloadUrl (Get-JdkRoot) $res.FolderName $checksumUrl $expectedChecksum
  Write-Host "Installation completed at: $installedPath"
  Write-Host "Use it now with: jhswitch use $($res.FolderName)"
}

function Run-Use([string]$Name) {
  if ([string]::IsNullOrWhiteSpace($Name)) { throw "Usage: jhswitch use <jdk_name>" }
  $safe = Assert-SafeJdkName $Name
  $root = Get-JdkRoot
  $target = Join-Path $root $safe
  if (-not (Test-Path -LiteralPath $target)) { throw "Folder does not exist: $target" }
  Set-UserJavaHome $target
  Write-Host "JAVA_HOME set to: $target"
  $binPath = Join-Path $target "bin"
  Update-UserPathJdkBin $root $binPath
  Write-Host "PATH updated: $binPath added to user PATH."
  Write-Host "Open a new terminal session to use the updated persistent value."
}

function Run-Uninstall([string]$Name) {
  if ([string]::IsNullOrWhiteSpace($Name)) { throw "Usage: jhswitch uninstall <jdk_name>" }
  $safe = Assert-SafeJdkName $Name
  $root = Get-JdkRoot
  $target = Join-Path $root $safe
  if (-not (Test-Path -LiteralPath $target)) { throw "JDK not found: $safe" }
  $inUse = $false
  $regHome = Get-UserJavaHome
  if ($regHome) {
    $inUse = ((Normalize-Path $regHome).ToLowerInvariant() -eq (Normalize-Path $target).ToLowerInvariant())
  }
  Remove-Item -LiteralPath $target -Recurse -Force
  Write-Host "Removed JDK: $safe"
  if (-not $inUse) { return }
  $remaining = Get-JdkFolders $root
  if ($remaining.Count -gt 0) {
    $first = $remaining[0]
    $msg = "JAVA_HOME pointed to the removed JDK. Run `"jhswitch use`" for the first remaining JDK ($first)? (Y=Yes, N=No)"
    if (Confirm-YesNo $msg) { Run-Use $first }
    return
  }
  $msg2 = "No JDKs are left in the install folder. Remove JAVA_HOME from your user environment? (Y=Yes, N=No)"
  if (Confirm-YesNo $msg2) {
    Clear-UserJavaHome
    Write-Host "JAVA_HOME was removed from your user environment. Open a new terminal session for changes to apply everywhere."
  }
}

function Run-Current {
  $javaHome = Get-UserJavaHome
  if ($javaHome) {
    Write-Host "JAVA_HOME: $javaHome"
    # Warn if JAVA_HOME is not under the jhSwitch-managed JDK root
    $root = Get-JdkRoot
    try {
      $normalizedHome = (Normalize-Path $javaHome).TrimEnd('\')
      $normalizedRoot = (Normalize-Path $root).TrimEnd('\')
      $underRoot = $normalizedHome.StartsWith($normalizedRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)
      if (-not $underRoot) {
        Write-Host "Warning: JAVA_HOME is not under the jhSwitch JDK root ($root). It may have been set externally." -ForegroundColor Yellow
      }
    } catch {}
  } else {
    Write-Host "JAVA_HOME is not set."
  }
  $version = Get-CurrentJavaVersion
  if ($version) {
    Write-Host "Current Java version:"
    Write-Host $version
  } elseif ($javaHome) {
    Write-Host "Could not run Java from JAVA_HOME or PATH (check that %JAVA_HOME%\bin\java.exe exists)."
  } else {
    Write-Host "JAVA_HOME is not set and `"java`" was not found on PATH."
  }
}

function Print-Help {
@"
jhSwitch - JDK manager for terminal (PowerShell + cmd)

Commands:
  jhswitch change-dir              Set the JDK install folder (default: %USERPROFILE%\.jhsdk)
  jhswitch current-dir             Show the JDK install folder in use
  jhswitch reset-def-dir           Restore the default JDK install folder (%USERPROFILE%\.jhsdk)
  jhswitch list  (ls)              Show locally available JDKs
  jhswitch remote-list             Show JDKs from all configured vendors (cached 1h)
  jhswitch install (i) <jdk_name>  Download and install a JDK (Corretto / Microsoft / Temurin)
  jhswitch uninstall <jdk_name>    Remove a downloaded JDK folder
  jhswitch use <jdk_name>          Set JAVA_HOME and update PATH to selected JDK
  jhswitch current                 Show JAVA_HOME and current Java version

Provider prefixes:
  corretto-<N>    Amazon Corretto (also: amazon-corretto-<N>, or just <N>)
  microsoft-jdk-<N>  Microsoft Build of OpenJDK (also: ms-jdk-<N>, msopenjdk-<N>)
  temurin-<N>     Eclipse Temurin / Adoptium (also: eclipse-temurin-<N>, adoptium-<N>)
"@ | Write-Host
}

try {
  $commandValue = ""
  if ($null -ne $Command) {
    $commandValue = $Command.ToLowerInvariant()
  }
  switch ($commandValue) {
    "change-dir" { Run-ChangeDir; break }
    "current-dir" { Run-CurrentDir; break }
    "reset-def-dir" { Run-ResetDefDir; break }
    "list"        { Run-List; break }
    "ls"          { Run-List; break }
    "remote-list" { Run-RemoteList; break }
    "install"     { Run-Install $Arg1; break }
    "i"           { Run-Install $Arg1; break }
    "uninstall"   { Run-Uninstall $Arg1; break }
    "use"         { Run-Use $Arg1; break }
    "current"     { Run-Current; break }
    "-h"          { Print-Help; break }
    "--help"      { Print-Help; break }
    default       { Print-Help; break }
  }
} catch {
  Write-Error $_.Exception.Message
  exit 1
}
