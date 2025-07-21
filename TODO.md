# Bookings Modal

- [x] When updating external dependents, update
  - Bookings count in sidebar
  - Bookings count in related containers
- [x] Correctly pass new booking data to vis-timeline and datatable for instant updates
- [x] Interpolate item type id into description
- [x] Wrap step sections in fieldsets for better visual separation
- [x] Make step headings fieldset legends
- [x] Debounce the patron search to not hit the database as often
- [x] Analyze current data flow for flatpickr widget
  - Note findings and plan refactor to assert correctness
  - Overview:
    - There are bookings
    - Bookings are primarily defined as a date range w/ associated metadata
    - Bookings are tied to a biblio (bibliographic record), which normally has items associated with it, these items are of a certain type, item types have associated metadata called circulation rules that dictate when and where a patron can interact with an item
    - A booking can be made if the following constraints are not violated
      - At least one item
        - Is not booked or checked out within the range that the booking is attempted to be scheduled for
        - Has a start date at or after the current date
        - Has an end date that is within the maximum booking period defined by circulation rules, normally there are loan periods with renewals, so the calculation is (loan period length * (number of renewals + 1))
      - Additionally, we have lead and trail periods that need to be added before and after existing bookings, these count towards the booking periods as if the item were booked during these periods
        - If we have a range of 3 days for an existing booking and lead and trail periods of 2 days, the effective booked date range would become 7 days. 2 before and 2 after.
~~- Note: the current problem with the rendering of the calendar markers is that the store is not updated when calculating disabled dates and therefore the marker generation does nothing~~

Integrate refactored modal into:
- [ ] "Bookings to collect"
- [ ] "OPAC"
- [ ] Bookings Tab
    - [ ] Edit
    - [ ] Edit via timeline

