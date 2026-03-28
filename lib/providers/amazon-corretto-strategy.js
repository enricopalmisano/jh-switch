"use strict";

const DOWNLOAD_PAGE = "https://corretto.aws/downloads/";

function tryParseInstallRequest(rawName) {
  const value = String(rawName || "").trim().toLowerCase();
  if (!value) {
    return null;
  }
  let m = value.match(/(?:amazon-)?corretto-(\d+)$/);
  if (m) {
    return { folderName: `corretto-${m[1]}`, major: m[1] };
  }
  m = value.match(/^(\d+)$/);
  if (m) {
    return { folderName: `corretto-${m[1]}`, major: m[1] };
  }
  return null;
}

async function listRemoteOffers(fetchText) {
  const page = await fetchText(DOWNLOAD_PAGE);
  const majors = Array.from(page.matchAll(/corretto-(\d+)-ug/g))
    .map((x) => x[1])
    .filter((v, i, arr) => arr.indexOf(v) === i)
    .sort((a, b) => Number(a) - Number(b));

  if (majors.length === 0) {
    throw new Error("Unable to fetch Amazon Corretto remote list.");
  }
  return majors.map((major) => ({ folderName: `corretto-${major}` }));
}

function getWindowsX64ZipUrl(selection) {
  return `https://corretto.aws/downloads/latest/amazon-corretto-${selection.major}-x64-windows-jdk.zip`;
}

module.exports = {
  id: "corretto",
  displayName: "Amazon Corretto",
  listRemoteOffers,
  tryParseInstallRequest,
  getWindowsX64ZipUrl
};
