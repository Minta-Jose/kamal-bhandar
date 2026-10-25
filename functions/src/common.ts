import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import { defineBoolean } from "firebase-functions/params";
import { CallableOptions, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { ValidationError } from "./lib/validation";

if (getApps().length === 0) initializeApp();

export const region = "asia-south1";
setGlobalOptions({ region, maxInstances: 5 });

export const db = getFirestore();

/**
 * App Check's Play Integrity check only recognises apps installed from the Play
 * Store, so it stays off while the app file is shared directly (version 1).
 * Set ENFORCE_APP_CHECK=true in functions/.env.<project> after the Play Store launch.
 */
const enforceAppCheck = defineBoolean("ENFORCE_APP_CHECK", { default: false });

export const callableOptions: CallableOptions = {
  enforceAppCheck,
  cors: false,
};

export interface Caller {
  uid: string;
  isOwner: boolean;
}

export function requireSignedIn(req: CallableRequest): Caller {
  if (!req.auth) throw new HttpsError("unauthenticated", "Please sign in");
  return { uid: req.auth.uid, isOwner: req.auth.token.owner === true };
}

export function requireOwner(req: CallableRequest): Caller {
  const caller = requireSignedIn(req);
  if (!caller.isOwner) throw new HttpsError("permission-denied", "Only the store owner can do this");
  return caller;
}

export async function requireApprovedCustomer(req: CallableRequest): Promise<Caller> {
  const caller = requireSignedIn(req);
  const snap = await db.doc(`users/${caller.uid}`).get();
  if (snap.get("status") !== "approved") {
    throw new HttpsError("permission-denied", "Your account is not approved yet");
  }
  return caller;
}

/** Turns validation problems into a message the app can show next to the field. */
export function asHttpsError(e: unknown): never {
  if (e instanceof HttpsError) throw e;
  if (e instanceof ValidationError) {
    throw new HttpsError("invalid-argument", e.message, { field: e.field });
  }
  if (e instanceof Error) throw new HttpsError("failed-precondition", e.message);
  throw new HttpsError("internal", "Something went wrong");
}

export async function audit(
  actorUid: string,
  action: string,
  target: string,
  before: unknown,
  after: unknown,
): Promise<void> {
  await db.collection("auditLog").add({
    actorUid,
    action,
    target,
    before: before ?? null,
    after: after ?? null,
    at: FieldValue.serverTimestamp(),
  });
}
