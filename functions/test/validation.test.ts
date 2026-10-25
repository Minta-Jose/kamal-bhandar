import { describe, expect, it } from "vitest";
import { normaliseMobile, validateProfile } from "../src/lib/validation";

const good = {
  firstName: " Ravi ", lastName: "Kumar", mobile: "+91 98765 43210", consentVersion: "2026-10",
  address: { line1: "12 MG Road", line2: "Salt Lake", landmark: "", city: "Kolkata", state: "West Bengal", pincode: "700091" },
};

describe("validateProfile", () => {
  it("cleans a good profile", () => {
    const p = validateProfile(good);
    expect(p.firstName).toBe("Ravi");
    expect(p.mobile).toBe("9876543210");
  });
  it("accepts Hindi names", () => {
    expect(validateProfile({ ...good, firstName: "रवि" }).firstName).toBe("रवि");
  });
  it.each([
    ["mobile", { mobile: "5876543210" }],
    ["mobile", { mobile: "98765" }],
    ["firstName", { firstName: "" }],
    ["firstName", { firstName: "R2D2" }],
    ["lastName", { lastName: "x".repeat(51) }],
    ["address.pincode", { address: { ...good.address, pincode: "07009" } }],
    ["address.line1", { address: { ...good.address, line1: "" } }],
    ["consent", { consentVersion: "" }],
  ])("rejects a bad %s", (field, patch) => {
    expect(() => validateProfile({ ...good, ...patch })).toThrow();
    try { validateProfile({ ...good, ...patch }); } catch (e) { expect((e as { field: string }).field).toBe(field); }
  });
});

describe("normaliseMobile", () => {
  it("strips country code and leading zero", () => {
    expect(normaliseMobile("919876543210")).toBe("9876543210");
    expect(normaliseMobile("09876543210")).toBe("9876543210");
    expect(normaliseMobile("98765-43210")).toBe("9876543210");
  });
});
