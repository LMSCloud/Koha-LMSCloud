/**
 * Modal scroll helpers shared across components.
 * Uses a window-scoped counter to manage body scroll lock for nested modals.
 */

/**
 * Enable body scroll when the last modal closes.
 */
export function enableBodyScroll() {
    const count = Number(window["kohaModalCount"] ?? 0);
    window["kohaModalCount"] = Math.max(0, count - 1);

    if ((window["kohaModalCount"] ?? 0) === 0) {
        document.body.classList.remove("modal-open");
        if (document.body.style.paddingRight) {
            document.body.style.paddingRight = "";
        }
    }
}

/**
 * Disable body scroll while a modal is open.
 */
export function disableBodyScroll() {
    const current = Number(window["kohaModalCount"] ?? 0);
    window["kohaModalCount"] = current + 1;

    if (!document.body.classList.contains("modal-open")) {
        const scrollbarWidth =
            window.innerWidth - document.documentElement.clientWidth;
        if (scrollbarWidth > 0) {
            document.body.style.paddingRight = `${scrollbarWidth}px`;
        }
        document.body.classList.add("modal-open");
    }
}
