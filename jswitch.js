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
    console.error("Errore: file di configurazione non valido.");
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

function validateJdkRoot(jdkRoot) {
  if (!fs.existsSync(jdkRoot)) {
    throw new Error(`La cartella non esiste: ${jdkRoot}`);
  }
  const stats = fs.statSync(jdkRoot);
  if (!stats.isDirectory()) {
    throw new Error(`Il percorso non e una cartella: ${jdkRoot}`);
  }
}

function getJdkRootOrExit() {
  const config = loadConfig();
  if (!config.jdkRoot) {
    console.error(
      'Nessuna cartella JDK configurata. Esegui prima "jswitch start".'
    );
    process.exit(1);
  }
  validateJdkRoot(config.jdkRoot);
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
    throw new Error("Al momento jswitch supporta la modifica di JAVA_HOME su Windows.");
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
  const input = await askQuestion("Inserisci il percorso della cartella con le JDK installate: ");
  if (!input) {
    console.error("Percorso non valido.");
    process.exit(1);
  }
  const jdkRoot = normalizeInputPath(input);
  validateJdkRoot(jdkRoot);
  saveConfig({ jdkRoot });
  console.log(`Configurazione salvata: ${jdkRoot}`);
}

function runList() {
  const jdkRoot = getJdkRootOrExit();
  const folders = getJdkFolders(jdkRoot);
  if (folders.length === 0) {
    console.log(`Nessuna JDK trovata in: ${jdkRoot}`);
    return;
  }
  console.log("JDK disponibili:");
  folders.forEach((name) => console.log(`- ${name}`));
}

function runUse(jdkName) {
  if (!jdkName) {
    console.error('Uso: jswitch use <nome_jdk>');
    process.exit(1);
  }

  const jdkRoot = getJdkRootOrExit();
  const targetPath = path.join(jdkRoot, jdkName);
  validateJdkRoot(targetPath);

  setJavaHome(targetPath);
  console.log(`JAVA_HOME impostata su: ${targetPath}`);
  console.log("Apri un nuovo terminale per usare il nuovo valore persistente.");
}

function runCurrent() {
  const javaHome = readWindowsUserJavaHome();
  if (javaHome) {
    console.log(`JAVA_HOME: ${javaHome}`);
  } else {
    console.log("JAVA_HOME non impostata.");
  }

  const version = getCurrentJavaVersion();
  if (version) {
    console.log("Versione Java corrente:");
    console.log(version.split(/\r?\n/)[0]);
  } else {
    console.log("Comando java non trovato nel PATH.");
  }
}

function printHelp() {
  console.log(`jSwitch - gestore JDK da terminale

Comandi:
  jswitch start               Configura la cartella radice delle JDK
  jswitch list                Mostra le JDK disponibili
  jswitch use <nome_jdk>      Imposta JAVA_HOME sulla JDK scelta
  jswitch current             Mostra JAVA_HOME e java corrente
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
    console.error(`Errore: ${error.message}`);
    process.exit(1);
  }
}

main();
