"use strict";

const fs = require("fs");
const path = require("path");
const { fetchText } = require("./http-windows");
const { downloadAndExtractJdkZip } = require("./archive");
const {
  loadConfig,
  saveConfig,
  defaultJdkRoot,
  normalizeInputPath,
  validateDirectory,
  getJdkRoot,
  getJdkFolders
} = require("./config-store");
const {
  javaHomePathsEqual,
  clearUserJavaHome,
  setJavaHome,
  readWindowsUserJavaHome,
  getCurrentJavaVersion
} = require("./java-env");
const { askQuestion, confirmYesNo } = require("./prompt");
const { strategies, resolveInstall } = require("./providers");

function assertSafeJdkFolderName(name) {
  const s = String(name || "").trim();
  if (!s) {
    throw new Error("JDK name is required.");
  }
  if (s !== path.basename(s) || /[/\\]/.test(s) || s.includes("..")) {
    throw new Error("Invalid JDK name.");
  }
  return s;
}

function activateJdkByFolderName(jdkFolderName) {
  const jdkRoot = getJdkRoot();
  const targetPath = path.join(jdkRoot, jdkFolderName);
  validateDirectory(targetPath);
  setJavaHome(targetPath);
}

function inferJdkFolderNameFromJavaHome(javaHome, oldRoot) {
  if (!javaHome || !oldRoot) {
    return null;
  }
  const h = path.resolve(String(javaHome).trim());
  const o = path.resolve(String(oldRoot).trim());
  const rel = path.relative(o, h);
  if (!rel || rel.startsWith("..") || path.isAbsolute(rel)) {
    return null;
  }
  const parts = rel.split(path.sep).filter(Boolean);
  return parts[0] || null;
}

function moveJdkSubfolders(sourceRoot, destRoot) {
  const src = path.resolve(sourceRoot);
  const dst = path.resolve(destRoot);
  if (src === dst) {
    return;
  }
  if (!fs.existsSync(src)) {
    return;
  }
  if (!fs.existsSync(dst)) {
    fs.mkdirSync(dst, { recursive: true });
  }
  const entries = fs.readdirSync(src, { withFileTypes: true });
  for (const ent of entries) {
    if (!ent.isDirectory()) {
      continue;
    }
    const name = ent.name;
    const from = path.join(src, name);
    const to = path.join(dst, name);
    if (fs.existsSync(to)) {
      console.log(`Skipped (already exists in destination): ${name}`);
      continue;
    }
    try {
      fs.renameSync(from, to);
    } catch (_e) {
      fs.cpSync(from, to, { recursive: true });
      fs.rmSync(from, { recursive: true, force: true });
    }
  }
}

async function maybeOfferJavaHomeUpdateAfterMove(oldRoot, newRoot, didMove) {
  if (!didMove) {
    return;
  }
  const regHome = readWindowsUserJavaHome();
  if (!regHome) {
    return;
  }
  const jdkName = inferJdkFolderNameFromJavaHome(regHome, oldRoot);
  if (!jdkName) {
    return;
  }
  const newJavaHome = path.resolve(path.join(newRoot, jdkName));
  if (!fs.existsSync(newJavaHome)) {
    return;
  }
  const msg =
    `JAVA_HOME points to a JDK under the previous folder. Update JAVA_HOME to the new path for "${jdkName}"?\n  ${newJavaHome}\n(Y=Yes, N=No): `;
  if (await confirmYesNo(msg)) {
    setJavaHome(newJavaHome);
    console.log(`JAVA_HOME set to: ${newJavaHome}`);
    console.log(
      "Open a new terminal session to use the updated persistent value."
    );
  }
}

async function runChangeDir() {
  const oldRoot = getJdkRoot();
  const input = await askQuestion(
    "Enter the folder where JDKs will be installed and managed: "
  );
  if (!input) {
    console.error("Invalid path.");
    process.exit(1);
  }
  const newRoot = normalizeInputPath(input);
  if (!fs.existsSync(newRoot)) {
    fs.mkdirSync(newRoot, { recursive: true });
  }
  validateDirectory(newRoot);

  if (path.resolve(oldRoot) === path.resolve(newRoot)) {
    const config = loadConfig();
    saveConfig({ ...config, jdkRoot: newRoot });
    console.log(`JDK install folder unchanged: ${newRoot}`);
    return;
  }

  const move = await confirmYesNo(
    `Move JDK folders from the previous location to the new one?\n  From: ${oldRoot}\n  To:   ${newRoot}\n(Y=Yes, N=No): `
  );
  if (move) {
    moveJdkSubfolders(oldRoot, newRoot);
  }

  const config = loadConfig();
  saveConfig({ ...config, jdkRoot: newRoot });
  console.log(`JDK install folder set to: ${newRoot}`);

  await maybeOfferJavaHomeUpdateAfterMove(oldRoot, newRoot, move);
  await maybeOfferDeleteOldJdkRoot(oldRoot, newRoot);
}

function canOfferDeleteOldJdkRoot(oldRoot, newRoot) {
  const o = path.resolve(oldRoot);
  const n = path.resolve(newRoot);
  if (o === n) {
    return false;
  }
  const rel = path.relative(o, n);
  if (rel && !rel.startsWith("..") && !path.isAbsolute(rel)) {
    return false;
  }
  if (!fs.existsSync(o)) {
    return false;
  }
  return true;
}

async function maybeOfferDeleteOldJdkRoot(oldRoot, newRoot) {
  if (!canOfferDeleteOldJdkRoot(oldRoot, newRoot)) {
    return;
  }
  const msg =
    `Delete the previous JDK install folder and all of its contents?\n  ${oldRoot}\n(Y=Yes, N=No): `;
  if (await confirmYesNo(msg)) {
    fs.rmSync(oldRoot, { recursive: true, force: true });
    console.log(`Removed folder: ${oldRoot}`);
  }
}

async function runRemoteList() {
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

  const jdkRoot = getJdkRoot();
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
  const jdkRoot = getJdkRoot();
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

  const name = assertSafeJdkFolderName(jdkName);
  const jdkRoot = getJdkRoot();
  const targetPath = path.join(jdkRoot, name);
  activateJdkByFolderName(name);
  console.log(`JAVA_HOME set to: ${targetPath}`);
  console.log(
    "Open a new terminal session to use the updated persistent value."
  );
}

async function runUninstall(jdkName) {
  if (!jdkName) {
    console.error("Usage: jhswitch uninstall <jdk_name>");
    process.exit(1);
  }

  const name = assertSafeJdkFolderName(jdkName);
  const jdkRoot = getJdkRoot();
  const targetPath = path.join(jdkRoot, name);

  const folders = getJdkFolders(jdkRoot);
  if (!folders.includes(name)) {
    throw new Error(`JDK not found: ${name}`);
  }

  validateDirectory(targetPath);
  const regHome = readWindowsUserJavaHome();
  const inUse = javaHomePathsEqual(regHome, targetPath);

  fs.rmSync(targetPath, { recursive: true, force: true });
  console.log(`Removed JDK: ${name}`);

  if (!inUse) {
    return;
  }

  const remaining = getJdkFolders(jdkRoot);
  if (remaining.length > 0) {
    const first = remaining[0];
    const msg =
      `JAVA_HOME pointed to the removed JDK. Run "jhswitch use" for the first remaining JDK (${first})? (Y=Yes, N=No): `;
    if (await confirmYesNo(msg)) {
      activateJdkByFolderName(first);
      console.log(`JAVA_HOME set to: ${path.join(getJdkRoot(), first)}`);
      console.log(
        "Open a new terminal session to use the updated persistent value."
      );
    }
    return;
  }

  const clearMsg =
    "No JDKs are left in the install folder. Remove JAVA_HOME from your user environment? (Y=Yes, N=No): ";
  if (await confirmYesNo(clearMsg)) {
    clearUserJavaHome();
    console.log(
      "JAVA_HOME was removed from your user environment. Open a new terminal session for changes to apply everywhere."
    );
  }
}

function runCurrentDir() {
  console.log(getJdkRoot());
}

async function runResetDefDir() {
  const oldRoot = getJdkRoot();
  const newRoot = defaultJdkRoot();

  if (path.resolve(oldRoot) === path.resolve(newRoot)) {
    const config = loadConfig();
    if (config.jdkRoot) {
      const next = { ...config };
      delete next.jdkRoot;
      saveConfig(next);
      console.log(
        "JDK install folder was already the default; removed redundant path from config."
      );
    } else {
      console.log(`JDK install folder is already the default: ${newRoot}`);
    }
    return;
  }

  const move = await confirmYesNo(
    `Move JDK folders from the previous location to the default folder?\n  From: ${oldRoot}\n  To:   ${newRoot}\n(Y=Yes, N=No): `
  );
  if (move) {
    if (!fs.existsSync(newRoot)) {
      fs.mkdirSync(newRoot, { recursive: true });
    }
    moveJdkSubfolders(oldRoot, newRoot);
  }

  const config = loadConfig();
  const next = { ...config };
  delete next.jdkRoot;
  saveConfig(next);

  const root = getJdkRoot();
  console.log(`JDK install folder reset to default: ${root}`);

  await maybeOfferJavaHomeUpdateAfterMove(oldRoot, newRoot, move);
  await maybeOfferDeleteOldJdkRoot(oldRoot, newRoot);
}

function runCurrent() {
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
  jhswitch change-dir          Set the JDK install folder (default: %USERPROFILE%\\.jhsdk)
  jhswitch current-dir         Show the JDK install folder in use
  jhswitch reset-def-dir       Restore the default JDK install folder (%USERPROFILE%\\.jhsdk)
  jhswitch list                Show locally available JDKs
  jhswitch remote-list         Show JDKs from all configured vendors (remote)
  jhswitch install <jdk_name>  Download and install a JDK (Corretto / Microsoft, …)
  jhswitch uninstall <jdk_name> Remove a downloaded JDK folder
  jhswitch use <jdk_name>      Set JAVA_HOME to selected JDK
  jhswitch current             Show JAVA_HOME and current Java version
`);
}

module.exports = {
  runChangeDir,
  runCurrentDir,
  runResetDefDir,
  runRemoteList,
  runInstall,
  runList,
  runUninstall,
  runUse,
  runCurrent,
  printHelp
};
