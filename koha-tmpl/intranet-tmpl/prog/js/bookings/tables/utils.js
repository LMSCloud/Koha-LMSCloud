// @ts-check
/**
 * Shared utilities for bookings tables modules
 */

/**
 * Generic accessor for window keys using bracket notation
 * @param {string} key
 * @returns {any}
 */
export function win(key) {
    /** @type {any} */
    const w = window;
    return w[key];
}

/**
 * Get a value from window by key, initializing with a default if undefined.
 * @template T
 * @param {string} key
 * @param {T} defaultValue
 * @returns {T}
 */
export function getWindowValue(key, defaultValue) {
    /** @type {any} */
    const w = window;
    if (typeof w[key] === "undefined") {
        w[key] = defaultValue;
    }
    return w[key];
}

/**
 * Set a value on window by key using bracket notation.
 * @param {string} key
 * @param {any} value
 */
export function setWindowValue(key, value) {
    /** @type {any} */
    const w = window;
    w[key] = value;
}

/**
 * Escape a string for safe inclusion in HTML attribute values
 * @param {any} value
 * @returns {string}
 */
export function escapeAttr(value) {
    const s = String(value ?? "");
    return s
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;")
        .replace(/[\r\n]+/g, " ");
}

/**
 * Get global dayjs function
 * @returns {any}
 */
export function dayjsFn() {
    /** @type {any} */
    const w = window;
    return w["dayjs"];
}

/**
 * Get global $date function
 * @returns {(d:any)=>string}
 */
export function $dateFn() {
    /** @type {any} */
    const w = window;
    return w["$date"] || (d => String(d ?? ""));
}

/**
 * Get global $biblio_to_html function
 * @returns {(b:any, opts:any)=>string}
 */
export function $biblioToHtmlFn() {
    /** @type {any} */
    const w = window;
    return w["$biblio_to_html"] || ((b) => (b && b.title) || "");
}

/**
 * Get global $patron_to_html function
 * @returns {(p:any, opts:any)=>string}
 */
export function $patronToHtmlFn() {
    /** @type {any} */
    const w = window;
    return (
        w["$patron_to_html"] ||
        ((p) =>
            p ? [p.firstname, p.surname].filter(Boolean).join(" ") : "")
    );
}

/**
 * Get AdditionalFields helper object
 * @returns {any}
 */
export function additionalFields() {
    /** @type {any} */
    const w = window;
    return w["AdditionalFields"];
}

/**
 * Permission flag
 * @returns {boolean}
 */
export function canManageBookings() {
    /** @type {any} */
    const w = window;
    return !!w["CAN_user_circulate_manage_bookings"];
}

/**
 * Normalize a jQuery select value (string|string[]) to string
 * @param {JQuery} $select
 * @returns {string}
 */
export function getSelectValueString($select) {
    const v = $select.val();
    return Array.isArray(v) ? String(v[0] ?? "") : String(v ?? "");
}

/**
 * Reduce DOM churn by syncing select options to desired list
 * @param {JQuery} $select
 * @param {Array<{_id:any,_str:string}>} options
 */
export function syncSelectOptions($select, options) {
    const currentOptions = $select
        .find("option")
        .not(":first")
        .map(function () {
            return /** @type {any} */ ($(this)).val();
        })
        .get();
    const newOptionValues = options.map(o => o._id);
    const changed =
        currentOptions.length === 0 ||
        currentOptions.length !== newOptionValues.length ||
        !currentOptions.every(val => newOptionValues.includes(val));
    if (!changed) return;
    $select.find("option").not(":first").remove();
    options.forEach(opt => {
        $select.append(`<option value="${opt._id}">${opt._str}</option>`);
    });
}

/**
 * Build a date range input inside a header cell
 * @param {JQuery} $th
 * @param {string} inputId
 * @returns {JQuery}
 */
export function buildDateRangeInput($th, inputId) {
    const html =
        '<input type="text" id="' +
        inputId +
        '" placeholder="Select date range" />';
    $th.html(html);
    return $("#" + inputId);
}

/**
 * Generate a flatpickr configuration from Koha globals
 * @param {object} overrides
 * @returns {any}
 */
export function getFlatpickrConfig(overrides = {}) {
    return {
        mode: "range",
        dateFormat: win("flatpickr_dateformat_string"),
        locale: {
            firstDayOfWeek: win("calendarFirstDayOfWeek"),
            weekdays: win("flatpickr_weekdays"),
            months: win("flatpickr_months"),
        },
        ...overrides,
    };
}

/**
 * Convert flatpickr selectedDates to ISO bound object
 * @param {Date[]} selectedDates
 * @param {{hour:number,minute:number,second:number,millisecond:number}} dayStart
 * @param {{hour:number,minute:number,second:number,millisecond:number}} dayEnd
 * @returns {{">=": string, "<=": string} | undefined}
 */
export function rangeToIsoBounds(selectedDates, dayStart, dayEnd) {
    if (!selectedDates || selectedDates.length !== 2) return undefined;
    const fromDate = new Date(selectedDates[0]);
    const toDate = new Date(selectedDates[1]);
    fromDate.setHours(
        dayStart.hour,
        dayStart.minute,
        dayStart.second,
        dayStart.millisecond
    );
    toDate.setHours(
        dayEnd.hour,
        dayEnd.minute,
        dayEnd.second,
        dayEnd.millisecond
    );
    return { ">=": fromDate.toISOString(), "<=": toDate.toISOString() };
}
