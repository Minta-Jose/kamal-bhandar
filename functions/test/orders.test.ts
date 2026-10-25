import { describe, expect, it } from "vitest";
import { OrderLine } from "../src/lib/model";
import { applyAdjustments, canAdjust, canMove, formatOrderNo, istYear } from "../src/lib/orders";

const lines: OrderLine[] = [
  { productId: "rice", name: "Rice", mode: "weight", qty: 1000, unitLabel: "1 kg", pricePaise: 6000, lineTotalPaise: 6000, adjusted: false },
  { productId: "atta", name: "Atta", mode: "bag", qty: 2, unitLabel: "2 bags × 10 kg", bagSizeKg: 10, pricePaise: 45000, lineTotalPaise: 90000, adjusted: false },
];

describe("status moves", () => {
  it("allows only the planned steps", () => {
    expect(canMove("placed", "ready")).toBe(true);
    expect(canMove("ready", "picked_up")).toBe(true);
    expect(canMove("placed", "picked_up")).toBe(false);
    expect(canMove("picked_up", "cancelled")).toBe(false);
    expect(canMove("cancelled", "placed")).toBe(false);
    expect(canMove("placed", "adjusted")).toBe(false);
  });
  it("lets the owner adjust until pickup", () => {
    expect(canAdjust("ready")).toBe(true);
    expect(canAdjust("picked_up")).toBe(false);
    expect(canAdjust("cancelled")).toBe(false);
  });
});

describe("applyAdjustments", () => {
  it("changes quantities, marks lines and recalculates the total", () => {
    const r = applyAdjustments(lines, [{ productId: "rice", mode: "weight", qty: 900 }]);
    expect(r.changed).toBe(true);
    expect(r.lines[0]).toMatchObject({ qty: 900, unitLabel: "900 g", lineTotalPaise: 5400, adjusted: true });
    expect(r.lines[1].adjusted).toBe(false);
    expect(r.totalPaise).toBe(5400 + 90000);
  });
  it("removes a line at zero and keeps bag labels", () => {
    const r = applyAdjustments(lines, [{ productId: "rice", mode: "weight", qty: 0 }, { productId: "atta", mode: "bag", qty: 1 }]);
    expect(r.lines).toHaveLength(1);
    expect(r.lines[0].unitLabel).toBe("1 bag × 10 kg");
    expect(r.totalPaise).toBe(45000);
  });
  it("refuses unknown items, bad quantities and emptying the order", () => {
    expect(() => applyAdjustments(lines, [{ productId: "dal", mode: "weight", qty: 1 }])).toThrow(/not in this order/);
    expect(() => applyAdjustments(lines, [{ productId: "rice", mode: "weight", qty: -1 }])).toThrow(/Invalid/);
    expect(() => applyAdjustments(lines, [{ productId: "rice", mode: "weight", qty: 0 }, { productId: "atta", mode: "bag", qty: 0 }])).toThrow(/cancel/);
  });
  it("reports no change when quantities are the same", () => {
    expect(applyAdjustments(lines, [{ productId: "rice", mode: "weight", qty: 1000 }]).changed).toBe(false);
  });
});

describe("order numbers", () => {
  it("pads and uses the India year", () => {
    expect(formatOrderNo(2026, 123)).toBe("KB-2026-000123");
    expect(istYear(new Date("2026-12-31T19:00:00Z"))).toBe(2027);
    expect(istYear(new Date("2026-12-31T18:00:00Z"))).toBe(2026);
  });
});
