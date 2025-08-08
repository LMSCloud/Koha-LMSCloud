/**
 * Safe accessors for window-scoped globals using bracket notation
 */

/**
 * Get a value from window by key using bracket notation
 * @param {string} key
 * @returns {any}
 */
export function win(key) {
    if (typeof window === "undefined") return undefined;
    return window[key];
}

/**
 * Get a value from window with default initialization
 * @param {string} key
 * @param {any} defaultValue
 * @returns {any}
 */
export function getWindowValue(key, defaultValue) {
    if (typeof window === "undefined") return defaultValue;
    if (window[key] === undefined) window[key] = defaultValue;
    return window[key];
}


