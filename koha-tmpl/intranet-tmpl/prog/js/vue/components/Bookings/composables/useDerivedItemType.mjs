import { watch } from "vue";
import { idsEqual } from "../lib/booking/id-utils.mjs";

/**
 * Auto-derive item type: prefer a single constrained type; otherwise infer
 * from currently selected item.
 *
 * @param {import('../types/bookings').DerivedItemTypeOptions} options
 * @returns {import('vue').WatchStopHandle} Stop handle from Vue watch()
 */
export function useDerivedItemType(options) {
    const {
        bookingItemtypeId,
        bookingItemId,
        constrainedItemTypes,
        bookableItems,
    } = options;

    return watch(
        [
            constrainedItemTypes,
            () => bookingItemId.value,
            () => bookableItems.value,
        ],
        ([types, itemId, items]) => {
            if (
                !bookingItemtypeId.value &&
                Array.isArray(types) &&
                types.length === 1
            ) {
                bookingItemtypeId.value = types[0].item_type_id;
                return;
            }
            if (!bookingItemtypeId.value && itemId) {
                const item = (items || []).find(i =>
                    idsEqual(i.item_id, itemId)
                );
                if (item) {
                    bookingItemtypeId.value =
                        item.effective_item_type_id ||
                        item.item_type_id ||
                        null;
                }
            }
        },
        { immediate: true }
    );
}
