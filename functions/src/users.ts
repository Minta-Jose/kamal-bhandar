import { getAuth } from "firebase-admin/auth";
import { FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { asHttpsError, audit, callableOptions, db, requireOwner, requireSignedIn } from "./common";
import { UserStatus } from "./lib/model";
import { validateProfile } from "./lib/validation";
import { sendTo, sendToOwners } from "./notify";

/** Saves a new customer's details as pending. A rejected customer may apply again. */
export const registerProfile = onCall(callableOptions, async (req) => {
  const { uid } = requireSignedIn(req);
  try {
    const p = validateProfile(req.data);
    const ref = db.doc(`users/${uid}`);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const status = snap.get("status") as UserStatus | undefined;
      if (status === "approved" || status === "pending") {
        throw new HttpsError("already-exists", "You are already registered");
      }
      if (status === "blocked") {
        throw new HttpsError("permission-denied", "This account has been blocked by the store");
      }
      tx.set(ref, {
        firstName: p.firstName,
        lastName: p.lastName,
        mobile: `+91${p.mobile}`,
        address: p.address,
        email: req.auth?.token.email ?? null,
        status: "pending",
        rejectReason: null,
        consent: { version: p.consentVersion, at: FieldValue.serverTimestamp() },
        createdAt: snap.exists ? snap.get("createdAt") : FieldValue.serverTimestamp(),
        approvedAt: null,
        approvedBy: null,
      });
    });
    return { status: "pending" };
  } catch (e) {
    asHttpsError(e);
  }
});

/** Tells the owner when someone is waiting for approval. */
export const onUserPending = onDocumentWritten("users/{uid}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!after || after.status !== "pending" || before?.status === "pending") return;
  const area = after.address?.line2 || after.address?.city || "";
  await sendToOwners({
    title: "New sign-up",
    body: `${after.firstName} ${after.lastName}${area ? `, ${area}` : ""} is waiting for approval`,
    channel: "sign_ups",
    route: "/owner/customers",
  });
});

const ownerSettable: UserStatus[] = ["approved", "rejected", "blocked"];

export const setUserStatus = onCall(callableOptions, async (req) => {
  const owner = requireOwner(req);
  const uid = String(req.data?.uid ?? "");
  const status = req.data?.status as UserStatus;
  const reason = typeof req.data?.reason === "string" ? req.data.reason.trim().slice(0, 200) : "";
  if (!uid || !ownerSettable.includes(status)) {
    throw new HttpsError("invalid-argument", "Choose approve, reject or block");
  }
  if (uid === owner.uid) throw new HttpsError("invalid-argument", "You cannot change your own account");

  const ref = db.doc(`users/${uid}`);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Customer not found");
  const before = snap.get("status");

  await ref.update({
    status,
    rejectReason: status === "approved" ? null : reason || null,
    ...(status === "approved"
      ? { approvedAt: FieldValue.serverTimestamp(), approvedBy: owner.uid }
      : {}),
  });
  await audit(owner.uid, "setUserStatus", `users/${uid}`, { status: before }, { status, reason });

  if (status === "blocked") {
    // Signs the customer out of every phone; the rules already refuse their reads.
    await getAuth().revokeRefreshTokens(uid);
  } else {
    await sendTo([uid], {
      title: status === "approved" ? "Welcome to Kamal Bhandar" : "Registration not approved",
      body:
        status === "approved"
          ? "Your account is approved. You can start ordering now."
          : reason || "The store could not approve your registration. Please contact the store.",
      channel: "account",
      route: "/",
    });
  }
  return { status };
});

/**
 * Removes the customer's profile, cart and devices, and anonymises their orders
 * (kept for the store's accounts) before deleting the sign-in account.
 */
export const deleteAccount = onCall(callableOptions, async (req) => {
  const { uid, isOwner } = requireSignedIn(req);
  if (isOwner) throw new HttpsError("failed-precondition", "The owner account cannot be deleted from the app");

  const devices = await db.collection(`users/${uid}/devices`).get();
  const orders = await db.collection("orders").where("uid", "==", uid).get();

  const writer = db.bulkWriter();
  devices.forEach((d) => writer.delete(d.ref));
  orders.forEach((o) =>
    writer.update(o.ref, {
      uid: null,
      customer: { name: "Deleted customer", mobile: null, address: null },
      updatedAt: FieldValue.serverTimestamp(),
    }),
  );
  writer.delete(db.doc(`carts/${uid}`));
  writer.delete(db.doc(`users/${uid}`));
  await writer.close();

  await audit(uid, "deleteAccount", `users/${uid}`, null, { orders: orders.size });
  await getAuth().deleteUser(uid);
  return { deleted: true };
});
