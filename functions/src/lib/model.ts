// Shared shapes for Firestore documents. Quantities are whole numbers in a
// base unit (grams, pieces or bags) and money is whole paise.

export type SellModeKind = "weight" | "piece" | "bag";

export interface SellMode {
  mode: SellModeKind;
  /** Smallest allowed quantity, in the base unit. */
  min: number;
  /** Quantities must be min + n * step. */
  step: number;
  /** Largest allowed quantity in one order line. */
  max: number;
  /** Only for bags: weight of one bag in kg. */
  bagSizeKg?: number;
  /** Price per kg for weight, per piece, or per bag. */
  pricePaise: number;
}

export interface Product {
  name: string;
  nameHi?: string;
  categoryId: string;
  sellModes: SellMode[];
  inStock: boolean;
  active: boolean;
}

export interface CartLine {
  productId: string;
  mode: SellModeKind;
  qty: number;
}

export interface OrderLine {
  productId: string;
  name: string;
  mode: SellModeKind;
  qty: number;
  unitLabel: string;
  bagSizeKg?: number;
  pricePaise: number;
  lineTotalPaise: number;
  adjusted: boolean;
}

export type UserStatus = "pending" | "approved" | "rejected" | "blocked";

export type OrderStatus =
  | "placed"
  | "adjusted"
  | "ready"
  | "picked_up"
  | "cancelled";

export type PaymentMethod = "cash" | "upi" | "card";

export interface Address {
  line1: string;
  line2: string;
  landmark: string;
  city: string;
  state: string;
  pincode: string;
}
