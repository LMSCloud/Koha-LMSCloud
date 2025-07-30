# Booking System Test Suite

Comprehensive test suite for the refactored booking system, covering all business logic, data structures, and integration scenarios.

## Test Structure

### Unit Tests

-   **`IntervalTree.test.mjs`** - Tests for the interval tree data structure
-   **`SweepLineProcessor.test.mjs`** - Tests for the sweep line algorithm
-   **`bookingManager.test.mjs`** - Tests for all business logic functions

### Integration Tests

-   **`integration.test.mjs`** - End-to-end workflow and performance tests

## Running Tests

### Using Package Scripts (Recommended)

```bash
# Run all mocha tests once (includes booking tests)
yarn test:mocha

# Run tests in watch mode (re-runs on file changes)
yarn test:mocha:watch

# Run specific test patterns with mocha filters
yarn test:mocha --grep "IntervalTree"
yarn test:mocha --grep "booking"
yarn test:mocha 't/mocha/unit/bookings/*.test.mjs'
```

### Direct Mocha Execution

```bash
# Run all tests
mocha 't/mocha/unit/**/*.test.mjs' --timeout 10000

# Run specific test file
mocha 't/mocha/unit/bookings/IntervalTree.test.mjs' --timeout 10000

# Run with grep pattern
mocha 't/mocha/unit/**/*.test.mjs' --grep "end_date_only" --timeout 10000

# Run tests in specific directory
mocha 't/mocha/unit/bookings/*.test.mjs' --timeout 10000
```

## Test Categories

### Performance Tests

-   Verify O(log n) performance for interval tree operations
-   Compare old vs new architecture performance
-   Test with large datasets (1000+ bookings)

### Business Logic Tests

-   Date validation and constraint checking
-   Circulation rule enforcement
-   End-date-only booking mode
-   Lead/trail time calculations

### Data Structure Tests

-   Interval tree balancing and correctness
-   Sweep line algorithm accuracy
-   Edge case handling (empty data, overlaps)

### Integration Tests

-   Complete booking workflow
-   Debug logging functionality
-   Architectural separation verification

## Test Data

Tests use realistic sample data:

-   Multiple item types (laptops, projectors, cameras)
-   Overlapping bookings and checkouts
-   Various circulation rules
-   Edge cases and invalid data

## Debug Features

Tests include verification of debug logging:

```javascript
// Enable debug logging during tests
window.BookingDebug.enable();

// Check log output
const logs = window.BookingDebug.exportLogs();
```

## Performance Benchmarks

Integration tests measure performance improvements:

-   Old approach: O(n) date processing
-   New approach: O(log n) with interval trees
-   Expected improvement: 20%+ for large datasets

## Coverage Goals

-   **IntervalTree**: 100% - All operations and edge cases
-   **SweepLineProcessor**: 95% - Core algorithm and utilities
-   **BookingManager**: 90% - All exported functions
-   **Integration**: 85% - Key workflows and error handling

## Test Environment

Tests are designed to run in:

-   Node.js with ES6 modules
-   Browser environment (manual testing)
-   CI/CD pipelines
-   Development watch mode

## Adding New Tests

When adding new functionality:

1. **Unit tests** for individual functions
2. **Integration tests** for workflows
3. **Performance tests** for algorithms
4. **Error handling** for edge cases

Example test structure:

```javascript
describe("NewFeature", () => {
    let testData;

    beforeEach(() => {
        testData = createTestData();
    });

    it("should handle normal case", () => {
        const result = newFeature(testData);
        expect(result).to.be.valid;
    });

    it("should handle edge case", () => {
        const result = newFeature(null);
        expect(result).to.handle.gracefully;
    });
});
```

## Debugging Test Failures

### Common Issues

1. **Date/timezone problems** - Use dayjs for consistent parsing
2. **Async operations** - Ensure proper await/Promise handling
3. **Mock dependencies** - Check global object mocking
4. **Performance variations** - Allow reasonable time tolerances

### Debug Tools

```javascript
// Enable detailed logging
managerLogger.setEnabled(true);
managerLogger.setLevels(["debug", "info", "warn", "error"]);

// Export data for inspection
const debugData = {
    tree: intervalTree.exportData(),
    logs: managerLogger.exportLogs(),
};
```

## Continuous Integration

Tests are designed to run in CI environments:

-   No external dependencies
-   Deterministic timing where possible
-   Clear pass/fail criteria
-   Detailed error reporting
