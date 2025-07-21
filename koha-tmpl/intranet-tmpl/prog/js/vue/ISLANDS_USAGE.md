# Koha Vue Islands Usage Guide

This document explains the standard usage pattern for Vue islands (custom elements) in the Koha codebase. It is not specific to any one feature or modal, but applies to all Vue islands registered and hydrated via the islands architecture.

## What is a Vue Island?
A Vue island is a web component (custom element) that encapsulates a Vue 3 Single File Component (SFC). Islands are registered in `componentRegistry` (see `koha-tmpl/intranet-tmpl/prog/js/vue/modules/islands.ts`) and hydrated only when present in the DOM. This enables progressive enhancement and on-demand loading of Vue-powered UI.

## How to Use a Vue Island

### 1. Add the Custom Element to Your HTML
```html
<my-vue-island></my-vue-island>
```
Replace `my-vue-island` with the tag name registered in the islands registry (e.g., `booking-modal-island`).

### 2. Control the Island via Props/Attributes
Islands are controlled by setting properties or attributes on the custom element. For example, to open a modal island:

```js
const island = document.querySelector('booking-modal-island');
island.open = true; // or: island.setAttribute('open', 'true');
```

To close the modal:
```js
island.open = false; // or: island.removeAttribute('open');
```

**Do not** call methods like `island.open()` unless the component explicitly documents such an API. Koha's islands are designed to be controlled via props/attributes, not methods.

### 3. Listen for Events (if applicable)
Some islands may emit custom DOM events for interactivity:
```js
island.addEventListener('some-event', (event) => {
  // handle event.detail
});
```
Refer to the island's documentation for supported events.

### 4. Data Flow
- Pass data into the island via attributes/properties.
- Receive data or actions via custom DOM events.

### 5. Example: Demo Button for Modal Island
```html
<button id="demo-modal-btn">Show Modal</button>
<booking-modal-island></booking-modal-island>
<script>
  document.getElementById('demo-modal-btn').addEventListener('click', function() {
    const island = document.querySelector('booking-modal-island');
    if (island) {
      island.open = true;
    }
  });
</script>
```

## Best Practices
- Always control islands via props/attributes, not direct method calls.
- Use events for communication from the island to the host page.
- Keep islands small and focused for best performance and maintainability.

## References
- `koha-tmpl/intranet-tmpl/prog/js/vue/modules/islands.ts` (island registration and hydration)
- Koha developer documentation
