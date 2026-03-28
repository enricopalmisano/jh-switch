"use strict";

const fs = require("fs");
const path = require("path");
const { execSync, spawnSync } = require("child_process");

function javaHomePathsEqual(a, b) {
  if (a == null || b == null) {
    return false;
  }
  const na = path.resolve(String(a).trim());
  const nb = path.resolve(String(b).trim());
  if (process.platform === "win32") {
    return na.toLowerCase() === nb.toLowerCase();
  }
  return na === nb;
}

function clearUserJavaHome() {
  if (process.platform !== "win32") {
    throw new Error(
      "jhswitch currently supports JAVA_HOME updates on Windows only."
    );
  }
  try {
    execSync("reg query HKCU\\Environment /v JAVA_HOME", {
      stdio: ["pipe", "pipe", "pipe"]
    });
  } catch (_e) {
    delete process.env.JAVA_HOME;
    return;
  }
  execSync("reg delete HKCU\\Environment /v JAVA_HOME /f", {
    stdio: ["pipe", "pipe", "pipe"]
  });
  delete process.env.JAVA_HOME;
}

function setJavaHome(jdkPath) {
  if (process.platform !== "win32") {
    throw new Error(
      "jhswitch currently supports JAVA_HOME updates on Windows only."
    );
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

function versionOutputFromResult(result) {
  if (result.error) {
    return null;
  }
  const code = result.status;
  if (code !== 0 && code !== null) {
    return null;
  }
  const combined = `${result.stdout || ""}\n${result.stderr || ""}`.trim();
  if (!combined) {
    return null;
  }
  const low = combined.toLowerCase();
  if (
    low.includes("not recognized") ||
    low.includes("non riconosciuto") ||
    low.includes("non è riconosciuto") ||
    low.includes("non reconnu")
  ) {
    return null;
  }
  return combined;
}

function windowsJavaHomesToTry() {
  const fromReg = readWindowsUserJavaHome();
  const fromEnv = process.env.JAVA_HOME || null;
  const seen = new Set();
  const ordered = [];
  for (const raw of [fromReg, fromEnv]) {
    if (!raw) {
      continue;
    }
    const normalized = path.resolve(raw.trim());
    if (seen.has(normalized)) {
      continue;
    }
    seen.add(normalized);
    ordered.push(normalized);
  }
  return ordered;
}

function getCurrentJavaVersion() {
  if (process.platform === "win32") {
    for (const javaHome of windowsJavaHomesToTry()) {
      const javaExe = path.join(javaHome, "bin", "java.exe");
      if (!fs.existsSync(javaExe)) {
        continue;
      }
      const fromHome = spawnSync(javaExe, ["-version"], {
        encoding: "utf8",
        stdio: ["pipe", "pipe", "pipe"]
      });
      const out = versionOutputFromResult(fromHome);
      if (out) {
        return out;
      }
    }
  }

  const fromPath = spawnSync("java", ["-version"], {
    encoding: "utf8",
    shell: process.platform === "win32",
    stdio: ["pipe", "pipe", "pipe"]
  });
  return versionOutputFromResult(fromPath);
}

module.exports = {
  javaHomePathsEqual,
  clearUserJavaHome,
  setJavaHome,
  readWindowsUserJavaHome,
  getCurrentJavaVersion
};
