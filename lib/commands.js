"use strict";

const fs = require("fs");
const path = require("path");
const { fetchText } = require("./http-windows");
const { downloadAndExtractJdkZip } = require("./archive");
const {
  saveConfig,
  normalizeInputPath,
  validateDirectory,
  getJdkRootOrExit,
  getJdkFolders
} = require("./config-store");
const {
  setJavaHome,
  readWindowsUserJavaHome,
  getCurrentJavaVersion
} = require("./java-env");
const { askQuestion } = require("./prompt");
const { strategies, resolveInstall } = require("./providers");

async function runStart() {
  const input = await askQuestion(
    "Enter the folder where JDKs will be installed and managed: "
  );
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

async function runRemoteList() {
  getJdkRootOrExit();

  for (let i = 0; i < strategies.length; i++) {
    const strategy = strategies[i];
    const offers = await strategy.listRemoteOffers(fetchText);
    console.log(`${strategy.displayName} (Windows x64, latest):`);
    offers.forEach((o) => console.log(`  - ${o.folderName}`));
    if (i < strategies.length - 1) {
      console.log("");
    }
  }
}

async function runInstall(jdkName) {
  if (!jdkName) {
    console.error("Usage: jhswitch install <jdk_name>");
    process.exit(1);
  }

  const jdkRoot = getJdkRootOrExit();
  const resolved = resolveInstall(jdkName);
  if (!resolved) {
    throw new Error(
      'Invalid JDK name. Examples: "corretto-21" or "21" (Corretto), "microsoft-jdk-21" (Microsoft).'
    );
  }

  const { strategy, selection } = resolved;
  const offers = await strategy.listRemoteOffers(fetchText);
  const allowed = new Set(offers.map((o) => o.folderName));
  if (!allowed.has(selection.folderName)) {
    throw new Error(
      `${selection.folderName} is not offered by ${strategy.displayName}. Run "jhswitch remote-list".`
    );
  }

  const downloadUrl = strategy.getWindowsX64ZipUrl(selection);
  const installedPath = downloadAndExtractJdkZip(
    downloadUrl,
    jdkRoot,
    selection.folderName
  );
  console.log(`Installation completed at: ${installedPath}`);
  console.log(`Use it now with: jhswitch use ${selection.folderName}`);
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
    console.error("Usage: jhswitch use <jdk_name>");
    process.exit(1);
  }

  const jdkRoot = getJdkRootOrExit();
  const targetPath = path.join(jdkRoot, jdkName);
  validateDirectory(targetPath);

  setJavaHome(targetPath);
  console.log(`JAVA_HOME set to: ${targetPath}`);
  console.log(
    "Open a new terminal session to use the updated persistent value."
  );
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
  } else if (javaHome) {
    console.log(
      "Could not run Java from JAVA_HOME or PATH (check that %JAVA_HOME%\\bin\\java.exe exists)."
    );
  } else {
    console.log("JAVA_HOME is not set and \"java\" was not found on PATH.");
  }
}

function printHelp() {
  console.log(`jhSwitch - JDK manager for terminal

Commands:
  jhswitch start               Configure the JDK root folder
  jhswitch list                Show locally available JDKs
  jhswitch remote-list         Show JDKs from all configured vendors (remote)
  jhswitch install <jdk_name>  Download and install a JDK (Corretto / Microsoft, …)
  jhswitch use <jdk_name>      Set JAVA_HOME to selected JDK
  jhswitch current             Show JAVA_HOME and current Java version
`);
}

module.exports = {
  runStart,
  runRemoteList,
  runInstall,
  runList,
  runUse,
  runCurrent,
  printHelp
};
