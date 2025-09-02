<template>
    <Teleport to="body">
        <div
            v-if="visible"
            class="booking-tooltip"
            :style="{
                position: 'absolute',
                zIndex: 2147483647,
                whiteSpace: 'nowrap',
                top: `${y}px`,
                left: `${x}px`,
            }"
            role="tooltip"
        >
            <div
                v-for="marker in markers"
                :key="
                    marker.type +
                    (marker.barcode || marker.external_id || marker.itemnumber)
                "
            >
                <span
                    :class="[
                        'booking-marker-dot',
                        `booking-marker-dot--${marker.type}`,
                    ]"
                />
                {{ getMarkerTypeLabel(marker.type) }} ({{ $__("Barcode") }}:
                {{ marker.barcode || marker.external_id || "N/A" }})
            </div>
        </div>
    </Teleport>
</template>

<script setup lang="ts">
import { defineProps, withDefaults } from "vue";
import { $__ } from "../../i18n";
import { getMarkerTypeLabel } from "./lib/ui/markerLabels.mjs";

type Marker = {
    type: string;
    barcode?: string;
    external_id?: string;
    itemnumber?: string;
};

withDefaults(
    defineProps<{
        markers: Marker[];
        x: number;
        y: number;
        visible: boolean;
    }>(),
    {
        markers: () => [],
        x: 0,
        y: 0,
        visible: false,
    }
);

// getMarkerTypeLabel provided by shared UI helper
</script>

<style scoped>
.booking-tooltip {
    background: hsl(var(--booking-warning-hue), 100%, 95%);
    color: hsl(var(--booking-neutral-hue), 20%, 20%);
    border: var(--booking-border-width) solid hsl(var(--booking-neutral-hue), 15%, 75%);
    border-radius: var(--booking-border-radius-md);
    box-shadow: 0 0.125rem 0.5rem hsla(var(--booking-neutral-hue), 10%, 0%, 0.08);
    padding: calc(var(--booking-space-xs) * 3) calc(var(--booking-space-xs) * 5);
    font-size: var(--booking-text-lg);
    pointer-events: none;
}

.booking-marker-dot {
    display: inline-block;
    width: calc(var(--booking-marker-size) * 1.25);
    height: calc(var(--booking-marker-size) * 1.25);
    border-radius: var(--booking-border-radius-full);
    margin: 0 var(--booking-space-xs) 0 0;
    vertical-align: middle;
}

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
</style>
