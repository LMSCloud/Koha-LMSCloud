import { $__ } from "../../../../i18n/index.js";

export function getMarkerTypeLabel(type) {
    const labels = {
        booked: $__("Booked"),
        "checked-out": $__("Checked out"),
        lead: $__("Lead period"),
        trail: $__("Trail period"),
        holiday: $__("Library closed"),
    };
    return labels[type] || type;
}
