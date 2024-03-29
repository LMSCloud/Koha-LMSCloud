(function (global, factory) {
    typeof exports === 'object' && typeof module !== 'undefined' ? module.exports = factory() :
    typeof define === 'function' && define.amd ? define(factory) :
    (global = typeof globalThis !== 'undefined' ? globalThis : global || self, global.LMSEllipsis = factory());
  })(this, (function () { 'use strict';
  
    /* eslint-disable max-len */
    class LMSEllipsis {
      constructor(args) {
        this.identifier = args.identifier;
        this.ellipsis = args.ellipsis;
        this.watch = args.watch;
        this.lines = args.lines;
        this.explanations = args.explanations;
        this.approach = args.approach;
        this.elements = document.querySelectorAll(`.${this.identifier}`);
        this.init = () => {
          const style = document.createElement('style');
          const triggerCSS = '.lmsellipsis-trigger { cursor: pointer; color: #0174AD; } .lmsellipsis-trigger:hover { text-decoration: underline; }';
          const togglerCSS = `.lmsellipsis-toggler {
          cursor: pointer;
          text-align: center;
          font-size: small;
          color: #0174AD;
        }
        .lmsellipsis-toggler-text:hover {
          text-decoration: underline;
        } 
        `;
          const CSS = `${triggerCSS} ${togglerCSS}`;
          if (style.styleSheet) {
            style.styleSheet.cssText = CSS;
          } else {
            style.appendChild(document.createTextNode(CSS));
          }
          document.getElementsByTagName('head')[0].appendChild(style);
  
          const postfix = document.createElement('span');
          postfix.classList.add('lmsellipsis-postfix');
          postfix.innerText = this.ellipsis;
  
          const trigger = document.createElement('nobr');
          trigger.classList.add('lmsellipsis-trigger');
          trigger.innerText = this.explanations.collapsed;
          trigger.setAttribute('tabindex', '0');
  
          const toggler = document.createElement('div');
          toggler.classList.add('lmsellipsis-toggler');
          toggler.setAttribute('tabindex', '0');
  
          const togglerText = document.createElement('span');
          togglerText.classList.add('lmsellipsis-toggler-text');
          togglerText.innerText = this.explanations.collapsed.replace(' »', '');
  
          const togglerSymbol = document.createElement('div');
          togglerSymbol.classList.add('lmsellipsis-toggler-symbol');
          togglerSymbol.innerText = '⇩';
  
          toggler.append(togglerText, togglerSymbol);
  
          return { postfix, trigger, toggler };
        };
      }
  
      static calculateElementDimensions(element) {
        const elementHeight = element.offsetHeight;
        const elementWidth = element.offsetWidth;
        return [elementHeight, elementWidth];
      }
  
      static calculateLineQuantity(element) {
        const elementHeight = element.offsetHeight;
        const lineHeight = +window.getComputedStyle(element, null).getPropertyValue('line-height').replace('px', '');
        const lineQuantity = Math.floor(elementHeight / lineHeight);
        return [lineQuantity, lineHeight];
      }
  
      static calculateElementProperties(element) {
        const [lineQuantity, lineHeight] = LMSEllipsis.calculateLineQuantity(element);
        const [elementHeight, elementWidth] = LMSEllipsis.calculateElementDimensions(element);
        const fontFamily = window.getComputedStyle(element, null).getPropertyValue('font-family');
        const fontSize = window.getComputedStyle(element, null).getPropertyValue('font-size').replace('px', '');
        return {
          elementHeight, elementWidth, lineHeight, lineQuantity, fontFamily, fontSize,
        };
      }
  
      static generateSubstringArray(element) {
        const elementClone = element.cloneNode(true);
        elementClone.setAttribute('lang', window.navigator.language);
        elementClone.setAttribute('style', 'hyphens: auto; width: auto; position: absolute; white-space: wrap;');
        const string = elementClone.innerText;
        const substrings = string.replaceAll('"', '').replaceAll('\n', ' ').split(' ');
  
        return substrings;
      }
  
      static buildStringFromArr(substringArr) {
        let contentString = '';
        substringArr.forEach((substring) => {
          contentString += `${substring} `;
        });
        return contentString;
      }
  
      static isCollapsed(element) {
        let isCollapsed = false;
        for (let idx = 0; idx < element.childNodes.length; idx += 1) {
          if (element.childNodes[idx].className === 'lmsellipsis-postfix') {
            isCollapsed = true;
            break;
          }
        }
        return isCollapsed;
      }
  
      fitSubstrings(args) {
        const {
          substrings, element, elementWidth, explanations,
        } = args;
  
        const ruler = document.createElement('div');
        let linesToProcess = this.lines;
        let previousLineLeftSpace = 0;
        let fittedString = '';
        let previousLineLastIdx = 0;
        ruler.style.width = 'auto';
        ruler.style.position = 'absolute';
        ruler.style.whiteSpace = 'wrap';
        ruler.setAttribute('lang', window.navigator.language);
        ruler.style.hyphens = 'auto';
  
        element.appendChild(ruler);
        for (let idx = 0; idx < substrings.length; idx += 1) {
          if (linesToProcess > 1) {
            ruler.innerHTML = LMSEllipsis.buildStringFromArr(substrings.slice(previousLineLastIdx, idx));
          }
          if (linesToProcess === 1) {
            ruler.innerHTML = LMSEllipsis.buildStringFromArr(substrings.slice(previousLineLastIdx, idx));
            ruler.appendChild(explanations.postfix);
            ruler.appendChild(explanations.trigger);
          }
          if (linesToProcess === 0) {
            fittedString = LMSEllipsis.buildStringFromArr(substrings.slice(0, idx - 1));
            break;
          }
          if ((ruler.scrollWidth + previousLineLeftSpace) > elementWidth) {
            while ((ruler.scrollWidth + previousLineLeftSpace) > elementWidth) {
              ruler.innerHTML = LMSEllipsis.buildStringFromArr(substrings.slice(previousLineLastIdx, idx -= 1));
            }
            linesToProcess -= 1;
            previousLineLastIdx = idx;
            previousLineLeftSpace = elementWidth - ruler.scrollWidth;
          }
          ruler.innerHTML = '';
        }
        element.removeChild(ruler);
        return fittedString;
      }
  
      truncate() {
        const truncate = (element, tags) => {
          const modifiedElement = element;
          const originalContent = element.innerText;
          const { elementWidth, lineQuantity } = LMSEllipsis.calculateElementProperties(element);
  
          if (this.lines >= lineQuantity) return;
  
          const substrings = LMSEllipsis.generateSubstringArray(element);
  
          const postfix = tags.postfix.cloneNode(true);
          const trigger = tags.trigger.cloneNode(true);
          const shownSubstrings = this.fitSubstrings({
            substrings, element, elementWidth, explanations: { postfix, trigger },
          });
          modifiedElement.innerText = shownSubstrings;
          modifiedElement.appendChild(postfix);
          modifiedElement.appendChild(trigger);
  
          const handleInteraction = () => {
            if (LMSEllipsis.isCollapsed(modifiedElement)) {
              modifiedElement.innerText = `${originalContent} `;
              trigger.innerText = this.explanations.expanded;
              modifiedElement.appendChild(trigger);
            } else if (!LMSEllipsis.isCollapsed(modifiedElement)) {
              modifiedElement.innerText = shownSubstrings;
              modifiedElement.appendChild(postfix);
              trigger.innerText = this.explanations.collapsed;
              modifiedElement.appendChild(trigger);
            }
          };
  
          trigger.addEventListener('click', handleInteraction);
          trigger.addEventListener('keypress', (e) => { if (e.code === 'Enter' || e.code === 'Space') { handleInteraction(); } });
        };
  
        const hide = (element, tags) => {
          const modifiedElement = element;
          const {
            lineHeight, lineQuantity,
          } = LMSEllipsis.calculateElementProperties(element);
  
          if (this.lines >= lineQuantity) return;
  
          modifiedElement.style.overflow = 'hidden';
          modifiedElement.style.height = `${Math.floor(lineHeight * this.lines)}px`;
  
          const toggler = tags.toggler.cloneNode(true);
          modifiedElement.insertAdjacentElement('afterend', toggler);
  
          const handleInteraction = () => {
            const [text, symbol] = toggler.childNodes;
            if (modifiedElement.style.overflow === 'hidden') {
              modifiedElement.style.height = 'unset';
              modifiedElement.style.overflow = 'visible';
              text.innerText = this.explanations.expanded.replace('« ', '');
              symbol.innerText = '⇧';
            } else if (modifiedElement.style.overflow === 'visible') {
              modifiedElement.style.height = `${Math.floor(lineHeight * this.lines)}px`;
              modifiedElement.style.overflow = 'hidden';
              text.innerText = this.explanations.collapsed.replace(' »', '');
              symbol.innerText = '⇩';
            }
          };
  
          toggler.addEventListener('click', handleInteraction);
          toggler.addEventListener('keypress', (e) => { if (e.code === 'Enter' || e.code === 'Space') { handleInteraction(); } });
        };
  
        const { postfix, trigger, toggler } = this.init();
  
        if (this.approach === 'hide') {
          this.elements.forEach((element) => {
            hide(element, { toggler });
          });
          return;
        }
        this.elements.forEach((element) => {
          truncate(element, { postfix, trigger });
          //   if (this.watch) {
          //     window.addEventListener('resize', () => {
          //       truncate(element); // TODO: Trigger event on resize (this.watch)
          //     });
          //   }
        });
      }
    }
  
    return LMSEllipsis;
  
  }));
  