// @ts-check
/**
 * Quick toggle filters (expired/cancelled) for booking tables
 * Integrates with additionalFilters and triggers table reloads
 */

/**
 * @typedef {{ expired: boolean; cancelled: boolean }} QuickToggleState
 */

// Track document-level listener bindings across instances
let __quickTogglesDocListenerCount = 0;

/**
 * Enhance booking table with quick toggle buttons
 * Expects two anchor elements with ids:
 *  - #bookings_expired_filter
 *  - #bookings_cancelled_filter
 *
 * @param {any} dataTable - DataTables instance
 * @param {any} tableElement - Table element or selector
 * @param {Record<string, any>} additionalFilters - Mutable additional filters map
 */
export function enhanceQuickToggles(
    dataTable,
    tableElement,
    additionalFilters
) {
    void tableElement; // not needed currently

    /** @type {QuickToggleState} */
    const state = { expired: false, cancelled: false };

    const expiredBtn =
        document.getElementById("bookings_expired_filter") ||
        document.getElementById("expired_filter");
    const cancelledBtn =
        document.getElementById("bookings_cancelled_filter") ||
        document.getElementById("cancelled_filter");

    /**
     * Track pre-toggle visibility for the status column so we can restore it
     * after turning off the "Show cancelled" quick toggle
     * @type {boolean|null}
     */
    let statusPrevVisibility = null;

    function getStatusColumn() {
        try {
            // Use named column selector; will throw if column not present
            return dataTable.column("status:name");
        } catch (_e) {
            return null;
        }
    }

    function applyFiltersFromState() {
        // Hide expired when state.expired is false
        additionalFilters["me.end_date"] = function () {
            if (state.expired) return; // show all
            const now = new Date();
            return { ">=": now.toISOString() };
        };

        // Hide cancelled when state.cancelled is false
        additionalFilters["me.status"] = function () {
            if (state.cancelled) return; // show all
            return { "!=": "cancelled" };
        };
    }

    function render() {
        if (expiredBtn) {
            // 'filtered' means expired are excluded (state.expired=false)
            expiredBtn.classList.toggle("filtered", !state.expired);
            expiredBtn.innerHTML = `<i class="fa fa-${
                state.expired ? "filter" : "bars"
            }"></i> ${state.expired ? __("Exclude expired") : __("Include expired")}`;
        }
        if (cancelledBtn) {
            // 'filtered' means cancelled are excluded (state.cancelled=false)
            cancelledBtn.classList.toggle("filtered", !state.cancelled);
            cancelledBtn.innerHTML = `<i class="fa fa-${
                state.cancelled ? "filter" : "bars"
            }"></i> ${
                state.cancelled ? __("Exclude cancelled") : __("Include cancelled")
            }`;
        }
    }

    function reload() {
        dataTable.ajax.reload(null, false);
    }

    function onClick(/** @type {MouseEvent} */ e) {
        const target = /** @type {HTMLElement} */ (e.target);
        if (!target) return;
        if (
            expiredBtn &&
            (target === expiredBtn ||
                target.closest("#bookings_expired_filter") ||
                target.closest("#expired_filter"))
        ) {
            e.preventDefault();
            state.expired = !state.expired;
            applyFiltersFromState();
            render();
            reload();
        } else if (
            cancelledBtn &&
            (target === cancelledBtn ||
                target.closest("#bookings_cancelled_filter") ||
                target.closest("#cancelled_filter"))
        ) {
            e.preventDefault();
            state.cancelled = !state.cancelled;
            applyFiltersFromState();
            render();
            // When showing cancelled, ensure the status column is visible.
            // Remember previous visibility to restore when hiding cancelled again.
            const statusCol = getStatusColumn();
            if (statusCol) {
                if (state.cancelled) {
                    // First activation: capture current visibility
                    if (statusPrevVisibility === null) {
                        try {
                            statusPrevVisibility = statusCol.visible();
                        } catch (_e) {
                            statusPrevVisibility = null;
                        }
                    }
                    // Rule: if hidden by default AND column is toggleable, show when QC is on.
                    const tableEl = (typeof tableElement === 'string') ? document.querySelector(tableElement) : /** @type {any} */ (tableElement);
                    const targetEl = tableEl && (/** @type {any} */ (tableEl)).closest ? (/** @type {any} */ ((/** @type {any} */ (tableEl)).closest('table, #bookingst') || tableEl)) : null;
                    const isHiddenByDefault = targetEl ? targetEl.getAttribute('data-status-hidden-default') === '1' : false;
                    const cannotToggle = targetEl ? targetEl.getAttribute('data-status-cannot-toggle') === '1' : false;
                    // Respect runtime lock: if column cannot be toggled, do not programmatically change visibility
                    if (isHiddenByDefault && !cannotToggle) {
                        try {
                            statusCol.visible(true, false);
                        } catch (_e) {
                            /* noop */
                        }
                    }
                } else {
                    if (statusPrevVisibility !== null) {
                        try {
                            statusCol.visible(statusPrevVisibility, false);
                        } catch (_e) {
                            /* noop */
                        }
                        // Reset captured state so future manual changes are respected
                        statusPrevVisibility = null;
                    }
                }
            }
            reload();
        }
    }

    // Initialize: default hidden for both expired and cancelled
    state.expired = false;
    state.cancelled = false;
    applyFiltersFromState();
    render();
    // Bind to the closest table wrapper to avoid global document listeners
    /** @type {HTMLElement|null} */
    let containerEl = null;
    if (typeof tableElement === "string") {
        const el = document.querySelector(tableElement);
        containerEl = el instanceof HTMLElement ? el : null;
    } else if (tableElement && /** @type {any} */ (tableElement).nodeType === 1) {
        containerEl = /** @type {any} */ (tableElement);
    }

    const wrapper = containerEl && containerEl.closest
        ? /** @type {HTMLElement|null} */ (containerEl.closest('.dataTables_wrapper'))
        : null;

    // Prefer binding to wrapper only if the toggles are within it; otherwise bind to document
    let bindTarget = wrapper || document;
    if (wrapper && (expiredBtn || cancelledBtn)) {
        const w = /** @type {HTMLElement} */ (wrapper);
        const containsExpired = expiredBtn instanceof HTMLElement ? w.contains(expiredBtn) : false;
        const containsCancelled = cancelledBtn instanceof HTMLElement ? w.contains(cancelledBtn) : false;
        if (!containsExpired && !containsCancelled) {
            bindTarget = document;
        }
    }
    // Prevent duplicate bindings on the same wrapper
    if (bindTarget !== document) {
        const el = /** @type {HTMLElement} */ (bindTarget);
        if (!(/** @type {any} */ (el)).dataset) (/** @type {any} */ (el)).dataset = {};
        if (!(/** @type {any} */ (el)).dataset.quickTogglesBound) {
            el.addEventListener("click", onClick);
            (/** @type {any} */ (el)).dataset.quickTogglesBound = "1";
        }
    } else {
        if (__quickTogglesDocListenerCount === 0) {
            document.addEventListener("click", onClick);
        }
        __quickTogglesDocListenerCount++;
    }

    // Unbind on table destroy
    dataTable.on("destroy.dt", function () {
        if (bindTarget !== document) {
            const el = /** @type {HTMLElement} */ (bindTarget);
            el.removeEventListener("click", onClick);
            if ((/** @type {any} */ (el)).dataset) {
                delete (/** @type {any} */ (el)).dataset.quickTogglesBound;
            }
        } else {
            __quickTogglesDocListenerCount = Math.max(0, __quickTogglesDocListenerCount - 1);
            if (__quickTogglesDocListenerCount === 0) {
                document.removeEventListener("click", onClick);
            }
        }
    });
}
