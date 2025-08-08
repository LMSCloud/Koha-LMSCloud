// @ts-check
/**
 * Configuration utilities for booking tables
 */

/**
 * Get unified embed configuration based on variant
 * @param {string} [variant='default'] - The variant to use for embed configuration
 *   - 'default': Standard embed configuration for all booking types
 *   - 'pending': Same as default (currently identical, but can be extended)
 *   - 'biblio': Embed configuration for biblio-specific bookings (excludes biblio since context is known)
 * @returns {Array<string>} Array of embed strings for KohaTable
 */
export function getBookingsEmbed(variant = "default") {
    switch (variant) {
        case "biblio":
            return ["item", "patron", "pickup_library", "extended_attributes"];
        case "default":
        default:
            return [
                "biblio",
                "item+strings",
                "item.checkout",
                "patron",
                "pickup_library",
                "extended_attributes",
            ];
    }
}

/**
 * Get unified URL configuration based on variant
 * @param {string} [variant='default'] - The variant to use for URL configuration
 * @param {string} [biblionumber] - Biblionumber for biblio-specific variants
 * @returns {string} API endpoint URL
 */
export function getBookingsUrl(variant = "default", biblionumber) {
    switch (variant) {
        case "biblio":
            if (!biblionumber) {
                throw new Error("biblionumber is required for biblio variant");
            }
            return `/api/v1/biblios/${biblionumber}/bookings`;
        case "pending":
        case "default":
        default:
            return "/api/v1/bookings?";
    }
}

/**
 * Get column filter configuration based on variant
 * @param {string} [variant='default'] - The variant to use for column filter configuration
 * @returns {1|0} Column filter flag (1 for enabled, 0 for disabled)
 */
export function getBookingsColumnFilterFlag(variant = "default") {
    switch (variant) {
        case "pending":
        case "default":
            return 1; // Enable column filters for both pending and regular bookings
        case "biblio":
        default:
            return 0; // Disable column filters for other variants
    }
}
