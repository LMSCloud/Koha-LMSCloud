/**
 * Physical item that can be booked (minimum shape used across the UI).
 */
export type BookableItem = {
    /** Internal item identifier */
    item_id: Id;
    /** Koha item type code */
    item_type_id: string;
    /** Effective type after MARC policies (when present) */
    effective_item_type_id?: string;
    /** Owning or home library id */
    home_library_id: string;
    /** Optional descriptive fields used in UI/logs */
    title?: string;
    barcode?: string;
    external_id?: string;
    holding_library?: string;
    available_pickup_locations?: any;
    /** Localized strings container (when available) */
    _strings?: { item_type_id?: { str?: string } };
};

/**
 * Booking record (core fields only, as used by the UI).
 */
export type Booking = {
    booking_id: number;
    item_id: Id;
    start_date: ISODateString;
    end_date: ISODateString;
    status?: string;
    patron_id?: number;
};

/**
 * Active checkout record for an item relevant to bookings.
 */
export type Checkout = {
    item_id: Id;
    due_date: ISODateString;
};

/**
 * Library that can serve as pickup location with optional item whitelist.
 */
export type PickupLocation = {
    library_id: string;
    name: string;
    /** Allowed item ids for pickup at this location (when restricted) */
    pickup_items?: Array<Id>;
};

/**
 * Subset of circulation rules used by bookings logic (from backend API).
 */
export type CirculationRule = {
    /** Max booking length in days (effective, UI-enforced) */
    maxPeriod?: number;
    /** Base issue length in days (backend rule) */
    issuelength?: number;
    /** Lead/trail periods around bookings (days) */
    leadTime?: number;
    leadTimeToday?: boolean;
    /** Optional calculated due date from backend (ISO) */
    calculated_due_date?: ISODateString;
    /** Optional calculated period in days (from backend) */
    calculated_period_days?: number;
    /** Constraint mode selection */
    booking_constraint_mode?: "range" | "end_date_only";
};

/** Visual marker type used in calendar tooltip and markers grid. */
export type MarkerType = "booked" | "checked-out" | "lead" | "trail";

/**
 * Visual marker entry for a specific date/item.
 */
export type Marker = {
    type: MarkerType;
    barcode?: string;
    external_id?: string;
    itemnumber?: Id;
};

/**
 * Marker used by calendar code (tooltips + aggregation).
 * Contains display label (itemName) and resolved barcode (or external id).
 */
export type CalendarMarker = {
    type: MarkerType;
    item: string;
    itemName: string;
    barcode: string | null;
};

/** Minimal item type shape used in constraints */
export type ItemType = {
    item_type_id: string;
    name?: string;
};

/**
 * Result of availability calculation: Flatpickr disable function + daily map.
 */
export type AvailabilityResult = {
    disable: DisableFn;
    unavailableByDate: UnavailableByDate;
};

/**
 * Canonical map of daily unavailability across items.
 *
 * Keys:
 * - Outer key: date in YYYY-MM-DD (calendar day)
 * - Inner key: item id as string
 * - Value: set of reasons for unavailability on that day
 */
export type UnavailableByDate = Record<string, Record<string, Set<UnavailabilityReason>>>;

/** Enumerates reasons an item is not bookable on a specific date. */
export type UnavailabilityReason = "booking" | "checkout" | "lead" | "trail" | string;

/** Disable function for Flatpickr */
export type DisableFn = (date: Date) => boolean;

/** Options affecting constraint calculations (UI + rules composition). */
export type ConstraintOptions = {
    dateRangeConstraint?: string;
    maxBookingPeriod?: number;
};

/** Resulting highlighting metadata for calendar UI. */
export type ConstraintHighlighting = {
    startDate: Date;
    targetEndDate: Date;
    blockedIntermediateDates: Date[];
    constraintMode: string;
    maxPeriod: number;
};

/** Minimal shape of the Pinia booking store used by the UI. */
export type BookingStoreLike = {
    selectedDateRange?: string[];
    circulationRules?: CirculationRule[];
    bookings?: Booking[];
    checkouts?: Checkout[];
    bookableItems?: BookableItem[];
    bookingItemId?: Id | null;
    bookingId?: Id | null;
    unavailableByDate?: UnavailableByDate;
};

/** Store actions used by composables to interact with backend. */
export type BookingStoreActions = {
    fetchPickupLocations: (
        biblionumber: Id,
        patronId: Id
    ) => Promise<unknown>;
    invalidateCalculatedDue: () => void;
    fetchCirculationRules: (
        params: Record<string, unknown>
    ) => Promise<unknown>;
};

/** Dependencies used for updating external widgets after booking changes. */
export type ExternalDependencies = {
    timeline: () => any;
    bookingsTable: () => any;
    patronRenderer: () => any;
    domQuery: (selector: string) => NodeListOf<HTMLElement>;
    logger: {
        warn: (msg: any, data?: any) => void;
        error: (msg: any, err?: any) => void;
        debug?: (msg: any, data?: any) => void;
    };
};

/** Generic Ref-like helper for accepting either Vue Ref or plain `{ value }`. */
export type RefLike<T> = import('vue').Ref<T> | { value: T };

/** Minimal patron shape used by composables. */
export type PatronLike = {
    patron_id?: number | string;
    category_id?: string | number;
    library_id?: string;
    cardnumber?: string;
};

/** Options object for `useDerivedItemType` composable. */
export type DerivedItemTypeOptions = {
    bookingItemtypeId: import('vue').Ref<string | null | undefined>;
    bookingItemId: import('vue').Ref<string | number | null | undefined>;
    constrainedItemTypes: import('vue').Ref<Array<ItemType>>;
    bookableItems: import('vue').Ref<Array<BookableItem>>;
};

/** Options object for `useDefaultPickup` composable. */
export type DefaultPickupOptions = {
    bookingPickupLibraryId: import('vue').Ref<string | null | undefined>;
    bookingPatron: import('vue').Ref<PatronLike | null>;
    pickupLocations: import('vue').Ref<Array<PickupLocation>>;
    bookableItems: import('vue').Ref<Array<BookableItem>>;
    opacDefaultBookingLibraryEnabled?: boolean | string | number;
    opacDefaultBookingLibrary?: string;
};

/** Input shape for `useErrorState`. */
export type ErrorStateInit = { message?: string; code?: string | null };
/** Return shape for `useErrorState`. */
export type ErrorStateResult = {
    error: { message: string; code: string | null };
    setError: (message: string, code?: string) => void;
    clear: () => void;
    hasError: import('vue').ComputedRef<boolean>;
};

/** Options for calendar `createOnChange` handler. */
export type OnChangeOptions = {
    setError?: (msg: string) => void;
    tooltipVisibleRef?: { value: boolean };
    constraintOptions?: ConstraintOptions;
};

/** Minimal parameter set for circulation rules fetching. */
export type RulesParams = {
    patron_category_id?: string | number;
    item_type_id?: Id;
    library_id?: string;
    start_date?: string;
};

/** Flatpickr instance augmented with a cache for constraint highlighting. */
export type FlatpickrInstanceWithHighlighting = import('flatpickr/dist/types/instance').Instance & {
    _constraintHighlighting?: ConstraintHighlighting | null;
};

/** Convenience alias for stores passed to fetchers. */
export type StoreWithActions = BookingStoreLike & BookingStoreActions;

/** Common result shape for `constrain*` helpers. */
export type ConstraintResult<T> = {
    filtered: T[];
    filteredOutCount: number;
    total: number;
    constraintApplied: boolean;
};

/** Navigation target calculation for calendar month navigation. */
export type CalendarNavigationTarget = {
    shouldNavigate: boolean;
    targetMonth?: number;
    targetYear?: number;
    targetDate?: Date;
};

/** Aggregated counts by marker type for the markers grid. */
export type MarkerAggregation = Record<string, number>;

/**
 * Current calendar view boundaries (visible date range) for navigation logic.
 */
export type CalendarCurrentView = {
    visibleStartDate?: Date;
    visibleEndDate?: Date;
};

/**
 * Common identifier type used across UI (string or number).
 */
export type Id = string | number;

/** ISO-8601 date string (YYYY-MM-DD or full ISO as returned by backend). */
export type ISODateString = string;

/** Minimal item type shape used in constraints and selection UI. */
export type ItemType = {
    item_type_id: string;
    name?: string;
};
