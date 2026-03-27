# jSwitch

A CLI to manage Java (JDK) versions from the terminal, similar to `nvm`, with Amazon Corretto installation support.

## Requirements

- Node.js installed
- Windows (for `JAVA_HOME` management via `setx`)

## Local installation

Inside the project:

```powershell
npm link
```

After linking, the `jswitch` command will be available in your terminal.

## Usage

1. Configure the JDK root folder (it will be created if it does not exist):

```powershell
jswitch start
```

2. List locally installed JDKs:

```powershell
jswitch list
```

3. List remote JDKs available on Amazon Corretto:

```powershell
jswitch remote-list
```

4. Install a JDK from Amazon Corretto:

```powershell
jswitch install <jdk_name>
```

Valid examples:

```powershell
jswitch install corretto-21
jswitch install 21
```

5. Set `JAVA_HOME` to a specific JDK:

```powershell
jswitch use <jdk_name>
```

Example:

```powershell
jswitch use corretto-1.8.0_482
```

6. Show the current JDK:

```powershell
jswitch current
```

7. Show command help:

```powershell
jswitch --help
```

or:

```powershell
jswitch -h
```

## Notes

- `jswitch use` sets `JAVA_HOME` at user level (persistent) using `setx`.
- After `jswitch use`, open a new terminal session to pick up the updated value in all shells.
- All commands (except `start` and `help`) require `jswitch start` to be configured first.

## Author

Enrico Palmisano
