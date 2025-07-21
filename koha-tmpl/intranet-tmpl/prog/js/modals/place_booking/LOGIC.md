# Booking Modal Data Flow

This document describes how data is initialized, constrained, and how interdependencies are managed in the Booking Modal and related booking logic.

## 1. Data Initialization

### a. API Data Loading

- **Bookings**: Loaded via API, provides existing bookings (`booking_id`, `item_id`, `start_date`, `end_date`).
- **Checkouts**: Loaded via API, provides currently checked-out items (`item_id`, `due_date`).
- **Bookable Items**: Loaded via API, includes all items that can be booked (`item_id`, `item_type_id`).
- **Circulation Rules**: Loaded via API, includes rules for lead/trail days, max period, etc.
- **Pickup Locations**: Loaded via API, includes libraries and which items can be picked up there.

### b. UI State Initialization

- **Selected Item/Itemtype/Library**: Initialized as `null` or from route/query params.
- **Selected Dates**: Initialized as empty array or from route/query params.
- **Store**: Pinia store manages all above state reactively.

## 2. Data Constraints & Interdependencies

### a. Constrain Pickup Locations

- **Function**: `constrainPickupLocations`
- **Depends on**: `bookableItems`, `bookingItemtypeId`, `bookingItemId`
- **Effect**: Only locations that can actually provide the selected item/itemtype are shown/enabled.

### b. Constrain Bookable Items

- **Function**: `constrainBookableItems`
- **Depends on**: `pickupLocations`, `pickupLibraryId`, `bookingItemtypeId`
- **Effect**: Only items available at the selected library and/or of the selected type are enabled.

### c. Constrain Item Types

- **Function**: `constrainItemTypes`
- **Depends on**: `bookableItems`, `pickupLocations`, `pickupLibraryId`, `bookingItemId`
- **Effect**: Only item types that are available for the selected library/item are enabled.

### d. Date Selection Constraints

- **Function**: `calculateDisabledDates`
- **Depends on**: `bookings`, `checkouts`, `bookableItems`, `selectedItem`, `editBookingId`, `selectedDates`, `circulationRules`
- **Effect**:
  - **Lead Period**: All dates within the lead period (before the first allowed booking date, as defined by circulation rules) are immediately disabled and visually indicated as unavailable. This is enforced as soon as the calendar is opened and does not depend on user interaction.
  - **Trail Period**: Trail period highlighting and constraint only activate after the user selects a start date. As the user hovers/selects an end date, the calendar dynamically highlights the trail period (the days after the selected end date up to the allowed trail period). If any of these trail days are unavailable (e.g., due to bookings/checkouts), the end date is visually marked as invalid/unselectable. This provides immediate feedback before the user confirms the range.
  - **Other Constraints**: Disables dates that are already booked/checked out, outside the allowed max period, or when not enough items are available.

### e. Date Events/Markers

- **Function**: `getBookingMarkersForDate`
- **Depends on**: `bookings`, `checkouts`, `date`, `circulationRules`, `selectedDates`
- **Effect**: Returns markers for each date, indicating if it is booked, checked out, lead, or trail (for calendar coloring).

### f. Date Range Validation

- **Function**: `handleBookingDateChange`
- **Depends on**: `selectedDates`, `circulationRules`, `bookings`, `checkouts`, `bookableItems`, `selectedItem`, `editBookingId`
- **Effect**: Validates the selected date range for correctness and availability.

## 3. Data Flow Example

1. **User selects a library**:
    - Bookable items and item types are constrained accordingly.
2. **User selects an item or item type**:
    - Pickup locations and bookable items are further constrained.
3. **User opens calendar**:
    - Disabled dates are computed based on bookings, checkouts, and circulation rules.
    - Markers for booked, checked out, lead, and trail days are computed for coloring.
4. **User selects a date range**:
    - Date validation runs, and constraints update reactively.
    - UI updates to reflect new constraints and available options.

## 4. Interdependency Notes

- Changing one selection (e.g., library) may cascade and constrain other selections (e.g., items, item types).
- Date constraints are always recalculated based on the current state of all selections and rules.
- All constraint functions are pure and depend only on their arguments, making the flow predictable and testable.

## 5. Key Functions (Reference)

- `constrainPickupLocations`
- `constrainBookableItems`
- `constrainItemTypes`
- `calculateDisabledDates`
- `getBookingMarkersForDate`
- `handleBookingDateChange`

---

**This document should be kept up to date as the booking logic evolves.**
