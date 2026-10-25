import { v1 } from "@google-cloud/firestore";
import { cloudbilling, auth as googleAuth } from "@googleapis/cloudbilling";
import { logger } from "firebase-functions/v2";
import { defineInt, projectID } from "firebase-functions/params";
import { onMessagePublished } from "firebase-functions/v2/pubsub";
import { onSchedule } from "firebase-functions/v2/scheduler";

/**
 * Exports the whole database every night at 2 am IST. The bucket keeps 30 days
 * of exports through its lifecycle rule (see docs/SETUP.md).
 */
export const nightlyBackup = onSchedule(
  { schedule: "0 2 * * *", timeZone: "Asia/Kolkata" },
  async () => {
    const project = projectID.value();
    const client = new v1.FirestoreAdminClient();
    const stamp = new Date().toISOString().slice(0, 10);
    const [op] = await client.exportDocuments({
      name: client.databasePath(project, "(default)"),
      outputUriPrefix: `gs://${project}-backups/${stamp}`,
      collectionIds: [],
    });
    logger.info("Backup started", { operation: op.name });
  },
);

/** Spend in rupees above which billing is switched off. */
const killSwitchLimitInr = defineInt("KILL_SWITCH_LIMIT_INR", { default: 10 });

interface BudgetMessage {
  costAmount: number;
  budgetAmount: number;
  currencyCode: string;
}

/**
 * Listens to the budget's Pub/Sub topic and detaches the billing account once
 * spend passes the limit, so charges stop. The app pauses until billing is
 * turned back on in the Google Cloud console.
 */
export const billingKillSwitch = onMessagePublished("billing-alerts", async (event) => {
  const msg = event.data.message.json as BudgetMessage;
  const limit = killSwitchLimitInr.value();
  logger.info("Budget notification", msg);
  if (msg.currencyCode !== "INR" || msg.costAmount <= limit) return;

  const name = `projects/${projectID.value()}`;
  const billing = cloudbilling({
    version: "v1",
    auth: new googleAuth.GoogleAuth({ scopes: ["https://www.googleapis.com/auth/cloud-billing"] }),
  });
  const info = await billing.projects.getBillingInfo({ name });
  if (!info.data.billingEnabled) return;
  await billing.projects.updateBillingInfo({ name, requestBody: { billingAccountName: "" } });
  logger.error(`Billing switched off: spend ₹${msg.costAmount} passed the ₹${limit} limit`);
});
