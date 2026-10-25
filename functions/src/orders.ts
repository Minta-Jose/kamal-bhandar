import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import {
  asHttpsError,
  audit,
  callableOptions,
  db,
  requireApprovedCustomer,
  requireOwner,
} from "./common";
import { CartLine, OrderLine, OrderStatus, Product } from "./lib/model";
import {
  applyAdjustments,
  canAdjust,
  canMove,
  formatOrderNo,
  isPaymentMethod,
  istYear,
  LineChange,
} from "./lib/orders";
import { priceCart } from "./lib/quantity";
import { sendTo, sendToOwners } from "./notify";

const maxLines = 100;

/**
 * Turns the customer's saved cart into a locked order. Products and prices are
 * read again here, so what the phone shows cannot change what gets ordered.
 */
export const placeOrder = onCall(callableOptions, async (req) => {
  const { uid } = await requireApprovedCustomer(req);
  const note = typeof req.data?.note === "string" ? req.data.note.trim().slice(0, 300) : "";

  try {
    return await db.runTransaction(async (tx) => {
      const userRef = db.doc(`users/${uid}`);
      const cartRef = db.doc(`carts/${uid}`);
      const counterRef = db.doc("counters/orders");
      const [user, cart, counter] = await Promise.all([
        tx.get(userRef),
        tx.get(cartRef),
        tx.get(counterRef),
      ]);

      const items = (cart.get("items") ?? []) as CartLine[];
      if (items.length === 0) throw new HttpsError("failed-precondition", "Your cart is empty");
      if (items.length > maxLines) throw new HttpsError("failed-precondition", "Too many items in one order");

      const ids = [...new Set(items.map((i) => String(i.productId)))];
      const productSnaps = await tx.getAll(...ids.map((id) => db.doc(`products/${id}`)));
      const products = new Map<string, Product>();
      productSnaps.forEach((s) => {
        if (s.exists) products.set(s.id, s.data() as Product);
      });

      const priced = priceCart(items, products);
      if (priced.problems.length > 0) {
        // The app shows these so the customer can fix the cart; nothing is skipped silently.
        throw new HttpsError("failed-precondition", "Some items need attention", {
          problems: priced.problems,
        });
      }

      const now = Timestamp.now();
      const year = istYear(now.toDate());
      const next = counter.exists && counter.get("year") === year ? (counter.get("next") as number) : 1;
      const orderNo = formatOrderNo(year, next);
      const orderRef = db.collection("orders").doc();

      tx.set(counterRef, { year, next: next + 1 });
      tx.set(orderRef, {
        orderNo,
        uid,
        customer: {
          name: `${user.get("firstName")} ${user.get("lastName")}`,
          mobile: user.get("mobile"),
          address: user.get("address"),
        },
        items: priced.lines,
        totalPaise: priced.totalPaise,
        note,
        status: "placed",
        statusHistory: [{ status: "placed", by: uid, at: now, note: "" }],
        paymentMethod: null,
        placedAt: now,
        updatedAt: now,
      });
      tx.set(cartRef, { items: [], updatedAt: now });
      return { orderId: orderRef.id, orderNo };
    });
  } catch (e) {
    asHttpsError(e);
  }
});

export const onOrderCreated = onDocumentCreated("orders/{orderId}", async (event) => {
  const o = event.data?.data();
  if (!o) return;
  const count = (o.items as OrderLine[]).length;
  await sendToOwners({
    title: `New order ${o.orderNo}`,
    body: `${o.customer.name}, ${count} ${count === 1 ? "item" : "items"}`,
    channel: "new_orders",
    route: `/owner/orders/${event.params.orderId}`,
  });
});

/** Owner changes quantities or removes items on a confirmed order. */
export const adjustOrder = onCall(callableOptions, async (req) => {
  const owner = requireOwner(req);
  const orderId = String(req.data?.orderId ?? "");
  const changes = (Array.isArray(req.data?.changes) ? req.data.changes : []) as LineChange[];
  const note = typeof req.data?.note === "string" ? req.data.note.trim().slice(0, 300) : "";
  if (!orderId || changes.length === 0) throw new HttpsError("invalid-argument", "Nothing to change");

  try {
    const ref = db.doc(`orders/${orderId}`);
    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "Order not found");
      const status = snap.get("status") as OrderStatus;
      if (!canAdjust(status)) throw new HttpsError("failed-precondition", `A ${status} order cannot be changed`);

      const before = snap.get("items") as OrderLine[];
      const res = applyAdjustments(before, changes);
      if (!res.changed) throw new HttpsError("failed-precondition", "No quantities were changed");

      const now = Timestamp.now();
      tx.update(ref, {
        items: res.lines,
        totalPaise: res.totalPaise,
        status: "adjusted",
        statusHistory: FieldValue.arrayUnion({ status: "adjusted", by: owner.uid, at: now, note }),
        updatedAt: now,
      });
      return { before, after: res.lines };
    });
    await audit(owner.uid, "adjustOrder", `orders/${orderId}`, result.before, result.after);
    return { status: "adjusted" };
  } catch (e) {
    asHttpsError(e);
  }
});

export const setOrderStatus = onCall(callableOptions, async (req) => {
  const owner = requireOwner(req);
  const orderId = String(req.data?.orderId ?? "");
  const to = req.data?.status as OrderStatus;
  const paymentMethod = req.data?.paymentMethod;
  const note = typeof req.data?.note === "string" ? req.data.note.trim().slice(0, 300) : "";
  if (to === "picked_up" && !isPaymentMethod(paymentMethod)) {
    throw new HttpsError("invalid-argument", "Choose how the customer paid: cash, UPI or card");
  }

  const ref = db.doc(`orders/${orderId}`);
  const from = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Order not found");
    const current = snap.get("status") as OrderStatus;
    if (!canMove(current, to)) {
      throw new HttpsError("failed-precondition", `Cannot move a ${current} order to ${to}`);
    }
    const now = Timestamp.now();
    tx.update(ref, {
      status: to,
      statusHistory: FieldValue.arrayUnion({ status: to, by: owner.uid, at: now, note }),
      ...(to === "picked_up" ? { paymentMethod } : {}),
      updatedAt: now,
    });
    return current;
  });
  await audit(owner.uid, "setOrderStatus", `orders/${orderId}`, { status: from }, { status: to, paymentMethod });
  return { status: to };
});

const customerMessages: Partial<Record<OrderStatus, (no: string) => string>> = {
  adjusted: (no) => `The store changed order ${no}. Tap to see what changed.`,
  ready: (no) => `Order ${no} is packed and ready for pickup.`,
  picked_up: (no) => `Thank you! Order ${no} has been picked up.`,
  cancelled: (no) => `Order ${no} was cancelled by the store.`,
};

/** Tells the customer about adjustments and status changes. */
export const onOrderUpdated = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || !after.uid) return;
  const historyGrew = (after.statusHistory?.length ?? 0) > (before.statusHistory?.length ?? 0);
  if (!historyGrew) return;
  const message = customerMessages[after.status as OrderStatus];
  if (!message) return;
  await sendTo([after.uid], {
    title: after.status === "adjusted" ? "Order updated" : "Order update",
    body: message(after.orderNo),
    channel: "order_updates",
    route: `/orders/${event.params.orderId}`,
  });
});
