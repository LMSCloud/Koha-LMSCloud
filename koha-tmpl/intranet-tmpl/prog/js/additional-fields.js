/**
 * AdditionalFields Module
 *
 * A reusable module for handling additional fields in Koha forms.
 * This module provides functionality for managing extended attributes
 * in a generic way that can be used across different Koha forms.
 *
 * @example
 * Expected HTML structure:
 * <fieldset class="brief" id="booking_extended_attributes">
 *   <div class="form-group">
 *     <label class="control-label">Field Name</label>
 *     <input type="text" class="extended-attribute form-control form-control-sm w-50" />
 *   </div>
 * </fieldset>
 *
 *
 * // Usage:
 * const additionalFields = AdditionalFields.init({
 *   containerId: 'booking_extended_attributes',
 *   resourceType: 'booking',
 *   onFieldsChanged: (values) => console.log('Fields changed:', values)
 * });
 *
 * // Fetch and render fields
 * additionalFields.fetchExtendedAttributes('booking')
 *   .then(types => additionalFields.renderExtendedAttributes(types, []));
 */

/**
 * @typedef {Object} AdditionalFieldsConfig
 * @property {string} containerId - ID of the container element
 * @property {string} resourceType - Type of resource (e.g., 'booking', 'patron')
 * @property {Function} onFieldsChanged - Callback for field changes
 * @property {Object} selectors - Custom selectors
 * @property {string} selectors.repeatableFieldClass - Class for repeatable fields
 * @property {string} selectors.inputClass - Class for input elements
 * @property {string} selectors.fieldPrefix - Prefix for field names
 */

/**
 * @typedef {Object} AuthorizedValue
 * @property {number} authorised_value_id - The ID of the authorized value
 * @property {string} category_name - The category name
 * @property {string} description - The description text
 * @property {string} image_url - The image URL, if any
 * @property {string|null} opac_description - The OPAC description, if any
 * @property {string} value - The value code
 */

/**
 * @typedef {Object} ExtendedAttributeType
 * @property {number} extended_attribute_type_id - The ID of the extended attribute type
 * @property {string} name - The name of the extended attribute type
 * @property {string|null} authorised_value_category_name - The category name for authorized values, if any
 * @property {boolean} repeatable - Whether the attribute is repeatable
 * @property {string} resource_type - The resource type this attribute belongs to
 * @property {string} marc_field - The MARC field associated with this attribute
 * @property {string} marc_field_mode - The MARC field mode (get/set)
 * @property {boolean} searchable - Whether the attribute is searchable
 */

/**
 * @typedef {Object} ExtendedAttribute
 * @property {number} field_id - The ID of the extended attribute
 * @property {string} id - The unique identifier
 * @property {string} record_id - The ID of the record this attribute belongs to
 * @property {string} value - The value of the extended attribute
 */

/**
 * @typedef {Object} ExtendedAttributeValue
 * @property {number} field_id - The ID of the extended attribute type
 * @property {string} value - The value of the extended attribute
 */

const AdditionalFields = (function () {
    // Constants for class names and selectors
    const CLASS_NAMES = {
        // Layout components
        CONTAINER: {
            FLEX: "d-flex",
            FLEX_ALIGN_CENTER: "align-items-center",
            MARGIN: {
                BOTTOM: "mb-2",
                START: "ms-2",
                START_AUTO: "ms-auto",
            },
            WIDTH: {
                HALF: "w-50",
            },
        },

        // Form components
        FORM: {
            GROUP: "form-group",
            LABEL: "control-label",
            INPUT: {
                BASE: "form-control",
                SELECT: "form-select",
                SMALL: "form-control-sm",
            },
        },

        // Extended attributes components
        EXTENDED_ATTRIBUTE: {
            BASE: "extended-attribute",
            REPEATABLE: {
                CONTAINER: "repeatable-field",
                ADD_BUTTON: "add-repeatable",
                REMOVE_BUTTON: "remove-repeatable",
            },
        },

        // State classes
        STATE: {
            HIDDEN: "d-none",
            VISUALLY_HIDDEN: "visually-hidden",
            FADE: "fade",
            SHOW: "show",
        },

        // Button components
        BUTTON: {
            BASE: "btn",
            SMALL: "btn-sm",
            LINK: "btn-link",
            PRIMARY: "text-primary",
        },

        // Icon components
        ICON: {
            BASE: "fa",
            ADD: "fa-plus",
            REMOVE: "fa-trash",
        },
    };

    const SELECTORS = {
        REPEATABLE_FIELD: `.${CLASS_NAMES.EXTENDED_ATTRIBUTE.REPEATABLE.CONTAINER}`,
        EXTENDED_ATTRIBUTE: `.${CLASS_NAMES.EXTENDED_ATTRIBUTE.BASE}`,
        FORM_GROUP: `li.${CLASS_NAMES.FORM.GROUP}`,
        INPUT: "input, select",
    };

    const NAMES = {
        EXTENDED_ATTRIBUTE: (fieldId, index) =>
            `extended_attributes.${fieldId}${index !== null ? `[${index}]` : ""}`,
    };

    const TEXTS = {
        EXTENDED_ATTRIBUTES: __("Additional Fields"),
        LOADING: __("Loading"),
        SELECT_AN_OPTION: __("Select an option"),
        ADD: __("New"),
        REMOVE: __("Remove"),
    };

    // Helper functions
    const Helpers = {
        /**
         * Get container element or return null if not found
         * @param {string} containerId - ID of the container element
         * @returns {HTMLElement|null} Container element or null if not found
         */
        getContainer: containerId => {
            return document.getElementById(containerId);
        },

        /**
         * Check if the given element is an input or select element
         * @param {Element} element - The element to check
         * @returns {element is HTMLInputElement|HTMLSelectElement} True if the element is an instance of HTMLInputElement or HTMLSelectElement, otherwise false.
         */
        isInputOrSelect(element) {
            return (
                element instanceof HTMLInputElement ||
                element instanceof HTMLSelectElement
            );
        },

        /**
         * Extracts the field ID from an input element's name attribute
         * @param {Element} input - The input element
         * @param {string} fieldPrefix - The prefix for field names
         * @returns {number} The extracted field ID
         */
        getFieldIdFromInputName(input, fieldPrefix) {
            if (!Helpers.isInputOrSelect(input)) {
                return 0;
            }

            const name = input.name.replace(`${fieldPrefix}.`, "");
            const fieldId = name.replace(/\[.*\]/, "");
            return parseInt(fieldId, 10) || 0;
        },

        /**
         * Create element with classes and optional attributes
         * @template {keyof HTMLElementTagNameMap} T
         * @param {T} tagName - HTML tag name
         * @param {string[]} classes - Array of class names
         * @param {Object.<string, string>} [attributes] - Optional attributes to set
         * @returns {HTMLElementTagNameMap[T]} Created element
         */
        createElement: (tagName, classes = [], attributes = {}) => {
            const element = document.createElement(tagName);
            if (classes.length) {
                element.className = classes.join(" ");
            }
            Object.entries(attributes).forEach(([key, value]) => {
                element.setAttribute(key, value);
            });
            return element;
        },

        /**
         * Create button with icon and text
         * @param {string} text - Button text
         * @param {string} iconClass - Icon class
         * @param {string[]} classes - Additional classes
         * @param {Object.<string, string>} [attributes] - Optional attributes
         * @returns {HTMLButtonElement} Button element
         */
        createButton: (text, iconClass, classes = [], attributes = {}) => {
            const button = Helpers.createElement(
                "button",
                [
                    CLASS_NAMES.BUTTON.BASE,
                    CLASS_NAMES.BUTTON.SMALL,
                    CLASS_NAMES.BUTTON.LINK,
                    ...classes,
                ],
                { type: "button", ...attributes }
            );

            const icon = Helpers.createElement("i", [
                CLASS_NAMES.ICON.BASE,
                iconClass,
            ]);
            button.appendChild(icon);

            const textNode = document.createTextNode(text);
            button.appendChild(textNode);

            return button;
        },

        /**
         * Group values by field_id
         * @param {Array<ExtendedAttributeValue>} values - Array of extended attribute values
         * @returns {Object.<number, string[]>} Grouped values
         * @todo use Object.groupBy once it is widely available
         */
        groupValues: values => {
            if (!values) {
                return {};
            }

            return values.reduce((acc, { field_id, value }) => {
                if (!acc[field_id]) {
                    acc[field_id] = [];
                }
                acc[field_id].push(value);
                return acc;
            }, {});
        },

        /**
         * Get unique categories from field types
         * @param {Array<ExtendedAttributeType>} types - Array of extended attribute types
         * @returns {string[]} Unique categories
         */
        getUniqueCategories: types => {
            return [
                ...new Set(
                    types
                        .map(type => type.authorised_value_category_name)
                        .filter(category => category !== null)
                ),
            ];
        },

        /**
         * Convert array of {category, values} to object
         * @param {Array<{category: string, values: AuthorizedValue[]}>} results - Array of results
         * @returns {Object.<string, AuthorizedValue[]>} Object of authorized values by category
         */
        convertToAuthorizedValues: results => {
            return results.reduce((acc, { category, values }) => {
                acc[category] = values;
                return acc;
            }, {});
        },

        /**
         * Handle adding a new repeatable field
         * @param {Event} event - The click event
         * @param {ExtendedAttributeType} type - The field type
         * @param {string|string[]|null} currentValues - Current values
         * @param {Object.<string, Array<AuthorizedValue>>} authorizedValues - Authorized values by category
         */
        handleAddRepeatable: (event, type, currentValues, authorizedValues) => {
            const button = /** @type {HTMLButtonElement} */ (
                event.currentTarget
            );
            const repeatableContainer = button.previousElementSibling;
            if (!repeatableContainer) {
                return;
            }

            const values =
                typeof currentValues === "string"
                    ? [currentValues]
                    : Array.isArray(currentValues)
                      ? currentValues
                      : [];
            const newInput = createInput(
                type,
                "",
                values.length,
                authorizedValues
            );
            if (newInput && repeatableContainer) {
                repeatableContainer.appendChild(newInput);
            }
            if (typeof config.onFieldsChanged === "function") {
                config.onFieldsChanged(getValues());
            }
        },

        /**
         * Handle removing a repeatable field
         * @param {Event} event - The click event
         */
        handleRemoveRepeatable: event => {
            const button = /** @type {HTMLButtonElement} */ (
                event.currentTarget
            );
            const wrapper = button.parentElement;
            if (wrapper) {
                wrapper.remove();
                if (typeof config.onFieldsChanged === "function") {
                    config.onFieldsChanged(getValues());
                }
            }
        },
    };

    /** @type {AdditionalFieldsConfig} */
    let config = {
        containerId: "",
        resourceType: "",
        onFieldsChanged: () => {},
        selectors: {
            repeatableFieldClass:
                CLASS_NAMES.EXTENDED_ATTRIBUTE.REPEATABLE.CONTAINER,
            inputClass: CLASS_NAMES.EXTENDED_ATTRIBUTE.BASE,
            fieldPrefix: "extended_attributes",
        },
    };

    /**
     * Initialize the module with configuration options
     * @param {Object} options - Configuration options
     * @param {string} options.containerId - ID of the container element
     * @param {string} options.resourceType - Type of resource (e.g., 'booking', 'patron')
     * @param {Function} options.onFieldsChanged - Callback for field changes
     * @param {Object} options.selectors - Custom selectors
     * @param {string} options.selectors.repeatableFieldClass - Class for repeatable fields
     * @param {string} options.selectors.inputClass - Class for input elements
     * @param {string} options.selectors.fieldPrefix - Prefix for field names
     */
    function init(options) {
        config = {
            ...config,
            ...options,
            selectors: {
                ...config.selectors,
                ...(options.selectors || {}),
            },
        };

        return {
            init,
            getValues,
            setValues,
            clear,
            renderExtendedAttributes,
            fetchExtendedAttributes,
            fetchAndProcessExtendedAttributes,
            fetchAndProcessAuthorizedValues,
            renderExtendedAttributesValues,
        };
    }

    /**
     * Get all field values from the form
     * @returns {ExtendedAttributeValue[]} Array of extended attribute values
     */
    function getValues() {
        const container = Helpers.getContainer(config.containerId);
        if (!container) {
            return [];
        }

        const values = [];
        const inputs = container.querySelectorAll(SELECTORS.INPUT);

        inputs.forEach(input => {
            if (!Helpers.isInputOrSelect(input)) {
                return;
            }

            const fieldId = Helpers.getFieldIdFromInputName(
                input,
                config.selectors.fieldPrefix
            );

            values.push({
                field_id: fieldId,
                value: input.value,
            });
        });

        return values;
    }

    /**
     * Set values for all extended attribute fields
     * @param {Array<ExtendedAttributeValue>} values - Array of extended attribute values
     * @param {Object.<string, Array<AuthorizedValue>>} [authorizedValues] - Optional authorized values by category
     */
    function setValues(values, authorizedValues = {}) {
        const container = Helpers.getContainer(config.containerId);
        if (!container) {
            return;
        }

        // Get all field types from the container
        const fieldTypes = Array.from(
            container?.querySelectorAll(SELECTORS.FORM_GROUP) ?? []
        )
            .map(li => {
                /** @type {HTMLInputElement|HTMLSelectElement|null} */
                const input = li.querySelector(SELECTORS.INPUT);
                if (!input) return null;

                const fieldId = Helpers.getFieldIdFromInputName(
                    input,
                    config.selectors.fieldPrefix
                );

                return {
                    extended_attribute_type_id: fieldId,
                    name: li.querySelector("label")?.textContent || "",
                    authorised_value_category_name:
                        input.tagName === "SELECT"
                            ? (input.dataset.category ?? null)
                            : null,
                    repeatable:
                        li.querySelector(SELECTORS.REPEATABLE_FIELD) !== null,
                    resource_type: config.resourceType,
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                };
            })
            .filter(type => type !== null);

        // Group values by field_id
        const groupedValues = Helpers.groupValues(values);

        // Get existing fields
        const existingFields = new Map(
            Array.from(
                container?.querySelectorAll(SELECTORS.FORM_GROUP) || []
            ).map(field => {
                const input = field.querySelector("input, select");
                if (!input) {
                    return [, field];
                }

                const fieldId = Helpers.getFieldIdFromInputName(
                    input,
                    config.selectors.fieldPrefix
                );

                return [Number(fieldId), field];
            })
        );

        // Check if we need to fetch authorized values
        const hasSelectFields = fieldTypes.some(
            type => type.authorised_value_category_name
        );

        const needsAuthorizedValues =
            hasSelectFields && Object.keys(authorizedValues).length === 0;
        if (!needsAuthorizedValues) {
            // Track which fields we've processed
            const processedFields = new Set();

            // Update or create fields
            fieldTypes.forEach(type => {
                const fieldId = type.extended_attribute_type_id;
                processedFields.add(fieldId);

                const fieldValues =
                    groupedValues[type.extended_attribute_type_id] || [];
                const currentValues = type.repeatable
                    ? fieldValues
                    : [fieldValues[0] || ""];

                const existingField = existingFields.get(fieldId);
                if (!existingField) {
                    // Create new field
                    const field = createField(
                        type,
                        currentValues,
                        authorizedValues
                    );
                    if (field && container) container.appendChild(field);
                    return;
                }

                // Update existing field
                updateExistingField(
                    existingField,
                    type,
                    currentValues,
                    authorizedValues
                );
            });

            // Remove fields that no longer exist
            existingFields.forEach((field, fieldId) => {
                if (!processedFields.has(fieldId)) {
                    field.remove();
                }
            });
            return;
        }

        // Get unique categories
        const categories = Helpers.getUniqueCategories(fieldTypes);

        // Fetch authorized values for each category
        Promise.all(
            categories.map(category =>
                fetchAuthorizedValues(category).then(values => ({
                    category,
                    values,
                }))
            )
        )
            .then(results => {
                // Convert array of {category, values} to object
                const fetchedValues =
                    Helpers.convertToAuthorizedValues(results);

                // Re-render with fetched values
                renderExtendedAttributes(fieldTypes, values, fetchedValues);
            })
            .catch(error => {
                console.error("Error fetching authorized values:", error);
            });
    }

    /**
     * Clear all field values
     */
    function clear() {
        const container = Helpers.getContainer(config.containerId);
        if (!container) {
            return;
        }

        const inputs = container.querySelectorAll(SELECTORS.INPUT);
        inputs.forEach(input => {
            if (!Helpers.isInputOrSelect(input)) {
                return;
            }

            input.value = "";
        });
    }

    /**
     * Update a single input field
     * @param {Element} field - The field element
     * @param {string} value - The new value
     */
    function updateSingleField(field, value) {
        const input = field.querySelector("input, select");
        if (!input || !Helpers.isInputOrSelect(input)) {
            return;
        }

        input.value = value || "";
    }

    /**
     * Update a repeatable field
     * @param {Element} field - The field element
     * @param {ExtendedAttributeType} type - The field type
     * @param {string[]} values - The new values
     * @param {Object.<string, Array<AuthorizedValue>>} authorizedValues - Authorized values by category
     */
    function updateRepeatableField(field, type, values, authorizedValues) {
        const repeatableContainer = field.querySelector(
            SELECTORS.REPEATABLE_FIELD
        );
        if (!repeatableContainer) {
            return;
        }

        const existingInputs = Array.from(
            repeatableContainer.querySelectorAll("input, select")
        );

        // Update or add inputs
        values.forEach((value, index) => {
            const input = existingInputs[index];
            if (!Helpers.isInputOrSelect(input)) {
                const newInput = createInput(
                    type,
                    value,
                    index,
                    authorizedValues
                );
                if (newInput) repeatableContainer.appendChild(newInput);
                return;
            }

            input.value = value;
        });

        // Remove excess inputs
        while (existingInputs.length > values.length) {
            existingInputs.pop()?.parentElement?.remove();
        }
    }

    /**
     * Update an existing field
     * @param {Element} field - The field element
     * @param {ExtendedAttributeType} type - The field type
     * @param {string[]} values - The new values
     * @param {Object.<string, Array<AuthorizedValue>>} authorizedValues - Authorized values by category
     */
    function updateExistingField(field, type, values, authorizedValues) {
        if (!type.repeatable) {
            updateSingleField(field, values[0]);
            return;
        }

        updateRepeatableField(field, type, values, authorizedValues);
    }

    /**
     * Render extended attributes in the form
     * @param {Array<ExtendedAttributeType>} types - Extended attribute types
     * @param {Array<ExtendedAttributeValue>} values - Current values
     * @param {Object.<string, Array<AuthorizedValue>>} [authorizedValues] - Optional authorized values by category
     */
    function renderExtendedAttributes(types, values, authorizedValues = {}) {
        const container = Helpers.getContainer(config.containerId);
        if (!container) {
            return;
        }

        if (!types || types.length === 0) {
            container.innerHTML = "";
            return;
        }

        // Group values by field_id to handle repeatable fields
        const groupedValues = Helpers.groupValues(values);

        // Get existing fields
        const existingFields = new Map(
            Array.from(
                container?.querySelectorAll(SELECTORS.FORM_GROUP) || []
            ).map(field => {
                const input = field.querySelector("input, select");
                if (!input) {
                    return [, field];
                }

                const fieldId = Helpers.isInputOrSelect(input)
                    ? input.name.split(".")[1]?.split("[")[0]
                    : undefined;
                return [fieldId, field];
            })
        );

        // Check if we need to fetch authorized values
        const hasSelectFields = types.some(
            type => type.authorised_value_category_name
        );

        const needsAuthorizedValues =
            hasSelectFields && Object.keys(authorizedValues).length === 0;
        if (!needsAuthorizedValues) {
            // Track which fields we've processed
            const processedFields = new Set();

            // Update or create fields
            types.forEach(type => {
                const fieldId = type.extended_attribute_type_id.toString();
                processedFields.add(fieldId);

                const fieldValues =
                    groupedValues[type.extended_attribute_type_id] || [];
                const currentValues = type.repeatable
                    ? fieldValues
                    : [fieldValues[0] || ""];

                const existingField = existingFields.get(fieldId);
                if (!existingField) {
                    // Create new field
                    const field = createField(
                        type,
                        currentValues,
                        authorizedValues
                    );
                    if (field && container) container.appendChild(field);
                    return;
                }

                // Update existing field
                updateExistingField(
                    existingField,
                    type,
                    currentValues,
                    authorizedValues
                );
            });

            // Remove fields that no longer exist
            existingFields.forEach((field, fieldId) => {
                if (!processedFields.has(fieldId)) {
                    field.remove();
                }
            });
            return;
        }

        // Get unique categories
        const categories = Helpers.getUniqueCategories(types);

        // Fetch authorized values for each category
        Promise.all(
            categories.map(category =>
                fetchAuthorizedValues(category).then(values => ({
                    category,
                    values,
                }))
            )
        )
            .then(results => {
                // Convert array of {category, values} to object
                const fetchedValues =
                    Helpers.convertToAuthorizedValues(results);

                // Re-render with fetched values
                renderExtendedAttributes(types, values, fetchedValues);
            })
            .catch(error => {
                console.error("Error fetching authorized values:", error);
            });
    }

    /**
     * Create a field element for an extended attribute type
     * @param {ExtendedAttributeType} type - Extended attribute type
     * @param {string|string[]|null} values - Current value
     * @param {Object.<string, Array<AuthorizedValue>>} [authorizedValues] - Optional authorized values by category
     * @returns {HTMLElement} Field element
     */
    function createField(type, values, authorizedValues = {}) {
        const field = Helpers.createElement("li", [
            CLASS_NAMES.FORM.GROUP,
        ]);

        const label = Helpers.createElement("label", [CLASS_NAMES.FORM.LABEL]);
        label.setAttribute(
            "for",
            `extended_attribute_${type.extended_attribute_type_id}`
        );
        label.textContent = type.name + ":";
        field.appendChild(label);

        if (type.repeatable) {
            const repeatableContainer = Helpers.createElement("div", [
                config.selectors.repeatableFieldClass,
            ]);

            // Always create at least one input field for repeatable fields
            values = Array.isArray(values) && values.length > 0 ? values : [""];
            values.forEach((value, index) => {
                const input = createInput(type, value, index, authorizedValues);
                if (input) {
                    repeatableContainer.appendChild(input);
                }
            });
            field.appendChild(repeatableContainer);

            const addButton = Helpers.createButton(
                TEXTS.ADD,
                CLASS_NAMES.ICON.ADD,
                [CLASS_NAMES.EXTENDED_ATTRIBUTE.REPEATABLE.ADD_BUTTON],
                {
                    "data-attribute-id": `extended_attribute_${type.extended_attribute_type_id}`,
                }
            );

            addButton.addEventListener("click", event => {
                Helpers.handleAddRepeatable(
                    event,
                    type,
                    values,
                    authorizedValues
                );
            });

            field.appendChild(addButton);
        } else {
            const input = createInput(
                type,
                values?.[0] || "",
                0,
                authorizedValues
            );
            if (input) {
                field.appendChild(input);
            }
        }

        return field;
    }

    /**
     * Create an input element for an extended attribute type
     * @param {ExtendedAttributeType} type - Extended attribute type
     * @param {string} value - Current value
     * @param {number} index - Index for repeatable fields
     * @param {Object.<string, Array<AuthorizedValue>>} [authorizedValues] - Optional authorized values by category
     * @returns {HTMLElement} Input element
     */
    function createInput(type, value, index = 0, authorizedValues = {}) {
        const wrapper = Helpers.createElement("div", [
            CLASS_NAMES.CONTAINER.FLEX,
            CLASS_NAMES.CONTAINER.FLEX_ALIGN_CENTER,
            CLASS_NAMES.CONTAINER.MARGIN.BOTTOM,
        ]);

        let input;
        if (type.authorised_value_category_name) {
            input = Helpers.createElement("select", [
                config.selectors.inputClass,
                CLASS_NAMES.FORM.INPUT.SELECT,
                CLASS_NAMES.CONTAINER.WIDTH.HALF,
            ]);
            input.id = `extended_attribute_${type.extended_attribute_type_id}${type.repeatable ? `_${index}` : ""}`;
            input.name = NAMES.EXTENDED_ATTRIBUTE(
                type.extended_attribute_type_id,
                type.repeatable ? index : null
            );
            input.dataset.category = type.authorised_value_category_name;

            // Add default option
            const defaultOption = Helpers.createElement("option");
            defaultOption.value = "";
            defaultOption.textContent = TEXTS.SELECT_AN_OPTION;
            input.appendChild(defaultOption);

            // Add authorized values from the correct category
            const categoryValues =
                authorizedValues[type.authorised_value_category_name] || [];
            if (categoryValues.length > 0) {
                categoryValues.forEach(val => {
                    const option = Helpers.createElement("option");
                    option.value = val.value;
                    option.textContent = val.description;
                    input.appendChild(option);
                });
            }

            // Set the value after all options are added
            if (value) {
                input.value = value;
            }
        } else {
            input = Helpers.createElement("input", [
                config.selectors.inputClass,
                CLASS_NAMES.FORM.INPUT.BASE,
                CLASS_NAMES.CONTAINER.WIDTH.HALF,
            ]);
            input.type = "text";
            input.id = `extended_attribute_${type.extended_attribute_type_id}${type.repeatable ? `_${index}` : ""}`;
            input.name = NAMES.EXTENDED_ATTRIBUTE(
                type.extended_attribute_type_id,
                type.repeatable ? index : null
            );
            input.value = value || "";
        }

        // Add change event listener to notify of field changes
        input.addEventListener("change", () => {
            if (typeof config.onFieldsChanged === "function") {
                config.onFieldsChanged(getValues());
            }
        });

        wrapper.appendChild(input);

        if (type.repeatable) {
            const removeButton = Helpers.createButton(
                TEXTS.REMOVE,
                CLASS_NAMES.ICON.REMOVE,
                [
                    CLASS_NAMES.EXTENDED_ATTRIBUTE.REPEATABLE.REMOVE_BUTTON,
                    CLASS_NAMES.CONTAINER.MARGIN.START,
                ],
                {
                    "data-attribute-id": `extended_attribute_${type.extended_attribute_type_id}`,
                }
            );
            removeButton.addEventListener(
                "click",
                Helpers.handleRemoveRepeatable
            );
            wrapper.appendChild(removeButton);
        }

        return wrapper;
    }

    /**
     * Fetch authorized values for a category
     * @param {string} category - The category to fetch values for
     * @returns {Promise<AuthorizedValue[]>} - The authorized values
     */
    async function fetchAuthorizedValues(category) {
        try {
            const response = await fetch(
                `/api/v1/authorised_value_categories/${category}/authorised_values`,
            );
            if (!response.ok) {
                return [];
            }

            const result = await response.json();

            return result;
        } catch (error) {
            console.error(
                `Error fetching authorized values for category ${category}:`,
                error
            );
            return [];
        }
    }

    /**
     * Fetch extended attribute types for a resource type
     * @param {string} resourceType - Type of resource
     * @returns {Promise<ExtendedAttributeType[]>} - The extended attribute types
     */
    async function fetchExtendedAttributes(resourceType) {
        try {
            const response = await fetch(
                `/api/v1/extended_attribute_types?resource_type=${resourceType}`,
            );
            if (!response.ok) {
                return [];
            }

            const result = await response.json();

            return result;
        } catch (error) {
            console.error(
                `Error fetching extended attributes for resource type ${resourceType}:`,
                error
            );
            return [];
        }
    }

    /**
     * Fetch and process extended attribute types
     * @param {string} resourceType - Type of resource (e.g., 'booking')
     * @returns {Promise<Object.<string, Pick<ExtendedAttributeType, "authorised_value_category_name" | "name">>>} Processed extended attribute types
     */
    async function fetchAndProcessExtendedAttributes(resourceType) {
        try {
            const response = await fetch(
                `/api/v1/extended_attribute_types?resource_type=${resourceType}`,
            );
            if (!response.ok) {
                return {};
            }

            const result = await response.json();

            return result.reduce(
                (
                    acc,
                    {
                        extended_attribute_type_id,
                        authorised_value_category_name,
                        name,
                    }
                ) => {
                    acc[extended_attribute_type_id] = {
                        authorised_value_category_name,
                        name,
                    };
                    return acc;
                },
                {}
            );
        } catch (error) {
            console.error(
                `Error fetching extended attributes for resource type ${resourceType}:`,
                error
            );
            return {};
        }
    }

    /**
     * Fetch and process authorized values for categories
     * @param {string[]} categories - Array of category names
     * @returns {Promise<Object.<string, Pick<AuthorizedValue, "description">>>} Processed authorized values
     */
    async function fetchAndProcessAuthorizedValues(categories) {
        try {
            const response = await fetch(
                `/api/v1/authorised_value_categories?q={"me.category_name":[${JSON.stringify(categories.join(","))}]}`,
                {
                    headers: {
                        "x-koha-embed": "authorised_values",
                    },
                },
            );
            if (!response.ok) {
                return {};
            }

            const result = await response.json();

            return result.reduce((acc, item) => {
                const { category_name, authorised_values } = item;
                acc[category_name] = acc[category_name] || {};
                authorised_values.forEach(({ value, description }) => {
                    acc[category_name][value] = description;
                });
                return acc;
            }, {});
        } catch (error) {
            console.error("Error fetching authorized values:", error);
            return {};
        }
    }

    /**
     * Render extended attributes values with their names and authorized values
     * @param {Array<ExtendedAttribute>} attributes - Array of extended attributes
     * @param {Object.<string, Pick<ExtendedAttributeType, "name" | "authorised_value_category_name">>} types - Extended attribute types
     * @param {Object.<string, Object.<string, string>>} authorizedValues - Authorized values by category
     * @param {string} recordId - The record ID to filter attributes by
     * @returns {string[]} Array of strings of rendered attributes
     */
    function renderExtendedAttributesValues(
        attributes,
        types = {},
        authorizedValues = {},
        recordId
    ) {
        if (!attributes || attributes.length === 0) return [""];
        return attributes
            .filter(attribute => attribute.record_id == recordId)
            .map(attribute => {
                const fieldId = attribute.field_id;
                const typeInfo = types[fieldId] || {};
                const name = typeInfo.name || fieldId;
                const categoryName =
                    typeInfo.authorised_value_category_name || "";
                const valueDescription =
                    authorizedValues[categoryName]?.[attribute.value] ||
                    attribute.value;

                return [name, valueDescription].join(": ");
            });
    }

    return {
        init,
        getValues,
        setValues,
        clear,
        renderExtendedAttributes,
        fetchExtendedAttributes,
        fetchAndProcessExtendedAttributes,
        fetchAndProcessAuthorizedValues,
        renderExtendedAttributesValues,
    };
})();

window["AdditionalFields"] = AdditionalFields;
