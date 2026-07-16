export * from "./islands";
import { hydrate, registerIsland, WebComponentDynamicImport } from "./islands";

/**
 * The islands available in the OPAC.
 * @type {Map<string, WebComponentDynamicImport>}
 */
// The OPAC self-renewal island is 26.06 only; the booking island registers
// here once its OPAC props are re-grafted
const islands: Map<string, WebComponentDynamicImport> = new Map();

// Core islands take the same registration path as plugin islands.
islands.forEach((entry, name) => registerIsland(name, entry));

if (parseInt(document?.currentScript?.getAttribute("init") ?? "0", 10)) {
    hydrate();
}
