<template>
    <div
        v-if="isOpen"
        class="modal show booking-modal-backdrop"
        tabindex="-1"
        role="dialog"
    >
        <div class="modal-dialog booking-modal-window" role="document">
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
                        <fieldset v-if="showPatronSelect" class="step-block">
                            <legend class="step-header">
                                {{ stepNumber.patron }}.
                                {{ $__("Select Patron") }}
                            </legend>
                            <PatronSearchSelect
                                v-model="bookingPatron"
                                :label="
                                    $__('Patron')
                                "
                                :placeholder="
                                    $__('Search for a patron')
                                "
                            >
                                <template #no-options="{ hasSearched }">
                                    {{ hasSearched ? $__("No patrons found.") : $__("Type to search for patrons.") }}
                                </template>
                                <template #spinner>
                                    <span class="sr-only">{{ $__("Searching...") }}</span>
                                </template>
                            </PatronSearchSelect>
                        </fieldset>
                        <hr
                            v-if="
                                showPatronSelect ||
                                showItemDetailsSelects ||
                                showPickupLocationSelect
                            "
                        />
                        <fieldset
                            v-if="
                                showItemDetailsSelects ||
                                showPickupLocationSelect
                            "
                            class="step-block"
                        >
                            <legend class="step-header">
                                {{ stepNumber.details }}.
                                {{
                                    showItemDetailsSelects
                                        ? $__(
                                              "Select Pickup Location and Item Type or Item"
                                          )
                                        : showPickupLocationSelect
                                        ? $__("Select Pickup Location")
                                        : ""
                                }}
                            </legend>
                            <div
                                v-if="
                                    showPickupLocationSelect ||
                                    showItemDetailsSelects
                                "
                                class="form-group"
                            >
                                <label for="pickup_library_id">{{
                                    $__("Pickup location")
                                }}</label>
                                <v-select
                                    v-model="bookingPickupLibraryId"
                                    :placeholder="
                                        $__('Select a pickup location')
                                    "
                                    :options="constrainedPickupLocations"
                                    label="name"
                                    :reduce="l => l.library_id"
                                    :loading="loading.pickupLocations"
                                    :clearable="true"
                                    :disabled="
                                        !bookingPatron && showPatronSelect
                                    "
                                >
                                    <template #no-options>
                                        {{ $__("No pickup locations available.") }}
                                    </template>
                                    <template #spinner>
                                        <span class="sr-only">{{ $__("Loading...") }}</span>
                                    </template>
                                </v-select>
                                <span
                                    v-if="
                                        constrainedFlags.pickupLocations &&
                                        (showPickupLocationSelect ||
                                            showItemDetailsSelects)
                                    "
                                    class="badge badge-warning ml-2"
                                >
                                    {{ $__("Options updated") }}
                                    <span class="ml-1"
                                        >({{
                                            pickupLocationsTotal -
                                            pickupLocationsFilteredOut
                                        }}/{{ pickupLocationsTotal }})</span
                                    >
                                </span>
                            </div>
                            <div
                                v-if="showItemDetailsSelects"
                                class="form-group"
                            >
                                <label for="booking_itemtype">{{
                                    $__("Item type")
                                }}</label>
                                <v-select
                                    v-model="bookingItemtypeId"
                                    :options="constrainedItemTypes"
                                    label="description"
                                    :reduce="t => t.item_type_id"
                                    :clearable="true"
                                    :disabled="
                                        !bookingPatron && showPatronSelect
                                    "
                                >
                                    <template #no-options>
                                        {{ $__("No item types available.") }}
                                    </template>
                                </v-select>
                                <span
                                    v-if="constrainedFlags.itemTypes"
                                    class="badge badge-warning ml-2"
                                    >{{ $__("Options updated") }}</span
                                >
                            </div>
                            <div
                                v-if="showItemDetailsSelects"
                                class="form-group"
                            >
                                <label for="booking_item_id">{{
                                    $__("Item")
                                }}</label>
                                <v-select
                                    v-model="bookingItemId"
                                    :placeholder="$__('Any item')"
                                    :options="constrainedBookableItems"
                                    label="external_id"
                                    :reduce="i => i.item_id"
                                    :clearable="true"
                                    :loading="loading.items"
                                    :disabled="
                                        !bookingPatron && showPatronSelect
                                    "
                                >
                                    <template #no-options>
                                        {{ $__("No items available.") }}
                                    </template>
                                    <template #spinner>
                                        <span class="sr-only">{{ $__("Loading...") }}</span>
                                    </template>
                                </v-select>
                                <span
                                    v-if="constrainedFlags.bookableItems"
                                    class="badge badge-warning ml-2"
                                >
                                    {{ $__("Options updated") }}
                                    <span class="ml-1"
                                        >({{
                                            bookableItemsTotal -
                                            bookableItemsFilteredOut
                                        }}/{{ bookableItemsTotal }})</span
                                    >
                                </span>
                            </div>
                        </fieldset>
                        <hr
                            v-if="
                                showItemDetailsSelects ||
                                showPickupLocationSelect
                            "
                        />
                        <fieldset class="step-block">
                            <legend class="step-header">
                                {{ stepNumber.period }}.
                                {{ $__("Select Booking Period") }}
                            </legend>
                            <div class="form-group">
                                <label for="booking_period">{{
                                    $__("Booking period")
                                }}</label>
                                <flat-pickr
                                    v-model="dateRange"
                                    class="booking-flatpickr-input"
                                    :config="flatpickrConfig"
                                />
                            </div>
                            <div
                                v-if="dateRangeConstraint && maxBookingPeriod"
                                class="alert alert-info mb-2"
                            >
                                <small>
                                    <strong>{{
                                        $__("Booking constraint active:")
                                    }}</strong>
                                    {{
                                        dateRangeConstraint === "issuelength"
                                            ? $__(
                                                  "Booking period limited to issue length (%s days)"
                                              ).format(maxBookingPeriod)
                                            : dateRangeConstraint ===
                                              "issuelength_with_renewals"
                                            ? $__(
                                                  "Booking period limited to issue length with renewals (%s days)"
                                              ).format(maxBookingPeriod)
                                            : $__(
                                                  "Booking period limited by circulation rules (%s days)"
                                              ).format(maxBookingPeriod)
                                    }}
                                </small>
                            </div>
                            <div class="calendar-legend mt-2 mb-3">
                                <span
                                    class="booking-marker-dot booking-marker-dot--booked"
                                ></span>
                                {{ $__("Booked") }}
                                <span
                                    class="booking-marker-dot booking-marker-dot--lead ml-3"
                                ></span>
                                {{ $__("Lead Period") }}
                                <span
                                    class="booking-marker-dot booking-marker-dot--trail ml-3"
                                ></span>
                                {{ $__("Trail Period") }}
                                <span
                                    class="booking-marker-dot booking-marker-dot--checked-out ml-3"
                                ></span>
                                {{ $__("Checked Out") }}
                                <span
                                    v-if="
                                        dateRangeConstraint &&
                                        dateRange &&
                                        dateRange.length === 1
                                    "
                                    class="booking-marker-dot ml-3"
                                    style="background-color: #28a745"
                                ></span>
                                <span
                                    v-if="
                                        dateRangeConstraint &&
                                        dateRange &&
                                        dateRange.length === 1
                                    "
                                    class="ml-1"
                                >
                                    {{ $__("Required end date") }}
                                </span>
                            </div>
                        </fieldset>
                        <hr
                            v-if="showAdditionalFields && hasAdditionalFields"
                        />
                        <fieldset
                            v-if="showAdditionalFields && hasAdditionalFields"
                            class="step-block"
                        >
                            <legend class="step-header">
                                {{ stepNumber.additionalFields }}.
                                {{ $__("Additional Fields") }}
                            </legend>
                            <ul
                                id="booking_extended_attributes"
                                class="booking-extended-attributes"
                            ></ul>
                        </fieldset>
                        <div
                            v-if="errorMessage"
                            class="alert alert-danger mt-2"
                        >
                            {{ errorMessage }}
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <div class="d-flex gap-2">
                        <button
                            class="btn btn-primary"
                            :disabled="loading.submit || !canProceedToStep3"
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
    <BookingTooltip
        :markers="tooltipMarkers"
        :x="tooltipX"
        :y="tooltipY"
        :visible="tooltipVisible"
    />
</template>

<script>
import dayjs from "../../utils/dayjs.js";
import { computed, ref, watch, watchEffect, nextTick } from "vue";
import flatPickr from "vue-flatpickr-component";
import vSelect from "vue-select";
import BookingTooltip from "./BookingTooltip.vue";
import { $__ } from "../../i18n";
import { processApiError } from "../../utils/apiErrors.js";
import {
    calculateDisabledDates,
    constrainBookableItems,
    constrainItemTypes,
    constrainPickupLocations,
    parseDateRange,
} from "./bookingManager.mjs";
import { useBookingStore } from "../../stores/bookingStore";
import { updateExternalDependents } from "./bookingUtils.mjs";
import {
    createOnChange,
    createOnDayCreate,
    createOnClose,
    createOnFlatpickrReady,
    createFlatpickrConfig,
    preloadFlatpickrLocale,
} from "./bookingCalendar.js";
import PatronSearchSelect from "./PatronSearchSelect.vue";


export default {
    name: "BookingModal",
    components: {
        vSelect,
        flatPickr,
        BookingTooltip,
        PatronSearchSelect,
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
            validator: value => ["api", "form-submission"].includes(value),
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
                    value
                ),
        },
        customDateRangeFormula: {
            type: Function,
            default: null,
        },
    },
    emits: ["close"],
    setup(props, { emit }) {
        const store = useBookingStore();

        const isOpen = ref(props.open);
        const dateRange = ref([]);
        const loading = store.loading;
        const step = ref(1);
        const constrainedFlags = ref({
            pickupLocations: false,
            itemTypes: false,
            bookableItems: false,
        });
        const errorMessage = ref("");
        const flatpickrInstance = ref(null);
        const patronOptions = ref([]);
        const tooltipVisible = ref(false);
        const tooltipX = ref(0);
        const tooltipY = ref(0);
        const tooltipMarkers = ref([]);
        const additionalFieldsInstance = ref(null);
        const hasAdditionalFields = ref(false);

        const modalTitle = computed(
            () =>
                props.title ||
                (store.bookingId ? $__("Edit booking") : $__("Place booking"))
        );

        const stepNumber = computed(() => {
            let currentStep = 1;
            const steps = {
                patron: 0,
                details: 0,
                period: 0,
                additionalFields: 0,
            };
            if (props.showPatronSelect) {
                steps.patron = currentStep++;
            }
            if (
                props.showItemDetailsSelects ||
                props.showPickupLocationSelect
            ) {
                steps.details = currentStep++;
            }
            steps.period = currentStep++;
            if (props.showAdditionalFields && hasAdditionalFields.value) {
                steps.additionalFields = currentStep++;
            }
            return steps;
        });

        const submitLabel = computed(() =>
            store.bookingId ? $__("Update booking") : $__("Place booking")
        );

        const isFormSubmission = computed(
            () => props.submitType === "form-submission"
        );

        const bookingPatron = computed({
            get: () => store.bookingPatron,
            set: value => {
                store.bookingPatron = value;
            },
        });

        const bookingPickupLibraryId = computed({
            get: () => store.pickupLibraryId,
            set: value => {
                store.pickupLibraryId = value;
            },
        });

        const bookingItemtypeId = computed({
            get: () => store.bookingItemtypeId,
            set: value => {
                store.bookingItemtypeId = value;
            },
        });

        const bookingItemId = computed({
            get: () => store.bookingItemId,
            set: value => {
                store.bookingItemId = value;
            },
        });

        const canProceedToStep3 = computed(() => {
            return !!(
                bookingPatron.value &&
                (bookingItemId.value ||
                    bookingItemtypeId.value ||
                    bookingPickupLibraryId.value)
            );
        });

        const pickupLocationConstraint = computed(() =>
            constrainPickupLocations(
                store.pickupLocations,
                store.bookableItems,
                bookingItemtypeId.value,
                bookingItemId.value,
                constrainedFlags
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
                store.bookableItems,
                store.pickupLocations,
                bookingPickupLibraryId.value,
                bookingItemtypeId.value,
                constrainedFlags
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

        const constrainedItemTypes = computed(() =>
            constrainItemTypes(
                store.itemTypes,
                store.bookableItems,
                store.pickupLocations,
                bookingPickupLibraryId.value,
                bookingItemId.value,
                constrainedFlags
            )
        );

        const computedAvailabilityData = computed(() => {
            const baseRules = store.circulationRules[0] || {};

            // Apply date range constraint by overriding maxPeriod if configured
            const effectiveRules = { ...baseRules };
            if (props.dateRangeConstraint && maxBookingPeriod.value) {
                effectiveRules.maxPeriod = maxBookingPeriod.value;
            }

            // Convert dateRange.value to proper selectedDates array for calculateDisabledDates
            let selectedDatesArray = [];
            if (typeof dateRange.value === "string") {
                // Parse the string format back to Date array
                if (dateRange.value.includes(" to ")) {
                    const [start, end] = dateRange.value.split(" to ");
                    selectedDatesArray = [new Date(start), new Date(end)];
                } else if (dateRange.value) {
                    selectedDatesArray = [new Date(dateRange.value)];
                }
            } else if (Array.isArray(dateRange.value)) {
                selectedDatesArray = dateRange.value.map(d => new Date(d));
            }

            const result = calculateDisabledDates(
                store.bookings,
                store.checkouts,
                store.bookableItems,
                store.bookingItemId,
                store.bookingId,
                selectedDatesArray,
                effectiveRules
            );

            return result;
        });

        const maxBookingPeriod = computed(() => {
            if (!props.dateRangeConstraint) return null;

            const rules = store.circulationRules[0];
            if (!rules) return null;

            const issuelength = parseInt(rules.issuelength) || 0;

            if (props.dateRangeConstraint === "issuelength") {
                return issuelength;
            }

            if (props.dateRangeConstraint === "issuelength_with_renewals") {
                const renewalperiod = parseInt(rules.renewalperiod) || 0;
                const renewalsallowed = parseInt(rules.renewalsallowed) || 0;
                return issuelength + renewalperiod * renewalsallowed;
            }

            if (props.dateRangeConstraint === "custom" && props.customDateRangeFormula) {
                return props.customDateRangeFormula(rules);
            }

            return null;
        });

        const flatpickrConfig = computed(() => {
            const availability = computedAvailabilityData.value || {
                disable: () => false,
            };

            const constraintOptions = {
                dateRangeConstraint: props.dateRangeConstraint,
                maxBookingPeriod: maxBookingPeriod.value,
            };

            const baseConfig = {
                mode: "range",
                minDate: "today",
                disable: [availability.disable],
                clickOpens: canProceedToStep3.value,
                dateFormat: "Y-m-d",
                wrap: false,
                allowInput: false,
                altInput: false,
                altInputClass: "booking-flatpickr-input",
                onChange: createOnChange(
                    store,
                    errorMessage,
                    tooltipVisible,
                    constraintOptions
                ),
                onDayCreate: createOnDayCreate(
                    store,
                    tooltipMarkers,
                    tooltipVisible,
                    tooltipX,
                    tooltipY
                ),
                onClose: createOnClose(tooltipMarkers, tooltipVisible),
                onFlatpickrReady: createOnFlatpickrReady(flatpickrInstance),
            };

            return createFlatpickrConfig(baseConfig);
        });

        watch(
            () => props.open,
            val => {
                isOpen.value = val;
                if (val) {
                    resetModalState();
                }
            }
        );

        watch(isOpen, async open => {
            if (open) {
                disableBodyScroll();
                // Preload the appropriate flatpickr locale
                await preloadFlatpickrLocale();
            } else {
                enableBodyScroll();
                return;
            }

            step.value = 1;
            const biblionumber = props.biblionumber;
            if (!biblionumber) return;

            store.bookingId = props.bookingId;

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
                    hasAdditionalFields.value = false;
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
                store.pickupLibraryId = props.pickupLibraryId;
                store.bookingItemId = props.itemId;
                store.bookingItemtypeId = props.itemtypeId;

                if (props.startDate && props.endDate) {
                    dateRange.value = [
                        new Date(props.startDate),
                        new Date(props.endDate),
                    ].map(d => d.getTime());
                }
            } catch (error) {
                console.error("Error initializing booking modal:", error);
                errorMessage.value = processApiError(error);
            }
        });

        watch(
            () => computedAvailabilityData.value,
            newAvailability => {
                store.unavailableByDate =
                    newAvailability?.unavailableByDate || {};
            },
            { immediate: true, deep: true }
        );

        watchEffect(() => {
            const patronId = bookingPatron.value?.patron_id;
            const biblionumber = props.biblionumber;
            if (patronId && biblionumber) {
                store.fetchPickupLocations(biblionumber, patronId);
            }

            const patron = bookingPatron.value;
            store.fetchCirculationRules({
                patron_category_id: patron?.category_id,
                item_type_id: bookingItemtypeId.value,
                library_id: bookingPickupLibraryId.value,
            });
        });

        watch(
            constrainedItemTypes,
            newTypes => {
                if (newTypes.length === 1 && !bookingItemtypeId.value) {
                    bookingItemtypeId.value = newTypes[0].item_type_id;
                }
            },
            { immediate: true }
        );

        watch(
            [() => bookingPatron.value, () => store.pickupLocations],
            ([patron, pickupLocations]) => {
                // Attempt to set default if pickupLibraryId is not already set
                if (bookingPickupLibraryId.value) return;

                if (!patron || pickupLocations.length === 0) return;

                const patronLibId = patron.library_id;
                const hasPatronLib = pickupLocations.some(
                    l => l.library_id === patronLibId
                );

                if (hasPatronLib) {
                    bookingPickupLibraryId.value = patronLibId;
                    return;
                }

                if (store.bookableItems.length === 0) return;

                const firstItemLibId = store.bookableItems[0].home_library_id;
                const hasItemLib = pickupLocations.some(
                    l => l.library_id === firstItemLibId
                );

                if (hasItemLib) {
                    bookingPickupLibraryId.value = firstItemLibId;
                }
            },
            { immediate: true }
        );

        /**
         * @param additionalFieldsModule
         */
        async function renderExtendedAttributes(additionalFieldsModule) {
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
                hasAdditionalFields.value = false;
                return;
            }

            hasAdditionalFields.value = true;

            nextTick(() => {
                additionalFieldsInstance.value.renderExtendedAttributes(
                    additionalFieldTypes,
                    props.extendedAttributes,
                    props.authorizedValues
                );
            });
        }

        function enableBodyScroll() {
            if (!window.kohaModalCount) window.kohaModalCount = 0;
            window.kohaModalCount = Math.max(0, window.kohaModalCount - 1);

            if (window.kohaModalCount === 0) {
                document.body.classList.remove("modal-open");
                if (document.body.style.paddingRight) {
                    document.body.style.paddingRight = "";
                }
            }
        }

        function disableBodyScroll() {
            if (!window.kohaModalCount) window.kohaModalCount = 0;
            window.kohaModalCount++;

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
            dateRange.value = [];
            step.value = 1;
            errorMessage.value = "";
            if (additionalFieldsInstance.value) {
                additionalFieldsInstance.value.clear();
            }
            hasAdditionalFields.value = false;
            Object.keys(store.error).forEach(key => (store.error[key] = null));
        }

        function handleClose() {
            isOpen.value = false;
            enableBodyScroll();
            emit("close");
            resetModalState();
        }

        async function handleSubmit(event) {
            const [start, end] = parseDateRange(dateRange.value);
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
                const csrfToken = document.querySelector('[name="csrf_token"]');

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
                    input.name = name;
                    input.value = value;
                    form.appendChild(input);
                });
                form.submit();
                return;
            }

            try {
                const result = await store.saveOrUpdateBooking(bookingData);
                updateExternalDependents(store, result, !!props.bookingId);
                emit("close");
                resetModalState();
            } catch (error) {
                errorMessage.value =
                    store.error.submit || processApiError(error);
            }
        }

        function goToStep(targetStep) {
            step.value = targetStep;
        }

        return {
            isOpen,
            modalTitle,
            submitLabel,
            isFormSubmission,
            errorMessage,
            loading,
            patronOptions,
            flatpickrConfig,
            dateRange,
            store,
            step,
            goToStep,
            constrainedPickupLocations,
            constrainedItemTypes,
            constrainedBookableItems,
            canProceedToStep3,
            constrainedFlags,
            handleClose,
            handleSubmit,
            tooltipVisible,
            tooltipX,
            tooltipY,
            tooltipMarkers,
            resetModalState,
            stepNumber,
            hasAdditionalFields,
            pickupLocationsFilteredOut,
            pickupLocationsTotal,
            bookableItemsFilteredOut,
            bookableItemsTotal,
            maxBookingPeriod,
            flatpickrInstance,
            bookingPatron,
            bookingItemtypeId,
            bookingItemId,
            bookingPickupLibraryId,
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
    --booking-space-sm: 0.25rem;   /* 4px */
    --booking-space-md: 0.5rem;    /* 8px */
    --booking-space-lg: 1rem;      /* 16px */
    --booking-space-xl: 1.5rem;    /* 24px */
    --booking-space-2xl: 2rem;     /* 32px */

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
    width: 100%;
    min-width: var(--booking-input-min-width);
    padding: calc(var(--booking-space-md) - var(--booking-space-xs)) calc(var(--booking-space-md) + var(--booking-space-sm));
    border: var(--booking-border-width) solid var(--booking-neutral-300);
    border-radius: var(--booking-border-radius-sm);
    font-size: var(--booking-text-base);
    transition: border-color var(--booking-transition-fast), box-shadow var(--booking-transition-fast);
}

/* Calendar Legend Component */
.calendar-legend {
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
/* External Library Integration */
.booking-modal-body .vs__selected {
    font-size: var(--vs-font-size);
    line-height: var(--vs-line-height);
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
    background-color: hsl(var(--booking-warning-hue), 100%, 70%, 0.2) !important;
}
</style>
