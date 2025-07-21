import mocha from "mocha";
import * as chai from "chai";
import sinonChai from "chai-sinon";
import jsdom from "jsdom";
import rewire from "rewire";
import sinon from "sinon";
const { JSDOM } = jsdom;
const { expect } = chai;
const { describe, it, beforeEach, afterEach } = mocha;

chai.use(sinonChai);

// Create a complete HTML document with our container
const dom = new JSDOM(`
    <!DOCTYPE html>
    <html>
        <body>
            <div id="extended_attributes"></div>
        </body>
    </html>
`);

const { window } = dom;
const { document } = window;

// Set up global variables
global.document = document;
global.window = window;
global.HTMLOListElement = window.HTMLOListElement;
global.HTMLInputElement = window.HTMLInputElement;
global.HTMLSelectElement = window.HTMLSelectElement;

// Add translation function
global.__ = str => str;

// Set up mock APIClient
global.window.APIClient = {
    additional_fields: {
        additional_fields: {
            getAll: resourceType => {
                if (!resourceType)
                    return Promise.reject(new Error("Resource type required"));
                return Promise.resolve([
                    {
                        extended_attribute_type_id: 1,
                        name: "Urgency",
                        authorised_value_category_name: "BOOKINGS_URGENCY",
                        repeatable: false,
                        resource_type: "booking",
                        marc_field: "",
                        marc_field_mode: "get",
                        searchable: false,
                    },
                    {
                        extended_attribute_type_id: 2,
                        name: "Note",
                        authorised_value_category_name: null,
                        repeatable: false,
                        resource_type: "booking",
                        marc_field: "",
                        marc_field_mode: "get",
                        searchable: false,
                    },
                ]);
            },
        },
    },
    authorised_values: {
        values: {
            getCategoriesWithValues: categories => {
                if (!categories || categories.length === 0) {
                    return Promise.resolve([]);
                }
                const categoryNames = JSON.parse(categories[0]);
                if (!categoryNames.length) {
                    return Promise.resolve([]);
                }
                return Promise.resolve(
                    categoryNames.map(category => ({
                        category_name: category,
                        authorised_values:
                            category === "BOOKINGS_URGENCY"
                                ? [
                                      { value: "HIGH", description: "High" },
                                      {
                                          value: "MEDIUM",
                                          description: "Medium",
                                      },
                                      { value: "LOW", description: "Low" },
                                  ]
                                : [
                                      { value: "1", description: "Yes" },
                                      { value: "0", description: "No" },
                                  ],
                    }))
                );
            },
        },
    },
};

// Mock console.error to silence error output
const originalConsoleError = console.error;
console.error = () => {};

// Restore console.error after tests
after(() => {
    console.error = originalConsoleError;
});

// Rewire the additional-fields.js file
const additionalFieldsModule = rewire(
    "./koha-tmpl/intranet-tmpl/prog/js/additional-fields.js"
);

// Get the result of the IIFE
const AdditionalFields = additionalFieldsModule.__get__("AdditionalFields");

describe("AdditionalFields", () => {
    let additionalFields;
    let container;
    let getAllStub;
    let getCategoriesWithValuesStub;

    beforeEach(() => {
        // Get the container
        container = document.getElementById("extended_attributes");
        if (!container) {
            throw new Error("Container not found");
        }
        container.innerHTML = "";

        // Set up mock APIClient
        window.APIClient = {
            additional_fields: {
                additional_fields: {
                    getAll: sinon.stub().resolves([
                        {
                            extended_attribute_type_id: 1,
                            name: "Urgency",
                            authorised_value_category_name: "BOOKINGS_URGENCY",
                            repeatable: false,
                            resource_type: "booking",
                            marc_field: "",
                            marc_field_mode: "get",
                            searchable: false,
                        },
                        {
                            extended_attribute_type_id: 2,
                            name: "Note",
                            authorised_value_category_name: null,
                            repeatable: false,
                            resource_type: "booking",
                            marc_field: "",
                            marc_field_mode: "get",
                            searchable: false,
                        },
                        {
                            extended_attribute_type_id: 3,
                            name: "Contact",
                            authorised_value_category_name: null,
                            repeatable: false,
                            resource_type: "booking",
                            marc_field: "",
                            marc_field_mode: "get",
                            searchable: false,
                        },
                        {
                            extended_attribute_type_id: 4,
                            name: "Test",
                            authorised_value_category_name: "YES_NO",
                            repeatable: true,
                            resource_type: "booking",
                            marc_field: "",
                            marc_field_mode: "get",
                            searchable: false,
                        },
                    ]),
                },
            },
            authorised_values: {
                values: {
                    getCategoriesWithValues: sinon.stub().resolves([
                        {
                            category_name: "BOOKINGS_URGENCY",
                            authorised_values: [
                                { value: "HIGH", description: "High" },
                                { value: "MEDIUM", description: "Medium" },
                                { value: "LOW", description: "Low" },
                            ],
                        },
                        {
                            category_name: "YES_NO",
                            authorised_values: [
                                { value: "1", description: "Yes" },
                                { value: "0", description: "No" },
                            ],
                        },
                    ]),
                },
            },
        };

        getAllStub =
            window.APIClient.additional_fields.additional_fields.getAll;
        getCategoriesWithValuesStub =
            window.APIClient.authorised_values.values.getCategoriesWithValues;

        // Rewire the additional-fields.js file
        const additionalFieldsModule = rewire(
            "./koha-tmpl/intranet-tmpl/prog/js/additional-fields.js"
        );

        // Get the result of the IIFE
        const AdditionalFields =
            additionalFieldsModule.__get__("AdditionalFields");

        additionalFields = AdditionalFields.init({
            containerId: "extended_attributes",
            resourceType: "booking",
            onFieldsChanged: () => {},
        });
    });

    afterEach(() => {
        // Restore container if it was removed
        if (!document.getElementById("extended_attributes")) {
            const container = document.createElement("div");
            container.id = "extended_attributes";
            document.body.appendChild(container);
        }
        // Reset stubs
        getAllStub.reset();
        getCategoriesWithValuesStub.reset();
    });

    describe("renderExtendedAttributes", () => {
        it("should render fields with provided authorized values", async () => {
            const types = [
                {
                    extended_attribute_type_id: 1,
                    name: "Test Attribute",
                    authorised_value_category_name: "test_category",
                    repeatable: false,
                    resource_type: "test-resource",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
            ];

            const values = [{ field_id: 1, value: "value1" }];

            const authorizedValues = {
                test_category: [
                    { value: "value1", description: "Value 1" },
                    { value: "value2", description: "Value 2" },
                ],
            };

            await additionalFields.renderExtendedAttributes(
                types,
                values,
                authorizedValues
            );

            const select = container.querySelector("select");
            expect(select).to.exist;
            expect(select.value).to.equal("value1");
            expect(select.options.length).to.equal(3); // Default option + 2 values
        });

        it("should handle repeatable fields", async () => {
            const types = [
                {
                    extended_attribute_type_id: 1,
                    name: "Test Field",
                    authorised_value_category_name: null,
                    repeatable: true,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
            ];

            const values = [{ field_id: 1, value: "value1" }];

            await additionalFields.renderExtendedAttributes(types, values, {});

            const input = container.querySelector("input");
            expect(input).to.exist;
            expect(input.value).to.equal("value1");

            const addButton = container.querySelector(".add-repeatable");
            expect(addButton).to.exist;

            // Test adding a new field
            addButton.click();
            const inputs = container.querySelectorAll("input");
            expect(inputs).to.have.lengthOf(2);
            expect(inputs[1].value).to.equal("");

            // Test removing a field
            const removeButton = inputs[1]
                .closest(".d-flex")
                .querySelector(".remove-repeatable");
            removeButton.click();
            expect(container.querySelectorAll("input")).to.have.lengthOf(1);
        });

        it("should handle empty types array", async () => {
            await additionalFields.renderExtendedAttributes([], [], {});
            expect(container.innerHTML).to.equal("");
        });

        it("should handle null values", async () => {
            const types = [
                {
                    extended_attribute_type_id: 1,
                    name: "Test Field",
                    authorised_value_category_name: null,
                    repeatable: false,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
            ];

            await additionalFields.renderExtendedAttributes(types, null, {});
            const input = container.querySelector("input");
            expect(input).to.exist;
            expect(input.value).to.equal("");
        });

        it("should handle multiple field types", async () => {
            const types = [
                {
                    extended_attribute_type_id: 1,
                    name: "Text Field",
                    authorised_value_category_name: null,
                    repeatable: false,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
                {
                    extended_attribute_type_id: 2,
                    name: "Select Field",
                    authorised_value_category_name: "test_category",
                    repeatable: false,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
                {
                    extended_attribute_type_id: 3,
                    name: "Repeatable Field",
                    authorised_value_category_name: null,
                    repeatable: true,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
            ];

            const authorizedValues = {
                test_category: [
                    { value: "option1", description: "Option 1" },
                    { value: "option2", description: "Option 2" },
                ],
            };

            await additionalFields.renderExtendedAttributes(
                types,
                [],
                authorizedValues
            );

            const textInput = container.querySelector(
                "input[name='extended_attributes.1']"
            );
            expect(textInput).to.exist;

            const select = container.querySelector(
                "select[name='extended_attributes.2']"
            );
            expect(select).to.exist;

            const repeatableInput = container.querySelector(
                "input[name='extended_attributes.3[0]']"
            );
            expect(repeatableInput).to.exist;
        });
    });

    describe("setValues", () => {
        it("should set values for all field types", async () => {
            const types = [
                {
                    extended_attribute_type_id: 1,
                    name: "Text Field",
                    authorised_value_category_name: null,
                    repeatable: false,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
                {
                    extended_attribute_type_id: 2,
                    name: "Select Field",
                    authorised_value_category_name: "test_category",
                    repeatable: false,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
                {
                    extended_attribute_type_id: 3,
                    name: "Repeatable Field",
                    authorised_value_category_name: null,
                    repeatable: true,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
            ];

            const values = [
                { field_id: 1, value: "text value" },
                { field_id: 2, value: "option1" },
                { field_id: 3, value: "repeat1" },
                { field_id: 3, value: "repeat2" },
            ];

            const authorizedValues = {
                test_category: [
                    { value: "option1", description: "Option 1" },
                    { value: "option2", description: "Option 2" },
                ],
            };

            await additionalFields.renderExtendedAttributes(
                types,
                [],
                authorizedValues
            );
            await additionalFields.setValues(values, authorizedValues);

            const textInput = container.querySelector(
                "input[name='extended_attributes.1']"
            );
            expect(textInput.value).to.equal("text value");

            const select = container.querySelector(
                "select[name='extended_attributes.2']"
            );
            expect(select.value).to.equal("option1");

            const repeatableInputs = container.querySelectorAll(
                "input[name^='extended_attributes.3']"
            );
            expect(repeatableInputs).to.have.lengthOf(2);
            expect(repeatableInputs[0].value).to.equal("repeat1");
            expect(repeatableInputs[1].value).to.equal("repeat2");
        });

        it("should handle empty values array", async () => {
            const types = [
                {
                    extended_attribute_type_id: 1,
                    name: "Test Field",
                    authorised_value_category_name: null,
                    repeatable: false,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
            ];

            await additionalFields.renderExtendedAttributes(types, [], {});
            await additionalFields.setValues([], {});

            const input = container.querySelector("input");
            expect(input.value).to.equal("");
        });

        it("should handle null values", async () => {
            const types = [
                {
                    extended_attribute_type_id: 1,
                    name: "Test Field",
                    authorised_value_category_name: null,
                    repeatable: false,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
            ];

            await additionalFields.renderExtendedAttributes(types, [], {});
            await additionalFields.setValues(null, {});

            const input = container.querySelector("input");
            expect(input.value).to.equal("");
        });

        it("should handle partial values", async () => {
            const types = [
                {
                    extended_attribute_type_id: 1,
                    name: "Field 1",
                    authorised_value_category_name: null,
                    repeatable: false,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
                {
                    extended_attribute_type_id: 2,
                    name: "Field 2",
                    authorised_value_category_name: null,
                    repeatable: false,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
            ];

            await additionalFields.renderExtendedAttributes(types, [], {});
            await additionalFields.setValues(
                [{ field_id: 1, value: "value1" }],
                {}
            );

            const input1 = container.querySelector(
                "input[name='extended_attributes.1']"
            );
            expect(input1.value).to.equal("value1");

            const input2 = container.querySelector(
                "input[name='extended_attributes.2']"
            );
            expect(input2.value).to.equal("");
        });
    });

    describe("getValues", () => {
        it("should return values from all field types", async () => {
            const types = [
                {
                    extended_attribute_type_id: 1,
                    name: "Text Field",
                    authorised_value_category_name: null,
                    repeatable: false,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
                {
                    extended_attribute_type_id: 2,
                    name: "Select Field",
                    authorised_value_category_name: "test_category",
                    repeatable: false,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
                {
                    extended_attribute_type_id: 3,
                    name: "Repeatable Field",
                    authorised_value_category_name: null,
                    repeatable: true,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
            ];

            const values = [
                { field_id: 1, value: "text value" },
                { field_id: 2, value: "option1" },
                { field_id: 3, value: "repeat1" },
                { field_id: 3, value: "repeat2" },
            ];

            const authorizedValues = {
                test_category: [
                    { value: "option1", description: "Option 1" },
                    { value: "option2", description: "Option 2" },
                ],
            };

            await additionalFields.renderExtendedAttributes(
                types,
                [],
                authorizedValues
            );
            await additionalFields.setValues(values, authorizedValues);

            const result = additionalFields.getValues();
            expect(result).to.deep.equal(values);
        });

        it("should return empty array when container is not found", () => {
            container.remove();
            const result = additionalFields.getValues();
            expect(result).to.deep.equal([]);
        });

        it("should return empty array when no fields are present", async () => {
            await additionalFields.renderExtendedAttributes([], [], {});
            const result = additionalFields.getValues();
            expect(result).to.deep.equal([]);
        });

        it("should handle partially filled fields", async () => {
            const types = [
                {
                    extended_attribute_type_id: 1,
                    name: "Field 1",
                    authorised_value_category_name: null,
                    repeatable: false,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
                {
                    extended_attribute_type_id: 2,
                    name: "Field 2",
                    authorised_value_category_name: null,
                    repeatable: false,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
            ];

            await additionalFields.renderExtendedAttributes(types, [], {});
            const input1 = container.querySelector(
                "input[name='extended_attributes.1']"
            );
            input1.value = "value1";

            const result = additionalFields.getValues();
            expect(result).to.deep.equal([
                { field_id: 1, value: "value1" },
                { field_id: 2, value: "" },
            ]);
        });
    });

    describe("clear", () => {
        it("should clear all extended attribute values", async () => {
            const types = [
                {
                    extended_attribute_type_id: 1,
                    name: "Text Field",
                    authorised_value_category_name: null,
                    repeatable: false,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
                {
                    extended_attribute_type_id: 2,
                    name: "Select Field",
                    authorised_value_category_name: "test_category",
                    repeatable: false,
                    resource_type: "test",
                    marc_field: "",
                    marc_field_mode: "",
                    searchable: false,
                },
            ];

            const values = [
                { field_id: 1, value: "text value" },
                { field_id: 2, value: "option1" },
            ];

            const authorizedValues = {
                test_category: [
                    { value: "option1", description: "Option 1" },
                    { value: "option2", description: "Option 2" },
                ],
            };

            await additionalFields.renderExtendedAttributes(
                types,
                [],
                authorizedValues
            );
            await additionalFields.setValues(values, authorizedValues);
            additionalFields.clear();

            const textInput = container.querySelector(
                "input[name='extended_attributes.1']"
            );
            expect(textInput.value).to.equal("");

            const select = container.querySelector(
                "select[name='extended_attributes.2']"
            );
            expect(select.value).to.equal("");
        });
    });

    describe("fetchExtendedAttributes", () => {
        it("should fetch extended attribute types", async () => {
            const types =
                await additionalFields.fetchExtendedAttributes("booking");
            expect(types).to.be.an("array");
            expect(types).to.have.lengthOf(4);
            expect(types[0]).to.have.property("name", "Urgency");
            expect(types[1]).to.have.property("name", "Note");
            expect(types[2]).to.have.property("name", "Contact");
            expect(types[3]).to.have.property("name", "Test");
        });
    });

    describe("renderExtendedAttributesValues", () => {
        it("should return empty array when no attributes are provided", () => {
            const result = AdditionalFields.renderExtendedAttributesValues(
                null,
                {},
                {},
                "test-id"
            );
            expect(result).to.deep.equal([""]);
        });

        it("should filter attributes by record ID", () => {
            const attributes = [
                { record_id: "test-id", field_id: 1, value: "value1" },
                { record_id: "other-id", field_id: 2, value: "value2" },
            ];
            const result = AdditionalFields.renderExtendedAttributesValues(
                attributes,
                {},
                {},
                "test-id"
            );
            expect(result).to.deep.equal(["1: value1"]);
        });

        it("should use type name when available", () => {
            const attributes = [
                { record_id: "test-id", field_id: 1, value: "value1" },
            ];
            const types = {
                1: { name: "Test Field" },
            };
            const result = AdditionalFields.renderExtendedAttributesValues(
                attributes,
                types,
                {},
                "test-id"
            );
            expect(result).to.deep.equal(["Test Field: value1"]);
        });

        it("should use field ID as fallback for name", () => {
            const attributes = [
                { record_id: "test-id", field_id: 1, value: "value1" },
            ];
            const result = AdditionalFields.renderExtendedAttributesValues(
                attributes,
                {},
                {},
                "test-id"
            );
            expect(result).to.deep.equal(["1: value1"]);
        });

        it("should use authorized value description when available", () => {
            const attributes = [
                { record_id: "test-id", field_id: 1, value: "value1" },
            ];
            const types = {
                1: {
                    name: "Test Field",
                    authorised_value_category_name: "test_category",
                },
            };
            const authorizedValues = {
                test_category: {
                    value1: "Value 1 Description",
                },
            };
            const result = AdditionalFields.renderExtendedAttributesValues(
                attributes,
                types,
                authorizedValues,
                "test-id"
            );
            expect(result).to.deep.equal(["Test Field: Value 1 Description"]);
        });

        it("should use raw value as fallback when authorized value not found", () => {
            const attributes = [
                { record_id: "test-id", field_id: 1, value: "value1" },
            ];
            const types = {
                1: {
                    name: "Test Field",
                    authorised_value_category_name: "test_category",
                },
            };
            const authorizedValues = {
                test_category: {
                    other_value: "Other Description",
                },
            };
            const result = AdditionalFields.renderExtendedAttributesValues(
                attributes,
                types,
                authorizedValues,
                "test-id"
            );
            expect(result).to.deep.equal(["Test Field: value1"]);
        });

        it("should handle multiple attributes", () => {
            const attributes = [
                { record_id: "test-id", field_id: 1, value: "value1" },
                { record_id: "test-id", field_id: 2, value: "value2" },
            ];
            const types = {
                1: { name: "Field 1" },
                2: { name: "Field 2" },
            };
            const result = AdditionalFields.renderExtendedAttributesValues(
                attributes,
                types,
                {},
                "test-id"
            );
            expect(result).to.deep.equal([
                "Field 1: value1",
                "Field 2: value2",
            ]);
        });
    });

    describe("fetchAndProcessExtendedAttributes", () => {
        it("should process extended attributes correctly", async () => {
            const result =
                await AdditionalFields.fetchAndProcessExtendedAttributes(
                    "booking"
                );
            expect(result).to.be.an("object");
            expect(result).to.have.property("1");
            expect(result["1"]).to.have.property("name", "Urgency");
            expect(result["1"]).to.have.property(
                "authorised_value_category_name",
                "BOOKINGS_URGENCY"
            );
        });

        it("should handle API errors gracefully", async () => {
            getAllStub.rejects(new Error("API Error"));

            const result =
                await AdditionalFields.fetchAndProcessExtendedAttributes(
                    "booking"
                );
            expect(result).to.deep.equal({});
        });
    });

    describe("fetchAndProcessAuthorizedValues", () => {
        it("should process authorized values correctly", async () => {
            const categories = ["BOOKINGS_URGENCY", "YES_NO"];
            const result =
                await AdditionalFields.fetchAndProcessAuthorizedValues(
                    categories
                );

            expect(result).to.be.an("object");
            expect(result).to.have.property("BOOKINGS_URGENCY");
            expect(result.BOOKINGS_URGENCY).to.have.property("HIGH", "High");
            expect(result.BOOKINGS_URGENCY).to.have.property(
                "MEDIUM",
                "Medium"
            );
            expect(result.BOOKINGS_URGENCY).to.have.property("LOW", "Low");
        });

        it("should handle empty categories array", async () => {
            getCategoriesWithValuesStub.resolves([]);
            const result =
                await AdditionalFields.fetchAndProcessAuthorizedValues([]);
            expect(result).to.deep.equal({});
        });

        it("should handle API errors gracefully", async () => {
            getCategoriesWithValuesStub.rejects(new Error("API Error"));

            const result =
                await AdditionalFields.fetchAndProcessAuthorizedValues([
                    "BOOKINGS_URGENCY",
                ]);
            expect(result).to.deep.equal({});
        });
    });
});
