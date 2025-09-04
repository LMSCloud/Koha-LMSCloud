// Adapter for dayjs to use the globally loaded instance from js-date-format.inc
// This prevents duplicate bundling and maintains TypeScript support

/** @typedef {typeof import('dayjs')} DayjsModule */
/** @typedef {import('dayjs').PluginFunc} DayjsPlugin */

if (!window["dayjs"]) {
    throw new Error("dayjs is not available globally. Please ensure js-date-format.inc is included before this module.");
}

/** @type {DayjsModule} */
const dayjs = /** @type {DayjsModule} */ (window["dayjs"]);

// Required plugins for booking functionality
const requiredPlugins = [
    { name: 'isSameOrBefore', global: 'dayjs_plugin_isSameOrBefore' },
    { name: 'isSameOrAfter', global: 'dayjs_plugin_isSameOrAfter' }
];

// Verify and extend required plugins
for (const plugin of requiredPlugins) {
    if (!(plugin.global in window)) {
        throw new Error(`Required dayjs plugin '${plugin.name}' is not available. Please ensure js-date-format.inc loads the ${plugin.name} plugin.`);
    }
    dayjs.extend(/** @type {DayjsPlugin} */ (window[plugin.global]));
}

export default dayjs;
