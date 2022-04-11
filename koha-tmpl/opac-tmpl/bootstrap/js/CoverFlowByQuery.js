var CoverFlowByQuery = (function () {
  'use strict';

  function CoverFlowByQuery({
    createLcfInstance,
    removeChildNodes,
    loaded,
  }) {
    class CurrentEventListeners {
      constructor() {
        if (!CurrentEventListeners.instance) {
          this.data = {
            left: false, right: false, leftHandler: null, rightHandler: null,
          };
          CurrentEventListeners.instance = this;
        }
        return CurrentEventListeners.instance;
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
        } else {
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

    const instance = new CurrentEventListeners();
    Object.freeze(instance);

    const lmsCoverFlowByQuery = document.querySelectorAll('.lmscoverflow-byquery');
    const coverFlowId = 'lmscoverflow';

    const fetchItemData = async (endpoint, offset, maxcount) => {
      const url = `${endpoint}&offset=${offset}&maxcount=${maxcount}`;
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
    };

    const extendCurrentCoverFlow = (
      newlyLoadedItems,
      extendedCoverFlow = false,
      buttonDirection = null,
    ) => {
      const shelfBrowserItems = newlyLoadedItems.items.map((item) => ({
        biblionumber: item.biblionumber,
        title: item.title,
        coverurl: item.coverurl,
        coverhtml: item.coverhtml,
        itemCallNumber: item.itemcallnumber,
        referenceToDetailsView: `/cgi-bin/koha/opac-detail.pl?biblionumber=${item.biblionumber}`,
      }));

      const portionData = {
        countItems: newlyLoadedItems.countItems,
        totalCount: newlyLoadedItems.totalCount,
        offset: newlyLoadedItems.offset,
        query: newlyLoadedItems.query
      };
      const lmscoverflow = createLcfInstance();
      lmscoverflow.setGlobals(
        {
          coverImageFallbackHeight: 210, // #shelfbrowser img { max-height: 250px } is koha's default.
          coverFlowTooltips: false,
          coverFlowCardBody: {
            lcfMediaAuthor: false,
            lcfMediaTitle: true,
            lcfMediaItemCallNumber: true,
          },
          coverFlowContext: 'default',
          coverFlowFlippableCards: false,
          coverFlowShelfBrowser: true,
          coverFlowButtonsCallback: { loadNewShelfBrowserItems, portionData },
          shelfBrowserExtendedCoverFlow: extendedCoverFlow,
          shelfBrowserButtonDirection: buttonDirection,
          shelfBrowserCurrentEventListeners: instance,
        },
        shelfBrowserItems,
        coverFlowId,
        loaded,
      );

      lmscoverflow.render();
      return true;
    };

    const loadNewShelfBrowserItems = async (portionData, buttonDirection) => {
      const { countItems, totalCount, offset, query } = portionData;

      if (buttonDirection === 'left' && offset > 0 ) {
        const resultPrevious = fetchItemData('/cgi-bin/koha/svc/coverflowbyquery?query=' + encodeURIComponent(query), offset - 10, 10);
        resultPrevious.then((result) => extendCurrentCoverFlow(result, true, buttonDirection));
      } else if (buttonDirection === 'right' && totalCount > (offset+countItems) ) {
        const resultNext = fetchItemData('/cgi-bin/koha/svc/coverflowbyquery?query=' + encodeURIComponent(query), offset + 10, 10);
        resultNext.then((result) => extendCurrentCoverFlow(result, true, buttonDirection));
      } else {
        console.trace(`Looks like something went wrong in ${loadNewShelfBrowserItems.name}`);
      }
    };

    const LMSCoverFlowByQuery = () => {
      lmsCoverFlowByQuery.forEach((node) => {
        node.addEventListener('click', (e) => {
 
          const container = document.getElementById(coverFlowId);
          container.replaceWith(container.cloneNode(true));

          instance.setLeftToFalse();
          instance.setRightToFalse();

          const { biblionumber, itemnumber } = e.target.dataset;
          removeChildNodes(document.getElementById(coverFlowId));

          const result = fetchItemData('/cgi-bin/koha/svc/coverflowbyquery?query=', 0, 10);
          result.then((result) => {
            const shelfBrowserLoaded = extendCurrentCoverFlow(result);
            return shelfBrowserLoaded;
          });
        });
      });
    };

    LMSCoverFlowByQuery();
  }

  return CoverFlowByQuery;

})();
