import { describe, expect, it } from "vitest";
import { Product, SellMode } from "../src/lib/model";
import { checkQuantity, isValidSellMode, lineTotalPaise, priceCart, unitLabel } from "../src/lib/quantity";

const weight: SellMode = { mode: "weight", min: 25, step: 25, max: 50000, pricePaise: 12000 };
const piece: SellMode = { mode: "piece", min: 1, step: 1, max: 50, pricePaise: 1000 };
const bag: SellMode = { mode: "bag", min: 1, step: 1, max: 20, bagSizeKg: 50, pricePaise: 220000 };

const rice: Product = { name: "Basmati rice", categoryId: "grains", sellModes: [weight, bag], inStock: true, active: true };
const eggs: Product = { name: "Eggs", categoryId: "dairy", sellModes: [piece], inStock: true, active: true };

describe("unitLabel", () => {
  it("shows grams below a kilo and kilos above", () => {
    expect(unitLabel(weight, 25)).toBe("25 g");
    expect(unitLabel(weight, 1000)).toBe("1 kg");
    expect(unitLabel(weight, 2500)).toBe("2.5 kg");
  });
  it("shows pieces and bags", () => {
    expect(unitLabel(piece, 1)).toBe("1 pc");
    expect(unitLabel(piece, 6)).toBe("6 pcs");
    expect(unitLabel(bag, 2)).toBe("2 bags × 50 kg");
  });
});

describe("checkQuantity", () => {
  it("accepts quantities on the step", () => {
    expect(checkQuantity(weight, 25)).toBeNull();
    expect(checkQuantity(weight, 1250)).toBeNull();
  });
  it("refuses below min, above max, off-step and fractions", () => {
    expect(checkQuantity(weight, 10)).toMatch(/Minimum/);
    expect(checkQuantity(weight, 60000)).toMatch(/Maximum/);
    expect(checkQuantity(weight, 30)).toMatch(/steps/);
    expect(checkQuantity(piece, 1.5)).toMatch(/whole/);
    expect(checkQuantity(piece, 0)).toMatch(/whole/);
  });
});

describe("lineTotalPaise", () => {
  it("prices weight per kg and rounds to whole paise", () => {
    expect(lineTotalPaise(weight, 250)).toBe(3000);
    expect(lineTotalPaise({ ...weight, pricePaise: 999 }, 25)).toBe(25);
  });
  it("prices pieces and bags per unit", () => {
    expect(lineTotalPaise(piece, 6)).toBe(6000);
    expect(lineTotalPaise(bag, 2)).toBe(440000);
  });
});

describe("isValidSellMode", () => {
  it("needs a bag size for bags", () => {
    expect(isValidSellMode(bag)).toBe(true);
    expect(isValidSellMode({ ...bag, bagSizeKg: undefined })).toBe(false);
    expect(isValidSellMode({ ...weight, min: 0 })).toBe(false);
    expect(isValidSellMode({ ...weight, mode: "litre" })).toBe(false);
  });
});

describe("priceCart", () => {
  const products = new Map([["rice", rice], ["eggs", eggs], ["old", { ...eggs, active: false }], ["oos", { ...eggs, inStock: false }]]);

  it("builds order lines with snapshots of name and price", () => {
    const r = priceCart([{ productId: "rice", mode: "weight", qty: 500 }, { productId: "rice", mode: "bag", qty: 1 }, { productId: "eggs", mode: "piece", qty: 12 }], products);
    expect(r.problems).toEqual([]);
    expect(r.lines.map((l) => l.unitLabel)).toEqual(["500 g", "1 bag × 50 kg", "12 pcs"]);
    expect(r.lines[1].bagSizeKg).toBe(50);
    expect(r.totalPaise).toBe(6000 + 220000 + 12000);
  });

  it("reports every line it cannot order", () => {
    const r = priceCart([
      { productId: "missing", mode: "piece", qty: 1 },
      { productId: "old", mode: "piece", qty: 1 },
      { productId: "oos", mode: "piece", qty: 1 },
      { productId: "eggs", mode: "weight", qty: 100 },
      { productId: "rice", mode: "weight", qty: 30 },
      { productId: "eggs", mode: "piece", qty: 2 },
      { productId: "eggs", mode: "piece", qty: 3 },
    ], products);
    expect(r.problems).toHaveLength(6);
    expect(r.lines).toHaveLength(1);
  });
});
