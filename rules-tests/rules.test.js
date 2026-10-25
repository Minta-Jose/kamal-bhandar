import { readFileSync } from "node:fs";
import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";
import { assertFails, assertSucceeds, initializeTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, query, where, serverTimestamp } from "firebase/firestore";
import { ref, uploadString, getBytes } from "firebase/storage";

let env;

const address = { line1: "12 MG Road", line2: "", landmark: "", city: "Kolkata", state: "West Bengal", pincode: "700091" };
const profile = (status) => ({ firstName: "Ravi", lastName: "Kumar", mobile: "+919876543210", address, status, role: null });
const product = { name: "Rice", categoryId: "grains", sellModes: [{ mode: "weight", min: 250, step: 250, max: 10000, pricePaise: 6000 }], inStock: true, active: true };

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-kamal-bhandar",
    firestore: { rules: readFileSync("../firestore.rules", "utf8"), host: "127.0.0.1", port: 8080 },
    storage: { rules: readFileSync("../storage.rules", "utf8"), host: "127.0.0.1", port: 9199 },
  });
});
afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users/approved"), profile("approved"));
    await setDoc(doc(db, "users/pending"), profile("pending"));
    await setDoc(doc(db, "users/blocked"), profile("blocked"));
    await setDoc(doc(db, "products/rice"), { ...product, updatedAt: new Date() });
    await setDoc(doc(db, "orders/o1"), { uid: "approved", status: "placed", items: [] });
    await setDoc(doc(db, "orders/o2"), { uid: "someoneElse", status: "placed", items: [] });
    await setDoc(doc(db, "settings/store"), { showPrices: false });
    await setDoc(doc(db, "counters/orders"), { next: 5 });
  });
});

const as = (uid, claims = {}) => env.authenticatedContext(uid, claims).firestore();
const owner = () => as("owner1", { owner: true });

describe("users", () => {
  it("lets a customer read only their own profile", async () => {
    await assertSucceeds(getDoc(doc(as("pending"), "users/pending")));
    await assertFails(getDoc(doc(as("pending"), "users/approved")));
    await assertSucceeds(getDoc(doc(owner(), "users/pending")));
  });
  it("never lets the phone create a profile or set its own status or role", async () => {
    await assertFails(setDoc(doc(as("newbie"), "users/newbie"), profile("approved")));
    await assertFails(updateDoc(doc(as("pending"), "users/pending"), { status: "approved" }));
    await assertFails(updateDoc(doc(as("approved"), "users/approved"), { role: "owner" }));
    await assertFails(updateDoc(doc(as("approved"), "users/approved"), { mobile: "+919999999999" }));
  });
  it("lets an approved customer fix their name and address", async () => {
    await assertSucceeds(updateDoc(doc(as("approved"), "users/approved"), { firstName: "Ravindra", address: { ...address, line2: "Sector 5" } }));
    await assertFails(updateDoc(doc(as("approved"), "users/approved"), { address: { ...address, pincode: "123" } }));
    await assertFails(updateDoc(doc(as("pending"), "users/pending"), { firstName: "X" }));
  });
  it("lets a user register their own phone for notifications", async () => {
    await assertSucceeds(setDoc(doc(as("pending"), "users/pending/devices/tok1"), { platform: "android", updatedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(as("pending"), "users/approved/devices/tok1"), { platform: "android", updatedAt: serverTimestamp() }));
  });
});

describe("catalogue", () => {
  it("is visible to approved customers and the owner only", async () => {
    await assertSucceeds(getDoc(doc(as("approved"), "products/rice")));
    await assertSucceeds(getDoc(doc(owner(), "products/rice")));
    await assertFails(getDoc(doc(as("pending"), "products/rice")));
    await assertFails(getDoc(doc(as("blocked"), "products/rice")));
  });
  it("is written only by the owner, with a server time stamp", async () => {
    await assertFails(setDoc(doc(as("approved"), "products/dal"), { ...product, updatedAt: serverTimestamp() }));
    await assertSucceeds(setDoc(doc(owner(), "products/dal"), { ...product, updatedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(owner(), "products/dal2"), { ...product, updatedAt: new Date(2020, 1, 1) }));
  });
});

describe("carts", () => {
  const cart = { items: [{ productId: "rice", mode: "weight", qty: 500 }], updatedAt: serverTimestamp() };
  it("belongs to the approved customer alone", async () => {
    await assertSucceeds(setDoc(doc(as("approved"), "carts/approved"), cart));
    await assertFails(setDoc(doc(as("approved"), "carts/pending"), cart));
    await assertFails(setDoc(doc(as("pending"), "carts/pending"), cart));
    await assertFails(getDoc(doc(owner(), "carts/approved")));
  });
});

describe("orders", () => {
  it("are read-only for customers and limited to their own", async () => {
    await assertSucceeds(getDoc(doc(as("approved"), "orders/o1")));
    await assertFails(getDoc(doc(as("approved"), "orders/o2")));
    await assertSucceeds(getDocs(query(collection(as("approved"), "orders"), where("uid", "==", "approved"))));
    await assertFails(getDocs(collection(as("approved"), "orders")));
    await assertFails(updateDoc(doc(as("approved"), "orders/o1"), { status: "cancelled" }));
    await assertFails(setDoc(doc(as("approved"), "orders/o3"), { uid: "approved", status: "placed" }));
    await assertFails(deleteDoc(doc(as("approved"), "orders/o1")));
  });
  it("can be read but not written directly by the owner", async () => {
    await assertSucceeds(getDocs(collection(owner(), "orders")));
    await assertFails(updateDoc(doc(owner(), "orders/o1"), { status: "ready" }));
  });
  it("cannot be read by a customer who is no longer approved", async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), "orders/o4"), { uid: "blocked", status: "placed" }));
    await assertFails(getDoc(doc(as("blocked"), "orders/o4")));
  });
});

describe("store data", () => {
  it("keeps counters and audit log away from customers", async () => {
    await assertFails(getDoc(doc(as("approved"), "counters/orders")));
    await assertSucceeds(getDoc(doc(owner(), "counters/orders")));
    await assertFails(setDoc(doc(owner(), "counters/orders"), { next: 1 }));
  });
  it("lets everyone signed in read settings but only the owner change them", async () => {
    await assertSucceeds(getDoc(doc(as("pending"), "settings/store")));
    await assertFails(updateDoc(doc(as("approved"), "settings/store"), { showPrices: true }));
    await assertSucceeds(updateDoc(doc(owner(), "settings/store"), { showPrices: true }));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), "settings/store")));
  });
});

describe("photos", () => {
  // The storage emulator reads the uid from user_id, which the test tokens leave out.
  const st = (uid, claims = {}) => env.authenticatedContext(uid, { ...claims, user_id: uid }).storage();
  it("are uploaded only by the owner, as images", async () => {
    await assertSucceeds(uploadString(ref(st("owner1", { owner: true }), "products/rice/main.webp"), "abc", "raw", { contentType: "image/webp" }));
    await assertFails(uploadString(ref(st("owner1", { owner: true }), "products/rice/evil.html"), "abc", "raw", { contentType: "text/html" }));
    await assertFails(uploadString(ref(st("approved"), "products/rice/main.webp"), "abc", "raw", { contentType: "image/webp" }));
  });
  it("are visible to approved customers", async () => {
    await env.withSecurityRulesDisabled((ctx) => uploadString(ref(ctx.storage(), "products/rice/thumb.webp"), "abc", "raw", { contentType: "image/webp" }));
    await assertSucceeds(getBytes(ref(st("approved"), "products/rice/thumb.webp")));
    await assertFails(getBytes(ref(st("pending"), "products/rice/thumb.webp")));
  });
});
