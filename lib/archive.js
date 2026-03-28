"use strict";

const fs = require("fs");
const path = require("path");
const os = require("os");
const { execSync } = require("child_process");
const { assertWindows } = require("./http-windows");

function downloadAndExtractJdkZip(downloadUrl, installRoot, folderName) {
  assertWindows();

  const tempBase = path.join(os.tmpdir(), `jhswitch-${Date.now()}`);
  const zipPath = path.join(tempBase, "jdk.zip");
  const extractPath = path.join(tempBase, "unzipped");
  fs.mkdirSync(extractPath, { recursive: true });

  try {
    const escapedUrl = downloadUrl.replace(/'/g, "''");
    const escapedZip = zipPath.replace(/'/g, "''");
    const escapedExtract = extractPath.replace(/'/g, "''");

    console.log(`Download: ${downloadUrl}`);
    execSync(
      `powershell -NoProfile -Command "Invoke-WebRequest -UseBasicParsing -Uri '${escapedUrl}' -OutFile '${escapedZip}'"`,
      { stdio: "inherit" }
    );

    execSync(
      `powershell -NoProfile -Command "Expand-Archive -Path '${escapedZip}' -DestinationPath '${escapedExtract}' -Force"`,
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

module.exports = { downloadAndExtractJdkZip };
