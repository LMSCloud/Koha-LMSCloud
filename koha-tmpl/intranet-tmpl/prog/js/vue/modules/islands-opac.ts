export * from "./islands";
import {
    hydrate as hydrateIslands,
    registerIsland,
    IslandStoreDefinitions,
    WebComponentDynamicImport,
} from "./islands";
import { useBookingStore } from "../stores/bookings";

/**
 * The islands available in the OPAC.
 *
 * The self-renewal island is 26.06 only, so bookings is the whole registry.
 * @type {Map<string, WebComponentDynamicImport>}
 */
const islands: Map<string, WebComponentDynamicImport> = new Map([
    [
        "booking-modal",
        {
            importFn: async () => {
                const module = await import(
                    /* webpackChunkName: "booking-modal" */
                    "../components/Bookings/BookingModal.vue"
                );
                return module.default;
            },
            config: {
                stores: ["bookingStore"],
            },
        },
    ],
]);

/**
 * The Pinia stores islands in the OPAC may request via config.stores.
 * @type {IslandStoreDefinitions}
 */
const storeDefinitions: IslandStoreDefinitions = {
    bookingStore: useBookingStore,
};

// Core islands take the same registration path as plugin islands.
islands.forEach((entry, name) => registerIsland(name, entry));

/**
 * Hydrate the OPAC islands with the stores they declare.
 */
export function hydrate(): void {
    hydrateIslands(storeDefinitions);
}

if (parseInt(document?.currentScript?.getAttribute("init") ?? "0", 10)) {
    hydrate();
}
