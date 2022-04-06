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
        const string = element.innerText;
        const substrings = string.split(' ');
        const substringWidths = [];
  
        substrings.forEach((substring) => {
          ruler.style.width = 'auto';
          ruler.style.position = 'absolute';
          ruler.style.whiteSpace = 'nowrap';
          ruler.style.fontFamily = props.fontFamily;
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
  
      static trimSubstrings(substringWidthsArr, elementWidth) {
        let accumulator = 0;
        let indexOfLastSubstring = 0;
        const leftoverStringSpaces = 3;
        for (let idx = 0; idx < substringWidthsArr.length; idx += 1) {
          if (accumulator > elementWidth) {
            indexOfLastSubstring = idx - leftoverStringSpaces;
            break;
          }
          accumulator += substringWidthsArr[idx];
        }
        return indexOfLastSubstring;
      }
  
      truncate() {
        this.elements.forEach((element) => {
          const modifiedElement = element;
          const elementType = element.tagName;
          const placeholder = document.createElement(elementType);
  
          const {
            elementHeight, elementWidth, lineHeight, lineQuantity, fontFamily, fontSize,
          } = LMSEllipsis.calculateElementProperties(element);
  
          if (this.lines >= lineQuantity) return;
  
          const [substrings, substringWidths] = LMSEllipsis.generateSubstringArray(element, placeholder, {
            elementHeight, elementWidth, lineHeight, lineQuantity, fontFamily, fontSize,
          });
  
          let indexOfLastSubstring = 0;
          for (let idx = 0; idx < this.lines; idx += 1) {
            indexOfLastSubstring += LMSEllipsis.trimSubstrings(substringWidths, elementWidth);
          }
  
          const shownSubstringsArr = substrings.slice(0, indexOfLastSubstring);
          const wholeSubstringArr = substrings;
  
          modifiedElement.innerText = LMSEllipsis.buildStringFromArr(shownSubstringsArr);
  
          const postfix = document.createElement('span');
          postfix.classList.add('lmsellipsis-postfix');
          postfix.innerText = this.ellipsis;
          modifiedElement.appendChild(postfix);
  
          const trigger = document.createElement('nobr');
          trigger.classList.add('lmsellipsis-trigger');
          trigger.innerText = this.explanations.collapsed;
          trigger.style.cursor = 'pointer';
          trigger.style.color = '#0174AD';
          trigger.style.textDecoration = 'underline';
          modifiedElement.appendChild(trigger);
          // modifiedElement.insertAdjacentElement('afterend', trigger);
  
          trigger.addEventListener('click', () => {
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
          });
        });
      }
    }
  
    return LMSEllipsis;
  
  }));
  