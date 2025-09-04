import dayjs from "../../../../utils/dayjs.mjs";

// Convert an array of ISO strings (or Date-like values) to plain Date objects
export function isoArrayToDates(values) {
    if (!Array.isArray(values)) return [];
    return values.filter(Boolean).map(d => dayjs(d).toDate());
}

// Convert a Date-like input to ISO string
export function toISO(input) {
    return dayjs(
        /** @type {import('dayjs').ConfigType} */ (input)
    ).toISOString();
}

// Normalize any Date-like input to a dayjs instance
export function toDayjs(input) {
    return dayjs(/** @type {import('dayjs').ConfigType} */ (input));
}

// Get start-of-day timestamp for a Date-like input
export function startOfDayTs(input) {
    return toDayjs(input).startOf("day").valueOf();
}

// Get end-of-day timestamp for a Date-like input
export function endOfDayTs(input) {
    return toDayjs(input).endOf("day").valueOf();
}

// Format a Date-like input as YYYY-MM-DD
export function formatYMD(input) {
    return toDayjs(input).format("YYYY-MM-DD");
}

// Add or subtract days returning a dayjs instance
export function addDays(input, days) {
    return toDayjs(input).add(days, "day");
}
export function subDays(input, days) {
    return toDayjs(input).subtract(days, "day");
}
