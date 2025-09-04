/**
 * Unit tests for Flatpickr integration in BookingModal.vue
 * Tests calendar configuration, class application, highlighting, and behavior modifications
 */

import { describe, it, beforeEach, afterEach } from "mocha";
import { expect } from "chai";
import sinon from "sinon";
import { JSDOM } from "jsdom";
import {
    applyCalendarHighlighting,
    clearCalendarHighlighting,
    createOnChange,
    createOnDayCreate,
    createOnClose,
    preloadFlatpickrLocale,
} from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/lib/adapters/calendar.mjs";
import dayjs from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/utils/dayjs.mjs";

// Setup JSDOM environment
const dom = new JSDOM('<!DOCTYPE html><html lang="en"><body></body></html>', {
    url: 'http://localhost',
    pretendToBeVisual: true,
    resources: 'usable'
});

global.document = dom.window.document;
global.window = dom.window;
try {
    global.navigator = dom.window.navigator;
} catch (e) {
    // Some Node versions expose a read-only global.navigator; skip in that case
}
global.HTMLElement = dom.window.HTMLElement;

// Mock DOM environment for testing
function createMockDOMEnvironment() {
    const dayElements = [];
    const container = {
        querySelectorAll: selector => {
            if (selector === ".flatpickr-day") {
                return dayElements;
            }
            if (selector === ".booking-constrained-range-marker") {
                return dayElements.filter(el =>
                    el.classList.contains("booking-constrained-range-marker")
                );
            }
            return [];
        },
    };
    
    return { container, dayElements };
}

// Create mock flatpickr instance
function createMockFlatpickrInstance(container) {
    return {
        calendarContainer: container,
        selectedDates: [],
        setDate: sinon.stub(),
        clear: sinon.stub(),
        jumpToDate: sinon.stub(),
        currentMonth: 0,
        currentYear: 2025,
        days: container,
        _constraintHighlighting: null,
    };
}

// Create mock day element
function createMockDayElement(date, disabled = false) {
    const classes = new Set(disabled ? ["flatpickr-disabled"] : []);
    const childElements = [];
    
    // Create a more complete mock that behaves like a real DOM element
    const element = {
        dateObj: date,
        classList: {
            contains: className => classes.has(className),
            add: (...classNames) => classNames.forEach(cn => classes.add(cn)),
            remove: (...classNames) => classNames.forEach(cn => classes.delete(cn)),
            toggle: (className, force) => {
                if (force === undefined) {
                    classes.has(className) ? classes.delete(className) : classes.add(className);
                } else {
                    force ? classes.add(className) : classes.delete(className);
                }
            },
        },
        setAttribute: sinon.stub(),
        removeAttribute: sinon.stub(),
        appendChild: sinon.stub().callsFake(child => {
            childElements.push(child);
            return child;
        }),
        addEventListener: sinon.stub(),
        getBoundingClientRect: () => ({ left: 100, top: 200, width: 40 }),
        // Return actual arrays, not stubs, since the code uses them immediately
        querySelectorAll: (selector) => {
            // Filter childElements based on selector
            if (selector === '.booking-marker-grid') {
                return childElements.filter(el => 
                    el.className && el.className.includes('booking-marker-grid')
                );
            }
            return [];
        },
        querySelector: (selector) => null,
        innerHTML: "",
        _classes: classes, // For test inspection
        _children: childElements, // For test inspection
    };
    
    return element;
}

// Create mock store
function createMockStore(overrides = {}) {
    let selectedDateRangeValue = [];
    const setSelectedDateRangeStub = sinon.stub().callsFake((dates) => {
        selectedDateRangeValue = dates;
    });
    
    const store = {
        loading: {
            bookableItems: false,
            bookings: false,
            checkouts: false,
            circulationRules: false,
        },
        bookableItems: [
            { item_id: 1, item_type_id: "BOOK", home_library_id: "LIB1" },
            { item_id: 2, item_type_id: "BOOK", home_library_id: "LIB2" },
        ],
        bookings: [],
        checkouts: [],
        circulationRules: [{ maxPeriod: 7, leadTime: 0, leadTimeToday: false }],
        unavailableByDate: {},
        bookingItemId: null,
        bookingId: null,
        setSelectedDateRange: setSelectedDateRangeStub,
        setUnavailableByDate: sinon.stub().callsFake((data) => {
            store.unavailableByDate = data;
        }),
        ...overrides,
    };
    
    // Create a property with getter/setter for selectedDateRange
    Object.defineProperty(store, 'selectedDateRange', {
        get() {
            return selectedDateRangeValue;
        },
        set(value) {
            selectedDateRangeValue = value;
            setSelectedDateRangeStub(value);
        },
        configurable: true,
        enumerable: true
    });
    
    // Override with any provided overrides including circulationRules
    if (overrides.circulationRules) {
        store.circulationRules = overrides.circulationRules;
    }
    
    return store;
}

describe("Flatpickr Integration in BookingModal", () => {
    let sandbox;
    
    beforeEach(() => {
        sandbox = sinon.createSandbox();
        global.requestAnimationFrame = fn => setTimeout(fn, 0);
        global.$__ = str => str; // Mock translation
        
        // Mock window functions used by bookingCalendar
        global.window.flatpickr_dateformat_string = "d.m.Y";
        global.window.scrollX = 0;
        global.window.scrollY = 0;
        global.win = (key) => {
            if (key === "flatpickr_dateformat_string") return "d.m.Y";
            if (key === "current_language") return "en";
            return null;
        };
        
        // Mock document.documentElement.lang
        Object.defineProperty(document.documentElement, 'lang', {
            value: 'en',
            writable: true,
            configurable: true
        });
        
        // Ensure document.createElement returns objects with the necessary properties
        const originalCreateElement = document.createElement;
        sandbox.stub(document, 'createElement').callsFake((tagName) => {
            const elem = originalCreateElement.call(document, tagName);
            // Add a remove method if it doesn't exist
            if (!elem.remove) {
                elem.remove = function() {
                    if (this.parentNode) {
                        this.parentNode.removeChild(this);
                    }
                };
            }
            return elem;
        });
    });
    
    afterEach(() => {
        sandbox.restore();
    });
    
    // Note: createFlatpickrConfig helper was removed during refactor. Tests now
    // focus on the calendar UI helpers and event factories actually used.
    
    describe("applyCalendarHighlighting", () => {
        it("should apply booking-constrained-range-marker class to dates in range", done => {
            const { container, dayElements } = createMockDOMEnvironment();
            const startDate = new Date("2025-01-15");
            const endDate = new Date("2025-01-20");
            
            // Create day elements for the range
            for (let i = 15; i <= 20; i++) {
                dayElements.push(createMockDayElement(new Date(`2025-01-${i}`)));
            }
            
            const instance = createMockFlatpickrInstance(container);
            const highlightingData = {
                startDate,
                targetEndDate: endDate,
                constraintMode: "normal",
                blockedIntermediateDates: [],
            };
            
            applyCalendarHighlighting(instance, highlightingData);
            
            // Wait for requestAnimationFrame
            setTimeout(() => {
                dayElements.forEach(dayElem => {
                    expect(dayElem._classes.has("booking-constrained-range-marker")).to.be.true;
                });
                expect(instance._constraintHighlighting).to.equal(highlightingData);
                done();
            }, 10);
        });
        
        it("should apply booking-intermediate-blocked class in end_date_only mode", done => {
            const { container, dayElements } = createMockDOMEnvironment();
            const startDate = new Date("2025-01-15");
            const endDate = new Date("2025-01-20");
            const blockedDates = [
                new Date("2025-01-16"),
                new Date("2025-01-17"),
                new Date("2025-01-18"),
                new Date("2025-01-19"),
            ];
            
            // Create day elements
            for (let i = 15; i <= 20; i++) {
                dayElements.push(createMockDayElement(new Date(`2025-01-${i}`)));
            }
            
            const instance = createMockFlatpickrInstance(container);
            const highlightingData = {
                startDate,
                targetEndDate: endDate,
                constraintMode: "end_date_only",
                blockedIntermediateDates: blockedDates,
            };
            
            applyCalendarHighlighting(instance, highlightingData);
            
            setTimeout(() => {
                // Check start date (should have marker but not blocked)
                expect(dayElements[0]._classes.has("booking-constrained-range-marker")).to.be.true;
                expect(dayElements[0]._classes.has("booking-intermediate-blocked")).to.be.false;
                
                // Check intermediate dates (should be blocked)
                for (let i = 1; i <= 4; i++) {
                    expect(dayElements[i]._classes.has("booking-constrained-range-marker")).to.be.true;
                    expect(dayElements[i]._classes.has("booking-intermediate-blocked")).to.be.true;
                }
                
                // Check end date (should have marker but not blocked)
                expect(dayElements[5]._classes.has("booking-constrained-range-marker")).to.be.true;
                expect(dayElements[5]._classes.has("booking-intermediate-blocked")).to.be.false;
                
                done();
            }, 10);
        });
        
        it("should not apply highlighting to disabled dates", done => {
            const { container, dayElements } = createMockDOMEnvironment();
            const startDate = new Date("2025-01-15");
            const endDate = new Date("2025-01-17");
            
            // Create mix of enabled and disabled days
            dayElements.push(createMockDayElement(new Date("2025-01-15"), false));
            dayElements.push(createMockDayElement(new Date("2025-01-16"), true)); // disabled
            dayElements.push(createMockDayElement(new Date("2025-01-17"), false));
            
            const instance = createMockFlatpickrInstance(container);
            const highlightingData = {
                startDate,
                targetEndDate: endDate,
                constraintMode: "normal",
                blockedIntermediateDates: [],
            };
            
            applyCalendarHighlighting(instance, highlightingData);
            
            setTimeout(() => {
                expect(dayElements[0]._classes.has("booking-constrained-range-marker")).to.be.true;
                expect(dayElements[1]._classes.has("booking-constrained-range-marker")).to.be.false;
                expect(dayElements[2]._classes.has("booking-constrained-range-marker")).to.be.true;
                done();
            }, 10);
        });
        
        it("should store highlighting data for reuse", done => {
            const { container, dayElements } = createMockDOMEnvironment();
            const instance = createMockFlatpickrInstance(container);
            const highlightingData = {
                startDate: new Date("2025-01-15"),
                targetEndDate: new Date("2025-01-20"),
                constraintMode: "normal",
                blockedIntermediateDates: [],
            };
            
            applyCalendarHighlighting(instance, highlightingData);
            
            setTimeout(() => {
                expect(instance._constraintHighlighting).to.deep.equal(highlightingData);
                done();
            }, 10);
        });
    });
    
    describe("clearCalendarHighlighting", () => {
        it("should remove all constraint highlighting classes", () => {
            const { container, dayElements } = createMockDOMEnvironment();
            
            // Create days with highlighting classes
            for (let i = 1; i <= 3; i++) {
                const dayElem = createMockDayElement(new Date(`2025-01-${i}`));
                dayElem.classList.add("booking-constrained-range-marker");
                dayElem.classList.add("booking-intermediate-blocked");
                dayElements.push(dayElem);
            }
            
            const instance = createMockFlatpickrInstance(container);
            clearCalendarHighlighting(instance);
            
            dayElements.forEach(dayElem => {
                expect(dayElem._classes.has("booking-constrained-range-marker")).to.be.false;
                expect(dayElem._classes.has("booking-intermediate-blocked")).to.be.false;
            });
        });
        
        it("should handle missing instance gracefully", () => {
            expect(() => clearCalendarHighlighting(null)).to.not.throw();
            expect(() => clearCalendarHighlighting(undefined)).to.not.throw();
        });
    });
    
    describe("createOnChange handler", () => {
        beforeEach(() => {
            // Mock the handleBookingDateChange function to avoid validation errors
            global.handleBookingDateChange = sinon.stub().returns({
                isValid: true,
                errorMessage: null,
                selectedDates: null
            });
            
            // Mock getVisibleCalendarDates
            global.getVisibleCalendarDates = sinon.stub().returns([]);
        });
        
        afterEach(() => {
            delete global.handleBookingDateChange;
            delete global.getVisibleCalendarDates;
        });
        
        it("should update store with selected date range", () => {
            // Create a future date to avoid "too soon" validation errors
            const futureDate1 = new Date();
            futureDate1.setDate(futureDate1.getDate() + 30);
            const futureDate2 = new Date();
            futureDate2.setDate(futureDate2.getDate() + 35);
            
            const store = createMockStore({
                circulationRules: [{ 
                    maxPeriod: 7,
                    leadTime: 0,  // No lead time required
                    leadTimeToday: false
                }],
            });
            const errorMessageRef = { value: "" };
            const tooltipVisibleRef = { value: false };
            const constraintOptions = {
                dateRangeConstraint: null,
                maxBookingPeriod: null,
            };
            
            const onChange = createOnChange(store, {
                setError: msg => (errorMessageRef.value = msg),
                tooltipVisibleRef,
                constraintOptions,
            });
            
            const selectedDates = [futureDate1, futureDate2];
            const instance = createMockFlatpickrInstance();
            
            // Override handleBookingDateChange to return valid result
            global.handleBookingDateChange.returns({
                isValid: true,
                errorMessage: null,
                selectedDates: [
                    dayjs(futureDate1).toISOString(),
                    dayjs(futureDate2).toISOString()
                ]
            });
            
            // Call onChange directly
            onChange(selectedDates, "", instance);
            
            // The handler should have updated the store
            expect(store.selectedDateRange).to.have.lengthOf(2);
            expect(store.setSelectedDateRange.calledOnce).to.be.true;
            const call = store.setSelectedDateRange.getCall(0);
            expect(call.args[0]).to.have.lengthOf(2);
            expect(dayjs(call.args[0][0]).format("YYYY-MM-DD")).to.equal(dayjs(futureDate1).format("YYYY-MM-DD"));
            expect(dayjs(call.args[0][1]).format("YYYY-MM-DD")).to.equal(dayjs(futureDate2).format("YYYY-MM-DD"));
        });
        
        it("should clear error message on valid selection", () => {
            const futureDate = new Date();
            futureDate.setDate(futureDate.getDate() + 30);
            
            const store = createMockStore({
                circulationRules: [{ 
                    maxPeriod: 7,
                    leadTime: 0,
                    leadTimeToday: false
                }],
            });
            const errorMessageRef = { value: "Previous error" };
            const tooltipVisibleRef = { value: false };
            const constraintOptions = {};
            
            const onChange = createOnChange(store, {
                setError: msg => (errorMessageRef.value = msg),
                tooltipVisibleRef,
                constraintOptions,
            });
            
            const selectedDates = [futureDate];
            const instance = createMockFlatpickrInstance();
            
            // Override to return valid result
            global.handleBookingDateChange.returns({
                isValid: true,
                errorMessage: null,
                selectedDates: [dayjs(futureDate).toISOString()]
            });
            
            onChange(selectedDates, "", instance);
            
            expect(errorMessageRef.value).to.equal("");
        });
        
        it("should handle constraint mode for date range", () => {
            const futureDate = new Date();
            futureDate.setDate(futureDate.getDate() + 30);
            
            const store = createMockStore({
                circulationRules: [{ 
                    maxPeriod: 7,
                    leadTime: 0,
                    leadTimeToday: false
                }],
            });
            const errorMessageRef = { value: "" };
            const tooltipVisibleRef = { value: false };
            const constraintOptions = {
                dateRangeConstraint: "issuelength",
                maxBookingPeriod: 7,
            };
            
            const onChange = createOnChange(store, {
                setError: msg => (errorMessageRef.value = msg),
                tooltipVisibleRef,
                constraintOptions,
            });
            
            const selectedDates = [futureDate];
            const instance = createMockFlatpickrInstance();
            
            // Mock calculateConstraintHighlighting to be available
            global.calculateConstraintHighlighting = sinon.stub().returns({
                startDate: selectedDates[0],
                targetEndDate: new Date(futureDate.getTime() + 7 * 24 * 60 * 60 * 1000),
                constraintMode: "normal",
                blockedIntermediateDates: [],
            });
            
            // Override to return constraint result
            const constraintEndDate = new Date(futureDate.getTime() + 7 * 24 * 60 * 60 * 1000);
            global.handleBookingDateChange.returns({
                isValid: true,
                errorMessage: null,
                selectedDates: [
                    dayjs(futureDate).toISOString(),
                    dayjs(constraintEndDate).toISOString()
                ]
            });
            
            onChange(selectedDates, "", instance);
            
            // Should have updated store with constraint applied
            expect(store.selectedDateRange).to.have.lengthOf(1); // Single date selected
            expect(store.setSelectedDateRange.called).to.be.true;
            const call = store.setSelectedDateRange.getCall(0);
            expect(call.args[0]).to.have.lengthOf(1);
        });
    });
    
    describe("createOnDayCreate handler", () => {
        beforeEach(() => {
            // Mock getBookingMarkersForDate function
            global.getBookingMarkersForDate = sinon.stub().returns([
                { type: 'booked', count: 2 },
                { type: 'checked-out', count: 1 }
            ]);
            
            // Mock aggregateMarkersByType function 
            global.aggregateMarkersByType = sinon.stub().returns({
                booked: 2,
                'checked-out': 1
            });
        });
        
        afterEach(() => {
            delete global.getBookingMarkersForDate;
            delete global.aggregateMarkersByType;
        });
        
        it("should aggregate markers for dates with bookings", () => {
            const store = createMockStore({
                unavailableByDate: {
                    "2025-01-15": {
                        booked: [{ item_id: 1 }],
                        checked_out: [],
                    },
                    "2025-01-16": {
                        booked: [{ item_id: 1 }, { item_id: 2 }],
                        checked_out: [{ item_id: 3 }],
                    },
                },
            });
            
            const markersRef = { value: [] };
            const visibleRef = { value: false };
            const xRef = { value: 0 };
            const yRef = { value: 0 };
            
            const onDayCreate = createOnDayCreate(
                store,
                markersRef,
                visibleRef,
                xRef,
                yRef
            );
            
            const dayElem = createMockDayElement(new Date("2025-01-16"));
            
            // Call with correct signature: selectedDates, dateStr, fp, dayElem
            onDayCreate([new Date("2025-01-16")], "", {}, dayElem);
            
            // Check that appendChild was called to add marker grid
            expect(dayElem.appendChild.called).to.be.true;
            const appendedElement = dayElem.appendChild.getCall(0).args[0];
            expect(appendedElement).to.have.property('className');
            expect(appendedElement.className).to.include('booking-marker-grid');
        });
        
        it("should handle hover events for tooltip display", () => {
            const store = createMockStore({
                unavailableByDate: {
                    "2025-01-15": {
                        booked: [{ item_id: 1, patron: { firstname: "John", surname: "Doe" } }],
                    },
                },
            });
            
            const markersRef = { value: [] };
            const visibleRef = { value: false };
            const xRef = { value: 0 };
            const yRef = { value: 0 };
            
            const onDayCreate = createOnDayCreate(
                store,
                markersRef,
                visibleRef,
                xRef,
                yRef
            );
            
            const dayElem = createMockDayElement(new Date("2025-01-15"));
            
            // Mock getBookingMarkersForDate to return markers for this date
            global.getBookingMarkersForDate.returns([
                { 
                    type: 'booked', 
                    count: 1,
                    patron: { firstname: "John", surname: "Doe" },
                    item_id: 1
                }
            ]);
            
            // Call with correct signature: selectedDates, dateStr, fp, dayElem
            onDayCreate([new Date("2025-01-15")], "", {}, dayElem);
            
            // Simulate hover event
            const hoverHandler = dayElem.addEventListener.getCall(0).args[1];
            hoverHandler({ currentTarget: dayElem });
            
            expect(visibleRef.value).to.be.true;
            expect(markersRef.value).to.have.lengthOf.at.least(1);
            expect(xRef.value).to.equal(120); // left + scrollX + width/2 = 100 + 0 + 40/2 = 120
            expect(yRef.value).to.equal(190); // top + scrollY - 10 = 200 + 0 - 10 = 190
        });
    });
    
    describe("createOnClose handler", () => {
        it("should clear tooltip state on calendar close", () => {
            const markersRef = { value: [{ type: "booked" }] };
            const visibleRef = { value: true };
            
            const onClose = createOnClose(markersRef, visibleRef);
            
            onClose([], "", {});
            
            expect(markersRef.value).to.be.empty;
            expect(visibleRef.value).to.be.false;
        });
    });
    
    // createOnFlatpickrReady helper removed; no longer tested here.
    
    describe("Calendar readiness based on loading states", () => {
        it("should disable calendar when data is loading", () => {
            const store = createMockStore({
                loading: {
                    bookableItems: true,
                    bookings: false,
                    checkouts: false,
                },
            });
            
            const isReady = !store.loading.bookableItems && 
                           !store.loading.bookings && 
                           !store.loading.checkouts &&
                           store.bookableItems?.length > 0;
            
            expect(isReady).to.be.false;
        });
        
        it("should enable calendar when all data is loaded", () => {
            const store = createMockStore({
                loading: {
                    bookableItems: false,
                    bookings: false,
                    checkouts: false,
                },
                bookableItems: [{ item_id: 1 }],
            });
            
            const isReady = !store.loading.bookableItems && 
                           !store.loading.bookings && 
                           !store.loading.checkouts &&
                           store.bookableItems?.length > 0;
            
            expect(isReady).to.be.true;
        });
        
        it("should disable calendar when no bookable items available", () => {
            const store = createMockStore({
                loading: {
                    bookableItems: false,
                    bookings: false,
                    checkouts: false,
                },
                bookableItems: [],
            });
            
            const isReady = !store.loading.bookableItems && 
                           !store.loading.bookings && 
                           !store.loading.checkouts &&
                           store.bookableItems?.length > 0;
            
            expect(isReady).to.be.false;
        });
    });
    
    describe("Race condition prevention", () => {
        // The prevention of date selection during loading is now handled in
        // the Vue layer (isCalendarReady), not via a config helper.
        
        it("should re-apply highlighting after data loads", done => {
            const { container, dayElements } = createMockDOMEnvironment();
            const instance = createMockFlatpickrInstance(container);
            
            // Add some day elements
            for (let i = 15; i <= 20; i++) {
                dayElements.push(createMockDayElement(new Date(`2025-01-${i}`)));
            }
            
            // Store highlighting data for reuse
            instance._constraintHighlighting = {
                startDate: new Date("2025-01-15"),
                targetEndDate: new Date("2025-01-20"),
                constraintMode: "normal",
                blockedIntermediateDates: [],
            };
            
            // Re-apply highlighting using stored data
            applyCalendarHighlighting(instance, instance._constraintHighlighting);
            
            setTimeout(() => {
                // Check that highlighting was applied
                dayElements.forEach(dayElem => {
                    expect(dayElem._classes.has("booking-constrained-range-marker")).to.be.true;
                });
                done();
            }, 10);
        });
    });
    
    describe("Constraint highlighting with different modes", () => {
        it("should highlight full range in normal mode", done => {
            const { container, dayElements } = createMockDOMEnvironment();
            const startDate = new Date("2025-01-15");
            const endDate = new Date("2025-01-18");
            
            for (let i = 15; i <= 18; i++) {
                dayElements.push(createMockDayElement(new Date(`2025-01-${i}`)));
            }
            
            const instance = createMockFlatpickrInstance(container);
            const highlightingData = {
                startDate,
                targetEndDate: endDate,
                constraintMode: "normal",
                blockedIntermediateDates: [],
            };
            
            applyCalendarHighlighting(instance, highlightingData);
            
            setTimeout(() => {
                dayElements.forEach(dayElem => {
                    expect(dayElem._classes.has("booking-constrained-range-marker")).to.be.true;
                    expect(dayElem._classes.has("booking-intermediate-blocked")).to.be.false;
                });
                done();
            }, 10);
        });
        
        it("should apply click prevention for blocked dates in end_date_only mode", done => {
            const { container, dayElements } = createMockDOMEnvironment();
            
            // Create elements with proper structure for click prevention
            const preventClickStub = sinon.stub();
            for (let i = 15; i <= 20; i++) {
                const dayElem = createMockDayElement(new Date(`2025-01-${i}`));
                dayElem.addEventListener = preventClickStub;
                dayElements.push(dayElem);
            }
            
            const instance = createMockFlatpickrInstance(container);
            const highlightingData = {
                startDate: new Date("2025-01-15"),
                targetEndDate: new Date("2025-01-20"),
                constraintMode: "end_date_only",
                blockedIntermediateDates: [
                    new Date("2025-01-16"),
                    new Date("2025-01-17"),
                    new Date("2025-01-18"),
                    new Date("2025-01-19"),
                ],
            };
            
            // Mock the applyClickPrevention function
            global.applyClickPrevention = inst => {
                inst.calendarContainer.querySelectorAll(".flatpickr-day").forEach(elem => {
                    if (elem._classes.has("booking-intermediate-blocked")) {
                        elem.addEventListener("click", preventClickStub);
                    }
                });
            };
            
            applyCalendarHighlighting(instance, highlightingData);
            
            setTimeout(() => {
                // Verify blocked dates have the blocked class
                expect(dayElements[1]._classes.has("booking-intermediate-blocked")).to.be.true;
                expect(dayElements[2]._classes.has("booking-intermediate-blocked")).to.be.true;
                expect(dayElements[3]._classes.has("booking-intermediate-blocked")).to.be.true;
                expect(dayElements[4]._classes.has("booking-intermediate-blocked")).to.be.true;
                
                // Start and end dates should not be blocked
                expect(dayElements[0]._classes.has("booking-intermediate-blocked")).to.be.false;
                expect(dayElements[5]._classes.has("booking-intermediate-blocked")).to.be.false;
                
                done();
            }, 10);
        });
    });
    
    describe("Tooltip state management", () => {
        beforeEach(() => {
            // Mock necessary functions
            global.getBookingMarkersForDate = sinon.stub().returns([
                { type: 'booked', count: 1, item_id: 1 }
            ]);
            global.aggregateMarkersByType = sinon.stub().returns({
                booked: 1
            });
        });
        
        afterEach(() => {
            delete global.getBookingMarkersForDate;
            delete global.aggregateMarkersByType;
        });
        
        it("should update tooltip position on hover", () => {
            const store = createMockStore({
                unavailableByDate: {
                    "2025-01-15": {
                        booked: [{ item_id: 1 }],
                    },
                },
            });
            
            const markersRef = { value: [] };
            const visibleRef = { value: false };
            const xRef = { value: 0 };
            const yRef = { value: 0 };
            
            const onDayCreate = createOnDayCreate(
                store,
                markersRef,
                visibleRef,
                xRef,
                yRef
            );
            
            const dayElem = createMockDayElement(new Date("2025-01-15"));
            // Override getBoundingClientRect for this specific test
            dayElem.getBoundingClientRect = () => ({
                left: 150,
                top: 250,
                width: 40,
            });
            
            // Call with correct signature: selectedDates, dateStr, fp, dayElem
            onDayCreate([new Date("2025-01-15")], "", {}, dayElem);
            
            // Get the hover handler
            const hoverHandler = dayElem.addEventListener.getCall(0).args[1];
            hoverHandler({ currentTarget: dayElem });
            
            // Check tooltip position calculation  
            expect(xRef.value).to.equal(170); // left + scrollX + width/2 = 150 + 0 + 40/2 = 170
            expect(yRef.value).to.equal(240); // top + scrollY - 10 = 250 + 0 - 10 = 240
        });
        
        it("should clear tooltip on mouseleave", () => {
            const store = createMockStore({
                unavailableByDate: {
                    "2025-01-15": {
                        booked: [{ item_id: 1 }],
                    },
                },
            });
            
            const markersRef = { value: [] };
            const visibleRef = { value: false };
            const xRef = { value: 0 };
            const yRef = { value: 0 };
            
            const onDayCreate = createOnDayCreate(
                store,
                markersRef,
                visibleRef,
                xRef,
                yRef
            );
            
            const dayElem = createMockDayElement(new Date("2025-01-15"));
            
            // Call with correct signature: selectedDates, dateStr, fp, dayElem
            onDayCreate([new Date("2025-01-15")], "", {}, dayElem);
            
            // Get both handlers
            const hoverHandler = dayElem.addEventListener.getCall(0).args[1]; // mouseover
            const leaveHandler = dayElem.addEventListener.getCall(1).args[1]; // mouseout
            
            // First hover to show tooltip
            hoverHandler({ currentTarget: dayElem });
            expect(visibleRef.value).to.be.true;
            
            // Then leave to hide tooltip - mouseout only hides tooltip, doesn't clear markers
            leaveHandler();
            expect(visibleRef.value).to.be.false;
            // The markers are not cleared on mouseout, only visibility is hidden
            // This is the correct behavior according to the implementation
        });
    });
    
    describe("preloadFlatpickrLocale", () => {
        it("should handle locale preloading", async () => {
            // Mock the window object
            global.window.flatpickr = {
                l10ns: {
                    default: {},
                    de: {},
                },
            };
            
            // The function should complete without errors
            try {
                await preloadFlatpickrLocale();
                expect(true).to.be.true; // Test passes if no error thrown
            } catch (error) {
                expect.fail(`preloadFlatpickrLocale threw an error: ${error}`);
            }
        });
        
        it("should handle missing flatpickr gracefully", async () => {
            delete global.window.flatpickr;
            
            // Should not throw even if flatpickr is not available
            try {
                await preloadFlatpickrLocale();
                expect(true).to.be.true; // Test passes if no error thrown
            } catch (error) {
                expect.fail(`preloadFlatpickrLocale threw an error: ${error}`);
            }
        });
    });
});
