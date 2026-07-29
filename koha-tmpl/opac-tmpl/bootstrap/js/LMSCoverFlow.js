/**
 * @file LMSCoverFlow — an OPAC cover-flow / cover-grid widget for Koha.
 *
 * A single-file UMD module. Public surface (see the exports at the bottom):
 *   - createLcfInstance() -> an instance with setGlobals / setConfig / setData /
 *     setContainer / getConfig / render.
 *   - ShelfBrowser: wires the opac-detail shelf browser.
 *   - CoverflowByQuery: a query-driven, paged cover flow.
 *   - externalSources: an Observable used to coordinate external cover sources.
 *
 * Internals are encapsulated inside the UMD factory. The pure, DOM-agnostic
 * helpers are grouped at the top of the factory and re-exported under the
 * internal `_internals` key purely so they can be unit-tested (see
 * t/mocha/unit/LMSCoverFlow.internals.test.mjs); they are not a public API.
 */
(function (global, factory) {
    typeof exports === "object" && typeof module !== "undefined"
        ? factory(exports)
        : typeof define === "function" && define.amd
          ? define(["exports"], factory)
          : ((global =
                typeof globalThis !== "undefined"
                    ? globalThis
                    : global || self),
            factory((global.LMSCoverFlow = {})));
})(this, function (exports) {
    "use strict";

    /*
     * Pure, DOM-agnostic helpers, grouped up front. They stay inside the UMD
     * factory so they don't leak to the global scope when this file is loaded as
     * a classic <script>; they're exposed for direct unit testing only through the
     * internal `_internals` export at the bottom of this factory.
     */
    /**
     * Extract an lcf item id (the `_<7 digits>` class) from a rendered node.
     * @param {Element} domNode - node whose second class holds the generated id.
     * @returns {string} the id class.
     * @throws {Error} when the second class does not match `_<7 digits>`.
     */
    function getLcfItemId(domNode) {
        const id = domNode?.classList[1];
        if (!/_[0-9]{7}/.test(id)) throw new Error("Id doesn't match pattern.");
        return id;
    }

    /**
     * @param {Object} object
     * @returns {Array<[string, *]>} the object's own enumerable entries.
     */
    function arrFromObjEntries(object) {
        return Array.from(Object.entries(object));
    }

    /**
     * Build `data-*` attribute pairs from an item's `additionalProperties` map.
     * @param {{additionalProperties?: Object}} currentItem
     * @returns {Array<[string, *]>|undefined} `['data-<key>', value]` pairs, or
     *   undefined when the item carries no additionalProperties.
     */
    function additionalProperties(currentItem) {
        if (currentItem.additionalProperties) {
            const result = [];
            arrFromObjEntries(currentItem?.additionalProperties).forEach(
                property => {
                    const [key, value] = property;
                    result.push([`data-${key}`, value]);
                }
            );
            return result;
        }
        return undefined;
    }

    /**
     * Map each lcf* aspect class to the attribute/value instruction that
     * applyInstructions() consumes. Instruction shape varies per row
     * (see describeArgShape).
     * @param {Object} item - a formatted data item.
     * @returns {Map<string, *>} aspect class -> instruction.
     */
    function attributeInstructionsFor(item) {
        return new Map([
            ["lcfItemContainer", additionalProperties(item)],
            ["lcfAnchor", ["href", item.referenceToDetailsView]],
            ["lcfCoverImage", ["src", item?.coverurl.replaceAll("&amp;", "&")]],
            ["lcfMediaTitle", [["textContent", "data-text"], item.title]],
            ["lcfMediaAuthor", ["textContent", item.author]],
            ["lcfMediaItemCallNumber", ["textContent", item.itemCallNumber]],
            ["lcfMediaISBD", ["textContent", `${item.author}: ${item.title}`]],
        ]);
    }

    /**
     * Classify an instruction's shape so applyInstructions() can pick a branch.
     * @param {string|string[]} attribute
     * @param {*|*[]} data
     * @returns {[boolean, boolean]} whether attribute and data are arrays.
     */
    function describeArgShape(attribute, data) {
        return [Array.isArray(attribute), Array.isArray(data)];
    }
    /**
     * @param {string} lcfClass
     * @param {Map<string, *>} map
     * @returns {*} the instruction registered for the given aspect class.
     */
    function instructionsForClass(lcfClass, map) {
        return map.get(lcfClass);
    }
    /**
     * @param {string} attribute
     * @returns {boolean} true when the attribute is the special `textContent` sink.
     */
    function isTextContent(attribute) {
        return attribute === "textContent";
    }

    /**
     * Assign one value to a node, routing the special `textContent` sink to the
     * property and everything else to a real attribute.
     * @param {Element} node
     * @param {string} attr
     * @param {*} value
     * @returns {void}
     */
    function setAttrOrText(node, attr, value) {
        if (isTextContent(attr)) {
            node.textContent = value;
            return;
        }
        node.setAttribute(attr, value);
    }

    /**
     * Apply an attribute instruction to a DOM node, handling the four shapes
     * describeArgShape() distinguishes: paired attribute/value lists, several
     * attributes sharing one value, several values for one attribute, and the
     * scalar attribute/textContent case.
     * @param {Element} currentTag - node to mutate.
     * @param {[string|string[], *|*[]]} currentInstructions - [attribute, data].
     * @returns {void}
     */
    function applyInstructions(currentTag, currentInstructions) {
        const node = currentTag;
        const [attribute, data] = currentInstructions;
        const [attrIsList, dataIsList] = describeArgShape(attribute, data);
        // Both lists: currentInstructions is itself a list of [attr, value] pairs.
        if (attrIsList && dataIsList) {
            currentInstructions.forEach(([attr, value]) =>
                setAttrOrText(node, attr, value)
            );
            return;
        }
        // Several attributes share one value.
        if (attrIsList) {
            attribute.forEach(attr => setAttrOrText(node, attr, data));
            return;
        }
        // One attribute, several values (last write wins).
        if (dataIsList) {
            data.forEach(value => setAttrOrText(node, attribute, value));
            return;
        }
        // Scalar attribute/value (covers the textContent sink too).
        setAttrOrText(node, attribute, data);
    }

    /**
     * @param {*} p
     * @returns {boolean} true when `p` is thenable (a Promise-like object).
     */
    function isPromise(p) {
        if (typeof p === "object" && typeof p.then === "function") {
            return true;
        }
        return false;
    }

    /**
     * Resolve the cover images' shared height: the tallest image, capped at the
     * configured fallback height. Non-numeric entries are treated as 0.
     * @param {Array<number|string|null>} lcfCoverImageHeights
     * @param {{coverImageFallbackHeight: number}} config
     * @returns {number}
     */
    function processHeights(lcfCoverImageHeights, config) {
        const heights = lcfCoverImageHeights
            .map(height => height || 0)
            .map(height => (Number.isNaN(+height) ? "" : +height));
        const coverImagesMaximumHeight = Math.max(...heights);
        return coverImagesMaximumHeight <= config.coverImageFallbackHeight
            ? coverImagesMaximumHeight
            : config.coverImageFallbackHeight;
    }

    /**
     * Collect the `.value` of each entry of a settled-promise result set.
     * @param {Array<{value: *}>} resultsArray
     * @returns {Array<*>}
     */
    function flattenPromiseResults(resultsArray) {
        const flattenedResults = [];
        Object.keys(resultsArray).forEach(index => {
            flattenedResults.push(resultsArray[index].value);
        });
        return flattenedResults;
    }

    /**
     * Sum the card widths plus one inter-card gap per card (used for shelf-browser
     * left-scroll offset). Returns 0 on error.
     * @param {number[]} offsetWidthArray
     * @param {number} computedFontSize - the gap size, in px.
     * @returns {number}
     */
    function calculateCoverFlowPlusGaps(offsetWidthArray, computedFontSize) {
        try {
            return (
                offsetWidthArray.reduce(
                    (accumulator, currentValue) =>
                        accumulator + currentValue + computedFontSize
                ) + computedFontSize
            );
        } catch (error) {
            console.trace(
                `Looks like something went wrong in ${calculateCoverFlowPlusGaps.name} ->`,
                error
            );
            return 0;
        }
    }

    /**
     * @param {number} ms
     * @returns {Promise<void>} a promise resolving after `ms` milliseconds.
     */
    function resyncExecution(ms) {
        return new Promise(resolve => {
            setTimeout(resolve, ms);
        });
    }

    /**
     * Generate a random lcf item id of the form `_<7 digits>` (see getLcfItemId).
     * @returns {string}
     */
    function generateId() {
        const randomValues = new Uint8Array(16);
        return `_${window.crypto
            .getRandomValues(randomValues)
            .join("")
            .toString()
            .substring(2, 9)}`;
    }

    /**
     * Whether the shelf browser should be scrolled into view for this render.
     * Only on the initial shelf open — never when extending with newly-loaded
     * nearby items, which would otherwise jump the (now taller) page on paging.
     * @param {{shelfBrowserScrollIntoView?: boolean, shelfBrowserExtendedCoverFlow?: boolean}} config
     * @returns {boolean}
     */
    function shouldScrollShelfBrowserIntoView(config) {
        return (
            !!config.shelfBrowserScrollIntoView &&
            !config.shelfBrowserExtendedCoverFlow
        );
    }

    /* eslint-disable max-len */
    /**
     * Build the request URI for the "nearby items" (shelf browser) endpoint.
     * @param {{endpoint?: string, itemnumber: (number|string), quantity: (number|string)}} params
     * @returns {string}
     */
    function nearbyItemsRequestURI({ endpoint, itemnumber, quantity }) {
        return `${endpoint || "/api/v1/public/coverflow_data_nearby_items/"}${itemnumber}?quantity=${quantity}`;
    }

    /**
     * Build the request URI for the generated-cover endpoint.
     * @param {{endpoint?: string, title?: string, author?: string}} params
     * @returns {string}
     */
    function generatedCoverRequestURI({ endpoint, title, author }) {
        return `${endpoint || "/api/v1/public/generated_cover"}${title ? `?title=${window.encodeURIComponent(title)}` : ""}${author ? `&author=${window.encodeURIComponent(author)}` : ""}`;
    }

    /**
     * Build the request URI for the coverflow-by-query endpoint.
     * @param {{endpoint?: string, query: string, offset: (number|string), maxcount: (number|string)}} params
     * @returns {string}
     */
    function byQueryRequestURI({ endpoint, query, offset, maxcount }) {
        return `${endpoint || "/api/v1/public/coverflow_data_query"}?query=${query}&offset=${offset}&maxcount=${maxcount}`;
    }
    /* eslint-enable max-len */

    /**
     * Feature-detect whether the browser's DOMParser can parse `text/html`.
     * @returns {boolean}
     */
    function domParserSupport() {
        if (!window.DOMParser) return false;
        const domParser = new DOMParser();
        try {
            domParser.parseFromString("x", "text/html");
        } catch (error) {
            return false;
        }
        return true;
    }
    /**
     * Parse an HTML string into a detached DOM container, collapsing whitespace
     * between tags first. Uses DOMParser when available, else an innerHTML div.
     * @param {string} coverhtml
     * @returns {HTMLElement} the parsed container (a <body> or a <div>).
     */
    function stringToHtml(coverhtml) {
        const sanitizedCoverhtml = coverhtml.replace(/>\s+|\s+</g, m =>
            m.trim()
        );
        if (domParserSupport()) {
            const domParser = new DOMParser();
            const parsedHtml = domParser.parseFromString(
                sanitizedCoverhtml,
                "text/html"
            );
            return parsedHtml.body;
        }
        const generatedDom = document.createElement("div");
        generatedDom.innerHTML = sanitizedCoverhtml;
        return generatedDom;
    }
    /**
     * Descend the first-child chain of the seed node, pushing each first child
     * onto the array, until an element with no element children is reached.
     * @param {(Node[]|NodeList)} arrayOfDomNodes - seed whose [0] is the current node.
     * @returns {Node} the deepest first-child leaf.
     */
    function recursiveArrayPopulation(arrayOfDomNodes) {
        if (arrayOfDomNodes[0].childElementCount === 0) {
            return arrayOfDomNodes[0];
        }
        arrayOfDomNodes.push(arrayOfDomNodes[0].firstChild);
        return recursiveArrayPopulation(arrayOfDomNodes[0].childNodes);
    }
    /**
     * Remove every element child from a node.
     * @param {Element} parent
     * @returns {Element} the same node, emptied of element children.
     */
    function removeChildNodes(parent) {
        while (parent.firstElementChild) {
            parent.removeChild(parent.lastElementChild);
        }
        return parent;
    }

    /**
     * Singleton tracking whether the shelf-browser scroll listeners are attached
     * for each edge, plus the handler references so they can be removed later.
     * `data` = { left, right, leftHandler, rightHandler }.
     */
    class EventListeners {
        static instance;
        data;
        constructor() {
            if (!EventListeners.instance) {
                this.data = {
                    left: false,
                    right: false,
                    leftHandler: null,
                    rightHandler: null,
                };
                EventListeners.instance = this;
            }
            // return EventListeners.instance;
        }
        /** Mark the left-edge scroll listener as attached. */
        setLeftToTrue() {
            this.data.left = true;
        }
        /** Mark the left-edge scroll listener as detached. */
        setLeftToFalse() {
            this.data.left = false;
        }
        /** Mark the right-edge scroll listener as attached. */
        setRightToTrue() {
            this.data.right = true;
        }
        /** Mark the right-edge scroll listener as detached. */
        setRightToFalse() {
            this.data.right = false;
        }
        /**
         * Store the scroll handler reference for one edge.
         * @param {Function} handler
         * @param {'left'|'right'} direction
         */
        setHandler(handler, direction) {
            if (direction === "left") {
                this.data.leftHandler = handler;
            } else {
                this.data.rightHandler = handler;
            }
        }
        /** @returns {{left:boolean,right:boolean,leftHandler:?Function,rightHandler:?Function}} */
        get() {
            return this.data;
        }
        /** @returns {boolean} whether the left-edge listener is attached. */
        getLeft() {
            return this.data.left;
        }
        /** @returns {boolean} whether the right-edge listener is attached. */
        getRight() {
            return this.data.right;
        }
    }

    const instance = new EventListeners();
    Object.freeze(instance);

    /**
     * Create (or replace) the shared `<style id="lcfStyle">` tag in <head>,
     * scoped to this container via its reference class. Rules are added later
     * through addGlobalStyle().
     * @param {Container} container
     * @returns {void}
     */
    function createStyleTag(container) {
        const lcfStyleReference = document.querySelector(
            `#lcfStyle.${container.referenceAsClass}`
        );
        if (lcfStyleReference) {
            lcfStyleReference.remove();
            const lcfStyle = document.createElement("style");
            lcfStyle.textContent =
                "👋 Styles injected by LMSCoverFlow are obtainable through logging out lcfStyle.sheet";
            lcfStyle.id = "lcfStyle";
            lcfStyle.classList.add(container.referenceAsClass);
            document.head.appendChild(lcfStyle);
        }
        if (!lcfStyleReference) {
            const lcfStyle = document.createElement("style");
            lcfStyle.textContent =
                "👋 Styles injected by LMSCoverFlow are obtainable through logging out lcfStyle.sheet";
            lcfStyle.id = "lcfStyle";
            lcfStyle.classList.add(container.referenceAsClass);
            document.head.appendChild(lcfStyle);
        }
    }

    /**
     * Insert a CSS rule into this container's own `<style id="lcfStyle">` tag,
     * matched by its reference class. (Using getElementById here would always
     * return the first such tag, so concurrently-rendered instances piled all
     * their rules into one sheet and left the others empty.) Plain class/element
     * selectors are scoped to this instance by appending `.<coverFlowId>`; id,
     * :root, @-rules and attribute selectors are inserted verbatim.
     * @param {string} selector
     * @param {string} newStyle - the rule body (declarations).
     * @param {Container} container
     * @returns {void}
     */
    function addGlobalStyle(selector, newStyle, container) {
        const lcfStyle = document.querySelector(
            `#lcfStyle.${container.referenceAsClass}`
        );
        if (selector.includes("#") || selector.includes(":root")) {
            const compositedStyle = `${selector} {${newStyle}}`;
            lcfStyle.sheet.insertRule(compositedStyle);
        } else {
            const compositedStyle =
                selector.includes("@") || selector.startsWith("[")
                    ? `${selector} {${newStyle}}`
                    : `${selector}.${container.coverFlowId} {${newStyle}}`;
            lcfStyle.sheet.insertRule(compositedStyle);
        }
    }

    /**
     * Inject the base per-instance styles: the `.text-custom-*` font-size scale
     * and, when enabled, the cover tooltip overlay rules.
     * @param {Config} config
     * @param {Container} container
     * @returns {void}
     */
    function setGlobalStyles(config, container) {
        let globalStyles = [
            [".text-custom-4", "font-size: .25rem;"],
            [".text-custom-8", "font-size: .5rem;"],
            [".text-custom-12", "font-size: .75rem;"],
            [".text-custom-16", "font-size: 1rem;"],
            [".text-custom-20", "font-size: 1.25rem;"],
            [".text-custom-24", "font-size: 1.5rem;"],
            [".text-custom-28", "font-size: 1.75rem;"],
            [".text-custom-32", "font-size: 2rem;"],
        ];
        if (config.coverFlowTooltips) {
            globalStyles = globalStyles.concat([
                ["[data-tooltip]", "position: relative;"],
                [
                    "[data-tooltip]:hover::before",
                    `
            display: -webkit-box;
            display: -ms-flexbox;
            display: flex;
            -webkit-box-pack: center;
            -ms-flex-pack: center;
            justify-content: center;
            -webkit-box-align: center;
            -ms-flex-align: center;
            align-items: center;
            text-align: center;
            content: attr(data-tooltip);
            position: absolute;
            width: calc(100% - 1px);
            height: calc(${config.coverImageFallbackHeight}px + 1px);
            background-color: rgba(0,0,0,0.3);
            padding: .5rem;
            color: white;
            top: 0;
            left: 50%;
            -webkit-transform: translate(-50%, 0%);
            -ms-transform: translate(-50%, 0%);
            transform: translate(-50%, 0%);
                      `,
                ],
            ]);
        }
        globalStyles.forEach(style => {
            addGlobalStyle(style[0], style[1], container);
        });
    }

    /**
     * Inject the loading-spinner styles and its `spin` keyframes.
     * @param {Config} config
     * @param {Container} container
     * @returns {void}
     */
    function setLoadingAnimation(config, container) {
        const LOADING_ANIMATION = [
            [
                ".lcfLoadingAnimation",
                `
            border: 16px solid transparent;
            border-top: 16px solid #0275d8;
            border-bottom: 16px solid #eee;
            border-radius: 50%;
            height: ${config.coverImageFallbackHeight}px;
            width: ${config.coverImageFallbackHeight}px;
            margin: auto;
            -webkit-animation: spin 3s linear infinite;
            animation: spin 3s linear infinite;
            `,
            ],
            [
                "@-webkit-keyframes spin",
                `
            0% { -webkit-transform: rotate(0deg); transform: rotate(0deg); }
            100% { -webkit-transform: rotate(360deg); transform: rotate(360deg); }
            `,
            ],
            [
                "@keyframes spin",
                `
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
            `,
            ],
        ];
        LOADING_ANIMATION.forEach(style => {
            addGlobalStyle(style[0], style[1], container);
        });
    }

    /**
     * Inject the 3D flip-card styles (perspective, back face, flip button and
     * the `popup` keyframes) used when coverFlowFlippableCards is on.
     * @param {Container} container
     * @returns {void}
     */
    function setFlipCards(container) {
        const FLIP_CARDS = [
            [
                ".flipCard",
                `
                -webkit-perspective: 1000px;
                perspective: 1000px;
                `,
            ],
            [
                ".flipCardInner",
                `
                position: relative;
                -webkit-transition: -webkit-transform .7s;
                transition: -webkit-transform .7s;
                -o-transition: transform .7s;
                transition: transform .7s;
                transition: transform .7s, -webkit-transform .7s;
                -webkit-transform-style: preserve-3d;
                transform-style: preserve-3d;
                `,
            ],
            [
                ".flipCardFront, .flipCardBack",
                `
                -webkit-backface-visibility: hidden;
                backface-visibility: hidden;
                `,
            ],
            [
                ".flipCardBack",
                `
                position: absolute;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                color: white;
                background: #6610f2;
                padding: 1rem;
                text-align: center;
                border-radius: .25rem;
                -webkit-transform: rotateY(180deg);
                transform: rotateY(180deg);
                `,
            ],
            [
                ".cardIsFlipped",
                `
                -webkit-transform: rotateY(-180deg);
                transform: rotateY(-180deg);
                -webkit-transition: -webkit-transform .4s;
                transition: -webkit-transform .4s;
                -o-transition: transform .4s;
                transition: transform .4s;
                transition: transform .4s, -webkit-transform .4s;
                `,
            ],
            [
                ".buttonIsFlipped",
                `
                -webkit-transform: rotate(180deg);
                -ms-transform: rotate(180deg);
                transform: rotate(180deg);
                -webkit-transition: -webkit-transform .4s;
                transition: -webkit-transform .4s;
                -o-transition: transform .4s;
                transition: transform .4s;
                transition: transform .4s, -webkit-transform .4s;
                `,
            ],
            [
                ".lcfFlipCardButton",
                `
                position: absolute;
                top: 1rem;
                right: 1rem;
                border: 1px solid white;
                background: #fff;
                color: #343a40;
                border-radius: 50%;
                width: 0;
                height: 0;
                font-size: 0;
                visibility: hidden;
                `,
            ],
            [
                ".flipCard:hover .lcfFlipCardButton",
                `
                -webkit-animation: popup .1s linear 1 forwards;
                animation: popup .1s linear 1 forwards;
                `,
            ],
            [
                "@-webkit-keyframes popup",
                `
                0% {width: 0; height: 0;}
                100% {width: 2rem; height: 2rem; font-size: medium; visibility: visible;}

                `,
            ],
            [
                "@keyframes popup",
                `
                0% {width: 0; height: 0;}
                100% {width: 2rem; height: 2rem; font-size: medium; visibility: visible;}
                `,
            ],
        ];
        /** Here we apply the flipCard logic to our dom-structure. */
        FLIP_CARDS.forEach(style => {
            addGlobalStyle(style[0], style[1], container);
        });
    }

    /**
     * Inject the default hover effect: raise the card with a drop shadow.
     * @param {Container} container
     * @returns {void}
     */
    function setRaiseShadowOnHover(container) {
        const RAISE_SHADOW_ONHOVER = [
            [
                ".lcfFlipCard:hover",
                `
              -webkit-box-shadow: 0px 5px 15px 3px rgba(0,0,0,0.1);
              box-shadow: 0px 5px 15px 3px rgba(0,0,0,0.1);
              position: relative;
              top: -3px;
              `,
            ],
        ];
        RAISE_SHADOW_ONHOVER.forEach(style => {
            addGlobalStyle(style[0], style[1], container);
        });
    }

    /**
     * Inject the `coloredFrame` hover effect: outline the card on hover.
     * @param {Container} container
     * @returns {void}
     */
    function setHighlightOnHover(container) {
        const HIGHLIGHT_ONHOVER = [
            [
                ".lcfFlipCard:hover",
                `
                outline: 1px solid #6610f2 !important;
                `,
            ],
        ];
        HIGHLIGHT_ONHOVER.forEach(style => {
            addGlobalStyle(style[0], style[1], container);
        });
    }

    /**
     * Describes one DOM "aspect" (node) to build: its tag, its identifying
     * reference class, the parent it attaches under, and any extra classes.
     */
    class LcfItemWrapper {
        tag;
        reference;
        parent;
        additionalClasses;
        /**
         * @param {(string|Element)} tag - tag name to create, or an existing node
         *   to reuse (shelf-browser path).
         * @param {string} reference - the aspect's identifying class (e.g. 'lcfAnchor').
         * @param {(string|Element)} parent - parent aspect's reference class, or the
         *   container's root element.
         * @param {string[]} additionalClasses - extra classes to add to the node.
         */
        constructor(tag, reference, parent, additionalClasses) {
            this.tag = tag;
            this.reference = reference;
            this.parent = parent;
            this.additionalClasses = additionalClasses;
        }
    }

    /**
     * Set the inline `style` attribute on the single element matching
     * `.<selector>.<coverFlowId>`.
     * @param {string} selector - class name(s) without the leading dot.
     * @param {string} newStyle
     * @param {Container} container
     * @returns {void}
     */
    function addInlineStyle(selector, newStyle, container) {
        const targetElement = document.querySelector(
            `.${selector}.${container.coverFlowId}`
        );
        targetElement.setAttribute("style", newStyle);
    }

    /**
     * Attach a freshly built aspect node to the DOM. Nested aspects go under the
     * parent element matched by their domId; top-level items append to the
     * container — except shelf-browser inserts, which position relative to the
     * right nav button, or to the item at currentIndex for left inserts.
     * @param {{lcfItem: Element, aspect: LcfItemWrapper, domId: string}} newTagWithClasses
     * @param {Container} container
     * @param {?('left'|'right')} [buttonDirection] - set during shelf-browser extension.
     * @param {number} [currentIndex] - insert position for left-direction inserts.
     * @returns {void}
     */
    function appendToDom(
        newTagWithClasses,
        // eslint-disable-next-line max-len
        container,
        buttonDirection,
        currentIndex
    ) {
        /* If the aspect.parent references the main container (lmscoverflow), it appends the
          current item to that handle. Otherwise it looks up the parent in the LcfItemWrapperClass
          (matched by the item's domId) and appends to it; currentIndex only positions
          shelf-browser left-inserts. */
        const lcfNavigationButtonRight = document.querySelector(
            `.lcfNavigationButtonRight.${container.coverFlowId}`
        );
        const lcfItemContainers = document.querySelectorAll(
            `.lcfItemContainer.${container.coverFlowId}`
        );
        /** If the new tag gets created in the shelfbrowser context, the element needs
         * to be inserted into the dom depending on the button direction that triggered
         * the loading of new titles. The new content gets inserted before the previously
         * rendered content if the left button is pressed and at the end of the container
         * if the right is pressed.
         */
        if (newTagWithClasses.aspect.parent !== container.reference) {
            const parentReference = document.querySelector(
                `.${newTagWithClasses.aspect.parent}.${newTagWithClasses.domId}`
            );
            parentReference.appendChild(newTagWithClasses.lcfItem);
        } else if (
            newTagWithClasses.aspect.parent === container.reference &&
            buttonDirection
        ) {
            if (buttonDirection === "right") {
                container.reference.insertBefore(
                    newTagWithClasses.lcfItem,
                    lcfNavigationButtonRight
                );
            } else {
                container.reference.insertBefore(
                    newTagWithClasses.lcfItem,
                    lcfItemContainers[0 + currentIndex]
                );
            }
        } else {
            newTagWithClasses.aspect.parent.appendChild(
                newTagWithClasses.lcfItem
            );
        }
    }

    /**
     * Wire the scroll-on-press handler and an arrow icon onto a navigation
     * button aspect (with an accessible label).
     * @param {{lcfItem: Element}} newTagWithClasses
     * @param {'left'|'right'} direction
     * @param {Container} container
     * @returns {object} the same newTagWithClasses, mutated in place.
     */
    function createNavigationButton(newTagWithClasses, direction, container) {
        const CONTAINER = container;
        const NEW_TAG_WITH_CLASSES = newTagWithClasses;
        const scrollContainerToRight = () => {
            CONTAINER.reference.scrollLeft -= 10;
            CONTAINER.reference.scrollLeft +=
                CONTAINER.reference.clientWidth / 1.5;
        };
        const scrollContainerToLeft = () => {
            CONTAINER.reference.scrollLeft += 10;
            CONTAINER.reference.scrollLeft -=
                CONTAINER.reference.clientWidth / 1.5;
        };
        if (direction === "left") {
            NEW_TAG_WITH_CLASSES.lcfItem.onmousedown = scrollContainerToLeft;
        } else {
            NEW_TAG_WITH_CLASSES.lcfItem.onmousedown = scrollContainerToRight;
        }
        /* Render the arrow as a decorative Font Awesome icon; keep an accessible name on the
           button since it no longer has text content. */
        const icon = document.createElement("i");
        icon.className =
            direction === "left" ? "fa fa-arrow-left" : "fa fa-arrow-right";
        icon.setAttribute("aria-hidden", "true");
        NEW_TAG_WITH_CLASSES.lcfItem.setAttribute(
            "aria-label",
            direction === "left" ? "←" : "→"
        );
        NEW_TAG_WITH_CLASSES.lcfItem.appendChild(icon);
        return NEW_TAG_WITH_CLASSES;
    }

    /**
     * Build (or reuse) an aspect's DOM node and tag it with its reference class,
     * its domId class, and any additional classes.
     * @param {LcfItemWrapper} aspect
     * @param {string} domId - the item's generated id, or a sentinel ('lcfLoading'/'lcfNavigation').
     * @param {string} [textContent]
     * @param {boolean} [shelfBrowserItem=false] - reuse aspect.tag as the node instead of creating one.
     * @returns {{lcfItem: Element, aspect: LcfItemWrapper, domId: string}}
     */
    function createTagAndSetClasses(
        aspect,
        domId,
        textContent,
        shelfBrowserItem = false
    ) {
        let lcfItem;
        if (shelfBrowserItem === true) {
            lcfItem = aspect.tag;
        } else {
            lcfItem = document.createElement(aspect.tag);
        }
        lcfItem.classList.add(aspect.reference);
        lcfItem.classList.add(domId);
        /* Adds the reference and the domId as classNames to lcfItem. */
        if (aspect.additionalClasses) {
            lcfItem.classList.add(...aspect.additionalClasses);
        }
        if (textContent) {
            lcfItem.textContent = textContent;
        }
        return {
            lcfItem,
            aspect,
            domId,
        };
    }

    /**
     * The horizontally-scrolling cover flow: builds the flex row, its loading
     * animation, left/right navigation buttons and one card per data item, and
     * owns that layout's CSS.
     */
    class DefaultContext {
        /**
         * @param {Config} config
         * @param {Container} container
         * @param {Object} data - formatted items keyed by domId.
         * @param {LcfItemWrapper[]} lcfLoadingAspects
         * @param {LcfItemWrapper[]} lcfItemWrapperAspects - the per-card aspect tree.
         * @param {LcfItemWrapper[]} lcfNavigationAspects - [leftButton, rightButton].
         */
        constructor(
            config,
            container,
            data,
            lcfLoadingAspects,
            lcfItemWrapperAspects,
            lcfNavigationAspects
        ) {
            this.config = config;
            this.container = container;
            this.data = data;
            this.lcfLoadingAspects = lcfLoadingAspects;
            this.lcfItemWrapperAspects = lcfItemWrapperAspects;
            this.lcfNavigationAspects = lcfNavigationAspects;
            this.defaultContext = [
                [
                    `#${container.reference.id}`,
                    `
                display: -webkit-box;
                display: -ms-flexbox;
                display: flex;
                gap: 1rem;
                width: ${config.coverFlowContainerWidth};
                overflow-x: scroll;
                overflow-y: hidden;
                padding: ${config.coverFlowContainerPadding};
                margin: ${config.coverFlowContainerMargin};

                position: relative;
                `,
                ],
                [
                    ".lcfItemContainer",
                    `
                -webkit-box-flex: 0;
                -ms-flex-positive: 0;
                flex-grow: 0;
                -ms-flex-negative: 0;
                flex-shrink: 0;
                `,
                ],
                [
                    ".lcfLoadingAnimation",
                    `
                -ms-grid-column: 2;
                -ms-grid-column-span: 2;
                grid-column: 2 / span 2;
                `,
                ],
            ];
        }
        /** Inject this context's layout CSS into the shared style sheet. */
        setStyles() {
            this.defaultContext.forEach(style => {
                addGlobalStyle(style[0], style[1], this.container);
            });
        }
        /** Build and append the loading-spinner node. */
        buildLoadingAnimation() {
            this.lcfLoadingAspects.forEach(aspect => {
                appendToDom(
                    createTagAndSetClasses(aspect, "lcfLoading"),
                    this.container
                );
            });
        }
        /** Build and append the left scroll button. */
        buildLeftNavigationButton() {
            appendToDom(
                createNavigationButton(
                    createTagAndSetClasses(
                        this.lcfNavigationAspects[0],
                        "lcfNavigation",
                        ""
                    ),
                    "left",
                    this.container
                ),
                this.container
            );
        }
        /** Build and append the right scroll button. */
        buildRightNavigationButton() {
            appendToDom(
                createNavigationButton(
                    createTagAndSetClasses(
                        this.lcfNavigationAspects[1],
                        "lcfNavigation",
                        ""
                    ),
                    "right",
                    this.container
                ),
                this.container
            );
        }
        /** Apply inline positioning styles to the two navigation buttons. */
        setNavigationButtonStyles() {
            const lcfNavigationButtonsBaseStyles = `
    position: sticky;
    z-index: 1;
    -ms-flex-item-align: center;
    -ms-grid-row-align: center;
    align-self: center;

    background: #343a40;
    color: #fff;
    border-radius: 50%;
    `;
            addInlineStyle(
                "lcfNavigationButtonLeft",
                `
    ${lcfNavigationButtonsBaseStyles}
    left: 1rem;
    margin-right: 1rem;
    `,
                this.container
            );
            addInlineStyle(
                "lcfNavigationButtonRight",
                `
    ${lcfNavigationButtonsBaseStyles}
    right: 1rem;
    margin-left: 1rem;
    `,
                this.container
            );
        }
        /**
         * Build one card per data item. Normally each aspect is created and
         * appended; under the `#shelfbrowser-testing` harness, cover markup is
         * parsed from each item's coverhtml and reused as the anchor/image nodes.
         */
        buildCoverFlow() {
            Array.from(Object.keys(this.data).entries()).forEach(entry => {
                const [numericIndex, domId] = entry;
                /** The following if statement handles external elements,
                 *  that are provided in the koha-shelfbrowser. */
                if (document.getElementById("shelfbrowser-testing")) {
                    const generatedHtml = stringToHtml(
                        this.data[domId].coverhtml
                    );
                    const newElementsArray = Array.from(generatedHtml.children);
                    recursiveArrayPopulation(newElementsArray);
                    Array.from(newElementsArray.entries()).forEach(domNode => {
                        newElementsArray[domNode[0]] = removeChildNodes(
                            domNode[1]
                        );
                    });
                    this.lcfItemWrapperAspects.forEach(aspect => {
                        if (
                            aspect.reference === "lcfAnchor" &&
                            newElementsArray[0].tagName === "A"
                        ) {
                            appendToDom(
                                createTagAndSetClasses(
                                    new LcfItemWrapper(
                                        newElementsArray[0],
                                        "lcfAnchor",
                                        "lcfCoverImageWrapper",
                                        [this.container.coverFlowId]
                                    ),
                                    domId,
                                    "",
                                    true
                                ),
                                this.container
                            );
                        } else if (
                            aspect.reference === "lcfCoverImage" &&
                            newElementsArray[1].tagName === "DIV"
                        ) {
                            appendToDom(
                                createTagAndSetClasses(
                                    new LcfItemWrapper(
                                        newElementsArray[1],
                                        "lcfCoverImage",
                                        "lcfAnchor",
                                        [this.container.coverFlowId]
                                    ),
                                    domId,
                                    "",
                                    true
                                ),
                                this.container
                            );
                        } else {
                            appendToDom(
                                createTagAndSetClasses(aspect, domId),
                                this.container
                            );
                        }
                    });
                } else {
                    this.lcfItemWrapperAspects.forEach(aspect => {
                        appendToDom(
                            createTagAndSetClasses(aspect, domId),
                            this.container,
                            this.config.shelfBrowserButtonDirection,
                            numericIndex
                        );
                    });
                }
            });
        }
    }

    /**
     * The responsive CSS-grid layout (used for recommendation sliders): builds
     * the same per-item cards as DefaultContext but with a breakpoint-driven grid
     * and no navigation buttons.
     */
    class GridContext {
        /**
         * @param {Config} config
         * @param {Container} container
         * @param {Object} data - formatted items keyed by domId.
         * @param {LcfItemWrapper[]} lcfLoadingAspects
         * @param {LcfItemWrapper[]} lcfItemWrapperAspects - the per-card aspect tree.
         */
        constructor(
            config,
            container,
            data,
            lcfLoadingAspects,
            lcfItemWrapperAspects
        ) {
            this.config = config;
            this.container = container;
            this.data = data;
            this.lcfLoadingAspects = lcfLoadingAspects;
            this.lcfItemWrapperAspects = lcfItemWrapperAspects;
            this.recommenderGridContext = [
                [
                    ":root",
                    `
                  /* extra large */
                  --w1: ${config.gridCoverFlowBreakpoints.xl}px;
                  --xl: 5;
                  /* large */
                  --w2: ${config.gridCoverFlowBreakpoints.l}px;
                  --l: 4;
                  /* medium */
                  --w3: ${config.gridCoverFlowBreakpoints.m}px;
                  --m: 3;
                  /* small */
                  --w4: ${config.gridCoverFlowBreakpoints.s}px;
                  --s: 2;
                  /* extra small */
                  --w5: ${config.gridCoverFlowBreakpoints.xs}px;
                  --xs: 1;
                  `,
                ],
                [
                    `#${container.reference.id}`,
                    `
                  display: -ms-grid;
                  display: grid;
                  grid-template-columns:
                      repeat(auto-fill,
                          minmax(clamp(clamp(clamp(clamp(clamp(
                              100% / (var(--xl) + 1) + 0.1%,
                                  (var(--w1) - 100vw) * 1000,
                              100% / (var(--l) + 1) + 0.1%),
                                  (var(--w2) - 100vw) * 1000,
                              100% / (var(--m) + 1) + 0.1%),
                                  (var(--w3) - 100vw) * 1000,
                              100% / (var(--s) + 1) + 0.1%),
                                  (var(--w4) - 100vw) * 1000,
                              100% / (var(--xs) + 1) + 0.1%),
                                  (var(--w5) - 100vw) * 1000,
                              100%), 1fr));
                  -webkit-column-gap: 1rem;
                  -moz-column-gap: 1rem;
                  column-gap: 1rem;
                  row-gap: 2rem;
                  width: ${config.coverFlowContainerWidth};
                  margin: ${config.coverFlowContainerMargin};
                  `,
                ],
                [
                    ".lcfCoverImageWrapper",
                    `
                  display: -webkit-box;
                  display: -ms-flexbox;
                  display: flex;
                  -webkit-box-pack: center;
                  -ms-flex-pack: center;
                  justify-content: center;
                  padding: 1rem;
                  background: rgb(254,254,254);
                  background: -o-radial-gradient(circle, rgba(254,254,254,1) 0%, rgba(235,235,235,1) 100%);
                  background: radial-gradient(circle, rgba(254,254,254,1) 0%, rgba(235,235,235,1) 100%);
                  filter: progid:DXImageTransform.Microsoft.gradient(startColorstr="#fefefe",endColorstr="#ebebeb",GradientType=1);
                  overflow: hidden;
                  `,
                ],
                [
                    ".lcfCoverImage",
                    `
                  border-radius: .25rem;
                  `,
                ],
                [
                    `@media (min-width: ${config.gridCoverFlowBreakpoints.xl}px)`,
                    `.lcfLoadingAnimation {
                      -ms-grid-column: 3;
                      -ms-grid-column-span: 1;
                      grid-column: 3 / span 1;
                  }`,
                ],
                [
                    `@media (min-width: ${config.gridCoverFlowBreakpoints.l}px)`,
                    `.lcfLoadingAnimation {
                      -ms-grid-column: 2;
                      -ms-grid-column-span: 2;
                      grid-column: 2 / span 2;
                  }`,
                ],
                [
                    `@media (min-width: ${config.gridCoverFlowBreakpoints.m}px)`,
                    `
                  .lcfLoadingAnimation {
                      -ms-grid-column: 2;
                      -ms-grid-column-span: 1;
                      grid-column: 2 / span 1;
                  }
                  `,
                ],
                [
                    `@media (min-width: ${config.gridCoverFlowBreakpoints.s}px)`,
                    `
                  .lcfLoadingAnimation {
                      -ms-grid-column: 1;
                      -ms-grid-column-span: 2;
                      grid-column: 1 / span 2;
                  }
                  `,
                ],
                [
                    `@media (min-width: ${config.gridCoverFlowBreakpoints.xs}px)`,
                    `
                  .lcfLoadingAnimation {
                      -ms-grid-column: 1;
                      -ms-grid-column-span: 1;
                      grid-column: 1 / span 1;
                  }
                  `,
                ],
            ];
        }
        /** Inject this context's grid CSS into the shared style sheet. */
        setStyles() {
            this.recommenderGridContext.forEach(style => {
                addGlobalStyle(style[0], style[1], this.container);
            });
        }
        /** Build and append the loading-spinner node. */
        buildLoadingAnimation() {
            this.lcfLoadingAspects.forEach(aspect => {
                appendToDom(
                    createTagAndSetClasses(aspect, "lcfLoading"),
                    this.container
                );
            });
        }
        /** Build one card per data item. */
        buildCoverFlow() {
            Object.keys(this.data).forEach(domId => {
                this.lcfItemWrapperAspects.forEach(aspect => {
                    appendToDom(
                        createTagAndSetClasses(aspect, domId),
                        this.container
                    );
                });
            });
        }
    }

    /**
     * Assemble the aspect tree for the current config, then render it through the
     * context that matches coverFlowContext + screen width + shelf-browser flags:
     * default (horizontal), grid, shelf-browser mobile, or shelf-browser extension.
     * @param {Object} data - formatted items keyed by domId.
     * @param {('default'|'grid')} coverFlowContext
     * @param {Container} container
     * @param {Config} config
     * @param {string[]} customClasses - extra classes applied to every aspect.
     * @returns {void}
     */
    // eslint-disable-next-line max-len
    function build(data, coverFlowContext, container, config, customClasses) {
        try {
            const lcfLoadingAspects = [
                new LcfItemWrapper(
                    "div",
                    "lcfLoadingAnimation",
                    container.reference,
                    [container.coverFlowId, ...customClasses]
                ),
            ];
            const lcfNavigationAspects = [
                new LcfItemWrapper(
                    "button",
                    "lcfNavigationButtonLeft",
                    container.reference,
                    ["btn", "d-none", container.coverFlowId, ...customClasses]
                ),
                new LcfItemWrapper(
                    "button",
                    "lcfNavigationButtonRight",
                    container.reference,
                    ["btn", "d-none", container.coverFlowId, ...customClasses]
                ),
            ];
            const lcfItemWrapperAspects = [
                new LcfItemWrapper(
                    "div",
                    "lcfItemContainer",
                    container.reference,
                    [
                        "d-none",
                        "card",
                        "border-0",
                        "flipCard",
                        container.coverFlowId,
                        ...customClasses,
                    ]
                ),
                new LcfItemWrapper("div", "lcfFlipCard", "lcfItemContainer", [
                    "border",
                    "rounded",
                    "flipCardInner",
                    container.coverFlowId,
                    ...customClasses,
                ]),
                /** Below are tags on the front of the flipCard. */
                new LcfItemWrapper("div", "lcfFlipCardFront", "lcfFlipCard", [
                    "flipCardFront",
                    container.coverFlowId,
                    ...customClasses,
                ]),
                new LcfItemWrapper(
                    "div",
                    "lcfCoverImageWrapper",
                    "lcfFlipCardFront",
                    ["card-img-top", container.coverFlowId, ...customClasses]
                ),
                new LcfItemWrapper("a", "lcfAnchor", "lcfCoverImageWrapper", [
                    container.coverFlowId,
                    ...customClasses,
                ]),
                new LcfItemWrapper("img", "lcfCoverImage", "lcfAnchor", [
                    container.coverFlowId,
                    ...customClasses,
                ]),
                new LcfItemWrapper("div", "lcfCardBody", "lcfFlipCardFront", [
                    "card-body",
                    "p-2",
                    "text-center",
                    container.coverFlowId,
                    ...customClasses,
                ]),
                new LcfItemWrapper("p", "lcfMediaAuthor", "lcfCardBody", [
                    "card-text",
                    "text-muted",
                    "text-truncate",
                    "font-weight-light",
                    "mb-0",
                    config.coverFlowCardBodyTextHeights.lcfMediaAuthor,
                    container.coverFlowId,
                    ...customClasses,
                ]),
                new LcfItemWrapper(
                    "p",
                    "lcfMediaItemCallNumber",
                    "lcfCardBody",
                    [
                        "card-text",
                        "text-muted",
                        "text-truncate",
                        "font-weight-light",
                        "mb-0",
                        config.coverFlowCardBodyTextHeights
                            .lcfMediaItemCallNumber,
                        container.coverFlowId,
                        ...customClasses,
                    ]
                ),
                new LcfItemWrapper("p", "lcfMediaTitle", "lcfCardBody", [
                    "card-text",
                    "text-truncate",
                    "font-weight-lighter",
                    "mb-0",
                    config.coverFlowCardBodyTextHeights.lcfMediaTitle,
                    container.coverFlowId,
                    ...customClasses,
                ]),
            ];
            if (config.coverFlowFlippableCards) {
                lcfItemWrapperAspects.push(
                    ...[
                        /** These tags are on the back of the flipCard. */
                        new LcfItemWrapper(
                            "div",
                            "lcfFlipCardBack",
                            "lcfFlipCard",
                            ["flipCardBack", container.coverFlowId]
                        ),
                        new LcfItemWrapper(
                            "p",
                            "lcfMediaISBD",
                            "lcfFlipCardBack",
                            [container.coverFlowId]
                        ),
                        new LcfItemWrapper(
                            "button",
                            "lcfFlipCardButton",
                            "lcfItemContainer",
                            ["shadow", container.coverFlowId]
                        ),
                    ]
                );
            }
            const evaluateConfiguration = () => {
                if (config.coverFlowFlippableCards) {
                    setFlipCards(container);
                    setHighlightOnHover(container);
                    return;
                }
                if (config.coverFlowHighlightingStyle === "default") {
                    setRaiseShadowOnHover(container);
                    return;
                }
                if (config.coverFlowHighlightingStyle === "coloredFrame") {
                    setHighlightOnHover(container);
                }
            };
            /* The default and shelf-browser-mobile contexts render identically. */
            const buildDefaultContext = () => {
                createStyleTag(container);
                setGlobalStyles(config, container);
                setLoadingAnimation(config, container);
                evaluateConfiguration();
                const defaultContext = new DefaultContext(
                    config,
                    container,
                    data,
                    lcfLoadingAspects,
                    lcfItemWrapperAspects,
                    lcfNavigationAspects
                );
                defaultContext.setStyles();
                defaultContext.buildLoadingAnimation();
                defaultContext.buildLeftNavigationButton();
                defaultContext.buildCoverFlow();
                defaultContext.buildRightNavigationButton();
                defaultContext.setNavigationButtonStyles();
            };
            /* context name -> builder. Replaces the old Strategy/StrategyManager
               classes, which were a full Strategy pattern for a one-shot lookup. */
            const strategies = {
                defaultContextStrategy: buildDefaultContext,
                shelfBrowserMobileStrategy: buildDefaultContext,
                gridContextStrategy: () => {
                    createStyleTag(container);
                    setGlobalStyles(config, container);
                    setLoadingAnimation(config, container);
                    evaluateConfiguration();
                    const gridContext = new GridContext(
                        config,
                        container,
                        data,
                        lcfLoadingAspects,
                        lcfItemWrapperAspects
                    );
                    gridContext.setStyles();
                    gridContext.buildLoadingAnimation();
                    gridContext.buildCoverFlow();
                },
                shelfBrowserExtensionStrategy: () => {
                    const defaultContext = new DefaultContext(
                        config,
                        container,
                        data,
                        lcfLoadingAspects,
                        lcfItemWrapperAspects,
                        lcfNavigationAspects
                    );
                    defaultContext.buildCoverFlow();
                },
            };
            if (config.shelfBrowserExtendedCoverFlow) {
                strategies.shelfBrowserExtensionStrategy();
                return;
            }
            // eslint-disable-next-line max-len
            if (
                config.coverFlowShelfBrowser &&
                window.screen.width <= config.gridCoverFlowBreakpoints.s - 1
            ) {
                strategies.shelfBrowserMobileStrategy();
                return;
            }
            if (
                coverFlowContext === "grid" ||
                (window.screen.width <= config.gridCoverFlowBreakpoints.s - 1 &&
                    config.coverFlowMobileAllowGridForDefault)
            ) {
                strategies.gridContextStrategy();
                return;
            }
            if (
                (coverFlowContext === "default" &&
                    window.screen.width >= config.gridCoverFlowBreakpoints.s) ||
                !config.coverFlowMobileAllowGridForDefault
            ) {
                strategies.defaultContextStrategy();
            }
        } catch (error) {
            console.trace(
                `Looks like something went wrong in ${build.name} ->`,
                error
            );
        }
    }

    /**
     * Normalises the caller-supplied options into a complete configuration,
     * filling every recognised `coverFlow*` / `coverImage*` / `shelfBrowser*` /
     * `gridCoverFlowBreakpoints` key with its default. This default set is part
     * of the public contract — keep the names and defaults stable.
     */
    class Config {
        /** @param {Object} configuration - the caller's partial options. */
        constructor(configuration) {
            this.config = configuration;
            this.coverImageFallbackHeight =
                this.config.coverImageFallbackHeight || 210;
            this.coverImageFallbackUrl =
                this.config.coverImageFallbackUrl ||
                "/api/v1/public/generated_cover";
            this.coverImageGeneratedCoverEndpoint =
                this.config.coverImageGeneratedCoverEndpoint ||
                "/api/v1/public/generated_cover";
            this.coverImageFetchTimeout =
                this.config.coverImageFetchTimeout || 1000;
            this.coverFlowDataBiblionumberEndpoint =
                this.config.coverFlowDataBiblionumberEndpoint ||
                "/api/v1/public/coverflow_data_biblionumber/";
            this.coverFlowNearbyItemsEndpoint =
                this.config.coverFlowNearbyItemsEndpoint ||
                "/api/v1/public/coverflow_data_nearby_items/";
            this.coverFlowTooltips = this.config.coverFlowTooltips || false;
            this.coverFlowAutoScroll = this.config.coverFlowAutoScroll || false;
            this.coverFlowAutoScrollInterval =
                this.config.coverFlowAutoScrollInterval || 8000;
            this.coverFlowCardBody = this.config.coverFlowCardBody || {
                lcfMediaAuthor: true,
                lcfMediaTitle: true,
                lcfMediaItemCallNumber: false,
            };
            this.coverFlowCardBodyTextHeights = this.config
                .coverFlowCardBodyTextHeights || {
                lcfMediaAuthor: "text-custom-12",
                lcfMediaTitle: "text-custom-12",
                lcfMediaItemCallNumber: "text-custom-12",
            };
            this.coverFlowCustomClasses =
                this.config.coverFlowCustomClasses || ""; // TODO: Enable selection of aspects.
            this.coverImageExternalSources =
                this.config.coverImageExternalSources || true;
            this.coverImageCallbackTimeout =
                this.config.coverImageCallbackTimeout || 500;
            this.coverFlowContext = this.config.coverFlowContext || "default";
            this.coverFlowMobileAllowGridForDefault =
                this.config.coverFlowMobileAllowGridForDefault || false;
            this.coverFlowShelfBrowser =
                this.config.coverFlowShelfBrowser || false;
            this.coverFlowContainerWidth =
                this.config.coverFlowContainerWidth || "100%";
            this.coverFlowContainerMargin =
                this.config.coverFlowContainerMargin || "0%";
            this.coverFlowContainerPadding =
                this.config.coverFlowContainerPadding || "2rem 1px 2rem 1px";
            this.coverFlowButtonsBehaviour =
                this.config.coverFlowButtonsBehaviour || "stay";
            this.coverFlowButtonsCallback =
                this.config.coverFlowButtonsCallback;
            this.coverFlowFlippableCards =
                this.config.coverFlowFlippableCards || false;
            this.coverFlowHighlightingStyle =
                this.config.coverFlowHighlightingStyle || "default";
            this.gridCoverFlowBreakpoints = this.config
                .gridCoverFlowBreakpoints || {
                xl: 1367,
                l: 1025,
                m: 769,
                s: 481,
                xs: 320,
            };
            this.shelfBrowserExtendedCoverFlow =
                this.config.shelfBrowserExtendedCoverFlow || false;
            this.shelfBrowserButtonDirection =
                this.config.shelfBrowserButtonDirection || null;
            this.shelfBrowserCurrentEventListeners =
                this.config.shelfBrowserCurrentEventListeners || null;
            this.shelfBrowserScrollIntoView =
                this.config.shelfBrowserScrollIntoView || false;
            this.debug = this.config.debug || false;
        }
    }

    /**
     * Wraps the coverflow's root DOM element and owns its scroll behaviour:
     * scrollability detection, smooth scrolling, navigation-button references and
     * the scroll listeners for both default and shelf-browser modes.
     */
    class Container {
        reference;
        scrollable;
        lcfNavigationButtonLeft;
        lcfNavigationButtonRight;
        config;
        referenceAsClass;
        /**
         * @param {string} element - the container element's id.
         * @param {Config} config
         */
        constructor(element, config) {
            this.config = config;
            this.reference = document.getElementById(element);
            this.scrollable = false;
            this.lcfNavigationButtonLeft = null;
            this.lcfNavigationButtonRight = null;
            this.referenceAsClass = this.reference.id;
        }
        /** Set `scrollable` when content overflows horizontally (or in shelf-browser mode). */
        isScrollable() {
            if (
                this.reference.scrollWidth > this.reference.clientWidth ||
                this.config.coverFlowShelfBrowser
            ) {
                this.scrollable = true;
            }
        }
        /**
         * Animate the container's horizontal scroll to a target position via rAF.
         * @param {Container} container
         * @param {number} position - target scrollLeft; 0 scrolls back to the start.
         * @param {?number} time - duration in ms (default 500, or 2000 when position is 0).
         * @returns {void}
         */
        static scrollSmoothly(container, position, time) {
            const CONTAINER = container;
            let POSITION = position;
            let TIME = time;
            const currentPosition =
                position !== 0
                    ? CONTAINER.reference.scrollLeft
                    : CONTAINER.reference.scrollWidth;
            let start = null;
            if (TIME === null) {
                TIME = 500;
            }
            if (position === 0) {
                TIME = 2000;
            }
            POSITION = +POSITION;
            TIME = +TIME;
            window.requestAnimationFrame(function step(currentTime) {
                start = !start ? currentTime : start;
                const progress = currentTime - start;
                if (currentPosition < POSITION) {
                    CONTAINER.reference.scrollLeft =
                        ((POSITION - currentPosition) * progress) / TIME +
                        currentPosition;
                } else {
                    CONTAINER.reference.scrollLeft =
                        currentPosition -
                        ((currentPosition - POSITION) * progress) / TIME;
                }
                if (progress < TIME) {
                    window.requestAnimationFrame(step);
                } else {
                    CONTAINER.reference.scrollLeft = POSITION;
                }
            });
        }
        /** @returns {string} the per-instance scoping class (the element id). */
        get coverFlowId() {
            return this.referenceAsClass;
        }
        /** Cache the current left/right navigation button elements. */
        updateNavigationButtonReferences() {
            this.lcfNavigationButtonLeft = document.querySelector(
                `.lcfNavigationButtonLeft.${this.coverFlowId}`
            );
            this.lcfNavigationButtonRight = document.querySelector(
                `.lcfNavigationButtonRight.${this.coverFlowId}`
            );
        }
        /**
         * Attach scroll listeners: edge-detection handlers in shelf-browser mode
         * (tracked via the shared EventListeners singleton), or the default
         * button hide/disable handler otherwise.
         */
        hideOrShowButton() {
            if (this.config.coverFlowShelfBrowser) {
                if (
                    this.config.shelfBrowserCurrentEventListeners.getLeft() ===
                    false
                ) {
                    this.config.shelfBrowserCurrentEventListeners.setHandler(
                        this.handleShelfBrowserScrollingLeft,
                        "left"
                    );
                    this.reference.addEventListener(
                        "scroll",
                        this.handleShelfBrowserScrollingLeft
                    );
                    this.config.shelfBrowserCurrentEventListeners.setLeftToTrue();
                }
                if (
                    this.config.shelfBrowserCurrentEventListeners.getRight() ===
                    false
                ) {
                    this.config.shelfBrowserCurrentEventListeners.setHandler(
                        this.handleShelfBrowserScrollingRight,
                        "right"
                    );
                    this.reference.addEventListener(
                        "scroll",
                        this.handleShelfBrowserScrollingRight
                    );
                    this.config.shelfBrowserCurrentEventListeners.setRightToTrue();
                }
            } else {
                this.reference.addEventListener(
                    "scroll",
                    this.handleDefaultScrolling
                );
            }
        }
        /** Scroll handler: at the left edge, load the previous shelf items. */
        handleShelfBrowserScrollingLeft = () => {
            const container = this.reference;
            if (this.config.coverFlowShelfBrowser) {
                if (container.scrollLeft === 0) {
                    this.handleScrollToEdge(this.lcfNavigationButtonLeft);
                }
            }
        };
        /** Scroll handler: at the right edge, load the next shelf items. */
        handleShelfBrowserScrollingRight = () => {
            const container = this.reference;
            const scrollRight =
                container.scrollWidth -
                container.clientWidth -
                container.scrollLeft;
            if (this.config.coverFlowShelfBrowser) {
                if (scrollRight <= 0) {
                    this.handleScrollToEdge(this.lcfNavigationButtonRight);
                }
            }
        };
        /**
         * Load more shelf-browser items for the reached edge and detach that
         * edge's scroll listener until the new content settles.
         * @param {?Element} buttonReference - the nav button at the reached edge.
         */
        handleScrollToEdge = buttonReference => {
            if (buttonReference) {
                const scrollDirection = buttonReference.classList.contains(
                    "lcfNavigationButtonLeft"
                )
                    ? "left"
                    : "right";
                const { loadNewShelfBrowserItems, nearbyItems } =
                    this.config.coverFlowButtonsCallback;
                loadNewShelfBrowserItems(nearbyItems, scrollDirection);
                if (scrollDirection === "left") {
                    this.reference.removeEventListener(
                        "scroll",
                        this.handleShelfBrowserScrollingLeft
                    );
                    this.config.shelfBrowserCurrentEventListeners.setLeftToFalse();
                } else {
                    this.reference.removeEventListener(
                        "scroll",
                        this.handleShelfBrowserScrollingRight
                    );
                    this.config.shelfBrowserCurrentEventListeners.setRightToFalse();
                }
            }
        };
        /**
         * Default-context scroll handler: disable or hide the navigation buttons
         * at each end according to coverFlowButtonsBehaviour.
         */
        handleDefaultScrolling = () => {
            const scrollRight =
                this.reference.scrollWidth -
                this.reference.clientWidth -
                this.reference.scrollLeft;
            if (this.config.coverFlowButtonsBehaviour === "disable") {
                if (this.reference.scrollLeft > 50) {
                    this.lcfNavigationButtonLeft.disabled = false;
                } else {
                    this.lcfNavigationButtonLeft.disabled = true;
                }
                if (scrollRight < 50) {
                    this.lcfNavigationButtonRight.disabled = true;
                } else {
                    this.lcfNavigationButtonRight.disabled = false;
                }
            }
            if (this.config.coverFlowButtonsBehaviour === "hide") {
                if (this.reference.scrollLeft > 50) {
                    this.lcfNavigationButtonLeft.classList.remove("d-none");
                } else {
                    this.lcfNavigationButtonLeft.classList.add("d-none");
                }
                if (scrollRight < 50) {
                    this.lcfNavigationButtonRight.classList.add("d-none");
                } else {
                    this.lcfNavigationButtonRight.classList.remove("d-none");
                }
            }
        };
        /**
         * Start an interval that gently auto-scrolls to the right, wrapping back
         * to the start once the end is reached.
         * @returns {number} the interval id (clear it to stop auto-scrolling).
         */
        autoScrollContainer() {
            const scrollRight = () =>
                this.reference.scrollWidth -
                this.reference.clientWidth -
                this.reference.scrollLeft;
            const scrollContainer = scrollRightResult => {
                if (scrollRightResult === 0) {
                    Container.scrollSmoothly(this, 0, 500);
                    return;
                }
                Container.scrollSmoothly(
                    this,
                    this.reference.scrollLeft + this.reference.clientWidth / 4,
                    500
                );
            };
            const runAutoScroll = () => {
                const scrollRightValue = scrollRight();
                scrollContainer(scrollRightValue);
            };
            const autoScrollId = setInterval(() => {
                runAutoScroll();
            }, this.config.coverFlowAutoScrollInterval);
            return autoScrollId;
        }
    }

    /* eslint-disable max-len */
    /**
     * Cover-URL resolution: validates/probes each item's cover URL and falls back
     * to the configured fallback image or the generated-cover endpoint when a
     * cover is missing, local-only, or unreachable.
     */
    class Data {
        config;
        /** @param {Config} config */
        constructor(config) {
            this.config = config;
        }
        /**
         * @param {string} urlInQuestion
         * @returns {boolean} whether the string is a valid http(s) URL.
         */
        static isValidUrl(urlInQuestion) {
            let url;
            try {
                url = new URL(urlInQuestion);
            } catch (error) {
                return false;
            }
            return url.protocol === "http:" || url.protocol === "https:";
        }
        /**
         * Probe a cover URL by loading it as an image, i.e. the same way the
         * rendered <img> will consume it. A fetch() probe cannot be used here:
         * cover hosts that send no Access-Control-Allow-Origin header (onleihe.de,
         * cover.ekz.de) make fetch() reject even though the image displays fine,
         * so a usable cover would be discarded in favour of the fallback.
         * @param {string} resourceInQuestion
         * @param {{timeout?: number}} [options] - abort the probe after timeout ms.
         * @returns {Promise<boolean>} whether the resource loads as an image.
         */
        checkIfFileExists(resourceInQuestion, options = {}) {
            const { timeout = 1000 } = options;
            return new Promise(resolve => {
                const probe = new Image();
                let timeoutId;
                const settle = result => {
                    clearTimeout(timeoutId);
                    probe.onload = null;
                    probe.onerror = null;
                    resolve(result);
                };
                timeoutId = setTimeout(() => {
                    settle(false);
                    /** Cancels the pending download. */
                    probe.src = "";
                }, timeout);
                probe.onload = () => settle(true);
                probe.onerror = () => settle(false);
                /** Matches the normalisation applied to the rendered src. */
                probe.src = resourceInQuestion.replaceAll("&amp;", "&");
            });
        }
        /**
         * Resolve every item's coverurl: keep valid remote URLs, otherwise swap in
         * the fallback image or a generated cover. Missing/local/unreachable
         * covers are replaced.
         * @param {Object[]} localData - raw data items.
         * @returns {Promise<Object>[]} per-item promises of the resolved item.
         */
        checkUrls(localData) {
            try {
                // eslint-disable-next-line max-len
                const checkedUrls = localData.map(async entry => {
                    const { coverurl, coverhtml } = entry;
                    if (
                        (coverhtml && !coverurl) ||
                        (coverurl && coverurl.startsWith("/")) ||
                        !coverurl
                    ) {
                        return {
                            ...entry,
                            coverurl:
                                this.config.coverImageFallbackUrl !==
                                this.config.coverImageGeneratedCoverEndpoint
                                    ? this.config.coverImageFallbackUrl
                                    : await Data.processDataUrl(
                                          generatedCoverRequestURI({
                                              title: entry.title,
                                          })
                                      ),
                        };
                    }
                    const fileExists = await this.checkIfFileExists(coverurl);
                    if (!fileExists) {
                        return {
                            ...entry,
                            coverurl:
                                this.config.coverImageFallbackUrl !==
                                this.config.coverImageGeneratedCoverEndpoint
                                    ? this.config.coverImageFallbackUrl
                                    : await Data.processDataUrl(
                                          generatedCoverRequestURI({
                                              title: entry.title,
                                          })
                                      ),
                        };
                    }
                    return entry;
                });
                return checkedUrls;
            } catch (error) {
                console.trace(
                    `Looks like a something went wrong in ${this.checkUrls.name} ->`,
                    error
                );
                return [];
            }
        }
        /**
         * Fetch a URL and return its parsed JSON body (used for generated-cover
         * data URLs).
         * @param {string} url
         * @returns {Promise<*>}
         */
        static async processDataUrl(url) {
            const response = await fetch(url);
            const result = await response.json();
            return result;
        }
    }

    /**
     * Populate one rendered aspect node with its data-driven attributes: look up
     * the item by the node's domId, resolve the instruction for its reference
     * class, and apply it.
     * @param {Element} node
     * @param {Object} formattedData - items keyed by domId.
     * @returns {void}
     */
    function populateTagAttributes(node, formattedData) {
        try {
            const tag = node;
            const [reference, domId] = tag.classList;
            const item = formattedData[domId];
            const cases = attributeInstructionsFor(item);
            const instructions = instructionsForClass(reference, cases);
            if (instructions) {
                applyInstructions(tag, instructions);
            }
        } catch (error) {
            console.trace(
                `Looks like something went wrong in ${populateTagAttributes.name} ->`,
                error
            );
        }
    }

    /**
     * Build a hidden `.urlHarvester` scratch container holding each item's
     * coverhtml, so external-source scripts can rewrite it in place.
     * @param {Object} formattedData - items keyed by domId.
     * @param {Container} container
     * @returns {Promise<boolean>} whether the scratch DOM was built.
     */
    async function urlHarvester(formattedData, container) {
        try {
            const dataArray = arrFromObjEntries(formattedData);
            const harvester = document.createElement("div");
            harvester.classList.add(
                "urlHarvester",
                "d-none",
                container.referenceAsClass
            );
            dataArray.forEach(entry => {
                const [id, { coverhtml }] = entry;
                const harvesterElement = document.createElement("div");
                harvesterElement.classList.add(
                    "harvesterElement",
                    id,
                    container.referenceAsClass
                );
                harvesterElement.innerHTML = coverhtml;
                harvester.appendChild(harvesterElement);
            });
            container.reference.appendChild(harvester);
            return true;
        } catch (error) {
            console.log(error);
            return false;
        }
    }

    /* eslint-disable no-underscore-dangle */
    /**
     * Minimal observable value: listeners are notified when `value` changes.
     * Carries a free-form `info` slot used to flag the external cover source in
     * play. The module-level `externalSources` instance is the public export.
     */
    class Observable {
        _info;
        _listeners;
        _value;
        /** @param {*} value - the initial value. */
        constructor(value) {
            this._info = null;
            this._listeners = [];
            this._value = value;
        }
        /** Call every subscribed listener with the current value. */
        notify() {
            this._listeners.forEach(listener => listener(this._value));
        }
        /**
         * Register a listener invoked on each value change.
         * @param {function(*):void} listener
         */
        subscribe(listener) {
            this._listeners.push(listener);
        }
        /** @returns {*} the current value. */
        get value() {
            return this._value;
        }
        /** Set the value, notifying listeners only when it actually changes. */
        set value(val) {
            if (val !== this._value) {
                this._value = val;
                this.notify();
            }
        }
        /** @returns {*} the free-form info slot. */
        get info() {
            return this._info;
        }
        /** Set the free-form info slot (does not notify). */
        set info(info) {
            this._info = info;
        }
    }

    /**
     * Remove the hidden `.urlHarvester` scratch container, if present.
     * @param {Container} container
     * @returns {void}
     */
    function clearHarvester(container) {
        const harvester = document.querySelector(
            `.urlHarvester.${container.referenceAsClass}`
        );
        if (harvester) {
            harvester.remove();
        }
    }

    const externalSources = new Observable(false);

    /**
     * Harvest final cover-image URLs from external-source markup: build the
     * scratch harvester, read each `src` (or, when an async source is registered,
     * subscribe and wait), normalise it, and write it back onto the data —
     * falling back to a generated cover when none is found.
     * @param {Object} formattedData - items keyed by domId (mutated in place).
     * @param {Container} container
     * @param {Config} config
     * @returns {Promise<number>} 1 on success, 0 on failure.
     */
    async function harvestUrls(formattedData, container, config) {
        try {
            const dataReference = formattedData;
            const containerReference = container;
            const harvesterBuilt = await urlHarvester(
                dataReference,
                containerReference
            );
            if (harvesterBuilt) {
                let harvesterElements = document.querySelectorAll(
                    `.harvesterElement.${container.referenceAsClass}`
                );
                const harvesterResults = [];
                // eslint-disable-next-line no-underscore-dangle
                if (externalSources._listeners.length !== 0) {
                    const harvesterObservers = {};
                    harvesterElements.forEach(node => {
                        const nodeId = getLcfItemId(node);
                        harvesterObservers[nodeId] = new Observable(
                            node.innerHTML
                        );
                        harvesterObservers[nodeId].subscribe(coverurl => {
                            const srcRe = /src="(.+?)"/g;
                            const sources = coverurl.match(srcRe);
                            if (sources) {
                                const [src] = sources;
                                let [, srcString] = src.split('"');
                                /** Google specific url parameters. Somehow the identifier &amp; ends up
                                 * in the resulting string when it should be just & instead. */
                                srcString = `${srcString.replaceAll("amp;", "").replace(/zoom=./g, "zoom=1")}&gbs_api`;
                                harvesterResults.push([nodeId, srcString]);
                                return;
                            }
                            harvesterResults.push([nodeId, undefined]);
                        });
                    });
                    /** Notify the observant to execute the callback. */
                    externalSources.value = true;
                    /** Reset to false. */
                    externalSources.value = false;
                    setTimeout(() => {
                        harvesterElements = document.querySelectorAll(
                            `.harvesterElement.${container.referenceAsClass}`
                        );
                        harvesterElements.forEach(node => {
                            const nodeId = getLcfItemId(node);
                            harvesterObservers[nodeId].value = node.innerHTML;
                        });
                    }, config.coverImageCallbackTimeout);
                    setTimeout(() => {
                        const resultIds = [];
                        harvesterResults.forEach(entry => {
                            const [id, coverurl] = entry;
                            if (coverurl) {
                                dataReference[id].coverurl = coverurl;
                                resultIds.push(id);
                            } else {
                                /** We can't await the result here because of setTimeout. */
                                dataReference[id].coverurl =
                                    Data.processDataUrl(
                                        generatedCoverRequestURI({
                                            title: dataReference[id.title],
                                        })
                                    );
                            }
                            harvesterElements.forEach(node => {
                                const nodeId = getLcfItemId(node);
                                if (!resultIds.includes(nodeId)) {
                                    dataReference[nodeId].coverurl =
                                        Data.processDataUrl(
                                            generatedCoverRequestURI({
                                                title: dataReference[nodeId]
                                                    .title,
                                            })
                                        );
                                }
                            });
                        });
                    }, config.coverImageCallbackTimeout);
                    await resyncExecution(config.coverImageCallbackTimeout);
                    clearHarvester(container);
                } else {
                    harvesterElements.forEach(node => {
                        const nodeId = getLcfItemId(node);
                        const srcRe = /src="(.+?)"/g;
                        const sources = node.innerHTML.match(srcRe);
                        if (sources) {
                            const [src] = sources;
                            const [, srcString] = src.split('"');
                            harvesterResults.push([nodeId, srcString]);
                        } else {
                            const nodesFirstChild = node.firstChild;
                            const hasNoImage =
                                nodesFirstChild.classList.contains("no-image");
                            if (hasNoImage) {
                                harvesterResults.push([nodeId, undefined]);
                            }
                        }
                        harvesterResults.forEach(entry => {
                            const [id, coverurl] = entry;
                            if (coverurl) {
                                dataReference[id].coverurl = coverurl;
                            } else {
                                /** We can't await the result here because of setTimeout. */
                                dataReference[id].coverurl =
                                    Data.processDataUrl(
                                        generatedCoverRequestURI({
                                            title: dataReference[id].title,
                                        })
                                    );
                            }
                        });
                        clearHarvester(container);
                    });
                }
            }
        } catch (error) {
            console.trace(
                `Looks like harvesting failed in ${harvestUrls.name} ->`,
                error
            );
            return 0;
        }
        return 1;
    }

    /**
     * @param {string} container - the container element's id.
     * @returns {number} the element's computed font-size in px (0 on error).
     */
    function calculateComputedFontSize(container) {
        try {
            return parseInt(
                window
                    .getComputedStyle(document.getElementById(container))
                    .fontSize.split("px")[0],
                10
            );
        } catch (error) {
            console.trace(
                `Looks like something went wrong in ${calculateComputedFontSize.name} ->`,
                error
            );
            return 0;
        }
    }

    /**
     * Hide the card-body aspects (author / title / call number) that are turned
     * off in config.coverFlowCardBody; hide the whole card body when all are off.
     * @param {{config: Config, containerReference: string}} args
     * @returns {void}
     */
    function changeAspectVisibility({ config, containerReference }) {
        if (
            Object.values(config.coverFlowCardBody).every(
                setting => setting === false
            )
        ) {
            const cardBodies = document.querySelectorAll(
                `.lcfCardBody.${containerReference}`
            );
            cardBodies.forEach(cardBody => {
                cardBody.classList.add("d-none");
            });
        }
        Object.entries(config.coverFlowCardBody).forEach(itemCardBodyAspect => {
            const [cardBodyClass, setting] = itemCardBodyAspect;
            if (!setting) {
                const aspectToHide = document.querySelectorAll(
                    `.${cardBodyClass}.${containerReference}`
                );
                aspectToHide.forEach(item => {
                    item.classList.add("d-none");
                });
            }
        });
    }

    /**
     * Finalise cover URLs after harvesting: await any still-pending coverurl
     * promises and default empty ones to the fallback image.
     * @param {Config} config
     * @param {Object} formattedData - items keyed by domId.
     * @returns {Promise<Object>} the same object with settled coverurls.
     */
    async function cleanupUrls(config, formattedData) {
        try {
            const cleanedData = formattedData;
            await Promise.all(
                arrFromObjEntries(formattedData).map(async entry => {
                    const [id, data] = entry;
                    if (isPromise(data.coverurl)) {
                        cleanedData[id] = {
                            ...data,
                            coverurl: await data.coverurl,
                        };
                        return;
                    }
                    cleanedData[id] = {
                        ...data,
                        coverurl: data.coverurl || config.coverImageFallbackUrl,
                    };
                })
            );
            return cleanedData;
        } catch (error) {
            console.trace(
                `Looks like something went wrong in ${cleanupUrls.name} ->`,
                error
            );
            return formattedData;
        }
    }

    /**
     * Re-key the data by a freshly generated domId per item — the id that ties a
     * card's DOM nodes together.
     * @param {Object} localData
     * @returns {Object} items keyed by generated domId ({} on error).
     */
    function format(localData) {
        try {
            return Object.fromEntries(
                Object.entries(localData).map(([, v]) => [generateId(), v])
            );
        } catch (error) {
            console.trace(
                `Looks like something didn't map properly in ${format.name} ->`,
                error
            );
            return {};
        }
    }

    /**
     * Enable auto-scroll when configured (and not in shelf-browser mode),
     * pausing while the pointer is over the container.
     * @param {{config: Config, container: Container}} args
     * @returns {void}
     */
    function addAutoScroll({ config, container }) {
        if (config.coverFlowAutoScroll && !config.coverFlowShelfBrowser) {
            let autoScrollId = container.autoScrollContainer();
            container.reference.addEventListener("mouseover", () => {
                clearInterval(autoScrollId);
            });
            container.reference.addEventListener("mouseout", () => {
                autoScrollId = container.autoScrollContainer();
            });
        }
    }

    /**
     * Set a card's `data-tooltip` to the item's author / call number / title.
     * @param {Element} lcfItemContainer
     * @param {Object} coverFlowEntity
     * @returns {void}
     */
    // eslint-disable-next-line max-len
    function addDataTooltip(lcfItemContainer, coverFlowEntity) {
        try {
            const itemContainer = lcfItemContainer;
            itemContainer.dataset.tooltip = `${coverFlowEntity.author ? coverFlowEntity.author : ""} ${coverFlowEntity.itemCallNumber ? coverFlowEntity.itemCallNumber : ""} ${coverFlowEntity.title ? coverFlowEntity.title : ""}`;
        } catch (error) {
            console.trace(
                `Looks like something went wrong in ${addDataTooltip.name} ->`,
                error
            );
        }
    }

    /**
     * On flippable cards, add the flip button's icon and toggle the flipped
     * state (card + button) on click.
     * @param {{id: string, config: Config, containerReference: string}} args
     * @returns {void}
     */
    function addFlipCards({ id, config, containerReference }) {
        if (config.coverFlowFlippableCards) {
            try {
                const lcfFlipCardButton = document.querySelector(
                    `.lcfFlipCardButton.${id}.${containerReference}`
                );
                if (lcfFlipCardButton && !lcfFlipCardButton.childElementCount) {
                    const icon = document.createElement("i");
                    icon.className = "fa fa-arrow-left";
                    icon.setAttribute("aria-hidden", "true");
                    lcfFlipCardButton.setAttribute("aria-label", "←");
                    lcfFlipCardButton.appendChild(icon);
                }
                lcfFlipCardButton.addEventListener("click", () => {
                    const innerFlipCard = document.querySelector(
                        `.flipCardInner.${id}.${containerReference}`
                    );
                    innerFlipCard.classList.toggle("cardIsFlipped");
                    lcfFlipCardButton.classList.toggle("buttonIsFlipped");
                });
            } catch (error) {
                console.trace(
                    `Looks like something went wrong in ${addFlipCards.name} ->`,
                    error
                );
            }
        }
    }

    /** Loads a single cover image so its natural dimensions become available. */
    class LcfCoverImage {
        coverUrl;
        /** @param {string} coverUrl */
        constructor(coverUrl) {
            this.coverUrl = coverUrl;
        }
        /**
         * A failed or hanging load must still settle: prepare() awaits all of
         * these together, so one unsettled promise would stall the whole render.
         * @param {{timeout?: number}} [options] - give up on the load after timeout ms.
         * @returns {Promise<?HTMLImageElement>} the loaded image, or null when it
         *   failed to load or timed out.
         */
        fetch(options = {}) {
            const { timeout = 1000 } = options;
            return new Promise(resolve => {
                const coverImage = new Image();
                let timeoutId;
                const settle = result => {
                    clearTimeout(timeoutId);
                    coverImage.onload = null;
                    coverImage.onerror = null;
                    resolve(result);
                };
                timeoutId = setTimeout(() => settle(null), timeout);
                coverImage.onload = () => settle(coverImage);
                coverImage.onerror = () => settle(null);
                coverImage.src = this.coverUrl.replaceAll("amp;", "");
            });
        }
    }

    /**
     * A single cover-flow item plus its computed image geometry. Image height is
     * capped at kohaImageMaxHeight, and dimensions are later normalised to the
     * tallest cover in the row so every card lines up.
     */
    class LcfEntity {
        /**
         * @param {Object} entityData - { id, title, author, coverhtml, biblionumber,
         *   referenceToDetailsView, itemCallNumber }.
         * @param {number} coverImageFallbackHeight
         */
        constructor(entityData, coverImageFallbackHeight) {
            this.id = entityData.id;
            this.title = entityData.title;
            this.author = entityData.author;
            this.coverhtml = entityData.coverhtml;
            this.biblionumber = entityData.biblionumber;
            this.referenceToDetailsView = entityData.referenceToDetailsView;
            this.itemCallNumber = entityData.itemCallNumber;
            this.coverImageFallbackHeight = coverImageFallbackHeight;
            this.kohaImageMaxHeight = 250;
            this.maxHeight = 0;
        }
        /**
         * Record the loaded image's dimensions (downscaled to kohaImageMaxHeight
         * when taller) and derive its aspect ratio and computed width.
         * @param {number} height - natural image height.
         * @param {number} width - natural image width.
         */
        addCoverImageMetadata(height, width) {
            if (height <= this.kohaImageMaxHeight) {
                this.imageHeight = height;
                this.imageWidth = width;
            } else {
                const aspectRatio = height / width;
                this.imageHeight = this.kohaImageMaxHeight;
                this.imageWidth = this.kohaImageMaxHeight / aspectRatio;
            }
            this.imageAspectRatio = this.calculateCoverImageAspectRatio();
            this.imageComputedWidth = this.imageHeight / this.imageAspectRatio;
        }
        /** @returns {number} the current image height/width ratio. */
        calculateCoverImageAspectRatio() {
            return this.imageHeight / this.imageWidth;
        }
        /**
         * Record the row's shared target height (applied by updateDimensions).
         * @param {number} height
         */
        updateMaxHeight(height) {
            this.maxHeight = height;
        }
        /** Resize the image to the shared maxHeight, preserving aspect ratio. */
        updateDimensions() {
            this.imageHeight = this.maxHeight;
            this.imageWidth = this.imageHeight / this.imageAspectRatio;
            this.imageComputedWidth = this.imageHeight / this.imageAspectRatio;
        }
    }

    /**
     * Wrap each raw {id, entry, image} record in an LcfEntity (attaching image
     * metadata when an image loaded), as an array of resolved promises.
     * @param {Config} config
     * @param {Array<{id: string, entry: Object, image: ?HTMLImageElement}>} lcfCoverFlowEntities
     * @returns {?Promise<LcfEntity>[]} the entity promises, or null on error.
     */
    function entityToCoverFlow(config, lcfCoverFlowEntities) {
        const promisedCoverFlowEntities = [];
        try {
            lcfCoverFlowEntities.forEach(entity => {
                const newLcfEntity = new LcfEntity(
                    {
                        id: entity.id,
                        title: entity.entry.title,
                        author: entity.entry.author,
                        biblionumber: entity.entry.biblionumber,
                        coverurl: entity.entry.coverurl,
                        coverhtml: entity.entry.coverhtml,
                        referenceToDetailsView:
                            entity.entry.referenceToDetailsView,
                        itemCallNumber: entity.entry.itemCallNumber,
                    },
                    config.coverImageFallbackHeight
                );
                if (entity.image) {
                    newLcfEntity.addCoverImageMetadata(
                        entity.image.naturalHeight,
                        entity.image.naturalWidth
                    );
                }
                promisedCoverFlowEntities.push(
                    new Promise(resolve => {
                        resolve(newLcfEntity);
                    })
                );
            });
            return promisedCoverFlowEntities;
        } catch (error) {
            console.trace(
                `Looks like something went wrong in ${entityToCoverFlow.name} ->`,
                error
            );
            return null;
        }
    }

    /* eslint-disable max-len */
    /**
     * The main display step: await all entity promises, pick a shared image
     * height, size each card to its cover's computed width, hide the loading
     * animation, reveal the cards, and wire up scrollability/navigation.
     * @param {Config} config
     * @param {Container} container
     * @param {NodeList} currentItemContainers - cards already present (shelf-browser
     *   extension), excluded from re-sizing.
     * @param {Promise<LcfEntity>[]} promisedEntities
     * @returns {Promise<LcfEntity[]|undefined>} the settled entities (undefined on error).
     */
    async function settlePromises(
        config,
        // eslint-disable-next-line max-len
        container,
        currentItemContainers,
        promisedEntities
    ) {
        try {
            const result = await Promise.allSettled(promisedEntities);
            const flattenedResults = flattenPromiseResults(result);
            const lcfCoverImageHeights = flattenedResults.map(lcfEntity =>
                lcfEntity.imageHeight ? lcfEntity.imageHeight : null
            );
            let lcfItemContainers = Array.from(
                document.querySelectorAll(
                    `.lcfItemContainer.${container.coverFlowId}`
                )
            );
            /** We determine whether all images have a height of null which may be the case when
             * external sources provide them. */
            const imageArrayExistent = !lcfCoverImageHeights.every(
                height => height === null
            );
            const lcfCoverImages = document.querySelectorAll(
                `.lcfCoverImage.${container.coverFlowId}`
            );
            const initialPopulation = Array.from(
                Object.values(lcfCoverImages)
            ).every(image => image.height === 0);
            let initialSetImageHeight;
            if (!initialPopulation) {
                const centralImage =
                    lcfCoverImages[Math.floor(lcfCoverImages.length / 2)];
                initialSetImageHeight = centralImage.height;
            }
            /** This handles the default case with images served via their urls. */
            if (imageArrayExistent) {
                const imagesMaxHeight = processHeights(
                    lcfCoverImageHeights,
                    config
                );
                addGlobalStyle(
                    ".lcfCoverImage",
                    `height: ${imagesMaxHeight}px`,
                    container
                );
                const localCurrentItemContainers = Array.from(
                    currentItemContainers
                );
                lcfItemContainers = lcfItemContainers.filter(
                    lcfItemContainer =>
                        !localCurrentItemContainers.includes(lcfItemContainer)
                );
                lcfItemContainers.forEach(lcfCardBody => {
                    const lcfItemId = getLcfItemId(lcfCardBody);
                    const lcfItemCurrent = flattenedResults.filter(
                        lcfEntity => lcfEntity.id === lcfItemId
                    )[0];
                    /** Updates the imageComputedWidth property if the tallest image is still
                     * shorter than the coverImageFallbackHeight.   */
                    lcfItemCurrent.updateMaxHeight(
                        initialSetImageHeight || imagesMaxHeight
                    );
                    lcfItemCurrent.updateDimensions();
                    /** Sets width of the whole card. */
                    addInlineStyle(
                        `lcfItemContainer.${lcfItemCurrent.id}`,
                        `flex-basis: ${lcfItemCurrent.imageComputedWidth + 2}px;`,
                        container
                    );
                });
            }
            /** This handles images served via external sources. */
            if (!imageArrayExistent) {
                lcfCoverImages.forEach(lcfCoverImage =>
                    lcfCoverImage.classList.add("d-none")
                );
            }
            /** Hides the loading animation. */
            const lcfLoadingAnimation = document.querySelector(
                `.lcfLoadingAnimation.${container.coverFlowId}`
            );
            lcfLoadingAnimation.classList.add("d-none");
            /** Removes d-none from all item containers and shows the content. */
            lcfItemContainers.forEach(lcfItemContainer => {
                lcfItemContainer.classList.remove("d-none");
            });
            const shelfBrowserReference =
                document.getElementById("shelfbrowser");
            if (
                shelfBrowserReference &&
                shouldScrollShelfBrowserIntoView(config)
            ) {
                setTimeout(() => shelfBrowserReference.scrollIntoView(), 100);
            }
            container.isScrollable();
            if (
                config.coverFlowContext === "default" &&
                window.screen.width >= config.gridCoverFlowBreakpoints.s
            ) {
                const lcfNavigationButtonRight = document.querySelector(
                    `.lcfNavigationButtonRight.${container.coverFlowId}`
                );
                const lcfNavigationButtonLeft = document.querySelector(
                    `.lcfNavigationButtonLeft.${container.coverFlowId}`
                );
                if (container.scrollable) {
                    lcfNavigationButtonRight.classList.remove("d-none");
                    lcfNavigationButtonLeft.classList.remove("d-none");
                }
            }
            container.updateNavigationButtonReferences();
            if (container.scrollable) {
                container.hideOrShowButton();
            }
            return flattenedResults;
        } catch (error) {
            return console.trace(
                `Looks like something went wrong in ${settlePromises.name} ->`,
                error
            );
        }
    }

    /**
     * Pre-render step: resolve any promised cover URLs, preload the cover images
     * to get their dimensions, wrap everything as LcfEntities and hand off to
     * settlePromises for layout.
     * @param {Object} data - formatted items keyed by domId.
     * @param {Config} config
     * @param {Container} container
     * @param {NodeList} currentItemContainers - cards already present (shelf-browser extension).
     * @returns {Promise<LcfEntity[]>} the settled entities ([] on error).
     */
    async function prepare(data, config, container, currentItemContainers) {
        try {
            let lcfCoverImages = [];
            const lcfCoverFlowEntities = [];
            const externalData = Object.entries(data);
            /** To work in the data urls that possibly come with the external data
             *  the promises in which these are wrapped need to be resolved for a
             *  uniform array, that the rest of the application understands. */
            const cleanedData = [];
            externalData.forEach(datum => {
                const [id] = datum;
                cleanedData.push([id]);
            });
            const externalDataPromisedUrlsResolved = externalData.map(
                async datum => {
                    const [, entry] = datum;
                    let resolvedCoverurl;
                    if (isPromise(entry.coverurl)) {
                        resolvedCoverurl = await entry.coverurl;
                    }
                    return {
                        ...entry,
                        coverurl: resolvedCoverurl || entry.coverurl,
                    };
                }
            );
            const entries = await Promise.all(externalDataPromisedUrlsResolved);
            cleanedData.forEach((id, idx) => {
                id.push(entries[idx]);
            });
            Array.from(cleanedData).forEach(entry => {
                lcfCoverFlowEntities.push({
                    id: entry[0],
                    entry: entry[1],
                    image: null,
                });
                if (entry[1].coverurl) {
                    lcfCoverImages.push(
                        new LcfCoverImage(entry[1].coverurl).fetch()
                    );
                }
            });
            lcfCoverImages = await Promise.all(lcfCoverImages);
            Array.from(lcfCoverImages.entries()).forEach(entry => {
                const [index, image] = entry;
                lcfCoverFlowEntities[index].image = image;
            });
            const promisedCoverFlowEntities = entityToCoverFlow(
                config,
                lcfCoverFlowEntities
            );
            // eslint-disable-next-line max-len
            return await settlePromises(
                config,
                container,
                currentItemContainers,
                promisedCoverFlowEntities
            );
        } catch (error) {
            console.trace(
                `Looks like something went wrong in ${prepare.name} ->`,
                error
            );
            return [];
        }
    }

    /* eslint-disable max-len */
    /**
     * The public cover-flow instance (see createLcfInstance). Holds the caller's
     * config/data/container element and, on each setter, rebuilds the derived
     * Config/Data/Container. Call render() to draw.
     * @constructor
     */
    function LmsCoverFlow() {
        /**
         * Set config, data and container element at once.
         * @param {Object} configuration
         * @param {Object[]} data
         * @param {string} element - the container element's id.
         */
        this.setGlobals = (configuration, data, element) => {
            this.callerConfiguration = configuration;
            this.callerData = data;
            this.callerContainer = element;
            this.updateGlobals();
        };
        /** @param {Object} configuration */
        this.setConfig = configuration => {
            this.callerConfiguration = configuration;
            this.updateGlobals();
        };
        /** @returns {Object} the caller-supplied configuration. */
        this.getConfig = () => this.callerConfiguration;
        /** @param {Object[]} data */
        this.setData = data => {
            this.callerData = data;
            this.updateGlobals();
        };
        /** @param {string} element - the container element's id. */
        this.setContainer = element => {
            this.callerContainer = element;
            this.updateGlobals();
        };
        /** Rebuild the derived Config/Data/Container from the caller values. */
        this.updateGlobals = () => {
            this.config = new Config(this.callerConfiguration);
            this.data = new Data(this.config);
            this.container = new Container(this.callerContainer, this.config);
        };
        /**
         * Render the cover flow: resolve/harvest cover URLs, build the DOM for the
         * chosen context, size and reveal the cards, then wire tooltips, flip
         * cards and auto-scroll.
         * @param {('default'|'grid')} [coverFlowContext] - overrides config.coverFlowContext.
         * @returns {Promise<void>}
         */
        this.render = async coverFlowContext => {
            try {
                const checkedData = await Promise.all(
                    this.data.checkUrls(this.callerData)
                );
                let formattedData = format(checkedData);
                if (!(externalSources.info === "ekz")) {
                    await harvestUrls(
                        formattedData,
                        this.container,
                        this.config
                    );
                }
                formattedData = await cleanupUrls(this.config, formattedData);
                /** The check for the current card bodies is necessary, to filter
                 * the existing ones out for extension of the coverflow-component
                 * in the shelfbrowser context. */
                const currentItemContainers = document.querySelectorAll(
                    `.lcfItemContainer.${this.container.coverFlowId}`
                );
                build(
                    formattedData,
                    coverFlowContext || this.config.coverFlowContext,
                    this.container,
                    this.config,
                    this.config.coverFlowCustomClasses
                );
                const coverFlowEntities = await prepare(
                    formattedData,
                    this.config,
                    this.container,
                    currentItemContainers
                );
                /** Shelfbrowser offset calculations. */
                const newOffsetWidth = [];
                const computedFontSize = calculateComputedFontSize(
                    this.callerContainer
                );
                /** Tooltip logic. */
                coverFlowEntities.forEach(entry => {
                    const lcfNodesOfSingleCoverImageWrapper =
                        document.querySelectorAll(
                            `.${entry.id}.${this.container.coverFlowId}`
                        );
                    const currentLcfItemContainer = document.querySelector(
                        `.lcfItemContainer.${entry.id}`
                    );
                    addDataTooltip(currentLcfItemContainer, entry);
                    /** Data population. */
                    lcfNodesOfSingleCoverImageWrapper.forEach(node => {
                        populateTagAttributes(node, formattedData);
                    });
                    /** Shelfbrowser offset array population. */
                    if (
                        this.config.shelfBrowserExtendedCoverFlow &&
                        this.config.shelfBrowserButtonDirection === "left"
                    ) {
                        const lcfItemContainer =
                            lcfNodesOfSingleCoverImageWrapper[0];
                        newOffsetWidth.push(lcfItemContainer.offsetWidth);
                    }
                    /** Flipcard logic. */
                    addFlipCards({
                        id: entry.id,
                        config: this.config,
                        containerReference: this.container.coverFlowId,
                    });
                });
                /** Shelfbrowser offset execution. */
                if (
                    this.config.shelfBrowserExtendedCoverFlow &&
                    this.config.shelfBrowserButtonDirection === "left"
                ) {
                    this.container.reference.scrollLeft +=
                        calculateCoverFlowPlusGaps(
                            newOffsetWidth,
                            computedFontSize
                        );
                }
            } catch (error) {
                console.trace(
                    `Looks like something went wrong in ${this.render.name} ->`,
                    error
                );
            }
            /** Autoscroll logic. */
            addAutoScroll({ config: this.config, container: this.container });
            /** Conditionally hide or show aspects of card bodies. */
            changeAspectVisibility({
                config: this.config,
                containerReference: this.container.coverFlowId,
            });
        };
    }

    /**
     * Public factory for a cover-flow instance.
     * @returns {LmsCoverFlow}
     */
    // eslint-disable-next-line import/no-cycle
    function createLcfInstance() {
        return new LmsCoverFlow();
    }

    /**
     * Apply a set of option overrides onto a config object, in place.
     * @param {Object} configuration - mutated and returned.
     * @param {Object} changes - option -> value overrides.
     * @returns {Object} the mutated configuration.
     */
    function overrideConfig(configuration, changes) {
        const modifiedConfiguration = configuration;
        arrFromObjEntries(changes).forEach(change => {
            const [option, value] = change;
            modifiedConfiguration[option] = value;
        });
        return modifiedConfiguration;
    }

    /** Caller overrides applied on top of the shelf-browser default config. */
    const shelfBrowserConfig = new Observable({});

    /**
     * Render (or extend) the shelf-browser cover flow from a nearby-items API
     * response, mapping the items to the cover-flow data shape and wiring the
     * paging callback.
     * @param {Object} params
     * @param {Object} params.newlyLoadedItems - the API response (items + prev/next).
     * @param {boolean} [params.extendedCoverFlow=false] - true when paging, not opening.
     * @param {?('left'|'right')} [params.buttonDirection=null]
     * @param {Function} params.loadNewShelfBrowserItems - paging callback.
     * @param {string} params.coverFlowId - the container element's id.
     * @returns {void}
     */
    // eslint-disable-next-line max-len
    function extendCurrentCoverFlow({
        newlyLoadedItems,
        extendedCoverFlow = false,
        buttonDirection = null,
        loadNewShelfBrowserItems,
        coverFlowId,
    }) {
        const shelfBrowserItems = newlyLoadedItems.items.map(item => ({
            biblionumber: item.biblionumber,
            title: item.title,
            coverurl: item.coverurl,
            coverhtml: item.coverhtml,
            itemCallNumber: item.itemcallnumber,
            referenceToDetailsView: `/cgi-bin/koha/opac-detail.pl?biblionumber=${item.biblionumber}`,
        }));
        const nearbyItems = {
            previousItemNumber: newlyLoadedItems.prev_item
                ? newlyLoadedItems.prev_item.itemnumber
                : null,
            nextItemNumber: newlyLoadedItems.next_item
                ? newlyLoadedItems.next_item.itemnumber
                : null,
        };
        const lmscoverflow = createLcfInstance();
        let shelfBrowserCoverFlowConfig = {
            coverImageFallbackHeight: 210,
            coverFlowTooltips: false,
            coverFlowCardBody: {
                lcfMediaAuthor: false,
                lcfMediaTitle: true,
                lcfMediaItemCallNumber: true,
            },
            coverFlowContext: "default",
            coverFlowFlippableCards: false,
            coverFlowShelfBrowser: true,
            coverFlowButtonsCallback: { loadNewShelfBrowserItems, nearbyItems },
            shelfBrowserExtendedCoverFlow: extendedCoverFlow,
            shelfBrowserButtonDirection: buttonDirection,
            shelfBrowserCurrentEventListeners: instance,
            shelfBrowserScrollIntoView: true,
        };
        // eslint-disable-next-line max-len
        shelfBrowserCoverFlowConfig = overrideConfig(
            shelfBrowserCoverFlowConfig,
            shelfBrowserConfig.value
        );
        lmscoverflow.setGlobals(
            shelfBrowserCoverFlowConfig,
            shelfBrowserItems,
            coverFlowId
        );
        lmscoverflow.render();
    }

    /**
     * GET a request URI and return its parsed JSON body.
     * @param {string} requestURI
     * @returns {Promise<*>}
     */
    async function fetchItemData(requestURI) {
        const options = {
            method: "GET",
            mode: "cors",
            cache: "no-cache",
            credentials: "same-origin",
            headers: {
                "Content-Type": "application/json",
            },
            redirect: "follow",
        };
        const response = await fetch(requestURI, options);
        return response.json();
    }

    /**
     * Paging callback: fetch the previous/next nearby item for the given
     * direction (when one exists) and extend the shelf-browser cover flow with it.
     * @param {{previousItemNumber: ?number, nextItemNumber: ?number}} nearbyItems
     * @param {'left'|'right'} buttonDirection
     * @returns {Promise<void>}
     */
    async function loadNewShelfBrowserItems(nearbyItems, buttonDirection) {
        const { previousItemNumber, nextItemNumber } = nearbyItems;
        const coverFlowId = "lmscoverflow";
        const args = {
            extendedCoverFlow: true,
            buttonDirection,
            loadNewShelfBrowserItems,
            instance,
            coverFlowId,
        };
        if (buttonDirection === "left" && previousItemNumber) {
            const resultPrevious = fetchItemData(
                nearbyItemsRequestURI({
                    itemnumber: previousItemNumber,
                    quantity: 1,
                })
            );
            resultPrevious.then(result =>
                extendCurrentCoverFlow({ newlyLoadedItems: result, ...args })
            );
        } else if (buttonDirection === "right" && nextItemNumber) {
            const resultNext = fetchItemData(
                nearbyItemsRequestURI({
                    itemnumber: nextItemNumber,
                    quantity: 1,
                })
            );
            resultNext.then(result =>
                extendCurrentCoverFlow({ newlyLoadedItems: result, ...args })
            );
        } else {
            console.trace(
                `Looks like something went wrong in ${loadNewShelfBrowserItems.name}`
            );
        }
    }

    /**
     * Public entry point (exported as `ShelfBrowser`). Wires every
     * `.lmscoverflow-shelfbrowser` trigger so clicking one opens `#shelfbrowser`,
     * fetches the item's neighbours, renders the cover flow and builds the
     * heading with a close control.
     * @param {Object} params
     * @param {Object} [params.header] - heading label templates (with a
     *   `{starting_*}` placeholder each).
     * @param {Object} [params.configuration] - overrides merged into the
     *   shelf-browser config via shelfBrowserConfig.
     * @returns {void}
     */
    function shelfBrowser({
        header = {
            header_browsing: "Browsing {starting_homebranch} shelves",
            header_location: "Shelving location: {starting_location}",
            header_collection: "Collection: {starting_ccode}",
            header_close: "Close shelf",
        },
        configuration,
    }) {
        if (
            configuration &&
            !(Object.keys(configuration).length === 0) &&
            Object.getPrototypeOf(configuration) === Object.prototype
        ) {
            shelfBrowserConfig.value = configuration;
        }
        const lmsCoverFlowShelfBrowser = document.querySelectorAll(
            ".lmscoverflow-shelfbrowser"
        );
        const coverFlowId = "lmscoverflow";
        const shelfBrowserReference = document.getElementById("shelfbrowser");
        const shelfBrowserHeading = document.createElement("h5");
        shelfBrowserHeading.id = "shelfBrowserHeading";
        const shelfBrowserClose = document.createElement("a");
        shelfBrowserClose.textContent = header.header_close;
        shelfBrowserClose.setAttribute("role", "button");
        shelfBrowserClose.style.fontSize = ".9rem";
        shelfBrowserClose.classList.add(
            "font-weight-light",
            "p-2",
            "shelfBrowserClose"
        );
        shelfBrowserClose.addEventListener("click", () => {
            shelfBrowserReference.classList.add("d-none");
        });
        const main = () => {
            lmsCoverFlowShelfBrowser.forEach(node => {
                node.addEventListener("click", async e => {
                    e.preventDefault();
                    const target = e.target;
                    /** If new shelves are opened, the event listeners for the
                     * previous shelf have to be removed. The instance properties
                     * of left and right have to be reset to false again, so the
                     * new event listeners are properly populated with data. */
                    shelfBrowserReference.classList.remove("d-none");
                    const container = document.getElementById(coverFlowId);
                    container.replaceWith(container.cloneNode(true));
                    if (!document.getElementById("shelfBrowserHeading")) {
                        shelfBrowserReference.insertBefore(
                            shelfBrowserHeading,
                            shelfBrowserReference.firstChild
                        );
                    }
                    instance.setLeftToFalse();
                    instance.setRightToFalse();
                    const { /* biblionumber, */ itemnumber } = target.dataset;
                    removeChildNodes(document.getElementById(coverFlowId));
                    const result = await fetchItemData(
                        nearbyItemsRequestURI({ itemnumber, quantity: 7 })
                    );
                    shelfBrowserHeading.classList.add(
                        "border",
                        "border-secondary",
                        "rounded",
                        "p-3",
                        "w-75",
                        "centered",
                        "mx-auto",
                        "shadow-sm",
                        "text-center"
                    );
                    shelfBrowserHeading.textContent = `
                    ${result.starting_homebranch && result.starting_homebranch.description ? header.header_browsing.replace("{starting_homebranch}", result.starting_homebranch.description) : ""}${result.starting_location && result.starting_location.description ? "," : ""}
                    ${result.starting_location && result.starting_location.description ? header.header_location.replace("{starting_location}", result.starting_location.description) : ""}${result.starting_ccode && result.starting_ccode.description ? "," : ""}
                    ${result.starting_ccode && result.starting_ccode.description ? header.header_collection.replace("{starting_ccode}", result.starting_ccode.description) : ""}
                    `;
                    shelfBrowserHeading.appendChild(shelfBrowserClose);
                    extendCurrentCoverFlow({
                        newlyLoadedItems: result,
                        loadNewShelfBrowserItems,
                        coverFlowId,
                    });
                });
            });
        };
        main();
    }

    /**
     * Public class (exported as `CoverflowByQuery`). Renders a labelled cover
     * flow driven by a search query against the coverflow-by-query endpoint,
     * paging through result windows and optionally coordinating an external
     * cover source.
     */
    class CoverflowByQuery {
        id;
        query;
        label;
        endpoint;
        offset;
        maxcount;
        data;
        positions;
        config;
        externalSourceInUse;
        /**
         * @param {Object} params
         * @param {string} params.id - the container element's id.
         * @param {string} params.query
         * @param {string} params.label - heading text.
         * @param {string} [params.endpoint]
         * @param {number} params.offset - starting result offset.
         * @param {number} params.maxcount - results per window.
         * @param {{coce?, openLibrary?, google?, ekz?}} params.externalSourcesInUse
         */
        constructor({
            id,
            query,
            label,
            endpoint,
            offset,
            maxcount,
            externalSourcesInUse,
        }) {
            const instance = new EventListeners();
            instance.data = {
                left: false,
                right: false,
                leftHandler: null,
                rightHandler: null,
            };
            const { coce, openLibrary, google, ekz } = externalSourcesInUse;
            this.id = id;
            this.query = query;
            this.label = label;
            this.endpoint = endpoint;
            this.offset = offset;
            this.maxcount = maxcount;
            this.externalSourceInUse = coce || openLibrary || google || ekz;
            this.data = {};
            this.positions = {
                left: this.offset,
                right: this.offset + this.maxcount,
            };
            this.config = {
                coverImageFallbackHeight: 210,
                coverFlowCardBody: {
                    lcfMediaAuthor: true,
                    lcfMediaTitle: true,
                    lcfMediaItemCallNumber: false,
                },
                coverFlowContext: "default",
                coverFlowShelfBrowser: true,
                shelfBrowserCurrentEventListeners: instance,
                coverFlowButtonsCallback: {
                    loadNewShelfBrowserItems: this.loadPortion.bind(this),
                    nearbyItems: {
                        previousItemNumber: this.offset - this.maxcount,
                        nextItemNumber: this.offset + this.maxcount,
                    },
                },
            };
            this.renderHeader();
        }
        /**
         * Fetch the current result window, add each item's detail-view link, and
         * subscribe to the external cover source when one is in use.
         * @returns {Promise<void>}
         */
        async prepareCoverflow() {
            this.data = await fetchItemData(
                byQueryRequestURI({
                    query: this.query,
                    offset: this.offset,
                    maxcount: this.maxcount,
                })
            );
            this.data.items.forEach(item => {
                const record = item;
                record.referenceToDetailsView = `/cgi-bin/koha/opac-detail.pl?biblionumber=${item.biblionumber}`;
            });
            if (this.externalSourceInUse) {
                this.subscribeToLoadingState();
            }
        }
        /**
         * Register the external cover source: mark ekz (synchronous) via
         * externalSources.info, or subscribe its callback to run when loading
         * completes.
         */
        subscribeToLoadingState() {
            if (
                this.externalSourceInUse &&
                Object.keys(this.externalSourceInUse).length === 0 &&
                Object.getPrototypeOf(this.externalSourceInUse) ===
                    Object.prototype
            ) {
                externalSources.info = "ekz";
                return;
            }
            externalSources.subscribe(isLoaded => {
                if (isLoaded) {
                    if (this.externalSourceInUse.args) {
                        this.externalSourceInUse.callback(
                            ...this.externalSourceInUse.args
                        );
                    } else {
                        this.externalSourceInUse.callback();
                    }
                }
            });
        }
        /**
         * Paging callback for the query cover flow: step the offset one window in
         * the given direction (within bounds) and re-render.
         * @param {*} nearbyItems - unused; kept for the paging callback signature.
         * @param {'left'|'right'} buttonDirection
         * @returns {Promise<void>}
         * @throws {Error} when there is nothing to load in that direction.
         */
        async loadPortion(nearbyItems, buttonDirection) {
            this.config = {
                ...this.config,
                shelfBrowserExtendedCoverFlow: true,
                shelfBrowserButtonDirection: buttonDirection,
            };
            if (buttonDirection === "left" && this.positions.left > 0) {
                this.offset -= this.maxcount;
                this.prepareCoverflow();
                this.render();
                this.positions.left -= this.data.count;
            } else if (
                buttonDirection === "right" &&
                this.positions.right < this.data.totalcount
            ) {
                this.offset += this.maxcount;
                this.prepareCoverflow();
                this.render();
                this.positions.right += this.data.count;
            } else {
                throw new Error(
                    `Nothing to load in this direction -> ${buttonDirection}`
                );
            }
        }
        /** Insert the label heading and wrap the container in a <section>. */
        renderHeader() {
            const coverflowQueryContainer = document.getElementById(this.id);
            const section = document.createElement("section");
            const label = document.createElement("header");
            label.textContent = this.label;
            label.classList.add("h3", "text-muted", "pl-3");
            coverflowQueryContainer.insertAdjacentElement(
                "beforebegin",
                section
            );
            section.appendChild(label);
            section.appendChild(coverflowQueryContainer);
        }
        /** Render the current result window through a fresh cover-flow instance. */
        render() {
            const lmscoverflow = createLcfInstance();
            lmscoverflow.setGlobals(this.config, this.data.items, this.id);
            if (this.externalSourceInUse) {
                this.subscribeToLoadingState();
            }
            lmscoverflow.render();
        }
    }

    exports.CoverflowByQuery = CoverflowByQuery;
    exports.ShelfBrowser = shelfBrowser;
    exports.createLcfInstance = createLcfInstance;
    exports.externalSources = externalSources;

    /* Internal test seam — NOT part of the public API. Exposes the pure helpers
       for direct unit testing without leaking them to the global scope (in the
       browser they live under window.LMSCoverFlow._internals, nowhere else). */
    exports._internals = {
        getLcfItemId,
        arrFromObjEntries,
        additionalProperties,
        attributeInstructionsFor,
        describeArgShape,
        instructionsForClass,
        isTextContent,
        setAttrOrText,
        applyInstructions,
        isPromise,
        processHeights,
        flattenPromiseResults,
        calculateCoverFlowPlusGaps,
        resyncExecution,
        generateId,
        shouldScrollShelfBrowserIntoView,
        nearbyItemsRequestURI,
        generatedCoverRequestURI,
        byQueryRequestURI,
    };

    Object.defineProperty(exports, "__esModule", { value: true });
});
