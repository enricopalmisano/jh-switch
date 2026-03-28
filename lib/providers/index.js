"use strict";

const strategies = [
  require("./microsoft-openjdk-strategy"),
  require("./amazon-corretto-strategy")
];

function resolveInstall(rawName) {
  for (const strategy of strategies) {
    const selection = strategy.tryParseInstallRequest(rawName);
    if (selection) {
      return { strategy, selection };
    }
  }
  return null;
}

module.exports = {
  strategies,
  resolveInstall
};
