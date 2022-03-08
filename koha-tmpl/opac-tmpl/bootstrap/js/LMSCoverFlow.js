(function (global, factory) {
    typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports) :
    typeof define === 'function' && define.amd ? define(['exports'], factory) :
    (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global.LMSCoverFlow = {}));
})(this, (function (exports) { 'use strict';

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

    /* This method can be used to append a compositedStyle to the globalStyleTag */
    function addGlobalStyle(selector, newStyle, container) {
        const containerReferenceAsClass = container.reference.id;
        const lcfStyle = document.getElementById('lcfStyle');
        if (selector.includes('#') || selector.includes(':root')) {
            const compositedStyle = `${selector} {${newStyle}}`;
            lcfStyle.sheet.insertRule(compositedStyle);
        }
        else {
            const compositedStyle = selector.includes('@') || selector.startsWith('[')
                ? `${selector} {${newStyle}}`
                : `${selector}.${containerReferenceAsClass} {${newStyle}}`;
            lcfStyle.sheet.insertRule(compositedStyle);
        }
    }

    function setGlobalStyles(config, container) {
        let globalStyles = [
            [
                '.text-custom-12',
                'font-size: .75rem;',
            ],
        ];
        if (config.coverFlowTooltips) {
            globalStyles = globalStyles.concat([
                [
                    '[data-tooltip]',
                    'position: relative;',
                ],
                [
                    '[data-tooltip]:hover::before',
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
        globalStyles.forEach((style) => {
            addGlobalStyle(style[0], style[1], container);
        });
    }

    function setLoadingAnimation(config, container) {
        const LOADING_ANIMATION = [
            [
                '.lcfLoadingAnimation',
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
    }

    function setFlipCards(container) {
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

    function setRaiseShadowOnHover(container) {
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

    function setHighlightOnHover(container) {
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

    class StrategyManager {
        strategies;
        constructor() {
            this.strategies = [];
        }
        addStrategy(strategy) {
            this.strategies = [...this.strategies, strategy];
        }
        getStrategy(name) {
            return this.strategies.find((strategy) => strategy.name === name);
        }
    }

    class Strategy {
        name;
        handler;
        constructor(name, handler) {
            this.name = name;
            this.handler = handler;
        }
        makePlay() {
            this.handler();
        }
    }

    function addInlineStyle(selector, newStyle, container) {
        const containerReferenceAsClass = container.reference.id;
        const targetElement = document.querySelector(`.${selector}.${containerReferenceAsClass}`);
        targetElement.setAttribute('style', newStyle);
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

    function createNavigationButton(newTagWithClasses, direction, container) {
        const CONTAINER = container;
        const NEW_TAG_WITH_CLASSES = newTagWithClasses;
        const scrollContainerToRight = () => {
            CONTAINER.reference.scrollLeft -= 10;
            CONTAINER.reference.scrollLeft += (CONTAINER.reference.clientWidth / 1.5);
        };
        const scrollContainerToLeft = () => {
            CONTAINER.reference.scrollLeft += 10;
            CONTAINER.reference.scrollLeft -= (CONTAINER.reference.clientWidth / 1.5);
        };
        if (direction === 'left') {
            NEW_TAG_WITH_CLASSES.lcfItem.onmousedown = scrollContainerToLeft;
        }
        else {
            NEW_TAG_WITH_CLASSES.lcfItem.onmousedown = scrollContainerToRight;
        }
        return NEW_TAG_WITH_CLASSES;
    }

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
        while (parent.firstElementChild) {
            parent.removeChild(parent.lastElementChild);
        }
        return parent;
    }

    class DefaultContext {
        constructor(config, container, data, lcfLoadingAspects, lcfItemWrapperAspects, lcfNavigationAspects, containerReferenceAsClass) {
            this.config = config;
            this.container = container;
            this.data = data;
            this.lcfLoadingAspects = lcfLoadingAspects;
            this.lcfItemWrapperAspects = lcfItemWrapperAspects;
            this.lcfNavigationAspects = lcfNavigationAspects;
            this.containerReferenceAsClass = containerReferenceAsClass;
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
                    '.lcfLoadingAnimation',
                    `
                -ms-grid-column: 2;
                -ms-grid-column-span: 2;
                grid-column: 2 / span 2;
                `,
                ],
            ];
        }
        setShelfBrowserMobile() {
            this.defaultContext.push([
                '.lcfItemContainer',
                `
            scroll-snap-type: x proximity;
            `,
            ]);
        }
        setStyles() {
            this.defaultContext.forEach((style) => {
                addGlobalStyle(style[0], style[1], this.container);
            });
        }
        buildLoadingAnimation() {
            this.lcfLoadingAspects.forEach((aspect) => {
                appendToDom(createTagAndSetClasses(aspect, 'lcfLoading'), this.container);
            });
        }
        buildLeftNavigationButton() {
            appendToDom(createNavigationButton(createTagAndSetClasses(this.lcfNavigationAspects[0], 'lcfNavigation', '←'), 'left', this.container), this.container);
        }
        buildRightNavigationButton() {
            appendToDom(createNavigationButton(createTagAndSetClasses(this.lcfNavigationAspects[1], 'lcfNavigation', '→'), 'right', this.container), this.container);
        }
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
            addInlineStyle('lcfNavigationButtonLeft', `
    ${lcfNavigationButtonsBaseStyles}
    left: 1rem;
    margin-right: 1rem;
    `, this.container);
            addInlineStyle('lcfNavigationButtonRight', `
    ${lcfNavigationButtonsBaseStyles}
    right: 1rem;
    margin-left: 1rem;
    `, this.container);
        }
        buildCoverFlow() {
            Array.from(Object.keys(this.data).entries()).forEach((entry) => {
                const [index, key] = entry;
                /** The following if statement handles external elements,
                   *  that are provided in the koha-shelfbrowser. */
                if (document.getElementById('shelfbrowser-testing')) {
                    const generatedHtml = stringToHtml(this.data[key].coverhtml);
                    const newElementsArray = Array.from(generatedHtml.children);
                    recursiveArrayPopulation(newElementsArray);
                    Array.from(newElementsArray.entries()).forEach((domNode) => {
                        newElementsArray[domNode[0]] = removeChildNodes(domNode[1]);
                    });
                    this.lcfItemWrapperAspects.forEach((aspect) => {
                        if (aspect.reference === 'lcfAnchor' && newElementsArray[0].tagName === 'A') {
                            appendToDom(createTagAndSetClasses(new LcfItemWrapper(newElementsArray[0], 'lcfAnchor', 'lcfCoverImageWrapper', [this.containerReferenceAsClass]), key, '', true), this.container);
                        }
                        else if (aspect.reference === 'lcfCoverImage' && newElementsArray[1].tagName === 'DIV') {
                            appendToDom(createTagAndSetClasses(new LcfItemWrapper(newElementsArray[1], 'lcfCoverImage', 'lcfAnchor', [this.containerReferenceAsClass]), key, '', true), this.container);
                        }
                        else {
                            appendToDom(createTagAndSetClasses(aspect, key), this.container);
                        }
                    });
                }
                else {
                    this.lcfItemWrapperAspects.forEach((aspect) => {
                        appendToDom(createTagAndSetClasses(aspect, key), this.container, this.config.shelfBrowserButtonDirection, index);
                    });
                }
            });
        }
    }

    class GridContext {
        constructor(config, container, data, lcfLoadingAspects, lcfItemWrapperAspects) {
            this.config = config;
            this.container = container;
            this.data = data;
            this.lcfLoadingAspects = lcfLoadingAspects;
            this.lcfItemWrapperAspects = lcfItemWrapperAspects;
            this.recommenderGridContext = [
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
            ];
        }
        setStyles() {
            this.recommenderGridContext.forEach((style) => {
                addGlobalStyle(style[0], style[1], this.container);
            });
        }
        buildLoadingAnimation() {
            this.lcfLoadingAspects.forEach((aspect) => {
                appendToDom(createTagAndSetClasses(aspect, 'lcfLoading'), this.container);
            });
        }
        buildCoverFlow() {
            Object.keys(this.data).forEach((index) => {
                this.lcfItemWrapperAspects.forEach((aspect) => {
                    appendToDom(createTagAndSetClasses(aspect, index), this.container);
                });
            });
        }
    }

    function build(data, coverFlowContext, container, config) {
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
            new LcfItemWrapper('img', 'lcfCoverAmazon', 'lcfAnchor', [containerReferenceAsClass]),
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
        const strategyManager = new StrategyManager();
        const evaluateConfiguration = () => {
            if (config.coverFlowFlippableCards) {
                setFlipCards(container);
                setHighlightOnHover(container);
                return;
            }
            if (config.coverFlowHighlightingStyle === 'default') {
                setRaiseShadowOnHover(container);
                return;
            }
            if (config.coverFlowHighlightingStyle === 'coloredFrame') {
                setHighlightOnHover(container);
            }
        };
        //   const onEntry = (entry) => {
        //     entry.forEach((change) => {
        //       if (change.isIntersecting) {
        //         change.target.style.width = window.screen.availWidth;
        //       }
        //     });
        //   };
        strategyManager.addStrategy(new Strategy('defaultContextStrategy', () => {
            createStyleTag();
            setGlobalStyles(config, container);
            setLoadingAnimation(config, container);
            evaluateConfiguration();
            const defaultContext = new DefaultContext(config, container, data, lcfLoadingAspects, lcfItemWrapperAspects, lcfNavigationAspects, containerReferenceAsClass);
            defaultContext.setStyles();
            defaultContext.buildLoadingAnimation();
            defaultContext.buildLeftNavigationButton();
            defaultContext.buildCoverFlow();
            defaultContext.buildRightNavigationButton();
            defaultContext.setNavigationButtonStyles();
        }));
        strategyManager.addStrategy(new Strategy('gridContextStrategy', () => {
            createStyleTag();
            setGlobalStyles(config, container);
            setLoadingAnimation(config, container);
            evaluateConfiguration();
            const gridContext = new GridContext(config, container, data, lcfLoadingAspects, lcfItemWrapperAspects);
            gridContext.setStyles();
            gridContext.buildLoadingAnimation();
            gridContext.buildCoverFlow();
        }));
        strategyManager.addStrategy(new Strategy('shelfBrowserExtensionStrategy', () => {
            const defaultContext = new DefaultContext(config, container, data, lcfLoadingAspects, lcfItemWrapperAspects, lcfNavigationAspects, containerReferenceAsClass);
            defaultContext.buildCoverFlow();
        }));
        strategyManager.addStrategy(new Strategy('shelfBrowserMobileStrategy', () => {
            // const options = {
            //   threshold: [1.0],
            // };
            // const observer = new IntersectionObserver(onEntry, options);
            createStyleTag();
            setGlobalStyles(config, container);
            setLoadingAnimation(config, container);
            evaluateConfiguration();
            const defaultContext = new DefaultContext(config, container, data, lcfLoadingAspects, lcfItemWrapperAspects, lcfNavigationAspects, containerReferenceAsClass);
            defaultContext.setStyles();
            // defaultContext.setShelfBrowserMobile();
            defaultContext.buildLoadingAnimation();
            defaultContext.buildLeftNavigationButton();
            defaultContext.buildCoverFlow();
            defaultContext.buildRightNavigationButton();
            defaultContext.setNavigationButtonStyles();
            // eslint-disable-next-line max-len
            // const lcfItemContainers = document.querySelectorAll(`.lcfItemContainer.${containerReferenceAsClass}`);
            // lcfItemContainers.forEach((itemContainer) => {
            //   observer.observe(itemContainer);
            // });
        }));
        if (config.shelfBrowserExtendedCoverFlow) {
            strategyManager.getStrategy('shelfBrowserExtensionStrategy').makePlay();
            return;
        }
        // eslint-disable-next-line max-len
        if (config.coverFlowShelfBrowser && window.screen.width <= (config.gridCoverFlowBreakpoints.s - 1)) {
            strategyManager.getStrategy('shelfBrowserMobileStrategy').makePlay();
            return;
        }
        if (coverFlowContext === 'default' && window.screen.width >= config.gridCoverFlowBreakpoints.s) {
            strategyManager.getStrategy('defaultContextStrategy').makePlay();
            return;
        }
        if (coverFlowContext === 'grid' || window.screen.width <= (config.gridCoverFlowBreakpoints.s - 1)) {
            strategyManager.getStrategy('gridContextStrategy').makePlay();
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
            constructor(entityData) {
                this.id = entityData.id;
                this.title = entityData.title;
                this.author = entityData.author;
                this.biblionumber = entityData.biblionumber;
                this.referenceToDetailsView = entityData.referenceToDetailsView;
                this.itemCallNumber = entityData.itemCallNumber;
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
                const newLcfEntity = new LcfEntity({
                    id: currentId,
                    title: currentEntry.title,
                    author: currentEntry.author,
                    biblionumber: currentEntry.biblionumber,
                    coverurl: currentEntry.coverurl,
                    referenceToDetailsView: currentEntry.referenceToDetailsView,
                    itemCallNumber: currentEntry.itemCallNumber,
                });
                const coverImage = promisedEntity;
                newLcfEntity.addCoverImageMetadata(coverImage.naturalHeight, coverImage.naturalWidth);
                return promisedCoverFlowEntities.push(new Promise((resolve) => {
                    resolve(newLcfEntity);
                }));
            }
            catch (error) {
                console.trace(`Looks like something went wrong in ${entityToCoverFlow.name} ->`, error);
                return null;
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
                    try {
                        const response = await fetch(resourceInQuestion, {
                            method: 'GET',
                            mode: 'cors',
                        });
                        return response.ok;
                    }
                    catch (error) {
                        console.trace(`Looks like a request failed in ${this.checkIfFileExists.name} ->`, error);
                        return error;
                    }
                },
                checkForUnresolvableResources(localData) {
                    const LOCAL_DATA = localData.map(async (entry) => {
                        let newEntry = entry;
                        if (entry.coverurl === '') {
                            // console.error('Resource url is an empty string.');
                            newEntry = { ...entry, coverurl: self.config.coverImageFallbackUrl };
                        }
                        if (entry.coverurl === undefined) {
                            // console.error('Resource url is undefined.');
                            newEntry = { ...entry, coverurl: self.config.coverImageFallbackUrl };
                        }
                        const fileExists = await this.checkIfFileExists(entry.coverurl);
                        if (!fileExists) {
                            // console.error('Resource url is non-resolvable.');
                            newEntry = { ...entry, coverurl: self.config.coverImageFallbackUrl };
                        }
                        return newEntry;
                    });
                    return LOCAL_DATA;
                },
                async format(localData) {
                    this.formatted = Object.fromEntries(Object.entries(localData).map(([, v]) => [generateId(), v]));
                },
            },
            config: {
                coverImageFallbackHeight: configuration.coverImageFallbackHeight || 210,
                coverFlowTooltips: configuration.coverFlowTooltips || false,
                coverFlowAutoScroll: configuration.coverFlowAutoScroll || false,
                coverFlowAutoScrollInterval: configuration.coverFlowAutoScrollInterval || 8000,
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
                isScrollable() {
                    if (this.reference.scrollWidth > this.reference.clientWidth
                        || self.config.coverFlowShelfBrowser) {
                        this.scrollable = true;
                    }
                },
                scrollSmoothly(container, position, time) {
                    const CONTAINER = container;
                    let POSITION = position;
                    let TIME = time;
                    const currentPosition = position !== 0
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
                            CONTAINER.reference.scrollLeft = ((((POSITION - currentPosition) * progress) / TIME) + currentPosition);
                        }
                        else {
                            CONTAINER.reference.scrollLeft = ((currentPosition - ((currentPosition - POSITION) * progress) / TIME));
                        }
                        if (progress < TIME) {
                            window.requestAnimationFrame(step);
                        }
                        else {
                            CONTAINER.reference.scrollLeft = POSITION;
                        }
                    });
                },
                updateNavigationButtonReferences() {
                    const containerReferenceAsClass = self.container.reference.id;
                    this.lcfNavigationButtonLeft = document.querySelector(`.lcfNavigationButtonLeft.${containerReferenceAsClass}`);
                    this.lcfNavigationButtonRight = document.querySelector(`.lcfNavigationButtonRight.${containerReferenceAsClass}`);
                },
                hideOrShowButton() {
                    if (self.config.coverFlowShelfBrowser) {
                        if (self.config.shelfBrowserCurrentEventListeners.getLeft() === false) {
                            self.config.shelfBrowserCurrentEventListeners.setHandler(this.handleShelfBrowserScrollingLeft, 'left');
                            this.reference.addEventListener('scroll', this.handleShelfBrowserScrollingLeft);
                            self.config.shelfBrowserCurrentEventListeners.setLeftToTrue();
                        }
                        if (self.config.shelfBrowserCurrentEventListeners.getRight() === false) {
                            self.config.shelfBrowserCurrentEventListeners.setHandler(this.handleShelfBrowserScrollingRight, 'right');
                            this.reference.addEventListener('scroll', this.handleShelfBrowserScrollingRight);
                            self.config.shelfBrowserCurrentEventListeners.setRightToTrue();
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
                            self.config.shelfBrowserCurrentEventListeners.setLeftToFalse();
                        }
                        else {
                            self.container.reference.removeEventListener('scroll', self.container.handleShelfBrowserScrollingRight);
                            self.config.shelfBrowserCurrentEventListeners.setRightToFalse();
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
                autoScrollContainer() {
                    const { container } = self;
                    const scrollRight = () => (container.reference.scrollWidth
                        - container.reference.clientWidth
                        - container.reference.scrollLeft);
                    const scrollContainer = (scrollRightResult) => {
                        if (scrollRightResult === 0) {
                            this.scrollSmoothly(container, 0, 500);
                            return;
                        }
                        this.scrollSmoothly(container, (container.reference.scrollLeft + container.reference.clientWidth / 4), 500);
                    };
                    const runAutoScroll = () => {
                        const scrollRightValue = scrollRight();
                        scrollContainer(scrollRightValue);
                    };
                    const autoScrollId = setInterval(() => {
                        runAutoScroll();
                    }, self.config.coverFlowAutoScrollInterval);
                    return autoScrollId;
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
                    const newOffsetWidth = [];
                    const computedFontSize = parseInt(window.getComputedStyle(document.getElementById(element)).fontSize.split('px')[0], 10);
                    const calculateCoverFlowPlusGaps = (offsetWidthArray) => offsetWidthArray.reduce((accumulator, currentValue) => accumulator + currentValue + computedFontSize) + computedFontSize;
                    coverFlowEntities.forEach((entry) => {
                        const lcfNodesOfSingleCoverImageWrapper = document.querySelectorAll(`.${entry.id}.${containerReferenceAsClass}`);
                        const lcfItemList = new LcfDocumentNodes(lcfNodesOfSingleCoverImageWrapper);
                        const addDataTooltip = (lcfItemContainer, coverFlowEntity) => {
                            const itemContainer = lcfItemContainer;
                            itemContainer.dataset.tooltip = `${coverFlowEntity.author ? coverFlowEntity.author : ''} ${coverFlowEntity.itemCallNumber ? coverFlowEntity.itemCallNumber : ''} ${coverFlowEntity.title ? coverFlowEntity.title : ''}`;
                        };
                        const currentLcfItemContainer = document.querySelector(`.lcfItemContainer.${entry.id}`);
                        addDataTooltip(currentLcfItemContainer, entry);
                        lcfItemList.fillTagsWithData();
                        if (self.config.shelfBrowserExtendedCoverFlow && self.config.shelfBrowserButtonDirection === 'left') {
                            const lcfItemContainer = lcfItemList.nodeList[0];
                            newOffsetWidth.push(lcfItemContainer.offsetWidth);
                        }
                        const lcfFlipCardButton = document.querySelector(`.lcfFlipCardButton.${entry.id}.${containerReferenceAsClass}`);
                        if (self.config.coverFlowFlippableCards) {
                            lcfFlipCardButton.addEventListener('click', () => {
                                const innerFlipCard = document.querySelector(`.flipCardInner.${entry.id}.${containerReferenceAsClass}`);
                                innerFlipCard.classList.toggle('cardIsFlipped');
                                lcfFlipCardButton.classList.toggle('buttonIsFlipped');
                            });
                        }
                    });
                    if (self.config.shelfBrowserExtendedCoverFlow && self.config.shelfBrowserButtonDirection === 'left') {
                        self.container.reference.scrollLeft += calculateCoverFlowPlusGaps(newOffsetWidth);
                    }
                }
                catch (error) {
                    // console.log(error);
                }
                if (self.config.coverFlowAutoScroll && !self.config.coverFlowShelfBrowser) {
                    let autoScrollId = self.container.autoScrollContainer();
                    self.container.reference.addEventListener('mouseover', () => {
                        clearInterval(autoScrollId);
                    });
                    self.container.reference.addEventListener('mouseout', () => {
                        autoScrollId = self.container.autoScrollContainer();
                    });
                }
            },
            /* end of render() */
        };
        return self;
    }

    exports.LMSCoverFlow = LMSCoverFlow;
    exports.removeChildNodes = removeChildNodes;

    Object.defineProperty(exports, '__esModule', { value: true });

}));
