# jhSwitch

A CLI to manage Java (JDK) versions from the terminal, similar to `nvm`, with remote install from **Amazon Corretto**, **Microsoft Build of OpenJDK**, and **Eclipse Temurin** (Adoptium) (Windows x64).

**jhSwitch runs only on Windows.** Commands that touch the network, extract archives, or change `JAVA_HOME` are implemented for Windows (x64) and are not supported on macOS or Linux.

## Requirements

- **Microsoft Windows** (64-bit; the tool is not supported on other operating systems)
- PowerShell 5.1+ (used by `jhswitch.ps1`)

## Installation

### Option A – GUI Installer (Recommended)

1. Go to the repository on GitHub and download the latest `jhswitch-setup.exe` from the **Releases** page.
2. Double-click the `.exe` and follow the wizard (no administrator rights required).
3. Restart the terminal and run:

```powershell
jhswitch --help
```

The installer registers jhSwitch in **Apps & Features** (Windows Settings) / **Programs and Features** (Control Panel), so you can uninstall it from there at any time.

### Option B – Command-line (from source)

#### Step 1: Download the Project from GitHub

1. Go to the repository on GitHub
2. Click the green **Code** button
3. Choose one of:
   - **Clone with Git**: `git clone <repository-url>`
   - **Download ZIP**: Extract the `.zip` file to your desired location

#### Step 2: Run the batch installer

From the project root directory, run:

```batch
installer\install.bat
```

The installer will:
- Copy `jhswitch.cmd`, `jhswitch.ps1`, and `providers.ps1` to `%APPDATA%\jhswitch`
- Add `%APPDATA%\jhswitch` to your user `PATH`

After installation, restart your terminal and run:

```powershell
jhswitch --help
```

#### Uninstall (batch)

From the project root, run:

```batch
installer\uninstall.bat
```

This will remove `%APPDATA%\jhswitch` and clean it from your user `PATH`.

### Local Installation (Development)

To test jhSwitch locally without installing:

```powershell
.\jhswitch.cmd --help
```

### Build the GUI installer from source

Requires [Inno Setup 6](https://jrsoftware.org/isinfo.php).

```bat
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\jhswitch.iss
```

The compiled installer is placed in `installer\Output\jhswitch-setup.exe`.

## JDK install folder

```powershell
jhswitch change-dir
```

You will be prompted for the new path (it is created if it does not exist). The choice is saved in `%USERPROFILE%\.jhswitch\config.json`.

You will also be asked whether to **move** existing JDK folders from the old location to the new one (**Y** / **N**). If you choose **Y** and user `JAVA_HOME` pointed at a JDK under the old folder, you are asked whether to **update `JAVA_HOME`** to that JDK’s path under the new folder (**Y** / **N**). Finally, you may be asked whether to **delete the previous install folder** entirely (**Y** / **N**); this is skipped if the new folder lies inside the old one (unsafe to remove).

Show the folder currently used for installs:

```powershell
jhswitch current-dir
```

Restore the default folder (removes the custom path from config; new installs use `%USERPROFILE%\.jhsdk` again):

```powershell
jhswitch reset-def-dir
```

The same **move** (**Y** / **N**), optional **`JAVA_HOME` update** (**Y** / **N**), and optional **delete old folder** (**Y** / **N**) prompts apply when switching from a custom folder back to the default, if the paths differ.

## Usage

1. List locally installed JDKs:

```powershell
jhswitch list
# alias:
jhswitch ls
```

2. List remote JDKs from all supported vendors:

```powershell
jhswitch remote-list
```

Results are cached for **1 hour** in `%USERPROFILE%\.jhswitch\remote-cache.json`. Delete that file to force an immediate refresh.

3. Install a JDK (use any name shown by `remote-list`):

```powershell
jhswitch install <jdk_name>
# alias:
jhswitch i <jdk_name>
```

Downloads are verified against their **SHA256 checksum** before extraction.

Corretto examples:

```powershell
jhswitch install corretto-21
jhswitch install 21
```

(`21` alone selects **Corretto** for backward compatibility.)

Microsoft Build of OpenJDK examples:

```powershell
jhswitch install microsoft-jdk-21
jhswitch install ms-jdk-17
```

Eclipse Temurin (Adoptium) examples:

```powershell
jhswitch install temurin-21
jhswitch install eclipse-temurin-17
jhswitch install adoptium-11
```

4. Remove a downloaded JDK folder:

```powershell
jhswitch uninstall <jdk_name>
```

If that JDK was the active one (`JAVA_HOME` points to it):

- If other JDKs remain, you are asked whether to run `jhswitch use` for the **first** remaining JDK (sorted like `jhswitch list`). Answer **Y** (Yes) or **N** (No).
- If no JDKs remain, you are asked whether to **remove `JAVA_HOME`** from your user environment (**Y** / **N**).

5. Set `JAVA_HOME` to a specific JDK:

```powershell
jhswitch use <jdk_name>
```

Example:

```powershell
jhswitch use corretto-21
jhswitch use microsoft-jdk-21
jhswitch use temurin-21
```

This sets `JAVA_HOME` **and** adds `%JAVA_HOME%\bin` to your user `PATH` (removing the previous JDK's bin entry).

6. Show the current JDK:

```powershell
jhswitch current
```

A warning is shown if `JAVA_HOME` points outside the jhSwitch-managed JDK root (e.g. set by another tool).

7. Show command help:

```powershell
jhswitch --help
```

or:

```powershell
jhswitch -h
```

## Implementation

The CLI is implemented with Windows-native scripts:

- `jhswitch.cmd` (entrypoint for `cmd`/`PowerShell`)
- `jhswitch.ps1` (all command logic)

## Notes

- `jhswitch use` sets `JAVA_HOME` **and** updates `%JAVA_HOME%\bin` in the user `PATH` — both at user scope (persistent).
- Uninstalling the last JDK can clear `JAVA_HOME` from the user environment when you confirm with **Y**.
- After `jhswitch use` or changing `JAVA_HOME`, open a new terminal session to pick up the updated value in all shells.
- Downloads are SHA256-verified before extraction. Corretto checksums come from `corretto.aws`; Temurin checksums come from the Adoptium API. Microsoft JDK has no public checksum endpoint.
- `remote-list` results are cached for 1 hour. Delete `%USERPROFILE%\.jhswitch\remote-cache.json` to force a refresh.

## Author

Enrico Palmisano

[Supporta il progetto con una donazione su PayPal](https://www.paypal.me/enricopalmisano)

[![PayPal](https://img.shields.io/badge/PayPal-004595?style=for-the-badge&logo=paypal&logoColor=white)](https://www.paypal.me/enricopalmisano)