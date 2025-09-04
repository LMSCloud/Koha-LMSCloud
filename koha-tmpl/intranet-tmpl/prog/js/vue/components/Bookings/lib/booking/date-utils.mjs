import dayjs from "../../../../utils/dayjs.mjs";

// Convert an array of ISO strings (or Date-like values) to plain Date objects
export function isoArrayToDates(values) {
    if (!Array.isArray(values)) return [];
    return values.filter(Boolean).map(d => dayjs(d).toDate());
}

