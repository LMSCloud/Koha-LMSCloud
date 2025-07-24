import { $__ } from "../i18n/index.js";

/**
 * Map API error messages to translated versions
 *
 * This utility translates common Mojolicious::Plugin::OpenAPI and JSON::Validator
 * error messages into user-friendly, localized strings.
 *
 * @param {string} errorMessage - The raw API error message
 * @returns {string} - Translated error message
 */
export function translateApiError(errorMessage) {
    if (!errorMessage || typeof errorMessage !== "string") {
        return $__("An error occurred.");
    }

    // Common OpenAPI/JSON::Validator error patterns
    const errorMappings = [
        // Missing required fields
        {
            pattern: /Missing property/i,
            translation: $__("Required field is missing."),
        },
        {
            pattern: /Expected (\w+) - got (\w+)/i,
            translation: $__("Invalid data type provided."),
        },
        {
            pattern: /String is too (long|short)/i,
            translation: $__("Text length is invalid."),
        },
        {
            pattern: /Not in enum list/i,
            translation: $__("Invalid value selected."),
        },
        {
            pattern: /Failed to parse JSON/i,
            translation: $__("Invalid data format."),
        },
        {
            pattern: /Schema validation failed/i,
            translation: $__("Data validation failed."),
        },
        {
            pattern: /Bad Request/i,
            translation: $__("Invalid request."),
        },
        // Generic fallbacks
        {
            pattern: /Something went wrong/i,
            translation: $__("An unexpected error occurred."),
        },
        {
            pattern: /Internal Server Error/i,
            translation: $__("A server error occurred."),
        },
        {
            pattern: /Not Found/i,
            translation: $__("The requested resource was not found."),
        },
        {
            pattern: /Unauthorized/i,
            translation: $__("You are not authorized to perform this action."),
        },
        {
            pattern: /Forbidden/i,
            translation: $__("Access to this resource is forbidden."),
        },
    ];

    // Try to match error patterns
    for (const mapping of errorMappings) {
        if (mapping.pattern.test(errorMessage)) {
            return mapping.translation;
        }
    }

    // If no pattern matches, return a generic translated error
    return $__("An error occurred: %s").format(errorMessage);
}

/**
 * Extract error message from various error response formats
 * @param {Error|Object|string} error - API error response
 * @returns {string} - Raw error message
 */
function extractErrorMessage(error) {
    const extractors = [
        // Direct string
        err => (typeof err === "string" ? err : null),

        // OpenAPI validation errors format: { errors: [{ message: "...", path: "..." }] }
        err => {
            const errors = err?.response?.data?.errors;
            if (Array.isArray(errors) && errors.length > 0) {
                return errors.map(e => e.message || e).join(", ");
            }
            return null;
        },

        // Standard API error response
        err => err?.response?.data?.message,

        // Error object message
        err => err?.message,

        // HTTP status text
        err => err?.statusText,

        // Default fallback
        () => "Unknown error",
    ];

    for (const extractor of extractors) {
        const message = extractor(error);
        if (message) return message;
    }

    return "Unknown error"; // This should never be reached due to the fallback extractor
}

/**
 * Process API error response and extract user-friendly message
 *
 * @param {Error|Object|string} error - API error response
 * @returns {string} - Translated error message
 */
export function processApiError(error) {
    const errorMessage = extractErrorMessage(error);
    return translateApiError(errorMessage);
}
