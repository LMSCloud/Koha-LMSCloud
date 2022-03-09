import { LMSCoverFlow, removeChildNodes } from '/opac-tmpl/bootstrap/js/LMSCoverFlow.js';

class CurrentEventListeners {
    constructor() {
        if (!CurrentEventListeners.instance) {
            this._data = { left: false, right: false, leftHandler: null, rightHandler: null };
            CurrentEventListeners.instance = this;
        }
        return CurrentEventListeners.instance;
    }
    toggleLeft() {
        this._data.left = !this._data.left;
    }
    toggleRight() {
        this._data.right = !this._data.right;
    }
    setHandler(handler, direction) {
        direction === 'left' ?
            this._data.leftHandler = handler :
            this._data.rightHandler = handler;
    }
    get() {
        return this._data;
    }
    getLeft() {
        return this._data.left;
    }
    getRight() {
        return this._data.right;
    }

}

const instance = new CurrentEventListeners();
Object.freeze(instance);

const lmsCoverFlowShelfBrowser = document.querySelectorAll('.lmscoverflow-shelfbrowser');
const coverFlowId = 'lmscoverflow';

const fetchItemData = async (endpoint, itemnumber) => {
    const url = `${endpoint}${itemnumber}`;
    let options = {
        method: 'GET',
        mode: 'cors',
        cache: 'no-cache',
        credentials: 'same-origin',
        headers: {
            'Content-Type': 'application/json'
        },
        redirect: 'follow'
    }

    const response = await fetch(url, options);
    return response.json();
}

const extendCurrentCoverFlow = (newlyLoadedItems, extendedCoverFlow = false, buttonDirection = null) => {
    const shelfBrowserItems = newlyLoadedItems.items.map(item => {
        return {
            title: item.title,
            coverurl: item.coverurl,
            itemCallNumber: item.itemcallnumber,
            referenceToDetailsView: `/cgi-bin/koha/opac-detail.pl?biblionumber=${item.biblionumber}`,
        }
    })

    const nearbyItems = {
        previousItemNumber: newlyLoadedItems.shelfbrowser_prev_item.itemnumber,
        nextItemNumber: newlyLoadedItems.shelfbrowser_next_item.itemnumber,
    }

    const lmscoverflow = LMSCoverFlow(
        coverFlowId,
        {
            coverImageFallbackHeight: 210, // #shelfbrowser img { max-height: 250px } is a default setting by koha.
            coverFlowContext: 'default',
            coverFlowFlippableCards: false,
            coverFlowShelfBrowser: true,
            coverFlowButtonsCallback: { loadNewShelfBrowserItems, nearbyItems },
            shelfBrowserExtendedCoverFlow: extendedCoverFlow,
            shelfBrowserButtonDirection: buttonDirection,
            shelfBrowserCurrentEventListeners: instance,
        },
        shelfBrowserItems,
    )

    lmscoverflow.render();
}

const loadNewShelfBrowserItems = async (nearbyItems, buttonDirection) => {
    const { previousItemNumber, nextItemNumber } = nearbyItems;

    if (buttonDirection === 'left') {
        const resultPrevious = fetchItemData('/cgi-bin/koha/svc/coverflowbyshelfitem?shelfbrowse_itemnumber=', previousItemNumber);
        resultPrevious.then(result => extendCurrentCoverFlow(result, true, buttonDirection))

    } else if (buttonDirection === 'right') {
        const resultNext = fetchItemData('/cgi-bin/koha/svc/coverflowbyshelfitem?shelfbrowse_itemnumber=', nextItemNumber);
        resultNext.then(result => extendCurrentCoverFlow(result, true, buttonDirection))

    } else {
        console.trace(`Looks like something went wrong in ${loadNewShelfBrowserItems.name}`);
    }

}

const LMSCoverFlowShelfBrowser = (headerTexts) => {
    for (const node of lmsCoverFlowShelfBrowser) {
        node.addEventListener('click', async e => {
            const { biblionumber, itemnumber } = e.target.dataset;
            removeChildNodes(document.getElementById(coverFlowId));

            const result = fetchItemData('/cgi-bin/koha/svc/coverflowbyshelfitem?shelfbrowse_itemnumber=', itemnumber);
            result.then(result => extendCurrentCoverFlow(result))


        })


    }

}

LMSCoverFlowShelfBrowser();
