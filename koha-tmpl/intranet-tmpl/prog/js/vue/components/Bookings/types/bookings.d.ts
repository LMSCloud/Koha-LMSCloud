export type BookableItem = {
  item_id: string | number;
  item_type_id: string;
  effective_item_type_id?: string;
  home_library_id: string;
  _strings?: { item_type_id?: { str?: string } };
};

export type Booking = {
  booking_id: number;
  item_id: string | number;
  start_date: string;
  end_date: string;
  status?: string;
  patron_id?: number;
};

export type Checkout = {
  item_id: string | number;
  due_date: string;
};

export type PickupLocation = {
  library_id: string;
  name: string;
  pickup_items?: Array<string | number>;
};

export type CirculationRule = {
  maxPeriod?: number;
  issuelength?: number;
  leadTime?: number;
  leadTimeToday?: boolean;
  calculated_due_date?: string;
  calculated_period_days?: number;
  booking_constraint_mode?: 'range' | 'end_date_only';
};

export type MarkerType = 'booked' | 'checked-out' | 'lead' | 'trail';

export type Marker = {
  type: MarkerType;
  barcode?: string;
  external_id?: string;
  itemnumber?: string | number;
};

export type AvailabilityResult = {
  disable: (date: Date) => boolean;
  unavailableByDate: Record<string, Record<string, Set<string>>>;
};

export type BookingStoreLike = {
  selectedDateRange?: string[];
  circulationRules?: CirculationRule[];
  bookings?: Booking[];
  checkouts?: Checkout[];
  bookableItems?: BookableItem[];
  bookingItemId?: string | number | null;
  bookingId?: string | number | null;
  unavailableByDate?: Record<string, Record<string, Set<string>>>;
};

export type BookingStoreActions = {
  fetchPickupLocations: (biblionumber: string | number, patronId: string | number) => Promise<unknown>;
  invalidateCalculatedDue: () => void;
  fetchCirculationRules: (params: Record<string, unknown>) => Promise<unknown>;
};
