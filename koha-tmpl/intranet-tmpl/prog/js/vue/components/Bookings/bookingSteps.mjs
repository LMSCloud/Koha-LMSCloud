/**
 * Pure functions for booking step calculation and management
 * Extracted from BookingStepService to provide pure, testable functions
 */

/**
 * Calculate step numbers based on configuration
 * @param {boolean} showPatronSelect - Whether patron selection step is shown
 * @param {boolean} showItemDetailsSelects - Whether item details step is shown
 * @param {boolean} showPickupLocationSelect - Whether pickup location step is shown
 * @param {boolean} showAdditionalFields - Whether additional fields step is shown
 * @param {boolean} hasAdditionalFields - Whether additional fields exist
 * @returns {Object} Step numbers for each section
 */
export function calculateStepNumbers(
    showPatronSelect,
    showItemDetailsSelects,
    showPickupLocationSelect,
    showAdditionalFields,
    hasAdditionalFields
) {
    let currentStep = 1;
    const steps = {
        patron: 0,
        details: 0,
        period: 0,
        additionalFields: 0,
    };

    if (showPatronSelect) {
        steps.patron = currentStep++;
    }

    if (showItemDetailsSelects || showPickupLocationSelect) {
        steps.details = currentStep++;
    }

    steps.period = currentStep++;

    if (showAdditionalFields && hasAdditionalFields) {
        steps.additionalFields = currentStep++;
    }

    return steps;
}

/**
 * Determine if additional fields section should be shown
 * @param {boolean} showAdditionalFields - Configuration setting for additional fields
 * @param {boolean} hasAdditionalFields - Whether additional fields exist
 * @returns {boolean} Whether to show additional fields section
 */
export function shouldShowAdditionalFields(
    showAdditionalFields,
    hasAdditionalFields
) {
    return showAdditionalFields && hasAdditionalFields;
}
