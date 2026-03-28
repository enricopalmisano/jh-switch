# jhSwitch

A CLI to manage Java (JDK) versions from the terminal, similar to `nvm`, with remote install from **Amazon Corretto** and **Microsoft Build of OpenJDK** (Windows x64).

**jhSwitch runs only on Windows.** Commands that touch the network, extract archives, or change `JAVA_HOME` are implemented for Windows (x64) and are not supported on macOS or Linux.

## Requirements

- **Microsoft Windows** (64-bit; the tool is not supported on other operating systems)
- Node.js installed
- PowerShell available (used for downloads and archive extraction)

## Local installation

Inside the project:

```powershell
npm link
```

After linking, the `jhswitch` command will be available in your terminal.

## JDK install folder

By default, downloaded JDKs are stored under **`%USERPROFILE%\.jhsdk`** (for example `C:\Users\YourName\.jhsdk`). The folder is created automatically when needed.

To use a different directory:

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
```

2. List remote JDKs from all supported vendors:

```powershell
jhswitch remote-list
```

3. Install a JDK (folder name must match a line from `remote-list`):

```powershell
jhswitch install <jdk_name>
```

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
```

or:

```powershell
jhswitch use microsoft-jdk-21
```

6. Show the current JDK:

```powershell
jhswitch current
```

7. Show command help:

```powershell
jhswitch --help
```

or:

```powershell
jhswitch -h
```

## Extending vendor support (strategy pattern)

Remote install is implemented with one **strategy module** per vendor under `lib/providers/`. Each strategy exports:

- `id`, `displayName`
- `listRemoteOffers(fetchText)` — returns `{ folderName }` entries for Windows x64
- `tryParseInstallRequest(rawName)` — returns `{ folderName, major }` or `null`
- `getWindowsX64ZipUrl(selection)` — download URL for that selection

Register a new strategy in `lib/providers/index.js` (`strategies` array). Resolution order matters: the first strategy whose `tryParseInstallRequest` matches wins.

## Notes

- `jhswitch use` sets `JAVA_HOME` at user level (persistent) using `setx`.
- Uninstalling the last JDK can clear `JAVA_HOME` via `reg delete` on the user environment (HKCU) when you confirm with **Y**.
- After `jhswitch use` or changing `JAVA_HOME`, open a new terminal session to pick up the updated value in all shells.

## Author

Enrico Palmisano
