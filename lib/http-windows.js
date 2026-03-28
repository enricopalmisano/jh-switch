"use strict";

const { execSync } = require("child_process");

function assertWindows() {
  if (process.platform !== "win32") {
    throw new Error("This command is available on Windows only.");
  }
}

function fetchText(url) {
  assertWindows();
  const escapedUrl = url.replace(/'/g, "''");
  return execSync(
    `powershell -NoProfile -Command "Invoke-WebRequest -UseBasicParsing -Uri '${escapedUrl}' | Select-Object -ExpandProperty Content"`,
    { encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] }
  );
}

module.exports = { fetchText, assertWindows };
