// Utilities for comparing and handling mixed string/number IDs consistently

export function idsEqual(a, b) {
    if (a == null || b == null) return false;
    return String(a) === String(b);
}

export function includesId(list, target) {
    if (!Array.isArray(list)) return false;
    return list.some(id => idsEqual(id, target));
}

export function toIdSet(list) {
    if (!Array.isArray(list)) return new Set();
    return new Set(list.map(v => String(v)));
}

