var ShelfBrowser = (function () {
  'use strict';

  function ShelfBrowser(LMSCoverFlow, removeChildNodes, header = {
    header_browsing: 'Browsing {starting_homebranch} shelves',
    header_location: 'Shelving location: {starting_location}',
    header_collection: 'Collection: {starting_ccode}',
    header_close: 'Close shelf',
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

    const lmsCoverFlowShelfBrowser = document.querySelectorAll('.lmscoverflow-shelfbrowser');
    const coverFlowId = 'lmscoverflow';

    const fetchItemData = async (endpoint, itemnumber, countItems) => {
      const url = `${endpoint}${itemnumber}&shelfbrowse_count_items=${countItems}`;
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
        author: item.author,
        biblionumber: item.biblionumber,
        title: item.title,
        coverurl: item.coverurl,
        itemCallNumber: item.itemcallnumber,
        referenceToDetailsView: `/cgi-bin/koha/opac-detail.pl?biblionumber=${item.biblionumber}`,
      }));

      const nearbyItems = {
        previousItemNumber: newlyLoadedItems.shelfbrowser_prev_item.itemnumber,
        nextItemNumber: newlyLoadedItems.shelfbrowser_next_item.itemnumber,
      };

      const lmscoverflow = LMSCoverFlow(
        coverFlowId,
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
          coverFlowButtonsCallback: { loadNewShelfBrowserItems, nearbyItems },
          shelfBrowserExtendedCoverFlow: extendedCoverFlow,
          shelfBrowserButtonDirection: buttonDirection,
          shelfBrowserCurrentEventListeners: instance,
        },
        shelfBrowserItems,
      );

      lmscoverflow.render();
    };

    const loadNewShelfBrowserItems = async (nearbyItems, buttonDirection) => {
      const { previousItemNumber, nextItemNumber } = nearbyItems;

      if (buttonDirection === 'left') {
        const resultPrevious = fetchItemData('/cgi-bin/koha/svc/coverflowbyshelfitem?shelfbrowse_itemnumber=', previousItemNumber, 1);
        resultPrevious.then((result) => extendCurrentCoverFlow(result, true, buttonDirection));
      } else if (buttonDirection === 'right') {
        const resultNext = fetchItemData('/cgi-bin/koha/svc/coverflowbyshelfitem?shelfbrowse_itemnumber=', nextItemNumber, 1);
        resultNext.then((result) => extendCurrentCoverFlow(result, true, buttonDirection));
      } else {
        console.trace(`Looks like something went wrong in ${loadNewShelfBrowserItems.name}`);
      }
    };

    const shelfBrowser = document.getElementById('shelfbrowser');
    const shelfBrowserHeading = document.createElement('h5');
    shelfBrowserHeading.id = 'shelfBrowserHeading';

    const shelfBrowserClose = document.createElement('a');
    shelfBrowserClose.textContent = header.header_close;
    shelfBrowserClose.setAttribute('role', 'button');
    shelfBrowserClose.style.fontSize = '.9rem';
    shelfBrowserClose.classList.add('font-weight-light', 'p-2', 'shelfBrowserClose');
    shelfBrowserClose.addEventListener('click', () => {
      shelfBrowser.classList.add('d-none');
    });

    const LMSCoverFlowShelfBrowser = () => {
      lmsCoverFlowShelfBrowser.forEach((node) => {
        node.addEventListener('click', (e) => {
          /** If new shelves are opened, the event listeners for the
             * previous shelf have to be removed. The instance properties
             * of left and right have to be reset to false again, so the
             * new event listeners are properly populated with data. */
          shelfBrowser.classList.remove('d-none');
          const container = document.getElementById(coverFlowId);
          container.replaceWith(container.cloneNode(true));

          if (!document.getElementById('shelfBrowserHeading')) {
            shelfBrowser.insertBefore(shelfBrowserHeading, shelfBrowser.firstChild);
          }

          instance.setLeftToFalse();
          instance.setRightToFalse();

          const { biblionumber, itemnumber } = e.target.dataset;
          removeChildNodes(document.getElementById(coverFlowId));

          const result = fetchItemData('/cgi-bin/koha/svc/coverflowbyshelfitem?shelfbrowse_itemnumber=', itemnumber, 7);
          result.then((result) => {
            shelfBrowserHeading.classList.add('border', 'border-secondary', 'rounded', 'p-3', 'w-75', 'centered', 'mx-auto', 'shadow-sm', 'text-center');
            shelfBrowserHeading.textContent = `
                  ${header.header_browsing.replace('{starting_homebranch}', result.starting_homebranch.description)}${result.starting_location.description ? ',' : ''}
                  ${header.header_location.replace('{starting_location}', result.starting_location.description)}${result.starting_ccode.description ? ',' : ''}
                  ${header.header_collection.replace('{starting_ccode}', result.starting_ccode.description)}
                  `;
            shelfBrowserHeading.appendChild(shelfBrowserClose);
            extendCurrentCoverFlow(result);
            setTimeout(() => shelfBrowser.scrollIntoView(), 250);
          });
        });
      });
    };

    LMSCoverFlowShelfBrowser();
  }

  return ShelfBrowser;

})();
