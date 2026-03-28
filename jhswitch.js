#!/usr/bin/env node

"use strict";

const {
  runStart,
  runRemoteList,
  runInstall,
  runList,
  runUse,
  runCurrent,
  printHelp
} = require("./lib/commands");

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
      case "remote-list":
        await runRemoteList();
        break;
      case "install":
        await runInstall(arg1);
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
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

main();
