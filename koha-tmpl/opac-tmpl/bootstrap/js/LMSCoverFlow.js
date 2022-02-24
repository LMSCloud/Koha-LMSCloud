/* This method can be used to create a global style tag inside the head */
// TODO: Check if style tag already exists and use a unique name for style.
function createStyleTag() {
    const lcfStyleReference = document.getElementById('lcfStyle');
    if (!lcfStyleReference) {
        const lcfStyle = document.createElement('style');
        lcfStyle.textContent = '👋 Styles injected by LMSCoverFlow are obtainable through logging out lcfStyle.sheet';
        lcfStyle.id = 'lcfStyle';
        document.head.appendChild(lcfStyle);
    }
}
/* end of createStyleTag() */

function createTagAndSetClasses(aspect, index, textContent, shelfBrowserItem = false) {
    let lcfItem;
    if (shelfBrowserItem === true) {
        lcfItem = aspect.tag;
    }
    else {
        lcfItem = document.createElement(aspect.tag);
    }
    lcfItem.classList.add(aspect.reference);
    lcfItem.classList.add(index);
    /* Adds reference and index as classNames to lcfItem. */
    if (aspect.additionalClasses) {
        lcfItem.classList.add(...aspect.additionalClasses);
    }
    if (textContent) {
        lcfItem.textContent = textContent;
    }
    return {
        lcfItem,
        aspect,
        index,
    };
}

function appendToDom(newTagWithClasses, container, buttonDirection, currentIndex) {
    /* If the aspect.parent references the main container (lmscoverflow), it appends the
      current item to that handle. Otherwise it looks up the parent in the LcfItemWrapperClass
      and appends to that element based on the context that the index provides. */
    const containerReferenceAsClass = container.reference.id;
    const lcfNavigationButtonRight = document.querySelector(`.lcfNavigationButtonRight.${containerReferenceAsClass}`);
    const lcfItemContainers = document.querySelectorAll(`.lcfItemContainer.${containerReferenceAsClass}`);
    /** If the new tag gets created in the shelfbrowser context, the element needs
       * to be inserted into the dom depending on the button direction that triggered
       * the loading of new titles. The new content gets inserted before the previously
       * rendered content if the left button is pressed and at the end of the container
       * if the right is pressed.
       */
    //   const insertAfter = (newNode: any, existingNode: Element) => {
    //     existingNode.parentNode.insertBefore(newNode, existingNode.nextSibling);
    //   };
    if (newTagWithClasses.aspect.parent !== container.reference) {
        const parentReference = document.querySelector(`.${newTagWithClasses.aspect.parent}.${newTagWithClasses.index}`);
        parentReference.appendChild(newTagWithClasses.lcfItem);
    }
    else if (newTagWithClasses.aspect.parent === container.reference && buttonDirection) {
        if (buttonDirection === 'right') {
            container.reference.insertBefore(newTagWithClasses.lcfItem, lcfNavigationButtonRight);
        }
        else {
            container.reference.insertBefore(newTagWithClasses.lcfItem, lcfItemContainers[0 + currentIndex]);
        }
    }
    else {
        newTagWithClasses.aspect.parent.appendChild(newTagWithClasses.lcfItem);
    }
}

/* This method can be used to append a compositedStyle to the globalStyleTag */
function addGlobalStyle(selector, newStyle, container) {
    const containerReferenceAsClass = container.reference.id;
    const lcfStyle = document.getElementById('lcfStyle');
    if (selector.includes('#') || selector.includes(':root')) {
        const compositedStyle = `${selector} {${newStyle}}`;
        lcfStyle.sheet.insertRule(compositedStyle);
    }
    else {
        const compositedStyle = selector.includes('@')
            ? `${selector} {${newStyle}}`
            : `${selector}.${containerReferenceAsClass} {${newStyle}}`;
        lcfStyle.sheet.insertRule(compositedStyle);
    }
}

function addInlineStyle(selector, newStyle, container) {
    const containerReferenceAsClass = container.reference.id;
    const targetElement = document.querySelector(`.${selector}.${containerReferenceAsClass}`);
    targetElement.setAttribute('style', newStyle);
}

function createNavigationButton(newTagWithClasses, direction, container) {
    const CONTAINER = container;
    const NEW_TAG_WITH_CLASSES = newTagWithClasses;
    const scrollContainerToRight = () => {
        CONTAINER.reference.scrollLeft
            += (CONTAINER.reference.clientWidth / 1.5);
    };
    const scrollContainerToLeft = () => {
        CONTAINER.reference.scrollLeft
            -= (CONTAINER.reference.clientWidth / 1.5);
    };
    if (direction === 'left') {
        NEW_TAG_WITH_CLASSES.lcfItem.onmousedown = scrollContainerToLeft;
    }
    else {
        NEW_TAG_WITH_CLASSES.lcfItem.onmousedown = scrollContainerToRight;
    }
    return NEW_TAG_WITH_CLASSES;
}

function domParserSupport() {
    if (!window.DOMParser)
        return false;
    const domParser = new DOMParser();
    try {
        domParser.parseFromString('x', 'text/html');
    }
    catch (error) {
        return false;
    }
    return true;
}
function stringToHtml(coverhtml) {
    const sanitizedCoverhtml = coverhtml.replace(/>\s+|\s+</g, (m) => m.trim());
    if (domParserSupport) {
        const domParser = new DOMParser();
        const parsedHtml = domParser.parseFromString(sanitizedCoverhtml, 'text/html');
        return parsedHtml.body;
    }
    const generatedDom = document.createElement('div');
    generatedDom.innerHTML = sanitizedCoverhtml;
    return generatedDom;
}
function recursiveArrayPopulation(arrayOfDomNodes) {
    if (arrayOfDomNodes[0].childElementCount === 0) {
        return arrayOfDomNodes[0];
    }
    arrayOfDomNodes.push(arrayOfDomNodes[0].firstChild);
    return recursiveArrayPopulation(arrayOfDomNodes[0].childNodes);
}
function removeChildNodes(parent) {
    while (parent.firstChild) {
        parent.removeChild(parent.lastChild);
    }
    return parent;
}

function build(data, coverFlowContext, container, config) {
    class LcfItemWrapper {
        tag;
        reference;
        parent;
        additionalClasses;
        constructor(tag, reference, parent, additionalClasses) {
            this.tag = tag;
            this.reference = reference;
            this.parent = parent;
            this.additionalClasses = additionalClasses;
        }
    }
    const containerReferenceAsClass = container.reference.id;
    // TODO: Add possibility to add additional custom classes to elements.
    const lcfLoadingAspects = [
        new LcfItemWrapper('div', 'lcfLoadingAnimation', container.reference, [containerReferenceAsClass]),
    ];
    const lcfNavigationAspects = [
        new LcfItemWrapper('button', 'lcfNavigationButtonLeft', container.reference, ['btn', 'd-none', containerReferenceAsClass]),
        new LcfItemWrapper('button', 'lcfNavigationButtonRight', container.reference, ['btn', 'd-none', containerReferenceAsClass]),
    ];
    const lcfItemWrapperAspects = [
        new LcfItemWrapper('div', 'lcfItemContainer', container.reference, ['d-none', 'card', 'border-0', 'flipCard', containerReferenceAsClass]),
        new LcfItemWrapper('div', 'lcfFlipCard', 'lcfItemContainer', ['border', 'rounded', 'flipCardInner', containerReferenceAsClass]),
        /** Below are tags on the front of the flipCard. */
        new LcfItemWrapper('div', 'lcfFlipCardFront', 'lcfFlipCard', ['flipCardFront', containerReferenceAsClass]),
        new LcfItemWrapper('div', 'lcfCoverImageWrapper', 'lcfFlipCardFront', ['card-img-top', containerReferenceAsClass]),
        new LcfItemWrapper('a', 'lcfAnchor', 'lcfCoverImageWrapper', [containerReferenceAsClass]),
        new LcfItemWrapper('img', 'lcfCoverImage', 'lcfAnchor', [containerReferenceAsClass]),
        new LcfItemWrapper('div', 'lcfCardBody', 'lcfFlipCardFront', ['card-body', 'p-2', 'text-center', containerReferenceAsClass]),
        new LcfItemWrapper('p', 'lcfMediaAuthor', 'lcfCardBody', ['card-text', 'text-muted', 'text-truncate', 'font-weight-light', 'mb-0', 'text-custom-12', containerReferenceAsClass]),
        new LcfItemWrapper('p', 'lcfMediaItemCallNumber', 'lcfCardBody', ['card-text', 'text-muted', 'text-truncate', 'font-weight-light', 'mb-0', 'text-custom-12', containerReferenceAsClass]),
        new LcfItemWrapper('p', 'lcfMediaTitle', 'lcfCardBody', ['card-text', 'text-truncate', 'font-weight-lighter', 'mb-0', 'text-custom-12', containerReferenceAsClass]),
    ];
    if (config.coverFlowFlippableCards) {
        lcfItemWrapperAspects.push(...[
            /** These tags are on the back of the flipCard. */
            new LcfItemWrapper('div', 'lcfFlipCardBack', 'lcfFlipCard', ['flipCardBack', containerReferenceAsClass]),
            new LcfItemWrapper('p', 'lcfMediaISBD', 'lcfFlipCardBack', [containerReferenceAsClass]),
            new LcfItemWrapper('button', 'lcfFlipCardButton', 'lcfItemContainer', ['shadow', containerReferenceAsClass]),
        ]);
    }
    /* Every group of elements (called aspects in this case) gets it's own array. */
    createStyleTag();
    const GLOBAL_STYLES = [
        [
            '.text-custom-12',
            'font-size: .75rem',
        ],
    ];
    GLOBAL_STYLES.forEach((style) => {
        addGlobalStyle(style[0], style[1], container);
    });
    const LOADING_ANIMATION = [
        [
            '.lcfLoadingAnimation',
            `
            border: 16px solid whitesmoke;
            border-top: 16px solid #0275d8;
            border-radius: 50%;
            height: ${config.coverImageFallbackHeight}px;
            width: ${config.coverImageFallbackHeight}px;
            margin: auto;
            -webkit-animation: spin 3s linear infinite;
            animation: spin 3s linear infinite;
            `,
        ],
        [
            '@-webkit-keyframes spin',
            `
            0% { -webkit-transform: rotate(0deg); transform: rotate(0deg); }
            100% { -webkit-transform: rotate(360deg); transform: rotate(360deg); }
            `,
        ],
        [
            '@keyframes spin',
            `
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
            `,
        ],
    ];
    LOADING_ANIMATION.forEach((style) => {
        addGlobalStyle(style[0], style[1], container);
    });
    if (config.coverFlowFlippableCards) {
        const FLIP_CARDS = [
            [
                '.flipCard',
                `
                -webkit-perspective: 1000px;
                perspective: 1000px;
                `,
            ],
            [
                '.flipCardInner',
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
                '.flipCardFront, .flipCardBack',
                `
                -webkit-backface-visibility: hidden;
                backface-visibility: hidden;
                `,
            ],
            [
                '.flipCardBack',
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
                '.cardIsFlipped',
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
                '.buttonIsFlipped',
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
                '.lcfFlipCardButton',
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
                '.flipCard:hover .lcfFlipCardButton',
                `
                -webkit-animation: popup .1s linear 1 forwards;
                animation: popup .1s linear 1 forwards;
                `,
            ],
            [
                '@-webkit-keyframes popup',
                `
                0% {width: 0; height: 0;}
                100% {width: 2rem; height: 2rem; font-size: medium; visibility: visible;}

                `,
            ],
            [
                '@keyframes popup',
                `
                0% {width: 0; height: 0;}
                100% {width: 2rem; height: 2rem; font-size: medium; visibility: visible;}
                `,
            ],
        ];
        /** Here we apply the flipCard logic to our dom-structure. */
        FLIP_CARDS.forEach((style) => {
            addGlobalStyle(style[0], style[1], container);
        });
    }
    if (!config.coverFlowFlippableCards && config.coverFlowHighlightingStyle === 'default') {
        const RAISE_SHADOW_ONHOVER = [
            [
                '.lcfItemContainer:hover',
                `
                -webkit-box-shadow: 0px 5px 15px 3px rgba(0,0,0,0.1);
                box-shadow: 0px 5px 15px 3px rgba(0,0,0,0.1);
                position: relative;
                top: -3px;
                `,
            ],
        ];
        RAISE_SHADOW_ONHOVER.forEach((style) => {
            addGlobalStyle(style[0], style[1], container);
        });
    }
    if (config.coverFlowFlippableCards || config.coverFlowHighlightingStyle === 'coloredFrame') {
        const HIGHLIGHT_ONHOVER = [
            [
                '.lcfFlipCard:hover',
                `
                outline: 1px solid #6610f2 !important;
                `,
            ],
        ];
        HIGHLIGHT_ONHOVER.forEach((style) => {
            addGlobalStyle(style[0], style[1], container);
        });
    }
    const DEFAULT_CONTEXT = [
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
            '.lcfItemContainer',
            `
            -webkit-box-flex: 0;
            -ms-flex-positive: 0;
            flex-grow: 0;
            -ms-flex-negative: 0;
            flex-shrink: 0;
            `,
        ],
        [
            'lcfLoadingAnimation',
            `
            -ms-grid-column: 2;
            -ms-grid-column-span: 2;
            grid-column: 2 / span 2;
            `,
        ],
    ];
    const RECOMMENDER_GRID_CONTEXT = [
        [
            ':root',
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
            '.lcfCoverImageWrapper',
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
            '.lcfCoverImage',
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
        // TODO: make card-top background configurable.
    ];
    if (coverFlowContext === 'default' && window.screen.width >= config.gridCoverFlowBreakpoints.s) {
        DEFAULT_CONTEXT.forEach((style) => {
            addGlobalStyle(style[0], style[1], container);
        });
        /* Here, some global css rules are applied, before the content gets rendered.
            These styles apply to the main lmscoverflow container. */
        if (!config.shelfBrowserExtendedCoverFlow) {
            lcfLoadingAspects.forEach((aspect) => {
                appendToDom(createTagAndSetClasses(aspect, 'lcfLoading'), container);
            });
        }
        /* We create the left navigation Button manually, before the rest of the content
            gets rendered. */
        if (!config.shelfBrowserExtendedCoverFlow) {
            appendToDom(createNavigationButton(createTagAndSetClasses(lcfNavigationAspects[0], 'lcfNavigation', '←'), 'left', container), container);
        }
        /* Here a wrapper gets created, that contains all necessary tags for an item. */
        Array.from(Object.keys(data).entries()).forEach((entry) => {
            const [index, key] = entry;
            /** The following if statement handles external elements,
             *  that are provided in the koha-shelfbrowser. */
            if (document.getElementById('shelfbrowser-testing')) {
                const generatedHtml = stringToHtml(data[key].coverhtml);
                const newElementsArray = Array.from(generatedHtml.children);
                recursiveArrayPopulation(newElementsArray);
                Array.from(newElementsArray.entries()).forEach((domNode) => {
                    newElementsArray[domNode[0]] = removeChildNodes(domNode[1]);
                });
                lcfItemWrapperAspects.forEach((aspect) => {
                    if (aspect.reference === 'lcfAnchor' && newElementsArray[0].tagName === 'A') {
                        appendToDom(createTagAndSetClasses(new LcfItemWrapper(newElementsArray[0], 'lcfAnchor', 'lcfCoverImageWrapper', [containerReferenceAsClass]), key, '', true), container);
                    }
                    else if (aspect.reference === 'lcfCoverImage' && newElementsArray[1].tagName === 'DIV') {
                        appendToDom(createTagAndSetClasses(new LcfItemWrapper(newElementsArray[1], 'lcfCoverImage', 'lcfAnchor', [containerReferenceAsClass]), key, '', true), container);
                    }
                    else {
                        appendToDom(createTagAndSetClasses(aspect, key), container);
                    }
                });
            }
            else {
                lcfItemWrapperAspects.forEach((aspect) => {
                    appendToDom(createTagAndSetClasses(aspect, key), container, config.shelfBrowserButtonDirection, index);
                });
            }
        });
        /* Finally we append the right navigation button to the end of the container. */
        if (!config.shelfBrowserExtendedCoverFlow) {
            appendToDom(createNavigationButton(createTagAndSetClasses(lcfNavigationAspects[1], 'lcfNavigation', '→'), 'right', container), container);
        }
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
        addInlineStyle('lcfNavigationButtonLeft', `
            ${lcfNavigationButtonsBaseStyles}
            left: 1rem;
            margin-right: 1rem;
            `, container);
        addInlineStyle('lcfNavigationButtonRight', `
            ${lcfNavigationButtonsBaseStyles}
            right: 1rem;
            margin-left: 1rem;
            `, container);
    }
    if (coverFlowContext === 'grid' || window.screen.width <= (config.gridCoverFlowBreakpoints.s - 1)) {
        RECOMMENDER_GRID_CONTEXT.forEach((style) => {
            addGlobalStyle(style[0], style[1], container);
        });
        /* Here, some global css rules are applied, before the content gets rendered.
            These styles apply to the main lmscoverflow container. */
        lcfLoadingAspects.forEach((aspect) => {
            appendToDom(createTagAndSetClasses(aspect, 'lcfLoading'), container);
        });
        /* Here a wrapper gets created, that contains all necessary tags for an item. */
        Object.keys(data).forEach((index) => {
            lcfItemWrapperAspects.forEach((aspect) => {
                appendToDom(createTagAndSetClasses(aspect, index), container);
            });
        });
    }
    if (document.getElementById('shelfbrowser')) {
        const SHELF_BROWSER = [
            [
                '#shelfbrowser',
                `

                `,
            ],
        ];
        SHELF_BROWSER.forEach((style) => {
            addGlobalStyle(style[0], style[1], container);
        });
    }
}
/* end of build() */

function generateId() {
    const randomValues = new Uint8Array(16);
    return `_${crypto.getRandomValues(randomValues)
        .join('')
        .toString()
        .substring(2, 9)}`;
}

function getLcfItemId(domNode) {
    return domNode.classList[1];
}

function processHeights(lcfCoverImageHeights, config) {
    const coverImageHeights = lcfCoverImageHeights.map((item) => item.imageHeight);
    const coverImagesMaximumHeight = Math.max(...coverImageHeights);
    return coverImagesMaximumHeight <= config.coverImageFallbackHeight
        ? coverImagesMaximumHeight : config.coverImageFallbackHeight;
}
/* end of processHeights() */

class LcfCoverImage {
    coverUrl;
    constructor(coverUrl) {
        this.coverUrl = coverUrl;
    }
    fetch() {
        return new Promise((resolve) => {
            const coverImage = new Image();
            coverImage.onload = () => resolve(coverImage);
            coverImage.src = this.coverUrl;
        });
    }
}

async function prepare(data, config, container, currentItemContainers) {
    // TODO: Enable feeding additional metadata to LcfEntity constructor.
    class LcfEntity {
        id;
        title;
        author;
        biblionumber;
        coverurl;
        referenceToDetailsView;
        itemCallNumber;
        imageHeight;
        imageWidth;
        imageAspectRatio;
        imageComputedWidth;
        coverhtml;
        constructor(id, title, author, biblionumber, coverurl, referenceToDetailsView, itemCallNumber, imageHeight, imageWidth, imageAspectRatio, imageComputedWidth, coverhtml) {
            this.id = id;
            this.title = title;
            this.author = author;
            this.biblionumber = biblionumber;
            this.coverurl = coverurl;
            this.referenceToDetailsView = referenceToDetailsView;
            this.itemCallNumber = itemCallNumber;
            this.imageHeight = imageHeight;
            this.imageWidth = imageWidth;
            this.imageAspectRatio = imageAspectRatio;
            this.imageComputedWidth = imageComputedWidth;
            this.coverhtml = coverhtml;
            this.id = id;
            this.title = title;
            this.author = author;
            this.biblionumber = biblionumber;
            this.referenceToDetailsView = referenceToDetailsView;
            this.itemCallNumber = itemCallNumber;
        }
        addCoverImageMetadata(height, width) {
            this.imageHeight = height;
            this.imageWidth = width;
            this.imageAspectRatio = this.calculateCoverImageAspectRatio();
            this.imageComputedWidth = config.coverImageFallbackHeight / this.imageAspectRatio;
        }
        calculateCoverImageAspectRatio() {
            return this.imageHeight / this.imageWidth;
        }
    }
    const flattenPromiseResults = (resultsArray) => {
        const flattenedResults = [];
        Object.keys(resultsArray).forEach((index) => {
            flattenedResults.push(resultsArray[index].value);
        });
        return flattenedResults;
    };
    const entityToCoverFlow = (currentId, currentEntry, promisedEntity, promisedCoverFlowEntities) => {
        try {
            const newLcfEntity = new LcfEntity(currentId, currentEntry.title, currentEntry.author, currentEntry.biblionumber, currentEntry.coverurl, currentEntry.referenceToDetailsView, currentEntry.itemCallNumber);
            const coverImage = promisedEntity;
            newLcfEntity.addCoverImageMetadata(coverImage.naturalHeight, coverImage.naturalWidth);
            promisedCoverFlowEntities.push(new Promise((resolve) => {
                resolve(newLcfEntity);
            }));
        }
        catch (error) {
            console.trace(`Looks like something went wrong in ${entityToCoverFlow.name} ->`, error);
        }
    };
    /* This promise chain is the main block for displaying covers. The global coverFlowEntities
     * Object gets flattened to promise level. The mapped imageHeights are used to set a universal
     * height for all images. Then the card widths are adjusted to the corresponding image widths.
     * Before the cards are displayed, a loading animation renders to bridge the gap between
     * awaiting all images and the depending methods for image sizing and so on. */
    const settlePromises = async (promisedEntities) => {
        try {
            const containerReferenceAsClass = container.reference.id;
            const result = await Promise.allSettled(promisedEntities);
            const flattenedResults = flattenPromiseResults(result);
            const lcfCoverImageHeights = flattenedResults.map((lcfEntity) => lcfEntity.imageHeight);
            addGlobalStyle(`.lcfCoverImage.${containerReferenceAsClass}`, `height: ${processHeights(lcfCoverImageHeights, config)}px`, container);
            let lcfItemContainers = Array.from(document.querySelectorAll(`.lcfItemContainer.${containerReferenceAsClass}`));
            const localCurrentItemContainers = Array.from(currentItemContainers);
            lcfItemContainers = lcfItemContainers.filter((lcfItemContainer) => !localCurrentItemContainers.includes(lcfItemContainer));
            lcfItemContainers.forEach((lcfCardBody) => {
                const lcfItemId = getLcfItemId(lcfCardBody);
                const lcfItemCurrent = flattenedResults.filter((lcfEntity) => lcfEntity.id === lcfItemId)[0];
                addInlineStyle(`lcfItemContainer.${lcfItemCurrent.id}`, `flex-basis: ${lcfItemCurrent.imageComputedWidth + 2}px;`, container);
            });
            const lcfLoadingAnimation = document.querySelector(`.lcfLoadingAnimation.${containerReferenceAsClass}`);
            lcfLoadingAnimation.classList.add('d-none');
            lcfItemContainers.forEach((lcfItemContainer) => {
                lcfItemContainer.classList.remove('d-none');
            });
            container.isScrollable();
            if (config.coverFlowContext === 'default' && window.screen.width >= config.gridCoverFlowBreakpoints.s) {
                const lcfNavigationButtonRight = document.querySelector(`.lcfNavigationButtonRight.${containerReferenceAsClass}`);
                const lcfNavigationButtonLeft = document.querySelector(`.lcfNavigationButtonLeft.${containerReferenceAsClass}`);
                if (container.scrollable) {
                    lcfNavigationButtonRight.classList.remove('d-none');
                    lcfNavigationButtonLeft.classList.remove('d-none');
                }
            }
            container.updateNavigationButtonReferences();
            if (container.scrollable) {
                container.hideOrShowButton();
            }
            return flattenedResults;
        }
        catch (error) {
            return console.trace(`Looks like something went wrong in ${settlePromises.name} ->`, error);
        }
    };
    const promisedCoverFlowEntities = [];
    let lcfCoverImages = [];
    const lcfCoverFlowEntities = [];
    const externalData = Object.entries(data);
    Array.from(externalData).forEach((entry) => {
        lcfCoverFlowEntities.push({ id: entry[0], entry: entry[1], image: null });
        lcfCoverImages.push(new LcfCoverImage(entry[1].coverurl).fetch());
    });
    lcfCoverImages = await Promise.all(lcfCoverImages);
    Array.from(lcfCoverImages.entries()).forEach((entry) => {
        const [index, image] = entry;
        lcfCoverFlowEntities[index].image = image;
    });
    lcfCoverFlowEntities.forEach((entity) => entityToCoverFlow(entity.id, entity.entry, entity.image, promisedCoverFlowEntities));
    return settlePromises(promisedCoverFlowEntities);
}

function LMSCoverFlow(element, configuration, data) {
    const self = {
        data: {
            formatted: {},
            isValidUrl(urlInQuestion) {
                let url;
                try {
                    url = new URL(urlInQuestion);
                }
                catch (_) {
                    return false;
                }
                return url.protocol === 'http:' || url.protocol === 'https:';
            },
            async checkIfFileExists(resourceInQuestion) {
                const response = await fetch(resourceInQuestion, {
                    method: 'GET',
                    mode: 'cors',
                });
                return response.ok;
            },
            checkForUnresolvableResources(localData) {
                const LOCAL_DATA = localData.map(async (entry) => {
                    let newEntry = entry;
                    if (entry.coverurl === '') {
                        console.error('Resource url is an empty string.');
                        newEntry = { ...entry, coverurl: self.config.coverImageFallbackUrl };
                    }
                    if (entry.coverurl === undefined) {
                        console.error('Resource url is undefined.');
                        newEntry = { ...entry, coverurl: self.config.coverImageFallbackUrl };
                    }
                    const fileExists = await this.checkIfFileExists(entry.coverurl);
                    if (!fileExists) {
                        console.error('Resource url is non-resolvable.');
                        newEntry = { ...entry, coverurl: self.config.coverImageFallbackUrl };
                    }
                    return newEntry;
                });
                return LOCAL_DATA;
            },
            async format(localData) {
                localData.map((entry) => (this.formatted[generateId()] = entry));
            },
        },
        config: {
            coverImageFallbackHeight: configuration.coverImageFallbackHeight || 210,
            coverImageFallbackUrl: configuration.coverImageFallbackUrl || 'http://placekitten.com/g/200/300',
            coverFlowContext: configuration.coverFlowContext || 'default',
            coverFlowShelfBrowser: configuration.coverFlowShelfBrowser || false,
            coverFlowContainerWidth: configuration.coverFlowContainerWidth || '100%',
            coverFlowContainerMargin: configuration.coverFlowContainerMargin || '0%',
            coverFlowContainerPadding: configuration.coverFlowContainerPadding || '2rem 1px 2rem 1px',
            coverFlowButtonsBehaviour: configuration.coverFlowButtonsBehaviour || 'stay',
            coverFlowButtonsCallback: configuration.coverFlowButtonsCallback,
            coverFlowFlippableCards: configuration.coverFlowFlippableCards || false,
            coverFlowHighlightingStyle: configuration.coverFlowHighlightingStyle || 'default',
            gridCoverFlowBreakpoints: configuration.gridCoverFlowBreakpoints || {
                xl: 1367,
                l: 1025,
                m: 769,
                s: 481,
                xs: 320,
            },
            shelfBrowserExtendedCoverFlow: configuration.shelfBrowserExtendedCoverFlow || false,
            shelfBrowserButtonDirection: configuration.shelfBrowserButtonDirection || null,
            shelfBrowserCurrentEventListeners: configuration.shelfBrowserCurrentEventListeners || null,
        },
        /* The selector doesn't have to be .lmscoverflow, but I'd strongly encourage it.
             Also it should be a div. */
        container: {
            reference: document.getElementById(element),
            scrollable: false,
            lcfNavigationButtonLeft: null,
            lcfNavigationButtonRight: null,
            currentEventListeners: { left: false, right: false },
            isScrollable() {
                if (this.reference.scrollWidth > this.reference.clientWidth) {
                    this.scrollable = true;
                }
            },
            updateNavigationButtonReferences() {
                const containerReferenceAsClass = self.container.reference.id;
                this.lcfNavigationButtonLeft = document.querySelector(`.lcfNavigationButtonLeft.${containerReferenceAsClass}`);
                this.lcfNavigationButtonRight = document.querySelector(`.lcfNavigationButtonRight.${containerReferenceAsClass}`);
            },
            hideOrShowButton() {
                if (self.config.coverFlowShelfBrowser) {
                    if (self.config.shelfBrowserCurrentEventListeners.getLeft() === false) {
                        this.reference.addEventListener('scroll', this.handleShelfBrowserScrollingLeft);
                        self.config.shelfBrowserCurrentEventListeners.toggleLeft();
                    }
                    if (self.config.shelfBrowserCurrentEventListeners.getRight() === false) {
                        this.reference.addEventListener('scroll', this.handleShelfBrowserScrollingRight);
                        self.config.shelfBrowserCurrentEventListeners.toggleRight();
                    }
                }
                else {
                    this.reference.addEventListener('scroll', this.handleDefaultScrolling);
                }
            },
            handleShelfBrowserScrollingLeft() {
                const container = self.container.reference;
                if (self.config.coverFlowShelfBrowser) {
                    if (container.scrollLeft === 0) {
                        self.container.handleScrollToEdge(self.container.lcfNavigationButtonLeft, container);
                    }
                }
            },
            handleShelfBrowserScrollingRight() {
                const container = self.container.reference;
                const scrollRight = (container.scrollWidth - container.clientWidth - container.scrollLeft);
                if (self.config.coverFlowShelfBrowser) {
                    if (scrollRight === 0) {
                        self.container.handleScrollToEdge(self.container.lcfNavigationButtonRight, container);
                    }
                }
            },
            handleScrollToEdge(buttonReference) {
                if (buttonReference) {
                    const scrollDirection = buttonReference.classList.contains('lcfNavigationButtonLeft') ? 'left' : 'right';
                    const { loadNewShelfBrowserItems, nearbyItems } = self.config.coverFlowButtonsCallback;
                    loadNewShelfBrowserItems(nearbyItems, scrollDirection);
                    if (scrollDirection === 'left') {
                        self.container.reference.removeEventListener('scroll', self.container.handleShelfBrowserScrollingLeft);
                        self.config.shelfBrowserCurrentEventListeners.toggleLeft();
                    }
                    else {
                        self.container.reference.removeEventListener('scroll', self.container.handleShelfBrowserScrollingRight);
                        self.config.shelfBrowserCurrentEventListeners.toggleRight();
                    }
                }
            },
            handleDefaultScrolling() {
                const { container } = self;
                const scrollRight = (container.reference.scrollWidth
                    - container.reference.clientWidth
                    - container.reference.scrollLeft);
                if (self.config.coverFlowButtonsBehaviour === 'disable') {
                    if (container.reference.scrollLeft > 50) {
                        container.lcfNavigationButtonLeft.disabled = false;
                    }
                    else {
                        container.lcfNavigationButtonLeft.disabled = true;
                    }
                    if (scrollRight < 50) {
                        container.lcfNavigationButtonRight.disabled = true;
                    }
                    else {
                        container.lcfNavigationButtonRight.disabled = false;
                    }
                }
                if (self.config.coverFlowButtonsBehaviour === 'hide') {
                    if (container.reference.scrollLeft > 50) {
                        container.lcfNavigationButtonLeft.classList.remove('d-none');
                    }
                    else {
                        container.lcfNavigationButtonLeft.classList.add('d-none');
                    }
                    if (scrollRight < 50) {
                        container.lcfNavigationButtonRight.classList.add('d-none');
                    }
                    else {
                        container.lcfNavigationButtonRight.classList.remove('d-none');
                    }
                }
            },
        },
        async render(coverFlowContext) {
            try {
                const dataToRender = await Promise.all(self.data.checkForUnresolvableResources(data));
                self.data.format(dataToRender);
                const formattedData = self.data.formatted;
                const containerReferenceAsClass = self.container.reference.id;
                /** The check for the current card bodies is necessary, to filter
                 * the existing ones out for extension of the coverflow-component
                 * in the shelfbrowser context. */
                const currentItemContainers = document.querySelectorAll(`.lcfItemContainer.${containerReferenceAsClass}`);
                build(formattedData, coverFlowContext || self.config.coverFlowContext, self.container, self.config);
                const coverFlowEntities = await prepare(formattedData, self.config, self.container, currentItemContainers);
                class LcfDocumentNodes {
                    nodeList;
                    constructor(nodeList) {
                        this.nodeList = nodeList;
                        this.nodeList = nodeList;
                    }
                    static populateTagAttributes(node) {
                        const TAG = node;
                        const itemClassReference = TAG.classList[0];
                        const itemClassIndex = TAG.classList[1];
                        const itemCurrent = formattedData[itemClassIndex];
                        switch (itemClassReference) {
                            case 'lcfAnchor':
                                TAG.href = itemCurrent.referenceToDetailsView;
                                break;
                            case 'lcfCoverImage':
                                TAG.src = itemCurrent?.coverurl;
                                TAG.alt = `The media cover for ${itemCurrent.title} from ${itemCurrent.author}.`;
                                break;
                            case 'lcfMediaTitle':
                                TAG.textContent = itemCurrent.title;
                                TAG.dataset.text = itemCurrent.title;
                                break;
                            case 'lcfMediaAuthor':
                                TAG.textContent = itemCurrent.author;
                                break;
                            case 'lcfMediaItemCallNumber':
                                TAG.textContent = itemCurrent.itemCallNumber;
                                break;
                            case 'lcfMediaISBD':
                                TAG.textContent = `${itemCurrent.author}: ${itemCurrent.title}`;
                                break;
                            case 'lcfFlipCardButton':
                                TAG.textContent = '⏎';
                                break;
                            default:
                                break;
                        }
                    }
                    fillTagsWithData() {
                        return this.nodeList.forEach((node) => {
                            LcfDocumentNodes.populateTagAttributes(node);
                        });
                    }
                }
                coverFlowEntities.forEach((entry) => {
                    const lcfNodesOfSingleCoverImageWrapper = document.querySelectorAll(`.${entry.id}.${containerReferenceAsClass}`);
                    const lcfItemList = new LcfDocumentNodes(lcfNodesOfSingleCoverImageWrapper);
                    lcfItemList.fillTagsWithData();
                    const lcfFlipCardButton = document.querySelector(`.lcfFlipCardButton.${entry.id}.${containerReferenceAsClass}`);
                    if (self.config.coverFlowFlippableCards) {
                        lcfFlipCardButton.addEventListener('click', () => {
                            const innerFlipCard = document.querySelector(`.flipCardInner.${entry.id}.${containerReferenceAsClass}`);
                            innerFlipCard.classList.toggle('cardIsFlipped');
                            lcfFlipCardButton.classList.toggle('buttonIsFlipped');
                        });
                    }
                });
            }
            catch (error) {
                console.log(error);
            }
        },
        /* end of render() */
    };
    return self;
}

export { LMSCoverFlow, removeChildNodes };
