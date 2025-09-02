/**
 * setup.mjs - Mocha test setup with path aliases
 *
 * Sets up module path resolution for cleaner imports in tests
 */

// Ensure consistent timezone across tests
process.env.TZ = "UTC";

import { pathToFileURL } from "url";
import { resolve } from "path";
import dayjsLib from "dayjs";
import isSameOrBefore from "dayjs/plugin/isSameOrBefore.js";
import isSameOrAfter from "dayjs/plugin/isSameOrAfter.js";

// Define path aliases for commonly used modules
const aliases = {
    "@booking-components":
        "koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings",
    "@utils": "koha-tmpl/intranet-tmpl/prog/js/vue/utils",
    "@test-fixtures": "t/mocha/fixtures",
};

// Get project root (4 levels up from this file)
const projectRoot = resolve(new URL(import.meta.url).pathname, "../../../..");

// Create a custom module resolver
const originalResolve = import.meta.resolve;

// Override import.meta.resolve if available
if (originalResolve) {
    import.meta.resolve = function (specifier, parent) {
        // Check if specifier starts with an alias
        for (const [alias, path] of Object.entries(aliases)) {
            if (specifier.startsWith(alias)) {
                const relativePath = specifier.replace(alias, path);
                const fullPath = resolve(projectRoot, relativePath);
                return pathToFileURL(fullPath).href;
            }
        }

        // Fall back to original resolver
        return originalResolve.call(this, specifier, parent);
    };
}

// Global test setup
global.$__ = str => ({
    toString: () => str,
    format: arg => String(str).replace("%s", arg),
    includes: searchStr => String(str).includes(searchStr),
    valueOf: () => str,
});

// Minimal window shim for modules expecting browser dayjs globals
global.window = global.window || {};
// Extend local dayjs instance with required plugins once
dayjsLib.extend(isSameOrBefore);
dayjsLib.extend(isSameOrAfter);
// Expose to window to satisfy utils/dayjs.mjs expectations
global.window.dayjs = dayjsLib;
global.window.dayjs_plugin_isSameOrBefore = isSameOrBefore;
global.window.dayjs_plugin_isSameOrAfter = isSameOrAfter;

// Export aliases for manual resolution if needed
export { aliases, projectRoot };

/**
 * Resolve alias path manually for dynamic imports
 */
export function resolveAlias(specifier) {
    for (const [alias, path] of Object.entries(aliases)) {
        if (specifier.startsWith(alias)) {
            const relativePath = specifier.replace(alias, path);
            return resolve(projectRoot, relativePath);
        }
    }
    return specifier;
}
