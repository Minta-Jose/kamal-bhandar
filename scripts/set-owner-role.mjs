// Gives a Google account the owner role. Run once per owner phone account:
//   GOOGLE_APPLICATION_CREDENTIALS=key.json node scripts/set-owner-role.mjs owner@gmail.com
// The owner then signs out and in again in the app.
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const email = process.argv[2];
const remove = process.argv.includes("--remove");
if (!email) {
  console.error("Usage: node scripts/set-owner-role.mjs <google-email> [--remove]");
  process.exit(1);
}

initializeApp({ credential: applicationDefault() });
const user = await getAuth().getUserByEmail(email).catch(() => null);
if (!user) {
  console.error(`${email} has not signed in to the app yet. Open the app, sign in with Google once, then run this again.`);
  process.exit(1);
}

await getAuth().setCustomUserClaims(user.uid, remove ? {} : { owner: true });
const ref = getFirestore().doc(`users/${user.uid}`);
if (remove) {
  await ref.set({ role: null }, { merge: true });
} else {
  const name = (user.displayName ?? "Store owner").split(" ");
  await ref.set(
    {
      firstName: name[0],
      lastName: name.slice(1).join(" ") || "Owner",
      email,
      role: "owner",
      status: "approved",
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}
console.log(`${email} ${remove ? "is no longer an owner" : "is now an owner"}. Sign out and in again in the app.`);
