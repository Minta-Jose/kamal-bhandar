import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions/v2";
import { db } from "./common";

/** Android notification channels; the app creates the same ids on start. */
export type Channel = "sign_ups" | "new_orders" | "account" | "order_updates";

export interface Note {
  title: string;
  body: string;
  channel: Channel;
  /** Screen to open when tapped, e.g. "/owner/orders/abc". */
  route: string;
}

async function tokensFor(uids: string[]): Promise<{ uid: string; token: string }[]> {
  const out: { uid: string; token: string }[] = [];
  for (const uid of uids) {
    const devices = await db.collection(`users/${uid}/devices`).get();
    devices.forEach((d) => out.push({ uid, token: d.id }));
  }
  return out;
}

export async function ownerUids(): Promise<string[]> {
  const snap = await db.collection("users").where("role", "==", "owner").get();
  return snap.docs.map((d) => d.id);
}

/** Sends to every device of the given users and removes tokens that no longer work. */
export async function sendTo(uids: string[], note: Note): Promise<void> {
  const targets = await tokensFor(uids);
  if (targets.length === 0) {
    logger.info("No devices to notify", { uids, channel: note.channel });
    return;
  }
  const highPriority = note.channel === "new_orders" || note.channel === "order_updates";
  const res = await getMessaging().sendEachForMulticast({
    tokens: targets.map((t) => t.token),
    notification: { title: note.title, body: note.body },
    data: { route: note.route, channel: note.channel },
    android: {
      priority: highPriority ? "high" : "normal",
      notification: {
        channelId: note.channel,
        ...(note.channel === "new_orders" ? { sound: "new_order", visibility: "public" as const } : {}),
      },
    },
  });

  const stale: Promise<unknown>[] = [];
  res.responses.forEach((r, i) => {
    const code = r.error?.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token" ||
      code === "messaging/invalid-argument"
    ) {
      const t = targets[i];
      stale.push(db.doc(`users/${t.uid}/devices/${t.token}`).delete());
    } else if (r.error) {
      logger.warn("Notification failed", { code, channel: note.channel });
    }
  });
  await Promise.all(stale);
}

export async function sendToOwners(note: Note): Promise<void> {
  await sendTo(await ownerUids(), note);
}
