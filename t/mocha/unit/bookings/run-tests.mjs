#!/usr/bin/env node

/**
 * run-tests.mjs - Simple test runner for booking system tests
 *
 * Wrapper around yarn scripts for convenience
 */

import { spawn } from "child_process";

const args = process.argv.slice(2);
const watchMode = args.includes("--watch");

console.log("🧪 Running Booking System Tests...\n");

// Build the command with specific test path
const scriptName = watchMode ? "test:mocha:watch" : "test:mocha";
const testPath = "t/mocha/unit/bookings/*.test.mjs";

const testProcess = spawn("yarn", [scriptName, testPath], {
    stdio: "inherit",
    shell: true,
    cwd: process.cwd().replace(/t\/mocha\/unit\/bookings.*/, ""), // Go to project root
});

testProcess.on("close", code => {
    if (code === 0) {
        console.log("\n✅ All booking tests passed!");
        if (!watchMode) {
            console.log("\n💡 To run in watch mode: node run-tests.mjs --watch");
            console.log("💡 To run all mocha tests: yarn test:mocha");
            console.log("💡 To run specific tests: yarn test:mocha --grep 'pattern'");
        }
    } else {
        console.log(`\n❌ Tests failed with exit code ${code}`);
        process.exit(code);
    }
});

testProcess.on("error", error => {
    console.error("Failed to start test process:", error);
    console.log("\n💡 Make sure you run from the project root directory");
    console.log("💡 Try: yarn test:mocha 't/mocha/unit/bookings/*.test.mjs'");
    process.exit(1);
});
