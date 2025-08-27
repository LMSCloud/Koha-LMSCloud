<template>
    <fieldset v-if="visible" class="step-block">
        <legend class="step-header">
            {{ stepNumber }}.
            {{
                showItemDetailsSelects
                    ? $__("Select Pickup Location and Item Type or Item")
                    : showPickupLocationSelect
                    ? $__("Select Pickup Location")
                    : ""
            }}
        </legend>

        <div
            v-if="showPickupLocationSelect || showItemDetailsSelects"
            class="form-group"
        >
            <label for="pickup_library_id">{{
                $__("Pickup location")
            }}</label>
            <v-select
                v-model="selectedPickupLibraryId"
                :placeholder="
                    $__('Select a pickup location')
                "
                :options="constrainedPickupLocations"
                label="name"
                :reduce="l => l.library_id"
                :loading="loading.pickupLocations"
                :clearable="true"
                :disabled="!selectedPatron && patronRequired"
            >
                <template #no-options>
                    {{ $__("No pickup locations available.") }}
                </template>
                <template #spinner>
                    <span class="sr-only">{{ $__("Loading...") }}</span>
                </template>
            </v-select>
            <span
                v-if="constrainedFlags.pickupLocations && (showPickupLocationSelect || showItemDetailsSelects)"
                class="badge badge-warning ml-2"
            >
                {{ $__("Options updated") }}
                <span class="ml-1"
                    >({{
                        pickupLocationsTotal - pickupLocationsFilteredOut
                    }}/{{ pickupLocationsTotal }})</span
                >
            </span>
        </div>

        <div v-if="showItemDetailsSelects" class="form-group">
            <label for="booking_itemtype">{{
                $__("Item type")
            }}</label>
            <v-select
                v-model="selectedItemtypeId"
                :options="constrainedItemTypes"
                label="description"
                :reduce="t => t.item_type_id"
                :clearable="true"
                :disabled="!selectedPatron && patronRequired"
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

        <div v-if="showItemDetailsSelects" class="form-group">
            <label for="booking_item_id">{{
                $__("Item")
            }}</label>
            <v-select
                v-model="selectedItemId"
                :placeholder="
                    $__('Any item')
                "
                :options="constrainedBookableItems"
                label="external_id"
                :reduce="i => i.item_id"
                :clearable="true"
                :loading="loading.bookableItems"
                :disabled="!selectedPatron && patronRequired"
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
                        bookableItemsTotal - bookableItemsFilteredOut
                    }}/{{ bookableItemsTotal }})</span
                >
            </span>
        </div>
    </fieldset>
</template>

<script>
import { computed } from "vue";
import vSelect from "vue-select";
import { $__ } from "../../i18n";
import { useBookingStore } from "../../stores/bookingStore";
import { storeToRefs } from "pinia";

export default {
    name: "BookingDetailsStep",
    components: {
        vSelect,
    },
    props: {
        visible: {
            type: Boolean,
            default: true,
        },
        stepNumber: {
            type: Number,
            required: true,
        },
        showItemDetailsSelects: {
            type: Boolean,
            default: false,
        },
        showPickupLocationSelect: {
            type: Boolean,
            default: false,
        },
        selectedPatron: {
            type: Object,
            default: null,
        },
        patronRequired: {
            type: Boolean,
            default: false,
        },
        // v-model values
        pickupLibraryId: {
            type: String,
            default: null,
        },
        itemtypeId: {
            type: [Number, String],
            default: null,
        },
        itemId: {
            type: [Number, String],
            default: null,
        },
        // Options and constraints
        constrainedPickupLocations: {
            type: Array,
            default: () => [],
        },
        constrainedItemTypes: {
            type: Array,
            default: () => [],
        },
        constrainedBookableItems: {
            type: Array,
            default: () => [],
        },
        constrainedFlags: {
            type: Object,
            default: () => ({
                pickupLocations: false,
                itemTypes: false,
                bookableItems: false,
            }),
        },
        // Statistics for badges
        pickupLocationsTotal: {
            type: Number,
            default: 0,
        },
        pickupLocationsFilteredOut: {
            type: Number,
            default: 0,
        },
        bookableItemsTotal: {
            type: Number,
            default: 0,
        },
        bookableItemsFilteredOut: {
            type: Number,
            default: 0,
        },
    },
    emits: [
        "update:pickupLibraryId",
        "update:itemtypeId",
        "update:itemId"
    ],
    setup(props, { emit }) {
        const store = useBookingStore();
        const { loading } = storeToRefs(store);
        const selectedPickupLibraryId = computed({
            get: () => props.pickupLibraryId,
            set: (value) => {
                emit("update:pickupLibraryId", value);
            },
        });

        const selectedItemtypeId = computed({
            get: () => props.itemtypeId,
            set: (value) => {
                emit("update:itemtypeId", value);
            },
        });

        const selectedItemId = computed({
            get: () => props.itemId,
            set: (value) => {
                emit("update:itemId", value);
            },
        });

        return {
            selectedPickupLibraryId,
            selectedItemtypeId,
            selectedItemId,
            loading,
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

.badge {
    font-size: var(--booking-text-xs);
}

.badge-warning {
    background-color: var(--booking-warning-bg);
    color: var(--booking-neutral-600);
}
</style>
