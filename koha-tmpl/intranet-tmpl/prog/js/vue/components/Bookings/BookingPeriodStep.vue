<template>
    <fieldset class="step-block">
        <legend class="step-header">
            {{ stepNumber }}.
            {{ $__("Select Booking Period") }}
        </legend>

        <!-- Date Picker -->
        <div class="form-group">
            <label for="booking_period">{{
                $__("Booking period")
            }}</label>
            <div class="booking-date-picker">
                <flat-pickr
                    v-model="selectedDateRange"
                    class="booking-flatpickr-input form-control"
                    :config="flatpickrConfig"
                />
                <div class="booking-date-picker-append">
                    <button
                        type="button"
                        class="btn btn-outline-secondary"
                        :disabled="!selectedDateRange || selectedDateRange.length === 0"
                        @click="clearDateRange"
                        :title="$__('Clear selected dates')"
                    >
                        <i class="fa fa-times" aria-hidden="true"></i>
                        <span class="sr-only">{{ $__("Clear selected dates") }}</span>
                    </button>
                </div>
            </div>
        </div>

        <!-- Constraint Information -->
        <div
            v-if="dateRangeConstraint && maxBookingPeriod"
            class="alert alert-info booking-constraint-info"
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
                        : dateRangeConstraint === "issuelength_with_renewals"
                        ? $__(
                              "Booking period limited to issue length with renewals (%s days)"
                          ).format(maxBookingPeriod)
                        : $__(
                              "Booking period limited by circulation rules (%s days)"
                          ).format(maxBookingPeriod)
                }}
            </small>
        </div>

        <!-- Calendar Legend -->
        <div class="calendar-legend">
            <span class="booking-marker-dot booking-marker-dot--booked"></span>
            {{ $__("Booked") }}
            <span class="booking-marker-dot booking-marker-dot--lead ml-3"></span>
            {{ $__("Lead Period") }}
            <span class="booking-marker-dot booking-marker-dot--trail ml-3"></span>
            {{ $__("Trail Period") }}
            <span class="booking-marker-dot booking-marker-dot--checked-out ml-3"></span>
            {{ $__("Checked Out") }}
            <span
                v-if="
                    dateRangeConstraint &&
                    selectedDateRange &&
                    selectedDateRange.length === 1
                "
                class="booking-marker-dot ml-3"
                style="background-color: #28a745"
            ></span>
            <span
                v-if="
                    dateRangeConstraint &&
                    selectedDateRange &&
                    selectedDateRange.length === 1
                "
                class="ml-1"
            >
                {{ $__("Required end date") }}
            </span>
        </div>

        <!-- Error Message -->
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
        modelValue: {
            type: Array,
            default: () => [],
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
    },
    emits: ["update:modelValue", "clear-dates"],
    setup(props, { emit }) {
        const flatpickrRef = ref(null);

        const selectedDateRange = computed({
            get: () => props.modelValue,
            set: (value) => {
                emit("update:modelValue", value);
            },
        });

        const clearDateRange = () => {
            selectedDateRange.value = [];
            emit("clear-dates");
        };

        // Cleanup event listeners when component is unmounted
        onUnmounted(() => {
            if (flatpickrRef.value?.fp) {
                flatpickrRef.value.fp.destroy();
            }
        });

        return {
            selectedDateRange,
            clearDateRange,
            flatpickrRef,
            $__,
        };
    },
};
</script>

<style scoped>
.step-block {
    margin-bottom: 1rem;
}

.step-header {
    font-weight: 600;
    font-size: 1.1rem;
    margin-bottom: 0.75rem;
    color: #495057;
}

.form-group {
    margin-bottom: 1rem;
}

.booking-date-picker {
    display: flex;
    align-items: center;
}

.booking-flatpickr-input {
    flex: 1;
    margin-right: 0.5rem;
}

.booking-date-picker-append {
    flex-shrink: 0;
}

.booking-constraint-info {
    margin-top: 0.5rem;
    margin-bottom: 1rem;
}

.calendar-legend {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.875rem;
    margin-top: 1rem;
}

.booking-marker-dot {
    display: inline-block;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    margin-right: 0.25rem;
}

.booking-marker-dot--booked {
    background-color: #dc3545;
}

.booking-marker-dot--lead {
    background-color: #ffc107;
}

.booking-marker-dot--trail {
    background-color: #fd7e14;
}

.booking-marker-dot--checked-out {
    background-color: #6f42c1;
}

.alert {
    padding: 0.75rem 1rem;
    border: 1px solid transparent;
    border-radius: 0.25rem;
}

.alert-info {
    color: #0c5460;
    background-color: #d1ecf1;
    border-color: #bee5eb;
}

.alert-danger {
    color: #721c24;
    background-color: #f8d7da;
    border-color: #f5c6cb;
}
</style>