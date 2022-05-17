(function (global, factory) {
    typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports) :
    typeof define === 'function' && define.amd ? define(['exports'], factory) :
    (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global.LMSCoverFlow = {}));
})(this, (function (exports) { 'use strict';

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

    class EventListeners {
        static instance;
        data;
        constructor() {
            if (!EventListeners.instance) {
                this.data = {
                    left: false, right: false, leftHandler: null, rightHandler: null,
                };
                EventListeners.instance = this;
            }
            // return EventListeners.instance;
        }
        setLeftToTrue() {
            this.data.left = true;
        }
        setLeftToFalse() {
            this.data.left = false;
        }
        setRightToTrue() {
            this.data.right = true;
        }
        setRightToFalse() {
            this.data.right = false;
        }
        setHandler(handler, direction) {
            if (direction === 'left') {
                this.data.leftHandler = handler;
            }
            else {
                this.data.rightHandler = handler;
            }
        }
        get() {
            return this.data;
        }
        getLeft() {
            return this.data.left;
        }
        getRight() {
            return this.data.right;
        }
    }

    const instance = new EventListeners();
    Object.freeze(instance);

    /* This method can be used to create a global style tag inside the head */
    function createStyleTag(container) {
        const lcfStyleReference = document.querySelector(`#lcfStyle.${container.referenceAsClass}`);
        if (lcfStyleReference) {
            lcfStyleReference.remove();
            const lcfStyle = document.createElement('style');
            lcfStyle.textContent = '👋 Styles injected by LMSCoverFlow are obtainable through logging out lcfStyle.sheet';
            lcfStyle.id = 'lcfStyle';
            lcfStyle.classList.add(container.referenceAsClass);
            document.head.appendChild(lcfStyle);
        }
        if (!lcfStyleReference) {
            const lcfStyle = document.createElement('style');
            lcfStyle.textContent = '👋 Styles injected by LMSCoverFlow are obtainable through logging out lcfStyle.sheet';
            lcfStyle.id = 'lcfStyle';
            lcfStyle.classList.add(container.referenceAsClass);
            document.head.appendChild(lcfStyle);
        }
    }

    /* This method can be used to append a compositedStyle to the globalStyleTag */
    function addGlobalStyle(selector, newStyle, container) {
        const lcfStyle = document.getElementById('lcfStyle');
        if (selector.includes('#') || selector.includes(':root')) {
            const compositedStyle = `${selector} {${newStyle}}`;
            lcfStyle.sheet.insertRule(compositedStyle);
        }
        else {
            const compositedStyle = selector.includes('@') || selector.startsWith('[')
                ? `${selector} {${newStyle}}`
                : `${selector}.${container.coverFlowId} {${newStyle}}`;
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
                '.lcfFlipCard:hover',
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
        const targetElement = document.querySelector(`.${selector}.${container.coverFlowId}`);
        targetElement.setAttribute('style', newStyle);
    }

    function appendToDom(newTagWithClasses, 
    // eslint-disable-next-line max-len
    container, buttonDirection, currentIndex) {
        /* If the aspect.parent references the main container (lmscoverflow), it appends the
          current item to that handle. Otherwise it looks up the parent in the LcfItemWrapperClass
          and appends to that element based on the context that the index provides. */
        const lcfNavigationButtonRight = document.querySelector(`.lcfNavigationButtonRight.${container.coverFlowId}`);
        const lcfItemContainers = document.querySelectorAll(`.lcfItemContainer.${container.coverFlowId}`);
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

    class DefaultContext {
        constructor(config, container, data, lcfLoadingAspects, lcfItemWrapperAspects, lcfNavigationAspects) {
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
                            appendToDom(createTagAndSetClasses(new LcfItemWrapper(newElementsArray[0], 'lcfAnchor', 'lcfCoverImageWrapper', [this.container.coverFlowId]), key, '', true), this.container);
                        }
                        else if (aspect.reference === 'lcfCoverImage' && newElementsArray[1].tagName === 'DIV') {
                            appendToDom(createTagAndSetClasses(new LcfItemWrapper(newElementsArray[1], 'lcfCoverImage', 'lcfAnchor', [this.container.coverFlowId]), key, '', true), this.container);
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

    // eslint-disable-next-line max-len
    function build(data, coverFlowContext, container, config, customClasses) {
        try {
            const lcfLoadingAspects = [
                new LcfItemWrapper('div', 'lcfLoadingAnimation', container.reference, [container.coverFlowId, ...customClasses]),
            ];
            const lcfNavigationAspects = [
                new LcfItemWrapper('button', 'lcfNavigationButtonLeft', container.reference, ['btn', 'd-none', container.coverFlowId, ...customClasses]),
                new LcfItemWrapper('button', 'lcfNavigationButtonRight', container.reference, ['btn', 'd-none', container.coverFlowId, ...customClasses]),
            ];
            const lcfItemWrapperAspects = [
                new LcfItemWrapper('div', 'lcfItemContainer', container.reference, ['d-none', 'card', 'border-0', 'flipCard', container.coverFlowId, ...customClasses]),
                new LcfItemWrapper('div', 'lcfFlipCard', 'lcfItemContainer', ['border', 'rounded', 'flipCardInner', container.coverFlowId, ...customClasses]),
                /** Below are tags on the front of the flipCard. */
                new LcfItemWrapper('div', 'lcfFlipCardFront', 'lcfFlipCard', ['flipCardFront', container.coverFlowId, ...customClasses]),
                new LcfItemWrapper('div', 'lcfCoverImageWrapper', 'lcfFlipCardFront', ['card-img-top', container.coverFlowId, ...customClasses]),
                new LcfItemWrapper('a', 'lcfAnchor', 'lcfCoverImageWrapper', [container.coverFlowId, ...customClasses]),
                new LcfItemWrapper('img', 'lcfCoverImage', 'lcfAnchor', [container.coverFlowId, ...customClasses]),
                // new LcfItemWrapper('div', 'lcfCoverHtmlWrapper', 'lcfAnchor', [container.coverFlowId]),
                new LcfItemWrapper('div', 'lcfCardBody', 'lcfFlipCardFront', ['card-body', 'p-2', 'text-center', container.coverFlowId, ...customClasses]),
                new LcfItemWrapper('p', 'lcfMediaAuthor', 'lcfCardBody', ['card-text', 'text-muted', 'text-truncate', 'font-weight-light', 'mb-0', config.coverFlowCardBodyTextHeights.lcfMediaAuthor, container.coverFlowId, ...customClasses]),
                new LcfItemWrapper('p', 'lcfMediaItemCallNumber', 'lcfCardBody', ['card-text', 'text-muted', 'text-truncate', 'font-weight-light', 'mb-0', config.coverFlowCardBodyTextHeights.lcfMediaItemCallNumber, container.coverFlowId, ...customClasses]),
                new LcfItemWrapper('p', 'lcfMediaTitle', 'lcfCardBody', ['card-text', 'text-truncate', 'font-weight-lighter', 'mb-0', config.coverFlowCardBodyTextHeights.lcfMediaTitle, container.coverFlowId, ...customClasses]),
            ];
            if (config.coverFlowFlippableCards) {
                lcfItemWrapperAspects.push(...[
                    /** These tags are on the back of the flipCard. */
                    new LcfItemWrapper('div', 'lcfFlipCardBack', 'lcfFlipCard', ['flipCardBack', container.coverFlowId]),
                    new LcfItemWrapper('p', 'lcfMediaISBD', 'lcfFlipCardBack', [container.coverFlowId]),
                    new LcfItemWrapper('button', 'lcfFlipCardButton', 'lcfItemContainer', ['shadow', container.coverFlowId]),
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
                createStyleTag(container);
                setGlobalStyles(config, container);
                setLoadingAnimation(config, container);
                evaluateConfiguration();
                const defaultContext = new DefaultContext(config, container, data, lcfLoadingAspects, lcfItemWrapperAspects, lcfNavigationAspects);
                defaultContext.setStyles();
                defaultContext.buildLoadingAnimation();
                defaultContext.buildLeftNavigationButton();
                defaultContext.buildCoverFlow();
                defaultContext.buildRightNavigationButton();
                defaultContext.setNavigationButtonStyles();
            }));
            strategyManager.addStrategy(new Strategy('gridContextStrategy', () => {
                createStyleTag(container);
                setGlobalStyles(config, container);
                setLoadingAnimation(config, container);
                evaluateConfiguration();
                const gridContext = new GridContext(config, container, data, lcfLoadingAspects, lcfItemWrapperAspects);
                gridContext.setStyles();
                gridContext.buildLoadingAnimation();
                gridContext.buildCoverFlow();
            }));
            strategyManager.addStrategy(new Strategy('shelfBrowserExtensionStrategy', () => {
                const defaultContext = new DefaultContext(config, container, data, lcfLoadingAspects, lcfItemWrapperAspects, lcfNavigationAspects);
                defaultContext.buildCoverFlow();
            }));
            strategyManager.addStrategy(new Strategy('shelfBrowserMobileStrategy', () => {
                // const options = {
                //   threshold: [1.0],
                // };
                // const observer = new IntersectionObserver(onEntry, options);
                createStyleTag(container);
                setGlobalStyles(config, container);
                setLoadingAnimation(config, container);
                evaluateConfiguration();
                const defaultContext = new DefaultContext(config, container, data, lcfLoadingAspects, lcfItemWrapperAspects, lcfNavigationAspects);
                defaultContext.setStyles();
                // defaultContext.setShelfBrowserMobile();
                defaultContext.buildLoadingAnimation();
                defaultContext.buildLeftNavigationButton();
                defaultContext.buildCoverFlow();
                defaultContext.buildRightNavigationButton();
                defaultContext.setNavigationButtonStyles();
                // eslint-disable-next-line max-len
                // const lcfItemContainers = document.querySelectorAll(`.lcfItemContainer.${container.coverFlowId}`);
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
        catch (error) {
            console.trace(`Looks like something went wrong in ${this.build.name} ->`, error);
            // eslint-disable-next-line consistent-return
            return error;
        }
    }

    class Config {
        constructor(configuration) {
            this.config = configuration;
            this.coverImageFallbackHeight = this.config.coverImageFallbackHeight || 210;
            this.coverImageFallbackUrl = this.config.coverImageFallbackUrl || '/api/v1/public/generated_cover';
            this.coverImageGeneratedCoverEndpoint = this.config.coverImageGeneratedCoverEndpoint || '/api/v1/public/generated_cover';
            this.coverImageFetchTimeout = this.config.coverImageFetchTimeout || 1000;
            this.coverFlowDataBiblionumberEndpoint = this.config.coverFlowDataBiblionumberEndpoint || '/api/v1/public/coverflow_data_biblionumber/';
            this.coverFlowNearbyItemsEndpoint = this.config.coverFlowNearbyItemsEndpoint || '/api/v1/public/coverflow_data_nearby_items/';
            this.coverFlowTooltips = this.config.coverFlowTooltips || false;
            this.coverFlowAutoScroll = this.config.coverFlowAutoScroll || false;
            this.coverFlowAutoScrollInterval = this.config.coverFlowAutoScrollInterval || 8000;
            this.coverFlowCardBody = this.config.coverFlowCardBody || {
                lcfMediaAuthor: true,
                lcfMediaTitle: true,
                lcfMediaItemCallNumber: false,
            };
            this.coverFlowCardBodyTextHeights = this.config.coverFlowCardBodyTextHeights || {
                lcfMediaAuthor: 'text-custom-12',
                lcfMediaTitle: 'text-custom-12',
                lcfMediaItemCallNumber: 'text-custom-12',
            };
            this.coverFlowCustomClasses = this.config.coverFlowCustomClasses || ''; // TODO: Enable selection of aspects.
            this.coverImageExternalSources = this.config.coverImageExternalSources || false;
            this.coverImageCallbackTimeout = this.config.coverImageCallbackTimeout || 500;
            this.coverFlowContext = this.config.coverFlowContext || 'default';
            this.coverFlowShelfBrowser = this.config.coverFlowShelfBrowser || false;
            this.coverFlowContainerWidth = this.config.coverFlowContainerWidth || '100%';
            this.coverFlowContainerMargin = this.config.coverFlowContainerMargin || '0%';
            this.coverFlowContainerPadding = this.config.coverFlowContainerPadding || '2rem 1px 2rem 1px';
            this.coverFlowButtonsBehaviour = this.config.coverFlowButtonsBehaviour || 'stay';
            this.coverFlowButtonsCallback = this.config.coverFlowButtonsCallback;
            this.coverFlowFlippableCards = this.config.coverFlowFlippableCards || false;
            this.coverFlowHighlightingStyle = this.config.coverFlowHighlightingStyle || 'default';
            this.gridCoverFlowBreakpoints = this.config.gridCoverFlowBreakpoints || {
                xl: 1367,
                l: 1025,
                m: 769,
                s: 481,
                xs: 320,
            };
            this.shelfBrowserExtendedCoverFlow = this.config.shelfBrowserExtendedCoverFlow || false;
            this.shelfBrowserButtonDirection = this.config.shelfBrowserButtonDirection || null;
            this.shelfBrowserCurrentEventListeners = this.config.shelfBrowserCurrentEventListeners || null;
            this.shelfBrowserScrollIntoView = this.config.shelfBrowserScrollIntoView || false;
            this.debug = this.config.debug || false;
        }
    }

    class Container {
        reference;
        scrollable;
        lcfNavigationButtonLeft;
        lcfNavigationButtonRight;
        config;
        referenceAsClass;
        constructor(element, config) {
            this.config = config;
            this.reference = document.getElementById(element);
            this.scrollable = false;
            this.lcfNavigationButtonLeft = null;
            this.lcfNavigationButtonRight = null;
            this.referenceAsClass = this.reference.id;
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
        get coverFlowId() {
            return this.referenceAsClass;
        }
        updateNavigationButtonReferences() {
            this.lcfNavigationButtonLeft = document.querySelector(`.lcfNavigationButtonLeft.${this.coverFlowId}`);
            this.lcfNavigationButtonRight = document.querySelector(`.lcfNavigationButtonRight.${this.coverFlowId}`);
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
                if (scrollRight <= 0) {
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

    /* eslint-disable max-len */
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
        // eslint-disable-next-line max-len
        async fetchWithTimeout(resource, options = {}) {
            const { timeout = 1000  } = options;
            const controller = new AbortController();
            const id = setTimeout(() => controller.abort(), timeout);
            const response = await fetch(resource, {
                ...options,
                signal: controller.signal,
            });
            clearTimeout(id);
            return response;
        }
        async checkIfFileExists(resourceInQuestion) {
            try {
                const response = await this.fetchWithTimeout(resourceInQuestion, { method: 'GET', mode: 'cors' });
                return response.ok;
            }
            catch (error) {
                console.trace(`Looks like a request failed in ${this.checkIfFileExists.name} ->`, error);
                return false;
            }
        }
        checkUrls(localData) {
            try {
                // eslint-disable-next-line max-len
                const checkedUrls = localData.map(async (entry) => {
                    const { coverurl, coverhtml } = entry;
                    if (coverhtml && !coverurl) {
                        return entry;
                    }
                    if (coverurl && coverurl.startsWith('/')) {
                        return { ...entry, coverurl: await Data.processDataUrl(`${this.config.coverImageGeneratedCoverEndpoint}?title=${window.encodeURIComponent(entry.title)}`) };
                    }
                    if (!coverurl) {
                        return {
                            ...entry,
                            coverurl: this.config.coverImageFallbackUrl !== this.config.coverImageGeneratedCoverEndpoint
                                ? this.config.coverImageFallbackUrl
                                : await Data.processDataUrl(`${this.config.coverImageGeneratedCoverEndpoint}?title=${window.encodeURIComponent(entry.title)}`),
                        };
                    }
                    const fileExists = await this.checkIfFileExists(coverurl);
                    if (!fileExists) {
                        return {
                            ...entry,
                            coverurl: this.config.coverImageFallbackUrl !== this.config.coverImageGeneratedCoverEndpoint
                                ? this.config.coverImageFallbackUrl
                                : await Data.processDataUrl(`${this.config.coverImageGeneratedCoverEndpoint}?title=${window.encodeURIComponent(entry.title)}`),
                        };
                    }
                    return entry;
                });
                return checkedUrls;
            }
            catch (error) {
                console.trace(`Looks like a something went wrong in ${this.checkUrls.name} ->`, error);
                return error;
            }
        }
        static async processDataUrl(url) {
            const response = await fetch(url);
            const result = await response.json();
            return result;
        }
    }

    function arrFromObjEntries(object) {
        return Array.from(Object.entries(object));
    }

    function additionalProperties(currentItem) {
        if (currentItem.additionalProperties) {
            const result = [];
            arrFromObjEntries(currentItem?.additionalProperties).forEach((property) => {
                const [key, value] = property;
                result.push([`data-${key}`, value]);
            });
            return result;
        }
        return undefined;
    }

    function caseMap(item) {
        return new Map([
            [
                'lcfItemContainer',
                additionalProperties(item),
            ],
            [
                'lcfAnchor',
                ['href', item.referenceToDetailsView],
            ],
            [
                'lcfCoverImage',
                ['src', item?.coverurl],
            ],
            [
                'lcfCoverHtmlWrapper',
                ['innerHtml', item?.coverhtml || ''],
            ],
            [
                'lcfMediaTitle',
                [['textContent', 'data-text'], item.title],
            ],
            [
                'lcfMediaAuthor',
                ['textContent', item.author],
            ],
            [
                'lcfMediaItemCallNumber',
                ['textContent', item.itemCallNumber],
            ],
            [
                'lcfMediaISBD',
                ['textContent', `${item.author}: ${item.title}`],
            ],
            [
                'lcfFlipCardButton',
                ['textContent', '←'],
            ],
        ]);
    }

    function determineStructure(attribute, data) {
        return [Array.isArray(attribute), Array.isArray(data)];
    }
    function getInstructions(lcfClass, map) { return map.get(lcfClass); }
    function isTextContent(attribute) { return attribute === 'textContent'; }

    function runInstructions(currentTag, currentInstructions) {
        const aspect = currentTag;
        const [attribute, data] = currentInstructions;
        const [attrBool, dBool] = determineStructure(attribute, data);
        const textContentBool = isTextContent(attribute);
        if (attrBool && dBool) {
            currentInstructions.forEach((instr) => {
                const [attr, d] = instr;
                if (isTextContent(attr)) {
                    aspect.textContent = d;
                    return;
                }
                aspect.setAttribute(attr, d);
            });
        }
        if (attrBool) {
            attribute.forEach((attr) => {
                if (isTextContent(attr)) {
                    aspect.textContent = data;
                    return;
                }
                aspect.setAttribute(attr, data);
            });
            return;
        }
        if (dBool) {
            data.forEach((d) => { aspect.setAttribute(attribute, d); });
            return;
        }
        if (textContentBool) {
            aspect.textContent = data;
            return;
        }
        aspect.setAttribute(attribute, data);
    }

    function populateTagAttributes(node, formattedData) {
        try {
            const tag = node;
            const [reference, index] = tag.classList;
            const item = formattedData[index];
            const cases = caseMap(item);
            const instructions = getInstructions(reference, cases);
            if (instructions) {
                runInstructions(tag, instructions);
            }
        }
        catch (error) {
            console.trace(`Looks like something went wrong in ${this.populateTagAttributes.name} ->`, error);
        }
    }

    async function urlHarvester(formattedData, containerReference) {
        try {
            const dataArray = arrFromObjEntries(formattedData);
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

    function getLcfItemId(domNode) {
        const id = domNode?.classList[1];
        if (!/_[0-9]{7}/.test(id))
            throw new Error("Id doesn't match pattern.");
        return id;
    }

    /* eslint-disable no-underscore-dangle */
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

    const externalSources = new Observable(false);

    async function harvestUrls(formattedData, container, config) {
        try {
            const dataReference = formattedData;
            const containerReference = container;
            const harvesterBuilt = await urlHarvester(dataReference, containerReference);
            if (harvesterBuilt) {
                let harvesterElements = document.querySelectorAll('.harvesterElement');
                const harvesterResults = [];
                // eslint-disable-next-line no-underscore-dangle
                if (externalSources._listeners.length !== 0) {
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
                                /** Google specific url parameters. Somehow the identifier &amp; ends up
                               * in the resulting string when it should be just & instead. */
                                srcString = `${srcString.replaceAll('amp;', '').replace(/zoom=./g, 'zoom=1')}&gbs_api`;
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
                        harvesterElements = document.querySelectorAll('.harvesterElement');
                        harvesterElements.forEach((node) => {
                            const nodeId = getLcfItemId(node);
                            harvesterObservers[nodeId].value = node.innerHTML;
                        });
                    }, config.coverImageCallbackTimeout);
                    setTimeout(() => {
                        const resultIds = [];
                        harvesterResults.forEach(async (entry) => {
                            const [id, coverurl] = entry;
                            if (coverurl) {
                                dataReference[id].coverurl = coverurl;
                                resultIds.push(id);
                            }
                            else {
                                /** We can't await the result here because of setTimeout. */
                                dataReference[id].coverurl = Data.processDataUrl(`${config.coverImageGeneratedCoverEndpoint}?title=${window.encodeURIComponent(dataReference[id].title)}`);
                            }
                            harvesterElements.forEach((node) => {
                                const nodeId = getLcfItemId(node);
                                if (!resultIds.includes(nodeId)) {
                                    dataReference[nodeId].coverurl = Data.processDataUrl(`${config.coverImageGeneratedCoverEndpoint}?title=${window.encodeURIComponent(dataReference[nodeId].title)}`);
                                }
                            });
                        });
                    }, config.coverImageCallbackTimeout);
                    await resyncExecution(config.coverImageCallbackTimeout);
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
                        harvesterResults.forEach(async (entry) => {
                            const [id, coverurl] = entry;
                            if (coverurl) {
                                dataReference[id].coverurl = coverurl;
                            }
                            else {
                                /** We can't await the result here because of setTimeout. */
                                dataReference[id].coverurl = Data.processDataUrl(`${config.coverImageGeneratedCoverEndpoint}?title=${window.encodeURIComponent(dataReference[id].title)}`);
                            }
                        });
                        clearHarvester();
                    });
                }
            }
        }
        catch (error) {
            console.trace(`Looks like harvesting failed in ${this.harvestUrls.name} ->`, error);
            return error;
        }
        return 1;
    }

    function calculateComputedFontSize(container) {
        try {
            return parseInt(window.getComputedStyle(document.getElementById(container)).fontSize.split('px')[0], 10);
        }
        catch (error) {
            console.trace(`Looks like somthing went wrong in ${this.calculateComputedFontSize.name} ->`, error);
            return error;
        }
    }

    function calculateCoverFlowPlusGaps(offsetWidthArray, computedFontSize) {
        try {
            return offsetWidthArray
                .reduce((accumulator, currentValue) => accumulator + currentValue + computedFontSize)
                + computedFontSize;
        }
        catch (error) {
            console.trace(`Looks like somthing went wrong in ${this.calculateCoverFlowPlusGaps.name} ->`, error);
            return error;
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

    function isPromise(p) {
        if (typeof p === 'object' && typeof p.then === 'function') {
            return true;
        }
        return false;
    }

    function cleanupUrls(config, formattedData) {
        try {
            const cleanedData = formattedData;
            arrFromObjEntries(formattedData).forEach(async (entry) => {
                const [id, data] = entry;
                if (isPromise(data.coverurl)) {
                    const result = await data.coverurl;
                    cleanedData[id] = { ...data, coverurl: result };
                    return;
                }
                cleanedData[id] = {
                    ...data, coverurl: data.coverurl || config.coverImageFallbackUrl,
                };
            });
            return cleanedData;
        }
        catch (error) {
            console.trace(`Looks like something went wrong in in ${this.checkIfFileExists.name} ->`, error);
            return error;
        }
    }

    class ErrorLogger {
        messages;
        constructor() {
            this.messages = [];
        }
        log(message, containerReference) {
            const date = new Date();
            const datePrefix = `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()}@${date.getHours()}:${date.getMinutes()}:${date.getSeconds()}`;
            this.messages.push(`${datePrefix}\t[${containerReference}]\t${message}`);
        }
        show() {
            let output = '';
            this.messages.forEach((message) => {
                output += `${message}
      `;
            });
            console.log(output);
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
        try {
            return Object.fromEntries(Object.entries(localData).map(([, v]) => [generateId(), v]));
        }
        catch (error) {
            console.trace(`Looks like something didn't map properly in ${this.format.name} ->`, error);
            return error;
        }
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

    // eslint-disable-next-line max-len
    function addDataTooltip(lcfItemContainer, coverFlowEntity) {
        try {
            const itemContainer = lcfItemContainer;
            itemContainer.dataset.tooltip = `${coverFlowEntity.author ? coverFlowEntity.author : ''} ${coverFlowEntity.itemCallNumber ? coverFlowEntity.itemCallNumber : ''} ${coverFlowEntity.title ? coverFlowEntity.title : ''}`;
        }
        catch (error) {
            console.trace(`Looks like something went wrong in ${this.addDataTooltip.name} ->`, error);
        }
    }

    function addFlipCards({ id, config, containerReference }) {
        if (config.coverFlowFlippableCards) {
            try {
                const lcfFlipCardButton = document.querySelector(`.lcfFlipCardButton.${id}.${containerReference}`);
                lcfFlipCardButton.addEventListener('click', () => {
                    const innerFlipCard = document.querySelector(`.flipCardInner.${id}.${containerReference}`);
                    innerFlipCard.classList.toggle('cardIsFlipped');
                    lcfFlipCardButton.classList.toggle('buttonIsFlipped');
                });
            }
            catch (error) {
                console.trace(`Looks like somthing went wrong in ${this.addFlipCards.name} ->`, error);
            }
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

    function entityToCoverFlow(config, lcfCoverFlowEntities) {
        const promisedCoverFlowEntities = [];
        try {
            lcfCoverFlowEntities.forEach(async (entity) => {
                const newLcfEntity = new LcfEntity({
                    id: entity.id,
                    title: entity.entry.title,
                    author: entity.entry.author,
                    biblionumber: entity.entry.biblionumber,
                    coverurl: entity.entry.coverurl,
                    coverhtml: entity.entry.coverhtml,
                    referenceToDetailsView: entity.entry.referenceToDetailsView,
                    itemCallNumber: entity.entry.itemCallNumber,
                }, config.coverImageFallbackHeight);
                if (entity.image) {
                    newLcfEntity.addCoverImageMetadata(entity.image.naturalHeight, entity.image.naturalWidth);
                }
                promisedCoverFlowEntities.push(new Promise((resolve) => { resolve(newLcfEntity); }));
            });
            return promisedCoverFlowEntities;
        }
        catch (error) {
            console.trace(`Looks like something went wrong in ${entityToCoverFlow.name} ->`, error);
            return null;
        }
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

    /* eslint-disable max-len */
    /* This promise chain is the main block for displaying covers. The global coverFlowEntities
       * Object gets flattened to promise level. The mapped imageHeights are used to set a universal
       * height for all images. Then the card widths are adjusted to the corresponding image widths.
       * Before the cards are displayed, a loading animation renders to bridge the gap between
       * awaiting all images and the depending methods for image sizing and so on. */
    async function settlePromises(config, 
    // eslint-disable-next-line max-len
    container, currentItemContainers, promisedEntities) {
        try {
            const result = await Promise.allSettled(promisedEntities);
            const flattenedResults = flattenPromiseResults(result);
            const lcfCoverImageHeights = flattenedResults.map((lcfEntity) => (lcfEntity.imageHeight ? lcfEntity.imageHeight : null));
            let lcfItemContainers = Array.from(document.querySelectorAll(`.lcfItemContainer.${container.coverFlowId}`));
            /** We determine whether all images have a height of null which may be the case when
             * external sources provide them. */
            const imageArrayExistent = !lcfCoverImageHeights.every((height) => height === null);
            const lcfCoverImages = document.querySelectorAll(`.lcfCoverImage.${container.coverFlowId}`);
            const initialPopulation = Array.from(Object.values(lcfCoverImages)).every((image) => image.height === 0);
            let initialSetImageHeight;
            if (!initialPopulation) {
                const centralImage = lcfCoverImages[Math.floor(lcfCoverImages.length / 2)];
                initialSetImageHeight = centralImage.height;
            }
            /** This handles the default case with images served via their urls. */
            if (imageArrayExistent) {
                const imagesMaxHeight = processHeights(lcfCoverImageHeights, config);
                addGlobalStyle('.lcfCoverImage', `height: ${imagesMaxHeight}px`, container);
                const localCurrentItemContainers = Array.from(currentItemContainers);
                lcfItemContainers = lcfItemContainers.filter((lcfItemContainer) => !localCurrentItemContainers.includes(lcfItemContainer));
                lcfItemContainers.forEach((lcfCardBody) => {
                    const lcfItemId = getLcfItemId(lcfCardBody);
                    const lcfItemCurrent = flattenedResults.filter((lcfEntity) => lcfEntity.id === lcfItemId)[0];
                    /** Updates the imageComputedWid†h property if the tallest image is still
                     * shorter than the coverImageFallbackHeight.   */
                    lcfItemCurrent.updateMaxHeight(initialSetImageHeight || imagesMaxHeight);
                    lcfItemCurrent.updateDimensions();
                    /** Sets width of the whole card. */
                    addInlineStyle(`lcfItemContainer.${lcfItemCurrent.id}`, `flex-basis: ${lcfItemCurrent.imageComputedWidth + 2}px;`, container);
                });
            }
            /** This handles images served via external sources. */
            if (!imageArrayExistent) {
                lcfCoverImages.forEach((lcfCoverImage) => lcfCoverImage.classList.add('d-none'));
            }
            /** Hides the loading animation. */
            const lcfLoadingAnimation = document.querySelector(`.lcfLoadingAnimation.${container.coverFlowId}`);
            lcfLoadingAnimation.classList.add('d-none');
            /** Removes d-none from all item containers and shows the content. */
            lcfItemContainers.forEach((lcfItemContainer) => {
                lcfItemContainer.classList.remove('d-none');
            });
            const shelfBrowserReference = document.getElementById('shelfbrowser');
            if (shelfBrowserReference && config.shelfBrowserScrollIntoView) {
                setTimeout(() => shelfBrowserReference.scrollIntoView(), 100);
            }
            container.isScrollable();
            if (config.coverFlowContext === 'default' && window.screen.width >= config.gridCoverFlowBreakpoints.s) {
                const lcfNavigationButtonRight = document.querySelector(`.lcfNavigationButtonRight.${container.coverFlowId}`);
                const lcfNavigationButtonLeft = document.querySelector(`.lcfNavigationButtonLeft.${container.coverFlowId}`);
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
        try {
            let lcfCoverImages = [];
            const lcfCoverFlowEntities = [];
            const externalData = Object.entries(data);
            /** To work in the data urls that possibly come with the external data
                     *  the promises in which these are wrapped need to be resolved for a
                     *  uniform array, that the rest of the application understands. */
            const cleanedData = [];
            externalData.forEach((datum) => {
                const [id] = datum;
                cleanedData.push([id]);
            });
            const externalDataPromisedUrlsResolved = externalData.map(async (datum) => {
                const [, entry] = datum;
                let resolvedCoverurl;
                if (isPromise(entry.coverurl)) {
                    resolvedCoverurl = await entry.coverurl;
                }
                return { ...entry, coverurl: resolvedCoverurl || entry.coverurl };
            });
            const entries = await Promise.all(externalDataPromisedUrlsResolved);
            cleanedData.forEach((id, idx) => {
                id.push(entries[idx]);
            });
            Array.from(cleanedData).forEach((entry) => {
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
            const promisedCoverFlowEntities = entityToCoverFlow(config, lcfCoverFlowEntities);
            // eslint-disable-next-line max-len
            return await settlePromises(config, container, currentItemContainers, promisedCoverFlowEntities);
        }
        catch (error) {
            console.trace(`Looks like something went wrong in ${this.prepare.name} ->`, error);
            return error;
        }
    }

    /* eslint-disable max-len */
    function LmsCoverFlow() {
        this.setGlobals = (configuration, data, element) => {
            this.callerConfiguration = configuration;
            this.callerData = data;
            this.callerContainer = element;
            this.logger = new ErrorLogger();
            this.updateGlobals();
        };
        this.setConfig = (configuration) => {
            this.callerConfiguration = configuration;
            this.updateGlobals();
        };
        this.getConfig = () => this.callerConfiguration;
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
                const checkedData = await Promise.all(this.data.checkUrls(this.callerData));
                let formattedData = format(checkedData);
                if (externalSources || this.config.coverImageExternalSources) {
                    await harvestUrls(formattedData, this.container.reference, this.config);
                }
                formattedData = cleanupUrls(this.config, formattedData);
                /** The check for the current card bodies is necessary, to filter
                     * the existing ones out for extension of the coverflow-component
                     * in the shelfbrowser context. */
                const currentItemContainers = document.querySelectorAll(`.lcfItemContainer.${this.container.coverFlowId}`);
                build(formattedData, coverFlowContext || this.config.coverFlowContext, this.container, this.config, this.config.coverFlowCustomClasses);
                const coverFlowEntities = await prepare(formattedData, this.config, this.container, currentItemContainers);
                /** Shelfbrowser offset calculations. */
                const newOffsetWidth = [];
                const computedFontSize = calculateComputedFontSize(this.callerContainer);
                /** Tooltip logic. */
                coverFlowEntities.forEach((entry) => {
                    const lcfNodesOfSingleCoverImageWrapper = document.querySelectorAll(`.${entry.id}.${this.container.coverFlowId}`);
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
                    addFlipCards({ id: entry.id, config: this.config, containerReference: this.container.coverFlowId });
                });
                /** Shelfbrowser offset execution. */
                if (this.config.shelfBrowserExtendedCoverFlow && this.config.shelfBrowserButtonDirection === 'left') {
                    this.container.reference.scrollLeft += calculateCoverFlowPlusGaps(newOffsetWidth, computedFontSize);
                }
            }
            catch (error) {
                if (this.config.debug) {
                    this.logger.log(error, this.container.coverFlowId);
                    this.logger.show();
                }
            }
            /** Autoscroll logic. */
            addAutoScroll({ config: this.config, container: this.container });
            /** Conditionally hide or show aspects of card bodies. */
            changeAspectVisibility({ config: this.config, containerReference: this.container.coverFlowId });
        };
    }

    // eslint-disable-next-line import/no-cycle
    function createLcfInstance() { return new LmsCoverFlow(); }

    function overrideConfig(configuration, changes) {
        const modifiedConfiguration = configuration;
        arrFromObjEntries(changes).forEach((change) => {
            const [option, value] = change;
            modifiedConfiguration[option] = value;
        });
        return modifiedConfiguration;
    }

    const shelfBrowserConfig = new Observable({});

    // eslint-disable-next-line max-len
    function extendCurrentCoverFlow({ newlyLoadedItems, extendedCoverFlow = false, buttonDirection = null, loadNewShelfBrowserItems, coverFlowId, }) {
        const shelfBrowserItems = newlyLoadedItems.items.map((item) => ({
            biblionumber: item.biblionumber,
            title: item.title,
            coverurl: item.coverurl,
            coverhtml: item.coverhtml,
            itemCallNumber: item.itemcallnumber,
            referenceToDetailsView: `/cgi-bin/koha/opac-detail.pl?biblionumber=${item.biblionumber}`,
        }));
        const nearbyItems = {
            previousItemNumber: newlyLoadedItems.prev_item ? newlyLoadedItems.prev_item.itemnumber : null,
            nextItemNumber: newlyLoadedItems.next_item ? newlyLoadedItems.next_item.itemnumber : null,
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
            coverFlowContext: 'default',
            coverFlowFlippableCards: false,
            coverFlowShelfBrowser: true,
            coverFlowButtonsCallback: { loadNewShelfBrowserItems, nearbyItems },
            shelfBrowserExtendedCoverFlow: extendedCoverFlow,
            shelfBrowserButtonDirection: buttonDirection,
            shelfBrowserCurrentEventListeners: instance,
            shelfBrowserScrollIntoView: true,
        };
        // eslint-disable-next-line max-len
        shelfBrowserCoverFlowConfig = overrideConfig(shelfBrowserCoverFlowConfig, shelfBrowserConfig.value);
        lmscoverflow.setGlobals(shelfBrowserCoverFlowConfig, shelfBrowserItems, coverFlowId);
        lmscoverflow.render();
    }

    async function fetchItemData(endpoint, itemnumber, countItems) {
        const url = `${endpoint}${itemnumber}?quantity=${countItems}`;
        const options = {
            method: 'GET',
            mode: 'cors',
            cache: 'no-cache',
            credentials: 'same-origin',
            headers: {
                'Content-Type': 'application/json',
            },
            redirect: 'follow',
        };
        const response = await fetch(url, options);
        return response.json();
    }

    // import showInfoModal from './showInfoModal';
    async function loadNewShelfBrowserItems(nearbyItems, buttonDirection) {
        const { previousItemNumber, nextItemNumber } = nearbyItems;
        const coverFlowId = 'lmscoverflow';
        const shelfBrowserEndpoint = '/api/v1/public/coverflow_data_nearby_items/';
        const args = {
            extendedCoverFlow: true,
            buttonDirection,
            loadNewShelfBrowserItems,
            instance,
            coverFlowId,
        };
        if (buttonDirection === 'left' && previousItemNumber) {
            const resultPrevious = fetchItemData(shelfBrowserEndpoint, previousItemNumber, 1);
            resultPrevious.then((result) => extendCurrentCoverFlow({ newlyLoadedItems: result, ...args }));
        }
        else if (buttonDirection === 'right' && nextItemNumber) {
            const resultNext = fetchItemData(shelfBrowserEndpoint, nextItemNumber, 1);
            resultNext.then((result) => extendCurrentCoverFlow({ newlyLoadedItems: result, ...args }));
        }
        else {
            // if (!previousItemNumber) { showInfoModal('No previous items!', 1000, 'left'); }
            // if (!nextItemNumber) { showInfoModal('No following items!', 1000, 'right'); }
            console.trace(`Looks like something went wrong in ${loadNewShelfBrowserItems.name}`);
        }
    }

    function shelfBrowser({ header = {
        header_browsing: 'Browsing {starting_homebranch} shelves',
        header_location: 'Shelving location: {starting_location}',
        header_collection: 'Collection: {starting_ccode}',
        header_close: 'Close shelf',
    }, configuration, }) {
        if (configuration) {
            shelfBrowserConfig.value = configuration;
        }
        const lmsCoverFlowShelfBrowser = document.querySelectorAll('.lmscoverflow-shelfbrowser');
        const coverFlowId = 'lmscoverflow';
        const shelfBrowserReference = document.getElementById('shelfbrowser');
        const shelfBrowserHeading = document.createElement('h5');
        shelfBrowserHeading.id = 'shelfBrowserHeading';
        const shelfBrowserClose = document.createElement('a');
        shelfBrowserClose.textContent = header.header_close;
        shelfBrowserClose.setAttribute('role', 'button');
        shelfBrowserClose.style.fontSize = '.9rem';
        shelfBrowserClose.classList.add('font-weight-light', 'p-2', 'shelfBrowserClose');
        shelfBrowserClose.addEventListener('click', () => {
            shelfBrowserReference.classList.add('d-none');
        });
        const main = () => {
            lmsCoverFlowShelfBrowser.forEach((node) => {
                node.addEventListener('click', async (e) => {
                    e.preventDefault();
                    const target = e.target;
                    const shelfBrowserEndpoint = '/api/v1/public/coverflow_data_nearby_items/';
                    /** If new shelves are opened, the event listeners for the
                         * previous shelf have to be removed. The instance properties
                         * of left and right have to be reset to false again, so the
                         * new event listeners are properly populated with data. */
                    shelfBrowserReference.classList.remove('d-none');
                    const container = document.getElementById(coverFlowId);
                    container.replaceWith(container.cloneNode(true));
                    if (!document.getElementById('shelfBrowserHeading')) {
                        shelfBrowserReference.insertBefore(shelfBrowserHeading, shelfBrowserReference.firstChild);
                    }
                    instance.setLeftToFalse();
                    instance.setRightToFalse();
                    const { /* biblionumber, */ itemnumber } = target.dataset;
                    removeChildNodes(document.getElementById(coverFlowId));
                    const result = await fetchItemData(shelfBrowserEndpoint, itemnumber, 7);
                    shelfBrowserHeading.classList.add('border', 'border-secondary', 'rounded', 'p-3', 'w-75', 'centered', 'mx-auto', 'shadow-sm', 'text-center');
                    shelfBrowserHeading.textContent = `
                    ${(result.starting_homebranch && result.starting_homebranch.description) ? header.header_browsing.replace('{starting_homebranch}', result.starting_homebranch.description) : ''}${(result.starting_location && result.starting_location.description) ? ',' : ''}
                    ${(result.starting_location && result.starting_location.description) ? header.header_location.replace('{starting_location}', result.starting_location.description) : ''}${(result.starting_ccode && result.starting_ccode.description) ? ',' : ''}
                    ${(result.starting_ccode && result.starting_ccode.description) ? header.header_collection.replace('{starting_ccode}', result.starting_ccode.description) : ''}
                    `;
                    shelfBrowserHeading.appendChild(shelfBrowserClose);
                    extendCurrentCoverFlow({
                        newlyLoadedItems: result, loadNewShelfBrowserItems, coverFlowId,
                    });
                });
            });
        };
        main();
    }

    class CoverflowByQuery {
        id;
        query;
        label;
        endpoint;
        offset;
        maxcount;
        data;
        config;
        externalSourceInUse;
        constructor({ id, query, label, endpoint, offset, maxcount, externalSourcesInUse, }) {
            const instance = new EventListeners();
            instance.data = {
                left: false, right: false, leftHandler: null, rightHandler: null,
            };
            const { coce, openLibrary, google } = externalSourcesInUse;
            this.id = id;
            this.query = query;
            this.label = label;
            this.endpoint = endpoint;
            this.offset = offset;
            this.maxcount = maxcount;
            this.externalSourceInUse = coce || openLibrary || google;
            this.data = {};
            this.config = {
                coverImageFallbackHeight: 210,
                coverFlowCardBody: {
                    lcfMediaAuthor: true,
                    lcfMediaTitle: true,
                    lcfMediaItemCallNumber: false,
                },
                coverFlowContext: 'default',
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
        async fetchItemData() {
            const url = `${this.endpoint}?query=${this.query}&offset=${this.offset}&maxcount=${this.maxcount}`;
            const options = {
                method: 'GET',
                mode: 'cors',
                cache: 'no-cache',
                credentials: 'same-origin',
                headers: {
                    'Content-Type': 'application/json',
                },
                redirect: 'follow',
            };
            const response = await fetch(url, options);
            this.data = await response.json();
            /** Add referenceToDetailsView to the resulting object. */
            this.data.referenceToDetailsView = `/cgi-bin/koha/opac-detail.pl?biblionumber=${this.data.biblionumber}`;
        }
        async loadPortion(nearbyItems, buttonDirection) {
            const { previousItemNumber, nextItemNumber } = nearbyItems;
            this.config = {
                ...this.config,
                shelfBrowserExtendedCoverFlow: true,
                shelfBrowserButtonDirection: buttonDirection,
            };
            if (buttonDirection === 'left' && previousItemNumber > 0) {
                this.offset -= this.maxcount;
                await this.fetchItemData();
                if (this.externalSourceInUse) {
                    externalSources.subscribe((isLoaded) => {
                        if (isLoaded) {
                            if (this.externalSourceInUse.args) {
                                this.externalSourceInUse.callback(...this.externalSourceInUse.args);
                            }
                            else {
                                this.externalSourceInUse.callback();
                            }
                        }
                    });
                }
                this.render();
            }
            else if (buttonDirection === 'right' && nextItemNumber) {
                this.offset += this.maxcount;
                await this.fetchItemData();
                if (this.externalSourceInUse) {
                    externalSources.subscribe((isLoaded) => {
                        if (isLoaded) {
                            if (this.externalSourceInUse.args) {
                                this.externalSourceInUse.callback(...this.externalSourceInUse.args);
                            }
                            else {
                                this.externalSourceInUse.callback();
                            }
                        }
                    });
                }
                this.render();
            }
            else {
                console.trace(`Looks like something went wrong in ${this.loadPortion.name}`);
            }
        }
        renderHeader() {
            const coverflowQueryContainer = document.getElementById(this.id);
            const section = document.createElement('section');
            const label = document.createElement('header');
            label.textContent = this.label;
            label.classList.add('h3', 'text-muted', 'pl-3');
            coverflowQueryContainer.insertAdjacentElement('beforebegin', section);
            section.appendChild(label);
            section.appendChild(coverflowQueryContainer);
        }
        render() {
            const lmscoverflow = createLcfInstance();
            lmscoverflow.setGlobals(this.config, this.data.items, this.id);
            if (this.externalSourceInUse) {
                externalSources.subscribe((isLoaded) => {
                    if (isLoaded) {
                        if (this.externalSourceInUse.args) {
                            this.externalSourceInUse.callback(...this.externalSourceInUse.args);
                        }
                        else {
                            this.externalSourceInUse.callback();
                        }
                    }
                });
            }
            lmscoverflow.render();
        }
    }

    exports.CoverflowByQuery = CoverflowByQuery;
    exports.ShelfBrowser = shelfBrowser;
    exports.createLcfInstance = createLcfInstance;
    exports.externalSources = externalSources;

    Object.defineProperty(exports, '__esModule', { value: true });

}));
