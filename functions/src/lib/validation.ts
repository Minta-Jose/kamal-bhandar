import { Address } from "./model";

export interface ProfileInput {
  firstName: string;
  lastName: string;
  mobile: string;
  address: Address;
  consentVersion: string;
}

export class ValidationError extends Error {
  constructor(public readonly field: string, message: string) {
    super(message);
  }
}

// Letters in any script (so Hindi names work), with spaces, dots, hyphens and apostrophes.
const nameRe = /^[\p{L}\p{M}][\p{L}\p{M} .'-]{0,49}$/u;
const mobileRe = /^[6-9]\d{9}$/;
const pincodeRe = /^[1-9]\d{5}$/;

function str(v: unknown): string {
  return typeof v === "string" ? v.trim().replace(/\s+/g, " ") : "";
}

/** Accepts "98765 43210", "+91 98765-43210" or "098765..." and returns the 10 digits. */
export function normaliseMobile(v: unknown): string {
  let digits = typeof v === "string" ? v.replace(/[\s()-]/g, "") : "";
  if (digits.startsWith("+91")) digits = digits.slice(3);
  else if (digits.length === 12 && digits.startsWith("91")) digits = digits.slice(2);
  else if (digits.length === 11 && digits.startsWith("0")) digits = digits.slice(1);
  return digits;
}

export function validateName(field: string, v: unknown): string {
  const s = str(v);
  if (!nameRe.test(s)) throw new ValidationError(field, "Use 1 to 50 letters");
  return s;
}

export function validateAddress(v: unknown): Address {
  const a = (typeof v === "object" && v !== null ? v : {}) as Record<string, unknown>;
  const line1 = str(a.line1);
  if (line1.length < 3 || line1.length > 120) {
    throw new ValidationError("address.line1", "Enter the house number and street");
  }
  const city = str(a.city);
  if (city.length < 2 || city.length > 60) throw new ValidationError("address.city", "Enter the city");
  const state = str(a.state);
  if (state.length < 2 || state.length > 60) throw new ValidationError("address.state", "Enter the state");
  const pincode = str(a.pincode);
  if (!pincodeRe.test(pincode)) throw new ValidationError("address.pincode", "Pincode must be 6 digits");
  const line2 = str(a.line2).slice(0, 120);
  const landmark = str(a.landmark).slice(0, 120);
  return { line1, line2, landmark, city, state, pincode };
}

export function validateProfile(input: unknown): ProfileInput {
  const d = (typeof input === "object" && input !== null ? input : {}) as Record<string, unknown>;
  const mobile = normaliseMobile(d.mobile);
  if (!mobileRe.test(mobile)) {
    throw new ValidationError("mobile", "Enter a 10-digit Indian mobile number starting with 6 to 9");
  }
  const consentVersion = str(d.consentVersion);
  if (!consentVersion) throw new ValidationError("consent", "Please accept the privacy policy");
  return {
    firstName: validateName("firstName", d.firstName),
    lastName: validateName("lastName", d.lastName),
    mobile,
    address: validateAddress(d.address),
    consentVersion,
  };
}
