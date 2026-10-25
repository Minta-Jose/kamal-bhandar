import { OrderLine, OrderStatus, PaymentMethod, SellMode } from "./model";
import { lineTotalPaise, sumTotals, unitLabel } from "./quantity";

/** Moves the owner may make with setOrderStatus. Adjusting goes through adjustOrder. */
const allowedMoves: Record<OrderStatus, OrderStatus[]> = {
  placed: ["ready", "cancelled"],
  adjusted: ["ready", "cancelled"],
  ready: ["picked_up", "cancelled"],
  picked_up: [],
  cancelled: [],
};

export function canMove(from: OrderStatus, to: OrderStatus): boolean {
  return allowedMoves[from]?.includes(to) ?? false;
}

/** Orders that can still have their items changed by the owner. */
export function canAdjust(status: OrderStatus): boolean {
  return status === "placed" || status === "adjusted" || status === "ready";
}

export const paymentMethods: PaymentMethod[] = ["cash", "upi", "card"];

export function isPaymentMethod(v: unknown): v is PaymentMethod {
  return paymentMethods.includes(v as PaymentMethod);
}

export interface LineChange {
  productId: string;
  mode: string;
  /** New quantity in the base unit; 0 removes the line. */
  qty: number;
}

export interface AdjustResult {
  lines: OrderLine[];
  totalPaise: number;
  changed: boolean;
}

/**
 * Applies the owner's changes to an order's lines. The owner may set any whole
 * quantity (for example 900 g when only that much is left), so min and step are
 * not enforced here. Prices stay as they were when the order was placed.
 */
export function applyAdjustments(lines: OrderLine[], changes: LineChange[]): AdjustResult {
  const byKey = new Map(changes.map((c) => [`${c.productId}:${c.mode}`, c]));
  for (const c of changes) {
    if (!Number.isInteger(c.qty) || c.qty < 0) {
      throw new Error(`Invalid quantity for ${c.productId}`);
    }
    if (!lines.some((l) => l.productId === c.productId && l.mode === c.mode)) {
      throw new Error(`Item ${c.productId} is not in this order`);
    }
  }

  let changed = false;
  const out: OrderLine[] = [];
  for (const line of lines) {
    const change = byKey.get(`${line.productId}:${line.mode}`);
    if (!change || change.qty === line.qty) {
      out.push(line);
      continue;
    }
    changed = true;
    if (change.qty === 0) continue;
    const mode: SellMode = {
      mode: line.mode,
      min: 1,
      step: 1,
      max: change.qty,
      bagSizeKg: line.bagSizeKg,
      pricePaise: line.pricePaise,
    };
    out.push({
      ...line,
      qty: change.qty,
      unitLabel: unitLabel(mode, change.qty),
      lineTotalPaise: lineTotalPaise(mode, change.qty),
      adjusted: true,
    });
  }

  if (changed && out.length === 0) {
    throw new Error("An order needs at least one item; cancel it instead");
  }
  return { lines: out, totalPaise: sumTotals(out), changed };
}

/** KB-2026-000123 */
export function formatOrderNo(year: number, n: number): string {
  return `KB-${year}-${String(n).padStart(6, "0")}`;
}

/** Year in India time, so order numbers restart at midnight IST on 1 January. */
export function istYear(date: Date): number {
  return new Date(date.getTime() + 5.5 * 3600 * 1000).getUTCFullYear();
}
