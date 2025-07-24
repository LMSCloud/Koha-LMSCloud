import { $__ } from "../i18n/index.js";

/**
 * Generic validation error factory
 *
 * Creates a validation error handler with injected message mappings
 * @param {Object} messageMappings - Object mapping error keys to translation functions
 * @returns {Object} - Object with validation error methods
 */
export function createValidationErrorHandler(messageMappings) {
    /**
     * Create a validation error with translated message
     * @param {string} errorKey - The error key to look up
     * @param {Object} params - Optional parameters for string formatting
     * @returns {Error} - Error object with translated message
     */
    function validationError(errorKey, params = {}) {
        const messageFunc = messageMappings[errorKey];

        if (!messageFunc) {
            // Fallback for unknown error keys
            return new Error($__("Validation error: %s").format(errorKey));
        }

        // Call the message function with params to get translated message
        const message = messageFunc(params);
        const error = new Error(message);

        // If status is provided in params, set it on the error object
        if (params.status !== undefined) {
            error.status = params.status;
        }

        return error;
    }

    /**
     * Validate required fields
     * @param {Object} data - Data object to validate
     * @param {Array<string>} requiredFields - List of required field names
     * @param {string} errorKey - Error key to use if validation fails
     * @returns {Error|null} - Error if validation fails, null if passes
     */
    function validateRequiredFields(
        data,
        requiredFields,
        errorKey = "missing_required_fields"
    ) {
        if (!data) {
            return validationError("data_required");
        }

        const missingFields = requiredFields.filter(field => !data[field]);

        if (missingFields.length > 0) {
            return validationError(errorKey, {
                fields: missingFields.join(", "),
            });
        }

        return null;
    }

    return {
        validationError,
        validateRequiredFields,
    };
}
