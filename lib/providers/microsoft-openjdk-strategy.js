"use strict";

const DOWNLOAD_DOC =
  "https://learn.microsoft.com/en-us/java/openjdk/download";
const FALLBACK_MAJORS = ["11", "17", "21", "25"];

function tryParseInstallRequest(rawName) {
  const value = String(rawName || "").trim();
  if (!value) {
    return null;
  }
  const lower = value.toLowerCase();
  const m = lower.match(/^(?:microsoft-jdk|ms-?jdk|msopenjdk)-(\d+)$/);
  if (!m) {
    return null;
  }
  return { folderName: `microsoft-jdk-${m[1]}`, major: m[1] };
}

async function listRemoteOffers(fetchText) {
  let majors = [];
  try {
    const page = await fetchText(DOWNLOAD_DOC);
    majors = [...page.matchAll(/^## OpenJDK (\d+)/gm)].map((x) => x[1]);
    majors = [...new Set(majors)];
  } catch (_e) {
    majors = [];
  }
  if (majors.length === 0) {
    majors = [...FALLBACK_MAJORS];
  }
  majors.sort((a, b) => Number(a) - Number(b));
  return majors.map((major) => ({ folderName: `microsoft-jdk-${major}` }));
}

function getWindowsX64ZipUrl(selection) {
  return `https://aka.ms/download-jdk/microsoft-jdk-${selection.major}-windows-x64.zip`;
}

module.exports = {
  id: "microsoft-openjdk",
  displayName: "Microsoft Build of OpenJDK",
  listRemoteOffers,
  tryParseInstallRequest,
  getWindowsX64ZipUrl
};
