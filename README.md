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

## Usage

1. Configure the JDK root folder (it will be created if it does not exist):

```powershell
jhswitch start
```

2. List locally installed JDKs:

```powershell
jhswitch list
```

3. List remote JDKs from all supported vendors:

```powershell
jhswitch remote-list
```

4. Install a JDK (folder name must match a line from `remote-list`):

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
- After `jhswitch use`, open a new terminal session to pick up the updated value in all shells.
- All commands (except `start` and `help`) require `jhswitch start` to be configured first.

## Author

Enrico Palmisano
