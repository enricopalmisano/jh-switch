#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const os = require("os");
const readline = require("readline");
const { execSync, spawnSync } = require("child_process");

const CONFIG_DIR = path.join(os.homedir(), ".jswitch");
const CONFIG_PATH = path.join(CONFIG_DIR, "config.json");

function ensureConfigDir() {
  if (!fs.existsSync(CONFIG_DIR)) {
    fs.mkdirSync(CONFIG_DIR, { recursive: true });
  }
}

function loadConfig() {
  ensureConfigDir();
  if (!fs.existsSync(CONFIG_PATH)) {
    return {};
  }
  try {
    return JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
  } catch (error) {
    console.error("Error: invalid configuration file.");
    process.exit(1);
  }
}

function saveConfig(config) {
  ensureConfigDir();
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2), "utf8");
}

function askQuestion(question) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

function normalizeInputPath(inputPath) {
  const expanded = inputPath.replace(/^~(?=$|[\\/])/, os.homedir());
  return path.resolve(expanded);
}

function validateDirectory(dirPath) {
  if (!fs.existsSync(dirPath)) {
    throw new Error(`Folder does not exist: ${dirPath}`);
  }
  const stats = fs.statSync(dirPath);
  if (!stats.isDirectory()) {
    throw new Error(`Path is not a folder: ${dirPath}`);
  }
}

function getJdkRootOrExit() {
  const config = loadConfig();
  if (!config.jdkRoot) {
    console.error(
      'No JDK root folder configured. Run "jswitch start" first.'
    );
    process.exit(1);
  }
  validateDirectory(config.jdkRoot);
  return config.jdkRoot;
}

function getJdkFolders(jdkRoot) {
  return fs
    .readdirSync(jdkRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort((a, b) => a.localeCompare(b));
}

function setJavaHome(jdkPath) {
  if (process.platform !== "win32") {
    throw new Error("jswitch currently supports JAVA_HOME updates on Windows only.");
  }
  const escaped = jdkPath.replace(/"/g, '\\"');
  execSync(`setx JAVA_HOME "${escaped}"`, { stdio: "pipe" });
  process.env.JAVA_HOME = jdkPath;
}

function readWindowsUserJavaHome() {
  if (process.platform !== "win32") {
    return process.env.JAVA_HOME || null;
  }
  try {
    const out = execSync("reg query HKCU\\Environment /v JAVA_HOME", {
      encoding: "utf8",
      stdio: ["pipe", "pipe", "pipe"]
    });
    const match = out.match(/JAVA_HOME\s+REG_\w+\s+([^\r\n]+)/i);
    return match ? match[1].trim() : null;
  } catch (_error) {
    return process.env.JAVA_HOME || null;
  }
}

function getCurrentJavaVersion() {
  const result = spawnSync("java", ["-version"], {
    encoding: "utf8",
    shell: true
  });

  if (result.error) {
    return null;
  }

  const combined = `${result.stdout || ""}\n${result.stderr || ""}`.trim();
  return combined || null;
}

async function runStart() {
  const input = await askQuestion("Enter the folder where JDKs will be installed and managed: ");
  if (!input) {
    console.error("Invalid path.");
    process.exit(1);
  }
  const jdkRoot = normalizeInputPath(input);
  if (!fs.existsSync(jdkRoot)) {
    fs.mkdirSync(jdkRoot, { recursive: true });
  }
  validateDirectory(jdkRoot);
  saveConfig({ jdkRoot });
  console.log(`Configuration saved: ${jdkRoot}`);
}

function fetchText(url) {
  if (process.platform !== "win32") {
    throw new Error("This command is available on Windows only.");
  }
  const escapedUrl = url.replace(/'/g, "''");
  return execSync(
    `powershell -NoProfile -Command "Invoke-WebRequest -UseBasicParsing -Uri '${escapedUrl}' | Select-Object -ExpandProperty Content"`,
    { encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] }
  );
}

async function getCorrettoMajors() {
  const page = await fetchText("https://corretto.aws/downloads/");
  const majors = Array.from(page.matchAll(/corretto-(\d+)-ug/g))
    .map((m) => m[1])
    .filter((value, index, arr) => arr.indexOf(value) === index)
    .sort((a, b) => Number(a) - Number(b));

  if (majors.length === 0) {
    throw new Error("Unable to fetch Amazon Corretto remote list.");
  }
  return majors;
}

async function runRemoteList() {
  getJdkRootOrExit();
  const majors = await getCorrettoMajors();
  console.log("Remote JDKs available on Amazon Corretto (Windows x64, latest):");
  majors.forEach((major) => {
    console.log(`- corretto-${major}`);
  });
}

function normalizeInstallName(rawName) {
  const value = String(rawName || "").trim().toLowerCase();
  if (!value) {
    return null;
  }
  const byPattern = value.match(/(?:amazon-)?corretto-(\d+)$/);
  if (byPattern) {
    return byPattern[1];
  }
  const onlyMajor = value.match(/^(\d+)$/);
  if (onlyMajor) {
    return onlyMajor[1];
  }
  return null;
}

function downloadAndExtractCorrettoZip(downloadUrl, installRoot, folderName) {
  if (process.platform !== "win32") {
    throw new Error("The install command is supported on Windows only.");
  }

  const tempBase = path.join(os.tmpdir(), `jswitch-${Date.now()}`);
  const zipPath = path.join(tempBase, "corretto.zip");
  const extractPath = path.join(tempBase, "unzipped");
  fs.mkdirSync(extractPath, { recursive: true });

  try {
    console.log(`Download: ${downloadUrl}`);
    execSync(
      `powershell -NoProfile -Command "Invoke-WebRequest -UseBasicParsing -Uri '${downloadUrl}' -OutFile '${zipPath}'"`,
      { stdio: "inherit" }
    );

    execSync(
      `powershell -NoProfile -Command "Expand-Archive -Path '${zipPath}' -DestinationPath '${extractPath}' -Force"`,
      { stdio: "inherit" }
    );

    const entries = fs
      .readdirSync(extractPath, { withFileTypes: true })
      .filter((entry) => entry.isDirectory());
    if (entries.length === 0) {
      throw new Error("Invalid downloaded archive: no folder found.");
    }

    const sourceDir = path.join(extractPath, entries[0].name);
    const targetDir = path.join(installRoot, folderName);
    if (fs.existsSync(targetDir)) {
      throw new Error(`Destination folder already exists: ${targetDir}`);
    }

    fs.renameSync(sourceDir, targetDir);
    return targetDir;
  } finally {
    if (fs.existsSync(tempBase)) {
      fs.rmSync(tempBase, { recursive: true, force: true });
    }
  }
}

async function runInstall(jdkName) {
  if (!jdkName) {
    console.error("Usage: jswitch install <jdk_name>");
    process.exit(1);
  }

  const jdkRoot = getJdkRootOrExit();
  const major = normalizeInstallName(jdkName);
  if (!major) {
    throw new Error('Invalid JDK name. Use for example "corretto-21" or "21".');
  }

  const available = await getCorrettoMajors();
  if (!available.includes(major)) {
    throw new Error(
      `Version not found on Amazon Corretto: ${jdkName}. Run "jswitch remote-list".`
    );
  }

  const canonicalName = `corretto-${major}`;
  const downloadUrl = `https://corretto.aws/downloads/latest/amazon-corretto-${major}-x64-windows-jdk.zip`;
  const installedPath = downloadAndExtractCorrettoZip(downloadUrl, jdkRoot, canonicalName);
  console.log(`Installation completed at: ${installedPath}`);
  console.log(`Use it now with: jswitch use ${canonicalName}`);
}

function runList() {
  const jdkRoot = getJdkRootOrExit();
  const folders = getJdkFolders(jdkRoot);
  if (folders.length === 0) {
    console.log(`No JDK found in: ${jdkRoot}`);
    return;
  }
  console.log("Available JDKs:");
  folders.forEach((name) => console.log(`- ${name}`));
}

function runUse(jdkName) {
  if (!jdkName) {
    console.error("Usage: jswitch use <jdk_name>");
    process.exit(1);
  }

  const jdkRoot = getJdkRootOrExit();
  const targetPath = path.join(jdkRoot, jdkName);
  validateDirectory(targetPath);

  setJavaHome(targetPath);
  console.log(`JAVA_HOME set to: ${targetPath}`);
  console.log("Open a new terminal session to use the updated persistent value.");
}

function runCurrent() {
  getJdkRootOrExit();
  const javaHome = readWindowsUserJavaHome();
  if (javaHome) {
    console.log(`JAVA_HOME: ${javaHome}`);
  } else {
    console.log("JAVA_HOME is not set.");
  }

  const version = getCurrentJavaVersion();
  if (version) {
    console.log("Current Java version:");
    console.log(version.split(/\r?\n/)[0]);
  } else {
    console.log("java command not found in PATH.");
  }
}

function printHelp() {
  console.log(`jSwitch - JDK manager for terminal

Commands:
  jswitch start               Configure the JDK root folder
  jswitch list                Show locally available JDKs
  jswitch remote-list         Show JDKs available on Amazon Corretto
  jswitch install <jdk_name>  Download and install a Corretto JDK
  jswitch use <jdk_name>      Set JAVA_HOME to selected JDK
  jswitch current             Show JAVA_HOME and current Java version
`);
}

async function main() {
  const [, , command, arg1] = process.argv;

  try {
    switch (command) {
      case "start":
        await runStart();
        break;
      case "list":
        runList();
        break;
      case "remote-list":
        await runRemoteList();
        break;
      case "install":
        await runInstall(arg1);
        break;
      case "use":
        runUse(arg1);
        break;
      case "current":
        runCurrent();
        break;
      case "-h":
      case "--help":
      default:
        printHelp();
        break;
    }
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

main();
