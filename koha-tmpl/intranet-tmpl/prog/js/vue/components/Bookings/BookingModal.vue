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
                        class="booking-modal-close"
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
                        <KohaAlert
                            :show="showCapacityWarning"
                            variant="warning"
                            :message="zeroCapacityMessage"
                        />
                        <BookingPatronStep
                            v-if="showPatronSelect"
                            v-model="bookingPatron"
                            :step-number="stepNumber.patron"
                            :set-error="setError"
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
                            :details-enabled="readiness.dataReady"
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
                            :step-number="stepNumber.period"
                            :calendar-enabled="readiness.isCalendarReady"
                            :constraint-options="constraintOptions"
                            :date-range-constraint="dateRangeConstraint"
                            :max-booking-period="maxBookingPeriod"
                            :error-message="uiError.message"
                            :set-error="setError"
                            :has-selected-dates="selectedDateRange?.length > 0"
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
                            :set-error="setError"
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
import { toISO } from "./lib/booking/date-utils.mjs";
import {
    computed,
    ref,
    reactive,
    watch,
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
    constrainBookableItems,
    constrainItemTypes,
    constrainPickupLocations,
} from "./lib/booking/manager.mjs";
import { useBookingStore } from "../../stores/bookingStore";
import { storeToRefs } from "pinia";
import { updateExternalDependents } from "./lib/adapters/external-dependents.mjs";
import { preloadFlatpickrLocale } from "./lib/adapters/calendar.mjs";
import { enableBodyScroll, disableBodyScroll } from "./lib/adapters/modal-scroll.mjs";
import { appendHiddenInputs } from "./lib/adapters/form.mjs";
import { calculateStepNumbers } from "./lib/ui/steps.mjs";
import { useBookingValidation } from "./composables/useBookingValidation.mjs";
import { calculateMaxBookingPeriod } from "./lib/booking/manager.mjs";
import { useDefaultPickup } from "./composables/useDefaultPickup.mjs";
import { buildNoItemsAvailableMessage } from "./lib/ui/selection-message.mjs";
import { useRulesFetcher } from "./composables/useRulesFetcher.mjs";
import { normalizeIdType } from "./lib/booking/id-utils.mjs";
import { useDerivedItemType } from "./composables/useDerivedItemType.mjs";
import { useErrorState } from "./composables/useErrorState.mjs";
import { useCapacityGuard } from "./composables/useCapacityGuard.mjs";
import KohaAlert from "../KohaAlert.vue";

export default {
    name: "BookingModal",
    components: {
        BookingPatronStep,
        BookingDetailsStep,
        BookingPeriodStep,
        BookingAdditionalFields,
        KohaAlert,
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
        } = storeToRefs(store);

        // Calculate max booking period from circulation rules and selected constraint

        // Use validation composable for reactive validation logic
        const { canSubmit: canSubmitReactive } = useBookingValidation(store);

        // Grouped reactive state following Vue 3 best practices
        const modalState = reactive({
            isOpen: props.open,
            step: 1,
            hasAdditionalFields: false,
        });
        const { error: uiError, setError, clear: clearError } = useErrorState();

        const additionalFieldsInstance = ref(null);

        const modalTitle = computed(
            () =>
                props.title ||
                (bookingId.value ? $__("Edit booking") : $__("Place booking"))
        );

        // Determine whether to show pickup location select
        // In OPAC: show if default library is not enabled
        // In staff: use the explicit prop
        const showPickupLocationSelect = computed(() => {
            if (props.opacDefaultBookingLibraryEnabled !== null) {
                const enabled = props.opacDefaultBookingLibraryEnabled === true ||
                    String(props.opacDefaultBookingLibraryEnabled) === "1";
                return !enabled;
            }
            return props.showPickupLocationSelect;
        });

        const stepNumber = computed(() => {
            return calculateStepNumbers(
                props.showPatronSelect,
                props.showItemDetailsSelects,
                showPickupLocationSelect.value,
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

        // pickupLibraryId is a ref from the store; use directly

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

        const maxBookingPeriod = computed(() =>
            calculateMaxBookingPeriod(
                circulationRules.value,
                props.dateRangeConstraint,
                props.customDateRangeFormula
            )
        );

        const constraintOptions = computed(() => ({
            dateRangeConstraint: props.dateRangeConstraint,
            maxBookingPeriod: maxBookingPeriod.value,
        }));

        // Centralized capacity guard (extracts UI and error handling)
        const { hasPositiveCapacity, zeroCapacityMessage, showCapacityWarning } =
            useCapacityGuard({
                circulationRules,
                loading,
                bookableItems,
                bookingPatron,
                bookingItemId,
                bookingItemtypeId,
                showPatronSelect: props.showPatronSelect,
                showItemDetailsSelects: props.showItemDetailsSelects,
                showPickupLocationSelect: showPickupLocationSelect.value,
                dateRangeConstraint: props.dateRangeConstraint,
                setError,
                clearError,
            });

        // Readiness flags
        const dataReady = computed(
            () =>
                !loading.value.bookableItems &&
                !loading.value.bookings &&
                !loading.value.checkouts &&
                (bookableItems.value?.length ?? 0) > 0
        );
        const formPrefilterValid = computed(() => {
            const requireTypeOrItem = !!props.showItemDetailsSelects;
            const hasTypeOrItem =
                !!bookingItemId.value || !!bookingItemtypeId.value;
            const patronOk = !props.showPatronSelect || !!bookingPatron.value;
            return patronOk && (requireTypeOrItem ? hasTypeOrItem : true);
        });
        const hasAvailableItems = computed(
            () => constrainedBookableItems.value.length > 0
        );

        const isCalendarReady = computed(() => {
            const basicReady = dataReady.value &&
                formPrefilterValid.value &&
                hasAvailableItems.value;
            if (!basicReady) return false;
            if (loading.value.circulationRules) return true;

            return hasPositiveCapacity.value;
        });

        // Separate validation for submit button using reactive composable
        const isSubmitReady = computed(
            () => isCalendarReady.value && canSubmitReactive.value
        );

        // Grouped readiness for convenient consumption (optional)
        const readiness = computed(() => ({
            dataReady: dataReady.value,
            formPrefilterValid: formPrefilterValid.value,
            hasAvailableItems: hasAvailableItems.value,
            isCalendarReady: isCalendarReady.value,
            canSubmit: isSubmitReady.value,
        }));

        // Watchers: synchronize open state, orchestrate initial data load,
        // push availability to store, fetch rules/pickup locations, and keep
        // UX guidance/errors fresh while inputs change.

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

                    // Normalize itemId type to match bookableItems' item_id type for vue-select strict matching
                    bookingItemId.value = (props.itemId != null) ? normalizeIdType(bookableItems.value?.[0]?.item_id, props.itemId) : null;
                    if (props.itemtypeId) {
                        bookingItemtypeId.value = props.itemtypeId;
                    }

                    if (props.startDate && props.endDate) {
                        selectedDateRange.value = [
                            toISO(props.startDate),
                            toISO(props.endDate),
                        ];
                    }
                } catch (error) {
                    console.error("Error initializing booking modal:", error);
                    setError(processApiError(error), "api");
                }
            }
        );

        useRulesFetcher({
            store,
            bookingPatron,
            bookingPickupLibraryId: pickupLibraryId,
            bookingItemtypeId,
            constrainedItemTypes,
            selectedDateRange,
            biblionumber: String(props.biblionumber),
        });

        useDerivedItemType({
            bookingItemtypeId,
            bookingItemId,
            constrainedItemTypes,
            bookableItems,
        });

        watch(
            () => ({
                patron: bookingPatron.value?.patron_id,
                pickup: pickupLibraryId.value,
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

                if (prev?.rulesLoading && !curr.rulesLoading) {
                    clearErrors();
                }
            }
        );

        // Default pickup selection handled by composable
        useDefaultPickup({
            bookingPickupLibraryId: pickupLibraryId,
            bookingPatron,
            pickupLocations,
            bookableItems,
            opacDefaultBookingLibraryEnabled: props.opacDefaultBookingLibraryEnabled,
            opacDefaultBookingLibrary: props.opacDefaultBookingLibrary,
        });

        // Show an actionable error when current selection yields no available
        // items, helping the user adjust filters.
        watch(
            [
                constrainedBookableItems,
                () => bookingPatron.value,
                () => pickupLibraryId.value,
                () => bookingItemtypeId.value,
            ],
            ([availableItems, patron, pickupLibrary, itemtypeId]) => {
                // Only show error if user has made selections that result in no items
                if (
                    patron &&
                    (pickupLibrary || itemtypeId) &&
                    availableItems.length === 0
                ) {
                    const msg = buildNoItemsAvailableMessage(
                        pickupLocations.value,
                        itemTypes.value,
                        pickupLibrary,
                        itemtypeId
                    );
                    setError(msg, "no_items");
                } else if (uiError.code === "no_items") {
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
            clearError();
            store.resetErrors();
        }


        function resetModalState() {
            bookingPatron.value = null;
            pickupLibraryId.value = null;
            bookingItemtypeId.value = null;
            bookingItemId.value = null;
            selectedDateRange.value = [];
            modalState.step = 1;
            clearErrors();
            additionalFieldsInstance.value?.clear?.();
            modalState.hasAdditionalFields = false;
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
                setError($__("Please select a valid date range"), "invalid_date_range");
                return;
            }

            const start = selectedDates[0];
            const end =
                selectedDates.length >= 2 ? selectedDates[1] : selectedDates[0];
            const bookingData = {
                booking_id: props.bookingId ?? undefined,
                start_date: start,
                end_date: end,
                pickup_library_id: pickupLibraryId.value,
                biblio_id: props.biblionumber,
                item_id: bookingItemId.value || null,
                patron_id: bookingPatron.value?.patron_id,
                extended_attributes: additionalFieldsInstance.value
                    ? additionalFieldsInstance.value.getValues()
                    : [],
            };

            if (isFormSubmission.value) {
                const form = /** @type {HTMLFormElement} */ (event.target);
                const csrfToken = /** @type {HTMLInputElement|null} */ (
                    document.querySelector('[name="csrf_token"]')
                );

                const dataToSubmit = { ...bookingData };
                if (dataToSubmit.extended_attributes) {
                    dataToSubmit.extended_attributes = JSON.stringify(
                        dataToSubmit.extended_attributes
                    );
                }

                appendHiddenInputs(
                    form,
                    [
                        ...Object.entries(dataToSubmit),
                        [csrfToken?.name, csrfToken?.value],
                        ['op', 'cud-add'],
                    ]
                );
                form.submit();
                return;
            }

            try {
                const result = await store.saveOrUpdateBooking(bookingData);
                updateExternalDependents(result, bookingPatron.value, !!props.bookingId);
                emit("close");
                resetModalState();
            } catch (errorObj) {
                setError(processApiError(errorObj), "api");
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
            showPickupLocationSelect,
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
            uiError,
            setError,
            // Computed values
            constrainedPickupLocations,
            constrainedItemTypes,
            constrainedBookableItems,
            isCalendarReady,
            isSubmitReady,
            readiness,
            constrainedFlags,
            constraintOptions,
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
            onAdditionalFieldsReady,
            onAdditionalFieldsDestroyed,
            hasPositiveCapacity,
            zeroCapacityMessage,
            showCapacityWarning,
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

/* Bold styling for end of loan and renewal period boundaries */
.flatpickr-calendar .flatpickr-day.booking-loan-boundary {
    font-weight: 700 !important;
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
    padding: 0;
    margin: 0;
    width: var(--booking-space-2xl);
    height: var(--booking-space-2xl);
    display: flex;
    align-items: center;
    justify-content: center;
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
