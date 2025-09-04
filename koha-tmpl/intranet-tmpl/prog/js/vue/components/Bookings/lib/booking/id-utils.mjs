// Utilities for comparing and handling mixed string/number IDs consistently

export function idsEqual(a, b) {
    if (a == null || b == null) return false;
    return String(a) === String(b);
}

export function includesId(list, target) {
    if (!Array.isArray(list)) return false;
    return list.some(id => idsEqual(id, target));
}

/**
 * Normalize an identifier's type to match a sample (number|string) for strict comparisons.
 * If sample is a number, casts value to number; otherwise casts to string.
 * Falls back to string when sample is null/undefined.
 *
 * @param {unknown} sample - A sample value to infer the desired type from
 * @param {unknown} value - The value to normalize
 * @returns {string|number|null}
 */
export function normalizeIdType(sample, value) {
    if (!value == null) return null;
    return typeof sample === "number" ? Number(value) : String(value);
}

export function toIdSet(list) {
    if (!Array.isArray(list)) return new Set();
    return new Set(list.map(v => String(v)));
}

/**
 * Normalize any value to a string ID (for Set/Map keys and comparisons)
 * @param {unknown} value
 * @returns {string}
 */
export function toStringId(value) {
    return String(value);
}
