import { defineConfig } from "cypress";
import communityConfig from "./cypress.config";

/**
 * The community Cypress configuration plus the LMSCloud tasks.
 *
 * Runs every community spec unchanged; the specs under
 * t/cypress/integration/LMSCloud need this file for their lms* tasks:
 *
 *   npx cypress run --config-file cypress.lmscloud.config.ts
 */
export default defineConfig({
    ...communityConfig,
    e2e: {
        ...communityConfig.e2e,
        setupNodeEvents(on, config) {
            const resolved = communityConfig.e2e.setupNodeEvents(on, config);
            require("./t/cypress/plugins/lmscloud/index.js")(on, resolved);
            return resolved;
        },
    },
});
