<template>
    <fieldset class="step-block">
        <legend class="step-header">
            {{ stepNumber }}.
            {{ $__("Select Booking Period") }}
        </legend>

        <div class="form-group">
            <label for="booking_period">{{ $__("Booking period") }}</label>
            <div class="booking-date-picker">
                <flat-pickr
                    ref="flatpickrRef"
                    model-value=""
                    class="booking-flatpickr-input form-control"
                    :config="flatpickrConfig"
                    @on-change="onFlatpickrChange"
                />
                <div class="booking-date-picker-append">
                    <button
                        type="button"
                        class="btn btn-outline-secondary"
                        :disabled="!hasSelectedDates"
                        @click="clearDateRange"
                        :title="$__('Clear selected dates')"
                    >
                        <i class="fa fa-times" aria-hidden="true"></i>
                        <span class="sr-only">{{
                            $__("Clear selected dates")
                        }}</span>
                    </button>
                </div>
            </div>
        </div>

        <div
            v-if="dateRangeConstraint"
            class="alert alert-info booking-constraint-info"
        >
            <small>
                <strong>{{ $__("Booking constraint active:") }}</strong>
                {{ constraintHelpText }}
            </small>
        </div>

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
</template>

<script>
import { computed, onUnmounted, ref } from "vue";
import flatPickr from "vue-flatpickr-component";
import { $__ } from "../../i18n";

export default {
    name: "BookingPeriodStep",
    components: {
        flatPickr,
    },
    props: {
        stepNumber: {
            type: Number,
            required: true,
        },
        flatpickrConfig: {
            type: Object,
            required: true,
        },
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
        hasSelectedDates: {
            type: Boolean,
            default: false,
        },
    },
    emits: ["clear-dates"],
    setup(props, { emit }) {
        const flatpickrRef = ref(null);

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

        const clearDateRange = () => {
            // Clear flatpickr directly since we're not using v-model
            if (flatpickrRef.value?.fp) {
                flatpickrRef.value.fp.clear();
            }
            emit("clear-dates");
        };

        const onFlatpickrChange = (selectedDates, dateStr) => {
            // This is handled by the flatpickr config onChange in BookingModal
        };

        // Cleanup event listeners when component is unmounted
        onUnmounted(() => {
            if (flatpickrRef.value?.fp) {
                flatpickrRef.value.fp.destroy();
            }
        });

        return {
            clearDateRange,
            flatpickrRef,
            onFlatpickrChange,
            constraintHelpText,
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
