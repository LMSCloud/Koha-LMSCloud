export * from "./islands";
import { hydrate as hydrateIslands, IslandStoreDefinitions } from "./islands";

// The OPAC registry is empty here: the self-renewal island is 26.06 only, and
// the booking island registers once its OPAC props are re-grafted.
const storeDefinitions: IslandStoreDefinitions = {};

/**
 * Hydrate the OPAC islands with the stores they declare.
 */
export function hydrate(): void {
    hydrateIslands(storeDefinitions);
}

if (parseInt(document?.currentScript?.getAttribute("init") ?? "0", 10)) {
    hydrate();
}
