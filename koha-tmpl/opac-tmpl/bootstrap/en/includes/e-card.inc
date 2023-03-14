[% USE raw %]
[% USE Asset %]
[% Asset.js("lib/JsBarcode.all.min.js") | $raw %]
<script defer>
    (function () {
  'use strict';

  /* eslint-disable no-underscore-dangle */
  /* eslint-disable no-undef */
  class ECard {
    constructor({ entryPoint, options = {} }) {
      const { breakpoint = 992, format, cardnumber } = options;
      this.options = options;
      this.format = format;

      const loggedInUsername = document.querySelector('.loggedinusername');
      if (!loggedInUsername) {
        throw new Error( _("Cannot find logged in username element.") );
      }

      this.cardnumber = cardnumber;
      if (!this.cardnumber) {
        throw new Error( _("Cannot find cardnumber attribute.") );
      }

      this.entryPoint = {
        ref: entryPoint,
        styles:
          'border: 2px solid rgba(0,0,0,0.1); border-radius: 12px; padding: 2em 1em; background-color: #fff; position: relative; width: 100%; z-index: 100;',
        mediaQuery: `@media only screen and (max-aspect-ratio: 1/1) { #${entryPoint.id} { transform: rotate(-90deg) translate(25%, -75%) !important; } }`,
      };
      this.eCardMobile = {
        entryPoint: options?.entryPointMobile,
        ref: undefined,
        styles: '',
        hint: _("Your library card"),
      };
      this.modalBackdrop = {
        ref: undefined,
        styles:
          'cursor: pointer; display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background-color: rgba(0, 0, 0, 0.5); z-index: 99;',
      };

      this.expanded = false;
      this.isMobileView = window.innerWidth < breakpoint;

      window.addEventListener(
        'resize',
        this.throttle(() => {
          if (this.expanded) this.collapse({ force: true });
          this.viewportWidth = window.innerWidth;
          this.isMobileView = window.innerWidth < breakpoint;
        }),
      );
    }

    set isMobileView(value) {
      this._isMobileView = value;
      this.style();
    }

    get isMobileView() {
      return this._isMobileView;
    }

    static setStyles({ element, styles }) {
      if (element) {
        element.setAttribute('style', styles);
      }
    }

    static createElementWithAttributes({ tagName, attributes }) {
      const element = document.createElement(tagName);
      Object.entries(attributes).forEach(([attribute, value]) => {
        element.setAttribute(attribute, value);
      });
      return element;
    }

    throttle(callback, delay = this.options?.throttleDelay ?? 1000) {
      let isWaiting = false;
      let waitingArgs;

      const timeoutFunc = () => {
        if (waitingArgs) {
          callback(...waitingArgs);
          waitingArgs = null;
          setTimeout(timeoutFunc, delay);
        } else {
          isWaiting = false;
        }
      };

      return (...args) => {
        if (isWaiting) {
          waitingArgs = args;
          return;
        }

        callback(...args);
        isWaiting = true;
        setTimeout(timeoutFunc, delay);
      };
    }

    style() {
      const { ref: entryPointRef, styles: entryPointStyles } = this.entryPoint;
      const { ref: modalBackdropRef, styles: modalBackdropStyles } = this.modalBackdrop;
      const { ref: eCardMobileRef, styles: eCardMobileStyles } = this.eCardMobile;

      ECard.setStyles({
        element: entryPointRef,
        styles: `${entryPointStyles}${this.isMobileView ? 'display: none;' : ''}`,
      });
      ECard.setStyles({ element: modalBackdropRef, styles: modalBackdropStyles });
      if (this.eCardMobile.ref) {
        ECard.setStyles({
          element: eCardMobileRef,
          styles: eCardMobileStyles,
        });
      }
    }

    addModalBackdrop() {
      const { styles } = this.modalBackdrop;
      const ref = ECard.createElementWithAttributes({
        tagName: 'div',
        attributes: { id: 'e-card-modal-backdrop', style: styles },
      });
      this.entryPoint.ref.insertAdjacentElement('afterend', ref);
      this.modalBackdrop.ref = ref;
    }

    addECardMobile() {
      const { styles, entryPoint } = this.eCardMobile;
      const eCardMobileButton = ECard.createElementWithAttributes({
        tagName: 'li',
        attributes: {
          class: 'nav-item',
          style: styles,
        },
      });
      const eCardMobileAnchor = ECard.createElementWithAttributes({
        tagName: 'a',
        attributes: {
          href: '#',
          'aria-label': 'e-card',
          id: 'e-card-mobile',
          role: 'button',
        },
      });
      const barcodeIcon = ECard.createElementWithAttributes({
        tagName: 'i',
        attributes: {
          class: 'fa fa-barcode fa-icon-black',
          'aria-hidden': 'true',
          id: 'e-card-mobile-icon',
        },
      });

      eCardMobileAnchor.addEventListener('keydown', (e) => {
        if (e.code === 'Space') {
          e.preventDefault();
        }
      });
      eCardMobileAnchor.addEventListener('click', (e) => {
        e.preventDefault();
        this.expand(e);
      });
      eCardMobileButton.addEventListener('keyup', (e) => {
        if (['Enter', 'Space'].includes(e.code)) {
          this.expand(e);
        }
      });

      const mobileHint = document.createTextNode(` ${this.eCardMobile.hint}`);
      eCardMobileAnchor.appendChild(barcodeIcon);
      eCardMobileAnchor.appendChild(mobileHint);
      eCardMobileButton.appendChild(eCardMobileAnchor);
      entryPoint.appendChild(eCardMobileButton);
      this.eCardMobile.ref = eCardMobileButton;
    }

    expand(e) {
      const shouldExpand = ['e-card', 'e-card-mobile', 'e-card-mobile-icon'].includes(e.target.id)
        && !this.expanded;

      if (shouldExpand) {
        const { ref } = this.modalBackdrop;
        ref.style.display = 'block';
        const mediaQuery = `<style id="e-card-media-queries">${this.entryPoint.mediaQuery}</style>`;
        this.entryPoint.ref.insertAdjacentHTML('afterend', mediaQuery);
        const styles = `${this.entryPoint.styles} position: fixed; top: 50%;left: 50%; width: 85.60mm; height: 53.98mm; transform: translate(-50%, -50%); background-color: white; box-shadow: 0px 2px 4px rgba(0, 0, 0, 0.1);`;
        ECard.setStyles({ element: this.entryPoint.ref, styles });
        this.entryPoint.ref.role = 'dialog';
        this.entryPoint.ref.focus();

        this.expanded = true;
      }
    }

    collapse({ e, force = false }) {
      const shouldCollapse = force
        || (['e-card-modal-backdrop', 'e-card'].includes(e?.target.id)
          && this.expanded);

      if (shouldCollapse) {
        const { ref } = this.modalBackdrop;
        ref.style.display = 'none';
        document.getElementById('e-card-media-queries').remove();
        ECard.setStyles({
          element: this.entryPoint.ref,
          styles: this.entryPoint.styles,
        });
        this.entryPoint.ref.role = 'button';

        if (this.isMobileView && !force) {
          this.eCardMobile.ref.firstElementChild.focus();
        }

        this.expanded = false;
      }
    }

    render() {
      if (!this.cardnumber) return;

      this.addECardMobile();
      this.addModalBackdrop();
      this.style();
      JsBarcode(this.entryPoint.ref, this.cardnumber, {
        format: this.format || 'CODE39',
        width: 2,
        height: 55,
        displayValue: true,
      });

      const { ref } = this.entryPoint;
      const { ref: modalBackdropRef } = this.modalBackdrop;
      const collapseFn = (e) => {
        e.preventDefault();
        this.collapse({ e });
        this.style();
      };

      ref.addEventListener('keydown', (e) => {
        if (e.code === 'Space') {
          e.preventDefault();
        }
      });
      ref.addEventListener('click', this.expand.bind(this));
      ref.addEventListener('keyup', (e) => {
        e.preventDefault();
        if (this.expanded) {
          if (['Escape'].includes(e.code)) {
            collapseFn(e);
          }
          return;
        }
        if (['Enter', 'Space'].includes(e.code)) {
          this.expand(e);
        }
      });
      modalBackdropRef.addEventListener('click', collapseFn);
    }
  }

  const entryPoint = document.getElementById('e-card');
  const { barcodeFormat, cardnumber } = entryPoint.dataset;

  const entryPointMobile = document.getElementById('moresearches');

  if (entryPoint) {
    const eCard = new ECard({
      entryPoint,
      options: {
        entryPointMobile,
        format: barcodeFormat,
        cardnumber,
        throttleDelay: 150,
      },
    });
    eCard.render();
  }

})();
</script>
