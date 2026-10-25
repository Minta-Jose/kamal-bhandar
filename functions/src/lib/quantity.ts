import { CartLine, OrderLine, Product, SellMode, SellModeKind } from "./model";

/** Human label for a quantity, e.g. "250 g", "2.5 kg", "3 pcs", "2 bags × 50 kg". */
export function unitLabel(mode: SellMode, qty: number): string {
  switch (mode.mode) {
    case "weight":
      if (qty < 1000) return `${qty} g`;
      return `${trimNumber(qty / 1000)} kg`;
    case "piece":
      return qty === 1 ? "1 pc" : `${qty} pcs`;
    case "bag":
      return `${qty} ${qty === 1 ? "bag" : "bags"} × ${trimNumber(mode.bagSizeKg ?? 0)} kg`;
  }
}

function trimNumber(n: number): string {
  return Number.isInteger(n) ? String(n) : String(Math.round(n * 1000) / 1000);
}

/** Returns null when the quantity is allowed, otherwise a reason. */
export function checkQuantity(mode: SellMode, qty: number): string | null {
  if (!Number.isInteger(qty) || qty <= 0) return "Quantity must be a whole positive number";
  if (qty < mode.min) return `Minimum is ${unitLabel(mode, mode.min)}`;
  if (qty > mode.max) return `Maximum is ${unitLabel(mode, mode.max)}`;
  if (mode.step > 0 && (qty - mode.min) % mode.step !== 0) {
    return `Must be in steps of ${unitLabel(mode, mode.step)}`;
  }
  return null;
}

/** Line total in paise. Weight prices are per kg, others per piece or bag. */
export function lineTotalPaise(mode: SellMode, qty: number): number {
  if (mode.mode === "weight") return Math.round((mode.pricePaise * qty) / 1000);
  return mode.pricePaise * qty;
}

export function findMode(product: Product, kind: SellModeKind): SellMode | undefined {
  return product.sellModes.find((m) => m.mode === kind);
}

export function isValidSellMode(m: unknown): m is SellMode {
  if (typeof m !== "object" || m === null) return false;
  const s = m as Record<string, unknown>;
  const ints = ["min", "step", "max", "pricePaise"].every(
    (k) => Number.isInteger(s[k]) && (s[k] as number) >= 0,
  );
  if (!ints || !["weight", "piece", "bag"].includes(s.mode as string)) return false;
  if ((s.min as number) <= 0 || (s.max as number) < (s.min as number)) return false;
  if (s.mode === "bag" && !(typeof s.bagSizeKg === "number" && s.bagSizeKg > 0)) return false;
  return true;
}

export interface PricedCart {
  lines: OrderLine[];
  totalPaise: number;
  problems: { productId: string; reason: string }[];
}

/**
 * Turns cart lines into order lines using the current product data. Nothing is
 * dropped silently: every line that cannot be ordered is listed in problems.
 */
export function priceCart(
  cart: CartLine[],
  products: Map<string, Product>,
): PricedCart {
  const lines: OrderLine[] = [];
  const problems: PricedCart["problems"] = [];
  const seen = new Set<string>();

  for (const item of cart) {
    const key = `${item.productId}:${item.mode}`;
    if (seen.has(key)) {
      problems.push({ productId: item.productId, reason: "Listed twice in the cart" });
      continue;
    }
    seen.add(key);

    const product = products.get(item.productId);
    if (!product || !product.active) {
      problems.push({ productId: item.productId, reason: "No longer sold" });
      continue;
    }
    if (!product.inStock) {
      problems.push({ productId: item.productId, reason: `${product.name} is out of stock` });
      continue;
    }
    const mode = findMode(product, item.mode);
    if (!mode) {
      problems.push({ productId: item.productId, reason: `${product.name} is not sold this way` });
      continue;
    }
    const qtyProblem = checkQuantity(mode, item.qty);
    if (qtyProblem) {
      problems.push({ productId: item.productId, reason: `${product.name}: ${qtyProblem}` });
      continue;
    }
    lines.push({
      productId: item.productId,
      name: product.name,
      mode: item.mode,
      qty: item.qty,
      unitLabel: unitLabel(mode, item.qty),
      ...(mode.mode === "bag" ? { bagSizeKg: mode.bagSizeKg } : {}),
      pricePaise: mode.pricePaise,
      lineTotalPaise: lineTotalPaise(mode, item.qty),
      adjusted: false,
    });
  }

  return { lines, totalPaise: sumTotals(lines), problems };
}

export function sumTotals(lines: OrderLine[]): number {
  return lines.reduce((sum, l) => sum + l.lineTotalPaise, 0);
}
