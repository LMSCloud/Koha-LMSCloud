/**
 * module-loader.mjs - Custom ES module loader with path aliases
 *
 * Enables clean imports like:
 * import { IntervalTree } from '@booking-components/IntervalTree.mjs'
 */

import { pathToFileURL, fileURLToPath } from "url";
import { resolve as resolvePath, dirname } from "path";

// Get project root directory
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = resolvePath(__dirname, "../..");

// Define path aliases
const aliases = {
    "@booking-components/":
        "koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/",
    "@utils/": "koha-tmpl/intranet-tmpl/prog/js/vue/utils/",
    "@test-fixtures/": "t/mocha/fixtures/",
};

/**
 * Resolve hook - transforms import specifiers with aliases
 */
export async function resolve(specifier, context, nextResolve) {
    // Check for alias matches
    for (const [alias, path] of Object.entries(aliases)) {
        if (specifier.startsWith(alias)) {
            const relativePath = specifier.replace(alias, path);
            const absolutePath = resolvePath(projectRoot, relativePath);
            const fileURL = pathToFileURL(absolutePath).href;

            return {
                shortCircuit: true,
                url: fileURL,
            };
        }
    }

    // Fall back to default resolution
    return nextResolve(specifier, context);
}

/**
 * Load hook - can be used for additional processing if needed
 */
export async function load(url, context, nextLoad) {
    return nextLoad(url, context);
}

// Set up global test environment
global.$__ = str => str; // Mock translation function
