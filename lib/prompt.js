"use strict";

const readline = require("readline");

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

async function confirmYesNo(questionText) {
  const answer = (await askQuestion(questionText)).trim().toLowerCase();
  return answer === "y" || answer === "yes";
}

module.exports = { askQuestion, confirmYesNo };
