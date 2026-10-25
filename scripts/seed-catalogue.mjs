// Adds starter categories and products (without photos) and the store settings,
// so the shop is not empty on day one. Safe to run again: it only fills gaps.
//   GOOGLE_APPLICATION_CREDENTIALS=key.json node scripts/seed-catalogue.mjs
import { readFileSync } from "node:fs";
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

initializeApp({ credential: applicationDefault() });
const db = getFirestore();
const seed = JSON.parse(readFileSync(new URL("./starter-catalogue.json", import.meta.url), "utf8"));

let added = 0;
for (const [i, c] of seed.categories.entries()) {
  const ref = db.doc(`categories/${c.id}`);
  if (!(await ref.get()).exists) {
    await ref.set({ name: c.name, nameHi: c.nameHi, sortOrder: i * 10, active: true, imageUrl: null, updatedAt: FieldValue.serverTimestamp() });
    added++;
  }
  for (const p of c.products) {
    const pref = db.doc(`products/${p.id}`);
    if ((await pref.get()).exists) continue;
    await pref.set({
      name: p.name,
      nameHi: p.nameHi ?? "",
      description: "",
      categoryId: c.id,
      keywords: p.keywords ?? [],
      sellModes: p.sellModes,
      inStock: true,
      active: true,
      imageUrl: null,
      thumbUrl: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    added++;
  }
}

const settings = db.doc("settings/store");
if (!(await settings.get()).exists) {
  await settings.set({ storeName: "Kamal Bhandar", showPrices: false, pickupHours: "", storeAddress: "", storePhone: "", grievanceContact: "", minAppVersion: 0 });
  added++;
}
console.log(`Added ${added} documents. Set real prices and photos in the app's Catalogue tab.`);
