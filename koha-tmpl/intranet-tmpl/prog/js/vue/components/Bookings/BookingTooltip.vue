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

<script setup>
import { defineProps } from "vue";
import { $__ } from "../../i18n";

defineProps({
    markers: {
        type: Array,
        required: true,
    },
    x: {
        type: Number,
        required: true,
    },
    y: {
        type: Number,
        required: true,
    },
    visible: {
        type: Boolean,
        required: true,
    },
});

function getMarkerTypeLabel(type) {
    const labels = {
        "booked": $__("Booked"),
        "checked-out": $__("Checked out"),
        "lead": $__("Lead period"),
        "trail": $__("Trail period")
    };
    return labels[type] || type;
}
</script>

<style scoped>
.booking-tooltip {
    background: #fffbe8;
    color: #333;
    border: 1px solid #ccc;
    border-radius: 4px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
    padding: 6px 10px;
    font-size: 13px;
    pointer-events: none;
}
.booking-marker-dot {
    display: inline-block;
    width: 5px;
    height: 5px;
    border-radius: 50%;
    margin: 0 1px 0 0;
    vertical-align: middle;
}
.booking-marker-dot--booked {
    background: #ffc107;
}
.booking-marker-dot--checked-out {
    background: #dc3545;
}
</style>
