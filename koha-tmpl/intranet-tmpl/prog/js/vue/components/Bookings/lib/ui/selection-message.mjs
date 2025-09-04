import { idsEqual } from "../booking/id-utils.mjs";
import { $__ } from "../../../../i18n/index.js";

export function buildNoItemsAvailableMessage(
    pickupLocations,
    itemTypes,
    pickupLibraryId,
    itemtypeId
) {
    const selectionParts = [];
    if (pickupLibraryId) {
        const location = (pickupLocations || []).find(l =>
            idsEqual(l.library_id, pickupLibraryId)
        );
        selectionParts.push(
            $__("pickup location: %s").format(
                (location && location.name) || pickupLibraryId
            )
        );
    }
    if (itemtypeId) {
        const itemType = (itemTypes || []).find(t =>
            idsEqual(t.item_type_id, itemtypeId)
        );
        selectionParts.push(
            $__("item type: %s").format(
                (itemType && itemType.description) || itemtypeId
            )
        );
    }
    return $__(
        "No items are available for booking with the selected criteria (%s). Please adjust your selection."
    ).format(selectionParts.join(", "));
}
