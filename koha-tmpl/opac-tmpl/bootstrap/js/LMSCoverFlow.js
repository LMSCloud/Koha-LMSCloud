(function (global, factory) {
    typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports) :
    typeof define === 'function' && define.amd ? define(['exports'], factory) :
    (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global.LMSCoverFlow = {}));
})(this, (function (exports) { 'use strict';

    class Observable {
        _listeners;
        _value;
        constructor(value) {
            this._listeners = [];
            this._value = value;
        }
        notify() {
            this._listeners.forEach((listener) => listener(this._value));
        }
        subscribe(listener) {
            this._listeners.push(listener);
        }
        get value() {
            return this._value;
        }
        set value(val) {
            if (val !== this._value) {
                this._value = val;
                this.notify();
            }
        }
    }

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
                '.text-custom-4',
                'font-size: .25rem;',
            ],
            [
                '.text-custom-8',
                'font-size: .5rem;',
            ],
            [
                '.text-custom-12',
                'font-size: .75rem;',
            ],
            [
                '.text-custom-16',
                'font-size: 1rem;',
            ],
            [
                '.text-custom-20',
                'font-size: 1.25rem;',
            ],
            [
                '.text-custom-24',
                'font-size: 1.5rem;',
            ],
            [
                '.text-custom-28',
                'font-size: 1.75rem;',
            ],
            [
                '.text-custom-32',
                'font-size: 2rem;',
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
            // new LcfItemWrapper('div', 'lcfCoverHtmlWrapper', 'lcfAnchor', [containerReferenceAsClass]),
            new LcfItemWrapper('div', 'lcfCardBody', 'lcfFlipCardFront', ['card-body', 'p-2', 'text-center', containerReferenceAsClass]),
            new LcfItemWrapper('p', 'lcfMediaAuthor', 'lcfCardBody', ['card-text', 'text-muted', 'text-truncate', 'font-weight-light', 'mb-0', config.coverFlowCardBodyTextHeights.lcfMediaAuthor, containerReferenceAsClass]),
            new LcfItemWrapper('p', 'lcfMediaItemCallNumber', 'lcfCardBody', ['card-text', 'text-muted', 'text-truncate', 'font-weight-light', 'mb-0', config.coverFlowCardBodyTextHeights.lcfMediaItemCallNumber, containerReferenceAsClass]),
            new LcfItemWrapper('p', 'lcfMediaTitle', 'lcfCardBody', ['card-text', 'text-truncate', 'font-weight-lighter', 'mb-0', config.coverFlowCardBodyTextHeights.lcfMediaTitle, containerReferenceAsClass]),
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

    class Config {
        constructor(configuration) {
            this.c = configuration;
            this.coverImageFallbackHeight = this.c.coverImageFallbackHeight || 210;
            this.coverFlowTooltips = this.c.coverFlowTooltips || false;
            this.coverFlowAutoScroll = this.c.coverFlowAutoScroll || false;
            this.coverFlowAutoScrollInterval = this.c.coverFlowAutoScrollInterval || 8000;
            this.coverFlowCardBody = this.c.coverFlowCardBody || {
                lcfMediaAuthor: true,
                lcfMediaTitle: true,
                lcfMediaItemCallNumber: false,
            };
            this.coverFlowCardBodyTextHeights = this.c.coverFlowCardBodyTextHeights || {
                lcfMediaAuthor: 'text-custom-12',
                lcfMediaTitle: 'text-custom-12',
                lcfMediaItemCallNumber: 'text-custom-12',
            };
            this.coverImageFallbackUrl = this.c.coverImageFallbackUrl || 'http://placekitten.com/g/200/300';
            this.coverImageExternalSources = this.c.coverImageExternalSources || false;
            this.coverFlowContext = this.c.coverFlowContext || 'default';
            this.coverFlowShelfBrowser = this.c.coverFlowShelfBrowser || false;
            this.coverFlowContainerWidth = this.c.coverFlowContainerWidth || '100%';
            this.coverFlowContainerMargin = this.c.coverFlowContainerMargin || '0%';
            this.coverFlowContainerPadding = this.c.coverFlowContainerPadding || '2rem 1px 2rem 1px';
            this.coverFlowButtonsBehaviour = this.c.coverFlowButtonsBehaviour || 'stay';
            this.coverFlowButtonsCallback = this.c.coverFlowButtonsCallback;
            this.coverFlowFlippableCards = this.c.coverFlowFlippableCards || false;
            this.coverFlowHighlightingStyle = this.c.coverFlowHighlightingStyle || 'default';
            this.gridCoverFlowBreakpoints = this.c.gridCoverFlowBreakpoints || {
                xl: 1367,
                l: 1025,
                m: 769,
                s: 481,
                xs: 320,
            };
            this.shelfBrowserExtendedCoverFlow = this.c.shelfBrowserExtendedCoverFlow || false;
            this.shelfBrowserButtonDirection = this.c.shelfBrowserButtonDirection || null;
            this.shelfBrowserCurrentEventListeners = this.c.shelfBrowserCurrentEventListeners || null;
        }
    }

    class Container {
        reference;
        scrollable;
        lcfNavigationButtonLeft;
        lcfNavigationButtonRight;
        config;
        constructor(element, config) {
            this.config = config;
            this.reference = document.getElementById(element);
            this.scrollable = false;
            this.lcfNavigationButtonLeft = null;
            this.lcfNavigationButtonRight = null;
        }
        isScrollable() {
            if (this.reference.scrollWidth > this.reference.clientWidth
                || this.config.coverFlowShelfBrowser) {
                this.scrollable = true;
            }
        }
        static scrollSmoothly(container, position, time) {
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
        }
        updateNavigationButtonReferences() {
            const containerReferenceAsClass = this.reference.id;
            this.lcfNavigationButtonLeft = document.querySelector(`.lcfNavigationButtonLeft.${containerReferenceAsClass}`);
            this.lcfNavigationButtonRight = document.querySelector(`.lcfNavigationButtonRight.${containerReferenceAsClass}`);
        }
        hideOrShowButton() {
            if (this.config.coverFlowShelfBrowser) {
                if (this.config.shelfBrowserCurrentEventListeners.getLeft() === false) {
                    this.config.shelfBrowserCurrentEventListeners.setHandler(this.handleShelfBrowserScrollingLeft, 'left');
                    this.reference.addEventListener('scroll', this.handleShelfBrowserScrollingLeft);
                    this.config.shelfBrowserCurrentEventListeners.setLeftToTrue();
                }
                if (this.config.shelfBrowserCurrentEventListeners.getRight() === false) {
                    this.config.shelfBrowserCurrentEventListeners.setHandler(this.handleShelfBrowserScrollingRight, 'right');
                    this.reference.addEventListener('scroll', this.handleShelfBrowserScrollingRight);
                    this.config.shelfBrowserCurrentEventListeners.setRightToTrue();
                }
            }
            else {
                this.reference.addEventListener('scroll', this.handleDefaultScrolling);
            }
        }
        handleShelfBrowserScrollingLeft = () => {
            const container = this.reference;
            if (this.config.coverFlowShelfBrowser) {
                if (container.scrollLeft === 0) {
                    this.handleScrollToEdge(this.lcfNavigationButtonLeft);
                }
            }
        };
        handleShelfBrowserScrollingRight = () => {
            const container = this.reference;
            const scrollRight = (container.scrollWidth - container.clientWidth - container.scrollLeft);
            if (this.config.coverFlowShelfBrowser) {
                if (scrollRight === 0) {
                    this.handleScrollToEdge(this.lcfNavigationButtonRight);
                }
            }
        };
        handleScrollToEdge = (buttonReference) => {
            if (buttonReference) {
                const scrollDirection = buttonReference.classList.contains('lcfNavigationButtonLeft') ? 'left' : 'right';
                const { loadNewShelfBrowserItems, nearbyItems } = this.config.coverFlowButtonsCallback;
                loadNewShelfBrowserItems(nearbyItems, scrollDirection);
                if (scrollDirection === 'left') {
                    this.reference.removeEventListener('scroll', this.handleShelfBrowserScrollingLeft);
                    this.config.shelfBrowserCurrentEventListeners.setLeftToFalse();
                }
                else {
                    this.reference.removeEventListener('scroll', this.handleShelfBrowserScrollingRight);
                    this.config.shelfBrowserCurrentEventListeners.setRightToFalse();
                }
            }
        };
        handleDefaultScrolling = () => {
            const scrollRight = (this.reference.scrollWidth
                - this.reference.clientWidth
                - this.reference.scrollLeft);
            if (this.config.coverFlowButtonsBehaviour === 'disable') {
                if (this.reference.scrollLeft > 50) {
                    this.lcfNavigationButtonLeft.disabled = false;
                }
                else {
                    this.lcfNavigationButtonLeft.disabled = true;
                }
                if (scrollRight < 50) {
                    this.lcfNavigationButtonRight.disabled = true;
                }
                else {
                    this.lcfNavigationButtonRight.disabled = false;
                }
            }
            if (this.config.coverFlowButtonsBehaviour === 'hide') {
                if (this.reference.scrollLeft > 50) {
                    this.lcfNavigationButtonLeft.classList.remove('d-none');
                }
                else {
                    this.lcfNavigationButtonLeft.classList.add('d-none');
                }
                if (scrollRight < 50) {
                    this.lcfNavigationButtonRight.classList.add('d-none');
                }
                else {
                    this.lcfNavigationButtonRight.classList.remove('d-none');
                }
            }
        };
        autoScrollContainer() {
            const scrollRight = () => (this.reference.scrollWidth
                - this.reference.clientWidth
                - this.reference.scrollLeft);
            const scrollContainer = (scrollRightResult) => {
                if (scrollRightResult === 0) {
                    Container.scrollSmoothly(this, 0, 500);
                    return;
                }
                Container.scrollSmoothly(this, (this.reference.scrollLeft + this.reference.clientWidth / 4), 500);
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

    class Data {
        config;
        constructor(config) {
            this.config = config;
        }
        static isValidUrl(urlInQuestion) {
            let url;
            try {
                url = new URL(urlInQuestion);
            }
            catch (error) {
                return false;
            }
            return url.protocol === 'http:' || url.protocol === 'https:';
        }
        async checkIfFileExists(resourceInQuestion) {
            try {
                const response = await fetch(resourceInQuestion, { method: 'GET', mode: 'cors' });
                return response.ok;
            }
            catch (error) {
                console.trace(`Looks like a request failed in ${this.checkIfFileExists.name} ->`, error);
                return error;
            }
        }
        checkUrls(localData) {
            // eslint-disable-next-line max-len
            const checkedUrls = localData.map(async (entry) => {
                console.log(entry)
                const { coverurl, coverhtml } = entry;
                if (coverhtml && !coverurl)
                    return entry;
                if (coverurl.startsWith('/'))
                    return { ...entry, coverurl: await Data.processDataUrl(coverurl) };
                if (!coverurl)
                    return { ...entry, coverurl: this.config.coverImageFallbackUrl };
                const fileExists = await this.checkIfFileExists(coverurl);
                if (!fileExists)
                    return { ...entry, coverurl: this.config.coverImageFallbackUrl };
                return entry;
            });
            return checkedUrls;
        }
        static async processDataUrl(url) {
            const response = await fetch(url);
            const result = await response.text();
            return result;
        }
    }

    function arrFromObjEntries(object) {
        return Array.from(Object.entries(object));
    }

    function populateTagAttributes(node, formattedData) {
        const TAG = node;
        const [itemClassReference, itemClassIndex] = TAG.classList;
        const itemCurrent = formattedData[itemClassIndex];
        switch (itemClassReference) {
            case 'lcfItemContainer':
                if (itemCurrent.additionalProperties) {
                    arrFromObjEntries(itemCurrent.additionalProperties).forEach((entry) => {
                        const [key, value] = entry;
                        TAG.setAttribute(`data-${key}`, value);
                    });
                }
                break;
            case 'lcfAnchor':
                TAG.href = itemCurrent.referenceToDetailsView;
                break;
            case 'lcfCoverImage':
                TAG.src = itemCurrent?.coverurl;
                break;
            case 'lcfCoverHtmlWrapper':
                TAG.innerHTML = itemCurrent?.coverhtml ? itemCurrent.coverhtml : '';
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
        }
    }

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

    class LcfEntity {
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
        addCoverImageMetadata(height, width) {
            if (height <= this.kohaImageMaxHeight) {
                this.imageHeight = height;
                this.imageWidth = width;
            }
            else {
                const aspectRatio = height / width;
                this.imageHeight = this.kohaImageMaxHeight;
                this.imageWidth = this.kohaImageMaxHeight / aspectRatio;
            }
            this.imageAspectRatio = this.calculateCoverImageAspectRatio();
            this.imageComputedWidth = this.imageHeight / this.imageAspectRatio;
        }
        calculateCoverImageAspectRatio() {
            return this.imageHeight / this.imageWidth;
        }
        updateMaxHeight(height) {
            this.maxHeight = height;
        }
        updateDimensions() {
            this.imageHeight = this.maxHeight;
            this.imageWidth = this.imageHeight / this.imageAspectRatio;
            this.imageComputedWidth = this.imageHeight / this.imageAspectRatio;
        }
    }

    function entityToCoverFlow(config, currentId, currentEntry, promisedEntity, promisedCoverFlowEntities) {
        try {
            const newLcfEntity = new LcfEntity({
                id: currentId,
                title: currentEntry.title,
                author: currentEntry.author,
                biblionumber: currentEntry.biblionumber,
                coverurl: currentEntry.coverurl,
                coverhtml: currentEntry.coverhtml,
                referenceToDetailsView: currentEntry.referenceToDetailsView,
                itemCallNumber: currentEntry.itemCallNumber,
            }, config.coverImageFallbackHeight);
            if (promisedEntity) {
                const coverImage = promisedEntity;
                newLcfEntity.addCoverImageMetadata(coverImage.naturalHeight, coverImage.naturalWidth);
            }
            return promisedCoverFlowEntities.push(new Promise((resolve) => {
                resolve(newLcfEntity);
            }));
        }
        catch (error) {
            console.trace(`Looks like something went wrong in ${entityToCoverFlow.name} ->`, error);
            return null;
        }
    }

    function getLcfItemId(domNode) {
        const id = domNode?.classList[1];
        if (!/_[0-9]{7}/.test(id))
            throw new Error("Id doesn't match pattern.");
        return id;
    }

    function processHeights(lcfCoverImageHeights, config) {
        const heights = lcfCoverImageHeights
            .map((height) => height || 0)
            .map((height) => (Number.isNaN(+height) ? '' : +height));
        const coverImagesMaximumHeight = Math.max(...heights);
        return coverImagesMaximumHeight <= config.coverImageFallbackHeight
            ? coverImagesMaximumHeight : config.coverImageFallbackHeight;
    }

    function flattenPromiseResults(resultsArray) {
        const flattenedResults = [];
        Object.keys(resultsArray).forEach((index) => {
            flattenedResults.push(resultsArray[index].value);
        });
        return flattenedResults;
    }

    // TODO: Enable feeding additional metadata to LcfEntity constructor.
    /* This promise chain is the main block for displaying covers. The global coverFlowEntities
       * Object gets flattened to promise level. The mapped imageHeights are used to set a universal
       * height for all images. Then the card widths are adjusted to the corresponding image widths.
       * Before the cards are displayed, a loading animation renders to bridge the gap between
       * awaiting all images and the depending methods for image sizing and so on. */
    async function settlePromises(config, container, currentItemContainers, promisedEntities) {
        try {
            const containerReferenceAsClass = container.reference.id;
            const result = await Promise.allSettled(promisedEntities);
            const flattenedResults = flattenPromiseResults(result);
            const lcfCoverImageHeights = flattenedResults.map((lcfEntity) => (lcfEntity.imageHeight ? lcfEntity.imageHeight : null));
            let lcfItemContainers = Array.from(document.querySelectorAll(`.lcfItemContainer.${containerReferenceAsClass}`));
            /** We determine whether all images have a height of null which may be the case when
             * external sources provide them. */
            const imageArrayExistent = !lcfCoverImageHeights.every((height) => height === null);
            /** This handles the default case with images served via their urls. */
            if (imageArrayExistent) {
                const imagesMaxHeight = processHeights(lcfCoverImageHeights, config);
                addGlobalStyle(`.lcfCoverImage.${containerReferenceAsClass}`, `height: ${imagesMaxHeight}px`, container);
                const localCurrentItemContainers = Array.from(currentItemContainers);
                lcfItemContainers = lcfItemContainers.filter((lcfItemContainer) => !localCurrentItemContainers.includes(lcfItemContainer));
                lcfItemContainers.forEach((lcfCardBody) => {
                    const lcfItemId = getLcfItemId(lcfCardBody);
                    const lcfItemCurrent = flattenedResults.filter((lcfEntity) => lcfEntity.id === lcfItemId)[0];
                    /** Updates the imageComputedWid†h property when the tallest image is still
                     * shorter than the coverImageFallbackHeight.   */
                    lcfItemCurrent.updateMaxHeight(imagesMaxHeight);
                    lcfItemCurrent.updateDimensions();
                    /** Sets width of the whole card. */
                    addInlineStyle(`lcfItemContainer.${lcfItemCurrent.id}`, `flex-basis: ${lcfItemCurrent.imageComputedWidth + 2}px;`, container);
                });
            }
            /** This handles images served via external sources. */
            if (!imageArrayExistent) {
                const lcfCoverImages = document.querySelectorAll(`.lcfCoverImage.${containerReferenceAsClass}`);
                lcfCoverImages.forEach((lcfCoverImage) => lcfCoverImage.classList.add('d-none'));
            }
            /** Hides the loading animation. */
            const lcfLoadingAnimation = document.querySelector(`.lcfLoadingAnimation.${containerReferenceAsClass}`);
            lcfLoadingAnimation.classList.add('d-none');
            /** Removes d-none from all item containers and shows the content. */
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
    }

    async function prepare(data, config, container, currentItemContainers) {
        const promisedCoverFlowEntities = [];
        let lcfCoverImages = [];
        const lcfCoverFlowEntities = [];
        const externalData = Object.entries(data);
        Array.from(externalData).forEach((entry) => {
            lcfCoverFlowEntities.push({ id: entry[0], entry: entry[1], image: null });
            if (entry[1].coverurl) {
                lcfCoverImages.push(new LcfCoverImage(entry[1].coverurl).fetch());
            }
        });
        lcfCoverImages = await Promise.all(lcfCoverImages);
        Array.from(lcfCoverImages.entries()).forEach((entry) => {
            const [index, image] = entry;
            lcfCoverFlowEntities[index].image = image;
        });
        lcfCoverFlowEntities.forEach((entity) => entityToCoverFlow(config, entity.id, entity.entry, entity.image, promisedCoverFlowEntities));
        return settlePromises(config, container, currentItemContainers, promisedCoverFlowEntities);
    }

    async function urlHarvester(formattedData, containerReference) {
        try {
            const dataArray = Array.from(Object.entries(formattedData));
            const harvester = document.createElement('div');
            harvester.classList.add('urlHarvester', 'd-none');
            dataArray.forEach((entry) => {
                const [id, { coverhtml }] = entry;
                const harvesterElement = document.createElement('div');
                harvesterElement.classList.add('harvesterElement', id);
                harvesterElement.innerHTML = coverhtml;
                harvester.appendChild(harvesterElement);
            });
            containerReference.appendChild(harvester);
            return true;
        }
        catch (error) {
            console.log(error);
            return false;
        }
    }

    function clearHarvester() {
        const harvester = document.querySelector('.urlHarvester');
        if (harvester) {
            harvester.remove();
        }
    }

    function resyncExecution(ms) {
        return new Promise((resolve) => {
            setTimeout(resolve, ms);
        });
    }

    async function harvestUrls(formattedData, loaded, container) {
        const dataReference = formattedData;
        const loadedReference = loaded;
        const containerReference = container;
        const harvesterBuilt = await urlHarvester(dataReference, containerReference);
        if (harvesterBuilt) {
            let harvesterElements = document.querySelectorAll('.harvesterElement');
            const harvesterResults = [];
            if (loadedReference) {
                const harvesterObservers = {};
                harvesterElements.forEach((node) => {
                    const nodeId = getLcfItemId(node);
                    harvesterObservers[nodeId] = new Observable(node.innerHTML);
                    harvesterObservers[nodeId].subscribe((coverurl) => {
                        //   console.log(coverurl);
                        //   const aHrefRe = /a href="(.+?)"/g;
                        //   const hrefs = coverurl.match(aHrefRe);
                        //   if (hrefs) {
                        //     const [src] = hrefs;
                        //     const [, srcString] = src.split('"');
                        //     harvesterResults.push([nodeId, srcString]);
                        //     return;
                        //   }
                        const srcRe = /src="(.+?)"/g;
                        const sources = coverurl.match(srcRe);
                        if (sources) {
                            const [src] = sources;
                            let [, srcString] = src.split('"');
                            /** Google specific url parameters. Somehow the idenatifier &amp; ends up
                             * in the resulting string when it should be just & instead. */
                            srcString = `${srcString.replaceAll('amp;', '').replace(/zoom=./g, 'zoom=1')}&gbs_api`;
                            harvesterResults.push([nodeId, srcString]);
                            return;
                        }
                        harvesterResults.push([nodeId, undefined]);
                    });
                });
                /** Notify the observant to execute the callback. */
                loadedReference.value = true;
                /** Reset to false. */
                loadedReference.value = false;
                setTimeout(() => {
                    harvesterElements = document.querySelectorAll('.harvesterElement');
                    harvesterElements.forEach((node) => {
                        const nodeId = getLcfItemId(node);
                        harvesterObservers[nodeId].value = node.innerHTML;
                    });
                }, 500);
                setTimeout(() => {
                    harvesterResults.forEach((entry) => {
                        const [id, coverurl] = entry;
                        dataReference[id].coverurl = coverurl;
                    });
                }, 500);
                await resyncExecution(500);
                clearHarvester();
            }
            else {
                harvesterElements.forEach((node) => {
                    const nodeId = getLcfItemId(node);
                    const srcRe = /src="(.+?)"/g;
                    const sources = node.innerHTML.match(srcRe);
                    if (sources) {
                        const [src] = sources;
                        const [, srcString] = src.split('"');
                        harvesterResults.push([nodeId, srcString]);
                    }
                    harvesterResults.forEach((entry) => {
                        const [id, coverurl] = entry;
                        dataReference[id].coverurl = coverurl;
                    });
                    clearHarvester();
                });
            }
        }
    }

    function generateId() {
        const randomValues = new Uint8Array(16);
        return `_${window.crypto.getRandomValues(randomValues)
        .join('')
        .toString()
        .substring(2, 9)}`;
    }

    function format(localData) {
        return Object.fromEntries(Object.entries(localData).map(([, v]) => [generateId(), v]));
    }

    // eslint-disable-next-line max-len
    function addDataTooltip(lcfItemContainer, coverFlowEntity) {
        const itemContainer = lcfItemContainer;
        itemContainer.dataset.tooltip = `${coverFlowEntity.author ? coverFlowEntity.author : ''} ${coverFlowEntity.itemCallNumber ? coverFlowEntity.itemCallNumber : ''} ${coverFlowEntity.title ? coverFlowEntity.title : ''}`;
    }

    function calculateComputedFontSize(container) {
        return parseInt(window.getComputedStyle(document.getElementById(container)).fontSize.split('px')[0], 10);
    }

    function calculateCoverFlowPlusGaps(offsetWidthArray, computedFontSize) {
        return offsetWidthArray
            .reduce((accumulator, currentValue) => accumulator + currentValue + computedFontSize)
            + computedFontSize;
    }

    function addFlipCards({ id, config, containerReference }) {
        if (config.coverFlowFlippableCards) {
            const lcfFlipCardButton = document.querySelector(`.lcfFlipCardButton.${id}.${containerReference}`);
            lcfFlipCardButton.addEventListener('click', () => {
                const innerFlipCard = document.querySelector(`.flipCardInner.${id}.${containerReference}`);
                innerFlipCard.classList.toggle('cardIsFlipped');
                lcfFlipCardButton.classList.toggle('buttonIsFlipped');
            });
        }
    }

    function cleanupUrls(config, formattedData) {
        const cleanedData = formattedData;
        arrFromObjEntries(formattedData).forEach((entry) => {
            const [id, data] = entry;
            cleanedData[id] = {
                ...data, coverurl: data.coverurl || config.coverImageFallbackUrl,
            };
        });
        return cleanedData;
    }

    function addAutoScroll({ config, container }) {
        if (config.coverFlowAutoScroll && !config.coverFlowShelfBrowser) {
            let autoScrollId = container.autoScrollContainer();
            container.reference.addEventListener('mouseover', () => {
                clearInterval(autoScrollId);
            });
            container.reference.addEventListener('mouseout', () => {
                autoScrollId = container.autoScrollContainer();
            });
        }
    }

    function changeAspectVisibility({ config, containerReference }) {
        if (Object.values(config.coverFlowCardBody).every((setting) => setting === false)) {
            const cardBodies = document.querySelectorAll(`.lcfCardBody.${containerReference}`);
            cardBodies.forEach((cardBody) => {
                cardBody.classList.add('d-none');
            });
        }
        Object.entries(config.coverFlowCardBody).forEach((itemCardBodyAspect) => {
            const [cardBodyClass, setting] = itemCardBodyAspect;
            if (!setting) {
                const aspectToHide = document.querySelectorAll(`.${cardBodyClass}.${containerReference}`);
                aspectToHide.forEach((item) => {
                    item.classList.add('d-none');
                });
            }
        });
    }

    function LmsCoverFlow() {
        this.setGlobals = (configuration, data, element, loaded) => {
            this.callerConfiguration = configuration;
            this.callerData = data;
            this.callerContainer = element;
            this.loaded = loaded;
            this.updateGlobals();
        };
        this.setConfig = (configuration) => {
            this.callerConfiguration = configuration;
            this.updateGlobals();
        };
        this.setData = (data) => {
            this.callerData = data;
            this.updateGlobals();
        };
        this.setContainer = (element) => {
            this.callerContainer = element;
            this.updateGlobals();
        };
        this.updateGlobals = () => {
            this.config = new Config(this.callerConfiguration);
            this.data = new Data(this.config);
            this.container = new Container(this.callerContainer, this.config);
        };
        this.render = async (coverFlowContext) => {
            try {
                const containerReferenceAsClass = this.container.reference.id;
                const checkedData = await Promise.all(this.data.checkUrls(this.callerData));
                let formattedData = format(checkedData);
                if (this.loaded || this.config.coverImageExternalSources) {
                    await harvestUrls(formattedData, this.loaded, this.container.reference);
                }
                formattedData = cleanupUrls(this.config, formattedData);
                /** The check for the current card bodies is necessary, to filter
                   * the existing ones out for extension of the coverflow-component
                   * in the shelfbrowser context. */
                const currentItemContainers = document.querySelectorAll(`.lcfItemContainer.${containerReferenceAsClass}`);
                build(formattedData, coverFlowContext || this.config.coverFlowContext, this.container, this.config);
                const coverFlowEntities = await prepare(formattedData, this.config, this.container, currentItemContainers);
                /** Shelfbrowser offset calculations. */
                const newOffsetWidth = [];
                const computedFontSize = calculateComputedFontSize(this.callerContainer);
                /** Tooltip logic. */
                coverFlowEntities.forEach((entry) => {
                    const lcfNodesOfSingleCoverImageWrapper = document.querySelectorAll(`.${entry.id}.${containerReferenceAsClass}`);
                    const currentLcfItemContainer = document.querySelector(`.lcfItemContainer.${entry.id}`);
                    addDataTooltip(currentLcfItemContainer, entry);
                    /** Data population. */
                    lcfNodesOfSingleCoverImageWrapper
                        .forEach((node) => { populateTagAttributes(node, formattedData); });
                    /** Shelfbrowser offset array population. */
                    if (this.config.shelfBrowserExtendedCoverFlow && this.config.shelfBrowserButtonDirection === 'left') {
                        const lcfItemContainer = lcfNodesOfSingleCoverImageWrapper[0];
                        newOffsetWidth.push(lcfItemContainer.offsetWidth);
                    }
                    /** Flipcard logic. */
                    // eslint-disable-next-line max-len
                    addFlipCards({ id: entry.id, config: this.config, containerReference: containerReferenceAsClass });
                });
                /** Shelfbrowser offset execution. */
                if (this.config.shelfBrowserExtendedCoverFlow && this.config.shelfBrowserButtonDirection === 'left') {
                    // eslint-disable-next-line max-len
                    this.container.reference.scrollLeft += calculateCoverFlowPlusGaps(newOffsetWidth, computedFontSize);
                }
            }
            catch (error) {
                console.log(error);
            }
            /** Autoscroll logic. */
            addAutoScroll({ config: this.config, container: this.container });
            /** The following two blocks determine the visibility of card body aspects or the visibility
             * of the card body alltogether. */
            const containerReferenceAsClass = this.container.reference.id;
            changeAspectVisibility({ config: this.config, containerReference: containerReferenceAsClass });
        };
    }
    function createLcfInstance() {
        return new LmsCoverFlow();
    }

    exports.LmsCoverFlow = LmsCoverFlow;
    exports.Observable = Observable;
    exports.createLcfInstance = createLcfInstance;
    exports.removeChildNodes = removeChildNodes;

    Object.defineProperty(exports, '__esModule', { value: true });

}));
