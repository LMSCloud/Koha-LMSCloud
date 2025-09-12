// @ts-check
/**
 * Quick toggle filters (expired/cancelled/completed) for booking tables
 * Integrates with additionalFilters and triggers table reloads
 */

/**
 * @typedef {{ expired: boolean; cancelled: boolean, completed: boolean }} QuickToggleState
 */

// Track document-level listener bindings across instances
let __quickTogglesDocListenerCount = 0;

/**
 * Enhance booking table with quick toggle buttons
 * Expects up to three anchor elements with ids:
 *  - #bookings_expired_filter
 *  - #bookings_cancelled_filter
 *  - #bookings_completed_filter
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
    const state = { expired: false, cancelled: false, completed: false };

    const expiredBtn =
        document.getElementById("bookings_expired_filter") ||
        document.getElementById("expired_filter");
    const cancelledBtn =
        document.getElementById("bookings_cancelled_filter") ||
        document.getElementById("cancelled_filter");
    const completedBtn =
        document.getElementById("bookings_completed_filter") ||
        document.getElementById("completed_filter");

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

    /**
     * Handle status column visibility when showing/hiding cancelled or completed bookings
     * @param {boolean} shouldShowStatusColumn - Whether status column should be visible
     */
    function handleStatusColumnVisibility(shouldShowStatusColumn) {
        const statusCol = getStatusColumn();
        if (!statusCol) return;

        if (shouldShowStatusColumn) {
            // First activation: capture current visibility if not already captured
            if (statusPrevVisibility === null) {
                try {
                    statusPrevVisibility = statusCol.visible();
                } catch (_e) {
                    statusPrevVisibility = null;
                }
            }
            // Rule: if hidden by default AND column is toggleable, show when showing cancelled/completed
            const tableEl =
                typeof tableElement === "string"
                    ? document.querySelector(tableElement)
                    : /** @type {any} */ (tableElement);
            const targetEl =
                tableEl && /** @type {any} */ (tableEl).closest
                    ? /** @type {any} */ (
                          /** @type {any} */ (tableEl).closest(
                              "table, #bookingst"
                          ) || tableEl
                      )
                    : null;
            const isHiddenByDefault = targetEl
                ? targetEl.getAttribute("data-status-hidden-default") === "1"
                : false;
            const cannotToggle = targetEl
                ? targetEl.getAttribute("data-status-cannot-toggle") === "1"
                : false;
            // Respect runtime lock: if column cannot be toggled, do not programmatically change visibility
            if (isHiddenByDefault && !cannotToggle) {
                try {
                    statusCol.visible(true, false);
                } catch (_e) {
                    /* noop */
                }
            }
        } else {
            // Restore previous visibility when hiding cancelled/completed
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

    function applyFiltersFromState() {
        // Hide expired when state.expired is false
        additionalFilters["me.end_date"] = function () {
            if (state.expired) return; // show all
            const now = new Date();
            return { ">=": now.toISOString() };
        };

        // Hide cancelled when state.cancelled is false
        additionalFilters["me.status"] = function () {
            const status = ["new"];
            if (state.cancelled) status.push("cancelled");
            if (state.completed) status.push("completed");
            return status;
        };
    }

    /**
     * Update button display with proper DOM manipulation
     * @param {HTMLElement} button - The button element to update
     * @param {boolean} isActive - Whether the toggle is active (excluding items)
     * @param {string} excludeText - Text to show when excluding
     * @param {string} includeText - Text to show when including
     */
    function updateButton(button, isActive, excludeText, includeText) {
        button.classList.toggle("filtered", !isActive);

        button.textContent = "";

        const icon = document.createElement("i");
        icon.className = `fa fa-${isActive ? "filter" : "bars"}`;
        button.appendChild(icon);

        button.appendChild(
            document.createTextNode(
                " " + (isActive ? excludeText : includeText)
            )
        );
    }

    function render() {
        if (expiredBtn) {
            // 'filtered' means expired are excluded (state.expired=false)
            updateButton(
                expiredBtn,
                state.expired,
                __("Exclude expired"),
                __("Include expired")
            );
        }
        if (cancelledBtn) {
            // 'filtered' means cancelled are excluded (state.cancelled=false)
            updateButton(
                cancelledBtn,
                state.cancelled,
                __("Exclude cancelled"),
                __("Include cancelled")
            );
        }
        if (completedBtn) {
            // 'filtered' means completed are excluded (state.completed=false)
            updateButton(
                completedBtn,
                state.completed,
                __("Exclude completed"),
                __("Include completed")
            );
        }
    }

    function reload() {
        dataTable.ajax.reload(null, false);
    }

    /**
     * Handle toggle for status-affecting buttons (cancelled/completed)
     * @param {keyof QuickToggleState} stateKey - The state property to toggle
     */
    function handleStatusToggle(stateKey) {
        state[stateKey] = !state[stateKey];
        applyFiltersFromState();
        render();

        // Handle status column visibility for cancelled and completed toggles
        const shouldShowStatusColumn = state.cancelled || state.completed;
        handleStatusColumnVisibility(shouldShowStatusColumn);

        reload();
    }

    /**
     * Identify which toggle button was clicked
     * @param {HTMLElement} target - The clicked element
     * @returns {string|null} - The button type or null if no match
     */
    function identifyToggleButton(target) {
        if (
            expiredBtn &&
            (target === expiredBtn ||
                target.closest("#bookings_expired_filter") ||
                target.closest("#expired_filter"))
        ) {
            return "expired";
        }

        if (
            cancelledBtn &&
            (target === cancelledBtn ||
                target.closest("#bookings_cancelled_filter") ||
                target.closest("#cancelled_filter"))
        ) {
            return "cancelled";
        }

        if (
            completedBtn &&
            (target === completedBtn ||
                target.closest("#bookings_completed_filter") ||
                target.closest("#completed_filter"))
        ) {
            return "completed";
        }

        return null;
    }

    function onClick(/** @type {MouseEvent} */ e) {
        const target = /** @type {HTMLElement} */ (e.target);
        if (!target) return;

        const buttonType = identifyToggleButton(target);
        if (!buttonType) return;

        e.preventDefault();

        switch (buttonType) {
            case "expired":
                state.expired = !state.expired;
                applyFiltersFromState();
                render();
                reload();
                break;

            case "cancelled":
                handleStatusToggle("cancelled");
                break;

            case "completed":
                handleStatusToggle("completed");
                break;
        }
    }

    // Initialize: exclude everything by default (all toggles OFF)
    state.expired = false;
    state.cancelled = false;
    state.completed = false;
    applyFiltersFromState();
    render();
    // Bind to the closest table wrapper to avoid global document listeners
    /** @type {HTMLElement|null} */
    let containerEl = null;
    if (typeof tableElement === "string") {
        const el = document.querySelector(tableElement);
        containerEl = el instanceof HTMLElement ? el : null;
    } else if (
        tableElement &&
        /** @type {any} */ (tableElement).nodeType === 1
    ) {
        containerEl = /** @type {any} */ (tableElement);
    }

    const wrapper =
        containerEl && containerEl.closest
            ? /** @type {HTMLElement|null} */ (
                  containerEl.closest(".dataTables_wrapper")
              )
            : null;

    // Prefer binding to wrapper only if the toggles are within it; otherwise bind to document
    let bindTarget = wrapper || document;
    if (wrapper && (expiredBtn || cancelledBtn || completedBtn)) {
        const w = /** @type {HTMLElement} */ (wrapper);
        const containsExpired =
            expiredBtn instanceof HTMLElement ? w.contains(expiredBtn) : false;
        const containsCancelled =
            cancelledBtn instanceof HTMLElement
                ? w.contains(cancelledBtn)
                : false;
        const containsCompleted =
            completedBtn instanceof HTMLElement
                ? w.contains(completedBtn)
                : false;
        if (!containsExpired && !containsCancelled && !containsCompleted) {
            bindTarget = document;
        }
    }
    // Prevent duplicate bindings on the same wrapper
    if (bindTarget !== document) {
        const el = /** @type {HTMLElement} */ (bindTarget);
        if (!(/** @type {any} */ (el).dataset))
            /** @type {any} */ (el).dataset = {};
        if (!(/** @type {any} */ (el).dataset.quickTogglesBound)) {
            el.addEventListener("click", onClick);
            /** @type {any} */ (el).dataset.quickTogglesBound = "1";
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
            if (/** @type {any} */ (el).dataset) {
                delete (/** @type {any} */ (el).dataset.quickTogglesBound);
            }
        } else {
            __quickTogglesDocListenerCount = Math.max(
                0,
                __quickTogglesDocListenerCount - 1
            );
            if (__quickTogglesDocListenerCount === 0) {
                document.removeEventListener("click", onClick);
            }
        }
    });
}
