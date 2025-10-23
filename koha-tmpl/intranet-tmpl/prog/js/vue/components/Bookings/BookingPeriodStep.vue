<template>
    <fieldset class="step-block">
        <legend class="step-header">
            {{ stepNumber }}.
            {{ $__("Select Booking Period") }}
        </legend>

        <div class="form-group">
            <label for="booking_period">{{ $__("Booking period") }}</label>
            <div class="booking-date-picker">
                <input
                    ref="inputEl"
                    id="booking_period"
                    type="text"
                    class="booking-flatpickr-input form-control"
                    :disabled="!calendarEnabled"
                    readonly
                />
                <div class="booking-date-picker-append">
                    <button
                        type="button"
                        class="btn btn-outline-secondary"
                        :disabled="!calendarEnabled"
                        :title="
                            $__('Clear selected dates')
                        "
                        @click="clearDateRange"
                    >
                        <i class="fa fa-times" aria-hidden="true"></i>
                        <span class="sr-only">{{
                            $__("Clear selected dates")
                        }}</span>
                    </button>
                </div>
            </div>
        </div>

        <KohaAlert
            v-if="
                dateRangeConstraint &&
                (maxBookingPeriod === null || maxBookingPeriod > 0)
            "
            variant="info"
            extra-class="booking-constraint-info"
        >
            <small>
                <strong>{{ $__("Booking constraint active:") }}</strong>
                {{ constraintHelpText }}
            </small>
        </KohaAlert>

        <div class="calendar-legend">
            <span class="booking-marker-dot booking-marker-dot--booked"></span>
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
                v-if="dateRangeConstraint && hasSelectedDates"
                class="booking-marker-dot ml-3"
                style="background-color: #28a745"
            ></span>
            <span v-if="dateRangeConstraint && hasSelectedDates" class="ml-1">
                {{ $__("Required end date") }}
            </span>
        </div>

        <div v-if="errorMessage" class="alert alert-danger mt-2">
            {{ errorMessage }}
        </div>
    </fieldset>
    <BookingTooltip
        :markers="tooltipMarkers"
        :x="tooltipX"
        :y="tooltipY"
        :visible="tooltipVisible"
    />
</template>

<script>
import { computed, ref, toRef, watch } from "vue";
import KohaAlert from "../KohaAlert.vue";
import { useFlatpickr } from "./composables/useFlatpickr.mjs";
import { useBookingStore } from "../../stores/bookingStore";
import { storeToRefs } from "pinia";
import { useAvailability } from "./composables/useAvailability.mjs";
import BookingTooltip from "./BookingTooltip.vue";
import { $__ } from "../../i18n";

export default {
    name: "BookingPeriodStep",
    components: { BookingTooltip, KohaAlert },
    props: {
        stepNumber: {
            type: Number,
            required: true,
        },
        calendarEnabled: { type: Boolean, default: true },
        // disable fn now computed in child
        constraintOptions: { type: Object, required: true },
        dateRangeConstraint: {
            type: String,
            default: null,
        },
        maxBookingPeriod: {
            type: Number,
            default: null,
        },
        errorMessage: {
            type: String,
            default: "",
        },
        setError: { type: Function, required: true },
        hasSelectedDates: {
            type: Boolean,
            default: false,
        },
    },
    emits: ["clear-dates"],
    setup(props, { emit }) {
        const store = useBookingStore();
        const {
            bookings,
            checkouts,
            bookableItems,
            bookingItemId,
            bookingId,
            selectedDateRange,
            circulationRules,
        } = storeToRefs(store);
        const inputEl = ref(null);

        const constraintHelpText = computed(() => {
            if (!props.dateRangeConstraint) return "";

            const baseMessages = {
                issuelength: props.maxBookingPeriod
                    ? $__(
                          "Booking period limited to issue length (%s days)"
                      ).format(props.maxBookingPeriod)
                    : $__("Booking period limited to issue length"),
                issuelength_with_renewals: props.maxBookingPeriod
                    ? $__(
                          "Booking period limited to issue length with renewals (%s days)"
                      ).format(props.maxBookingPeriod)
                    : $__(
                          "Booking period limited to issue length with renewals"
                      ),
                default: props.maxBookingPeriod
                    ? $__(
                          "Booking period limited by circulation rules (%s days)"
                      ).format(props.maxBookingPeriod)
                    : $__("Booking period limited by circulation rules"),
            };

            return (
                baseMessages[props.dateRangeConstraint] || baseMessages.default
            );
        });

        // Visible calendar range for on-demand markers
        const visibleRangeRef = ref({
            visibleStartDate: null,
            visibleEndDate: null,
        });

        // Merge constraint options with visible range for availability calc
        const availabilityOptionsRef = computed(() => ({
            ...(props.constraintOptions || {}),
            ...(visibleRangeRef.value || {}),
        }));

        const { availability, disableFnRef } = useAvailability(
            {
                bookings,
                checkouts,
                bookableItems,
                bookingItemId,
                bookingId,
                selectedDateRange,
                circulationRules,
            },
            availabilityOptionsRef
        );

        // Tooltip refs local to this component, used by the composable and rendered via BookingTooltip
        const tooltipMarkers = ref([]);
        const tooltipVisible = ref(false);
        const tooltipX = ref(0);
        const tooltipY = ref(0);

        const setErrorForFlatpickr = msg => props.setError(msg);

        const { clear } = useFlatpickr(inputEl, {
            store,
            disableFnRef,
            constraintOptionsRef: toRef(props, "constraintOptions"),
            setError: setErrorForFlatpickr,
            tooltipMarkersRef: tooltipMarkers,
            tooltipVisibleRef: tooltipVisible,
            tooltipXRef: tooltipX,
            tooltipYRef: tooltipY,
            visibleRangeRef,
        });

        // Push availability map (on-demand for current view) to store for markers
        watch(
            () => availability.value?.unavailableByDate,
            map => {
                try {
                    store.setUnavailableByDate(map ?? {});
                } catch (e) {
                    // ignore if store shape differs in some contexts
                }
            },
            { immediate: true }
        );

        const clearDateRange = () => {
            clear();
            emit("clear-dates");
        };

        return {
            clearDateRange,
            inputEl,
            constraintHelpText,
            tooltipMarkers,
            tooltipVisible,
            tooltipX,
            tooltipY,
        };
    },
};
</script>

<style scoped>
.step-block {
    margin-bottom: var(--booking-space-lg);
}

.step-header {
    font-weight: 600;
    font-size: var(--booking-text-lg);
    margin-bottom: calc(var(--booking-space-lg) * 0.75);
    color: var(--booking-neutral-600);
}

.form-group {
    margin-bottom: var(--booking-space-lg);
}

.booking-date-picker {
    display: flex;
    align-items: center;
}

.booking-flatpickr-input {
    flex: 1;
    margin-right: var(--booking-space-md);
}

.booking-date-picker-append {
    flex-shrink: 0;
}

.booking-constraint-info {
    margin-top: var(--booking-space-md);
    margin-bottom: var(--booking-space-lg);
}

.calendar-legend {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: var(--booking-space-md);
    font-size: var(--booking-text-sm);
    margin-top: var(--booking-space-lg);
}

.booking-marker-dot {
    display: inline-block;
    width: calc(var(--booking-marker-size) * 3);
    height: calc(var(--booking-marker-size) * 3);
    border-radius: var(--booking-border-radius-full);
    margin-right: var(--booking-space-sm);
    border: var(--booking-border-width) solid hsla(0, 0%, 0%, 0.15);
}

.booking-marker-dot--booked {
    background-color: var(--booking-warning-bg);
}

.booking-marker-dot--lead {
    background-color: hsl(var(--booking-info-hue), 60%, 85%);
}

.booking-marker-dot--trail {
    background-color: var(--booking-warning-bg);
}

.booking-marker-dot--checked-out {
    background-color: hsl(var(--booking-danger-hue), 60%, 85%);
}

.alert {
    padding: calc(var(--booking-space-lg) * 0.75) var(--booking-space-lg);
    border: var(--booking-border-width) solid transparent;
    border-radius: var(--booking-border-radius-sm);
}

.alert-info {
    color: hsl(var(--booking-info-hue), 80%, 20%);
    background-color: hsl(var(--booking-info-hue), 40%, 90%);
    border-color: hsl(var(--booking-info-hue), 40%, 70%);
}

.alert-danger {
    color: hsl(var(--booking-danger-hue), 80%, 20%);
    background-color: hsl(var(--booking-danger-hue), 40%, 90%);
    border-color: hsl(var(--booking-danger-hue), 40%, 70%);
}
</style>
