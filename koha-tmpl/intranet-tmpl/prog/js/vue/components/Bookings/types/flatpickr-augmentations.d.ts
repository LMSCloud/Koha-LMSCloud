import "flatpickr/dist/types/instance";

// Augment flatpickr Instance to carry cached highlighting data
declare module "flatpickr/dist/types/instance" {
    interface Instance {
        /** Koha Bookings: cached constraint highlighting for re-application after navigation */
        _constraintHighlighting?: import('./bookings').ConstraintHighlighting | null;
        /** Koha Bookings: cached loan boundary timestamps for bold styling */
        _loanBoundaryTimes?: Set<number>;
    }
}

// Augment DOM Element to include flatpickr's custom property used in our UI code
declare global {
    interface Element {
        /** set by flatpickr on day cells */
        dateObj?: Date;
    }
}
