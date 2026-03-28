"use strict";

const fs = require("fs");
const path = require("path");
const os = require("os");

const CONFIG_DIR = path.join(os.homedir(), ".jhswitch");
const CONFIG_PATH = path.join(CONFIG_DIR, "config.json");

function defaultJdkRoot() {
  return path.join(os.homedir(), ".jhsdk");
}

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
  } catch (_error) {
    console.error("Error: invalid configuration file.");
    process.exit(1);
  }
}

function saveConfig(config) {
  ensureConfigDir();
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2), "utf8");
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

function resolveStoredJdkRoot(config) {
  let root = config.jdkRoot;
  if (!root || String(root).trim() === "") {
    root = defaultJdkRoot();
  } else {
    root = normalizeInputPath(String(root).trim());
  }
  return root;
}

function getJdkRoot() {
  const config = loadConfig();
  const root = resolveStoredJdkRoot(config);
  if (!fs.existsSync(root)) {
    fs.mkdirSync(root, { recursive: true });
  }
  validateDirectory(root);
  return root;
}

function getJdkFolders(jdkRoot) {
  return fs
    .readdirSync(jdkRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort((a, b) => a.localeCompare(b));
}

module.exports = {
  CONFIG_DIR,
  CONFIG_PATH,
  defaultJdkRoot,
  loadConfig,
  saveConfig,
  normalizeInputPath,
  validateDirectory,
  getJdkRoot,
  getJdkFolders
};
