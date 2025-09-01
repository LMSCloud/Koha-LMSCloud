<template>
    <div
        v-if="modalState.isOpen"
        class="modal show booking-modal-backdrop"
        tabindex="-1"
        role="dialog"
    >
        <div
            class="modal-dialog booking-modal-window booking-modal"
            role="document"
        >
            <div class="modal-content">
                <div class="booking-modal-header">
                    <h5 class="booking-modal-title">
                        {{ modalTitle }}
                    </h5>
                    <button
                        type="button"
                        class="close booking-modal-close"
                        aria-label="Close"
                        @click="handleClose"
                    >
                        <span aria-hidden="true">&times;</span>
                    </button>
                </div>
                <div class="modal-body booking-modal-body">
                    <form
                        id="form-booking"
                        :action="submitUrl"
                        method="post"
                        @submit.prevent="handleSubmit"
                    >
                        <BookingPatronStep
                            v-if="showPatronSelect"
                            v-model="bookingPatron"
                            :step-number="stepNumber.patron"
                        />
                        <hr
                            v-if="
                                showPatronSelect ||
                                showItemDetailsSelects ||
                                showPickupLocationSelect
                            "
                        />
                        <BookingDetailsStep
                            v-if="
                                showItemDetailsSelects ||
                                showPickupLocationSelect
                            "
                            :step-number="stepNumber.details"
                            :show-item-details-selects="showItemDetailsSelects"
                            :show-pickup-location-select="
                                showPickupLocationSelect
                            "
                            :selected-patron="bookingPatron"
                            :patron-required="showPatronSelect"
                            v-model:pickup-library-id="pickupLibraryId"
                            v-model:itemtype-id="bookingItemtypeId"
                            v-model:item-id="bookingItemId"
                            :constrained-pickup-locations="
                                constrainedPickupLocations
                            "
                            :constrained-item-types="constrainedItemTypes"
                            :constrained-bookable-items="
                                constrainedBookableItems
                            "
                            :constrained-flags="constrainedFlags"
                            :pickup-locations-total="pickupLocationsTotal"
                            :pickup-locations-filtered-out="
                                pickupLocationsFilteredOut
                            "
                            :bookable-items-total="bookableItemsTotal"
                            :bookable-items-filtered-out="
                                bookableItemsFilteredOut
                            "
                        />
                        <hr
                            v-if="
                                showItemDetailsSelects ||
                                showPickupLocationSelect
                            "
                        />
                        <BookingPeriodStep
                            v-if="isCalendarReady"
                            :step-number="stepNumber.period"
                            :constraint-options="{
                                dateRangeConstraint: dateRangeConstraint,
                                maxBookingPeriod: maxBookingPeriod,
                            }"
                            :date-range-constraint="dateRangeConstraint"
                            :max-booking-period="maxBookingPeriod"
                            :error-message="modalState.errorMessage"
                            :set-error="val => (modalState.errorMessage = val)"
                            :has-selected-dates="selectedDateRange?.value?.length > 0"
                            @clear-dates="clearDateRange"
                        />
                        <hr
                            v-if="
                                showAdditionalFields &&
                                modalState.hasAdditionalFields
                            "
                        />
                        <BookingAdditionalFields
                            v-if="showAdditionalFields"
                            :step-number="stepNumber.additionalFields"
                            :has-fields="modalState.hasAdditionalFields"
                            :extended-attributes="extendedAttributes"
                            :extended-attribute-types="extendedAttributeTypes"
                            :authorized-values="authorizedValues"
                            @fields-ready="onAdditionalFieldsReady"
                            @fields-destroyed="onAdditionalFieldsDestroyed"
                        />
                    </form>
                </div>
                <div class="modal-footer">
                    <div class="d-flex gap-2">
                        <button
                            class="btn btn-primary"
                            :disabled="loading.submit || !isSubmitReady"
                            type="submit"
                            form="form-booking"
                        >
                            {{ submitLabel }}
                        </button>
                        <button
                            class="btn btn-secondary ml-2"
                            @click.prevent="handleClose"
                        >
                            {{ $__("Cancel") }}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import dayjs from "../../utils/dayjs.mjs";
import {
    computed,
    ref,
    reactive,
    watch,
    watchEffect,
    nextTick,
    onUnmounted,
} from "vue";
import BookingPatronStep from "./BookingPatronStep.vue";
import BookingDetailsStep from "./BookingDetailsStep.vue";
import BookingPeriodStep from "./BookingPeriodStep.vue";
import BookingAdditionalFields from "./BookingAdditionalFields.vue";
import { $__ } from "../../i18n";
import { processApiError } from "../../utils/apiErrors.js";
import {
    calculateDisabledDates,
    constrainBookableItems,
    constrainItemTypes,
    constrainPickupLocations,
} from "./lib/booking/bookingManager.mjs";
import { useBookingStore } from "../../stores/bookingStore";
import { storeToRefs } from "pinia";
import { updateExternalDependents } from "./lib/booking/index.mjs";
import { preloadFlatpickrLocale, deriveEffectiveRules } from "./lib/booking/bookingCalendar.mjs";
// Pure functions and composables (new architecture)
import { calculateStepNumbers } from "./lib/booking/bookingSteps.mjs";
import { useBookingValidation } from "./composables/useBookingValidation.mjs";
import { BookingConfigurationService } from "./lib/booking/BookingModalService.mjs";

export default {
    name: "BookingModal",
    components: {
        BookingPatronStep,
        BookingDetailsStep,
        BookingPeriodStep,
        BookingAdditionalFields,
    },
    props: {
        open: { type: Boolean, default: false },
        size: { type: String, default: "lg" },
        title: { type: String, default: "" },
        biblionumber: { type: [String, Number], required: true },
        bookingId: { type: [Number, String], default: null },
        itemId: { type: [Number, String], default: null },
        patronId: { type: [Number, String], default: null },
        pickupLibraryId: { type: String, default: null },
        startDate: { type: String, default: null },
        endDate: { type: String, default: null },
        itemtypeId: { type: [Number, String], default: null },
        showPatronSelect: { type: Boolean, default: false },
        showItemDetailsSelects: { type: Boolean, default: false },
        showPickupLocationSelect: { type: Boolean, default: false },
        submitType: {
            type: String,
            default: "api",
            validator: value => ["api", "form-submission"].includes(String(value)),
        },
        submitUrl: { type: String, default: "" },
        extendedAttributes: { type: Array, default: () => [] },
        extendedAttributeTypes: { type: Object, default: null },
        authorizedValues: { type: Object, default: null },
        showAdditionalFields: { type: Boolean, default: false },
        dateRangeConstraint: {
            type: String,
            default: null,
            validator: value =>
                !value ||
                ["issuelength", "issuelength_with_renewals", "custom"].includes(
                    String(value)
                ),
        },
        customDateRangeFormula: {
            type: Function,
            default: null,
        },
        opacDefaultBookingLibraryEnabled: { type: [Boolean, String], default: null },
        opacDefaultBookingLibrary: { type: String, default: null },
    },
    emits: ["close"],
    setup(props, { emit }) {
        const store = useBookingStore();

        // Properly destructure reactive store state using storeToRefs
        const {
            bookingId,
            bookingItemId,
            bookingPatron,
            bookingItemtypeId,
            pickupLibraryId,
            selectedDateRange,
            bookableItems,
            bookings,
            checkouts,
            pickupLocations,
            itemTypes,
            circulationRules,
            loading,
            error
        } = storeToRefs(store);

        // Initialize business logic - new architecture using pure functions and composables
        const configurationService = new BookingConfigurationService(
            props.dateRangeConstraint,
            props.customDateRangeFormula
        );

        // Use validation composable for reactive validation logic
        const { canProceedToStep3: canProceedToStep3Reactive } = useBookingValidation(store);

        // Grouped reactive state following Vue 3 best practices
        const modalState = reactive({
            isOpen: props.open,
            step: 1,
            errorMessage: "",
            hasAdditionalFields: false,
        });

        // Tooltip state is now managed inside BookingPeriodStep via composable
        // Refs for specific instances and external library integration
        const additionalFieldsInstance = ref(null);

        const modalTitle = computed(
            () =>
                props.title ||
                (bookingId.value ? $__("Edit booking") : $__("Place booking"))
        );

        const stepNumber = computed(() => {
            return calculateStepNumbers(
                props.showPatronSelect,
                props.showItemDetailsSelects,
                props.showPickupLocationSelect,
                props.showAdditionalFields,
                modalState.hasAdditionalFields
            );
        });

        const submitLabel = computed(() =>
            bookingId.value ? $__("Update booking") : $__("Place booking")
        );

        const isFormSubmission = computed(
            () => props.submitType === "form-submission"
        );

        // Create computed wrappers for v-model bindings in child components
        const bookingPickupLibraryId = computed({
            get: () => pickupLibraryId.value,
            set: value => { pickupLibraryId.value = value; },
        });

        // Constraint flags computed from pure function results
        const constrainedFlags = computed(() => ({
            pickupLocations: pickupLocationConstraint.value.constraintApplied,
            bookableItems: bookableItemsConstraint.value.constraintApplied,
            itemTypes: itemTypeConstraint.value.constraintApplied,
        }));

        const pickupLocationConstraint = computed(() =>
            constrainPickupLocations(
                pickupLocations.value,
                bookableItems.value,
                bookingItemtypeId.value,
                bookingItemId.value
            )
        );
        const constrainedPickupLocations = computed(
            () => pickupLocationConstraint.value.filtered
        );
        const pickupLocationsFilteredOut = computed(
            () => pickupLocationConstraint.value.filteredOutCount
        );
        const pickupLocationsTotal = computed(
            () => pickupLocationConstraint.value.total
        );

        const bookableItemsConstraint = computed(() =>
            constrainBookableItems(
                bookableItems.value,
                pickupLocations.value,
                pickupLibraryId.value,
                bookingItemtypeId.value
            )
        );
        const constrainedBookableItems = computed(
            () => bookableItemsConstraint.value.filtered
        );
        const bookableItemsFilteredOut = computed(
            () => bookableItemsConstraint.value.filteredOutCount
        );
        const bookableItemsTotal = computed(
            () => bookableItemsConstraint.value.total
        );

        const itemTypeConstraint = computed(() =>
            constrainItemTypes(
                itemTypes.value,
                bookableItems.value,
                pickupLocations.value,
                pickupLibraryId.value,
                bookingItemId.value
            )
        );
        const constrainedItemTypes = computed(
            () => itemTypeConstraint.value.filtered
        );

        const lastRulesKey = ref(null);

        // Cache for availability data to prevent excessive recalculation
        let availabilityCache = null;
        let availabilityCacheKey = null;

        const computedAvailabilityData = computed(() => {
            // CRITICAL FIX: Proper loading states for calendar availability
            // This prevents race condition where modal opens before store is populated
            if (
                !bookableItems.value ||
                bookableItems.value.length === 0 ||
                loading.value.bookableItems ||
                loading.value.bookings ||
                loading.value.checkouts
            ) {
                // Return restrictive default while data loads to prevent invalid selections
                return {
                    disable: () => true, // Disable all dates while loading
                    unavailableByDate: {},
                };
            }

            // Create a cache key from relevant data
            const cacheKey = JSON.stringify({
                bookingsCount: bookings.value?.length || 0,
                checkoutsCount: checkouts.value?.length || 0,
                bookableItemsCount: bookableItems.value?.length || 0,
                selectedItem: bookingItemId.value,
                editBookingId: bookingId.value,
                selectedDates: selectedDateRange.value,
                dateRangeConstraint: props.dateRangeConstraint,
                maxBookingPeriod: maxBookingPeriod.value,
            });

            // Return cached result if data hasn't changed
            if (availabilityCacheKey === cacheKey && availabilityCache) {
                return availabilityCache;
            }

            // Use selectedDateRange supplied by store
            const currentSelectedDates = selectedDateRange.value || [];

            const baseRules = circulationRules.value[0] || {};
            const effectiveRules = deriveEffectiveRules(baseRules, {
                dateRangeConstraint: props.dateRangeConstraint,
                maxBookingPeriod: maxBookingPeriod.value,
            });

            // Convert ISO strings to Date objects for calculateDisabledDates
            const selectedDatesArray = (currentSelectedDates || []).map(
                isoString => dayjs(isoString).toDate()
            );

            // Parent no longer uses visible calendar window optimization
            let calcOptions = {};

            const result = calculateDisabledDates(
                bookings.value,
                checkouts.value,
                bookableItems.value,
                bookingItemId.value,
                bookingId.value,
                selectedDatesArray,
                effectiveRules,
                undefined,
                calcOptions
            );

            // Cache the result
            availabilityCache = result;
            availabilityCacheKey = cacheKey;
            
            return result;
        });

        const maxBookingPeriod = computed(() =>
            configurationService.calculateMaxBookingPeriod(circulationRules.value)
        );

        // Prevent calendar interaction until all data is loaded to avoid race conditions
        const isCalendarReady = computed(() => {
            const dataLoaded =
                !loading.value.bookableItems &&
                !loading.value.bookings &&
                !loading.value.checkouts &&
                bookableItems.value?.length > 0;

            // Basic form validation for calendar readiness (not full step 3 validation)
            const formValid = !!(
                bookingPatron.value &&
                (bookingItemId.value ||
                    bookingItemtypeId.value ||
                    pickupLibraryId.value)
            );

            // Check if the current selection results in any available items
            const hasAvailableItems = constrainedBookableItems.value.length > 0;

            return dataLoaded && formValid && hasAvailableItems;
        });

        // Separate validation for submit button using reactive composable
        const isSubmitReady = computed(() => {
            return isCalendarReady.value && canProceedToStep3Reactive.value;
        });

        /*
         * Watchers overview
         *
         * - Open prop sync: mirror `open` into local modal state and reset inputs on open
         * - Modal lifecycle: when the modal opens/closes, handle async data loads, body scroll, and locale preload
         * - Availability mapping: push computed unavailableByDate to the store for calendar markers
         * - Data-driven fetches: react to patron/library/item type changes to load pickup locations and circulation rules
         * - Item type auto-selection: prefer a unique constrained type, otherwise infer from the selected item
         * - Error maintenance: clear messages on core input/date changes and after circulation rules finish loading
         * - Defaults: set a sensible pickup library based on OPAC default, patron library, or first item’s home library
         * - Guidance: warn when no items are available for the current selection to help the user adjust filters
         */

        // Sync internal modal state with the `open` prop and reset inputs when
        // opening to ensure a clean form each time.
        watch(
            () => props.open,
            val => {
                modalState.isOpen = val;
                if (val) {
                    resetModalState();
                }
            }
        );

        // Orchestrates initial data loading on modal open. This needs to
        // remain isolated because it handles async fetch ordering, DOM body
        // scroll state and localization preload.
        watch(
            () => modalState.isOpen,
            async open => {
                if (open) {
                    disableBodyScroll();
                    // Preload the appropriate flatpickr locale
                    await preloadFlatpickrLocale();
                } else {
                    enableBodyScroll();
                    // Clear availability cache on modal close
                    availabilityCache = null;
                    availabilityCacheKey = null;
                    return;
                }

                modalState.step = 1;
                const biblionumber = props.biblionumber;
                if (!biblionumber) return;

                bookingId.value = props.bookingId;

                try {
                    // Fetch core data first
                    await Promise.all([
                        store.fetchBookableItems(biblionumber),
                        store.fetchBookings(biblionumber),
                        store.fetchCheckouts(biblionumber),
                    ]);

                    const additionalFieldsModule = window["AdditionalFields"];
                    if (additionalFieldsModule) {
                        await renderExtendedAttributes(additionalFieldsModule);
                    } else {
                        modalState.hasAdditionalFields = false;
                    }

                    // Derive item types after bookable items are loaded
                    store.deriveItemTypesFromBookableItems();

                    // If editing with patron, fetch patron-specific data
                    if (props.patronId) {
                        const patron = await store.fetchPatron(props.patronId);
                        await store.fetchPickupLocations(
                            biblionumber,
                            props.patronId
                        );

                        // Now set patron after data is available
                        bookingPatron.value = patron;
                    }

                    // Set other form values after all dependencies are loaded
                    (function applyPickupDefault() {
                        const enabled = String(
                            /** @type {any} */ (props.opacDefaultBookingLibraryEnabled)
                        ) === "1" || /** @type {any} */ (props.opacDefaultBookingLibraryEnabled) === true;
                        const branch = props.opacDefaultBookingLibrary;
                        if (
                            enabled &&
                            typeof branch === "string" &&
                            branch &&
                            Array.isArray(pickupLocations.value) &&
                            pickupLocations.value.some(l => l.library_id === branch)
                        ) {
                            pickupLibraryId.value = branch;
                        } else {
                            pickupLibraryId.value = props.pickupLibraryId;
                        }
                    })();

                    // Normalize itemId type to match bookableItems' item_id type for vue-select strict matching
                    if (props.itemId != null) {
                        const sample = bookableItems.value?.[0]?.item_id;
                        const normalized =
                            typeof sample === "number"
                                ? Number(props.itemId)
                                : String(props.itemId);
                        bookingItemId.value = normalized;
                    } else {
                        bookingItemId.value = null;
                    }
                    bookingItemtypeId.value = props.itemtypeId;

                    if (props.startDate && props.endDate) {
                        selectedDateRange.value = [
                            dayjs(props.startDate).toISOString(),
                            dayjs(props.endDate).toISOString(),
                        ];
                    }
                } catch (error) {
                    console.error("Error initializing booking modal:", error);
                    modalState.errorMessage = processApiError(error);
                }
            }
        );

        // Keep unavailableByDate in sync for calendar markers. Using a watcher
        // allows us to reuse the manager’s cached data and push the result to
        // the store without re-computing in multiple places.
        watch(
            () => computedAvailabilityData.value,
            newAvailability => {
                store.setUnavailableByDate(
                    newAvailability?.unavailableByDate || {});
            },
            { immediate: true, deep: true }
        );

        // Respond to patron/library/itemtype changes by fetching pickup
        // locations and circulation rules. This uses watchEffect so any of the
        // referenced reactive sources re-trigger the logic and the lastRulesKey
        // guard prevents redundant network calls.
        watchEffect(
            () => {
                const patronId = bookingPatron.value?.patron_id;
                const biblionumber = props.biblionumber;
                if (patronId && biblionumber) {
                    store.fetchPickupLocations(biblionumber, patronId);
                }

                const patron = bookingPatron.value;
                const derivedItemTypeId =
                    bookingItemtypeId.value ??
                    (Array.isArray(constrainedItemTypes.value) &&
                    constrainedItemTypes.value.length === 1
                        ? constrainedItemTypes.value[0].item_type_id
                        : undefined);

                const rulesParams = {
                    patron_category_id: patron?.category_id,
                    item_type_id: derivedItemTypeId,
                    library_id: bookingPickupLibraryId.value,
                };
                const key = JSON.stringify(rulesParams);
                if (lastRulesKey.value !== key) {
                    lastRulesKey.value = key;
                    store.fetchCirculationRules(rulesParams);
                }
            },
            { flush: "post" }
        );

        // Auto-derive item type: prefer a unique constrained type; otherwise
        // infer it from the currently selected item id.
        watch(
            [constrainedItemTypes, () => bookingItemId.value, () => bookableItems.value],
            ([types, itemId, items]) => {
                if (!bookingItemtypeId.value && Array.isArray(types) && types.length === 1) {
                    bookingItemtypeId.value = types[0].item_type_id;
                    return;
                }
                if (!bookingItemtypeId.value && itemId) {
                    const item = (items || []).find(i => String(i.item_id) === String(itemId));
                    if (item) {
                        bookingItemtypeId.value = item.effective_item_type_id || item.item_type_id || null;
                    }
                }
            },
            { immediate: true, deep: true }
        );

        // Clear errors on core inputs/date changes and when circulation rules
        // finish loading (true -> false). Keeps feedback fresh without wiping
        // messages mid-load.
        watch(
            () => ({
                patron: bookingPatron.value?.patron_id,
                pickup: bookingPickupLibraryId.value,
                itemtype: bookingItemtypeId.value,
                item: bookingItemId.value,
                d0: selectedDateRange.value?.[0],
                d1: selectedDateRange.value?.[1],
                rulesLoading: loading.value.circulationRules,
            }),
            (curr, prev) => {
                const inputsChanged =
                    !prev ||
                    curr.patron !== prev.patron ||
                    curr.pickup !== prev.pickup ||
                    curr.itemtype !== prev.itemtype ||
                    curr.item !== prev.item ||
                    curr.d0 !== prev.d0 ||
                    curr.d1 !== prev.d1;
                if (inputsChanged) clearErrors();

                if (prev && prev.rulesLoading && !curr.rulesLoading) {
                    clearErrors();
                }
            },
            { deep: true }
        );

        // Choose a default pickup library when none is set yet. Preference
        // order: configured OPAC default (if enabled), patron’s library, then
        // the first bookable item’s home library when available.
        watch(
            [() => bookingPatron.value, () => pickupLocations.value],
            ([patron, pickupLocations]) => {
                // Attempt to set default if pickupLibraryId is not already set
                if (bookingPickupLibraryId.value) return;


                // OPAC override: Use configured default pickup library if enabled
                try {
                    const opacOverrideEnabled = String(
                        /** @type {any} */ (props.opacDefaultBookingLibraryEnabled)
                    ) === "1" || /** @type {any} */ (props.opacDefaultBookingLibraryEnabled) === true;
                    const opacDefaultBranch = props.opacDefaultBookingLibrary;
                    if (
                        opacOverrideEnabled &&
                        typeof opacDefaultBranch === "string" &&
                        opacDefaultBranch &&
                        Array.isArray(pickupLocations) &&
                        pickupLocations.some(
                            l => l.library_id === opacDefaultBranch
                        )
                    ) {
                        bookingPickupLibraryId.value = opacDefaultBranch;
                        return;
                    }
                } catch (e) {
                    // noop
                }

                if (!patron || pickupLocations.length === 0) return;

                const patronLibId = patron.library_id;
                const hasPatronLib = pickupLocations.some(
                    l => l.library_id === patronLibId
                );

                if (hasPatronLib) {
                    bookingPickupLibraryId.value = patronLibId;
                    return;
                }

                if (bookableItems.value.length === 0) return;

                const firstItemLibId = bookableItems.value[0].home_library_id;
                const hasItemLib = pickupLocations.some(
                    l => l.library_id === firstItemLibId
                );

                if (hasItemLib) {
                    bookingPickupLibraryId.value = firstItemLibId;
                }
            },
            { immediate: true }
        );

        // Show an actionable error when current selection yields no available
        // items, helping the user adjust filters.
        watch(
            [
                constrainedBookableItems,
                () => bookingPatron.value,
                () => bookingPickupLibraryId.value,
                () => bookingItemtypeId.value,
            ],
            ([availableItems, patron, pickupLibraryId, itemtypeId]) => {
                // Only show error if user has made selections that result in no items
                if (
                    patron &&
                    (pickupLibraryId || itemtypeId) &&
                    availableItems.length === 0
                ) {
                    const selectionParts = [];
                    if (pickupLibraryId) {
                        const location = pickupLocations.value.find(
                            l => l.library_id === pickupLibraryId
                        );
                        selectionParts.push(
                            $__("pickup location: %s").format(
                                location?.name || pickupLibraryId
                            )
                        );
                    }
                    if (itemtypeId) {
                        const itemType = itemTypes.value.find(
                            t => t.item_type_id === itemtypeId
                        );
                        selectionParts.push(
                            $__("item type: %s").format(
                                itemType?.description || itemtypeId
                            )
                        );
                    }

                    modalState.errorMessage = $__(
                        "No items are available for booking with the selected criteria (%s). Please adjust your selection."
                    ).format(selectionParts.join(", "));
                } else if (
                    modalState.errorMessage?.includes(
                        $__("No items are available")
                    )
                ) {
                    clearErrors();
                }
            },
            { immediate: true }
        );

        /**
         * Handle additional fields initialization
         */
        async function renderExtendedAttributes(additionalFieldsModule) {
            try {
                additionalFieldsInstance.value = additionalFieldsModule.init({
                    containerId: "booking_extended_attributes",
                    resourceType: "booking",
                });

                const additionalFieldTypes =
                    props.extendedAttributeTypes ??
                    (await additionalFieldsInstance.value.fetchExtendedAttributes(
                        "booking"
                    ));
                if (!additionalFieldTypes?.length) {
                    modalState.hasAdditionalFields = false;
                    return;
                }

                modalState.hasAdditionalFields = true;

                nextTick(() => {
                    additionalFieldsInstance.value.renderExtendedAttributes(
                        additionalFieldTypes,
                        props.extendedAttributes,
                        props.authorizedValues
                    );
                });
            } catch (error) {
                console.error("Failed to render extended attributes:", error);
                modalState.hasAdditionalFields = false;
            }
        }

        function onAdditionalFieldsReady(instance) {
            additionalFieldsInstance.value = instance;
        }

        function onAdditionalFieldsDestroyed() {
            additionalFieldsInstance.value = null;
        }

        // Globally clear all error states (modal + store)
        function clearErrors() {
            modalState.errorMessage = "";
            if (error.value) {
                Object.keys(error.value).forEach(key => {
                    error.value[key] = null;
                });
            }
        }

        function enableBodyScroll() {
            // Use window property via bracket notation for TS friendliness
            const count = Number(window["kohaModalCount"]) || 0;
            window["kohaModalCount"] = Math.max(0, count - 1);

            if ((window["kohaModalCount"] || 0) === 0) {
                document.body.classList.remove("modal-open");
                if (document.body.style.paddingRight) {
                    document.body.style.paddingRight = "";
                }
            }
        }

        function disableBodyScroll() {
            const current = Number(window["kohaModalCount"]) || 0;
            window["kohaModalCount"] = current + 1;

            if (!document.body.classList.contains("modal-open")) {
                const scrollbarWidth =
                    window.innerWidth - document.documentElement.clientWidth;
                if (scrollbarWidth > 0) {
                    document.body.style.paddingRight = scrollbarWidth + "px";
                }
                document.body.classList.add("modal-open");
            }
        }

        function resetModalState() {
            bookingPatron.value = null;
            bookingPickupLibraryId.value = null;
            bookingItemtypeId.value = null;
            bookingItemId.value = null;
            selectedDateRange.value = [];
            modalState.step = 1;
            clearErrors();
            if (additionalFieldsInstance.value) {
                additionalFieldsInstance.value.clear();
            }
            modalState.hasAdditionalFields = false;
            Object.keys(error.value).forEach(key => (error.value[key] = null));
        }

        function clearDateRange() {
            selectedDateRange.value = [];
            clearErrors();
        }

        function handleClose() {
            modalState.isOpen = false;
            enableBodyScroll();
            emit("close");
            resetModalState();
        }

        async function handleSubmit(event) {
            // Use selectedDateRange (clean ISO strings maintained by onChange handler)
            const selectedDates = selectedDateRange.value;

            if (!selectedDates || selectedDates.length === 0) {
                modalState.errorMessage = $__(
                    "Please select a valid date range"
                );
                return;
            }

            const start = selectedDates[0];
            const end =
                selectedDates.length >= 2 ? selectedDates[1] : selectedDates[0];
            const bookingData = {
                booking_id: props.bookingId ?? undefined,
                start_date: start,
                end_date: end,
                pickup_library_id: bookingPickupLibraryId.value,
                biblio_id: props.biblionumber,
                item_id: bookingItemId.value || null,
                patron_id: bookingPatron.value?.patron_id,
                extended_attributes: additionalFieldsInstance.value
                    ? additionalFieldsInstance.value.getValues()
                    : [],
            };

            if (isFormSubmission.value) {
                const form = event.target.closest("form");
                const csrfToken = /** @type {HTMLInputElement|null} */ (
                    document.querySelector('[name="csrf_token"]')
                );

                const dataToSubmit = { ...bookingData };
                if (dataToSubmit.extended_attributes) {
                    dataToSubmit.extended_attributes = JSON.stringify(
                        dataToSubmit.extended_attributes
                    );
                }

                [
                    ...Object.entries(dataToSubmit),
                    [csrfToken?.name, csrfToken?.value],
                    ["op", "cud-add"],
                ].forEach(([name, value]) => {
                    if (value === undefined || value === null) return;
                    const input = document.createElement("input");
                    input.type = "hidden";
                    input.name = String(name);
                    input.value = String(value);
                    form.appendChild(input);
                });
                form.submit();
                return;
            }

            try {
                const result = await store.saveOrUpdateBooking(bookingData);
                updateExternalDependents(result, bookingPatron.value, !!props.bookingId);
                emit("close");
                resetModalState();
            } catch (errorObj) {
                modalState.errorMessage =
                    error.value.submit || processApiError(errorObj);
            }
        }

        // Cleanup function for proper memory management
        onUnmounted(() => {
            if (typeof additionalFieldsInstance.value?.destroy === "function") {
                additionalFieldsInstance.value.destroy();
            }
            enableBodyScroll();
        });

        return {
            modalState,
            modalTitle,
            submitLabel,
            isFormSubmission,
            loading,
            // Store refs from storeToRefs
            selectedDateRange,
            bookingId,
            bookingItemId,
            bookingPatron,
            bookingItemtypeId,
            pickupLibraryId,
            bookableItems,
            bookings,
            checkouts,
            pickupLocations,
            itemTypes,
            circulationRules,
            error,
            // Computed values
            constrainedPickupLocations,
            constrainedItemTypes,
            constrainedBookableItems,
            isCalendarReady,
            isSubmitReady,
            constrainedFlags,
            handleClose,
            handleSubmit,
            clearDateRange,
            resetModalState,
            stepNumber,
            pickupLocationsFilteredOut,
            pickupLocationsTotal,
            bookableItemsFilteredOut,
            bookableItemsTotal,
            maxBookingPeriod,
            bookingPickupLibraryId,
            onAdditionalFieldsReady,
            onAdditionalFieldsDestroyed,
        };
    },
};
</script>

<style>
.booking-modal-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.5);
    z-index: 1050;
    display: block;
    overflow-y: auto;
}

/* Global variables for external libraries (flatpickr) and cross-block usage */
:root {
    /* Success colors for constraint highlighting */
    --booking-success-hue: 134;
    --booking-success-bg: hsl(var(--booking-success-hue), 40%, 90%);
    --booking-success-bg-hover: hsl(var(--booking-success-hue), 35%, 85%);
    --booking-success-border: hsl(var(--booking-success-hue), 70%, 40%);
    --booking-success-border-hover: hsl(var(--booking-success-hue), 75%, 30%);
    --booking-success-text: hsl(var(--booking-success-hue), 80%, 20%);

    /* Border width used by flatpickr */
    --booking-border-width: 1px;

    /* Variables used by second style block (booking markers, calendar states) */
    --booking-marker-size: 0.25em;
    --booking-marker-grid-gap: 0.25rem;
    --booking-marker-grid-offset: -0.75rem;

    /* Color hues used in second style block */
    --booking-warning-hue: 45;
    --booking-danger-hue: 354;
    --booking-info-hue: 195;
    --booking-neutral-hue: 210;

    /* Colors derived from hues (used in second style block) */
    --booking-warning-bg: hsl(var(--booking-warning-hue), 100%, 85%);
    --booking-neutral-600: hsl(var(--booking-neutral-hue), 10%, 45%);

    /* Spacing used in second style block */
    --booking-space-xs: 0.125rem;

    /* Typography used in second style block */
    --booking-text-xs: 0.7rem;

    /* Border radius used in second style block and other components */
    --booking-border-radius-sm: 0.25rem;
    --booking-border-radius-md: 0.5rem;
    --booking-border-radius-full: 50%;
}

/* Design System: CSS Custom Properties (First Style Block Only) */
.booking-modal-backdrop {
    /* Colors not used in second style block */
    --booking-warning-bg-hover: hsl(var(--booking-warning-hue), 100%, 70%);
    --booking-neutral-100: hsl(var(--booking-neutral-hue), 15%, 92%);
    --booking-neutral-300: hsl(var(--booking-neutral-hue), 15%, 75%);
    --booking-neutral-500: hsl(var(--booking-neutral-hue), 10%, 55%);

    /* Spacing Scale (first block only) */
    --booking-space-sm: 0.25rem; /* 4px */
    --booking-space-md: 0.5rem; /* 8px */
    --booking-space-lg: 1rem; /* 16px */
    --booking-space-xl: 1.5rem; /* 24px */
    --booking-space-2xl: 2rem; /* 32px */

    /* Typography Scale (first block only) */
    --booking-text-sm: 0.8125rem;
    --booking-text-base: 1rem;
    --booking-text-lg: 1.1rem;
    --booking-text-xl: 1.3rem;
    --booking-text-2xl: 2rem;

    /* Layout */
    --booking-modal-max-height: calc(100vh - var(--booking-space-2xl));
    --booking-input-min-width: 15rem;

    /* Animation */
    --booking-transition-fast: 0.15s ease-in-out;
}

/* Constraint Highlighting Component */
.flatpickr-calendar .booking-constrained-range-marker {
    background-color: var(--booking-success-bg) !important;
    border: var(--booking-border-width) solid var(--booking-success-border) !important;
    color: var(--booking-success-text) !important;
}

.flatpickr-calendar .flatpickr-day.booking-constrained-range-marker {
    background-color: var(--booking-success-bg) !important;
    border-color: var(--booking-success-border) !important;
    color: var(--booking-success-text) !important;
}

.flatpickr-calendar .flatpickr-day.booking-constrained-range-marker:hover {
    background-color: var(--booking-success-bg-hover) !important;
    border-color: var(--booking-success-border-hover) !important;
}

/* End Date Only Mode - Blocked Intermediate Dates */
.flatpickr-calendar .flatpickr-day.booking-intermediate-blocked {
    background-color: hsl(var(--booking-success-hue), 40%, 90%) !important;
    border-color: hsl(var(--booking-success-hue), 40%, 70%) !important;
    color: hsl(var(--booking-success-hue), 40%, 50%) !important;
    cursor: not-allowed !important;
    opacity: 0.7 !important;
}
.flatpickr-calendar .flatpickr-day.booking-intermediate-blocked:hover {
    background-color: hsl(var(--booking-success-hue), 40%, 85%) !important;
    border-color: hsl(var(--booking-success-hue), 40%, 60%) !important;
}

/* Modal Layout Components */
.booking-modal-window {
    max-height: var(--booking-modal-max-height);
    margin: var(--booking-space-lg) auto;
}

.modal-content {
    max-height: var(--booking-modal-max-height);
    display: flex;
    flex-direction: column;
}

.booking-modal-header {
    padding: var(--booking-space-lg);
    border-bottom: var(--booking-border-width) solid var(--booking-neutral-100);
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-shrink: 0;
}

.booking-modal-title {
    margin: 0;
    font-size: var(--booking-text-xl);
    font-weight: 600;
}

.booking-modal-close {
    background: transparent;
    border: none;
    font-size: var(--booking-text-2xl);
    line-height: 1;
    cursor: pointer;
    color: var(--booking-neutral-500);
    opacity: 0.5;
    transition: opacity var(--booking-transition-fast);
}

.booking-modal-close:hover {
    opacity: 0.75;
}

.booking-modal-body {
    padding: var(--booking-space-xl);
    overflow-y: auto;
    flex: 1 1 auto;
}

/* Form & Layout Components */
.booking-extended-attributes {
    list-style: none;
    padding: 0;
    margin: 0;
}

.step-block {
    margin-bottom: var(--booking-space-2xl);
}

.step-header {
    font-weight: bold;
    font-size: var(--booking-text-lg);
    margin-bottom: var(--booking-space-md);
}

hr {
    border: none;
    border-top: var(--booking-border-width) solid var(--booking-neutral-100);
    margin: var(--booking-space-2xl) 0;
}

/* Input Components */
.booking-flatpickr-input,
.flatpickr-input.booking-flatpickr-input {
    min-width: var(--booking-input-min-width);
    padding: calc(var(--booking-space-md) - var(--booking-space-xs))
        calc(var(--booking-space-md) + var(--booking-space-sm));
    border: var(--booking-border-width) solid var(--booking-neutral-300);
    border-radius: var(--booking-border-radius-sm);
    font-size: var(--booking-text-base);
    transition: border-color var(--booking-transition-fast),
        box-shadow var(--booking-transition-fast);
}

/* Calendar Legend Component */
.calendar-legend {
    margin-top: var(--booking-space-lg);
    margin-bottom: var(--booking-space-lg);
    font-size: var(--booking-text-sm);
    display: flex;
    align-items: center;
}

.calendar-legend .booking-marker-dot {
    /* Make legend dots much larger and more visible */
    width: calc(var(--booking-marker-size) * 3) !important;
    height: calc(var(--booking-marker-size) * 3) !important;
    margin-right: calc(var(--booking-space-sm) * 1.5);
    border: var(--booking-border-width) solid hsla(0, 0%, 0%, 0.15);
}

.calendar-legend .ml-3 {
    margin-left: var(--booking-space-lg);
}

/* Legend colors match actual calendar markers exactly */
.calendar-legend .booking-marker-dot--booked {
    background: var(--booking-warning-bg) !important;
}

.calendar-legend .booking-marker-dot--checked-out {
    background: hsl(var(--booking-danger-hue), 60%, 85%) !important;
}

.calendar-legend .booking-marker-dot--lead {
    background: hsl(var(--booking-info-hue), 60%, 85%) !important;
}

.calendar-legend .booking-marker-dot--trail {
    background: var(--booking-warning-bg) !important;
}
</style>

<style>
.booking-date-picker {
    display: flex;
    align-items: stretch;
    width: 100%;
}

.booking-date-picker > .form-control {
    flex: 1 1 auto;
    min-width: 0;
    margin-bottom: 0;
}

.booking-date-picker-append {
    display: flex;
    margin-left: -1px;
}

.booking-date-picker-append .btn {
    border-top-left-radius: 0;
    border-bottom-left-radius: 0;
}

.booking-date-picker > .form-control:not(:last-child) {
    border-top-right-radius: 0;
    border-bottom-right-radius: 0;
}

/* External Library Integration */
.booking-modal-body .vs__selected {
    font-size: var(--vs-font-size);
    line-height: var(--vs-line-height);
}

.booking-constraint-info {
    margin-top: var(--booking-space-lg);
    margin-bottom: var(--booking-space-lg);
}

/* Booking Status Marker System */
.booking-marker-grid {
    position: relative;
    top: var(--booking-marker-grid-offset);
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: var(--booking-marker-grid-gap);
    width: fit-content;
    max-width: 90%;
    margin-left: auto;
    margin-right: auto;
    line-height: normal;
}

.booking-marker-item {
    display: inline-flex;
    align-items: center;
}

.booking-marker-dot {
    display: inline-block;
    width: var(--booking-marker-size);
    height: var(--booking-marker-size);
    border-radius: var(--booking-border-radius-full);
    vertical-align: middle;
}

.booking-marker-count {
    font-size: var(--booking-text-xs);
    margin-left: var(--booking-space-xs);
    line-height: 1;
    font-weight: normal;
    color: var(--booking-neutral-600);
}

/* Status Indicator Colors */
.booking-marker-dot--booked {
    background: var(--booking-warning-bg);
}

.booking-marker-dot--checked-out {
    background: hsl(var(--booking-danger-hue), 60%, 85%);
}

.booking-marker-dot--lead {
    background: hsl(var(--booking-info-hue), 60%, 85%);
}

.booking-marker-dot--trail {
    background: var(--booking-warning-bg);
}

/* Calendar Day States */
.booked {
    background: var(--booking-warning-bg) !important;
    color: hsl(var(--booking-warning-hue), 80%, 25%) !important;
    border-radius: var(--booking-border-radius-full) !important;
}

.checked-out {
    background: hsl(var(--booking-danger-hue), 60%, 85%) !important;
    color: hsl(var(--booking-danger-hue), 80%, 25%) !important;
    border-radius: var(--booking-border-radius-full) !important;
}

/* Hover States with Transparency */
.flatpickr-day.booking-day--hover-lead {
    background-color: hsl(var(--booking-info-hue), 60%, 85%, 0.2) !important;
}

.flatpickr-day.booking-day--hover-trail {
    background-color: hsl(
        var(--booking-warning-hue),
        100%,
        70%,
        0.2
    ) !important;
}
</style>
