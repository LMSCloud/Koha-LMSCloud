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
        this.elements = document.querySelectorAll(`.${this.identifier}`);
        this.init = () => {
          const style = document.createElement('style');
          const triggerCSS = '.lmsellipsis-trigger { cursor: pointer; color: #0174AD; } .lmsellipsis-trigger:hover { text-decoration: underline; }';
          if (style.styleSheet) {
            style.styleSheet.cssText = triggerCSS;
          } else {
            style.appendChild(document.createTextNode(triggerCSS));
          }
          document.getElementsByTagName('head')[0].appendChild(style);
  
          const postfix = document.createElement('span');
          postfix.classList.add('lmsellipsis-postfix');
          postfix.innerText = this.ellipsis;
  
          const trigger = document.createElement('nobr');
          trigger.classList.add('lmsellipsis-trigger');
          trigger.innerText = this.explanations.collapsed;
          trigger.setAttribute('tabindex', '0');
  
          return [postfix, trigger];
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
  
      static generateSubstringArray(element, placeholder, props) {
        const ruler = placeholder;
        element.setAttribute('lang', window.navigator.language);
        element.setAttribute('style', 'hyphens: auto;');
        const string = element.innerText;
        const substrings = string.replaceAll('"', '').replaceAll('\n', '\n ').split(' ');
        const substringWidths = [];
  
        substrings.forEach((substring) => {
          ruler.style.width = 'auto';
          ruler.style.position = 'absolute';
          ruler.style.whiteSpace = 'nowrap';
          ruler.style.fontFamily = props.fontFamily;
          ruler.style.fontSize = props.fontSize;
          ruler.innerText = `${substring}${String.fromCharCode(0X1F)}`;
          element.appendChild(ruler);
          const substringWidth = ruler.clientWidth;
          substringWidths.push(substringWidth);
  
          element.removeChild(ruler);
        });
  
        return [substrings, substringWidths];
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
  
      trimSubstrings(substrings, substringWidthsArr, elementWidth, explanationWidth) {
        const substringWidths = substringWidthsArr;
        let linesToProcess = this.lines;
        let accumulator = 0;
        let indexOfLastSubstring = 0;
        let removedSubstring = 0;
  
        while (substringWidths.length > 0) {
          if (linesToProcess === 1) {
            if ((elementWidth - accumulator) < explanationWidth) {
              break;
            }
            if (substrings[indexOfLastSubstring].includes('\n')) {
              break;
            }
          } else if (accumulator >= elementWidth) {
            linesToProcess -= 1;
            accumulator = 0;
          }
          removedSubstring = substringWidths.shift();
          accumulator += removedSubstring;
          indexOfLastSubstring += 1;
          if (substrings[indexOfLastSubstring - 1].includes('\n')) {
            linesToProcess -= 1;
          }
        }
        return indexOfLastSubstring;
      }
  
      static calculateExplanationWidth(element, explanation, fontFamily) {
        const ruler = document.createElement('nobr');
        ruler.style.width = 'auto';
        ruler.style.position = 'absolute';
        ruler.style.whiteSpace = 'nowrap';
        ruler.style.fontFamily = fontFamily;
        ruler.setAttribute('lang', window.navigator.language);
        ruler.style.hyphens = 'auto';
        ruler.innerText = `${this.ellipsis}${explanation}`;
  
        element.appendChild(ruler);
        const substringWidth = ruler.clientWidth;
  
        element.removeChild(ruler);
  
        return substringWidth;
      }
  
      truncate() {
        const truncate = (element, tags) => {
          const modifiedElement = element;
          const elementType = element.tagName;
          const placeholder = document.createElement(elementType);
  
          const {
            elementHeight, elementWidth, lineHeight, lineQuantity, fontFamily, fontSize,
          } = LMSEllipsis.calculateElementProperties(element);
  
          if (this.lines >= lineQuantity) return;
  
          const expanded = LMSEllipsis.calculateExplanationWidth(element, this.explanations.expanded, fontFamily);
          const collapsed = LMSEllipsis.calculateExplanationWidth(element, this.explanations.collapsed, fontFamily);
          const explanationWidth = collapsed >= expanded ? collapsed : expanded;
  
          const [substrings, substringWidths] = LMSEllipsis.generateSubstringArray(element, placeholder, {
            elementHeight, elementWidth, lineHeight, lineQuantity, fontFamily, fontSize,
          });
  
          const indexOfLastSubstring = this.trimSubstrings(substrings, substringWidths, elementWidth, explanationWidth);
  
          const shownSubstringsArr = substrings.slice(0, indexOfLastSubstring);
          const wholeSubstringArr = substrings;
  
          modifiedElement.innerText = LMSEllipsis.buildStringFromArr(shownSubstringsArr);
          const postfix = tags.postfix.cloneNode(true);
          const trigger = tags.trigger.cloneNode(true);
          modifiedElement.appendChild(postfix);
          modifiedElement.appendChild(trigger);
  
          const handleInteraction = () => {
            if (LMSEllipsis.isCollapsed(modifiedElement)) {
              modifiedElement.innerText = LMSEllipsis.buildStringFromArr(wholeSubstringArr);
              trigger.innerText = this.explanations.expanded;
              modifiedElement.appendChild(trigger);
            } else if (!LMSEllipsis.isCollapsed(modifiedElement)) {
              modifiedElement.innerText = LMSEllipsis.buildStringFromArr(shownSubstringsArr);
              modifiedElement.appendChild(postfix);
              trigger.innerText = this.explanations.collapsed;
              modifiedElement.appendChild(trigger);
            }
          };
  
          trigger.addEventListener('click', handleInteraction);
          trigger.addEventListener('keypress', (e) => { if (e.code === 'Enter' || e.code === 'Space') { handleInteraction(); } });
        };
  
        const [postfix, trigger] = this.init();
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
  