// Shared constants for booking system (business logic + UI)

// Constraint modes
export const CONSTRAINT_MODE_END_DATE_ONLY = "end_date_only";
export const CONSTRAINT_MODE_NORMAL = "normal";

// Selection semantics (logging, diagnostics)
export const SELECTION_ANY_AVAILABLE = "ANY_AVAILABLE";
export const SELECTION_SPECIFIC_ITEM = "SPECIFIC_ITEM";

// UI class names (used across calendar/adapters/composables)
export const CLASS_BOOKING_CONSTRAINED_RANGE_MARKER =
    "booking-constrained-range-marker";
export const CLASS_BOOKING_DAY_HOVER_LEAD = "booking-day--hover-lead";
export const CLASS_BOOKING_DAY_HOVER_TRAIL = "booking-day--hover-trail";
export const CLASS_BOOKING_INTERMEDIATE_BLOCKED = "booking-intermediate-blocked";
export const CLASS_BOOKING_MARKER_COUNT = "booking-marker-count";
export const CLASS_BOOKING_MARKER_DOT = "booking-marker-dot";
export const CLASS_BOOKING_MARKER_GRID = "booking-marker-grid";
export const CLASS_BOOKING_MARKER_ITEM = "booking-marker-item";
export const CLASS_BOOKING_OVERRIDE_ALLOWED = "booking-override-allowed";
export const CLASS_FLATPICKR_DAY = "flatpickr-day";
export const CLASS_FLATPICKR_DISABLED = "flatpickr-disabled";
export const CLASS_FLATPICKR_NOT_ALLOWED = "notAllowed";
export const CLASS_BOOKING_LOAN_BOUNDARY = "booking-loan-boundary";

// Data attributes
export const DATA_ATTRIBUTE_BOOKING_OVERRIDE = "data-booking-override";
